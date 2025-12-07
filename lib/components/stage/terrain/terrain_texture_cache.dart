import 'dart:ui' as ui;

import 'package:flame/cache.dart';

import 'terrain_type.dart';

/// 地形テクスチャのキャッシュ管理
class TerrainTextureCache {
  static final TerrainTextureCache _instance = TerrainTextureCache._();
  static TerrainTextureCache get instance => _instance;

  TerrainTextureCache._();

  final Map<TerrainType, ui.Image> _textures = {};
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
  };

  /// 全テクスチャをロード
  Future<void> loadAll() async {
    if (_isLoaded) return;

    final images = Images(prefix: 'assets/texture/');

    for (final entry in _textureFiles.entries) {
      final image = await images.load(entry.value);
      _textures[entry.key] = image;
    }

    _isLoaded = true;
  }

  /// 指定タイプのテクスチャを取得
  ui.Image? getTexture(TerrainType type) {
    return _textures[type];
  }

  /// テクスチャサイズ（ワールド座標単位）
  /// 128pxのテクスチャを2ワールド単位で表示
  static const double textureSizeInWorld = 2.0;

  /// キャッシュをクリア
  void clear() {
    _textures.clear();
    _isLoaded = false;
  }
}
