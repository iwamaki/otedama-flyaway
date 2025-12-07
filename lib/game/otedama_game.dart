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
import '../config/otedama_skin_config.dart';
import '../config/physics_config.dart';
import '../models/stage_data.dart';
import 'camera_controller.dart';

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
  void Function(String nextStageAsset)? onStageTransition;

  /// 現在のステージ境界設定
  StageBoundaries _boundaries = const StageBoundaries();

  /// 遷移中フラグ（二重遷移防止）
  bool _isTransitioning = false;

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
        await loadStage(stageData);
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

  /// 遷移をトリガー
  void _triggerTransition(TransitionBoundary transition) {
    if (_isTransitioning) return;
    _isTransitioning = true;
    logger.info(
        LogCategory.game, 'Stage transition: ${transition.edge} -> ${transition.nextStage}');
    onStageTransition?.call(transition.nextStage);
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

  /// 画像オブジェクトを追加
  Future<void> addImageObject(String imagePath, {Vector2? position}) async {
    final pos = position ?? camera.viewfinder.position.clone();
    final obj = ImageObject(
      imagePath: imagePath,
      position: pos,
      scale: 0.05,
    );
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// 足場を追加
  Future<void> addPlatform({Vector2? position}) async {
    final pos = position ?? camera.viewfinder.position.clone();
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
    final pos = position ?? camera.viewfinder.position.clone();
    final obj = Trampoline(position: pos);
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// 氷床を追加
  Future<void> addIceFloor({Vector2? position}) async {
    final pos = position ?? camera.viewfinder.position.clone();
    final obj = IceFloor(position: pos);
    await _addStageObject(obj);
    selectObject(obj);
  }

  /// 地形を追加
  Future<void> addTerrain({Vector2? position}) async {
    final pos = position ?? camera.viewfinder.position.clone();
    final obj = Terrain.rectangle(
      position: pos,
      width: 20.0,
      height: 4.0,
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
      objects: objects,
    );
  }

  /// ステージをクリア（全オブジェクト削除）
  void clearStage() {
    deselectObject();

    // 全オブジェクトを削除
    for (final obj in _stageObjects) {
      (obj as dynamic).removeFromParent();
    }
    _stageObjects.clear();
    goal = null;

    // ステージ情報をリセット
    currentStageLevel = 0;
    currentStageName = 'New Stage';
    _goalReached = false;

    onEditModeChanged?.call();
  }

  /// StageDataからステージを読み込み
  Future<void> loadStage(StageData stageData) async {
    // 既存のステージをクリア
    clearStage();

    // ステージ情報を設定
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

    // お手玉を新しいスポーン位置に移動
    otedama?.resetToPosition(Vector2(_spawnX, _spawnY));

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

    final pos = position ?? camera.viewfinder.position.clone();
    goal = Goal(
      position: pos,
      width: 5,
      height: 4,
    );
    await _addStageObject(goal!);
    selectObject(goal!);
  }
}
