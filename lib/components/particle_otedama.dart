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

  // 設定可能なパラメータ（調整済み）
  static int shellCount = 18;
  static int beadCount = 28;
  static double shellRadius = 0.47;
  static double beadRadius = 0.20;
  static double overallRadius = 2.51;
  static double shellDensity = 3.0;
  static double beadDensity = 0.98;
  static double shellFriction = 1.0;
  static double beadFriction = 0.0;
  static double shellRestitution = 0.0;
  static double beadRestitution = 0.0;
  static double jointFrequency = 20.0;
  static double jointDamping = 1.0;
  static double shellRelativeDamping = 5.0; // 節同士の相対運動の減衰（重力に影響しない）
  static double gravityScale = 1.0; // 重力スケール（1.0 = 通常）

  ParticleOtedama({
    required Vector2 position,
    this.color = const Color(0xFFCC3333),
  }) : initialPosition = position;

  @override
  void update(double dt) {
    super.update(dt);

    // 節同士の相対運動に減衰を適用（重力には影響しない）
    _applyRelativeDamping(dt);

    // ダミーボディを粒子の重心に追従させる
    if (shellBodies.isNotEmpty || beadBodies.isNotEmpty) {
      body.setTransform(centerPosition, 0);
    }
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
    for (int i = 0; i < shellCount; i++) {
      final bodyA = shellBodies[i];
      final bodyB = shellBodies[(i + 1) % shellCount];

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

  /// 発射（全ボディに力を加える）
  void launch(Vector2 impulse) {
    final scaledImpulse = impulse * PhysicsConfig.launchMultiplier;

    for (final body in shellBodies) {
      body.applyLinearImpulse(scaledImpulse * body.mass);
    }
    for (final body in beadBodies) {
      body.applyLinearImpulse(scaledImpulse * body.mass);
    }
  }

  /// リセット
  void reset() {
    _destroyAllBodies();
    _createParticleBodies();
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
