# Terrain描画のSpriteBatch化計画

## 調査日: 2025-12-10

## 問題箇所

- `edge_decoration.dart` - `EdgeDecorationRenderer.draw()` (行139-164)
- `terrain_pattern.dart` - `TerrainPattern._drawTiledTexture()` (行129-133)

## 現状の問題

```dart
// 各セグメントで個別にドローコール
for (int i = 0; i < numSegments; i++) {
  canvas.save();
  canvas.translate(posX, posY);
  canvas.rotate(angle);
  canvas.drawImageRect(texture, srcRect, dstRect, _paint);
  canvas.restore();
}
```

**影響**:
- 長いエッジで数十〜数百のドローコール
- タイルテクスチャでも大きな地形で多数のドローコール
- ステージ遷移時や複雑な地形でカクつき発生

## 最適化案: SpriteBatchによる一括描画

### Step 1: TerrainTextureCacheにSpriteBatch管理を追加

```dart
// terrain_texture_cache.dart
class TerrainTextureCache {
  final Map<TerrainType, ui.Image> _textures = {};
  final Map<TerrainType, SpriteBatch> _spriteBatches = {};  // 追加

  /// SpriteBatchを取得（遅延初期化）
  SpriteBatch? getSpriteBatch(TerrainType type) {
    if (!_spriteBatches.containsKey(type)) {
      final texture = _textures[type];
      if (texture == null) return null;
      _spriteBatches[type] = SpriteBatch(texture);
    }
    return _spriteBatches[type];
  }

  /// フレーム終了時にSpriteBatchをクリア
  void clearBatches() {
    for (final batch in _spriteBatches.values) {
      batch.clear();
    }
  }
}
```

### Step 2: EdgeDecorationRendererの変更

```dart
// edge_decoration.dart
void draw({
  required Canvas canvas,
  required Path clipPath,
  required List<(Vector2, Vector2, Vector2)> edges,
  required EdgeDecoration decoration,
  Rect? viewportBounds,
}) {
  final spriteBatch = TerrainTextureCache.instance
      .getSpriteBatch(decoration.textureType);
  if (spriteBatch == null) return;

  // バッチをクリア
  spriteBatch.clear();

  // クリップパスを適用
  canvas.save();
  canvas.clipPath(clipPath);

  final texture = TerrainTextureCache.instance.getTexture(decoration.textureType);
  if (texture == null) {
    canvas.restore();
    return;
  }

  final textureWidth = texture.width.toDouble();
  final textureHeight = texture.height.toDouble();
  final srcRect = Rect.fromLTWH(0, 0, textureWidth, textureHeight * decoration.srcRectRatio);

  // ビューポートカリング用の拡張範囲
  final cullingBounds = viewportBounds?.inflate(decoration.height + textureSizeInWorld);

  for (final (start, end, normal) in edges) {
    if (!_matchesDirection(normal, decoration)) continue;
    if (cullingBounds != null && !_edgeIntersectsBounds(start, end, cullingBounds)) continue;

    final edgeVector = end - start;
    final edgeLength = edgeVector.length;
    if (edgeLength < 0.1) continue;

    final angle = math.atan2(edgeVector.y, edgeVector.x);
    final segmentWidth = textureSizeInWorld;
    final numSegments = (edgeLength / segmentWidth).ceil() + 1;

    for (int i = 0; i < numSegments; i++) {
      final t = i / (numSegments > 1 ? numSegments - 1 : 1);
      final posX = start.x + edgeVector.x * t;
      final posY = start.y + edgeVector.y * t;

      if (cullingBounds != null && !cullingBounds.contains(Offset(posX, posY))) continue;

      // SpriteBatchに追加（ドローコールなし）
      spriteBatch.add(
        source: srcRect,
        offset: Vector2(posX, posY),
        rotation: angle,
        scale: segmentWidth / textureWidth,
        anchor: Vector2(segmentWidth / 2, 0),
      );
    }
  }

  // 一括描画（1回のドローコール）
  spriteBatch.render(canvas);
  canvas.restore();
}
```

### Step 3: TerrainPatternの変更

```dart
// terrain_pattern.dart
void _drawTiledTexture(Canvas canvas, Path clipPath, ui.Image texture, Rect? viewportBounds) {
  final spriteBatch = TerrainTextureCache.instance.getSpriteBatch(terrainType);
  if (spriteBatch == null) {
    _drawFallback(canvas, clipPath);
    return;
  }

  spriteBatch.clear();
  canvas.save();
  canvas.clipPath(clipPath);

  final bounds = clipPath.getBounds();
  final effectiveBounds = viewportBounds != null ? bounds.intersect(viewportBounds) : bounds;

  if (effectiveBounds.isEmpty) {
    canvas.restore();
    return;
  }

  final textureWidth = texture.width.toDouble();
  final textureHeight = texture.height.toDouble();
  final srcRect = Rect.fromLTWH(0, 0, textureWidth, textureHeight);

  final startX = ((effectiveBounds.left / textureSizeInWorld).floor() - 1) * textureSizeInWorld;
  final startY = ((effectiveBounds.top / textureSizeInWorld).floor() - 1) * textureSizeInWorld;
  final endX = effectiveBounds.right + textureSizeInWorld;
  final endY = effectiveBounds.bottom + textureSizeInWorld;

  for (double x = startX; x < endX; x += textureSizeInWorld) {
    for (double y = startY; y < endY; y += textureSizeInWorld) {
      spriteBatch.add(
        source: srcRect,
        offset: Vector2(x, y),
        scale: textureSizeInWorld / textureWidth,
      );
    }
  }

  spriteBatch.render(canvas);
  canvas.restore();
}
```

## 期待効果

| 項目 | Before | After |
|------|--------|-------|
| ドローコール数 | N回/Terrain | 1回/Terrain |
| canvas.save/restore | N回/Terrain | 1回/Terrain |
| Paint生成 | N回/フレーム | 0回（SpriteBatch内部） |

**推定改善**: Terrain描画で **50-80%** のパフォーマンス向上

## 注意事項

- SpriteBatchはFlameのGameに依存するため、初期化タイミングに注意
- Web(HTML mode)では`drawAtlas`が使えないためフォールバック必要
- テクスチャごとにSpriteBatchが必要（メモリ使用量増加）

## 状態

[ ] 未着手
