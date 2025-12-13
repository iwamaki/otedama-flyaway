import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

/// ParticleOtedama の物理ソルバー
/// 距離制約（PBD）とビーズ封じ込めを担当
class ParticlePhysicsSolver {
  /// 距離制約の反復回数
  final int constraintIterations;

  /// 距離制約の強さ (0.0-1.0)
  final double constraintStiffness;

  /// ビーズ封じ込め有効フラグ
  final bool beadContainmentEnabled;

  /// 外殻境界からのマージン
  final double beadContainmentMargin;

  /// ビーズの半径
  final double beadRadius;

  /// 外殻粒子の半径（接触判定に使用）
  final double shellRadius;

  /// 反転チェックをスキップするための速度閾値
  final double inversionCheckVelocityThreshold;

  /// 凹み検出の外積閾値（負の値、小さいほど敏感）
  final double inversionCrossThreshold;

  /// 押し出し開始の距離比率（隣接頂点の平均距離に対する比率）
  final double inversionPushStartRatio;

  /// 押し出し先の距離比率
  final double inversionPushTargetRatio;

  /// 曲げ制約: 最小角度（ラジアン）
  final double minBendingAngle;

  /// 曲げ制約: 剛性（0.0-1.0）
  final double bendingStiffness;

  /// キャッシュ用バッファ（毎フレームの再割り当てを防ぐ）
  List<Vector2> _shellPositionCache = [];
  final Vector2 _centroidCache = Vector2.zero();

  /// PBD計算用の再利用可能なVector2キャッシュ
  final Vector2 _deltaCache = Vector2.zero();
  final Vector2 _correctionCache = Vector2.zero();
  final Vector2 _newPosACache = Vector2.zero();
  final Vector2 _newPosBCache = Vector2.zero();

  /// 外殻反転チェック用キャッシュ
  List<Vector2> _inversionPositionCache = [];
  final Vector2 _inversionCentroidCache = Vector2.zero();

  /// 速度変化の閾値（この速度以下の粒子は一部の計算をスキップ）
  static const double _lowVelocityThreshold = 0.5;
  static const double _lowVelocityThresholdSq = _lowVelocityThreshold * _lowVelocityThreshold;

  ParticlePhysicsSolver({
    required this.constraintIterations,
    required this.constraintStiffness,
    required this.beadContainmentEnabled,
    required this.beadContainmentMargin,
    required this.beadRadius,
    required this.shellRadius,
    this.inversionCheckVelocityThreshold = 5.0,
    this.inversionCrossThreshold = -0.01,
    this.inversionPushStartRatio = 0.7,
    this.inversionPushTargetRatio = 0.9,
    this.minBendingAngle = 2.094, // 120度 = 2π/3
    this.bendingStiffness = 0.5,
  });

  /// 隣接する節間の相対速度に減衰力を適用
  void applyRelativeDamping(
    List<Body> shellBodies,
    double dt,
    double dampingFactor,
  ) {
    if (shellBodies.length < 2 || dampingFactor <= 0) return;

    for (int i = 0; i < shellBodies.length; i++) {
      final bodyA = shellBodies[i];
      final bodyB = shellBodies[(i + 1) % shellBodies.length];

      // 相対速度を計算
      final relativeVel = bodyA.linearVelocity - bodyB.linearVelocity;

      // 減衰力を計算（相対速度に比例）
      final dampingForce = relativeVel * dampingFactor * dt;

      // 両方のボディに反対方向の力を適用
      bodyA.applyLinearImpulse(-dampingForce * bodyA.mass);
      bodyB.applyLinearImpulse(dampingForce * bodyB.mass);
    }
  }

  /// 距離制約を強制（Position Based Dynamics）
  /// Box2Dのジョイントだけでは伸びてしまうので、位置を直接補正
  /// 最適化版: Vector2キャッシュの再利用、早期終了判定
  void enforceDistanceConstraints(
    List<Body> shellBodies,
    List<double> initialJointLengths,
  ) {
    enforceDistanceConstraintsMultiple(
      shellBodies,
      initialJointLengths,
      constraintIterations,
    );
  }

