import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

/// ステージ遷移時の情報
class TransitionInfo {
  /// 次ステージのアセットパス
  final String nextStage;

  /// 遷移時の速度
  final Vector2 velocity;

  /// 遷移先ゾーンのID（このIDを持つゾーンの位置にスポーンする）
  final String? targetZoneId;

  const TransitionInfo({
    required this.nextStage,
    required this.velocity,
    this.targetZoneId,
  });
}
