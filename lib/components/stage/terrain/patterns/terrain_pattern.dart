import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../terrain_texture_cache.dart';
import '../terrain_type.dart';
import 'edge_decoration.dart';

/// テクスチャベースの地形パターン描画
class TerrainPattern {
  final TerrainType terrainType;

  /// エッジ装飾レンダラー
  final EdgeDecorationRenderer _edgeRenderer = EdgeDecorationRenderer();

  TerrainPattern(this.terrainType);

  /// テクスチャサイズ（ワールド座標単位）
  double get textureSizeInWorld => TerrainTextureCache.textureSizeInWorld;

  /// エッジ装飾を持つ地形タイプとその設定のマッピング
  static const Map<TerrainType, EdgeDecoration> _edgeDecorations = {
    TerrainType.grass: EdgeDecoration.grass,
    TerrainType.snow: EdgeDecoration.snow,
  };

  /// パターンを描画
  /// [viewportBounds] はローカル座標系でのビューポート範囲（カリング用）
  void draw({
    required Canvas canvas,
    required Path clipPath,
    required List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    required int seed,
    Rect? viewportBounds,
  }) {
    // エッジ装飾を持つタイプの場合は特別処理
    final edgeDecoration = _edgeDecorations[terrainType];
    if (edgeDecoration != null) {
      _drawWithEdgeDecoration(
        canvas,
        clipPath,
        edges,
        viewportBounds,
        edgeDecoration,
      );
      return;
    }

    final texture = TerrainTextureCache.instance.getTexture(terrainType);

    if (texture == null) {
      _drawFallback(canvas, clipPath);
      return;
    }

    _drawTiledTexture(canvas, clipPath, texture, viewportBounds);
  }

  /// エッジ装飾付き地形を描画（草・雪など）
  void _drawWithEdgeDecoration(
    Canvas canvas,
    Path clipPath,
    List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    Rect? viewportBounds,
    EdgeDecoration decoration,
  ) {
    // ベースはdirtテクスチャで塗りつぶす
    final dirtTexture =
        TerrainTextureCache.instance.getTexture(TerrainType.dirt);

    if (dirtTexture == null) {
      _drawFallback(canvas, clipPath);
      return;
    }

    // 土テクスチャをベースとして描画
    _drawTiledTexture(canvas, clipPath, dirtTexture, viewportBounds);

    // エッジに沿って装飾を描画
    _edgeRenderer.draw(
      canvas: canvas,
      clipPath: clipPath,
      edges: edges,
      decoration: decoration,
    );
  }

  /// タイル状にテクスチャを描画
  void _drawTiledTexture(
    Canvas canvas,
    Path clipPath,
    ui.Image texture,
    Rect? viewportBounds,
  ) {
    canvas.save();
    canvas.clipPath(clipPath);

    final bounds = clipPath.getBounds();
    final effectiveBounds =
        viewportBounds != null ? bounds.intersect(viewportBounds) : bounds;

    if (effectiveBounds.isEmpty) {
      canvas.restore();
      return;
    }

    final startX =
        ((effectiveBounds.left / textureSizeInWorld).floor() - 1) *
            textureSizeInWorld;
    final startY =
        ((effectiveBounds.top / textureSizeInWorld).floor() - 1) *
            textureSizeInWorld;
    final endX = effectiveBounds.right + textureSizeInWorld;
    final endY = effectiveBounds.bottom + textureSizeInWorld;

    final srcRect = Rect.fromLTWH(
      0,
      0,
      texture.width.toDouble(),
      texture.height.toDouble(),
    );

    for (double x = startX; x < endX; x += textureSizeInWorld) {
      for (double y = startY; y < endY; y += textureSizeInWorld) {
        final dstRect = Rect.fromLTWH(x, y, textureSizeInWorld, textureSizeInWorld);
        canvas.drawImageRect(texture, srcRect, dstRect, Paint());
      }
    }

    canvas.restore();
  }

  /// フォールバック描画（テクスチャ未ロード時）
  void _drawFallback(Canvas canvas, Path clipPath) {
    canvas.save();
    canvas.clipPath(clipPath);

    final bounds = clipPath.getBounds();
    final paint = Paint()
      ..color = terrainType.defaultFillColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRect(bounds, paint);
    canvas.restore();
  }
}
