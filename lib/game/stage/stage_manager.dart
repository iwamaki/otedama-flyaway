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

  /// 背景の暗さ（0.0〜1.0）
  double _backgroundDarkness = 0.0;
  double get backgroundDarkness => _backgroundDarkness;
  set backgroundDarkness(double value) {
    _backgroundDarkness = value.clamp(0.0, 1.0);
    _background?.darkness = _backgroundDarkness;
    onChanged?.call();
  }

  /// 現在の環境音パス
  String? _ambientSound;
  String? get ambientSound => _ambientSound;

  /// 現在の環境音音量
  double _ambientSoundVolume = 0.5;
  double get ambientSoundVolume => _ambientSoundVolume;

  /// 現在のBGMパス
  String? _bgm;
  String? get bgm => _bgm;

  /// 現在のBGM音量
  double _bgmVolume = 0.4;
  double get bgmVolume => _bgmVolume;

  /// 環境音変更時コールバック
  void Function(String?, double)? onAmbientSoundChanged;

  /// BGM変更時コールバック（nullなら変更なし＝継続）
  void Function(String?, double)? onBgmChanged;

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
      backgroundDarkness: _backgroundDarkness,
      ambientSound: _ambientSound,
      ambientSoundVolume: _ambientSoundVolume,
      bgm: _bgm,
      bgmVolume: _bgmVolume,
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
    required void Function(String zoneId, double cx, double cy, double halfW, double halfH, bool isLine) setSpawnZoneCooldown,
    required void Function(String zoneId, bool isDownward) setLineCooldownDirection,
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

    // 背景の暗さを設定
    _backgroundDarkness = stageData.backgroundDarkness;
    _background?.darkness = _backgroundDarkness;

    // 環境音を変更
    final newAmbientSound = stageData.ambientSound;
    final newAmbientVolume = stageData.ambientSoundVolume;
    if (newAmbientSound != _ambientSound ||
        newAmbientVolume != _ambientSoundVolume) {
      _ambientSound = newAmbientSound;
      _ambientSoundVolume = newAmbientVolume;
      onAmbientSoundChanged?.call(_ambientSound, _ambientSoundVolume);
    }

    // BGMを変更（nullなら変更しない＝継続）
    final newBgm = stageData.bgm;
    final newBgmVolume = stageData.bgmVolume;
    if (newBgm != null && (newBgm != _bgm || newBgmVolume != _bgmVolume)) {
      _bgm = newBgm;
      _bgmVolume = newBgmVolume;
      onBgmChanged?.call(_bgm, _bgmVolume);
    }

    // オブジェクトを配置（ファクトリパターン）- 並列化
    final objectsToAdd = <BodyComponent>[];
    for (final objJson in stageData.objects) {
      final obj = StageObjectFactory.fromJson(objJson);
      if (obj == null) continue;

      // Goalの場合はフィールドに保持
      if (obj is Goal) {
        goal = obj;
      }

      objectsToAdd.add(obj as BodyComponent);
    }

    // 全オブジェクトを並列で追加
    await Future.wait(objectsToAdd.map((obj) => addStageObject(obj)));

    // お手玉を新しいスポーン位置に移動（遷移情報があれば速度も維持）
    if (transitionInfo != null) {
      // targetZoneIdで対応する遷移ゾーンを探し、そのゾーンの位置をスポーン位置として使用
      Vector2 spawnPos = Vector2(spawnX, spawnY);
      if (transitionInfo.targetZoneId != null) {
        // targetZoneIdと一致するidを持つゾーンを探す
        final matchingZone = _stageObjects
            .whereType<TransitionZone>()
            .where((zone) => zone.id == transitionInfo.targetZoneId)
            .firstOrNull;
        if (matchingZone != null) {
          // 対応するゾーンの位置をスポーン位置として使用
          final zonePos = matchingZone.position;

          if (matchingZone.isLine) {
            // ライン判定ゾーン：Y座標をオフセットしてライン上にスポーンしないようにする
            // 速度の方向に基づいてオフセット方向を決定
            // velocity.y >= 0（下方向）→ ラインの少し上にスポーン
            // velocity.y < 0（上方向）→ ラインの少し下にスポーン
            const spawnOffset = 0.5;
            final yOffset = transitionInfo.velocity.y >= 0 ? -spawnOffset : spawnOffset;

            // X座標は相対X座標があれば適用
            double spawnXPos = zonePos.x;
            if (transitionInfo.relativeX != null) {
              final halfW = matchingZone.width / 2;
              final clampedRelativeX = transitionInfo.relativeX!.clamp(-halfW, halfW);
              spawnXPos = zonePos.x + clampedRelativeX;
            }

            spawnPos = Vector2(spawnXPos, zonePos.y + yOffset);
            logger.debug(LogCategory.stage,
                'Spawn position resolved from line zone ${transitionInfo.targetZoneId}: '
                'zonePos=(${zonePos.x.toStringAsFixed(1)}, ${zonePos.y.toStringAsFixed(1)}), '
                'yOffset=$yOffset, '
                'final=(${spawnPos.x.toStringAsFixed(1)}, ${spawnPos.y.toStringAsFixed(1)})');
          } else {
            // 面判定ゾーン：ゾーン中心にスポーン
            spawnPos = zonePos.clone();
            logger.debug(LogCategory.stage,
                'Spawn position resolved from targetZoneId=${transitionInfo.targetZoneId}: (${spawnPos.x.toStringAsFixed(1)}, ${spawnPos.y.toStringAsFixed(1)})');
          }

          // リスポーン位置も設定（ゾーンにrespawnPositionがあればそれを使用）
          final respawnPos = matchingZone.respawnPosition;
          if (respawnPos != null) {
            spawnX = respawnPos.$1;
            spawnY = respawnPos.$2;
            logger.debug(LogCategory.stage,
                'Respawn position set from zone: (${spawnX.toStringAsFixed(1)}, ${spawnY.toStringAsFixed(1)})');
          }
        } else {
          logger.warning(LogCategory.stage,
              'No matching zone found for targetZoneId=${transitionInfo.targetZoneId}, using stage default');
        }
      }

      otedama?.resetToPosition(spawnPos, velocity: transitionInfo.velocity);
      logger.debug(LogCategory.game,
          'Otedama positioned at ${spawnPos.x.toStringAsFixed(1)}, ${spawnPos.y.toStringAsFixed(1)} with velocity ${transitionInfo.velocity.length.toStringAsFixed(2)}');

      // スポーン先ゾーンのクールダウンを設定
      if (transitionInfo.targetZoneId != null) {
        final matchingZone = _stageObjects
            .whereType<TransitionZone>()
            .where((zone) => zone.id == transitionInfo.targetZoneId)
            .firstOrNull;
        if (matchingZone != null) {
          if (matchingZone.isLine) {
            // ライン判定ゾーン：速度のY成分から到来方向を判定してクールダウン設定
            // velocity.y > 0 → 下方向に移動中（上から来た）→ downward = true
            // velocity.y < 0 → 上方向に移動中（下から来た）→ downward = false
            final isDownward = transitionInfo.velocity.y >= 0;
            setLineCooldownDirection(matchingZone.id, isDownward);
            logger.debug(LogCategory.stage,
                'Line zone cooldown set: ${matchingZone.id}, isDownward=$isDownward (velocity.y=${transitionInfo.velocity.y.toStringAsFixed(2)})');
          } else {
            // 面判定ゾーン：位置ベースクールダウン
            setSpawnZoneCooldown(
              matchingZone.id,
              matchingZone.position.x,
              matchingZone.position.y,
              matchingZone.width / 2,
              matchingZone.height / 2,
              false,
            );
          }
        }
      }
    } else {
      otedama?.resetToPosition(Vector2(spawnX, spawnY));
    }

    onChanged?.call();
  }

  /// 遷移先ステージに戻り用TransitionZoneを追加
  /// 戻り値: 追加された戻りゾーンのID（元ゾーンのtargetZoneIdに設定する用）
  Future<String?> addReturnTransitionZoneToTargetStage({
    required String targetStageAsset,
    required Vector2 currentZonePosition,
    required String sourceZoneId,
  }) async {
    if (_currentStageAsset == null) {
      logger.warning(LogCategory.stage, 'Cannot add return zone: current stage asset is null');
      return null;
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

      // 既存の戻りゾーンを targetZoneId で検索（このゾーンへ戻るゾーン）
      final existingReturnZone = targetStage.objects.firstWhere(
        (obj) => obj['type'] == 'transitionZone' && obj['targetZoneId'] == sourceZoneId,
        orElse: () => <String, dynamic>{},
      );

      if (existingReturnZone.isNotEmpty) {
        // 既存の戻りゾーンがある - そのIDを返す
        final existingId = existingReturnZone['id'] as String?;
        logger.debug(LogCategory.stage,
            'Return zone already exists with id=$existingId targeting $sourceZoneId in $targetStageAsset');
        return existingId;
      }

      // 新規に戻りゾーンを追加
      final returnZoneId = TransitionZone.generateId();
      final returnZoneX = currentZonePosition.x;
      final returnZoneY = currentZonePosition.y;

      final returnZoneJson = {
        'type': 'transitionZone',
        'x': returnZoneX,
        'y': returnZoneY,
        'width': 5.0,
        'height': 5.0,
        'angle': 0.0,
        'nextStage': _currentStageAsset!,
        'id': returnZoneId,
        'targetZoneId': sourceZoneId,
      };
      final newObjects = [...targetStage.objects, returnZoneJson];

      // 更新したステージデータを作成
      final updatedStage = targetStage.copyWith(objects: newObjects);

      // 一時保存に保存
      _unsavedStages[targetStageAsset] = updatedStage;
      logger.info(LogCategory.stage,
          'Added return TransitionZone (id=$returnZoneId, targetZoneId=$sourceZoneId) to $targetStageAsset at (${returnZoneX.toStringAsFixed(1)}, ${returnZoneY.toStringAsFixed(1)}) -> $_currentStageAsset');

      onChanged?.call();
      return returnZoneId;
    } catch (e) {
      logger.error(LogCategory.stage, 'Failed to add return zone to $targetStageAsset', error: e);
      return null;
    }
  }

  /// 背景を初期化
  Future<void> initBackground(CameraComponent camera, Vector2 size) async {
    // 画像を事前に読み込む
    final preloadedImage = await Background.preloadImage(_backgroundImage);

    _background = Background(
      imagePath: _backgroundImage,
      preloadedImage: preloadedImage,
      darkness: _backgroundDarkness,
    )
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

    // 画像を事前に読み込む
    final preloadedImage = await Background.preloadImage(_backgroundImage);

    // 新しい背景を追加
    _background = Background(
      imagePath: _backgroundImage,
      preloadedImage: preloadedImage,
      darkness: _backgroundDarkness,
    )
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
