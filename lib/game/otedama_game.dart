import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/drag_line.dart';
import '../components/particle_otedama.dart';
import '../components/stage/goal.dart';
import '../components/stage/stage_object.dart';
import '../components/stage/transition_zone.dart';
import '../config/otedama_skin_config.dart';
import '../config/physics_config.dart';
import '../models/stage_data.dart';
import '../models/transition_info.dart';
import '../services/audio_service.dart';
import '../services/loading_manager.dart';
import '../services/logger_service.dart';
import '../services/performance_monitor.dart';
import 'camera_controller.dart';
import 'mixins/drag_handler_mixin.dart';
import 'mixins/edit_mode_mixin.dart';
import 'mixins/game_timer_mixin.dart';
import 'mixins/goal_handler_mixin.dart';
import 'mixins/transition_handler_mixin.dart';
import 'stage/stage_manager.dart';
import 'stage/stage_object_builder.dart';

export '../models/transition_info.dart' show TransitionInfo;

/// メインゲームクラス
class OtedamaGame extends Forge2DGame
    with
        DragCallbacks,
        GameTimerMixin,
        GoalHandlerMixin,
        TransitionHandlerMixin,
        DragHandlerMixin,
        EditModeMixin {
  @override
  ParticleOtedama? otedama;

  /// カメラコントローラー
  late CameraController _cameraController;

  /// ステージマネージャー
  late StageManager _stageManager;

  /// オブジェクトビルダー
  late StageObjectBuilder _objectBuilder;

  /// お手玉のスキン設定
  OtedamaSkin _otedamaSkin;

  /// 初期ステージのアセットパス
  final String? _initialStageAsset;

  /// 背景画像のパス
  final String? _initialBackgroundImage;

  OtedamaGame({
    String? backgroundImage,
    String? initialStageAsset,
    OtedamaSkin? otedamaSkin,
  })  : _initialBackgroundImage = backgroundImage,
        _initialStageAsset = initialStageAsset,
        _otedamaSkin = otedamaSkin ?? OtedamaSkinConfig.defaultSkin,
        super(gravity: Vector2(0, PhysicsConfig.gravityY));

  // --- Getter/Setter ---

  /// ゴール（GoalHandlerMixinから委譲）
  @override
  Goal? get goal => _stageManager.goal;

  @override
  set goal(Goal? value) => _stageManager.goal = value;

  /// ステージオブジェクトのリスト
  @override
  List<StageObject> get stageObjects => _stageManager.stageObjects;

  /// 現在のステージ境界
  @override
  StageBoundaries get boundaries => _stageManager.boundaries;
  set boundaries(StageBoundaries value) => _stageManager.boundaries = value;

  /// 現在のステージレベル
  int get currentStageLevel => _stageManager.currentStageLevel;
  set currentStageLevel(int value) => _stageManager.currentStageLevel = value;

  /// 現在のステージ名
  String get currentStageName => _stageManager.currentStageName;
  set currentStageName(String value) => _stageManager.currentStageName = value;

  /// 現在のステージアセットパス
  String? get currentStageAsset => _stageManager.currentStageAsset;

  /// 背景画像のパス
  String? get currentBackground => _stageManager.backgroundImage;

  /// 一時保存があるステージのアセットパス一覧
  Set<String> get unsavedStageAssets => _stageManager.unsavedStageAssets;

  /// スポーン位置X
  double get spawnX => _stageManager.spawnX;
  set spawnX(double value) {
    _stageManager.spawnX = value;
    onEditModeChanged?.call();
  }

  /// スポーン位置Y
  double get spawnY => _stageManager.spawnY;
  set spawnY(double value) {
    _stageManager.spawnY = value;
    onEditModeChanged?.call();
  }

  /// 現在の高さ（Y座標の負数、上が正）
  double get currentHeight => -(otedama?.centerPosition.y ?? 0);

  /// 最高到達高さ
  double _maxHeight = 0;
  double get maxHeight => _maxHeight;

  /// 前回の重力スケール（条件付き更新用）
  double _lastGravityScale = -1;

  // --- ライフサイクル ---

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 注: AudioServiceはLoadingManager.initializeApp()で初期化済み

    // カメラ設定
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = CameraConfig.zoom;
    _cameraController = CameraController(camera);

    // ステージマネージャーを初期化
    _stageManager = StageManager(this, backgroundImage: _initialBackgroundImage);
    _stageManager.onChanged = () => onEditModeChanged?.call();
    _stageManager.onAmbientSoundChanged = _onAmbientSoundChanged;
    _stageManager.onBgmChanged = _onBgmChanged;

    // 背景を追加
    await _stageManager.initBackground(camera, size);

    // オブジェクトビルダーを初期化
    _objectBuilder = StageObjectBuilder(
      stageManager: _stageManager,
      camera: camera,
    );

    // ドラッグ線（最前面に表示するためviewportに追加）
    dragLine = DragLine();
    camera.viewport.add(dragLine!);

    // お手玉を配置（粒子ベース）
    otedama = ParticleOtedama(
      position: Vector2(StageConfig.spawnX, StageConfig.spawnY),
      skin: _otedamaSkin,
    );
    await world.add(otedama!);

    // 初期ステージが指定されている場合は読み込む
    if (_initialStageAsset != null) {
      try {
        // プリロード済みのステージデータがあれば使用
        final preloaded = LoadingManager.instance.getPreloadedStage(_initialStageAsset);
        final stageData = preloaded?.stageData ??
            await StageData.loadFromAsset(_initialStageAsset);
        await loadStage(stageData, assetPath: _initialStageAsset);
      } catch (e) {
        logger.error(LogCategory.stage, 'Failed to load initial stage', error: e);
      }
    }
  }

  @override
  void update(double dt) {
    // パフォーマンスモニター: フレーム記録
    PerformanceMonitor.instance.recordFrame(dt);

    PerformanceMonitor.instance.startSection('physics');

    // Forge2Dサブステッピングが有効な場合、物理ステップを分割
    if (ParticleOtedama.forge2dSubsteppingEnabled &&
        ParticleOtedama.forge2dSubsteps > 1) {
      final subDt = dt / ParticleOtedama.forge2dSubsteps;
      for (int i = 0; i < ParticleOtedama.forge2dSubsteps; i++) {
        // 各サブステップ前に速度制限を適用
        otedama?.applyPreStepVelocityLimits(subDt);
        // Forge2Dの物理ステップ（小さいdtで）
        world.physicsWorld.stepDt(subDt);
      }
      // 子コンポーネントのupdateはdt全体で1回だけ呼ぶ
      for (final child in world.children) {
        child.update(dt);
      }
    } else {
      // ★ Forge2D物理ステップの前に速度制限を適用（反転防止の根本対策）
      // super.update()内でWorld.stepDt()が実行されるため、その前に制限する必要がある
      otedama?.applyPreStepVelocityLimits(dt);
      super.update(dt);
    }

    PerformanceMonitor.instance.endSection('physics');

    // 音声サービスの更新（クールダウン管理）
    AudioService.instance.update(dt);

    // 重力スケールを適用（変更時のみ更新）
    if (_lastGravityScale != ParticleOtedama.gravityScale) {
      world.gravity = Vector2(0, PhysicsConfig.gravityY * ParticleOtedama.gravityScale);
      _lastGravityScale = ParticleOtedama.gravityScale;
    }

    if (otedama != null) {
      // カメラ追従
      _cameraController.follow(otedama!.centerPosition);

      // 最高高さを更新
      if (currentHeight > _maxHeight) {
        _maxHeight = currentHeight;
      }

      // 境界判定（遷移中でない場合のみ）
      if (canTransition) {
        final pos = otedama!.centerPosition;

        // 遷移境界チェック
        checkBoundaryTransitions();

        // 落下境界チェック
        if (pos.y > boundaries.fallThreshold) {
          // 落下音を再生
          AudioService.instance.playFall();
          resetOtedama();
        }
      }

      // ゴール判定（お手玉の中心がゴール内にあるか、最終ステージのみ）
      if (!goalReached && goal != null && boundaries.isFinalStage) {
        checkGoalReached();
      }

      // 遷移クールダウンを更新
      updateTransitionCooldown(dt);

      // 遷移ゾーン判定
      if (canTransition) {
        checkTransitionZones();
      }
    }

    // パララックス効果を更新
    if (otedama != null) {
      _stageManager.updateParallax(otedama!.centerPosition);
    }
  }

  // --- ドラッグ操作（DragCallbacks）---

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    handleDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    handleDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    handleDragEnd(event);
  }

  // --- EditModeMixin実装 ---

  @override
  void removeStageObject(StageObject obj) {
    _stageManager.removeStageObject(obj);
  }

  // --- スキン ---

  /// スキンを変更
  Future<void> setOtedamaSkin(OtedamaSkin skin) async {
    _otedamaSkin = skin;
    await otedama?.setSkin(skin);
  }

  // --- お手玉操作 ---

  /// お手玉をリセット
  void resetOtedama() {
    // スポーン位置にリセット（JSONで設定した位置）
    otedama?.resetToPosition(Vector2(spawnX, spawnY));
    resetGoalState();
    resetTimer();
    // クールダウンをクリア（リスポーン後は全方向への遷移を許可）
    clearAllCooldowns();
  }

  // --- ステージ管理（委譲） ---

  /// 現在のステージをStageDataにエクスポート
  StageData exportStage() => _stageManager.exportStage();

  /// ステージをクリア
  void clearStage() {
    _stageManager.clearStage(deselectCallback: () {
      deselectObject();
      return null;
    });
    resetGoalState();
  }

  /// 現在のステージを一時保存
  void saveCurrentStageTemporarily() => _stageManager.saveCurrentStageTemporarily();

  /// 指定ステージの一時保存データを取得
  StageData? getUnsavedStage(String assetPath) => _stageManager.getUnsavedStage(assetPath);

  /// 指定ステージの一時保存データをクリア
  void clearUnsavedStage(String assetPath) => _stageManager.clearUnsavedStage(assetPath);

  /// 全ての一時保存データをクリア
  void clearAllUnsavedStages() => _stageManager.clearAllUnsavedStages();

  /// 遷移先ステージに戻り用TransitionZoneを追加
  /// 戻り値: 追加された戻りゾーンのID（元ゾーンのtargetZoneIdに設定する用）
  Future<String?> addReturnTransitionZoneToTargetStage({
    required String targetStageAsset,
    required Vector2 currentZonePosition,
    required String sourceZoneId,
  }) =>
      _stageManager.addReturnTransitionZoneToTargetStage(
        targetStageAsset: targetStageAsset,
        currentZonePosition: currentZonePosition,
        sourceZoneId: sourceZoneId,
      );

  /// StageDataからステージを読み込み
  Future<void> loadStage(
    StageData stageData, {
    String? assetPath,
    TransitionInfo? transitionInfo,
  }) async {
    await _stageManager.loadStage(
      stageData,
      assetPath: assetPath,
      transitionInfo: transitionInfo,
      otedama: otedama,
      changeBackground: (bg) => changeBackground(bg),
      deselectObject: deselectObject,
      setSpawnZoneCooldown: setSpawnZoneCooldown,
      setLineCooldownDirection: setLineCooldownDirection,
    );
    resetGoalState();

    // ステージ遷移後、カメラを即座にお手玉の位置にテレポート
    // これにより、旧位置から新位置への補間中に大量のオブジェクトが
    // 描画対象になることを防ぐ
    if (otedama != null) {
      _cameraController.teleportTo(otedama!.centerPosition);
    }
  }

  /// 背景を変更
  Future<void> changeBackground(String? newBackground) async {
    await _stageManager.changeBackground(newBackground, camera, size);
  }

  /// 環境音変更時のコールバック
  void _onAmbientSoundChanged(String? soundFile, double volume) {
    logger.info(LogCategory.audio, 'Ambient sound changed: $soundFile (volume: $volume)');

    if (soundFile == null || soundFile.isEmpty) {
      // 環境音なしの場合は即時停止（ステージ遷移中のカクつき防止）
      AudioService.instance.stopAmbientImmediate();
      return;
    }

    // 環境音を再生（フルパスに変換、フェードなしで即時切り替え）
    final assetPath = 'audio/environmental_sounds/$soundFile';
    AudioService.instance.playAmbient(assetPath, volume: volume, fadeDuration: 0.0);
  }

  /// BGM変更時のコールバック
  void _onBgmChanged(String? bgmFile, double volume) {
    logger.info(LogCategory.audio, 'BGM changed: $bgmFile (volume: $volume)');

    if (bgmFile == null || bgmFile.isEmpty) {
      // BGMなしの場合はフェードアウト
      AudioService.instance.stopBgm();
      return;
    }

    // BGMを再生（フルパスに変換）
    final assetPath = 'audio/bgm/$bgmFile';
    AudioService.instance.playBgm(assetPath, volume: volume);
  }

  // --- オブジェクト追加（委譲） ---

  /// 画像オブジェクトを追加
  Future<void> addImageObject(String imagePath, {Vector2? position}) async {
    final obj = await _objectBuilder.addImageObject(imagePath, position: position);
    selectObject(obj);
  }

  /// 足場を追加
  Future<void> addPlatform({Vector2? position}) async {
    final obj = await _objectBuilder.addPlatform(position: position);
    selectObject(obj);
  }

  /// トランポリンを追加
  Future<void> addTrampoline({Vector2? position}) async {
    final obj = await _objectBuilder.addTrampoline(position: position);
    selectObject(obj);
  }

  /// 氷床を追加
  Future<void> addIceFloor({Vector2? position}) async {
    final obj = await _objectBuilder.addIceFloor(position: position);
    selectObject(obj);
  }

  /// 地形を追加
  Future<void> addTerrain({Vector2? position}) async {
    final obj = await _objectBuilder.addTerrain(position: position);
    selectObject(obj);
  }

  /// 遷移ゾーンを追加
  Future<void> addTransitionZone({Vector2? position}) async {
    final obj = await _objectBuilder.addTransitionZone(position: position);
    selectObject(obj);
  }

  /// ゴールを追加
  Future<void> addGoal({Vector2? position}) async {
    final obj = await _objectBuilder.addGoal(position: position);
    selectObject(obj);
  }

  /// 小豆を追加
  Future<void> addAzuki({Vector2? position}) async {
    final obj = await _objectBuilder.addAzuki(position: position);
    selectObject(obj);
  }

  /// 遷移ゾーンからの遷移をトリガー（コンポーネントから呼び出し用）
  void triggerZoneTransitionCompat(TransitionZone zone) {
    triggerZoneTransition(zone);
  }
}
