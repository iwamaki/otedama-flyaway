import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../config/physics_config.dart';
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
  static const double defaultWidth = 6.0;
  static const double defaultHeight = 0.4;
  static const double defaultBounceForce = 120.0;

  /// 初期位置
  final Vector2 initialPosition;

  /// サイズ（幅、高さの半分）
  Vector2 _size;

  /// 初期角度（ラジアン）
  final double initialAngle;

  /// 弾く力
  final double bounceForce;

  /// 水平反転
  bool _flipX;

  /// 垂直反転
  bool _flipY;

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
    bool flipX = false,
    bool flipY = false,
    this.color = const Color(0xFFE74C3C),
  })  : initialPosition = position.clone(),
        _size = Vector2(width / 2, height / 2),
        initialAngle = angle,
        _flipX = flipX,
        _flipY = flipY;

  /// JSONから生成
  factory Trampoline.fromJson(Map<String, dynamic> json) {
    return Trampoline(
      position: json.getVector2(),
      width: json.getDouble('width', defaultWidth),
      height: json.getDouble('height', defaultHeight),
      angle: json.getDouble('angle'),
      bounceForce: json.getDouble('bounceForce', defaultBounceForce),
      flipX: json.getBool('flipX'),
      flipY: json.getBool('flipY'),
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
      Vector2(pos.x - _size.x, pos.y - _size.y - 0.5),
      Vector2(pos.x + _size.x, pos.y + _size.y + 0.3),
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
      'bounceForce': bounceForce,
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

    // ベースボディのフィクスチャを再構築
    while (body.fixtures.isNotEmpty) {
      body.destroyFixture(body.fixtures.first);
    }
    final baseShape = PolygonShape()..setAsBoxXY(_size.x, 0.1);
    body.createFixture(FixtureDef(baseShape)
      ..friction = 0.5
      ..restitution = 0.0);

    // 表面ボディのフィクスチャを再構築
    if (_surfaceBody != null) {
      while (_surfaceBody!.fixtures.isNotEmpty) {
        _surfaceBody!.destroyFixture(_surfaceBody!.fixtures.first);
      }
      final surfaceShape = PolygonShape()..setAsBoxXY(_size.x, _size.y);
      _surfaceBody!.createFixture(FixtureDef(surfaceShape)
        ..friction = 0.3
        ..restitution = PhysicsConfig.groundRestitution);
    }
  }

  /// バネの静止長
  double get _springRestLength => 1.0;

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    // ベース部分（static、見えない土台）
    final baseShape = PolygonShape()..setAsBoxXY(_size.x, 0.1);
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
    final surfaceShape = PolygonShape()..setAsBoxXY(_size.x, _size.y);
    final surfaceDef = BodyDef()
      ..type = BodyType.kinematic
      ..position = _surfaceRestPosition!.clone()
      ..angle = initialAngle;

    _surfaceBody = world.createBody(surfaceDef);
    _surfaceBody!.createFixture(FixtureDef(surfaceShape)
      ..friction = 0.3
      ..restitution = PhysicsConfig.groundRestitution);

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
    final surfaceMinX = surfacePos.x - _size.x;
    final surfaceMaxX = surfacePos.x + _size.x;
    final surfaceMinY = surfacePos.y - _size.y;
    final surfaceMaxY = surfacePos.y + _size.y;

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
        halfWidth: _size.x,
        halfHeight: _size.y + _springRestLength,
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

    // 反転のためのスケール
    canvas.scale(_flipX ? -1 : 1, _flipY ? -1 : 1);

    // トランポリンの弾む面
    final surfacePaint = Paint()..color = color;
    final surfaceRect = Rect.fromCenter(
      center: Offset.zero,
      width: _size.x * 2,
      height: _size.y * 2,
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
      Offset(-_size.x + 0.1, -_size.y + 0.05),
      Offset(_size.x - 0.1, -_size.y + 0.05),
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
        halfWidth: _size.x,
        halfHeight: _size.y + _springRestLength,
      );
      canvas.restore();
    }
  }

  /// ばね形状の支柱を描画
  void _drawLegs(Canvas canvas) {
    if (_surfaceBody == null) return;

    final springPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12
      ..strokeCap = StrokeCap.round;

    final basePos = body.position;
    final surfacePos = _surfaceBody!.position;
    final cos = math.cos(body.angle);
    final sin = math.sin(body.angle);

    // 左右のばね
    for (final xOffset in [-_size.x + 0.5, _size.x - 0.5]) {
      final basePoint = Offset(
        basePos.x + xOffset * cos,
        basePos.y + xOffset * sin,
      );
      final surfacePoint = Offset(
        surfacePos.x + xOffset * cos,
        surfacePos.y + xOffset * sin + _size.y,
      );

      // ばねのジグザグを描画
      _drawSpring(canvas, basePoint, surfacePoint, springPaint);
    }
  }

  /// ばね（ジグザグ）を描画
  void _drawSpring(Canvas canvas, Offset start, Offset end, Paint paint) {
    const int coils = 3; // コイルの数
    const double amplitude = 0.3; // ジグザグの振幅

    final direction = end - start;
    final length = direction.distance;
    if (length < 0.01) return;

    final normalized = direction / length;
    // 垂直方向（ジグザグの横方向）
    final perpendicular = Offset(-normalized.dy, normalized.dx);

    final path = Path();
    path.moveTo(start.dx, start.dy);

    // コイル部分
    final coilStart = 0.05; // 最初のストレート部分
    final coilEnd = 0.95; // 最後のストレート部分
    final coilLength = coilEnd - coilStart;

    for (int i = 0; i <= coils * 2; i++) {
      final t = coilStart + (i / (coils * 2)) * coilLength;
      final point = start + direction * t;
      // 奇数で右、偶数で左にずらす
      final offset = (i % 2 == 1 ? 1 : -1) * amplitude;
      final zigzagPoint = point + perpendicular * offset;
      path.lineTo(zigzagPoint.dx, zigzagPoint.dy);
    }

    path.lineTo(end.dx, end.dy);
    canvas.drawPath(path, paint);
  }
}

/// Trampolineをファクトリに登録
void registerTrampolineFactory() {
  StageObjectFactory.register('trampoline', (json) => Trampoline.fromJson(json));
}
