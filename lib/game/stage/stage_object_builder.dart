import 'package:flame/components.dart';

import '../../components/stage/goal.dart';
import '../../components/stage/ice_floor.dart';
import '../../components/stage/image_object.dart';
import '../../components/stage/platform.dart';
import '../../components/stage/terrain.dart';
import '../../components/stage/trampoline.dart';
import '../../components/stage/transition_zone.dart';
import 'stage_manager.dart';

/// ステージオブジェクトを生成するビルダークラス
class StageObjectBuilder {
  final StageManager stageManager;
  final CameraComponent camera;

  /// オブジェクト追加時のデフォルトYオフセット（上方向）
  static const double addObjectYOffset = -10.0;

  StageObjectBuilder({
    required this.stageManager,
    required this.camera,
  });

  /// オブジェクト追加のデフォルト位置を取得（カメラ位置の少し上）
  Vector2 getDefaultAddPosition() {
    final cameraPos = camera.viewfinder.position.clone();
    return Vector2(cameraPos.x, cameraPos.y + addObjectYOffset);
  }

  /// 画像オブジェクトを追加
  Future<ImageObject> addImageObject(String imagePath, {Vector2? position}) async {
    final pos = position ?? getDefaultAddPosition();
    final obj = ImageObject(
      imagePath: imagePath,
      position: pos,
      scale: 0.05,
    );
    await stageManager.addStageObject(obj);
    return obj;
  }

  /// 足場を追加
  Future<Platform> addPlatform({Vector2? position}) async {
    final pos = position ?? getDefaultAddPosition();
    final obj = Platform(
      position: pos,
      width: 6.0,
      height: 0.5,
    );
    await stageManager.addStageObject(obj);
    return obj;
  }

  /// トランポリンを追加
  Future<Trampoline> addTrampoline({Vector2? position}) async {
    final pos = position ?? getDefaultAddPosition();
    final obj = Trampoline(position: pos);
    await stageManager.addStageObject(obj);
    return obj;
  }

  /// 氷床を追加
  Future<IceFloor> addIceFloor({Vector2? position}) async {
    final pos = position ?? getDefaultAddPosition();
    final obj = IceFloor(position: pos);
    await stageManager.addStageObject(obj);
    return obj;
  }

  /// 地形を追加
  Future<Terrain> addTerrain({Vector2? position}) async {
    final pos = position ?? getDefaultAddPosition();
    final obj = Terrain.rectangle(
      position: pos,
      width: 20.0,
      height: 4.0,
    );
    await stageManager.addStageObject(obj);
    return obj;
  }

  /// 遷移ゾーンを追加
  Future<TransitionZone> addTransitionZone({Vector2? position}) async {
    final pos = position ?? getDefaultAddPosition();
    final obj = TransitionZone(
      position: pos,
      width: 5.0,
      height: 5.0,
    );
    await stageManager.addStageObject(obj);
    return obj;
  }

  /// ゴールを追加
  Future<Goal> addGoal({Vector2? position}) async {
    // 既存のゴールがあれば削除
    if (stageManager.goal != null) {
      stageManager.removeStageObject(stageManager.goal!);
    }

    final pos = position ?? getDefaultAddPosition();
    final goal = Goal(
      position: pos,
      width: 5,
      height: 4,
    );
    await stageManager.addStageObject(goal);
    stageManager.goal = goal;
    return goal;
  }
}
