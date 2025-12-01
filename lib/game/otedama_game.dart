import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../components/background.dart';
import '../components/drag_line.dart';
import '../components/ground.dart';
import '../components/particle_otedama.dart';
import '../components/wall.dart';
import '../config/physics_config.dart';

/// メインゲームクラス
class OtedamaGame extends Forge2DGame with DragCallbacks {
  ParticleOtedama? otedama;
  DragLine? _dragLine;
  Background? _background;
  Vector2? _dragStart;
  Vector2? _dragCurrent;

  /// 背景画像のパス（nullならデフォルト背景）
  final String? backgroundImage;

  OtedamaGame({this.backgroundImage})
      : super(gravity: Vector2(0, PhysicsConfig.gravityY));

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // カメラ設定
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = CameraConfig.zoom;

    // 背景を追加（最背面に表示、パララックス効果付き）
    _background = Background(imagePath: backgroundImage)
      ..size = size
      ..position = Vector2.zero()
      ..priority = -100; // 最背面
    camera.backdrop.add(_background!);

    // ドラッグ線（ワールド座標で描画）
    _dragLine = DragLine();
    await world.add(_dragLine!);

    // ステージを構築
    await _buildStage();

    // お手玉を配置（粒子ベース）
    otedama = ParticleOtedama(position: Vector2(0, -5));
    await world.add(otedama!);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 重力スケールを適用
    world.gravity = Vector2(0, PhysicsConfig.gravityY * ParticleOtedama.gravityScale);

    // パララックス効果を更新
    if (otedama != null && _background != null) {
      _background!.updateParallax(otedama!.centerPosition);
    }
  }

  /// ステージの構築
  Future<void> _buildStage() async {
    // 地面
    await world.add(Ground(
      position: Vector2(0, StageConfig.groundY),
      size: Vector2(StageConfig.groundWidth, 1),
    ));

    // 左の壁
    await world.add(Wall(
      position: Vector2(-StageConfig.wallX, 0),
      size: Vector2(1, StageConfig.wallHeight),
    ));

    // 右の壁
    await world.add(Wall(
      position: Vector2(StageConfig.wallX, 0),
      size: Vector2(1, StageConfig.wallHeight),
    ));
  }

  // --- ドラッグ操作（パチンコ式発射） ---

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // 画面座標をワールド座標に変換
    _dragStart = screenToWorld(event.localPosition);
    _dragCurrent = _dragStart;

    // お手玉の位置からドラッグ線を開始
    if (otedama != null) {
      _dragLine?.update_(
        start: otedama!.centerPosition.clone(),
        end: _dragCurrent,
      );
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _dragCurrent = screenToWorld(event.localEndPosition);

    // ドラッグ線を更新
    if (otedama != null) {
      _dragLine?.update_(
        start: otedama!.centerPosition.clone(),
        end: _dragCurrent,
      );
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (_dragStart != null && _dragCurrent != null && otedama != null) {
      // スワイプの方向と逆に発射（パチンコ式）
      final otedamaPos = otedama!.centerPosition;
      final diff = otedamaPos - _dragCurrent!;
      otedama!.launch(diff);
    }

    _dragStart = null;
    _dragCurrent = null;
    _dragLine?.clear();
  }

  /// お手玉をリセット
  void resetOtedama() {
    otedama?.reset();
  }
}
