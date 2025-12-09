import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../terrain_texture_cache.dart';
import '../terrain_type.dart';

/// エッジの方向（内向き法線基準）
enum EdgeDirection {
  /// 上側の面（内向き法線のYが正 = 下向き法線 = 上側の面）
  top,

  /// 側面（左右）
  side,

  /// 下側の面
  bottom,
}

/// エッジ装飾の設定
class EdgeDecoration {
  /// 使用するテクスチャのタイプ（エッジ装飾用）
  final TerrainType textureType;

  /// ベースとなるテクスチャのタイプ（地形全体の塗りつぶし用）
  final TerrainType baseTextureType;

  /// 装飾の高さ（ワールド座標単位）
  final double height;

  /// 対象とするエッジの方向
  final EdgeDirection direction;

  /// テクスチャのソース領域（0.0〜1.0、上からの比率）
  /// 例: 0.6 = テクスチャの上部60%を使用
  final double srcRectRatio;

  /// エッジ方向判定の閾値（法線のY成分）
  final double directionThreshold;

  const EdgeDecoration({
    required this.textureType,
    this.baseTextureType = TerrainType.dirt,
    this.height = 1.2,
    this.direction = EdgeDirection.top,
    this.srcRectRatio = 0.6,
    this.directionThreshold = 0.3,
  });

  /// 草のデフォルト設定
  static const grass = EdgeDecoration(
    textureType: TerrainType.grass,
    height: 1.2,
    direction: EdgeDirection.top,
    srcRectRatio: 0.6,
    directionThreshold: 0.3,
  );

  /// 雪のデフォルト設定（土ベース）
  static const snow = EdgeDecoration(
    textureType: TerrainType.snow,
    baseTextureType: TerrainType.dirt,
    height: 1.2,
    direction: EdgeDirection.top,
    srcRectRatio: 0.6,
    directionThreshold: 0.3,
  );

  /// 雪のデフォルト設定（氷ベース）
  static const snowIce = EdgeDecoration(
    textureType: TerrainType.snowIce,
    baseTextureType: TerrainType.ice,
    height: 1.2,
    direction: EdgeDirection.top,
    srcRectRatio: 0.6,
    directionThreshold: 0.3,
  );
}

/// エッジ装飾の描画ロジック（斜面対応）
class EdgeDecorationRenderer {
  /// テクスチャサイズ（ワールド座標単位）
  double get textureSizeInWorld => TerrainTextureCache.textureSizeInWorld;

  /// 再利用するPaintオブジェクト（GC負荷軽減）
  static final Paint _paint = Paint();

  /// エッジに沿って装飾を描画（斜面対応）
  /// [viewportBounds] はローカル座標系でのビューポート範囲（カリング用）
  void draw({
    required Canvas canvas,
    required Path clipPath,
    required List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    required EdgeDecoration decoration,
    Rect? viewportBounds,
  }) {
    final texture =
        TerrainTextureCache.instance.getTexture(decoration.textureType);
    if (texture == null) return;

    // 装飾は地形の境界内に収める
    canvas.save();
    canvas.clipPath(clipPath);

    // テクスチャのソース領域を計算
    final srcRect = Rect.fromLTWH(
      0,
      0,
      texture.width.toDouble(),
      texture.height * decoration.srcRectRatio,
    );

    // ビューポートカリング用の拡張範囲（装飾の高さ分のマージン）
    final cullingBounds =
        viewportBounds?.inflate(decoration.height + textureSizeInWorld);

    for (final (start, end, normal) in edges) {
      // 指定した方向のエッジのみ処理
      if (!_matchesDirection(normal, decoration)) continue;

      // ビューポートカリング: エッジがビューポート外なら完全スキップ
      if (cullingBounds != null &&
          !_edgeIntersectsBounds(start, end, cullingBounds)) {
        continue;
      }

      final edgeVector = end - start;
      final edgeLength = edgeVector.length;
      if (edgeLength < 0.1) continue;

      // エッジの角度を計算（斜面対応の核心）
      final angle = math.atan2(edgeVector.y, edgeVector.x);

      // エッジに沿ってテクスチャを配置
      final segmentWidth = textureSizeInWorld;
      final numSegments = (edgeLength / segmentWidth).ceil() + 1;

      for (int i = 0; i < numSegments; i++) {
        final t = i / (numSegments > 1 ? numSegments - 1 : 1);
        final posX = start.x + edgeVector.x * t;
        final posY = start.y + edgeVector.y * t;

        // セグメント単位のビューポートカリング
        if (cullingBounds != null &&
            !cullingBounds.contains(Offset(posX, posY))) {
          continue;
        }

        canvas.save();
        canvas.translate(posX, posY);
        canvas.rotate(angle);

        // 装飾テクスチャを描画（エッジから内側に向かって）
        final dstRect = Rect.fromLTWH(
          -segmentWidth / 2,
          0, // エッジから内側（回転後の下方向）に描画
          segmentWidth,
          decoration.height,
        );

        canvas.drawImageRect(texture, srcRect, dstRect, _paint);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  /// エッジ（線分）がバウンディングボックスと交差するかチェック
  bool _edgeIntersectsBounds(Vector2 start, Vector2 end, Rect bounds) {
    // まず、両端点のいずれかがバウンズ内にあるかチェック
    if (bounds.contains(Offset(start.x, start.y)) ||
        bounds.contains(Offset(end.x, end.y))) {
      return true;
    }

    // エッジのバウンディングボックスとビューポートの交差チェック
    final edgeMinX = math.min(start.x, end.x);
    final edgeMaxX = math.max(start.x, end.x);
    final edgeMinY = math.min(start.y, end.y);
    final edgeMaxY = math.max(start.y, end.y);

    // AABBの交差判定
    return edgeMinX <= bounds.right &&
        edgeMaxX >= bounds.left &&
        edgeMinY <= bounds.bottom &&
        edgeMaxY >= bounds.top;
  }

  /// 法線がエッジ方向にマッチするか判定
  bool _matchesDirection(Vector2 normal, EdgeDecoration decoration) {
    switch (decoration.direction) {
      case EdgeDirection.top:
        // 内向き法線のYが閾値より大きい = 上側の面
        return normal.y >= decoration.directionThreshold;
      case EdgeDirection.bottom:
        // 内向き法線のYが負の閾値より小さい = 下側の面
        return normal.y <= -decoration.directionThreshold;
      case EdgeDirection.side:
        // 内向き法線のYが閾値の範囲内 = 側面
        return normal.y.abs() < decoration.directionThreshold;
    }
  }
}