  /// 距離制約を指定イテレーション数で強制（サブステップ対応版）
  void enforceDistanceConstraintsMultiple(
    List<Body> shellBodies,
    List<double> initialJointLengths,
    int iterations,
  ) {
    if (shellBodies.length < 2 || initialJointLengths.isEmpty) return;
    if (constraintStiffness <= 0) return;

    final shellCount = shellBodies.length;
    final halfStiffness = 0.5 * constraintStiffness;

    // 複数回反復して精度を上げる
    for (int iter = 0; iter < iterations; iter++) {
      for (int i = 0; i < shellCount; i++) {
        final bodyA = shellBodies[i];
        final bodyB = shellBodies[(i + 1) % shellCount];
        final targetLength = initialJointLengths[i];

        // キャッシュを再利用してVector2生成を回避
        final posA = bodyA.position;
        final posB = bodyB.position;
        _deltaCache.x = posB.x - posA.x;
        _deltaCache.y = posB.y - posA.y;

        final currentLengthSq = _deltaCache.x * _deltaCache.x + _deltaCache.y * _deltaCache.y;
        if (currentLengthSq < 0.000001) continue;

        // sqrtを1回だけ呼ぶ
        final currentLength = math.sqrt(currentLengthSq);
        final diff = currentLength - targetLength;

        // 差が小さい場合はスキップ
        if (diff.abs() < 0.001) continue;

        // 正規化と補正量を計算（キャッシュ使用）
        final invLength = 1.0 / currentLength;
        final correctionFactor = diff * halfStiffness * invLength;
        _correctionCache.x = _deltaCache.x * correctionFactor;
        _correctionCache.y = _deltaCache.y * correctionFactor;

        // 無効な値チェック（まとめてチェック）
        if (!_correctionCache.x.isFinite || !_correctionCache.y.isFinite) {
          continue;
        }

        // 両方の粒子を均等に移動（質量を考慮）
        final massA = bodyA.mass;
        final massB = bodyB.mass;
        final totalMass = massA + massB;
        if (totalMass <= 0) continue;

        final ratioA = massB / totalMass;
        final ratioB = massA / totalMass;

        // 新しい位置を計算（キャッシュ使用）
        _newPosACache.x = posA.x + _correctionCache.x * ratioA;
        _newPosACache.y = posA.y + _correctionCache.y * ratioA;
        _newPosBCache.x = posB.x - _correctionCache.x * ratioB;
        _newPosBCache.y = posB.y - _correctionCache.y * ratioB;

        // 位置が有効な場合のみ適用
        if (_newPosACache.x.isFinite && _newPosACache.y.isFinite) {
          bodyA.setTransform(_newPosACache, bodyA.angle);
        }
        if (_newPosBCache.x.isFinite && _newPosBCache.y.isFinite) {
          bodyB.setTransform(_newPosBCache, bodyB.angle);
        }

        // 速度補正は伸びが大きい場合のみ実行
        if (diff > 0.01) {
          final velA = bodyA.linearVelocity;
          final velB = bodyB.linearVelocity;
          final relVelX = velB.x - velA.x;
          final relVelY = velB.y - velA.y;

          // 正規化済みdelta
          final normalizedX = _deltaCache.x * invLength;
          final normalizedY = _deltaCache.y * invLength;
          final velAlongNormal = relVelX * normalizedX + relVelY * normalizedY;

          if (velAlongNormal > 0) {
            final velCorrectionFactor = velAlongNormal * halfStiffness;
            final velCorrX = normalizedX * velCorrectionFactor;
            final velCorrY = normalizedY * velCorrectionFactor;
            bodyA.linearVelocity = Vector2(velA.x + velCorrX * ratioA, velA.y + velCorrY * ratioA);
            bodyB.linearVelocity = Vector2(velB.x - velCorrX * ratioB, velB.y - velCorrY * ratioB);
          }
        }
      }
    }
  }


  /// スキップ制約用キャッシュ
  final Vector2 _skipDeltaCache = Vector2.zero();
  final Vector2 _skipCorrectionCache = Vector2.zero();

  /// 角度順序維持用キャッシュ
  final List<double> _angleCache = [];
  final Vector2 _angleCentroidCache = Vector2.zero();

  /// 位相的速度制約用キャッシュ
  final Vector2 _topologyCentroidCache = Vector2.zero();
  final List<double> _topologyAngleCache = [];

