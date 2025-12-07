import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../config/physics_config.dart';
import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';

/// 地形コンポーネント（ChainShape使用）
/// 地面、壁、天井などの大きな地形を表現
/// 頂点リストで自由な形状を定義可能
class Terrain extends BodyComponent with StageObject {
  /// 初期位置（頂点のオフセット基準点）
  final Vector2 initialPosition;

  /// 頂点リスト（ローカル座標）
  List<Vector2> _vertices;

  /// ループするかどうか（閉じた形状 vs 開いた線）
  final bool isLoop;

  /// 塗りつぶし色
  final Color fillColor;

  /// 輪郭色
  final Color strokeColor;

  /// 輪郭の太さ
  final double strokeWidth;

  Terrain({
    required Vector2 position,
    required List<Vector2> vertices,
    this.isLoop = true,
    this.fillColor = const Color(0xFF5D4037), // ブラウン
    this.strokeColor = const Color(0xFF3E2723), // ダークブラウン
    this.strokeWidth = 0.1,
  })  : initialPosition = position.clone(),
        _vertices = vertices.map((v) => v.clone()).toList();

  /// JSONから生成
  factory Terrain.fromJson(Map<String, dynamic> json) {
    final verticesList = json['vertices'] as List<dynamic>? ?? [];
    final vertices = <Vector2>[];

    for (final v in verticesList) {
      if (v is Map<String, dynamic>) {
        vertices.add(Vector2(
          (v['x'] as num?)?.toDouble() ?? 0.0,
          (v['y'] as num?)?.toDouble() ?? 0.0,
        ));
      }
    }

    // 頂点がない場合はデフォルトの四角形
    if (vertices.isEmpty) {
      vertices.addAll([
        Vector2(-10, -1),
        Vector2(10, -1),
        Vector2(10, 1),
        Vector2(-10, 1),
      ]);
    }

    return Terrain(
      position: json.getVector2(),
      vertices: vertices,
      isLoop: json.getBool('isLoop', true),
      fillColor: json.getColor('fillColor', const Color(0xFF5D4037)),
      strokeColor: json.getColor('strokeColor', const Color(0xFF3E2723)),
      strokeWidth: json.getDouble('strokeWidth', 0.1),
    );
  }

  /// 矩形の地形を簡単に作成
  factory Terrain.rectangle({
    required Vector2 position,
    required double width,
    required double height,
    Color fillColor = const Color(0xFF5D4037),
    Color strokeColor = const Color(0xFF3E2723),
  }) {
    final halfW = width / 2;
    final halfH = height / 2;
    return Terrain(
      position: position,
      vertices: [
        Vector2(-halfW, -halfH), // 左上
        Vector2(halfW, -halfH), // 右上
        Vector2(halfW, halfH), // 右下
        Vector2(-halfW, halfH), // 左下
      ],
      isLoop: true,
      fillColor: fillColor,
      strokeColor: strokeColor,
    );
  }

  /// 地面（横長）を簡単に作成
  factory Terrain.ground({
    required Vector2 position,
    double width = 50.0,
    double height = 5.0,
    Color fillColor = const Color(0xFF5D4037),
  }) {
    return Terrain.rectangle(
      position: position,
      width: width,
      height: height,
      fillColor: fillColor,
    );
  }

  /// 壁（縦長）を簡単に作成
  factory Terrain.wall({
    required Vector2 position,
    double width = 2.0,
    double height = 20.0,
    Color fillColor = const Color(0xFF757575),
  }) {
    return Terrain.rectangle(
      position: position,
      width: width,
      height: height,
      fillColor: fillColor,
      strokeColor: const Color(0xFF424242),
    );
  }

  // --- StageObject 実装 ---

  @override
  String get type => 'terrain';

  @override
  Vector2 get position => body.position;

  @override
  double get angle => body.angle;

  @override
  double? get width => _calculateBoundsSize().x;

  @override
  double? get height => _calculateBoundsSize().y;

  @override
  bool get canResize => false; // 頂点編集で対応

  @override
  bool get canFlip => false;

