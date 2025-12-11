import 'package:flame_forge2d/flame_forge2d.dart' show Vector2;

/// ステージ遷移時の情報
class TransitionInfo {
  /// 次ステージのアセットパス
  final String nextStage;

  /// 遷移時の速度
  final Vector2 velocity;

  /// 遷移先ゾーンのID（このIDを持つゾーンの位置にスポーンする）
  final String? targetZoneId;

  /// ライン判定時の相対X座標（ゾーン中心からのオフセット）
  /// nullの場合はゾーン中心にスポーン
  final double? relativeX;

  const TransitionInfo({
    required this.nextStage,
    required this.velocity,
    this.targetZoneId,
    this.relativeX,
  });
}
