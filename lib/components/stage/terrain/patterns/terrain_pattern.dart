import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../terrain_texture_cache.dart';
import '../terrain_type.dart';

/// テクスチャベースの地形パターン描画
class TerrainPattern {
  final TerrainType terrainType;

  TerrainPattern(this.terrainType);

  /// テクスチャサイズ（ワールド座標単位）
  double get textureSizeInWorld => TerrainTextureCache.textureSizeInWorld;

  /// パターンを描画
  /// [viewportBounds] はローカル座標系でのビューポート範囲（カリング用）
  void draw({
    required Canvas canvas,
    required Path clipPath,
    required List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    required int seed,
    Rect? viewportBounds,
  }) {
    final texture = TerrainTextureCache.instance.getTexture(terrainType);

    if (texture == null) {
      // テクスチャが未ロードの場合はフォールバック描画
      _drawFallback(canvas, clipPath);
      return;
    }

    canvas.save();
    canvas.clipPath(clipPath);

    // クリップパスのバウンディングボックスを取得
    final bounds = clipPath.getBounds();

    // ビューポートカリング: boundsとviewportの交差部分だけ描画
    final effectiveBounds = viewportBounds != null
        ? bounds.intersect(viewportBounds)
        : bounds;

    // 交差がない場合は描画不要
    if (effectiveBounds.isEmpty) {
      canvas.restore();
      return;
    }

    // タイルグリッドの開始位置（タイルサイズでスナップ、1タイル分余裕を持たせる）
    final startX =
        ((effectiveBounds.left / textureSizeInWorld).floor() - 1) * textureSizeInWorld;
    final startY =
        ((effectiveBounds.top / textureSizeInWorld).floor() - 1) * textureSizeInWorld;

    // 終了位置（1タイル分余裕を持たせる）
    final endX = effectiveBounds.right + textureSizeInWorld;
    final endY = effectiveBounds.bottom + textureSizeInWorld;

    // テクスチャのソース矩形
    final srcRect = Rect.fromLTWH(
      0,
      0,
      texture.width.toDouble(),
      texture.height.toDouble(),
    );

    // テクスチャをタイル敷き（clipPathでクリップされるので余分に描画しても問題なし）
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
