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
  Vector2 _size;

  /// 初期角度（ラジアン）
  final double initialAngle;

  /// 水平反転
  bool _flipX;

  /// 垂直反転
  bool _flipY;

  /// 色
  final Color color;

  Platform({
    required Vector2 position,
    double width = 3.0,
    double height = 0.3,
    double angle = 0.0,
    bool flipX = false,
    bool flipY = false,
    this.color = const Color(0xFF6B8E23), // オリーブグリーン
  })  : initialPosition = position.clone(),
        _size = Vector2(width / 2, height / 2),
        initialAngle = angle,
        _flipX = flipX,
        _flipY = flipY;

  /// JSONから生成
  factory Platform.fromJson(Map<String, dynamic> json) {
    return Platform(
      position: json.getVector2(),
      width: json.getDouble('width', 3.0),
      height: json.getDouble('height', 0.3),
      angle: json.getDouble('angle'),
      flipX: json.getBool('flipX'),
      flipY: json.getBool('flipY'),
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
  double get width => _size.x * 2;

  @override
  double get height => _size.y * 2;

  @override
  bool get canResize => true;

  @override
  bool get canFlip => true;

  @override
  bool get flipX => _flipX;

  @override
  bool get flipY => _flipY;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final pos = body.position;
    return (
      Vector2(pos.x - _size.x, pos.y - _size.y),
      Vector2(pos.x + _size.x, pos.y + _size.y),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': position.x,
      'y': position.y,
      'width': _size.x * 2,
      'height': _size.y * 2,
      'angle': angle,
      'flipX': _flipX,
      'flipY': _flipY,
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
    if (props.containsKey('width')) {
      final newWidth = (props['width'] as num?)?.toDouble() ?? width;
      _size.x = newWidth / 2;
      _rebuildFixtures();
    }
    if (props.containsKey('height')) {
      final newHeight = (props['height'] as num?)?.toDouble() ?? height;
      _size.y = newHeight / 2;
      _rebuildFixtures();
    }
    if (props.containsKey('flipX')) {
      _flipX = props['flipX'] as bool? ?? _flipX;
    }
    if (props.containsKey('flipY')) {
      _flipY = props['flipY'] as bool? ?? _flipY;
    }
  }

  /// 物理フィクスチャを再構築
  void _rebuildFixtures() {
    if (!isMounted) return;

    // 既存フィクスチャを削除
    while (body.fixtures.isNotEmpty) {
      body.destroyFixture(body.fixtures.first);
    }
    // 新しいフィクスチャを作成
    _createFixture();
  }

  /// フィクスチャを作成
  void _createFixture() {
    final shape = PolygonShape()..setAsBoxXY(_size.x, _size.y);
    body.createFixture(FixtureDef(shape)
      ..friction = PhysicsConfig.groundFriction
      ..restitution = PhysicsConfig.groundRestitution);
  }

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(_size.x, _size.y);

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
    // 反転のためのスケール
    canvas.save();
    canvas.scale(_flipX ? -1 : 1, _flipY ? -1 : 1);

    final paint = Paint()..color = color;

    // 板の本体
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _size.x * 2,
      height: _size.y * 2,
    );
    canvas.drawRect(rect, paint);

    // 上面のハイライト
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    canvas.drawLine(
      Offset(-_size.x, -_size.y),
      Offset(_size.x, -_size.y),
      highlightPaint,
    );

    // 下面の影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;
    canvas.drawLine(
      Offset(-_size.x, _size.y),
      Offset(_size.x, _size.y),
      shadowPaint,
    );

    // 木目風のテクスチャ（オプション）
    _drawWoodGrain(canvas, rect);

    canvas.restore();

    // 選択中ならハイライト
    if (isSelected) {
      SelectionHighlight.draw(canvas, halfWidth: _size.x, halfHeight: _size.y);
    }
  }

  void _drawWoodGrain(Canvas canvas, Rect rect) {
    final grainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02;

    // 横線を数本描画
    final grainCount = (_size.x * 2 / 0.5).floor().clamp(2, 10);
    for (int i = 1; i < grainCount; i++) {
      final x = -_size.x + (_size.x * 2 / grainCount) * i;
      canvas.drawLine(
        Offset(x, -_size.y + 0.02),
        Offset(x, _size.y - 0.02),
        grainPaint,
      );
    }
  }
}

/// Platformをファクトリに登録
void registerPlatformFactory() {
  StageObjectFactory.register('platform', (json) => Platform.fromJson(json));
}
