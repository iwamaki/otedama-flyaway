import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../components/background.dart';
import '../services/logger_service.dart';
import '../components/drag_line.dart';
import '../components/ground.dart';
import '../components/particle_otedama.dart';
import '../components/stage/goal.dart';
import '../components/stage/ice_floor.dart';
import '../components/stage/image_object.dart';
import '../components/stage/platform.dart';
import '../components/stage/stage_object.dart';
import '../components/stage/terrain.dart';
import '../components/stage/trampoline.dart';
import '../components/stage/transition_zone.dart';
import '../config/otedama_skin_config.dart';
import '../config/physics_config.dart';
import '../models/stage_data.dart';
import 'camera_controller.dart';

/// ステージ遷移時の情報
class TransitionInfo {
  /// 次ステージのアセットパス
  final String nextStage;

  /// 遷移時の速度
  final Vector2 velocity;

  /// 遷移先でのスポーン位置（nullの場合はステージのデフォルト）
  final Vector2? spawnPosition;

  const TransitionInfo({
    required this.nextStage,
    required this.velocity,
    this.spawnPosition,
  });
}

/// メインゲームクラス
class OtedamaGame extends Forge2DGame with DragCallbacks {
  ParticleOtedama? otedama;
  DragLine? _dragLine;
  Background? _background;
  Vector2? _dragStart;
  Vector2? _dragCurrent;
  bool _isDraggingOtedama = false; // お手玉をつかんでいるか

  /// カメラコントローラー
  late CameraController _cameraController;

  /// ゴール
  Goal? goal;

  /// ゴール到達フラグ
  bool _goalReached = false;
  bool get goalReached => _goalReached;

  /// タイマー関連
  DateTime? _gameStartTime;
  DateTime? _gameEndTime;
  bool _timerStarted = false;

  /// ゲーム開始からの経過時間（秒）
  double get elapsedSeconds {
    if (_gameStartTime == null) return 0;
    final endTime = _gameEndTime ?? DateTime.now();
    return endTime.difference(_gameStartTime!).inMilliseconds / 1000;
  }

  /// タイマーが開始しているか
  bool get timerStarted => _timerStarted;

  /// クリアタイム（ゴール到達時の経過時間）
  double? _clearTime;
  double? get clearTime => _clearTime;

  /// ゴール到達コールバック（外部通知用）
  VoidCallback? onGoalReachedCallback;

  /// ステージ遷移コールバック（外部通知用）
  void Function(TransitionInfo info)? onStageTransition;

  /// 現在のステージ境界設定
  StageBoundaries _boundaries = const StageBoundaries();
  StageBoundaries get boundaries => _boundaries;
  set boundaries(StageBoundaries value) {
    _boundaries = value;
    onEditModeChanged?.call();
  }

  /// 遷移中フラグ（二重遷移防止）
  bool _isTransitioning = false;

  /// 遷移クールダウン（遷移直後の再遷移を防止）
  double _transitionCooldown = 0.0;
  static const double _transitionCooldownDuration = 1.0; // 1秒

  /// お手玉をつかめる距離（お手玉半径の倍率）
  static const double grabRadiusMultiplier = 1.8;

  /// 背景画像のパス（nullならデフォルト背景）
  String? _backgroundImage;
  String? get currentBackground => _backgroundImage;

  /// 初期ステージのアセットパス
  final String? _initialStageAsset;

  /// 現在のステージレベル
  int currentStageLevel = 0;

  /// 現在のステージ名
  String currentStageName = 'New Stage';

  /// 現在編集中のステージのアセットパス（新規の場合はnull）
  String? _currentStageAsset;
  String? get currentStageAsset => _currentStageAsset;

  /// 一時保存されたステージデータ（assetPath -> StageData）
  final Map<String, StageData> _unsavedStages = {};

  /// 一時保存があるステージのアセットパス一覧
  Set<String> get unsavedStageAssets => _unsavedStages.keys.toSet();

  /// スポーン位置
  double _spawnX = 0.0;
  double _spawnY = 5.0;

