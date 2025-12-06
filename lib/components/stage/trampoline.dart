import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../game/otedama_game.dart';
import '../../services/logger_service.dart';
import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';

/// トランポリンの状態
enum _TrampolineState {
  idle, // 待機中
  launching, // 上に飛び出し中
  returning, // 元の位置に戻り中
}

/// トランポリンコンポーネント
/// 接触したら上に弾いてお手玉を飛ばす
class Trampoline extends BodyComponent with StageObject {
  /// デフォルト値
  static const double defaultWidth = 8.0;
  static const double defaultHeight = 0.4;
  static const double defaultBounceForce = 120.0;

  /// 初期位置
  final Vector2 initialPosition;

  /// サイズ（幅、高さの半分）
  final Vector2 size;

  /// 初期角度（ラジアン）
  final double initialAngle;

  /// 弾く力
  final double bounceForce;

  /// 色
  final Color color;

  /// 弾む面のボディ（kinematic）
  Body? _surfaceBody;

  /// 静止位置
  Vector2? _surfaceRestPosition;

  /// 飛び出し状態
  _TrampolineState _state = _TrampolineState.idle;

  /// 飛び出し距離（長くして勢いをつける）
  static const double _launchDistance = 1.2;

  /// 戻り速度（下向き）
  static const double _returnSpeed = 3.0;

  Trampoline({
    required Vector2 position,
    double width = defaultWidth,
    double height = defaultHeight,
    double angle = 0.0,
    this.bounceForce = defaultBounceForce,
    this.color = const Color(0xFFE74C3C),
  })  : initialPosition = position.clone(),
        size = Vector2(width / 2, height / 2),
        initialAngle = angle;

  /// JSONから生成
  factory Trampoline.fromJson(Map<String, dynamic> json) {
    return Trampoline(
      position: json.getVector2(),
      width: json.getDouble('width', defaultWidth),
      height: json.getDouble('height', defaultHeight),
      angle: json.getDouble('angle'),
      bounceForce: json.getDouble('bounceForce', defaultBounceForce),
      color: json.getColor('color', const Color(0xFFE74C3C)),
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'trampoline';

  @override
  Vector2 get position => body.position;

  @override
  double get angle => body.angle;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final pos = body.position;
    return (
      Vector2(pos.x - size.x, pos.y - size.y - 0.5),
      Vector2(pos.x + size.x, pos.y + size.y + 0.3),
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
      'bounceForce': bounceForce,
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
      // 表面ボディも移動
      _surfaceBody?.setTransform(
        Vector2(newX, newY - _springRestLength),
        body.angle,
      );
    }
    if (props.containsKey('angle')) {
      final newAngle = (props['angle'] as num?)?.toDouble() ?? 0.0;
      body.setTransform(body.position, newAngle);
    }
  }

  /// バネの静止長
  double get _springRestLength => 0.4;

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    // ベース部分（static、見えない土台）
    final baseShape = PolygonShape()..setAsBoxXY(size.x, 0.1);
    final baseDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition
      ..angle = initialAngle;

    final baseBody = world.createBody(baseDef);
    baseBody.createFixture(FixtureDef(baseShape)
      ..friction = 0.5
      ..restitution = 0.0);

    return baseBody;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _createSurfaceBody();
  }

  /// 弾む表面ボディを作成
  void _createSurfaceBody() {
    logger.debug(LogCategory.physics,
        'Trampoline._createSurfaceBody: initialPosition=$initialPosition, initialAngle=$initialAngle');

    // 表面の位置（ベースの上）
    final cos = math.cos(initialAngle);
    final sin = math.sin(initialAngle);
    final offsetY = -_springRestLength;
    _surfaceRestPosition = Vector2(
      initialPosition.x - sin * offsetY,
      initialPosition.y + cos * offsetY,
    );

    logger.debug(LogCategory.physics,
        'Trampoline: surfaceRestPosition=$_surfaceRestPosition');

    // 弾む面（kinematic - プログラムで位置制御）
    final surfaceShape = PolygonShape()..setAsBoxXY(size.x, size.y);
    final surfaceDef = BodyDef()
      ..type = BodyType.kinematic
      ..position = _surfaceRestPosition!.clone()
      ..angle = initialAngle;

    _surfaceBody = world.createBody(surfaceDef);
    _surfaceBody!.createFixture(FixtureDef(surfaceShape)
      ..friction = 0.3 // 滑りやすく
      ..restitution = 1.2); // 強い反発

    _surfaceBody!.userData = this;

    logger.info(LogCategory.physics,
        'Trampoline: created _surfaceBody=$_surfaceBody at pos=${_surfaceBody!.position}');
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_surfaceBody == null) return;

    // ベースの現在位置から静止位置を再計算（エディタでの移動に追従）
    final cos = math.cos(body.angle);
    final sin = math.sin(body.angle);
    final offsetY = -_springRestLength;
    _surfaceRestPosition = Vector2(
      body.position.x - sin * offsetY,
      body.position.y + cos * offsetY,
    );

    // 上方向ベクトル
    final upDir = Vector2(-sin, -cos);

