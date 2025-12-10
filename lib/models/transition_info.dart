import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

/// ステージ遷移時の情報
class TransitionInfo {
  /// 次ステージのアセットパス
  final String nextStage;

  /// 遷移時の速度
  final Vector2 velocity;

  /// 遷移先でのスポーン位置（nullの場合はステージのデフォルト）
  final Vector2? spawnPosition;

  /// 遷移ゾーンのリンクID（遷移先で対応するゾーンを特定するため）
  final String? linkId;

  /// 遷移元ゾーンの位置（同じステージ内の遷移時に除外するため）
  final Vector2? sourceZonePosition;

  const TransitionInfo({
    required this.nextStage,
    required this.velocity,
    this.spawnPosition,
    this.linkId,
    this.sourceZonePosition,
  });
}
