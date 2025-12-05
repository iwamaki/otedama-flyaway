import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';

import '../components/background.dart';
import '../components/stage/goal.dart';
import '../components/stage/image_object.dart';
import '../components/stage/platform.dart';
import '../components/stage/stage_object.dart';
import '../models/stage_data.dart';

/// ステージ管理Mixin
/// ステージの読み込み、保存、オブジェクト追加を担当
mixin StageManagerMixin on Forge2DGame {
  /// ステージオブジェクトのリスト
  final List<StageObject> stageObjects = [];

  /// ゴールオブジェクト
  Goal? stageGoal;

  /// 背景オブジェクト
  Background? stageBackground;

  /// 現在のステージレベル
  int stageLevel = 0;

  /// 現在のステージ名
  String stageName = 'New Stage';

  /// 背景画像のパス
  String? stageBackgroundImage;

  /// スポーン位置
  double spawnX = 0.0;
  double spawnY = 5.0;

  /// UI更新コールバック
  VoidCallback? onStageChanged;

  /// ゴール到達コールバック
  void Function()? onGoalReachedCallback;

  /// ステージオブジェクトを追加（管理リストにも登録）
  Future<void> addStageObject<T extends BodyComponent>(T obj) async {
    await world.add(obj);
    if (obj is StageObject) {
      stageObjects.add(obj as StageObject);
    }
  }

  /// 現在のステージをStageDataにエクスポート
  StageData exportStage() {
    final objects = stageObjects.map((obj) => obj.toJson()).toList();
    return StageData(
      level: stageLevel,
      name: stageName,
      background: stageBackgroundImage,
      spawnX: spawnX,
      spawnY: spawnY,
      objects: objects,
    );
  }

  /// ステージをクリア（全オブジェクト削除）
  void clearStage() {
    // 全オブジェクトを削除
    for (final obj in stageObjects) {
      (obj as dynamic).removeFromParent();
    }
    stageObjects.clear();
    stageGoal = null;

    // ステージ情報をリセット
    stageLevel = 0;
    stageName = 'New Stage';

    onStageChanged?.call();
  }

  /// StageDataからステージを読み込み
  Future<void> loadStage(StageData stageData) async {
    // 既存のステージをクリア
    clearStage();

    // ステージ情報を設定
    stageLevel = stageData.level;
    stageName = stageData.name;
    spawnX = stageData.spawnX;
    spawnY = stageData.spawnY;

    // 背景を変更
    if (stageData.background != stageBackgroundImage) {
      await changeBackground(stageData.background);
    }

    // オブジェクトを配置
    for (final objJson in stageData.objects) {
      final type = objJson['type'] as String?;
      if (type == null) continue;

      switch (type) {
        case 'platform':
          await addStageObject(Platform.fromJson(objJson));
          break;
        case 'image_object':
          await addStageObject(ImageObject.fromJson(objJson));
          break;
        case 'goal':
          stageGoal = Goal.fromJson(objJson);
          await addStageObject(stageGoal!);
          break;
      }
    }

    onStageChanged?.call();
  }

  /// 背景を変更
  Future<void> changeBackground(String? newBackground) async {
    stageBackgroundImage = newBackground;

    // 既存の背景を削除
    if (stageBackground != null) {
      stageBackground!.removeFromParent();
    }

    // 新しい背景を追加
    stageBackground = Background(imagePath: stageBackgroundImage)
      ..size = size
      ..position = Vector2.zero()
      ..priority = -100;
    camera.backdrop.add(stageBackground!);

    onStageChanged?.call();
  }

  /// ゴールを追加
  Future<void> addGoal({Vector2? position}) async {
    // 既存のゴールがあれば削除
    if (stageGoal != null) {
      stageObjects.remove(stageGoal);
      (stageGoal as dynamic).removeFromParent();
    }

    final pos = position ?? camera.viewfinder.position.clone();
    stageGoal = Goal(
      position: pos,
      width: 5,
      height: 4,
      onGoalReached: onGoalReachedCallback,
    );
    await addStageObject(stageGoal!);
  }

  /// 足場を追加
  Future<Platform> addPlatform({Vector2? position}) async {
    final pos = position ?? camera.viewfinder.position.clone();
    final obj = Platform(
      position: pos,
      width: 6.0,
      height: 0.5,
    );
    await addStageObject(obj);
    return obj;
  }

  /// 画像オブジェクトを追加
  Future<ImageObject> addImageObject(String imagePath, {Vector2? position}) async {
    final pos = position ?? camera.viewfinder.position.clone();
    final obj = ImageObject(
      imagePath: imagePath,
      position: pos,
      scale: 0.05,
    );
    await addStageObject(obj);
    return obj;
  }

  /// ステージオブジェクトを削除
  void removeStageObject(StageObject obj) {
    stageObjects.remove(obj);
    if (obj == stageGoal) {
      stageGoal = null;
    }
    (obj as dynamic).removeFromParent();
    onStageChanged?.call();
  }
}
