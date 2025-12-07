import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../components/background.dart';
import '../../components/particle_otedama.dart';
import '../../components/stage/goal.dart';
import '../../components/stage/stage_object.dart';
import '../../components/stage/transition_zone.dart';
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

  /// 遷移先ステージに戻り用TransitionZoneを追加（または更新）
  /// linkId でペアを特定するため、同じステージ間に複数の遷移ゾーンがあっても正しく対応できる
  /// 戻り値: (成功フラグ, 戻りゾーンの位置) - 位置は元ゾーンのspawnX/Y更新に使用
  Future<(bool, Vector2?)> addReturnTransitionZoneToTargetStage({
    required String targetStageAsset,
    required Vector2 currentZonePosition,
    required String linkId,
  }) async {
    if (_currentStageAsset == null) {
      logger.warning(LogCategory.stage, 'Cannot add return zone: current stage asset is null');
      return (false, null);
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

      // 既存の戻りゾーンを linkId で検索
      // 同じステージ内の場合は、元のゾーン（位置が一致するもの）を除外
      final isSameStage = targetStageAsset == _currentStageAsset;
      final existingReturnZoneIndex = targetStage.objects.indexWhere((obj) {
        if (obj['type'] != 'transitionZone' || obj['linkId'] != linkId) {
          return false;
        }

        if (isSameStage) {
          // 同じステージの場合、元のゾーン（位置が一致）は除外
          final objX = (obj['x'] as num?)?.toDouble() ?? 0.0;
          final objY = (obj['y'] as num?)?.toDouble() ?? 0.0;
          final positionMatches =
              (objX - currentZonePosition.x).abs() < 0.1 &&
              (objY - currentZonePosition.y).abs() < 0.1;
          if (positionMatches) {
            return false; // 元のゾーンなので除外
          }
        }

        return true;
      });

      List<Map<String, dynamic>> newObjects;
      String logMessage;
      Vector2 returnZonePosition;

      if (existingReturnZoneIndex >= 0) {
        // 既存の戻りゾーンがある場合は spawnX/spawnY を更新
        newObjects = List<Map<String, dynamic>>.from(targetStage.objects);
        final existingZone = Map<String, dynamic>.from(newObjects[existingReturnZoneIndex]);
        existingZone['spawnX'] = currentZonePosition.x;
        existingZone['spawnY'] = currentZonePosition.y;
        newObjects[existingReturnZoneIndex] = existingZone;
        // 戻りゾーンの現在位置を取得
        returnZonePosition = Vector2(
          (existingZone['x'] as num?)?.toDouble() ?? 0.0,
          (existingZone['y'] as num?)?.toDouble() ?? 0.0,
        );
        logMessage = 'Updated return TransitionZone (linkId=$linkId) spawn position in $targetStageAsset to (${currentZonePosition.x.toStringAsFixed(1)}, ${currentZonePosition.y.toStringAsFixed(1)})';
      } else {
        // 新規に戻りゾーンを追加
        final returnZoneX = targetStage.spawnX;
        final returnZoneY = targetStage.spawnY + 5.0;
        returnZonePosition = Vector2(returnZoneX, returnZoneY);

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
          'linkId': linkId,
        };
        newObjects = [...targetStage.objects, returnZoneJson];
        logMessage = 'Added return TransitionZone (linkId=$linkId) to $targetStageAsset at (${returnZoneX.toStringAsFixed(1)}, ${returnZoneY.toStringAsFixed(1)}) -> $_currentStageAsset';
      }

      // 更新したステージデータを作成
      final updatedStage = targetStage.copyWith(objects: newObjects);

      // 一時保存に保存
      _unsavedStages[targetStageAsset] = updatedStage;
      logger.info(LogCategory.stage, logMessage);

      onChanged?.call();
      return (true, returnZonePosition);
    } catch (e) {
      logger.error(LogCategory.stage, 'Failed to add/update return zone to $targetStageAsset', error: e);
      return (false, null);
    }
  }

  /// TransitionZone の位置変更時にペアのゾーンの spawnX/Y を自動同期
  /// 同じステージ内のペアゾーン、および一時保存されたクロスステージのペアゾーンを更新
  void syncTransitionZonePair(TransitionZone movedZone) {
    final newPosition = movedZone.position;
    final linkId = movedZone.linkId;
    final nextStage = movedZone.nextStage;

    if (linkId.isEmpty) return;

    // 1. 同じステージ内のペアゾーンを更新
    for (final obj in _stageObjects) {
      if (obj is TransitionZone &&
          obj.linkId == linkId &&
          obj != movedZone) {
        // ペアゾーンの spawnX/Y を移動したゾーンの位置に更新
        obj.spawnX = newPosition.x;
        obj.spawnY = newPosition.y;
        logger.debug(LogCategory.stage,
            'Synced same-stage pair: updated spawnX/Y to (${newPosition.x.toStringAsFixed(1)}, ${newPosition.y.toStringAsFixed(1)})');
      }
    }

    // 2. クロスステージのペアゾーンを更新（一時保存データ内）
    if (nextStage.isNotEmpty && nextStage != _currentStageAsset) {
      _syncCrossStageZone(nextStage, linkId, newPosition);
    }

    // 3. 現在のステージが一時保存の対象になっている他ステージからの参照を更新
    if (_currentStageAsset != null) {
      for (final entry in _unsavedStages.entries) {
        if (entry.key == _currentStageAsset) continue;
        _syncCrossStageZone(entry.key, linkId, newPosition);
      }
    }
  }

  /// クロスステージのゾーンの spawnX/Y を更新（一時保存データ内）
  void _syncCrossStageZone(String stageAsset, String linkId, Vector2 newPosition) {
    final stageData = _unsavedStages[stageAsset];
    if (stageData == null) return;

    bool updated = false;
    final newObjects = stageData.objects.map((obj) {
      if (obj['type'] == 'transitionZone' && obj['linkId'] == linkId) {
        final updatedObj = Map<String, dynamic>.from(obj);
        updatedObj['spawnX'] = newPosition.x;
        updatedObj['spawnY'] = newPosition.y;
        updated = true;
        return updatedObj;
      }
      return obj;
    }).toList();

    if (updated) {
      _unsavedStages[stageAsset] = stageData.copyWith(objects: newObjects);
      logger.debug(LogCategory.stage,
          'Synced cross-stage pair in $stageAsset: updated spawnX/Y to (${newPosition.x.toStringAsFixed(1)}, ${newPosition.y.toStringAsFixed(1)})');
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