  /// 角度順序を維持（クロス防止の根本対策）
  /// 粒子が重心から見て正しい角度順序を保つように制約
  void enforceAngleOrder(List<Body> shellBodies, double strength) {
    if (shellBodies.length < 3) return;
    if (strength <= 0) return;

    final n = shellBodies.length;

    // 重心を計算
    _angleCentroidCache.setValues(0, 0);
    for (final body in shellBodies) {
      _angleCentroidCache.x += body.position.x;
      _angleCentroidCache.y += body.position.y;
    }
    _angleCentroidCache.x /= n;
    _angleCentroidCache.y /= n;

    // 各粒子の角度を計算
    if (_angleCache.length != n) {
      _angleCache.clear();
      for (int i = 0; i < n; i++) {
        _angleCache.add(0);
      }
    }

    for (int i = 0; i < n; i++) {
      final pos = shellBodies[i].position;
      final dx = pos.x - _angleCentroidCache.x;
      final dy = pos.y - _angleCentroidCache.y;
      _angleCache[i] = math.atan2(dy, dx);
    }

    // 期待される角度間隔
    final expectedAngleStep = 2 * math.pi / n;

    // 各粒子について、隣接粒子との角度関係をチェック
    for (int i = 0; i < n; i++) {
      final prevIdx = (i - 1 + n) % n;

      final prevAngle = _angleCache[prevIdx];
      final currAngle = _angleCache[i];

      // 前の粒子との角度差
      var diffPrev = currAngle - prevAngle;
      while (diffPrev > math.pi) { diffPrev -= 2 * math.pi; }
      while (diffPrev < -math.pi) { diffPrev += 2 * math.pi; }

      // クロス検出: 角度差が負（順序が逆転）
      // 閾値を設けて、小さな揺らぎは無視
      final crossThreshold = -expectedAngleStep * 0.1; // 10%までは許容

      if (diffPrev < crossThreshold) {
        // クロスしている - 前の粒子と現在の粒子の中間に移動
        final midAngle = prevAngle + expectedAngleStep * 0.5;

        // 現在の重心からの距離を維持
        final pos = shellBodies[i].position;
        final dist = math.sqrt(
          (pos.x - _angleCentroidCache.x) * (pos.x - _angleCentroidCache.x) +
          (pos.y - _angleCentroidCache.y) * (pos.y - _angleCentroidCache.y)
        );

        // 理想的な位置（前の粒子より少し先）
        final idealX = _angleCentroidCache.x + math.cos(midAngle) * dist;
        final idealY = _angleCentroidCache.y + math.sin(midAngle) * dist;

        // 滑らかに補正（strengthで強さを調整）
        final corrStrength = strength * 0.3; // 控えめに補正
        final newX = pos.x + (idealX - pos.x) * corrStrength;
        final newY = pos.y + (idealY - pos.y) * corrStrength;

        if (newX.isFinite && newY.isFinite) {
          shellBodies[i].setTransform(Vector2(newX, newY), shellBodies[i].angle);
        }
      }
    }
  }

  /// スキップ距離制約を強制（i番目とi+step番目の粒子間の最小距離を維持）
  /// これにより外殻が内側に折れ曲がることを防ぐ
  void enforceSkipConstraints(
    List<Body> shellBodies,
    List<double> initialSkipLengths,
    int step,
    double minRatio,
  ) {
    if (shellBodies.length < 3 || initialSkipLengths.isEmpty) return;
    if (step <= 0 || step >= shellBodies.length ~/ 2) return;

    final shellCount = shellBodies.length;

    for (int i = 0; i < shellCount; i++) {
      final bodyA = shellBodies[i];
      final bodyB = shellBodies[(i + step) % shellCount];
      final minLength = initialSkipLengths[i] * minRatio;

      final posA = bodyA.position;
      final posB = bodyB.position;
      _skipDeltaCache.x = posB.x - posA.x;
      _skipDeltaCache.y = posB.y - posA.y;

      final currentLengthSq = _skipDeltaCache.x * _skipDeltaCache.x +
          _skipDeltaCache.y * _skipDeltaCache.y;
      final minLengthSq = minLength * minLength;

      // 最小距離より近い場合のみ補正
      if (currentLengthSq < minLengthSq && currentLengthSq > 0.000001) {
        final currentLength = math.sqrt(currentLengthSq);
        final diff = minLength - currentLength; // 正の値（押し広げる）

        // 正規化と補正量を計算
        final invLength = 1.0 / currentLength;
        final correctionFactor = diff * 0.5 * invLength; // 両側に半分ずつ
        _skipCorrectionCache.x = _skipDeltaCache.x * correctionFactor;
        _skipCorrectionCache.y = _skipDeltaCache.y * correctionFactor;

        if (!_skipCorrectionCache.x.isFinite || !_skipCorrectionCache.y.isFinite) {
          continue;
        }

        // 両方の粒子を均等に押し広げる
        final newPosAx = posA.x - _skipCorrectionCache.x;
        final newPosAy = posA.y - _skipCorrectionCache.y;
        final newPosBx = posB.x + _skipCorrectionCache.x;
        final newPosBy = posB.y + _skipCorrectionCache.y;

        if (newPosAx.isFinite && newPosAy.isFinite) {
          bodyA.setTransform(Vector2(newPosAx, newPosAy), bodyA.angle);
        }
        if (newPosBx.isFinite && newPosBy.isFinite) {
          bodyB.setTransform(Vector2(newPosBx, newPosBy), bodyB.angle);
        }
      }
    }
  }

  /// AABB（軸並行境界ボックス）のキャッシュ
  double _aabbMinX = 0, _aabbMinY = 0, _aabbMaxX = 0, _aabbMaxY = 0;

