import 'package:flame/camera.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../config/physics_config.dart';

/// カメラ追従コントローラー
/// ターゲットにスムーズに追従するカメラ制御を提供
class CameraController {
  final CameraComponent camera;

  CameraController(this.camera);

  /// カメラをターゲット位置に追従させる
  /// [targetPosition] 追従するターゲットの位置
  void follow(Vector2 targetPosition) {
    final currentPos = camera.viewfinder.position;
    final diff = targetPosition - currentPos;

    // デッドゾーン内なら追従しない
    if (diff.length < CameraConfig.deadZone) return;

    // Lerp補間でスムーズに追従
    final newPos = currentPos + diff * CameraConfig.followLerpSpeed;
    camera.viewfinder.position = newPos;
  }
}
