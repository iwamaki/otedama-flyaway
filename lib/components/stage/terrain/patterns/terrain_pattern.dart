import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// 草の高さ（ワールド座標単位）
  static const double grassHeight = 1.2;

  /// 上側の面の判定閾値（内向き法線のY成分がこれより大きければ上側の面）
  static const double topFaceThreshold = 0.3;

  /// パターンを描画
  /// [viewportBounds] はローカル座標系でのビューポート範囲（カリング用）
  void draw({
    required Canvas canvas,
    required Path clipPath,
    required List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    required int seed,
    Rect? viewportBounds,
  }) {
    // grassタイプの場合は特別処理
    if (terrainType == TerrainType.grass) {
      _drawGrassWithSlope(canvas, clipPath, edges, viewportBounds);
      return;
    }

    final texture = TerrainTextureCache.instance.getTexture(terrainType);

    if (texture == null) {
      _drawFallback(canvas, clipPath);
      return;
    }

    _drawTiledTexture(canvas, clipPath, texture, viewportBounds);
  }

  /// 斜面対応の草地形を描画
  void _drawGrassWithSlope(
    Canvas canvas,
    Path clipPath,
    List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    Rect? viewportBounds,
  ) {
    // ベースはdirtテクスチャで塗りつぶす
    final dirtTexture = TerrainTextureCache.instance.getTexture(TerrainType.dirt);
    final grassTexture = TerrainTextureCache.instance.getTexture(terrainType);

    if (dirtTexture == null) {
      _drawFallback(canvas, clipPath);
      return;
    }

    // 土テクスチャをベースとして描画
    _drawTiledTexture(canvas, clipPath, dirtTexture, viewportBounds);

    // 上向きエッジに沿って草を描画
    if (grassTexture != null) {
      _drawGrassOnUpwardEdges(canvas, clipPath, edges, grassTexture);
    }
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
    final effectiveBounds = viewportBounds != null
        ? bounds.intersect(viewportBounds)
        : bounds;

    if (effectiveBounds.isEmpty) {
      canvas.restore();
      return;
    }

    final startX =
        ((effectiveBounds.left / textureSizeInWorld).floor() - 1) * textureSizeInWorld;
    final startY =
        ((effectiveBounds.top / textureSizeInWorld).floor() - 1) * textureSizeInWorld;
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

  /// 上向きエッジに沿って草を描画
  void _drawGrassOnUpwardEdges(
    Canvas canvas,
    Path clipPath,
    List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    ui.Image grassTexture,
  ) {
    // 草は地形の境界内に収める
    canvas.save();
    canvas.clipPath(clipPath);

    // テクスチャの上部(草の部分)のみを使用（上から60%が草）
    final grassSrcRect = Rect.fromLTWH(
      0,
      0,
      grassTexture.width.toDouble(),
      grassTexture.height * 0.6,
    );

    for (final (start, end, normal) in edges) {
      // 上側の面のみ処理（内向き法線のYが正 = 下向き = 上側の面）
      if (normal.y < topFaceThreshold) continue;

      final edgeVector = end - start;
      final edgeLength = edgeVector.length;
      if (edgeLength < 0.1) continue;

      // エッジの角度を計算
      final angle = math.atan2(edgeVector.y, edgeVector.x);

      // エッジに沿って草テクスチャを配置
      final segmentWidth = textureSizeInWorld;
      final numSegments = (edgeLength / segmentWidth).ceil() + 1;

      for (int i = 0; i < numSegments; i++) {
        final t = i / (numSegments > 1 ? numSegments - 1 : 1);
        final posX = start.x + edgeVector.x * t;
        final posY = start.y + edgeVector.y * t;

        canvas.save();
        canvas.translate(posX, posY);
        canvas.rotate(angle);

        // 草テクスチャを描画（エッジから内側に向かって）
        // 地形の表面に草が生えているように見せる
        final dstRect = Rect.fromLTWH(
          -segmentWidth / 2,
          0, // エッジから内側（下方向）に描画
          segmentWidth,
          grassHeight,
        );

        canvas.drawImageRect(grassTexture, grassSrcRect, dstRect, Paint());
        canvas.restore();
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
