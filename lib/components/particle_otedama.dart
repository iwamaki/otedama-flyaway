import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../config/physics_config.dart';

/// 粒子ベースのお手玉
/// 外殻（8点）+ 内部ビーズ（15個）で構成
class ParticleOtedama extends BodyComponent {
  final Vector2 initialPosition;
  final Color color;

  // 外殻のボディ（袋を形成）
  final List<Body> shellBodies = [];
  // 内部ビーズのボディ
  final List<Body> beadBodies = [];
  // ジョイント（外殻を繋ぐ）
  final List<Joint> shellJoints = [];

  // ダミーボディ（BodyComponentの要件を満たすため）
  Body? _dummyBody;

  // 設定可能なパラメータ（調整済みデフォルト値）
  static int shellCount = 13;
  static int beadCount = 20;
  static double shellRadius = 0.28;
  static double beadRadius = 0.3;
  static double overallRadius = 2.50;
  static double shellDensity = 5.0;
  static double beadDensity = 5.0;
  static double shellFriction = 0.51;
  static double beadFriction = 1.0;
  static double shellRestitution = 0.0;
  static double beadRestitution = 0.0;
  static double jointFrequency = 0.0; // 0=硬い接続（伸びない）、>0=バネ
  static double jointDamping = 0.0;
  static double shellRelativeDamping = 0.0; // 節同士の相対運動の減衰（重力に影響しない）
  static double gravityScale = 2.0; // 重力スケール（1.0 = 通常）

  // 距離制約の補正（PBDアプローチ）
  static int distanceConstraintIterations = 10; // 補正の反復回数
  static double distanceConstraintStiffness = 1.0; // 補正の強さ（0.0-1.0）

  // ビーズ封じ込め制約
  static bool beadContainmentEnabled = true; // 封じ込め有効
  static double beadContainmentMargin = 0.25; // 外殻境界からのマージン

  // 初期ジョイント長を記録
  final List<double> _initialJointLengths = [];

  // 発射制限用
  int _launchCount = 0; // 発射回数（0: 未発射, 1: 初回発射済み, 2: 空中発射済み）
  bool _isGrounded = false; // 接地中フラグ
  static const double _groundedVelocityThreshold = 1.5; // 接地判定の速度閾値

  /// 空中発射の力の倍率（初回の何倍か）
  static double airLaunchMultiplier = 0.5;

  /// 発射可能かどうか
  bool get canLaunch => _launchCount < 2;

  /// 空中発射かどうか（UI表示用）
  bool get isAirLaunch => _launchCount == 1 && !_isGrounded;

  ParticleOtedama({
    required Vector2 position,
    this.color = const Color(0xFFCC3333),
  }) : initialPosition = position;

  @override
  void update(double dt) {
    super.update(dt);

    // 節同士の相対運動に減衰を適用（重力には影響しない）
    _applyRelativeDamping(dt);

    // 距離制約を強制（PBD：位置ベースで補正）
    _enforceDistanceConstraints();

    // ビーズ封じ込め制約（外殻の内側に留める）
    _enforceBeadContainment();

    // ダミーボディを粒子の重心に追従させる
    if (shellBodies.isNotEmpty || beadBodies.isNotEmpty) {
      body.setTransform(centerPosition, 0);
    }

    // 接地判定（速度ベース）と発射カウントリセット
    _updateGroundedState();
  }

  /// 接地状態の更新と発射カウントのリセット
  void _updateGroundedState() {
    // 平均速度を計算
    final avgVelocity = _getAverageVelocity();

    // 速度が閾値以下なら接地とみなす
    final wasGrounded = _isGrounded;
    _isGrounded = avgVelocity < _groundedVelocityThreshold;

    // 接地した瞬間に発射カウントをリセット
    if (_isGrounded && !wasGrounded && _launchCount > 0) {
      _launchCount = 0;
    }
  }

  /// 外殻粒子の平均速度を取得
  double _getAverageVelocity() {
    if (shellBodies.isEmpty) return 0;

    double totalSpeed = 0;
    for (final body in shellBodies) {
      totalSpeed += body.linearVelocity.length;
    }
    return totalSpeed / shellBodies.length;
  }

