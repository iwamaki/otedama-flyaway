import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../config/physics_config.dart';
import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';

/// 氷床コンポーネント
/// 摩擦がほぼゼロでお手玉が滑る
class IceFloor extends BodyComponent with StageObject {
  /// デフォルト値
  static const double defaultWidth = 5.0;
  static const double defaultHeight = 0.4;
  static const double defaultFriction = 0.01;

  /// 初期位置
  final Vector2 initialPosition;

  /// サイズ（幅、高さの半分）
  Vector2 _size;

  /// 初期角度（ラジアン）
  final double initialAngle;

  /// 摩擦（デフォルトで非常に低い）
  final double friction;

  /// 水平反転
  bool _flipX;

  /// 垂直反転
  bool _flipY;

  /// 色
  final Color color;

  /// キラキラ用のランダム
  final List<_Sparkle> _sparkles = [];

  IceFloor({
    required Vector2 position,
    double width = defaultWidth,
    double height = defaultHeight,
    double angle = 0.0,
    this.friction = defaultFriction,
    bool flipX = false,
    bool flipY = false,
    this.color = const Color(0xFF87CEEB), // スカイブルー
  })  : initialPosition = position.clone(),
        _size = Vector2(width / 2, height / 2),
        initialAngle = angle,
        _flipX = flipX,
        _flipY = flipY {
    _initSparkles();
  }

  /// キラキラを初期化
  void _initSparkles() {
    _sparkles.clear();
    final random = math.Random();
    final count = (_size.x * 2).floor().clamp(3, 8);
    for (int i = 0; i < count; i++) {
      _sparkles.add(_Sparkle(
        x: -_size.x + random.nextDouble() * _size.x * 2,
        y: -_size.y * 0.5 + random.nextDouble() * _size.y,
        size: 0.1 + random.nextDouble() * 0.15,
        phase: random.nextDouble() * math.pi * 2,
      ));
    }
  }

  /// JSONから生成
  factory IceFloor.fromJson(Map<String, dynamic> json) {
    return IceFloor(
      position: json.getVector2(),
      width: json.getDouble('width', defaultWidth),
      height: json.getDouble('height', defaultHeight),
      angle: json.getDouble('angle'),
      friction: json.getDouble('friction', defaultFriction),
      flipX: json.getBool('flipX'),
      flipY: json.getBool('flipY'),
      color: json.getColor('color', const Color(0xFF87CEEB)),
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'iceFloor';

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
      'friction': friction,
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
      _initSparkles();
    }
    if (props.containsKey('height')) {
      final newHeight = (props['height'] as num?)?.toDouble() ?? height;
      _size.y = newHeight / 2;
      _rebuildFixtures();
      _initSparkles();
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
      ..friction = friction
      ..restitution = PhysicsConfig.groundRestitution);
  }

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    final shape = PolygonShape()..setAsBoxXY(_size.x, _size.y);

    final fixtureDef = FixtureDef(shape)
      ..friction = friction // 非常に低い摩擦
      ..restitution = PhysicsConfig.groundRestitution;

    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition
      ..angle = initialAngle;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    // 反転のためのスケール
    canvas.save();
    canvas.scale(_flipX ? -1 : 1, _flipY ? -1 : 1);

    // 氷のグラデーション
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFE0FFFF), // ライトシアン
        color,
      ],
    );

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _size.x * 2,
      height: _size.y * 2,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.05)),
      paint,
    );

    // 枠線
    final borderPaint = Paint()
      ..color = const Color(0xFF5DADE2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.04;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.05)),
      borderPaint,
    );

    // キラキラを描画
    _drawSparkles(canvas);

    canvas.restore();

    // 選択中ならハイライト
    if (isSelected) {
      SelectionHighlight.draw(canvas, halfWidth: _size.x, halfHeight: _size.y);
    }
  }

  /// キラキラを描画
  void _drawSparkles(Canvas canvas) {
    final sparklePaint = Paint()..color = Colors.white;

    for (final sparkle in _sparkles) {
      // 点滅アニメーション
      final alpha = 0.4 + 0.6 * math.sin(_time * 3 + sparkle.phase).abs();
      sparklePaint.color = Colors.white.withValues(alpha: alpha);

      // ✦形状を描画
      final path = Path();
      final s = sparkle.size;
      path.moveTo(sparkle.x, sparkle.y - s);
      path.lineTo(sparkle.x + s * 0.3, sparkle.y);
      path.lineTo(sparkle.x, sparkle.y + s);
      path.lineTo(sparkle.x - s * 0.3, sparkle.y);
      path.close();

      path.moveTo(sparkle.x - s, sparkle.y);
      path.lineTo(sparkle.x, sparkle.y + s * 0.3);
      path.lineTo(sparkle.x + s, sparkle.y);
      path.lineTo(sparkle.x, sparkle.y - s * 0.3);
      path.close();

      canvas.drawPath(path, sparklePaint);
    }
  }
}

/// キラキラのデータ
class _Sparkle {
  final double x;
  final double y;
  final double size;
  final double phase;

  _Sparkle({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });
}

/// IceFloorをファクトリに登録
void registerIceFloorFactory() {
  StageObjectFactory.register('iceFloor', (json) => IceFloor.fromJson(json));
}
