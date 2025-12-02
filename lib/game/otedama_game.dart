import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../components/background.dart';
import '../components/drag_line.dart';
import '../components/ground.dart';
import '../components/particle_otedama.dart';
import '../components/stage/goal.dart';
import '../components/stage/image_object.dart';
import '../components/stage/platform.dart';
import '../config/physics_config.dart';

/// メインゲームクラス
class OtedamaGame extends Forge2DGame with DragCallbacks {
  ParticleOtedama? otedama;
  DragLine? _dragLine;
  Background? _background;
  Vector2? _dragStart;
  Vector2? _dragCurrent;
  bool _isDraggingOtedama = false; // お手玉をつかんでいるか

  /// ゴール
  Goal? goal;

  /// ゴール到達フラグ
  bool _goalReached = false;
  bool get goalReached => _goalReached;

  /// お手玉をつかめる距離（お手玉半径の倍率）
  static const double grabRadiusMultiplier = 1.8;

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

    // ドラッグ線（最前面に表示するためviewportに追加）
    _dragLine = DragLine();
    camera.viewport.add(_dragLine!);

    // ステージを構築
    await _buildStage();

    // お手玉を配置（粒子ベース）
    otedama = ParticleOtedama(
      position: Vector2(StageConfig.spawnX, StageConfig.spawnY),
    );
    await world.add(otedama!);
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
      _updateCameraFollow(otedama!.centerPosition);

      // 最高高さを更新
      if (currentHeight > _maxHeight) {
        _maxHeight = currentHeight;
      }

      // 落下判定
      if (otedama!.centerPosition.y > StageConfig.fallThreshold) {
        resetOtedama();
      }
    }

    // パララックス効果を更新
    if (otedama != null && _background != null) {
      _background!.updateParallax(otedama!.centerPosition);
    }
  }

  /// カメラをお手玉に追従させる
  void _updateCameraFollow(Vector2 targetPosition) {
    final currentPos = camera.viewfinder.position;
    final diff = targetPosition - currentPos;

    // デッドゾーン内なら追従しない
    if (diff.length < CameraConfig.deadZone) return;

    // Lerp補間でスムーズに追従
    final newPos = currentPos + diff * CameraConfig.followLerpSpeed;
    camera.viewfinder.position = newPos;
  }

  /// ステージの構築
  Future<void> _buildStage() async {
    // 地面（スタート地点）- Groundを維持（大きな地面用）
    await world.add(Ground(
      position: Vector2(0, StageConfig.groundY),
      size: Vector2(StageConfig.groundWidth, 1),
    ));

    // デモ用の足場を配置（Platformを使用、角度対応）
    await world.add(Platform(
      position: Vector2(5, 0),
      width: 8,
      height: 0.5,
    ));
    await world.add(Platform(
      position: Vector2(-4, -8),
      width: 10,
      height: 0.5,
      angle: -0.15, // 少し傾斜
    ));
    await world.add(Platform(
      position: Vector2(3, -16),
      width: 8,
      height: 0.5,
      angle: 0.1,
    ));
    await world.add(Platform(
      position: Vector2(-5, -24),
      width: 10,
      height: 0.5,
    ));

    // 画像ベースのオブジェクト（テスト）
    await world.add(ImageObject(
      imagePath: 'branch.png',
      position: Vector2(0, -12),
      scale: 0.08, // 調整可能
    ));

    // ゴール（籠）を配置
    goal = Goal(
      position: Vector2(0, -32),
      width: 5,
      height: 4,
      onGoalReached: _onGoalReached,
    );
    await world.add(goal!);
  }

  /// ゴール到達時の処理
  void _onGoalReached() {
    if (!_goalReached) {
      _goalReached = true;
      debugPrint('🎉 Goal reached!');
      // TODO: Phase 6でゴール演出を追加
    }
  }

  // --- ドラッグ操作（パチンコ式発射） ---

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // 画面座標をワールド座標に変換
    final touchPos = screenToWorld(event.localPosition);

    // お手玉をつかめる距離かチェック
    if (otedama != null) {
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
        );
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!_isDraggingOtedama || _dragStart == null) return;

    _dragCurrent = screenToWorld(event.localEndPosition);

    // スクリーン座標に変換して渡す
    _dragLine?.updateScreen(
      start: worldToScreen(_dragStart!),
      end: worldToScreen(_dragCurrent!),
    );
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (_isDraggingOtedama && _dragStart != null && _dragCurrent != null && otedama != null) {
      // スワイプの方向と逆に発射（パチンコ式）
      final otedamaPos = otedama!.centerPosition;
      final diff = otedamaPos - _dragCurrent!;
      // タップ位置に力を加える（回転が発生する）
      otedama!.launch(diff, touchPoint: _dragStart!);
    }

    // 状態をリセット
    _isDraggingOtedama = false;
    _dragStart = null;
    _dragCurrent = null;
    _dragLine?.clear();
  }

  /// お手玉をリセット
  void resetOtedama() {
    otedama?.reset();
    _goalReached = false;
  }
}