  /// 隣接する節間の相対速度に減衰力を適用
  void _applyRelativeDamping(double dt) {
    if (shellBodies.length < 2 || shellRelativeDamping <= 0) return;

    for (int i = 0; i < shellBodies.length; i++) {
      final bodyA = shellBodies[i];
      final bodyB = shellBodies[(i + 1) % shellBodies.length];

      // 相対速度を計算
      final relativeVel = bodyA.linearVelocity - bodyB.linearVelocity;

      // 減衰力を計算（相対速度に比例）
      final dampingForce = relativeVel * shellRelativeDamping * dt;

      // 両方のボディに反対方向の力を適用
      bodyA.applyLinearImpulse(-dampingForce * bodyA.mass);
      bodyB.applyLinearImpulse(dampingForce * bodyB.mass);
    }
  }

  /// 距離制約を強制（Position Based Dynamics）
  /// Box2Dのジョイントだけでは伸びてしまうので、位置を直接補正
  void _enforceDistanceConstraints() {
    if (shellBodies.length < 2 || _initialJointLengths.isEmpty) return;
    if (distanceConstraintStiffness <= 0) return;

    // 複数回反復して精度を上げる
    for (int iter = 0; iter < distanceConstraintIterations; iter++) {
      for (int i = 0; i < shellBodies.length; i++) {
        final bodyA = shellBodies[i];
        final bodyB = shellBodies[(i + 1) % shellBodies.length];
        final targetLength = _initialJointLengths[i];

        final delta = bodyB.position - bodyA.position;
        final currentLength = delta.length;

        if (currentLength < 0.001) continue;

        // 目標長さとの差
        final diff = currentLength - targetLength;
        if (diff.abs() < 0.001) continue;

        // 補正量を計算
        final normalized = delta / currentLength; // normalized()より安全
        final correction = normalized * (diff * 0.5 * distanceConstraintStiffness);

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
          final velCorrection = normalized * (velAlongNormal * 0.5 * distanceConstraintStiffness);
          bodyA.linearVelocity = bodyA.linearVelocity + velCorrection * ratioA;
          bodyB.linearVelocity = bodyB.linearVelocity - velCorrection * ratioB;
        }
      }
    }
  }

  /// ビーズを外殻の内側に閉じ込める
  /// 外殻が形成する多角形の外にビーズがいたら内側に押し戻す
  void _enforceBeadContainment() {
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

  @override
  Body createBody() {
    // ダミーボディ（センサー、衝突しない）
    final shape = CircleShape()..radius = 0.01;
    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..density = 0;
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition;
    _dummyBody = world.createBody(bodyDef)..createFixture(fixtureDef);
    return _dummyBody!;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _createParticleBodies();
  }

  void _createParticleBodies() {
    // 外殻を作成（円形に配置）
    for (int i = 0; i < shellCount; i++) {
      final angle = (i / shellCount) * 2 * math.pi;
      final x = initialPosition.x + math.cos(angle) * overallRadius * 0.7;
      final y = initialPosition.y + math.sin(angle) * overallRadius * 0.7;

      final body = _createCircleBody(
        Vector2(x, y),
        shellRadius,
        shellDensity,
        shellFriction,
        shellRestitution,
      );
      shellBodies.add(body);
    }

    // 外殻同士をDistance Jointで接続（隣接のみ、対角線なし）
    _initialJointLengths.clear();
    for (int i = 0; i < shellCount; i++) {
      final bodyA = shellBodies[i];
      final bodyB = shellBodies[(i + 1) % shellCount];

      // 初期長を記録（PBD補正用）
      final initialLength = (bodyA.position - bodyB.position).length;
      _initialJointLengths.add(initialLength);

      final jointDef = DistanceJointDef()
        ..initialize(bodyA, bodyB, bodyA.position, bodyB.position)
        ..frequencyHz = jointFrequency
        ..dampingRatio = jointDamping;

      final joint = DistanceJoint(jointDef);
      world.createJoint(joint);
      shellJoints.add(joint);
    }

    // 内部ビーズを作成（ランダムに配置）
    final random = math.Random();
    for (int i = 0; i < beadCount; i++) {
      // 中心付近にランダム配置
      final r = random.nextDouble() * overallRadius * 0.4;
      final angle = random.nextDouble() * 2 * math.pi;
      final x = initialPosition.x + math.cos(angle) * r;
      final y = initialPosition.y + math.sin(angle) * r;

      final body = _createCircleBody(
        Vector2(x, y),
        beadRadius,
        beadDensity,
        beadFriction,
        beadRestitution,
      );
      beadBodies.add(body);
    }
  }

  Body _createCircleBody(
    Vector2 position,
    double radius,
    double density,
    double friction,
    double restitution,
  ) {
    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density = density
      ..friction = friction
      ..restitution = restitution;

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = position
      ..angularDamping = 1.0
      ..linearDamping = 0.1; // 最小限の減衰

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    // 外殻を線で結んで袋を描画
    if (shellBodies.isEmpty) return;

    // BodyComponentはbody.positionを基準にcanvasを変換済み
    // 粒子はワールド座標で動いているので、body.position分を引いて相対座標にする
    final bodyPos = body.position;

    // 外殻の重心を計算（外縁オフセット用）
    double centerX = 0, centerY = 0;
    for (final shellBody in shellBodies) {
      centerX += shellBody.position.x - bodyPos.x;
      centerY += shellBody.position.y - bodyPos.y;
    }
    centerX /= shellBodies.length;
    centerY /= shellBodies.length;

    // 袋の形状（外殻の外縁を結ぶPath）
    final points = <Offset>[];

    for (final shellBody in shellBodies) {
      final sx = shellBody.position.x - bodyPos.x;
      final sy = shellBody.position.y - bodyPos.y;

      // 中心から外側への方向ベクトル
      final dx = sx - centerX;
      final dy = sy - centerY;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist > 0.001) {
        // 外殻の外縁にオフセット（shellRadiusだけ外側へ）
        final nx = dx / dist;
        final ny = dy / dist;
        points.add(Offset(
          sx + nx * shellRadius,
          sy + ny * shellRadius,
        ));
      } else {
        points.add(Offset(sx, sy));
      }
    }

    if (points.isEmpty) return;

    // Catmull-Romスプラインで滑らかに
    final smoothPath = _createSmoothPath(points);

    // 袋の塗りつぶし
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.2,
      colors: [
        color,
        Color.lerp(color, Colors.black, 0.4)!,
      ],
    );
    final bounds = smoothPath.getBounds();
    if (bounds.isEmpty) return;

    final paint = Paint()..shader = gradient.createShader(bounds);
    canvas.drawPath(smoothPath, paint);

    // 縁取り
    final borderPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.25)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;
    canvas.drawPath(smoothPath, borderPaint);

    // デバッグ: ビーズを表示（半透明）
    final beadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    for (final beadBody in beadBodies) {
      canvas.drawCircle(
        Offset(
          beadBody.position.x - bodyPos.x,
          beadBody.position.y - bodyPos.y,
        ),
        beadRadius,
        beadPaint,
      );
    }

    // 縫い目模様
    _drawPattern(canvas, bounds);
  }

  Path _createSmoothPath(List<Offset> points) {
    if (points.length < 3) return Path();

    final path = Path();

    for (int i = 0; i < points.length; i++) {
      final p0 = points[(i - 1 + points.length) % points.length];
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final p3 = points[(i + 2) % points.length];

      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      }

      // Catmull-Rom to Bezier
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  void _drawPattern(Canvas canvas, Rect bounds) {
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final radiusX = bounds.width / 2 * 0.5;
    final radiusY = bounds.height / 2 * 0.5;

    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;

    // 縦の縫い目
    canvas.drawLine(
      Offset(centerX, centerY - radiusY),
      Offset(centerX, centerY + radiusY),
      patternPaint,
    );

    // 横の縫い目
    canvas.drawLine(
      Offset(centerX - radiusX, centerY),
      Offset(centerX + radiusX, centerY),
      patternPaint,
    );

    // 中心の結び目
    final knotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: radiusX * 0.15,
        height: radiusY * 0.15,
      ),
      knotPaint,
    );
  }

  /// 重心位置を取得
  Vector2 get centerPosition {
    if (shellBodies.isEmpty && beadBodies.isEmpty) return initialPosition;

    var sum = Vector2.zero();
    var count = 0;

    for (final body in shellBodies) {
      sum += body.position;
      count++;
    }
    for (final body in beadBodies) {
      sum += body.position;
      count++;
    }

    return count > 0 ? sum / count.toDouble() : initialPosition;
  }

  /// タップ位置に力を加える際の効果範囲（半径の倍率）
  /// 小さいほどタップ位置に集中、大きいほど全体に分散
  static double touchEffectRadius = 1.0;

  /// 発射（タップ位置に近い外殻粒子に強い力を加える）
  /// touchPointを指定すると、その位置に近い外殻粒子に強いインパルスが加わり
  /// 回転（トルク）が発生する
  /// ※内部ビーズには力を加えない
  ///
  /// 発射制限:
  /// - 初回発射: フルパワー
  /// - 空中発射: 1回だけ、半分のパワー（airLaunchMultiplier）
  /// - それ以降: 発射不可
  void launch(Vector2 impulse, {Vector2? touchPoint}) {
    // 発射可能かチェック
    if (!canLaunch) {
      return; // 発射回数制限に達している
    }

    // 空中発射かどうかで力を調整
    final powerMultiplier = (_launchCount >= 1) ? airLaunchMultiplier : 1.0;
    final scaledImpulse = impulse * PhysicsConfig.launchMultiplier * powerMultiplier;

    if (touchPoint == null || shellBodies.isEmpty) {
      // タップ位置がない場合は従来通り全体に均一に力を加える
      for (final body in shellBodies) {
        body.applyLinearImpulse(scaledImpulse * body.mass);
      }
    } else {
      // タップ位置に近い外殻粒子に強いインパルスを加える（ガウシアン重み付け）
      final sigma = overallRadius * touchEffectRadius;
      final sigma2 = sigma * sigma;

      double totalWeight = 0;
      final weights = <double>[];

      for (final body in shellBodies) {
        final distance = (body.position - touchPoint).length;
        // ガウシアン関数: exp(-d^2 / (2σ^2))
        final weight = math.exp(-(distance * distance) / (2 * sigma2));
        weights.add(weight);
        totalWeight += weight;
      }

      // 重みを正規化して、合計インパルスが一定になるようにする
      final normalizer = shellBodies.length / totalWeight;

      for (int i = 0; i < shellBodies.length; i++) {
        final body = shellBodies[i];
        final normalizedWeight = weights[i] * normalizer;
        body.applyLinearImpulse(scaledImpulse * body.mass * normalizedWeight);
      }
    }
    // beadBodiesには一切インパルスを加えない
    // → 外殻に閉じ込められているので、衝突で自然に動く

    // 発射カウントを増加
    _launchCount++;
  }

  /// リセット
  void reset() {
    _destroyAllBodies();
    _createParticleBodies();
    _launchCount = 0;
    _isGrounded = true;
  }

  /// 指定位置にリセット
  void resetToPosition(Vector2 newPosition) {
    // 現在位置との差分を計算
    final diff = newPosition - centerPosition;

    // 全ボディを移動
    for (final body in shellBodies) {
      body.setTransform(body.position + diff, body.angle);
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
    }
    for (final body in beadBodies) {
      body.setTransform(body.position + diff, body.angle);
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
    }

    // 発射カウントもリセット
    _launchCount = 0;
    _isGrounded = true;
  }

  /// 物理を一時停止（編集モード用）
  void freeze() {
    for (final body in shellBodies) {
      body.setType(BodyType.static);
    }
    for (final body in beadBodies) {
      body.setType(BodyType.static);
    }
  }

  /// 物理を再開（編集モード用）
  void unfreeze() {
    for (final body in shellBodies) {
      body.setType(BodyType.dynamic);
    }
    for (final body in beadBodies) {
      body.setType(BodyType.dynamic);
    }
  }

  /// パラメータ変更後の再構築
  void rebuild() {
    reset();
  }

  void _destroyAllBodies() {
    for (final joint in shellJoints) {
      world.destroyJoint(joint);
    }
    shellJoints.clear();

    for (final body in shellBodies) {
      world.destroyBody(body);
    }
    shellBodies.clear();

    for (final body in beadBodies) {
      world.destroyBody(body);
    }
    beadBodies.clear();
  }

  @override
  void onRemove() {
    _destroyAllBodies();
    super.onRemove();
  }
}
