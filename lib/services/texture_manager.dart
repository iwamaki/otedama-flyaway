import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// テクスチャ画像の読み込みとキャッシュを管理
class TextureManager {
  TextureManager._();
  static final TextureManager instance = TextureManager._();

  /// 読み込み済みテクスチャのキャッシュ
  final Map<String, ui.Image> _cache = {};

  /// テクスチャを読み込む（キャッシュがあればそれを返す）
  Future<ui.Image?> loadTexture(String assetPath) async {
    // キャッシュチェック
    if (_cache.containsKey(assetPath)) {
      return _cache[assetPath];
    }

    try {
      // アセットからバイトデータを読み込み
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();

      // デコード
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // キャッシュに保存
      _cache[assetPath] = image;

      return image;
    } catch (e) {
      // 読み込み失敗時はnullを返す
      return null;
    }
  }

  /// キャッシュ済みのテクスチャを取得（同期的）
  ui.Image? getCachedTexture(String assetPath) {
    return _cache[assetPath];
  }

  /// テクスチャがキャッシュ済みかどうか
  bool isCached(String assetPath) {
    return _cache.containsKey(assetPath);
  }

  /// 指定したテクスチャのキャッシュをクリア
  void clearTexture(String assetPath) {
    _cache.remove(assetPath);
  }

  /// 全てのキャッシュをクリア
  void clearAll() {
    _cache.clear();
  }

  /// プリロード（複数テクスチャを事前に読み込む）
  Future<void> preloadTextures(List<String> assetPaths) async {
    await Future.wait(
      assetPaths.map((path) => loadTexture(path)),
    );
  }
}
