import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../config/physics_config.dart';

/// 壁コンポーネント
/// 静的な衝突オブジェクト
class Wall extends BodyComponent {
  final Vector2 initialPosition;
  final Vector2 size;
  final Color color;

  Wall({
    required Vector2 position,
    required this.size,
    this.color = const Color(0xFF654321), // 木の壁
  }) : initialPosition = position;

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(size.x, size.y);

    final fixtureDef = FixtureDef(shape)
      ..friction = PhysicsConfig.wallFriction
      ..restitution = PhysicsConfig.wallRestitution;

    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.x * 2,
        height: size.y * 2,
      ),
      paint,
    );
  }
}
