import 'package:flame/flame.dart';

import '../models/stage_data.dart';
import 'asset_preloader.dart';
import 'audio_service.dart';
import 'logger_service.dart';
import 'settings_service.dart';
import '../components/stage/terrain/terrain_texture_cache.dart';

/// ローディング進捗情報
class LoadingProgress {
  final double progress; // 0.0〜1.0
  final String task;
  final bool isComplete;

  const LoadingProgress({
    required this.progress,
    required this.task,
    this.isComplete = false,
  });

  static const initial = LoadingProgress(progress: 0.0, task: '');
  static const complete = LoadingProgress(progress: 1.0, task: '', isComplete: true);
}

/// ステージプリロード結果
class StagePreloadResult {
  final StageData stageData;
  final bool backgroundPreloaded;
  final int imageObjectsPreloaded;

  const StagePreloadResult({
    required this.stageData,
    required this.backgroundPreloaded,
    required this.imageObjectsPreloaded,
  });
}

/// ローディング管理サービス
/// アプリ起動時の初期化とステージ遷移時のプリロードを一元管理
class LoadingManager {
  LoadingManager._();
  static final LoadingManager _instance = LoadingManager._();
  static LoadingManager get instance => _instance;

  /// アプリ初期化済みフラグ
  bool _appInitialized = false;
  bool get isAppInitialized => _appInitialized;

  /// 現在の進捗
  LoadingProgress _progress = LoadingProgress.initial;
  LoadingProgress get progress => _progress;

  /// 進捗変更コールバック
  void Function(LoadingProgress)? onProgressChanged;

  /// プリロード済みステージデータのキャッシュ
  final Map<String, StagePreloadResult> _preloadedStages = {};

  // ========== アプリ起動時の初期化 ==========

