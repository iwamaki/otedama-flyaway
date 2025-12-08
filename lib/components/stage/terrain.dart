import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../utils/json_helpers.dart';
import '../../utils/selection_highlight.dart';
import 'stage_object.dart';
import 'terrain/terrain_type.dart';
import 'terrain/patterns/terrain_pattern.dart';

export 'terrain/terrain_type.dart';
export 'terrain/terrain_texture_cache.dart';

/// 地形コンポーネント（ChainShape使用）
class Terrain extends BodyComponent with StageObject {
  final Vector2 initialPosition;
  List<Vector2> _vertices;
  final bool isLoop;
  final TerrainType terrainType;
  final Color fillColor;

  late final int _patternSeed;
  late final TerrainPattern _pattern;

  Terrain({
    required Vector2 position,
    required List<Vector2> vertices,
    this.isLoop = true,
    this.terrainType = TerrainType.dirt,
    Color? fillColor,
  })  : initialPosition = position.clone(),
        _vertices = vertices.map((v) => v.clone()).toList(),
        fillColor = fillColor ?? terrainType.defaultFillColor {
    _patternSeed = position.hashCode ^ vertices.length;
    _pattern = _createPattern(terrainType);
  }

  static TerrainPattern _createPattern(TerrainType type) {
    return TerrainPattern(type);
  }

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

    if (vertices.isEmpty) {
      vertices.addAll([
        Vector2(-10, -1),
        Vector2(10, -1),
        Vector2(10, 1),
        Vector2(-10, 1),
      ]);
    }

    final terrainType = TerrainTypeExtension.fromString(
      json['terrainType'] as String? ?? 'dirt',
    );

