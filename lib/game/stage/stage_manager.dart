import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../components/background.dart';
import '../../components/particle_otedama.dart';
import '../../components/stage/goal.dart';
import '../../components/stage/stage_object.dart';
import '../../models/stage_data.dart';
import '../../models/transition_info.dart';
import '../../services/logger_service.dart';

/// ステージ管理クラス
/// ステージの読み込み、保存、クリア、一時保存を担当
class StageManager {
  final Forge2DGame game;

  /// 現在のステージレベル
  int currentStageLevel = 0;

  /// 現在のステージ名
  String currentStageName = 'New Stage';

  /// 現在編集中のステージのアセットパス（新規の場合はnull）
  String? _currentStageAsset;
  String? get currentStageAsset => _currentStageAsset;

  /// スポーン位置
  double spawnX = 0.0;
  double spawnY = 5.0;

  /// 現在のステージ境界設定
  StageBoundaries _boundaries = const StageBoundaries();
  StageBoundaries get boundaries => _boundaries;
  set boundaries(StageBoundaries value) {
    _boundaries = value;
    onChanged?.call();
  }

  /// 背景画像のパス
  String? _backgroundImage;
  String? get backgroundImage => _backgroundImage;

  /// 一時保存されたステージデータ（assetPath -> StageData）
  final Map<String, StageData> _unsavedStages = {};

  /// 一時保存があるステージのアセットパス一覧
  Set<String> get unsavedStageAssets => _unsavedStages.keys.toSet();

  /// ステージオブジェクトのリスト
  final List<StageObject> _stageObjects = [];
  List<StageObject> get stageObjects => List.unmodifiable(_stageObjects);

  /// ゴールへの参照
  Goal? goal;

  /// 背景コンポーネント
  Background? _background;

  /// 変更時コールバック
  VoidCallback? onChanged;

  StageManager(this.game, {String? backgroundImage}) : _backgroundImage = backgroundImage;

  /// 現在のステージをStageDataにエクスポート
  StageData exportStage() {
    final objects = _stageObjects.map((obj) => obj.toJson()).toList();
    return StageData(
      level: currentStageLevel,
      name: currentStageName,
      background: _backgroundImage,
      spawnX: spawnX,
      spawnY: spawnY,
      boundaries: _boundaries,
      objects: objects,
    );
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
    onChanged?.call();
  }

  /// 全ての一時保存データをクリア
  void clearAllUnsavedStages() {
    _unsavedStages.clear();
    onChanged?.call();
  }

  /// ステージオブジェクトを追加（管理リストにも登録）
  Future<void> addStageObject<T extends BodyComponent>(T obj) async {
    await game.world.add(obj);
    if (obj is StageObject) {
      _stageObjects.add(obj as StageObject);
    }
  }

  /// ステージオブジェクトを削除
  void removeStageObject(StageObject obj) {
    _stageObjects.remove(obj);
    (obj as dynamic).removeFromParent();
  }

  /// ステージをクリア（全オブジェクト削除）- 外部用
  void clearStage({StageObject? Function()? deselectCallback}) {
    // 現在のステージを一時保存
    if (_currentStageAsset != null && _stageObjects.isNotEmpty) {
      saveCurrentStageTemporarily();
    }
    _clearStageInternal(deselectCallback: deselectCallback);
  }

  /// ステージをクリア（内部用、一時保存なし）
  void _clearStageInternal({StageObject? Function()? deselectCallback}) {
    deselectCallback?.call();

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

    onChanged?.call();
  }

  /// StageDataからステージを読み込み
  Future<void> loadStage(
    StageData stageData, {
    String? assetPath,
    TransitionInfo? transitionInfo,
    ParticleOtedama? otedama,
    required Future<void> Function(String?) changeBackground,
    required void Function() deselectObject,
    required void Function() setTransitionCooldown,
  }) async {
    // 現在のステージを一時保存（アセットパスがある場合のみ）
    if (_currentStageAsset != null && _stageObjects.isNotEmpty) {
      saveCurrentStageTemporarily();
    }

    // 既存のステージをクリア（一時保存はしない）
    _clearStageInternal(deselectCallback: () {
      deselectObject();
      return null;
    });

    // ステージ情報を設定
    _currentStageAsset = assetPath;
    currentStageLevel = stageData.level;
    currentStageName = stageData.name;
    spawnX = stageData.spawnX;
    spawnY = stageData.spawnY;
    _boundaries = stageData.boundaries;

    // 背景を変更
    if (stageData.background != _backgroundImage) {
      _backgroundImage = stageData.background;
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

      await addStageObject(obj as BodyComponent);
    }

    // お手玉を新しいスポーン位置に移動（遷移情報があれば速度も維持）
    if (transitionInfo != null) {
      final spawnPos = transitionInfo.spawnPosition ?? Vector2(spawnX, spawnY);
      otedama?.resetToPosition(spawnPos, velocity: transitionInfo.velocity);
      logger.debug(LogCategory.game,
          'Otedama positioned at ${spawnPos.x.toStringAsFixed(1)}, ${spawnPos.y.toStringAsFixed(1)} with velocity ${transitionInfo.velocity.length.toStringAsFixed(2)}');

      // 遷移クールダウンを設定
      setTransitionCooldown();
    } else {
      otedama?.resetToPosition(Vector2(spawnX, spawnY));
    }

    onChanged?.call();
  }

  /// 遷移先ステージに戻り用TransitionZoneを追加
  Future<bool> addReturnTransitionZoneToTargetStage({
    required String targetStageAsset,
    required Vector2 currentZonePosition,
  }) async {
    if (_currentStageAsset == null) {
      logger.warning(LogCategory.stage, 'Cannot add return zone: current stage asset is null');
      return false;
    }

    try {
      // 現在のステージも一時保存
      saveCurrentStageTemporarily();
      logger.debug(LogCategory.stage, 'Current stage saved before adding return zone');

      // 遷移先のステージデータを取得
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
        'color': 0xFFFF9800,
      };

      // 新しいオブジェクトリストを作成
      final newObjects = [...targetStage.objects, returnZoneJson];

      // 更新したステージデータを作成
      final updatedStage = targetStage.copyWith(objects: newObjects);

      // 一時保存に保存
      _unsavedStages[targetStageAsset] = updatedStage;
      logger.info(LogCategory.stage,
          'Added return TransitionZone to $targetStageAsset at (${returnZoneX.toStringAsFixed(1)}, ${returnZoneY.toStringAsFixed(1)}) -> $_currentStageAsset');

      onChanged?.call();
      return true;
    } catch (e) {
      logger.error(LogCategory.stage, 'Failed to add return zone to $targetStageAsset', error: e);
      return false;
    }
  }

  /// 背景を初期化
  Future<void> initBackground(CameraComponent camera, Vector2 size) async {
    _background = Background(imagePath: _backgroundImage)
      ..size = size
      ..position = Vector2.zero()
      ..priority = -100;
    camera.backdrop.add(_background!);
  }

  /// 背景を変更
  Future<void> changeBackground(String? newBackground, CameraComponent camera, Vector2 size) async {
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

    onChanged?.call();
  }

  /// パララックス効果を更新
  void updateParallax(Vector2 otedamaPosition) {
    _background?.updateParallax(otedamaPosition);
  }
}
