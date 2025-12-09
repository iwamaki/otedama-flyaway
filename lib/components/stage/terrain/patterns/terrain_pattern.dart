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
    TerrainType.snowIce: EdgeDecoration.snowIce,
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

    _drawTiledTexture(canvas, clipPath, texture, terrainType, viewportBounds);
  }

  /// エッジ装飾付き地形を描画（草・雪など）
  void _drawWithEdgeDecoration(
    Canvas canvas,
    Path clipPath,
    List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    Rect? viewportBounds,
    EdgeDecoration decoration,
  ) {
    // ベーステクスチャで塗りつぶす
    final baseTexture =
        TerrainTextureCache.instance.getTexture(decoration.baseTextureType);

    if (baseTexture == null) {
      _drawFallback(canvas, clipPath);
      return;
    }

    // ベーステクスチャを描画
    _drawTiledTexture(
        canvas, clipPath, baseTexture, decoration.baseTextureType, viewportBounds);

    // エッジに沿って装飾を描画（ビューポートカリング適用）
    _edgeRenderer.draw(
      canvas: canvas,
      clipPath: clipPath,
      edges: edges,
      decoration: decoration,
      viewportBounds: viewportBounds,
    );
  }

  /// タイル状にテクスチャを描画（SpriteBatch使用）
  void _drawTiledTexture(
    Canvas canvas,
    Path clipPath,
    ui.Image texture,
    TerrainType textureType,
    Rect? viewportBounds,
  ) {
    final spriteBatch = TerrainTextureCache.instance.getSpriteBatch(textureType);
    if (spriteBatch == null) {
      _drawFallback(canvas, clipPath);
      return;
    }

    // バッチをクリア
    spriteBatch.clear();

    final bounds = clipPath.getBounds();
    final effectiveBounds =
        viewportBounds != null ? bounds.intersect(viewportBounds) : bounds;

    if (effectiveBounds.isEmpty) {
      return;
    }

    final textureWidth = texture.width.toDouble();
    final textureHeight = texture.height.toDouble();
    final srcRect = Rect.fromLTWH(0, 0, textureWidth, textureHeight);
    final scale = textureSizeInWorld / textureWidth;

    final startX =
        ((effectiveBounds.left / textureSizeInWorld).floor() - 1) *
            textureSizeInWorld;
    final startY =
        ((effectiveBounds.top / textureSizeInWorld).floor() - 1) *
            textureSizeInWorld;
    final endX = effectiveBounds.right + textureSizeInWorld;
    final endY = effectiveBounds.bottom + textureSizeInWorld;

    for (double x = startX; x < endX; x += textureSizeInWorld) {
      for (double y = startY; y < endY; y += textureSizeInWorld) {
        spriteBatch.add(
          source: srcRect,
          offset: Vector2(x, y),
          scale: scale,
        );
      }
    }

    // クリップパスを適用して一括描画
    canvas.save();
    canvas.clipPath(clipPath);
    spriteBatch.render(canvas);
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
