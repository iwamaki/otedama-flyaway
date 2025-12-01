import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../config/physics_config.dart';
import 'soft_body.dart';

/// お手玉コンポーネント
/// 物理演算で動く主役のオブジェクト
/// ビーズの重心シミュレーションで形状が変化
class Otedama extends BodyComponent with ContactCallbacks {
  final Vector2 initialPosition;
  final Color color;

  // ソフトボディ（形状変化用）
  late SoftBody _softBody;

  // 衝突時の追加変形
  double _impactSquash = 0.0;
  double _impactAngle = 0.0;

  Otedama({
    required Vector2 position,
    this.color = const Color(0xFFCC3333),
  }) : initialPosition = position;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ソフトボディを初期化
    _softBody = SoftBody(
      baseRadius: PhysicsConfig.otedamaRadius,
      numPoints: 16,
    );
  }

  @override
  Body createBody() {
    // 物理は円で近似（衝突判定用）
    final shape = CircleShape()..radius = PhysicsConfig.otedamaRadius;

    final fixtureDef = FixtureDef(shape)
      ..density = PhysicsConfig.otedamaDensity
      ..friction = PhysicsConfig.otedamaFriction
      ..restitution = PhysicsConfig.otedamaRestitution;

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = initialPosition
      ..angularDamping = PhysicsConfig.otedamaAngularDamping
      ..linearDamping = PhysicsConfig.otedamaLinearDamping;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 衝突変形を徐々に戻す
    if (_impactSquash > 0) {
      _impactSquash = (_impactSquash - dt * 6).clamp(0.0, 1.0);
    }

    // ソフトボディの物理演算を実行
    _softBody.update(dt, body.linearVelocity);
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);

    // 衝突時の変形演出
    final impactSpeed = body.linearVelocity.length;
    if (impactSpeed > 2.0) {
      _impactSquash = (impactSpeed / 10).clamp(0.0, 0.7);

      // 衝突方向を計算
      final manifold = contact.manifold;
      if (manifold.localNormal.length > 0) {
        _impactAngle = math.atan2(manifold.localNormal.y, manifold.localNormal.x);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    // 衝突時の追加変形（潰れる）
    if (_impactSquash > 0) {
      canvas.rotate(_impactAngle);
      canvas.scale(1.0 + _impactSquash * 0.5, 1.0 - _impactSquash * 0.4);
      canvas.rotate(-_impactAngle);
    }

    // ソフトボディの形状を取得して描画
    final path = _softBody.getOuterPath();

    // グラデーションで立体感
    final bounds = path.getBounds();
    if (bounds.isEmpty) {
      canvas.restore();
      return;
    }

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.2,
      colors: [
        color,
        Color.lerp(color, Colors.black, 0.4)!,
      ],
    );
    final paint = Paint()..shader = gradient.createShader(bounds);
    canvas.drawPath(path, paint);

    // 縁取り（布の質感）
    final borderPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.25)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06;
    canvas.drawPath(path, borderPaint);

    // 縫い目模様
    _drawPattern(canvas, bounds);

    canvas.restore();
  }

  void _drawPattern(Canvas canvas, Rect bounds) {
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final radiusX = bounds.width / 2 * 0.65;
    final radiusY = bounds.height / 2 * 0.65;

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

    // 斜めの縫い目
    canvas.drawLine(
      Offset(centerX - radiusX * 0.6, centerY - radiusY * 0.6),
      Offset(centerX + radiusX * 0.6, centerY + radiusY * 0.6),
      patternPaint,
    );
    canvas.drawLine(
      Offset(centerX + radiusX * 0.6, centerY - radiusY * 0.6),
      Offset(centerX - radiusX * 0.6, centerY + radiusY * 0.6),
      patternPaint,
    );

    // 中心の結び目
    final knotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: radiusX * 0.18,
        height: radiusY * 0.18,
      ),
      knotPaint,
    );
  }

  /// パチンコ式発射
  void launch(Vector2 impulse) {
    body.applyLinearImpulse(impulse * body.mass * PhysicsConfig.launchMultiplier);
  }

  /// 初期位置にリセット
  void reset() {
    body.setTransform(initialPosition, 0);
    body.linearVelocity = Vector2.zero();
    body.angularVelocity = 0;
    _impactSquash = 0;
    _softBody.reset();
  }

  /// 現在の速度を取得
  Vector2 get velocity => body.linearVelocity;

  /// 静止しているかどうか
  bool get isAtRest => body.linearVelocity.length < 0.5;
}