  /// アプリ起動時の全初期化を実行
  /// main.dartから呼び出す
  Future<void> initializeApp() async {
    if (_appInitialized) {
      logger.debug(LogCategory.system, 'App already initialized, skipping');
      return;
    }

    logger.info(LogCategory.system, 'LoadingManager: Starting app initialization...');
    final stopwatch = Stopwatch()..start();

    try {
      // 1. 設定サービス初期化 (10%)
      _updateProgress(0.05, 'Loading settings...');
      await SettingsService.instance.init();
      logger.debug(LogCategory.system, 'Settings initialized');

      // 2. テクスチャプリロード (30%) - 並列化済み
      _updateProgress(0.15, 'Loading terrain textures...');
      await TerrainTextureCache.instance.loadAll();
      logger.debug(LogCategory.system, 'Terrain textures loaded');

      // 3. 背景画像プリロード (50%)
      _updateProgress(0.35, 'Loading background images...');
      await AssetPreloader.instance.loadAll();
      logger.debug(LogCategory.system, 'Background images loaded');

      // 4. オーディオサービス初期化 (80%)
      _updateProgress(0.60, 'Initializing audio...');
      await AudioService.instance.initialize();
      logger.debug(LogCategory.system, 'Audio initialized');

      // 5. 完了
      _updateProgress(1.0, 'Ready!');
      _appInitialized = true;

      stopwatch.stop();
      logger.info(LogCategory.system,
          'LoadingManager: App initialization complete (${stopwatch.elapsedMilliseconds}ms)');
    } catch (e, stackTrace) {
      logger.error(LogCategory.system, 'LoadingManager: Initialization failed', error: e);
      logger.debug(LogCategory.system, 'Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ========== ステージプリロード ==========

  /// ステージを事前読み込み
  /// ステージ遷移前に呼び出すことで、遷移時の遅延を削減
  Future<StagePreloadResult> preloadStage(String assetPath) async {
    // キャッシュにあれば返す
    if (_preloadedStages.containsKey(assetPath)) {
      logger.debug(LogCategory.stage, 'Stage already preloaded: $assetPath');
      return _preloadedStages[assetPath]!;
    }

    logger.info(LogCategory.stage, 'Preloading stage: $assetPath');
    final stopwatch = Stopwatch()..start();

    // 1. ステージJSONを読み込み
    final stageData = await StageData.loadFromAsset(assetPath);

    // 2. 背景画像をプリロード
    bool backgroundPreloaded = false;
    if (stageData.background != null) {
      try {
        await Flame.images.load(stageData.background!);
        backgroundPreloaded = true;
        logger.debug(LogCategory.stage, 'Background preloaded: ${stageData.background}');
      } catch (e) {
        logger.warning(LogCategory.stage, 'Failed to preload background: ${stageData.background}');
      }
    }

    // 3. ImageObjectの画像を並列プリロード
    final imageObjectPaths = <String>[];
    for (final obj in stageData.objects) {
      if (obj['type'] == 'imageObject') {
        final imagePath = obj['imagePath'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          imageObjectPaths.add(imagePath);
        }
      }
    }

    int imageObjectsPreloaded = 0;
    if (imageObjectPaths.isNotEmpty) {
      final results = await Future.wait(
        imageObjectPaths.map((path) => _preloadImage(path)),
        eagerError: false,
      );
      imageObjectsPreloaded = results.where((success) => success).length;
      logger.debug(LogCategory.stage,
          'ImageObjects preloaded: $imageObjectsPreloaded/${imageObjectPaths.length}');
    }

    final result = StagePreloadResult(
      stageData: stageData,
      backgroundPreloaded: backgroundPreloaded,
      imageObjectsPreloaded: imageObjectsPreloaded,
    );

    // キャッシュに保存
    _preloadedStages[assetPath] = result;

    stopwatch.stop();
    logger.info(LogCategory.stage,
        'Stage preloaded: $assetPath (${stopwatch.elapsedMilliseconds}ms)');

    return result;
  }

  /// プリロード済みステージデータを取得（なければnull）
  StagePreloadResult? getPreloadedStage(String assetPath) {
    return _preloadedStages[assetPath];
  }

  /// プリロードキャッシュをクリア
  void clearPreloadCache() {
    _preloadedStages.clear();
    logger.debug(LogCategory.stage, 'Preload cache cleared');
  }

  /// 特定ステージのプリロードキャッシュをクリア
  void clearPreloadedStage(String assetPath) {
    _preloadedStages.remove(assetPath);
  }

  // ========== 隣接ステージの先行プリロード ==========

  /// 現在のステージから遷移可能なステージを先行プリロード（バックグラウンド）
  /// 遷移オーバーレイのフェードアウト中に呼び出すと効果的
  Future<void> preloadAdjacentStages(StageData currentStage) async {
    final adjacentPaths = <String>{};

    // 境界遷移からの遷移先
    for (final transition in currentStage.boundaries.transitions) {
      adjacentPaths.add(transition.nextStage);
    }

    // TransitionZoneからの遷移先
    for (final obj in currentStage.objects) {
      if (obj['type'] == 'transitionZone') {
        final nextStage = obj['nextStage'] as String?;
        if (nextStage != null && nextStage.isNotEmpty) {
          adjacentPaths.add(nextStage);
        }
      }
    }

    if (adjacentPaths.isEmpty) {
      logger.debug(LogCategory.stage, 'No adjacent stages to preload');
      return;
    }

    logger.debug(LogCategory.stage, 'Preloading ${adjacentPaths.length} adjacent stages...');

    // 並列プリロード（エラーは無視）
    await Future.wait(
      adjacentPaths.map((path) => preloadStage(path).catchError((e) {
        logger.warning(LogCategory.stage, 'Failed to preload adjacent stage: $path');
        return StagePreloadResult(
          stageData: StageData.empty(),
          backgroundPreloaded: false,
          imageObjectsPreloaded: 0,
        );
      })),
      eagerError: false,
    );
  }

  // ========== 内部メソッド ==========

  void _updateProgress(double progress, String task) {
    _progress = LoadingProgress(
      progress: progress.clamp(0.0, 1.0),
      task: task,
      isComplete: progress >= 1.0,
    );
    onProgressChanged?.call(_progress);
    logger.debug(LogCategory.system, 'Loading: ${(progress * 100).toStringAsFixed(0)}% - $task');
  }

  Future<bool> _preloadImage(String path) async {
    try {
      await Flame.images.load(path);
      return true;
    } catch (e) {
      logger.warning(LogCategory.stage, 'Failed to preload image: $path');
      return false;
    }
  }
}
