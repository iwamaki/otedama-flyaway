import 'package:flame_forge2d/flame_forge2d.dart';

import '../../components/particle_otedama.dart';
import '../../components/stage/stage_object.dart';
import '../../components/stage/transition_zone.dart';
import '../../models/stage_data.dart';
import '../../models/transition_info.dart';
import '../../services/logger_service.dart';

/// ステージ遷移管理用Mixin
mixin TransitionHandlerMixin on Forge2DGame {
  /// ステージ遷移コールバック（外部通知用）
  void Function(TransitionInfo info)? onStageTransition;

  /// 遷移中フラグ（二重遷移防止）
  bool _isTransitioning = false;

  /// 遷移クールダウン（遷移直後の再遷移を防止）
  double _transitionCooldown = 0.0;
  static const double transitionCooldownDuration = 1.0; // 1秒

  /// お手玉への参照（サブクラスで実装）
  ParticleOtedama? get otedama;

  /// ステージオブジェクトのリスト（サブクラスで実装）
  List<StageObject> get stageObjects;

  /// 現在のステージ境界（サブクラスで実装）
  StageBoundaries get boundaries;

  /// 遷移クールダウンを更新
  void updateTransitionCooldown(double dt) {
    if (_transitionCooldown > 0) {
      _transitionCooldown -= dt;
    }
  }

  /// 遷移可能かどうか
  bool get canTransition => !_isTransitioning && _transitionCooldown <= 0;

  /// 境界条件をチェック
  bool checkBoundary(Vector2 pos, BoundaryEdge edge, double threshold) {
    switch (edge) {
      case BoundaryEdge.top:
        return pos.y < threshold;
      case BoundaryEdge.bottom:
        return pos.y > threshold;
      case BoundaryEdge.left:
        return pos.x < threshold;
      case BoundaryEdge.right:
        return pos.x > threshold;
    }
  }

  /// 境界遷移をチェック
  void checkBoundaryTransitions() {
    if (_isTransitioning || otedama == null) return;

    final pos = otedama!.centerPosition;

    for (final transition in boundaries.transitions) {
      if (checkBoundary(pos, transition.edge, transition.threshold)) {
        triggerBoundaryTransition(transition);
        return;
      }
    }
  }

  /// 遷移をトリガー（境界による）
  void triggerBoundaryTransition(TransitionBoundary transition) {
    if (_isTransitioning) return;
    _isTransitioning = true;

    // 遷移検出時に即座に物理演算を停止
    paused = true;
    logger.debug(LogCategory.game, 'Physics paused immediately on boundary detection');

    final velocity = otedama?.getVelocity() ?? Vector2.zero();
    logger.info(LogCategory.game,
        'Stage transition: ${transition.edge} -> ${transition.nextStage}, velocity: ${velocity.length.toStringAsFixed(2)}');

    final info = TransitionInfo(
      nextStage: transition.nextStage,
      velocity: velocity,
    );
    onStageTransition?.call(info);
  }

  /// 遷移ゾーン判定チェック
  void checkTransitionZones() {
    if (!canTransition || otedama == null) return;

    final pos = otedama!.centerPosition;
    final transitionZones = stageObjects.whereType<TransitionZone>().toList();

    for (final zone in transitionZones) {
      if (zone.nextStage.isNotEmpty) {
        final zonePos = zone.position;
        final halfW = zone.width / 2;
        final halfH = zone.height / 2;

        // お手玉の中心がゾーン内にあるか
        if (pos.x >= zonePos.x - halfW &&
            pos.x <= zonePos.x + halfW &&
            pos.y >= zonePos.y - halfH &&
            pos.y <= zonePos.y + halfH) {
          logger.debug(LogCategory.game,
              '_checkTransitionZones: otedama at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)}) inside zone at (${zonePos.x.toStringAsFixed(1)}, ${zonePos.y.toStringAsFixed(1)})');
          triggerZoneTransition(zone);
          return;
        }
      }
    }
  }

  /// 遷移ゾーンからの遷移をトリガー
  /// スポーン位置はlinkIdを使って遷移先ステージで解決する
  void triggerZoneTransition(TransitionZone zone) {
    logger.debug(LogCategory.game,
        'triggerZoneTransition called: nextStage=${zone.nextStage}, linkId=${zone.linkId}, _isTransitioning=$_isTransitioning');

    if (_isTransitioning) {
      logger.debug(LogCategory.game, 'triggerZoneTransition: already transitioning, skipped');
      return;
    }
    _isTransitioning = true;

    // 遷移検出時に即座に物理演算を停止
    paused = true;
    logger.debug(LogCategory.game, 'Physics paused immediately on zone detection');

    final velocity = otedama?.getVelocity() ?? Vector2.zero();
    logger.info(LogCategory.game,
        'Zone transition -> ${zone.nextStage}, linkId=${zone.linkId}, velocity: ${velocity.length.toStringAsFixed(2)}');

    // スポーン位置は遷移先でlinkIdを使って対応するゾーンの位置から解決する
    // 遷移元ゾーンの位置も渡して、同じステージ内の遷移時に除外できるようにする
    final info = TransitionInfo(
      nextStage: zone.nextStage,
      velocity: velocity,
      linkId: zone.linkId.isNotEmpty ? zone.linkId : null,
      sourceZonePosition: zone.position.clone(),
    );

    logger.debug(LogCategory.game,
        'TransitionInfo: nextStage=${info.nextStage}, linkId=${info.linkId}');

    if (onStageTransition != null) {
      onStageTransition!.call(info);
    } else {
      logger.warning(LogCategory.game, 'onStageTransition callback is null!');
    }
  }

  /// 遷移状態をリセット（遷移完了後に呼び出す）
  void resetTransitionState() {
    _isTransitioning = false;
  }

  /// 遷移クールダウンを設定
  void setTransitionCooldown() {
    _transitionCooldown = transitionCooldownDuration;
    logger.debug(LogCategory.game, 'Transition cooldown set: ${transitionCooldownDuration}s');
  }
}