  /// ビーズを外殻の内側に閉じ込める
  /// 最適化版: AABBによる早期判定、速度が小さいビーズのスキップ
  void enforceBeadContainment(List<Body> shellBodies, List<Body> beadBodies) {
    if (!beadContainmentEnabled) return;
    if (shellBodies.length < 3 || beadBodies.isEmpty) return;

    // 外殻の頂点リストをキャッシュに更新（再割り当てを避ける）
    _updateShellPositionCache(shellBodies);

    // AABBを計算（高速な境界チェック用）
    _updateAABB();

    // 重心を事前計算（_pushBeadInside内で毎回計算していたものをキャッシュ）
    _calculateCentroidInto(_shellPositionCache, _centroidCache);

    // AABBにマージンを追加（ビーズ半径分）
    final margin = beadRadius + beadContainmentMargin;
    final aabbMinXExpanded = _aabbMinX + margin;
    final aabbMaxXExpanded = _aabbMaxX - margin;
    final aabbMinYExpanded = _aabbMinY + margin;
    final aabbMaxYExpanded = _aabbMaxY - margin;

    for (final bead in beadBodies) {
      final beadPos = bead.position;

      // 速度が十分小さく、AABBの内側深くにいるビーズはスキップ
      final vel = bead.linearVelocity;
      final speedSq = vel.x * vel.x + vel.y * vel.y;
      if (speedSq < _lowVelocityThresholdSq) {
        // 内側マージン付きAABB内にいればスキップ
        if (beadPos.x > aabbMinXExpanded && beadPos.x < aabbMaxXExpanded &&
            beadPos.y > aabbMinYExpanded && beadPos.y < aabbMaxYExpanded) {
          continue;
        }
      }

      // AABBの外側にいる場合は確実に外殻外
      if (beadPos.x < _aabbMinX || beadPos.x > _aabbMaxX ||
          beadPos.y < _aabbMinY || beadPos.y > _aabbMaxY) {
        _pushBeadInsideWithCentroid(bead, _shellPositionCache, _centroidCache);
        continue;
      }

      // ビーズが多角形の内側にあるかチェック
      if (_isPointInsidePolygon(beadPos, _shellPositionCache)) {
        continue; // 内側にいるので何もしない
      }

      // 外側にいる場合、最も近い外殻エッジに押し戻す
      _pushBeadInsideWithCentroid(bead, _shellPositionCache, _centroidCache);
    }
  }

  /// AABBを更新
  void _updateAABB() {
    if (_shellPositionCache.isEmpty) return;

    _aabbMinX = _shellPositionCache[0].x;
    _aabbMaxX = _shellPositionCache[0].x;
    _aabbMinY = _shellPositionCache[0].y;
    _aabbMaxY = _shellPositionCache[0].y;

    for (int i = 1; i < _shellPositionCache.length; i++) {
      final p = _shellPositionCache[i];
      if (p.x < _aabbMinX) _aabbMinX = p.x;
      if (p.x > _aabbMaxX) _aabbMaxX = p.x;
      if (p.y < _aabbMinY) _aabbMinY = p.y;
      if (p.y > _aabbMaxY) _aabbMaxY = p.y;
    }
  }

  /// shellPositionCacheを更新（メモリ割り当てを最小化）
  void _updateShellPositionCache(List<Body> shellBodies) {
    if (_shellPositionCache.length != shellBodies.length) {
      _shellPositionCache = shellBodies.map((b) => b.position).toList();
    } else {
      for (int i = 0; i < shellBodies.length; i++) {
        _shellPositionCache[i] = shellBodies[i].position;
      }
    }
  }

  /// 点が多角形の内側にあるか判定（レイキャスティング法）
  bool _isPointInsidePolygon(Vector2 point, List<Vector2> polygon) {
    int intersections = 0;
    final n = polygon.length;

    for (int i = 0; i < n; i++) {
      final p1 = polygon[i];
      final p2 = polygon[(i + 1) % n];

      // 点から右方向への半直線と辺が交差するかチェック
      if ((p1.y > point.y) != (p2.y > point.y)) {
        final xIntersect = (p2.x - p1.x) * (point.y - p1.y) / (p2.y - p1.y) + p1.x;
        if (point.x < xIntersect) {
          intersections++;
        }
      }
    }

    return intersections % 2 == 1; // 奇数回交差なら内側
  }

