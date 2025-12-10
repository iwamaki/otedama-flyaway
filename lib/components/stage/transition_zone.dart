import 'dart:math';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../game/otedama_game.dart';
import '../../services/logger_service.dart';
import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';

/// 遷移ゾーンコンポーネント
/// お手玉が入ったら次ステージへ遷移する
class TransitionZone extends BodyComponent with StageObject, ContactCallbacks {
  /// ゲーム参照を取得
  OtedamaGame get otedamaGame => game as OtedamaGame;

  /// 初期位置
  final Vector2 initialPosition;

  /// ゾーンのサイズ
  double _width;
  double _height;

  @override
  double get width => _width;

  @override
  double get height => _height;

  /// 初期角度
  final double initialAngle;

  /// 次ステージのアセットパス
  String nextStage;

  /// 遷移先でのスポーン位置（nullの場合はステージのデフォルトを使用）
  double? spawnX;
  double? spawnY;

  /// このゾーンに遷移してきた場合のリスポーン位置（nullの場合はゾーン位置を使用）
  double? respawnX;
  double? respawnY;

  /// リンクID（ペアの遷移ゾーンを識別するための一意のID）
  String linkId;

  /// ゾーンの色（linkIdから自動生成）
  Color get color => _colorFromLinkId(linkId);

  /// サイズ変更可能
  @override
  bool get canResize => true;

