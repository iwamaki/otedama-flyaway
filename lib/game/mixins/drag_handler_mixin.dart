import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../../components/drag_line.dart';
import '../../components/particle_otedama.dart';
import '../../config/physics_config.dart';
import '../../services/audio_service.dart';
import 'game_timer_mixin.dart';

/// ドラッグ操作（パチンコ式発射）用Mixin
mixin DragHandlerMixin on Forge2DGame, GameTimerMixin {
  DragLine? dragLine;
  Vector2? _dragStart;
  Vector2? _dragCurrent;
  bool _isDraggingOtedama = false;

  /// お手玉をつかめる距離（お手玉半径の倍率）
  static const double grabRadiusMultiplier = 1.8;

  /// お手玉への参照（サブクラスで実装）
  ParticleOtedama? get otedama;

  /// 編集モードかどうか（サブクラスで実装）
  bool get isEditMode;

  /// 編集モードのドラッグ開始（サブクラスで実装）
  void handleEditModeDragStart(Vector2 touchPos);

  /// 編集モードのドラッグ更新（サブクラスで実装）
  void handleEditModeDragUpdate(Vector2 touchPos);

  /// 編集モードのドラッグ終了（サブクラスで実装）
  void handleEditModeDragEnd();

  /// ドラッグ開始処理
  void handleDragStart(DragStartEvent event) {
    final touchPos = screenToWorld(event.localPosition);

    // 編集モードの場合
    if (isEditMode) {
      handleEditModeDragStart(touchPos);
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
        dragLine?.updateScreen(
          start: worldToScreen(_dragStart!),
          end: worldToScreen(_dragCurrent!),
          isAirLaunch: otedama?.isAirLaunch ?? false,
        );
      }
    }
  }

  /// ドラッグ更新処理
  void handleDragUpdate(DragUpdateEvent event) {
    final touchPos = screenToWorld(event.localEndPosition);

    // 編集モードの場合
    if (isEditMode) {
      handleEditModeDragUpdate(touchPos);
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
    dragLine?.updateScreen(
      start: worldToScreen(_dragStart!),
      end: worldToScreen(_dragCurrent!),
      isAirLaunch: otedama?.isAirLaunch ?? false,
    );
  }

  /// ドラッグ終了処理
  void handleDragEnd(DragEndEvent event) {
    // 編集モードの場合
    if (isEditMode) {
      handleEditModeDragEnd();
      return;
    }

    if (_isDraggingOtedama && _dragStart != null && _dragCurrent != null && otedama != null) {
      // スワイプの方向と逆に発射（パチンコ式）
      final otedamaPos = otedama!.centerPosition;
      final diff = otedamaPos - _dragCurrent!;
      // タップ位置に力を加える（回転が発生する）
      if (otedama!.canLaunch) {
        otedama!.launch(diff, touchPoint: _dragStart!);
        // 発射音を再生
        AudioService.instance.playLaunch();
      }

      // 初回発射時にタイマー開始
      if (!timerStarted) {
        startTimer();
      }
    }

    // 状態をリセット
    _isDraggingOtedama = false;
    _dragStart = null;
    _dragCurrent = null;
    dragLine?.clear();
  }
}
