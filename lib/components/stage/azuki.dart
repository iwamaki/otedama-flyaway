import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../game/otedama_game.dart';
import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';

/// 小豆（あずき）コレクタブル
/// お手玉が触れるとビーズが1つ追加される
class Azuki extends BodyComponent with StageObject {
  /// ゲーム参照を取得
  OtedamaGame get otedamaGame => game as OtedamaGame;

  /// 初期位置
  final Vector2 initialPosition;

  /// 小豆の半径
  final double radius;

  /// 小豆の色
  final Color color;

  /// 収集済みかどうか
  bool _isCollected = false;
  bool get isCollected => _isCollected;

  Azuki({
    required Vector2 position,
    this.radius = 0.4,
    this.color = const Color(0xFF8B0000), // 暗い赤（小豆色）
  }) : initialPosition = position.clone();

  /// JSONから生成
  factory Azuki.fromJson(Map<String, dynamic> json) {
    return Azuki(
      position: json.getVector2(),
      radius: json.getDouble('radius', 0.4),
      color: json.getColor('color', const Color(0xFF8B0000)),
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'azuki';

  @override
  Vector2 get position => body.position;

  @override
  double get angle => body.angle;

  @override
  double get width => radius * 2;

  @override
  double get height => radius * 2;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final pos = body.position;
    return (
      Vector2(pos.x - radius, pos.y - radius),
      Vector2(pos.x + radius, pos.y + radius),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': position.x,
      'y': position.y,
      'radius': radius,
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
  }

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition;

    final body = world.createBody(bodyDef);

    // センサーのみ（物理衝突なし）
    final shape = CircleShape()..radius = radius;
    body.createFixture(FixtureDef(shape)..isSensor = true);

    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isCollected) return;

    // お手玉との接触をチェック
    if (_checkContactWithOtedama()) {
      _collect();
    }
  }

  /// お手玉との接触をチェック（AABBオーバーラップ）
  bool _checkContactWithOtedama() {
    final otedama = otedamaGame.otedama;
    if (otedama == null) return false;

    final myPos = body.position;

    // お手玉の全ボディをチェック
    final allBodies = [...otedama.shellBodies, ...otedama.beadBodies];
    for (final otedamaBody in allBodies) {
      final pos = otedamaBody.position;
      final dx = pos.x - myPos.x;
      final dy = pos.y - myPos.y;
      final distSq = dx * dx + dy * dy;
      final touchRadius = radius + 0.3; // お手玉粒子の半径を加算

      if (distSq < touchRadius * touchRadius) {
        return true;
      }
    }
    return false;
  }

  void _collect() {
    _isCollected = true;

    // お手玉にビーズを追加
    otedamaGame.otedama?.addBead();

    // 自身を削除
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_isCollected) return;

    // 小豆本体
    final paint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius * 1.4, // 楕円形（小豆っぽく）
      ),
      paint,
    );

    // ハイライト
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-radius * 0.2, -radius * 0.2),
        width: radius * 0.6,
        height: radius * 0.4,
      ),
      highlightPaint,
    );

    // 選択中ならハイライト
    if (isSelected) {
      SelectionHighlight.draw(canvas, halfWidth: radius, halfHeight: radius);
    }
  }
}

/// Azukiをファクトリに登録
void registerAzukiFactory() {
  StageObjectFactory.register('azuki', (json) => Azuki.fromJson(json));
}