    return Terrain(
      position: json.getVector2(),
      vertices: vertices,
      isLoop: json.getBool('isLoop', true),
      terrainType: terrainType,
      fillColor: json.containsKey('fillColor')
          ? json.getColor('fillColor', terrainType.defaultFillColor)
          : null,
    );
  }

  factory Terrain.rectangle({
    required Vector2 position,
    required double width,
    required double height,
    TerrainType terrainType = TerrainType.dirt,
    Color? fillColor,
  }) {
    final halfW = width / 2;
    final halfH = height / 2;
    return Terrain(
      position: position,
      vertices: [
        Vector2(-halfW, -halfH),
        Vector2(halfW, -halfH),
        Vector2(halfW, halfH),
        Vector2(-halfW, halfH),
      ],
      isLoop: true,
      terrainType: terrainType,
      fillColor: fillColor,
    );
  }

  factory Terrain.ground({
    required Vector2 position,
    double width = 50.0,
    double height = 5.0,
    TerrainType terrainType = TerrainType.grass,
  }) {
    return Terrain.rectangle(
      position: position,
      width: width,
      height: height,
      terrainType: terrainType,
    );
  }

  factory Terrain.wall({
    required Vector2 position,
    double width = 2.0,
    double height = 20.0,
    TerrainType terrainType = TerrainType.rock,
  }) {
    return Terrain.rectangle(
      position: position,
      width: width,
      height: height,
      terrainType: terrainType,
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
  bool get canResize => false;

  @override
  bool get canFlip => false;

  List<Vector2> get vertices => _vertices;

  @override
  (Vector2 min, Vector2 max) get bounds {
    final (minV, maxV) = _getVerticesBounds();
    final pos = body.position;
    return (
      Vector2(minV.x + pos.x, minV.y + pos.y),
      Vector2(maxV.x + pos.x, maxV.y + pos.y),
    );
  }

  /// verticesのmin/maxを取得（ローカル座標）
  (Vector2 min, Vector2 max) _getVerticesBounds() {
    if (_vertices.isEmpty) {
      return (Vector2.zero(), Vector2.zero());
    }

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

    return (Vector2(minX, minY), Vector2(maxX, maxY));
  }

  Vector2 _calculateBoundsSize() {
    final (minV, maxV) = _getVerticesBounds();
    return Vector2(maxV.x - minV.x, maxV.y - minV.y);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'x': position.x,
      'y': position.y,
      'vertices': _vertices.map((v) => {'x': v.x, 'y': v.y}).toList(),
      'isLoop': isLoop,
      'terrainType': terrainType.name,
      // ignore: deprecated_member_use
      'fillColor': fillColor.value,
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

  void addVertex(Vector2 vertex) {
    _vertices.add(vertex.clone());
    _rebuildFixtures();
  }

  void updateVertex(int index, Vector2 newPosition) {
    if (index >= 0 && index < _vertices.length) {
      _vertices[index] = newPosition.clone();
      _rebuildFixtures();
    }
  }

  void removeVertex(int index) {
    if (index >= 0 && index < _vertices.length && _vertices.length > 3) {
      _vertices.removeAt(index);
      _rebuildFixtures();
    }
  }

  void _rebuildFixtures() {
    if (!isMounted) return;

    while (body.fixtures.isNotEmpty) {
      body.destroyFixture(body.fixtures.first);
    }
    _createFixture();
  }

  void _createFixture() {
    if (_vertices.length < 2) return;

    final chain = ChainShape();

    if (isLoop) {
      chain.createLoop(_vertices);
    } else {
      chain.createChain(_vertices);
    }

    body.createFixture(FixtureDef(chain)
      ..friction = terrainType.friction
      ..restitution = terrainType.restitution);
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
        ..friction = terrainType.friction
        ..restitution = terrainType.restitution);
    }

    return body;
  }

  @override
  void render(Canvas canvas) {
    if (_vertices.isEmpty) return;

    // 塗りつぶし
    if (isLoop && _vertices.length >= 3) {
      final fillPath = Path();
      fillPath.moveTo(_vertices[0].x, _vertices[0].y);
      for (int i = 1; i < _vertices.length; i++) {
        fillPath.lineTo(_vertices[i].x, _vertices[i].y);
      }
      fillPath.close();

      // ベース塗りつぶし
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );

      // ビューポート範囲を計算（ローカル座標系）
      final viewportBounds = _calculateViewportBounds();

      // 質感パターン
      final edges = _getAllEdges();
      _pattern.draw(
        canvas: canvas,
        clipPath: fillPath,
        edges: edges,
        seed: _patternSeed,
        viewportBounds: viewportBounds,
      );
    }

    // 選択中ならハイライト
    if (isSelected) {
      // verticesの中心を計算
      final (minV, maxV) = _getVerticesBounds();
      final centerX = (minV.x + maxV.x) / 2;
      final centerY = (minV.y + maxV.y) / 2;
      final halfWidth = (maxV.x - minV.x) / 2;
      final halfHeight = (maxV.y - minV.y) / 2;

      canvas.save();
      canvas.translate(centerX, centerY);
      SelectionHighlight.draw(
        canvas,
        halfWidth: halfWidth,
        halfHeight: halfHeight,
      );
      canvas.restore();
    }
  }

  /// ビューポート範囲をローカル座標系で計算
  Rect? _calculateViewportBounds() {
    if (!isMounted) return null;

    try {
      final camera = game.camera;
      final cameraPos = camera.viewfinder.position;
      final zoom = camera.viewfinder.zoom;
      final viewportSize = camera.viewport.size;

      // ビューポートの半分のサイズ（ワールド座標）
      final halfWidth = viewportSize.x / zoom / 2;
      final halfHeight = viewportSize.y / zoom / 2;

      // ワールド座標でのビューポート範囲
      final worldLeft = cameraPos.x - halfWidth;
      final worldTop = cameraPos.y - halfHeight;
      final worldRight = cameraPos.x + halfWidth;
      final worldBottom = cameraPos.y + halfHeight;

      // ローカル座標に変換（body.positionを引く）
      final bodyPos = body.position;
      return Rect.fromLTRB(
        worldLeft - bodyPos.x,
        worldTop - bodyPos.y,
        worldRight - bodyPos.x,
        worldBottom - bodyPos.y,
      );
    } catch (_) {
      return null;
    }
  }

  /// 全エッジを取得（内向き法線付き）
  List<(Vector2 start, Vector2 end, Vector2 normal)> _getAllEdges() {
    final edges = <(Vector2, Vector2, Vector2)>[];

    // ポリゴンの重心を計算（法線の向きを決定するため）
    var centroid = Vector2.zero();
    for (final v in _vertices) {
      centroid += v;
    }
    centroid /= _vertices.length.toDouble();

    for (int i = 0; i < _vertices.length; i++) {
      final current = _vertices[i];
      final next = _vertices[(i + 1) % _vertices.length];

      final edge = next - current;
      // 法線の候補（右回転）
      var normal = Vector2(-edge.y, edge.x)..normalize();

      // エッジの中点から重心への方向をチェック
      final edgeMidpoint = (current + next) / 2;
      final toCenter = centroid - edgeMidpoint;

      // 法線が内向きでなければ反転
      if (normal.dot(toCenter) < 0) {
        normal = -normal;
      }

      edges.add((current, next, normal));
    }

    return edges;
  }
}

/// Terrainをファクトリに登録
void registerTerrainFactory() {
  StageObjectFactory.register('terrain', (json) => Terrain.fromJson(json));
}