  /// 一意のリンクIDを生成
  static String generateLinkId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(0xFFFF);
    return '${now.toRadixString(36)}_${random.toRadixString(36)}';
  }

  /// linkIdから一貫した色を生成
  static Color _colorFromLinkId(String linkId) {
    // linkIdのハッシュ値を計算
    int hash = 0;
    for (int i = 0; i < linkId.length; i++) {
      hash = linkId.codeUnitAt(i) + ((hash << 5) - hash);
    }
    // HSLで鮮やかな色を生成（色相のみ変更、彩度と輝度は固定）
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  TransitionZone({
    required Vector2 position,
    double width = 5.0,
    double height = 5.0,
    double angle = 0.0,
    this.nextStage = '',
    this.spawnX,
    this.spawnY,
    this.respawnX,
    this.respawnY,
    String? linkId,
  })  : initialPosition = position.clone(),
        _width = width,
        _height = height,
        initialAngle = angle,
        linkId = linkId ?? generateLinkId();

  /// JSONから生成
  factory TransitionZone.fromJson(Map<String, dynamic> json) {
    return TransitionZone(
      position: json.getVector2(),
      width: json.getDouble('width', 5.0),
      height: json.getDouble('height', 5.0),
      angle: json.getDouble('angle'),
      nextStage: json['nextStage'] as String? ?? '',
      spawnX: (json['spawnX'] as num?)?.toDouble(),
      spawnY: (json['spawnY'] as num?)?.toDouble(),
      respawnX: (json['respawnX'] as num?)?.toDouble(),
      respawnY: (json['respawnY'] as num?)?.toDouble(),
      linkId: json['linkId'] as String?,
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'transitionZone';

  @override
  Vector2 get position => body.position;

  @override
  double get angle => body.angle;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final halfW = _width / 2;
    final halfH = _height / 2;
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
      'width': _width,
      'height': _height,
      'angle': angle,
      'nextStage': nextStage,
      if (spawnX != null) 'spawnX': spawnX,
      if (spawnY != null) 'spawnY': spawnY,
      if (respawnX != null) 'respawnX': respawnX,
      if (respawnY != null) 'respawnY': respawnY,
      'linkId': linkId,
    };
  }

  @override
  void applyProperties(Map<String, dynamic> props) {
    bool positionChanged = false;

    if (props.containsKey('x') || props.containsKey('y')) {
      final newX = (props['x'] as num?)?.toDouble() ?? position.x;
      final newY = (props['y'] as num?)?.toDouble() ?? position.y;
      body.setTransform(Vector2(newX, newY), body.angle);
      positionChanged = true;
    }
    if (props.containsKey('angle')) {
      final newAngle = (props['angle'] as num?)?.toDouble() ?? 0.0;
      body.setTransform(body.position, newAngle);
    }
    if (props.containsKey('width')) {
      _width = (props['width'] as num?)?.toDouble() ?? _width;
      _rebuildFixtures();
    }
    if (props.containsKey('height')) {
      _height = (props['height'] as num?)?.toDouble() ?? _height;
      _rebuildFixtures();
    }
    if (props.containsKey('nextStage')) {
      nextStage = props['nextStage'] as String? ?? '';
    }
    if (props.containsKey('spawnX')) {
      spawnX = (props['spawnX'] as num?)?.toDouble();
    }
    if (props.containsKey('spawnY')) {
      spawnY = (props['spawnY'] as num?)?.toDouble();
    }
    if (props.containsKey('respawnX')) {
      respawnX = (props['respawnX'] as num?)?.toDouble();
    }
    if (props.containsKey('respawnY')) {
      respawnY = (props['respawnY'] as num?)?.toDouble();
    }
    if (props.containsKey('linkId')) {
      linkId = props['linkId'] as String? ?? linkId;
    }

    // 位置が変更された場合、ペアゾーンの spawnX/Y を自動同期
    if (positionChanged && isMounted && linkId.isNotEmpty) {
      otedamaGame.syncTransitionZonePair(this);
    }
  }

  void _rebuildFixtures() {
    // 既存のフィクスチャを削除
    while (body.fixtures.isNotEmpty) {
      body.destroyFixture(body.fixtures.first);
    }

    // 新しいフィクスチャを作成
    final shape = PolygonShape()
      ..setAsBox(_width / 2, _height / 2, Vector2.zero(), 0);
    body.createFixture(FixtureDef(shape)
      ..isSensor = true
      ..userData = 'transition_zone');
  }

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition
      ..angle = initialAngle;

    final body = world.createBody(bodyDef);

    // センサーエリア（物理的な当たり判定なし）
    final shape = PolygonShape()
      ..setAsBox(_width / 2, _height / 2, Vector2.zero(), 0);
    body.createFixture(FixtureDef(shape)
      ..isSensor = true
      ..userData = 'transition_zone');

    return body;
  }

  @override
  void beginContact(Object other, Contact contact) {
    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    logger.debug(LogCategory.game,
        'TransitionZone.beginContact: fixtureA=${fixtureA.userData}, fixtureB=${fixtureB.userData}, nextStage=$nextStage');

    final isTransitionZone = fixtureA.userData == 'transition_zone' ||
        fixtureB.userData == 'transition_zone';

    if (isTransitionZone && nextStage.isNotEmpty) {
      logger.info(LogCategory.game,
          'TransitionZone triggering: nextStage=$nextStage, spawnX=$spawnX, spawnY=$spawnY');
      // 遷移を発動（自分自身を渡して、スポーン位置や速度情報を取得できるようにする）
      otedamaGame.triggerZoneTransitionCompat(this);
    } else {
      logger.debug(LogCategory.game,
          'TransitionZone NOT triggering: isTransitionZone=$isTransitionZone, nextStage.isEmpty=${nextStage.isEmpty}');
    }
  }

  @override
  void render(Canvas canvas) {
    final halfWidth = _width / 2;
    final halfHeight = _height / 2;

    // 半透明の背景
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(-halfWidth, -halfHeight, _width, _height),
      bgPaint,
    );

    // 枠線
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1;
    canvas.drawRect(
      Rect.fromLTWH(-halfWidth, -halfHeight, _width, _height),
      borderPaint,
    );

    // 矢印アイコン（遷移を示す）
    _drawTransitionIcon(canvas);

    // 選択中ならハイライト
    if (isSelected) {
      SelectionHighlight.draw(canvas, halfWidth: halfWidth, halfHeight: halfHeight);
    }
  }

  void _drawTransitionIcon(Canvas canvas) {
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.15
      ..strokeCap = StrokeCap.round;

    // 矢印を描画（→）
    const arrowSize = 1.0;
    const arrowHeadSize = 0.4;

    // 矢印の本体
    canvas.drawLine(
      const Offset(-arrowSize / 2, 0),
      const Offset(arrowSize / 2, 0),
      iconPaint,
    );

    // 矢印の頭
    canvas.drawLine(
      const Offset(arrowSize / 2 - arrowHeadSize, -arrowHeadSize),
      const Offset(arrowSize / 2, 0),
      iconPaint,
    );
    canvas.drawLine(
      const Offset(arrowSize / 2 - arrowHeadSize, arrowHeadSize),
      const Offset(arrowSize / 2, 0),
      iconPaint,
    );
  }
}

/// TransitionZoneをファクトリに登録
void registerTransitionZoneFactory() {
  StageObjectFactory.register(
      'transitionZone', (json) => TransitionZone.fromJson(json));
}
