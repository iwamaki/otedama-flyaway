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

  /// 反転チェックをスキップするための速度閾値
  static const double _inversionCheckVelocityThreshold = 5.0;

  ParticlePhysicsSolver({
    required this.constraintIterations,
    required this.constraintStiffness,
    required this.beadContainmentEnabled,
    required this.beadContainmentMargin,
    required this.beadRadius,
    required this.shellRadius,
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
    if (shellBodies.length < 2 || initialJointLengths.isEmpty) return;
    if (constraintStiffness <= 0) return;

    final shellCount = shellBodies.length;
    final halfStiffness = 0.5 * constraintStiffness;

    // 複数回反復して精度を上げる
    for (int iter = 0; iter < constraintIterations; iter++) {
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
    final thresholdSq = _inversionCheckVelocityThreshold * _inversionCheckVelocityThreshold;
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
      if (cross < -0.01) {
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
        if (dist < avgNeighborDist * 0.7) {
          final targetDist = avgNeighborDist * 0.9;
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
}