  /// 地面オブジェクト（クリア時に再利用）
  Ground? _ground;

  /// お手玉のスキン設定
  OtedamaSkin _otedamaSkin;

  // --- 編集モード ---

  /// 編集モードフラグ
  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  /// 選択中のオブジェクト
  StageObject? _selectedObject;
  StageObject? get selectedObject => _selectedObject;

  /// ステージオブジェクトのリスト
  final List<StageObject> _stageObjects = [];
  List<StageObject> get stageObjects => List.unmodifiable(_stageObjects);

  /// 編集モード中のドラッグ移動
  bool _isDraggingObject = false;
  Vector2? _dragOffset;

  /// UI更新コールバック
  VoidCallback? onEditModeChanged;

  OtedamaGame({
    String? backgroundImage,
    String? initialStageAsset,
    OtedamaSkin? otedamaSkin,
  })  : _backgroundImage = backgroundImage,
        _initialStageAsset = initialStageAsset,
        _otedamaSkin = otedamaSkin ?? OtedamaSkinConfig.defaultSkin,
        super(gravity: Vector2(0, PhysicsConfig.gravityY));

  /// スキンを変更
  Future<void> setOtedamaSkin(OtedamaSkin skin) async {
    _otedamaSkin = skin;
    await otedama?.setSkin(skin);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // カメラ設定
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = CameraConfig.zoom;
    _cameraController = CameraController(camera);

    // 背景を追加（最背面に表示、パララックス効果付き）
    _background = Background(imagePath: _backgroundImage)
      ..size = size
      ..position = Vector2.zero()
      ..priority = -100; // 最背面
    camera.backdrop.add(_background!);

    // ドラッグ線（最前面に表示するためviewportに追加）
    _dragLine = DragLine();
    camera.viewport.add(_dragLine!);

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

  /// 現在の高さ（Y座標の負数、上が正）
  double get currentHeight => -(otedama?.centerPosition.y ?? 0);

  /// 最高到達高さ
  double _maxHeight = 0;
  double get maxHeight => _maxHeight;

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
      if (!_isTransitioning) {
        final pos = otedama!.centerPosition;

        // 遷移境界チェック（優先）
        for (final transition in _boundaries.transitions) {
          if (_checkBoundary(pos, transition.edge, transition.threshold)) {
            _triggerTransition(transition);
            return;
          }
        }

        // 落下境界チェック
        if (pos.y > _boundaries.fallThreshold) {
          resetOtedama();
        }
      }

      // ゴール判定（お手玉の中心がゴール内にあるか、最終ステージのみ）
      if (!_goalReached && goal != null && _boundaries.isFinalStage) {
        _checkGoalReached();
      }

      // 遷移クールダウンを更新
      if (_transitionCooldown > 0) {
        _transitionCooldown -= dt;
      }

      // 遷移ゾーン判定（クールダウン中はスキップ）
      if (!_isTransitioning && _transitionCooldown <= 0) {
        _checkTransitionZones();
      }
    }

