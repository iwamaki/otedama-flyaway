import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../components/particle_otedama.dart';
import '../../components/stage/goal.dart';
import '../../services/audio_service.dart';
import '../../services/logger_service.dart';
import 'game_timer_mixin.dart';

/// ゴール判定処理用Mixin
mixin GoalHandlerMixin on Forge2DGame, GameTimerMixin {
  /// ゴール
  Goal? goal;

  /// ゴール到達フラグ
  bool _goalReached = false;
  bool get goalReached => _goalReached;

  /// ゴール到達コールバック（外部通知用）
  VoidCallback? onGoalReachedCallback;

  /// お手玉への参照（サブクラスで実装）
  ParticleOtedama? get otedama;

  /// ゴール判定チェック
  void checkGoalReached() {
    if (goal == null || otedama == null) return;

    final pos = otedama!.centerPosition;
    final goalPos = goal!.position;
    final halfW = goal!.width / 2 - goal!.wallThickness;
    final halfH = goal!.height / 2 - goal!.wallThickness;

    // お手玉の中心がゴール内部にあるか
    if (pos.x >= goalPos.x - halfW &&
        pos.x <= goalPos.x + halfW &&
        pos.y >= goalPos.y - halfH &&
        pos.y <= goalPos.y + halfH) {
      onGoalReached();
    }
  }

  /// ゴール到達時の処理
  void onGoalReached() {
    if (!_goalReached) {
      _goalReached = true;
      // タイマー停止＆クリアタイム記録
      stopTimer();
      // ゴール音を再生
      AudioService.instance.playGoal();
      logger.info(LogCategory.game, 'Goal reached! Clear time: ${clearTime?.toStringAsFixed(2)}s');
      // 外部コールバックを呼び出し
      onGoalReachedCallback?.call();
    }
  }

  /// ゴール到達を通知（Goalコンポーネントから呼ばれる）
  void notifyGoalReached() {
    onGoalReached();
  }

  /// ゴール到達状態をリセット
  void resetGoalState() {
    _goalReached = false;
  }
}
