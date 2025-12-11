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

  /// 位置ベースクールダウン用: 遷移したゾーンのID
  String? _cooldownZoneId;

  /// 位置ベースクールダウン用: 遷移したゾーンの境界情報
  /// (centerX, centerY, halfWidth, halfHeight, isLine)
  (double, double, double, double, bool)? _cooldownZoneBounds;

  /// 前フレームのお手玉Y座標（ライン通過判定用）
  double? _previousOtedamaY;

  /// ライン判定用クールダウン状態（ゾーンID -> 最後に通過した方向）
  /// true = 上から下へ通過、false = 下から上へ通過
  final Map<String, bool> _lineCooldownDirection = {};

  /// お手玉への参照（サブクラスで実装）
  ParticleOtedama? get otedama;

  /// ステージオブジェクトのリスト（サブクラスで実装）
  List<StageObject> get stageObjects;

  /// 現在のステージ境界（サブクラスで実装）
  StageBoundaries get boundaries;

  /// 位置ベースクールダウンを更新
  /// お手玉がゾーン範囲外に出たらクールダウン解除
  void updateTransitionCooldown(double dt) {
    if (_cooldownZoneId == null || _cooldownZoneBounds == null) return;
    if (otedama == null) return;

    final pos = otedama!.centerPosition;
    final (cx, cy, halfW, halfH, isLine) = _cooldownZoneBounds!;

    bool isOutside;
    if (isLine) {
      // ライン判定: X座標がゾーン幅の範囲外に出たらクールダウン解除
      // （Y方向は方向ベースクールダウンで制御）
      isOutside = pos.x < cx - halfW || pos.x > cx + halfW;
    } else {
      // 面判定: 矩形範囲から完全に出たらクールダウン解除
      isOutside = pos.x < cx - halfW ||
          pos.x > cx + halfW ||
          pos.y < cy - halfH ||
          pos.y > cy + halfH;
    }

    if (isOutside) {
      logger.debug(LogCategory.game,
          'Position-based cooldown cleared: zone $_cooldownZoneId');
      _cooldownZoneId = null;
      _cooldownZoneBounds = null;
    }
  }

  /// 遷移可能かどうか（特定のゾーンに対して）
  bool canTransitionToZone(String zoneId) {
    if (_isTransitioning) return false;
    // クールダウン中のゾーンには遷移不可
    if (_cooldownZoneId == zoneId) return false;
    return true;
  }

  /// 遷移可能かどうか（汎用）
  bool get canTransition => !_isTransitioning;

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
    if (onStageTransition != null) {
      onStageTransition!.call(info);
    } else {
      // コールバックがない場合は遷移状態をリセット
      _isTransitioning = false;
      paused = false;
    }
  }

  /// 遷移ゾーン判定チェック
  void checkTransitionZones() {
    if (!canTransition || otedama == null) return;

    final pos = otedama!.centerPosition;
    final previousY = _previousOtedamaY;
    _previousOtedamaY = pos.y;

    final transitionZones = stageObjects.whereType<TransitionZone>().toList();

    for (final zone in transitionZones) {
      if (zone.nextStage.isNotEmpty) {
        final zonePos = zone.position;
        final halfW = zone.width / 2;

        // X座標がゾーンの範囲内かチェック（共通）
        if (pos.x < zonePos.x - halfW || pos.x > zonePos.x + halfW) {
          continue;
        }

        if (zone.isLine) {
          // ライン判定モード：方向ベースクールダウンのみ使用（位置ベースは使わない）
          if (previousY == null) continue;

          final lineY = zonePos.y;
          final crossedDownward = previousY < lineY && pos.y >= lineY; // 上から下へ
          final crossedUpward = previousY > lineY && pos.y <= lineY; // 下から上へ

          if (crossedDownward || crossedUpward) {
            // クールダウンチェック：同じ方向への再通過を防止
            final lastDirection = _lineCooldownDirection[zone.id];
            if (lastDirection != null) {
              // 同じ方向への通過はスキップ
              if (lastDirection == crossedDownward) {
                continue;
              }
            }

            // 相対X座標を計算（ゾーン中心からのオフセット）
            final relativeX = pos.x - zonePos.x;

            logger.debug(LogCategory.game,
                'Line transition: zone ${zone.id} at y=$lineY, '
                'otedama crossed ${crossedDownward ? "downward" : "upward"}, '
                'relativeX=${relativeX.toStringAsFixed(1)}');

            // クールダウン方向を記録
            _lineCooldownDirection[zone.id] = crossedDownward;

            triggerZoneTransitionWithRelativeX(zone, relativeX);
            return;
          }
        } else {
          // 面判定モード：位置ベースクールダウンを使用
          // お手玉がゾーン外に出るまで再遷移不可
          if (!canTransitionToZone(zone.id)) {
            continue;
          }

          final halfH = zone.height / 2;

          // お手玉の中心がゾーン内にあるか
          if (pos.y >= zonePos.y - halfH && pos.y <= zonePos.y + halfH) {
            logger.debug(LogCategory.game,
                '_checkTransitionZones: otedama at (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)}) inside zone at (${zonePos.x.toStringAsFixed(1)}, ${zonePos.y.toStringAsFixed(1)})');
            triggerZoneTransition(zone);
            return;
          }
        }
      }
    }
  }

  /// 遷移ゾーンからの遷移をトリガー
  /// スポーン位置はtargetZoneIdを使って遷移先ステージで解決する
  void triggerZoneTransition(TransitionZone zone) {
    triggerZoneTransitionWithRelativeX(zone, null);
  }

  /// 遷移ゾーンからの遷移をトリガー（相対X座標付き）
  void triggerZoneTransitionWithRelativeX(TransitionZone zone, double? relativeX) {
    logger.debug(LogCategory.game,
        'triggerZoneTransition called: nextStage=${zone.nextStage}, targetZoneId=${zone.targetZoneId}, relativeX=$relativeX, _isTransitioning=$_isTransitioning');

    if (_isTransitioning) {
      logger.debug(LogCategory.game, 'triggerZoneTransition: already transitioning, skipped');
      return;
    }
    _isTransitioning = true;

    // 面判定の場合のみ位置ベースクールダウンを設定
    // ライン判定は方向ベースクールダウンのみ使用
    if (!zone.isLine) {
      _cooldownZoneId = zone.id;
      _cooldownZoneBounds = (
        zone.position.x,
        zone.position.y,
        zone.width / 2,
        zone.height / 2,
        false,
      );
      logger.debug(LogCategory.game, 'Position-based cooldown set for zone: ${zone.id}');
    }

    // 遷移検出時に即座に物理演算を停止
    paused = true;
    logger.debug(LogCategory.game, 'Physics paused immediately on zone detection');

    final velocity = otedama?.getVelocity() ?? Vector2.zero();
    logger.info(LogCategory.game,
        'Zone transition -> ${zone.nextStage}, targetZoneId=${zone.targetZoneId}, '
        'relativeX=${relativeX?.toStringAsFixed(1)}, velocity: ${velocity.length.toStringAsFixed(2)}');

    // スポーン位置は遷移先でtargetZoneIdを使って対応するゾーンの位置から解決する
    final info = TransitionInfo(
      nextStage: zone.nextStage,
      velocity: velocity,
      targetZoneId: zone.targetZoneId,
      relativeX: relativeX,
    );

    logger.debug(LogCategory.game,
        'TransitionInfo: nextStage=${info.nextStage}, targetZoneId=${info.targetZoneId}, relativeX=${info.relativeX}');

    if (onStageTransition != null) {
      onStageTransition!.call(info);
    } else {
      // コールバックがない場合（エディタモードなど）は遷移状態をリセット
      logger.warning(LogCategory.game, 'onStageTransition callback is null, resetting transition state');
      _isTransitioning = false;
      paused = false;
    }
  }

  /// 遷移状態をリセット（遷移完了後に呼び出す）
  /// 注意: クールダウン（位置ベース、方向ベース両方）はリセットしない
  /// クールダウンはスポーン時に設定され、逆方向への遷移のみ許可する
  void resetTransitionState() {
    _isTransitioning = false;
    _previousOtedamaY = null;
    // 方向ベースクールダウンはクリアしない（スポーン先ゾーンへの即時再遷移を防止）
  }

  /// 全てのクールダウンをクリア（ステージ完全リセット時用）
  void clearAllCooldowns() {
    _cooldownZoneId = null;
    _cooldownZoneBounds = null;
    _lineCooldownDirection.clear();
    logger.debug(LogCategory.game, 'All cooldowns cleared');
  }

  /// スポーン先ゾーンのクールダウンを設定（遷移完了後に呼び出す）
  void setSpawnZoneCooldown(
      String zoneId, double cx, double cy, double halfW, double halfH, bool isLine) {
    _cooldownZoneId = zoneId;
    _cooldownZoneBounds = (cx, cy, halfW, halfH, isLine);
    logger.debug(LogCategory.game, 'Spawn zone cooldown set for zone: $zoneId');
  }

  /// ライン判定ゾーンの方向クールダウンを設定（スポーン時に呼び出す）
  /// isDownward: true = 下方向に通過した（上から来た）、false = 上方向に通過した（下から来た）
  void setLineCooldownDirection(String zoneId, bool isDownward) {
    _lineCooldownDirection[zoneId] = isDownward;
    logger.debug(LogCategory.game,
        'Line cooldown direction set for zone $zoneId: ${isDownward ? "downward" : "upward"}');
  }
}
