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

  ParticlePhysicsSolver({
    required this.constraintIterations,
    required this.constraintStiffness,
    required this.beadContainmentEnabled,
    required this.beadContainmentMargin,
    required this.beadRadius,
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
  void enforceDistanceConstraints(
    List<Body> shellBodies,
    List<double> initialJointLengths,
  ) {
    if (shellBodies.length < 2 || initialJointLengths.isEmpty) return;
    if (constraintStiffness <= 0) return;

    // 複数回反復して精度を上げる
    for (int iter = 0; iter < constraintIterations; iter++) {
      for (int i = 0; i < shellBodies.length; i++) {
        final bodyA = shellBodies[i];
        final bodyB = shellBodies[(i + 1) % shellBodies.length];
        final targetLength = initialJointLengths[i];

        final delta = bodyB.position - bodyA.position;
        final currentLength = delta.length;

        if (currentLength < 0.001) continue;

        // 目標長さとの差
        final diff = currentLength - targetLength;
        if (diff.abs() < 0.001) continue;

        // 補正量を計算
        final normalized = delta / currentLength;
        final correction = normalized * (diff * 0.5 * constraintStiffness);

        // 無効な値チェック
        if (correction.x.isNaN || correction.y.isNaN ||
            correction.x.isInfinite || correction.y.isInfinite) {
          continue;
        }

        // 両方の粒子を均等に移動（質量を考慮）
        final totalMass = bodyA.mass + bodyB.mass;
        if (totalMass <= 0) continue;

        final ratioA = bodyB.mass / totalMass;
        final ratioB = bodyA.mass / totalMass;

        // 新しい位置を計算
        final newPosA = bodyA.position + correction * ratioA;
        final newPosB = bodyB.position - correction * ratioB;

        // 位置が有効な場合のみ適用
        if (!newPosA.x.isNaN && !newPosA.y.isNaN &&
            !newPosA.x.isInfinite && !newPosA.y.isInfinite) {
          bodyA.setTransform(newPosA, bodyA.angle);
        }
        if (!newPosB.x.isNaN && !newPosB.y.isNaN &&
            !newPosB.x.isInfinite && !newPosB.y.isInfinite) {
          bodyB.setTransform(newPosB, bodyB.angle);
        }

        // 速度も補正（伸びる方向の速度成分を減衰）
        final relVel = bodyB.linearVelocity - bodyA.linearVelocity;
        final velAlongNormal = relVel.dot(normalized);

        if (diff > 0 && velAlongNormal > 0) {
          // 伸びている＆さらに伸びようとしている場合、速度を補正
          final velCorrection = normalized * (velAlongNormal * 0.5 * constraintStiffness);
          bodyA.linearVelocity = bodyA.linearVelocity + velCorrection * ratioA;
          bodyB.linearVelocity = bodyB.linearVelocity - velCorrection * ratioB;
        }
      }
    }
  }

  /// ビーズを外殻の内側に閉じ込める
  void enforceBeadContainment(List<Body> shellBodies, List<Body> beadBodies) {
    if (!beadContainmentEnabled) return;
    if (shellBodies.length < 3 || beadBodies.isEmpty) return;

    // 外殻の頂点リスト（位置のみ）
    final shellPositions = shellBodies.map((b) => b.position).toList();

    for (final bead in beadBodies) {
      final beadPos = bead.position;

      // ビーズが多角形の内側にあるかチェック
      if (_isPointInsidePolygon(beadPos, shellPositions)) {
        continue; // 内側にいるので何もしない
      }

      // 外側にいる場合、最も近い外殻エッジに押し戻す
      _pushBeadInside(bead, shellPositions);
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

  /// ビーズを最も近い外殻エッジの内側に押し戻す
  void _pushBeadInside(Body bead, List<Vector2> shellPositions) {
    final beadPos = bead.position;
    final n = shellPositions.length;

    // 最も近いエッジを見つける
    double minDist = double.infinity;
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
      final dist = (beadPos - closest).length;

      if (dist < minDist) {
        minDist = dist;
        closestPoint = closest;

        // エッジの内向き法線を計算
        final perpendicular = Vector2(-edge.y, edge.x).normalized();
        // 多角形の重心方向が内側
        final center = _calculateCentroid(shellPositions);
        final toCenter = center - closest;
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

  /// 多角形の重心を計算
  Vector2 _calculateCentroid(List<Vector2> polygon) {
    var sum = Vector2.zero();
    for (final p in polygon) {
      sum += p;
    }
    return sum / polygon.length.toDouble();
  }
}