  /// 頂点リストを取得
  List<Vector2> get vertices => _vertices;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final pos = body.position;
    final size = _calculateBoundsSize();
    final halfSize = size / 2;
    return (
      Vector2(pos.x - halfSize.x, pos.y - halfSize.y),
      Vector2(pos.x + halfSize.x, pos.y + halfSize.y),
    );
  }

  Vector2 _calculateBoundsSize() {
    if (_vertices.isEmpty) return Vector2.zero();

    double minX = _vertices[0].x;
    double maxX = _vertices[0].x;
    double minY = _vertices[0].y;
    double maxY = _vertices[0].y;

    for (final v in _vertices) {
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
    }

    return Vector2(maxX - minX, maxY - minY);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': position.x,
      'y': position.y,
      'vertices': _vertices.map((v) => {'x': v.x, 'y': v.y}).toList(),
      'isLoop': isLoop,
      // ignore: deprecated_member_use
      'fillColor': fillColor.value,
      // ignore: deprecated_member_use
      'strokeColor': strokeColor.value,
      'strokeWidth': strokeWidth,
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
    if (props.containsKey('vertices')) {
      final verticesList = props['vertices'] as List<dynamic>? ?? [];
      _vertices = [];
      for (final v in verticesList) {
        if (v is Map<String, dynamic>) {
          _vertices.add(Vector2(
            (v['x'] as num?)?.toDouble() ?? 0.0,
            (v['y'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }
      _rebuildFixtures();
    }
  }

  /// 頂点を追加
  void addVertex(Vector2 vertex) {
    _vertices.add(vertex.clone());
    _rebuildFixtures();
  }

  /// 頂点を更新
  void updateVertex(int index, Vector2 newPosition) {
    if (index >= 0 && index < _vertices.length) {
      _vertices[index] = newPosition.clone();
      _rebuildFixtures();
    }
  }

  /// 頂点を削除
  void removeVertex(int index) {
    if (index >= 0 && index < _vertices.length && _vertices.length > 3) {
      _vertices.removeAt(index);
      _rebuildFixtures();
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
    if (_vertices.length < 2) return;

    final chain = ChainShape();

    if (isLoop) {
      chain.createLoop(_vertices);
    } else {
      chain.createChain(_vertices);
    }

    body.createFixture(FixtureDef(chain)
      ..friction = PhysicsConfig.terrainFriction
      ..restitution = PhysicsConfig.terrainRestitution);
  }

  // --- BodyComponent 実装 ---

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition;

    final body = world.createBody(bodyDef);

    if (_vertices.length >= 2) {
      final chain = ChainShape();

      if (isLoop) {
        chain.createLoop(_vertices);
      } else {
        chain.createChain(_vertices);
      }

      body.createFixture(FixtureDef(chain)
        ..friction = PhysicsConfig.terrainFriction
        ..restitution = PhysicsConfig.terrainRestitution);
    }

    return body;
  }

  @override
  void render(Canvas canvas) {
    if (_vertices.isEmpty) return;

    // 塗りつぶし（ループの場合のみ）
    if (isLoop && _vertices.length >= 3) {
      final fillPath = Path();
      fillPath.moveTo(_vertices[0].x, _vertices[0].y);
      for (int i = 1; i < _vertices.length; i++) {
        fillPath.lineTo(_vertices[i].x, _vertices[i].y);
      }
      fillPath.close();

      // グラデーション塗りつぶし
      final bounds = fillPath.getBounds();
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor,
          Color.lerp(fillColor, Colors.black, 0.3)!,
        ],
      );

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = gradient.createShader(bounds)
          ..style = PaintingStyle.fill,
      );

      // テクスチャパターン（土・岩風）
      _drawTerrainTexture(canvas, fillPath);
    }

    // 輪郭線
    final strokePath = Path();
    strokePath.moveTo(_vertices[0].x, _vertices[0].y);
    for (int i = 1; i < _vertices.length; i++) {
      strokePath.lineTo(_vertices[i].x, _vertices[i].y);
    }
    if (isLoop) {
      strokePath.close();
    }

    canvas.drawPath(
      strokePath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 上面のハイライト（地面っぽく見せる）
    if (isLoop && _vertices.length >= 2) {
      _drawTopHighlight(canvas);
    }

    // 選択中ならハイライト
    if (isSelected) {
      final size = _calculateBoundsSize();
      SelectionHighlight.draw(
        canvas,
        halfWidth: size.x / 2,
        halfHeight: size.y / 2,
      );
    }
  }

  void _drawTerrainTexture(Canvas canvas, Path clipPath) {
    canvas.save();
    canvas.clipPath(clipPath);

    final texturePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // ランダムな点々でテクスチャ表現
    final bounds = clipPath.getBounds();
    final random = 12345; // 固定シードで再現性確保
    var seed = random;

    for (int i = 0; i < 50; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final x = bounds.left + (seed % 1000) / 1000 * bounds.width;
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final y = bounds.top + (seed % 1000) / 1000 * bounds.height;
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final radius = 0.05 + (seed % 100) / 1000;

      canvas.drawCircle(Offset(x, y), radius, texturePaint);
    }

    canvas.restore();
  }

  void _drawTopHighlight(Canvas canvas) {
    // 上向きのエッジを探してハイライト
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < _vertices.length; i++) {
      final current = _vertices[i];
      final next = _vertices[(i + 1) % _vertices.length];

      // 上向きのエッジ（Y座標が小さい方向）をハイライト
      // 法線が上を向いている（Y成分が負）エッジを検出
      final edge = next - current;
      final normal = Vector2(-edge.y, edge.x); // 90度回転

      if (normal.y < 0) {
        canvas.drawLine(
          Offset(current.x, current.y),
          Offset(next.x, next.y),
          highlightPaint,
        );
      }
    }
  }
}

/// Terrainをファクトリに登録
void registerTerrainFactory() {
  StageObjectFactory.register('terrain', (json) => Terrain.fromJson(json));
}