    // パララックス効果を更新
    if (otedama != null && _background != null) {
      _background!.updateParallax(otedama!.centerPosition);
    }
  }

  /// ステージの構築（地面のみ）
  Future<void> _buildStage() async {
    // 地面（スタート地点）
    _ground = Ground(
      position: Vector2(0, StageConfig.groundY),
      size: Vector2(StageConfig.groundWidth, 1),
    );
    await world.add(_ground!);
  }

  /// ステージオブジェクトを追加（管理リストにも登録）
  Future<void> _addStageObject<T extends BodyComponent>(T obj) async {
    await world.add(obj);
    if (obj is StageObject) {
      _stageObjects.add(obj as StageObject);
    }
  }

  /// ゴール判定チェック
  void _checkGoalReached() {
    if (goal == null || otedama == null) return;

    final pos = otedama!.centerPosition;
    final goalPos = goal!.position;
    final halfW = goal!.width / 2 - goal!.wallThickness;
    final halfH = goal!.height / 2 - goal!.wallThickness;

    // お手玉の中心がゴール内部にあるか
    if (pos.x >= goalPos.x - halfW &&
        pos.x <= goalPos.x + halfW &&
        pos.y >= goalPos.y - halfH &&
        pos.y <= goalPos.y + halfH) {
      _onGoalReached();
    }
  }

  /// 遷移ゾーン判定チェック
  void _checkTransitionZones() {
    if (otedama == null) return;

    final pos = otedama!.centerPosition;
    final transitionZones = _stageObjects.whereType<TransitionZone>().toList();

    for (final obj in transitionZones) {
      if (obj.nextStage.isNotEmpty) {
        final zonePos = obj.position;
        final halfW = obj.width / 2;
        final halfH = obj.height / 2;

        // お手玉の中心がゾーン内にあるか
        if (pos.x >= zonePos.x - halfW &&
            pos.x <= zonePos.x + halfW &&
            pos.y >= zonePos.y - halfH &&
            pos.y <= zonePos.y + halfH) {
          logger.debug(LogCategory.game,
              '_checkTransitionZones: otedama at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)}) inside zone at (${zonePos.x.toStringAsFixed(1)}, ${zonePos.y.toStringAsFixed(1)})');
          triggerZoneTransition(obj);
          return;
        }
      }
    }
  }

  /// 境界条件をチェック
  bool _checkBoundary(Vector2 pos, BoundaryEdge edge, double threshold) {
    switch (edge) {
      case BoundaryEdge.top:
        return pos.y < threshold;
      case BoundaryEdge.bottom:
        return pos.y > threshold;
      case BoundaryEdge.left:
        return pos.x < threshold;
      case BoundaryEdge.right:
        return pos.x > threshold;
    }
  }

  /// 遷移をトリガー（境界による）
  void _triggerTransition(TransitionBoundary transition) {
    if (_isTransitioning) return;
    _isTransitioning = true;

    final velocity = otedama?.getVelocity() ?? Vector2.zero();
    logger.info(
        LogCategory.game, 'Stage transition: ${transition.edge} -> ${transition.nextStage}, velocity: ${velocity.length.toStringAsFixed(2)}');

    final info = TransitionInfo(
      nextStage: transition.nextStage,
      velocity: velocity,
    );
    onStageTransition?.call(info);
  }

  /// 遷移ゾーンからの遷移をトリガー
  void triggerZoneTransition(TransitionZone zone) {
    logger.debug(LogCategory.game,
        'triggerZoneTransition called: nextStage=${zone.nextStage}, _isTransitioning=$_isTransitioning');

    if (_isTransitioning) {
      logger.debug(LogCategory.game, 'triggerZoneTransition: already transitioning, skipped');
      return;
    }
    _isTransitioning = true;

    final velocity = otedama?.getVelocity() ?? Vector2.zero();
    logger.info(LogCategory.game,
        'Zone transition -> ${zone.nextStage}, velocity: ${velocity.length.toStringAsFixed(2)}');

    // スポーン位置が指定されている場合はそれを使う
    Vector2? spawnPos;
    if (zone.spawnX != null || zone.spawnY != null) {
      spawnPos = Vector2(
        zone.spawnX ?? _spawnX,
        zone.spawnY ?? _spawnY,
      );
      logger.debug(LogCategory.game,
          'Custom spawn position: (${spawnPos.x.toStringAsFixed(1)}, ${spawnPos.y.toStringAsFixed(1)})');
    }

    final info = TransitionInfo(
      nextStage: zone.nextStage,
      velocity: velocity,
      spawnPosition: spawnPos,
    );

    logger.debug(LogCategory.game,
        'TransitionInfo: nextStage=${info.nextStage}, spawnPos=(${spawnPos?.x.toStringAsFixed(1)}, ${spawnPos?.y.toStringAsFixed(1)})');

    if (onStageTransition != null) {
      onStageTransition!.call(info);
    } else {
      logger.warning(LogCategory.game, 'onStageTransition callback is null!');
    }
  }

  /// 遷移状態をリセット（遷移完了後に呼び出す）
  void resetTransitionState() {
    _isTransitioning = false;
  }

  /// タイマー開始
  void _startTimer() {
    _timerStarted = true;
    _gameStartTime = DateTime.now();
    _gameEndTime = null;
    _clearTime = null;
  }

  /// タイマーリセット
  void _resetTimer() {
    _timerStarted = false;
    _gameStartTime = null;
    _gameEndTime = null;
    _clearTime = null;
  }

  /// ゴール到達時の処理（内部用）
  void _onGoalReached() {
    if (!_goalReached) {
      _goalReached = true;
      // タイマー停止＆クリアタイム記録
      _gameEndTime = DateTime.now();
      _clearTime = elapsedSeconds;
      logger.info(LogCategory.game, 'Goal reached! Clear time: ${_clearTime?.toStringAsFixed(2)}s');
      // 外部コールバックを呼び出し
      onGoalReachedCallback?.call();
    }
  }

  /// ゴール到達を通知（Goalコンポーネントから呼ばれる）
  void notifyGoalReached() {
    _onGoalReached();
  }

  // --- ドラッグ操作（パチンコ式発射 / 編集モード） ---

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final touchPos = screenToWorld(event.localPosition);

    // 編集モードの場合
    if (_isEditMode) {
      _handleEditModeDragStart(touchPos);
      return;
    }

    // 通常モード: お手玉をつかめる距離かチェック
    if (otedama != null) {
      // 発射可能かチェック
      if (!otedama!.canLaunch) return;

      final otedamaPos = otedama!.centerPosition;
      final distance = (touchPos - otedamaPos).length;
      final grabRadius = ParticleOtedama.overallRadius * grabRadiusMultiplier;

      if (distance <= grabRadius) {
        // お手玉をつかんだ
        _isDraggingOtedama = true;
        _dragStart = touchPos;
        _dragCurrent = touchPos;

        // スクリーン座標に変換して渡す
        _dragLine?.updateScreen(
          start: worldToScreen(_dragStart!),
          end: worldToScreen(_dragCurrent!),
          isAirLaunch: otedama?.isAirLaunch ?? false,
        );
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final touchPos = screenToWorld(event.localEndPosition);

    // 編集モードの場合
    if (_isEditMode) {
      _handleEditModeDragUpdate(touchPos);
      return;
    }

    if (!_isDraggingOtedama || _dragStart == null) return;

    // 最大引張距離を適用
    final dragVector = touchPos - _dragStart!;
    final distance = dragVector.length;
    if (distance > PhysicsConfig.maxDragDistance) {
      _dragCurrent = _dragStart! + dragVector.normalized() * PhysicsConfig.maxDragDistance;
    } else {
      _dragCurrent = touchPos;
    }

    // スクリーン座標に変換して渡す
    _dragLine?.updateScreen(
      start: worldToScreen(_dragStart!),
      end: worldToScreen(_dragCurrent!),
      isAirLaunch: otedama?.isAirLaunch ?? false,
    );
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    // 編集モードの場合
    if (_isEditMode) {
      _handleEditModeDragEnd();
      return;
    }

    if (_isDraggingOtedama && _dragStart != null && _dragCurrent != null && otedama != null) {
      // スワイプの方向と逆に発射（パチンコ式）
      final otedamaPos = otedama!.centerPosition;
      final diff = otedamaPos - _dragCurrent!;
      // タップ位置に力を加える（回転が発生する）
      otedama!.launch(diff, touchPoint: _dragStart!);

      // 初回発射時にタイマー開始
      if (!_timerStarted) {
        _startTimer();
      }
    }

    // 状態をリセット
    _isDraggingOtedama = false;
    _dragStart = null;
    _dragCurrent = null;
    _dragLine?.clear();
  }

  // --- 編集モード操作 ---

  void _handleEditModeDragStart(Vector2 touchPos) {
    // タッチ位置にあるオブジェクトを探す
    final obj = _findObjectAt(touchPos);

    if (obj != null) {
      // オブジェクトを選択
      selectObject(obj);
      _isDraggingObject = true;
      _dragOffset = touchPos - obj.position;
    } else {
      // 何もない場所をタップ → 選択解除
      deselectObject();
    }
  }

  void _handleEditModeDragUpdate(Vector2 touchPos) {
    if (!_isDraggingObject || _selectedObject == null || _dragOffset == null) return;

    // 選択中のオブジェクトをドラッグ移動
    final newPos = touchPos - _dragOffset!;
    _selectedObject!.applyProperties({
      'x': newPos.x,
      'y': newPos.y,
    });
  }

  void _handleEditModeDragEnd() {
    _isDraggingObject = false;
    _dragOffset = null;
  }

  /// 指定位置にあるオブジェクトを探す
  StageObject? _findObjectAt(Vector2 pos) {
    for (final obj in _stageObjects.reversed) {
      final (min, max) = obj.bounds;
      if (pos.x >= min.x && pos.x <= max.x && pos.y >= min.y && pos.y <= max.y) {
        return obj;
      }
    }
    return null;
  }

  // --- 編集モードAPI ---

  /// 編集モードを切り替え
  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    if (_isEditMode) {
      // 物理を一時停止（重力を0に）
      world.gravity = Vector2.zero();
      // お手玉を静止
      otedama?.freeze();
    } else {
      // 物理を再開
      world.gravity = Vector2(0, PhysicsConfig.gravityY * ParticleOtedama.gravityScale);
      // 選択解除
      deselectObject();
      // お手玉の静止解除
      otedama?.unfreeze();
    }
    onEditModeChanged?.call();
  }

  /// オブジェクトを選択
  void selectObject(StageObject obj) {
    // 既存の選択を解除
    _selectedObject?.isSelected = false;
    // 新しいオブジェクトを選択
    _selectedObject = obj;
    obj.isSelected = true;
    onEditModeChanged?.call();
  }

  /// 選択解除
  void deselectObject() {
    _selectedObject?.isSelected = false;
    _selectedObject = null;
    onEditModeChanged?.call();
  }

  /// 選択中のオブジェクトを削除
  void deleteSelectedObject() {
    if (_selectedObject == null) return;

    final obj = _selectedObject!;
    deselectObject();

    _stageObjects.remove(obj);
    // StageObjectはBodyComponentを継承しているクラスで実装されている
    (obj as dynamic).removeFromParent();
    onEditModeChanged?.call();
  }

  /// オブジェクト追加時のデフォルトYオフセット（上方向）
  static const double _addObjectYOffset = -10.0;

  /// 画像オブジェクトを追加
  Future<void> addImageObject(String imagePath, {Vector2? position}) async {
    final pos = position ?? _getDefaultAddPosition();
    final obj = ImageObject(
      imagePath: imagePath,
      position: pos,
      scale: 0.05,
    );
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// オブジェクト追加のデフォルト位置を取得（カメラ位置の少し上）
  Vector2 _getDefaultAddPosition() {
    final cameraPos = camera.viewfinder.position.clone();
    return Vector2(cameraPos.x, cameraPos.y + _addObjectYOffset);
  }

  /// 足場を追加
  Future<void> addPlatform({Vector2? position}) async {
    final pos = position ?? _getDefaultAddPosition();
    final obj = Platform(
      position: pos,
      width: 6.0,
      height: 0.5,
    );
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// トランポリンを追加
  Future<void> addTrampoline({Vector2? position}) async {
    final pos = position ?? _getDefaultAddPosition();
    final obj = Trampoline(position: pos);
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// 氷床を追加
  Future<void> addIceFloor({Vector2? position}) async {
    final pos = position ?? _getDefaultAddPosition();
    final obj = IceFloor(position: pos);
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// 地形を追加
  Future<void> addTerrain({Vector2? position}) async {
    final pos = position ?? _getDefaultAddPosition();
    final obj = Terrain.rectangle(
      position: pos,
      width: 20.0,
      height: 4.0,
    );
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// 遷移ゾーンを追加
  Future<void> addTransitionZone({Vector2? position}) async {
    final pos = position ?? _getDefaultAddPosition();
    final obj = TransitionZone(
      position: pos,
      width: 5.0,
      height: 5.0,
    );
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// お手玉をリセット
  void resetOtedama() {
    otedama?.reset();
    _goalReached = false;
    _resetTimer();
  }

  // --- ステージ管理 ---

  /// 現在のステージをStageDataにエクスポート
  StageData exportStage() {
    final objects = _stageObjects.map((obj) => obj.toJson()).toList();
    return StageData(
      level: currentStageLevel,
      name: currentStageName,
      background: _backgroundImage,
      spawnX: _spawnX,
      spawnY: _spawnY,
      boundaries: _boundaries,
      objects: objects,
    );
  }

  /// ステージをクリア（全オブジェクト削除）- 外部用
  void clearStage() {
    // 現在のステージを一時保存
    if (_currentStageAsset != null && _stageObjects.isNotEmpty) {
      saveCurrentStageTemporarily();
    }
    _clearStageInternal();
  }

  /// ステージをクリア（内部用、一時保存なし）
  void _clearStageInternal() {
    deselectObject();

    // 全オブジェクトを削除
    for (final obj in _stageObjects) {
      (obj as dynamic).removeFromParent();
    }
    _stageObjects.clear();
    goal = null;

    // ステージ情報をリセット
    _currentStageAsset = null;
    currentStageLevel = 0;
    currentStageName = 'New Stage';
    _goalReached = false;

    onEditModeChanged?.call();
  }

  /// 現在のステージを一時保存
  void saveCurrentStageTemporarily() {
    if (_currentStageAsset != null) {
      final stageData = exportStage();
      _unsavedStages[_currentStageAsset!] = stageData;
      logger.debug(LogCategory.stage, 'Stage saved temporarily: $_currentStageAsset');
    }
  }

  /// 指定ステージの一時保存データを取得
  StageData? getUnsavedStage(String assetPath) {
    return _unsavedStages[assetPath];
  }

  /// 指定ステージの一時保存データをクリア
  void clearUnsavedStage(String assetPath) {
    _unsavedStages.remove(assetPath);
    onEditModeChanged?.call();
  }

  /// 全ての一時保存データをクリア
  void clearAllUnsavedStages() {
    _unsavedStages.clear();
    onEditModeChanged?.call();
  }

  /// 遷移先ステージに戻り用TransitionZoneを追加
  /// [targetStageAsset] 遷移先ステージのアセットパス
  /// [currentZonePosition] 現在のTransitionZoneの位置（戻り時のスポーン位置として使用）
  Future<bool> addReturnTransitionZoneToTargetStage({
    required String targetStageAsset,
    required Vector2 currentZonePosition,
  }) async {
    if (_currentStageAsset == null) {
      logger.warning(LogCategory.stage, 'Cannot add return zone: current stage asset is null');
      return false;
    }

    try {
      // 現在のステージも一時保存（両方に変更を反映するため）
      saveCurrentStageTemporarily();
      logger.debug(LogCategory.stage, 'Current stage saved before adding return zone');

      // 遷移先のステージデータを取得（一時保存があればそれを使用）
      StageData targetStage;
      if (_unsavedStages.containsKey(targetStageAsset)) {
        targetStage = _unsavedStages[targetStageAsset]!;
        logger.debug(LogCategory.stage, 'Using unsaved stage data for: $targetStageAsset');
      } else {
        targetStage = await StageData.loadFromAsset(targetStageAsset);
        logger.debug(LogCategory.stage, 'Loaded stage from asset: $targetStageAsset');
      }

      // 遷移先ステージのスポーン位置の下に戻りゾーンを配置
      final returnZoneX = targetStage.spawnX;
      final returnZoneY = targetStage.spawnY + 5.0;

      // 戻り用TransitionZoneのJSONを作成
      final returnZoneJson = {
        'type': 'transitionZone',
        'x': returnZoneX,
        'y': returnZoneY,
        'width': 5.0,
        'height': 5.0,
        'angle': 0.0,
        'nextStage': _currentStageAsset!,
        'spawnX': currentZonePosition.x,
        'spawnY': currentZonePosition.y,
        'color': 0xFFFF9800, // オレンジ色
      };

      // 新しいオブジェクトリストを作成
      final newObjects = [...targetStage.objects, returnZoneJson];

      // 更新したステージデータを作成
      final updatedStage = targetStage.copyWith(objects: newObjects);

      // 一時保存に保存
      _unsavedStages[targetStageAsset] = updatedStage;
      logger.info(LogCategory.stage,
          'Added return TransitionZone to $targetStageAsset at (${returnZoneX.toStringAsFixed(1)}, ${returnZoneY.toStringAsFixed(1)}) -> $_currentStageAsset');

      onEditModeChanged?.call();
      return true;
    } catch (e) {
      logger.error(LogCategory.stage, 'Failed to add return zone to $targetStageAsset', error: e);
      return false;
    }
  }

  /// StageDataからステージを読み込み
  /// [transitionInfo] が指定された場合、遷移先スポーン位置と速度を維持
  Future<void> loadStage(
    StageData stageData, {
    String? assetPath,
    TransitionInfo? transitionInfo,
  }) async {
    // 現在のステージを一時保存（アセットパスがある場合のみ）
    if (_currentStageAsset != null && _stageObjects.isNotEmpty) {
      saveCurrentStageTemporarily();
    }

    // 既存のステージをクリア（一時保存はしない）
    _clearStageInternal();

    // ステージ情報を設定
    _currentStageAsset = assetPath;
    currentStageLevel = stageData.level;
    currentStageName = stageData.name;
    _spawnX = stageData.spawnX;
    _spawnY = stageData.spawnY;
    _boundaries = stageData.boundaries;

    // 背景を変更
    if (stageData.background != _backgroundImage) {
      await changeBackground(stageData.background);
    }

    // オブジェクトを配置（ファクトリパターン）
    for (final objJson in stageData.objects) {
      final obj = StageObjectFactory.fromJson(objJson);
      if (obj == null) continue;

      // Goalの場合はフィールドに保持
      if (obj is Goal) {
        goal = obj;
      }

      await _addStageObject(obj as BodyComponent);
    }

    // お手玉を新しいスポーン位置に移動（遷移情報があれば速度も維持）
    if (transitionInfo != null) {
      final spawnPos = transitionInfo.spawnPosition ?? Vector2(_spawnX, _spawnY);
      otedama?.resetToPosition(spawnPos, velocity: transitionInfo.velocity);
      logger.debug(LogCategory.game,
          'Otedama positioned at ${spawnPos.x.toStringAsFixed(1)}, ${spawnPos.y.toStringAsFixed(1)} with velocity ${transitionInfo.velocity.length.toStringAsFixed(2)}');

      // 遷移クールダウンを設定（即座に再遷移を防止）
      _transitionCooldown = _transitionCooldownDuration;
      logger.debug(LogCategory.game, 'Transition cooldown set: ${_transitionCooldownDuration}s');
    } else {
      otedama?.resetToPosition(Vector2(_spawnX, _spawnY));
    }

    onEditModeChanged?.call();
  }

  /// 背景を変更
  Future<void> changeBackground(String? newBackground) async {
    _backgroundImage = newBackground;

    // 既存の背景を削除
    if (_background != null) {
      _background!.removeFromParent();
    }

    // 新しい背景を追加
    _background = Background(imagePath: _backgroundImage)
      ..size = size
      ..position = Vector2.zero()
      ..priority = -100;
    camera.backdrop.add(_background!);

    onEditModeChanged?.call();
  }

  /// ゴールを追加
  Future<void> addGoal({Vector2? position}) async {
    // 既存のゴールがあれば削除
    if (goal != null) {
      _stageObjects.remove(goal);
      (goal as dynamic).removeFromParent();
    }

    final pos = position ?? _getDefaultAddPosition();
    goal = Goal(
      position: pos,
      width: 5,
      height: 4,
    );
    await _addStageObject(goal!);
    selectObject(goal!);
  }
}
