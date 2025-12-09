import 'package:flame/flame.dart';

import 'logger_service.dart';

/// アセットのプリロードを管理するサービス
class AssetPreloader {
  AssetPreloader._();
  static final instance = AssetPreloader._();

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// 全ての背景画像をプリロード
  Future<void> loadAll() async {
    if (_loaded) return;

    logger.info(LogCategory.system, 'Preloading assets...');

    // 背景画像一覧
    final backgroundImages = [
      'tatami.jpg',
      'backgroundArt.jpeg',
      'backgrounds/Overgrown_trees.png',
      'backgrounds/Snow_mountain.png',
      'backgrounds/屋敷と山々.jpeg',
    ];

    // 並列でプリロード
    await Future.wait(
      backgroundImages.map((path) => _loadImage(path)),
    );

    _loaded = true;
    logger.info(LogCategory.system, 'Assets preloaded: ${backgroundImages.length} images');
  }

  Future<void> _loadImage(String path) async {
    try {
      await Flame.images.load(path);
      logger.debug(LogCategory.system, 'Preloaded: $path');
    } catch (e) {
      logger.warning(LogCategory.system, 'Failed to preload: $path');
    }
  }
}
