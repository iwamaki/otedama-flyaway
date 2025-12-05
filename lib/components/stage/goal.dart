import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';

/// ゴール籠コンポーネント
/// お手玉が入る目標地点
class Goal extends BodyComponent with StageObject, ContactCallbacks {
  /// 初期位置
  final Vector2 initialPosition;

  /// 籠のサイズ
  final double width;
  final double height;
  final double wallThickness;

  /// 初期角度
  final double initialAngle;

  /// 籠の色
  final Color color;

  /// ゴール判定コールバック
  void Function()? onGoalReached;

  /// ゴールに入っているかどうか
  bool _isOtedamaInside = false;
  bool get isOtedamaInside => _isOtedamaInside;

  Goal({
    required Vector2 position,
    this.width = 4.0,
    this.height = 3.0,
    this.wallThickness = 0.3,
    double angle = 0.0,
    this.color = const Color(0xFF8B4513), // 茶色（竹籠風）
    this.onGoalReached,
  })  : initialPosition = position.clone(),
        initialAngle = angle;

  /// JSONから生成
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      position: json.getVector2(),
      width: json.getDouble('width', 4.0),
      height: json.getDouble('height', 3.0),
      angle: json.getDouble('angle'),
      color: json.getColor('color', const Color(0xFF8B4513)),
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'goal';

  @override
  Vector2 get position => body.position;

  @override
  double get angle => body.angle;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final halfW = width / 2;
    final halfH = height / 2;
    final pos = body.position;
    return (
      Vector2(pos.x - halfW, pos.y - halfH),
      Vector2(pos.x + halfW, pos.y + halfH),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': position.x,
      'y': position.y,
      'width': width,
      'height': height,
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
  }

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition
      ..angle = initialAngle;

    final body = world.createBody(bodyDef);

    final halfWidth = width / 2;
    final halfHeight = height / 2;
    final wallHalf = wallThickness / 2;

    // 底面
    final bottomShape = PolygonShape()
      ..setAsBox(
        halfWidth,
        wallHalf,
        Vector2(0, halfHeight - wallHalf),
        0,
      );
    body.createFixture(FixtureDef(bottomShape)
      ..friction = 0.8
      ..restitution = 0.1);

    // 左壁
    final leftShape = PolygonShape()
      ..setAsBox(
        wallHalf,
        halfHeight,
        Vector2(-halfWidth + wallHalf, 0),
        0,
      );
    body.createFixture(FixtureDef(leftShape)
      ..friction = 0.5
      ..restitution = 0.2);

    // 右壁
    final rightShape = PolygonShape()
      ..setAsBox(
        wallHalf,
        halfHeight,
        Vector2(halfWidth - wallHalf, 0),
        0,
      );
    body.createFixture(FixtureDef(rightShape)
      ..friction = 0.5
      ..restitution = 0.2);

    // センサーエリア（籠の内側、お手玉検知用）
    final sensorShape = PolygonShape()
      ..setAsBox(
        halfWidth - wallThickness,
        halfHeight - wallThickness,
        Vector2(0, wallHalf),
        0,
      );
    body.createFixture(FixtureDef(sensorShape)
      ..isSensor = true
      ..userData = 'goal_sensor');

    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    // センサーとの接触をチェック
    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    final isGoalSensor = fixtureA.userData == 'goal_sensor' ||
        fixtureB.userData == 'goal_sensor';

    if (isGoalSensor) {
      _isOtedamaInside = true;
      onGoalReached?.call();
    }
  }

  @override
  void endContact(Object other, Contact contact) {
    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    final isGoalSensor = fixtureA.userData == 'goal_sensor' ||
        fixtureB.userData == 'goal_sensor';

    if (isGoalSensor) {
      _isOtedamaInside = false;
    }
  }

  @override
  void render(Canvas canvas) {
    final halfWidth = width / 2;
    final halfHeight = height / 2;

    // 籠の本体色
    final paint = Paint()..color = color;

    // 底面
    canvas.drawRect(
      Rect.fromLTWH(
        -halfWidth,
        halfHeight - wallThickness,
        width,
        wallThickness,
      ),
      paint,
    );

    // 左壁
    canvas.drawRect(
      Rect.fromLTWH(
        -halfWidth,
        -halfHeight,
        wallThickness,
        height,
      ),
      paint,
    );

    // 右壁
    canvas.drawRect(
      Rect.fromLTWH(
        halfWidth - wallThickness,
        -halfHeight,
        wallThickness,
        height,
      ),
      paint,
    );

    // 竹籠風の編み目模様
    _drawBasketPattern(canvas, halfWidth, halfHeight);

    // ゴール中はハイライト
    if (_isOtedamaInside) {
      final highlightPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(
          -halfWidth + wallThickness,
          -halfHeight + wallThickness,
          width - wallThickness * 2,
          height - wallThickness * 2,
        ),
        highlightPaint,
      );
    }

    // 選択中ならハイライト
    if (isSelected) {
      SelectionHighlight.draw(canvas, halfWidth: halfWidth, halfHeight: halfHeight);
    }
  }

  void _drawBasketPattern(Canvas canvas, double halfWidth, double halfHeight) {
    final patternPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;

    // 横線（左壁）
    for (double y = -halfHeight + 0.5; y < halfHeight; y += 0.5) {
      canvas.drawLine(
        Offset(-halfWidth, y),
        Offset(-halfWidth + wallThickness, y),
        patternPaint,
      );
    }

    // 横線（右壁）
    for (double y = -halfHeight + 0.5; y < halfHeight; y += 0.5) {
      canvas.drawLine(
        Offset(halfWidth - wallThickness, y),
        Offset(halfWidth, y),
        patternPaint,
      );
    }

    // 横線（底面）
    for (double x = -halfWidth + 0.5; x < halfWidth; x += 0.5) {
      canvas.drawLine(
        Offset(x, halfHeight - wallThickness),
        Offset(x, halfHeight),
        patternPaint,
      );
    }
  }
}

/// Goalをファクトリに登録
void registerGoalFactory() {
  StageObjectFactory.register('goal', (json) => Goal.fromJson(json));
}
