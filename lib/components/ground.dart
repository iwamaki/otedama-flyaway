import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../config/physics_config.dart';

/// 地面コンポーネント
/// 静的な衝突オブジェクト
class Ground extends BodyComponent {
  final Vector2 initialPosition;
  final Vector2 size;
  final Color color;

  Ground({
    required Vector2 position,
    required this.size,
    this.color = const Color(0xFF8B7355), // 畳っぽい色
  }) : initialPosition = position;

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(size.x, size.y);

    final fixtureDef = FixtureDef(shape)
      ..friction = PhysicsConfig.groundFriction
      ..restitution = PhysicsConfig.groundRestitution;

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
