import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../config/physics_config.dart';
import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';

/// 足場コンポーネント
/// お手玉が乗れる静的な板
class Platform extends BodyComponent with StageObject {
  /// 初期位置
  final Vector2 initialPosition;

  /// サイズ（幅、高さの半分）
  final Vector2 size;

  /// 初期角度（ラジアン）
  final double initialAngle;

  /// 色
  final Color color;

  Platform({
    required Vector2 position,
    double width = 3.0,
    double height = 0.3,
    double angle = 0.0,
    this.color = const Color(0xFF6B8E23), // オリーブグリーン
  })  : initialPosition = position.clone(),
        size = Vector2(width / 2, height / 2),
        initialAngle = angle;

  /// JSONから生成
  factory Platform.fromJson(Map<String, dynamic> json) {
    return Platform(
      position: json.getVector2(),
      width: json.getDouble('width', 3.0),
      height: json.getDouble('height', 0.3),
      angle: json.getDouble('angle'),
      color: json.getColor('color', const Color(0xFF6B8E23)),
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'platform';

  @override
  Vector2 get position => body.position;

  @override
  double get angle => body.angle;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final pos = body.position;
    return (
      Vector2(pos.x - size.x, pos.y - size.y),
      Vector2(pos.x + size.x, pos.y + size.y),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': position.x,
      'y': position.y,
      'width': size.x * 2,
      'height': size.y * 2,
      'angle': angle,
      // ignore: deprecated_member_use
      'color': color.value,
    };
  }

  @override
  void applyProperties(Map<String, dynamic> props) {
    if (props.containsKey('x') || props.containsKey('y')) {
      final newX = (props['x'] as num?)?.toDouble() ?? position.x;
      final newY = (props['y'] as num?)?.toDouble() ?? position.y;
      body.setTransform(Vector2(newX, newY), body.angle);
    }
    if (props.containsKey('angle')) {
      final newAngle = (props['angle'] as num?)?.toDouble() ?? 0.0;
      body.setTransform(body.position, newAngle);
    }
    // サイズ変更は物理ボディの再生成が必要なため、現時点では未対応
  }

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(size.x, size.y);

    final fixtureDef = FixtureDef(shape)
      ..friction = PhysicsConfig.groundFriction
      ..restitution = PhysicsConfig.groundRestitution;

    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition
      ..angle = initialAngle;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;

    // 板の本体
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x * 2,
      height: size.y * 2,
    );
    canvas.drawRect(rect, paint);

    // 上面のハイライト
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    canvas.drawLine(
      Offset(-size.x, -size.y),
      Offset(size.x, -size.y),
      highlightPaint,
    );

    // 下面の影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    canvas.drawLine(
      Offset(-size.x, size.y),
      Offset(size.x, size.y),
      shadowPaint,
    );

    // 木目風のテクスチャ（オプション）
    _drawWoodGrain(canvas, rect);

    // 選択中ならハイライト
    if (isSelected) {
      SelectionHighlight.draw(canvas, halfWidth: size.x, halfHeight: size.y);
    }
  }

  void _drawWoodGrain(Canvas canvas, Rect rect) {
    final grainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;

    // 横線を数本描画
    final grainCount = (size.x * 2 / 0.5).floor().clamp(2, 10);
    for (int i = 1; i < grainCount; i++) {
      final x = -size.x + (size.x * 2 / grainCount) * i;
      canvas.drawLine(
        Offset(x, -size.y + 0.02),
        Offset(x, size.y - 0.02),
        grainPaint,
      );
    }
  }
}

/// Platformをファクトリに登録
void registerPlatformFactory() {
  StageObjectFactory.register('platform', (json) => Platform.fromJson(json));
}