  /// ビーズを最も近い外殻エッジの内側に押し戻す（重心をキャッシュから使用）
  void _pushBeadInsideWithCentroid(Body bead, List<Vector2> shellPositions, Vector2 centroid) {
    final beadPos = bead.position;
    final n = shellPositions.length;

    // 最も近いエッジを見つける
    double minDistSq = double.infinity;
    Vector2? closestPoint;
    Vector2? edgeNormal;

    for (int i = 0; i < n; i++) {
      final p1 = shellPositions[i];
      final p2 = shellPositions[(i + 1) % n];

      // エッジ上の最近点を計算
      final edge = p2 - p1;
      final edgeLengthSq = edge.length2;
      if (edgeLengthSq < 0.0001) continue;

      var t = (beadPos - p1).dot(edge) / edgeLengthSq;
      t = t.clamp(0.0, 1.0);

      final closest = p1 + edge * t;
      // 距離の2乗で比較（sqrtを避ける）
      final dx = beadPos.x - closest.x;
      final dy = beadPos.y - closest.y;
      final distSq = dx * dx + dy * dy;

      if (distSq < minDistSq) {
        minDistSq = distSq;
        closestPoint = closest;

        // エッジの内向き法線を計算
        final perpendicular = Vector2(-edge.y, edge.x).normalized();
        // 多角形の重心方向が内側（キャッシュされた重心を使用）
        final toCenter = centroid - closest;
        if (perpendicular.dot(toCenter) < 0) {
          edgeNormal = -perpendicular;
        } else {
          edgeNormal = perpendicular;
        }
      }
    }

    if (closestPoint != null && edgeNormal != null) {
      // マージン分だけ内側に押し戻す
      final targetPos = closestPoint + edgeNormal * (beadRadius + beadContainmentMargin);
      bead.setTransform(targetPos, bead.angle);

      // 速度も補正（外向きの速度成分を除去）
      final vel = bead.linearVelocity;
      final outwardVel = vel.dot(-edgeNormal);
      if (outwardVel > 0) {
        bead.linearVelocity = vel + edgeNormal * outwardVel;
      }
    }
  }

  /// 多角形の重心を計算（既存のVector2に格納）
  void _calculateCentroidInto(List<Vector2> polygon, Vector2 result) {
    result.setValues(0, 0);
    for (final p in polygon) {
      result.x += p.x;
      result.y += p.y;
    }
    result.x /= polygon.length;
    result.y /= polygon.length;
  }

