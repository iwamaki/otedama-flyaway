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

  /// このゾーンに遷移してきた場合のリスポーン位置
  /// respawnSideが指定されている場合はゾーン位置から自動計算
  /// respawnX/Yが指定されている場合はそちらを優先
  double? respawnX;
  double? respawnY;

  /// リスポーン位置の方向（"left" または "right"）
  /// 指定するとゾーンの左右にオフセットした位置を自動計算
  String? respawnSide;

  /// リスポーン位置のオフセット距離
  static const double _respawnOffset = 3.0;

  /// 計算されたリスポーン位置を取得
  (double x, double y)? get respawnPosition {
    // 明示的な座標指定がある場合はそちらを優先
    if (respawnX != null && respawnY != null) {
      return (respawnX!, respawnY!);
    }
    // respawnSideが指定されている場合は自動計算
    if (respawnSide != null) {
      final zoneX = body.position.x;
      final zoneY = body.position.y;
      if (respawnSide == 'left') {
        return (zoneX - _width / 2 - _respawnOffset, zoneY);
      } else if (respawnSide == 'right') {
        return (zoneX + _width / 2 + _respawnOffset, zoneY);
      }
    }
    return null;
  }

  /// このゾーンの一意のID
  String id;

  /// 遷移先ゾーンのID（このIDを持つゾーンの位置にスポーンする）
  String? targetZoneId;

  /// ライン判定モード（true: 線で判定、false: 面で判定）
  bool isLine;

  /// ゾーンの色（idから自動生成）
  Color get color => _colorFromId(id);

  /// サイズ変更可能
  @override
  bool get canResize => true;

  /// 一意のIDを生成
  static String generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(0xFFFF);
    return '${now.toRadixString(36)}_${random.toRadixString(36)}';
  }

  /// idから一貫した色を生成
  static Color _colorFromId(String id) {
    // idのハッシュ値を計算
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = id.codeUnitAt(i) + ((hash << 5) - hash);
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
    this.respawnX,
    this.respawnY,
    this.respawnSide,
    String? id,
    this.targetZoneId,
    this.isLine = false,
  })  : initialPosition = position.clone(),
        _width = width,
        _height = height,
        initialAngle = angle,
        id = id ?? generateId();

  /// JSONから生成
  factory TransitionZone.fromJson(Map<String, dynamic> json) {
    return TransitionZone(
      position: json.getVector2(),
      width: json.getDouble('width', 5.0),
      height: json.getDouble('height', 5.0),
      angle: json.getDouble('angle'),
      nextStage: json['nextStage'] as String? ?? '',
      respawnX: (json['respawnX'] as num?)?.toDouble(),
      respawnY: (json['respawnY'] as num?)?.toDouble(),
      respawnSide: json['respawnSide'] as String?,
      id: json['id'] as String?,
      targetZoneId: json['targetZoneId'] as String?,
      isLine: json['isLine'] as bool? ?? false,
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
      if (respawnX != null) 'respawnX': respawnX,
      if (respawnY != null) 'respawnY': respawnY,
      if (respawnSide != null) 'respawnSide': respawnSide,
      'id': id,
      if (targetZoneId != null) 'targetZoneId': targetZoneId,
      'isLine': isLine,
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
    if (props.containsKey('respawnX')) {
      respawnX = (props['respawnX'] as num?)?.toDouble();
    }
    if (props.containsKey('respawnY')) {
      respawnY = (props['respawnY'] as num?)?.toDouble();
    }
    if (props.containsKey('respawnSide')) {
      respawnSide = props['respawnSide'] as String?;
    }
    if (props.containsKey('id')) {
      id = props['id'] as String? ?? id;
    }
    if (props.containsKey('targetZoneId')) {
      targetZoneId = props['targetZoneId'] as String?;
    }
    if (props.containsKey('isLine')) {
      isLine = props['isLine'] as bool? ?? false;
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
    // ライン判定モードの場合は物理コンタクトによる遷移を無効化
    // （checkTransitionZones()のライン通過判定に任せる）
    if (isLine) return;

    final fixtureA = contact.fixtureA;
    final fixtureB = contact.fixtureB;

    logger.debug(LogCategory.game,
        'TransitionZone.beginContact: fixtureA=${fixtureA.userData}, fixtureB=${fixtureB.userData}, nextStage=$nextStage');

    final isTransitionZone = fixtureA.userData == 'transition_zone' ||
        fixtureB.userData == 'transition_zone';

    if (isTransitionZone && nextStage.isNotEmpty) {
      logger.info(LogCategory.game,
          'TransitionZone triggering: nextStage=$nextStage, id=$id, targetZoneId=$targetZoneId');
      // 遷移を発動（自分自身を渡して、速度情報を取得できるようにする）
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

    if (isLine) {
      // ライン判定モード：水平線として描画
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.2;
      canvas.drawLine(
        Offset(-halfWidth, 0),
        Offset(halfWidth, 0),
        linePaint,
      );

      // 破線風の装飾（視認性向上）
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1;
      const dashLength = 1.0;
      const gapLength = 0.5;
      double x = -halfWidth;
      while (x < halfWidth) {
        canvas.drawLine(
          Offset(x, -0.3),
          Offset(x, 0.3),
          dashPaint,
        );
        x += dashLength + gapLength;
      }

      // 矢印アイコン（遷移を示す）
      _drawTransitionIcon(canvas);

      // 選択中ならハイライト
      if (isSelected) {
        SelectionHighlight.draw(canvas, halfWidth: halfWidth, halfHeight: 0.5);
      }
    } else {
      // 面判定モード：矩形として描画（従来の動作）
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
