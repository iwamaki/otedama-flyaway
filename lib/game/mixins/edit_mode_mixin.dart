import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../components/particle_otedama.dart';
import '../../components/stage/stage_object.dart';
import '../../config/physics_config.dart';

/// 編集モード操作用Mixin
mixin EditModeMixin on Forge2DGame {
  /// 編集モードフラグ
  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  /// 選択中のオブジェクト
  StageObject? _selectedObject;
  StageObject? get selectedObject => _selectedObject;

  /// 編集モード中のドラッグ移動
  bool _isDraggingObject = false;
  Vector2? _dragOffset;

  /// UI更新コールバック
  VoidCallback? onEditModeChanged;

  /// お手玉への参照（サブクラスで実装）
  ParticleOtedama? get otedama;

  /// ステージオブジェクトのリスト（サブクラスで実装）
  List<StageObject> get stageObjects;

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

    removeStageObject(obj);
    onEditModeChanged?.call();
  }

  /// ステージオブジェクトを削除（サブクラスで実装）
  void removeStageObject(StageObject obj);

  /// 指定位置にあるオブジェクトを探す
  StageObject? findObjectAt(Vector2 pos) {
    for (final obj in stageObjects.reversed) {
      final (min, max) = obj.bounds;
      if (pos.x >= min.x && pos.x <= max.x && pos.y >= min.y && pos.y <= max.y) {
        return obj;
      }
    }
    return null;
  }

  /// 編集モードのドラッグ開始
  void handleEditModeDragStart(Vector2 touchPos) {
    // タッチ位置にあるオブジェクトを探す
    final obj = findObjectAt(touchPos);

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

  /// 編集モードのドラッグ更新
  void handleEditModeDragUpdate(Vector2 touchPos) {
    if (!_isDraggingObject || _selectedObject == null || _dragOffset == null) return;

    // 選択中のオブジェクトをドラッグ移動
    final newPos = touchPos - _dragOffset!;
    _selectedObject!.applyProperties({
      'x': newPos.x,
      'y': newPos.y,
    });
  }

  /// 編集モードのドラッグ終了
  void handleEditModeDragEnd() {
    _isDraggingObject = false;
    _dragOffset = null;
  }
}