    // 状態に応じた処理
    switch (_state) {
      case _TrampolineState.idle:
        // 静止位置に固定
        _surfaceBody!.setTransform(_surfaceRestPosition!, body.angle);
        _surfaceBody!.linearVelocity = Vector2.zero();

        // お手玉との接触をチェック
        if (_checkContactWithOtedama()) {
          _state = _TrampolineState.launching;
          logger.info(LogCategory.physics, 'Trampoline: launch triggered!');
        }

      case _TrampolineState.launching:
        // 上に飛び出し中: 速度で移動（物理的に押す）
        // bounceForce を速度として使う（すり抜け防止で上限あり）
        final launchSpeed = (bounceForce / 6).clamp(10.0, 25.0);
        _surfaceBody!.linearVelocity = upDir * launchSpeed;

        // 最大距離に達したら戻りフェーズへ
        final currentOffset = _surfaceBody!.position - _surfaceRestPosition!;
        final distance = currentOffset.dot(upDir);
        if (distance >= _launchDistance) {
          _state = _TrampolineState.returning;
          logger.debug(LogCategory.physics, 'Trampoline: switching to returning');
        }

      case _TrampolineState.returning:
        // 元の位置に戻り中
        _surfaceBody!.linearVelocity = upDir * -_returnSpeed;

        // 元の位置に戻ったら終了
        final currentOffset = _surfaceBody!.position - _surfaceRestPosition!;
        final distance = currentOffset.dot(upDir);
        if (distance <= 0) {
          _state = _TrampolineState.idle;
          _surfaceBody!.setTransform(_surfaceRestPosition!, body.angle);
          _surfaceBody!.linearVelocity = Vector2.zero();
          logger.debug(LogCategory.physics, 'Trampoline: back to idle');
        }
    }
  }

  /// お手玉との接触をチェック（AABBオーバーラップ）
  bool _checkContactWithOtedama() {
    final otedamaGame = game as OtedamaGame?;
    final otedama = otedamaGame?.otedama;
    if (otedama == null) return false;

    // 表面のAABB
    final surfacePos = _surfaceBody!.position;
    final surfaceMinX = surfacePos.x - size.x;
    final surfaceMaxX = surfacePos.x + size.x;
    final surfaceMinY = surfacePos.y - size.y;
    final surfaceMaxY = surfacePos.y + size.y;

    // お手玉の全ボディをチェック
    final allBodies = [...otedama.shellBodies, ...otedama.beadBodies];
    for (final otedamaBody in allBodies) {
      final pos = otedamaBody.position;
      const radius = 0.3;

      if (pos.x + radius > surfaceMinX &&
          pos.x - radius < surfaceMaxX &&
          pos.y + radius > surfaceMinY &&
          pos.y - radius < surfaceMaxY) {
        return true;
      }
    }
    return false;
  }

  @override
  void onRemove() {
    // 表面ボディを削除
    if (_surfaceBody != null) {
      world.destroyBody(_surfaceBody!);
      _surfaceBody = null;
    }

    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    // ベース（土台）は見えない形で描画をスキップ

    // 選択中ならハイライト
    if (isSelected) {
      SelectionHighlight.draw(
        canvas,
        halfWidth: size.x,
        halfHeight: size.y + _springRestLength,
      );
    }
  }

  @override
  void renderTree(Canvas canvas) {
    // 表面ボディの位置に基づいて描画
    if (_surfaceBody == null) {
      super.renderTree(canvas);
      return;
    }

    // 脚を描画（ベースから表面へ）
    _drawLegs(canvas);

    // 表面を描画
    canvas.save();
    final pos = _surfaceBody!.position;
    canvas.translate(pos.x, pos.y);
    canvas.rotate(_surfaceBody!.angle);

    // トランポリンの弾む面
    final surfacePaint = Paint()..color = color;
    final surfaceRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x * 2,
      height: size.y * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(surfaceRect, const Radius.circular(0.1)),
      surfacePaint,
    );

    // 上面のハイライト
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;
    canvas.drawLine(
      Offset(-size.x + 0.1, -size.y + 0.05),
      Offset(size.x - 0.1, -size.y + 0.05),
      highlightPaint,
    );

    canvas.restore();

    // 選択ハイライト
    if (isSelected) {
      canvas.save();
      canvas.translate(body.position.x, body.position.y - _springRestLength / 2);
      canvas.rotate(body.angle);
      SelectionHighlight.draw(
        canvas,
        halfWidth: size.x,
        halfHeight: size.y + _springRestLength,
      );
      canvas.restore();
    }
  }

  /// 脚を描画（ベースから表面への支柱）
  void _drawLegs(Canvas canvas) {
    if (_surfaceBody == null) return;

    final legPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.15;

    final basePos = body.position;
    final surfacePos = _surfaceBody!.position;
    final cos = math.cos(body.angle);
    final sin = math.sin(body.angle);

    // 左右の脚
    for (final xOffset in [-size.x + 0.3, size.x - 0.3]) {
      final basePoint = Offset(
        basePos.x + xOffset * cos,
        basePos.y + xOffset * sin,
      );
      final surfacePoint = Offset(
        surfacePos.x + xOffset * cos,
        surfacePos.y + xOffset * sin + size.y,
      );
      canvas.drawLine(basePoint, surfacePoint, legPaint);
    }
  }
}

/// Trampolineをファクトリに登録
void registerTrampolineFactory() {
  StageObjectFactory.register('trampoline', (json) => Trampoline.fromJson(json));
}
