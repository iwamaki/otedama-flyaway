import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/drag_line.dart';
import '../components/ground.dart';
import '../components/particle_otedama.dart';
import '../components/stage/goal.dart';
import '../components/stage/stage_object.dart';
import '../components/stage/transition_zone.dart';
import '../config/otedama_skin_config.dart';
import '../config/physics_config.dart';
import '../models/stage_data.dart';
import '../models/transition_info.dart';
import '../services/logger_service.dart';
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

  /// 地面オブジェクト
  Ground? _ground;

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

  /// 現在の高さ（Y座標の負数、上が正）
  double get currentHeight => -(otedama?.centerPosition.y ?? 0);

  /// 最高到達高さ
  double _maxHeight = 0;
  double get maxHeight => _maxHeight;

  // --- ライフサイクル ---

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // カメラ設定
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = CameraConfig.zoom;
    _cameraController = CameraController(camera);

    // ステージマネージャーを初期化
    _stageManager = StageManager(this, backgroundImage: _initialBackgroundImage);
    _stageManager.onChanged = () => onEditModeChanged?.call();

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

    // ステージを構築（地面のみ）
    await _buildStage();

    // お手玉を配置（粒子ベース）
    otedama = ParticleOtedama(
      position: Vector2(StageConfig.spawnX, StageConfig.spawnY),
      skin: _otedamaSkin,
    );
    await world.add(otedama!);

    // 初期ステージが指定されている場合は読み込む
    if (_initialStageAsset != null) {
      try {
        final stageData = await StageData.loadFromAsset(_initialStageAsset);
        await loadStage(stageData, assetPath: _initialStageAsset);
      } catch (e) {
        logger.error(LogCategory.stage, 'Failed to load initial stage', error: e);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 重力スケールを適用
    world.gravity = Vector2(0, PhysicsConfig.gravityY * ParticleOtedama.gravityScale);

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
        checkTransitionZones(_stageManager.spawnX, _stageManager.spawnY);
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

  // --- ステージ構築 ---

  /// ステージの構築（地面のみ）
  Future<void> _buildStage() async {
    _ground = Ground(
      position: Vector2(0, StageConfig.groundY),
      size: Vector2(StageConfig.groundWidth, 1),
    );
    await world.add(_ground!);
  }

  // --- お手玉操作 ---

  /// お手玉をリセット
  void resetOtedama() {
    otedama?.reset();
    resetGoalState();
    resetTimer();
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
  /// 戻り値: (成功フラグ, 戻りゾーンの位置)
  Future<(bool, Vector2?)> addReturnTransitionZoneToTargetStage({
    required String targetStageAsset,
    required Vector2 currentZonePosition,
    required String linkId,
  }) =>
      _stageManager.addReturnTransitionZoneToTargetStage(
        targetStageAsset: targetStageAsset,
        currentZonePosition: currentZonePosition,
        linkId: linkId,
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
      setTransitionCooldown: setTransitionCooldown,
    );
    resetGoalState();
  }

  /// 背景を変更
  Future<void> changeBackground(String? newBackground) async {
    await _stageManager.changeBackground(newBackground, camera, size);
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

  /// 遷移ゾーンからの遷移をトリガー（1引数版、コンポーネントから呼び出し用）
  void triggerZoneTransitionCompat(TransitionZone zone) {
    triggerZoneTransition(zone, _stageManager.spawnX, _stageManager.spawnY);
  }
}
