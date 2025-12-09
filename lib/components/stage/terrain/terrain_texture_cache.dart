import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/sprite.dart';

import 'terrain_type.dart';

/// 地形テクスチャのキャッシュ管理
class TerrainTextureCache {
  static final TerrainTextureCache _instance = TerrainTextureCache._();
  static TerrainTextureCache get instance => _instance;

  TerrainTextureCache._();

  final Map<TerrainType, ui.Image> _textures = {};
  final Map<TerrainType, SpriteBatch> _spriteBatches = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// テクスチャファイル名のマッピング
  static const Map<TerrainType, String> _textureFiles = {
    TerrainType.grass: 'terrain/grass-dirt_128x128.png',
    TerrainType.dirt: 'terrain/dirt_128x128.png',
    TerrainType.rock: 'terrain/rock_128x128.png',
    TerrainType.ice: 'terrain/ice_128x128.png',
    TerrainType.wood: 'terrain/wood_128x128.png',
    TerrainType.metal: 'terrain/metal_128x128.png',
    TerrainType.snow: 'terrain/snow-dirt_128x128.png',
    TerrainType.snowIce: 'terrain/snow-ice_128x128.png',
    TerrainType.stoneTiles: 'terrain/stone-tiles_128x128.png',
    // エッジ装飾専用（透過テクスチャ）
    TerrainType.grassEdge: 'terrain/grass_128x128.png',
    TerrainType.snowEdge: 'terrain/snow_128x128.png',
  };

  /// 全テクスチャをロード（並列処理）
  Future<void> loadAll() async {
    if (_isLoaded) return;

    final images = Images(prefix: 'assets/texture/');

    // 並列でロード
    await Future.wait(
      _textureFiles.entries.map((entry) async {
        final image = await images.load(entry.value);
        _textures[entry.key] = image;
      }),
    );

    _isLoaded = true;
  }

  /// 指定タイプのテクスチャを取得
  ui.Image? getTexture(TerrainType type) {
    return _textures[type];
  }

  /// SpriteBatchを取得（遅延初期化）
  SpriteBatch? getSpriteBatch(TerrainType type) {
    if (!_spriteBatches.containsKey(type)) {
      final texture = _textures[type];
      if (texture == null) return null;
      _spriteBatches[type] = SpriteBatch(texture);
    }
    return _spriteBatches[type];
  }

  /// テクスチャサイズ（ワールド座標単位）
  /// 128pxのテクスチャを4ワールド単位で表示
  static const double textureSizeInWorld = 4.0;

  /// キャッシュをクリア
  void clear() {
    for (final batch in _spriteBatches.values) {
      batch.clear();
    }
    _spriteBatches.clear();
    _textures.clear();
    _isLoaded = false;
  }
}