  /// ビーズ同士の重複を解消（PBDアプローチ）
  /// 着地時にめり込んだビーズを即座に押し広げる
  void enforceBeadSeparation(List<Body> beadBodies, List<double> beadRadii) {
    if (beadBodies.length < 2 || beadRadii.length != beadBodies.length) return;

    final n = beadBodies.length;

    // 全てのビーズペアをチェック
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final bodyA = beadBodies[i];
        final bodyB = beadBodies[j];
        final radiusA = beadRadii[i];
        final radiusB = beadRadii[j];
        final minDist = radiusA + radiusB;

        final posA = bodyA.position;
        final posB = bodyB.position;
        final dx = posB.x - posA.x;
        final dy = posB.y - posA.y;
        final distSq = dx * dx + dy * dy;
        final minDistSq = minDist * minDist;

        // 重なっている場合のみ処理
        if (distSq < minDistSq && distSq > 0.000001) {
          final dist = math.sqrt(distSq);
          final overlap = minDist - dist;

          // 正規化方向ベクトル
          final invDist = 1.0 / dist;
          final nx = dx * invDist;
          final ny = dy * invDist;

          // 両方のビーズを半分ずつ押し広げる
          final halfOverlap = overlap * 0.5;
          final newPosAx = posA.x - nx * halfOverlap;
          final newPosAy = posA.y - ny * halfOverlap;
          final newPosBx = posB.x + nx * halfOverlap;
          final newPosBy = posB.y + ny * halfOverlap;

          if (newPosAx.isFinite && newPosAy.isFinite) {
            bodyA.setTransform(Vector2(newPosAx, newPosAy), bodyA.angle);
          }
          if (newPosBx.isFinite && newPosBy.isFinite) {
            bodyB.setTransform(Vector2(newPosBx, newPosBy), bodyB.angle);
          }

          // 速度も補正（接近方向の速度成分を除去）
          final velA = bodyA.linearVelocity;
          final velB = bodyB.linearVelocity;
          final relVelX = velB.x - velA.x;
          final relVelY = velB.y - velA.y;
          final approachSpeed = -(relVelX * nx + relVelY * ny);

          if (approachSpeed > 0) {
            // 接近している場合、速度を修正
            final velCorrection = approachSpeed * 0.5;
            bodyA.linearVelocity = Vector2(
              velA.x - nx * velCorrection,
              velA.y - ny * velCorrection,
            );
            bodyB.linearVelocity = Vector2(
              velB.x + nx * velCorrection,
              velB.y + ny * velCorrection,
            );
          }
        }
      }
    }
  }

  /// 曲げ制約を強制（Bending Constraint）
  /// 隣接3点の角度が最小値を下回らないように制約
  /// これにより外殻が内側に折れ曲がること自体を防ぐ
  void enforceBendingConstraints(List<Body> shellBodies) {
    if (shellBodies.length < 3) return;
    if (bendingStiffness <= 0) return;

    final n = shellBodies.length;
    final cosMinAngle = math.cos(minBendingAngle);

    for (int i = 0; i < n; i++) {
      final prevBody = shellBodies[(i - 1 + n) % n];
      final currBody = shellBodies[i];
      final nextBody = shellBodies[(i + 1) % n];

      final prev = prevBody.position;
      final curr = currBody.position;
      final next = nextBody.position;

      // currを頂点とするベクトル
      final v1x = prev.x - curr.x;
      final v1y = prev.y - curr.y;
      final v2x = next.x - curr.x;
      final v2y = next.y - curr.y;

      final len1Sq = v1x * v1x + v1y * v1y;
      final len2Sq = v2x * v2x + v2y * v2y;
      if (len1Sq < 0.0001 || len2Sq < 0.0001) continue;

      final len1 = math.sqrt(len1Sq);
      final len2 = math.sqrt(len2Sq);

      // cos(angle) = dot(v1, v2) / (|v1| * |v2|)
      final dot = v1x * v2x + v1y * v2y;
      final cosAngle = dot / (len1 * len2);

      // 角度が最小値より小さい場合（cosが大きい場合）に補正
      // cos(120°) ≈ -0.5 なので、cosAngle > -0.5 なら角度 < 120°
      if (cosAngle > cosMinAngle) {
        // 外積で回転方向を判定（正=反時計回り=凸、負=時計回り=凹）
        final cross = v1x * v2y - v1y * v2x;

        // 凹んでいる場合のみ補正（cross < 0）
        if (cross < 0) {
          // currを外側に押し出す
          // 押し出し方向: v1とv2の二等分線の逆方向（外向き）
          final bisectX = v1x / len1 + v2x / len2;
          final bisectY = v1y / len1 + v2y / len2;
          final bisectLen = math.sqrt(bisectX * bisectX + bisectY * bisectY);

          if (bisectLen > 0.0001) {
            // 必要な角度補正量を計算
            final targetCosAngle = cosMinAngle - 0.1; // 少し余裕を持たせる
            final angleDiff = math.acos(cosAngle.clamp(-1.0, 1.0)) -
                math.acos(targetCosAngle.clamp(-1.0, 1.0));

            // 補正距離（角度差に比例）
            final avgLen = (len1 + len2) * 0.5;
            final correctionDist = angleDiff * avgLen * bendingStiffness * 0.5;

            // 二等分線方向に押し出し（bisectは内向きなので符号反転）
            final pushX = -bisectX / bisectLen * correctionDist;
            final pushY = -bisectY / bisectLen * correctionDist;

            if (pushX.isFinite && pushY.isFinite) {
              // currを主に動かし、prev/nextも少し動かす
              final newCurrX = curr.x + pushX * 0.6;
              final newCurrY = curr.y + pushY * 0.6;
              currBody.setTransform(Vector2(newCurrX, newCurrY), currBody.angle);

              // prev/nextは逆方向に少し動かす（全体の形を保つ）
              final sidePush = 0.2;
              prevBody.setTransform(
                Vector2(prev.x - pushX * sidePush, prev.y - pushY * sidePush),
                prevBody.angle,
              );
              nextBody.setTransform(
                Vector2(next.x - pushX * sidePush, next.y - pushY * sidePush),
                nextBody.angle,
              );

              // 速度も補正（内向き成分を除去）
              final vel = currBody.linearVelocity;
              final inwardNormX = bisectX / bisectLen;
              final inwardNormY = bisectY / bisectLen;
              final inwardVel = vel.x * inwardNormX + vel.y * inwardNormY;
              if (inwardVel > 0) {
                currBody.linearVelocity = Vector2(
                  vel.x - inwardNormX * inwardVel * bendingStiffness,
                  vel.y - inwardNormY * inwardVel * bendingStiffness,
                );
              }
            }
          }
        }
      }
    }
  }

  /// 外殻の反転（クロス）を検出して補正する
  /// 強い衝撃で外殻が八の字にクロスしてしまう問題を防ぐ
  /// 最適化版: 速度が低い時はスキップ、キャッシュ使用
  void preventShellInversion(List<Body> shellBodies) {
    if (shellBodies.length < 3) return;

    // 速度が低い場合は反転チェックをスキップ（衝撃がなければ反転しない）
    double maxSpeedSq = 0;
    for (final body in shellBodies) {
      final vel = body.linearVelocity;
      final speedSq = vel.x * vel.x + vel.y * vel.y;
      if (speedSq > maxSpeedSq) maxSpeedSq = speedSq;
    }
    final thresholdSq = inversionCheckVelocityThreshold * inversionCheckVelocityThreshold;
    if (maxSpeedSq < thresholdSq) return;

    final n = shellBodies.length;

    // キャッシュを使用してメモリ割り当てを削減
    if (_inversionPositionCache.length != n) {
      _inversionPositionCache = List.generate(n, (_) => Vector2.zero());
    }
    for (int i = 0; i < n; i++) {
      _inversionPositionCache[i].setFrom(shellBodies[i].position);
    }
    _calculateCentroidInto(_inversionPositionCache, _inversionCentroidCache);

    // 各頂点について、隣接する3点で凹みが発生していないかチェック
    for (int i = 0; i < n; i++) {
      final prev = _inversionPositionCache[(i - 1 + n) % n];
      final curr = _inversionPositionCache[i];
      final next = _inversionPositionCache[(i + 1) % n];

      // 外積で回転方向をチェック（反時計回りなら正）
      // インライン計算で一時オブジェクト生成を回避
      final v1x = curr.x - prev.x;
      final v1y = curr.y - prev.y;
      final v2x = next.x - curr.x;
      final v2y = next.y - curr.y;
      final cross = v1x * v2y - v1y * v2x;

      // 凹み（内側に折れ曲がり）を検出
      if (cross < inversionCrossThreshold) {
        final toVertexX = curr.x - _inversionCentroidCache.x;
        final toVertexY = curr.y - _inversionCentroidCache.y;
        final distSq = toVertexX * toVertexX + toVertexY * toVertexY;

        if (distSq < 0.0001) continue;
        final dist = math.sqrt(distSq);

        // 隣接頂点の重心からの平均距離を計算
        final prevDx = prev.x - _inversionCentroidCache.x;
        final prevDy = prev.y - _inversionCentroidCache.y;
        final nextDx = next.x - _inversionCentroidCache.x;
        final nextDy = next.y - _inversionCentroidCache.y;
        final prevDist = math.sqrt(prevDx * prevDx + prevDy * prevDy);
        final nextDist = math.sqrt(nextDx * nextDx + nextDy * nextDy);
        final avgNeighborDist = (prevDist + nextDist) * 0.5;

        // 現在の頂点が隣より内側にいる場合、押し出す
        if (dist < avgNeighborDist * inversionPushStartRatio) {
          final targetDist = avgNeighborDist * inversionPushTargetRatio;
          final invDist = 1.0 / dist;
          final normalizedX = toVertexX * invDist;
          final normalizedY = toVertexY * invDist;
          final correctionDist = targetDist - dist;

          final body = shellBodies[i];
          final newPosX = curr.x + normalizedX * correctionDist;
          final newPosY = curr.y + normalizedY * correctionDist;

          if (newPosX.isFinite && newPosY.isFinite) {
            body.setTransform(Vector2(newPosX, newPosY), body.angle);

            // 内向きの速度成分も除去
            final vel = body.linearVelocity;
            final inwardVel = -(vel.x * normalizedX + vel.y * normalizedY);
            if (inwardVel > 0) {
              body.linearVelocity = Vector2(
                vel.x + normalizedX * inwardVel,
                vel.y + normalizedY * inwardVel,
              );
            }
          }
        }
      }
    }

    // 全体の符号付き面積もチェック（完全に反転した場合）
    final signedArea = _calculateSignedArea(_inversionPositionCache);
    if (signedArea < 0) {
      _expandFromCentroid(shellBodies, _inversionCentroidCache);
    }
  }

  /// 符号付き面積を計算（正=反時計回り、負=時計回り=反転）
  double _calculateSignedArea(List<Vector2> polygon) {
    double area = 0;
    final n = polygon.length;
    for (int i = 0; i < n; i++) {
      final curr = polygon[i];
      final next = polygon[(i + 1) % n];
      area += curr.x * next.y - next.x * curr.y;
    }
    return area / 2;
  }

  /// 全頂点を重心から押し広げる
  void _expandFromCentroid(List<Body> shellBodies, Vector2 centroid) {
    for (final body in shellBodies) {
      final pos = body.position;
      final toVertex = pos - centroid;
      final dist = toVertex.length;

      if (dist < 0.01) continue;

      // 最低限の距離を確保
      const minDist = 0.5;
      if (dist < minDist) {
        final newPos = centroid + toVertex.normalized() * minDist;
        if (!newPos.x.isNaN && !newPos.y.isNaN) {
          body.setTransform(newPos, body.angle);
        }
      }
    }
  }

  /// 位相的速度制約（Topological Velocity Constraint）
  /// 粒子が隣の粒子を「追い越す」ような速度成分を事前に除去
  /// CCDなしでクロスを防ぐための予防的アプローチ
  ///
  /// [dt] シミュレーションの時間刻み
  /// [strength] 制約の強さ (0.0-1.0)
  /// [safetyMargin] 追い越し判定のマージン（ラジアン、小さいほど厳しい）
  void enforceTopologicalVelocityConstraint(
    List<Body> shellBodies,
    double dt,
    double strength, {
    double safetyMargin = 0.1,
  }) {
    if (shellBodies.length < 3 || strength <= 0 || dt <= 0) return;

    final n = shellBodies.length;

    // 重心を計算
    _topologyCentroidCache.setValues(0, 0);
    for (final body in shellBodies) {
      _topologyCentroidCache.x += body.position.x;
      _topologyCentroidCache.y += body.position.y;
    }
    _topologyCentroidCache.x /= n;
    _topologyCentroidCache.y /= n;

    // 各粒子の現在の角度を計算
    if (_topologyAngleCache.length != n) {
      _topologyAngleCache.clear();
      for (int i = 0; i < n; i++) {
        _topologyAngleCache.add(0);
      }
    }

    for (int i = 0; i < n; i++) {
      final pos = shellBodies[i].position;
      final dx = pos.x - _topologyCentroidCache.x;
      final dy = pos.y - _topologyCentroidCache.y;
      _topologyAngleCache[i] = math.atan2(dy, dx);
    }

    // 各粒子について、速度によって隣を追い越すかチェック
    for (int i = 0; i < n; i++) {
      final body = shellBodies[i];
      final vel = body.linearVelocity;

      // 速度が小さい場合はスキップ
      final speedSq = vel.x * vel.x + vel.y * vel.y;
      if (speedSq < 1.0) continue;

      final pos = body.position;
      final currAngle = _topologyAngleCache[i];

      // 予測位置での角度
      final predictedX = pos.x + vel.x * dt;
      final predictedY = pos.y + vel.y * dt;
      final predictedDx = predictedX - _topologyCentroidCache.x;
      final predictedDy = predictedY - _topologyCentroidCache.y;
      var predictedAngle = math.atan2(predictedDy, predictedDx);

      // 角度差を計算（-π ~ π）
      var angleDelta = predictedAngle - currAngle;
      while (angleDelta > math.pi) {
        angleDelta -= 2 * math.pi;
      }
      while (angleDelta < -math.pi) {
        angleDelta += 2 * math.pi;
      }

      // 前後の粒子の角度
      final prevIdx = (i - 1 + n) % n;
      final nextIdx = (i + 1) % n;
      final prevAngle = _topologyAngleCache[prevIdx];
      final nextAngle = _topologyAngleCache[nextIdx];

      // 前の粒子との角度差（現在の角度 - 前の角度）
      var diffPrev = currAngle - prevAngle;
      while (diffPrev > math.pi) {
        diffPrev -= 2 * math.pi;
      }
      while (diffPrev < -math.pi) {
        diffPrev += 2 * math.pi;
      }

      // 次の粒子との角度差（次の角度 - 現在の角度）
      var diffNext = nextAngle - currAngle;
      while (diffNext > math.pi) {
        diffNext -= 2 * math.pi;
      }
      while (diffNext < -math.pi) {
        diffNext += 2 * math.pi;
      }

      bool needsCorrection = false;

      // 反時計回りに移動して次の粒子を追い越しそうか
      if (angleDelta > 0 && angleDelta > diffNext - safetyMargin) {
        needsCorrection = true;
      }
      // 時計回りに移動して前の粒子を追い越しそうか
      if (angleDelta < 0 && -angleDelta > diffPrev - safetyMargin) {
        needsCorrection = true;
      }

      if (needsCorrection) {
        // 周方向の速度成分を削減
        // 周方向の単位ベクトル（反時計回り = 正）
        final toCenter = _topologyCentroidCache - pos;
        final dist = math.sqrt(toCenter.x * toCenter.x + toCenter.y * toCenter.y);
        if (dist < 0.001) continue;

        // 接線方向（反時計回り）: 中心への垂直
        final tangentX = -toCenter.y / dist;
        final tangentY = toCenter.x / dist;

        // 周方向の速度成分
        final tangentialVel = vel.x * tangentX + vel.y * tangentY;

        // 周方向成分を減衰（追い越しを防ぐ）
        final correctionFactor = strength * 0.9; // 強く抑制
        final newVelX = vel.x - tangentX * tangentialVel * correctionFactor;
        final newVelY = vel.y - tangentY * tangentialVel * correctionFactor;

        if (newVelX.isFinite && newVelY.isFinite) {
          body.linearVelocity = Vector2(newVelX, newVelY);
        }
      }
    }
  }

  /// 多層スキップ制約を強制
  /// 複数のstep値で制約を適用し、より強固にクロスを防ぐ
  void enforceMultiLayerSkipConstraints(
    List<Body> shellBodies,
    List<List<double>> initialSkipLengthsByStep,
    List<int> steps,
    List<double> minRatios,
  ) {
    if (shellBodies.length < 3) return;
    if (steps.length != minRatios.length) return;
    if (steps.length != initialSkipLengthsByStep.length) return;

    for (int layer = 0; layer < steps.length; layer++) {
      final step = steps[layer];
      final minRatio = minRatios[layer];
      final initialLengths = initialSkipLengthsByStep[layer];

      if (initialLengths.isEmpty) continue;

      enforceSkipConstraints(shellBodies, initialLengths, step, minRatio);
    }
  }
}
