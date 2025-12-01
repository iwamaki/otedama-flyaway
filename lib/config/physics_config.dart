/// 物理パラメータの設定
/// お手玉らしさを調整するための定数
class PhysicsConfig {
  // 重力
  static const double gravityY = 20.0;

  // お手玉のパラメータ
  static const double otedamaRadius = 1.5;
  static const double otedamaDensity = 1.0;
  static const double otedamaFriction = 0.8; // 高め（布の摩擦）
  static const double otedamaRestitution = 0.3; // 低め（ビーズが衝撃吸収）
  static const double otedamaAngularDamping = 2.0; // 回転がすぐ止まる
  static const double otedamaLinearDamping = 0.3; // 空気抵抗

  // 地面のパラメータ
  static const double groundFriction = 0.5;
  static const double groundRestitution = 0.2;

  // 壁のパラメータ
  static const double wallFriction = 0.3;
  static const double wallRestitution = 0.4;

  // 発射パラメータ
  static const double launchMultiplier = 5.0; // スワイプ→力の変換係数
}

/// カメラ設定
class CameraConfig {
  static const double zoom = 15.0;
}

/// ステージの境界
class StageConfig {
  static const double groundY = 20.0;
  static const double wallX = 12.0;
  static const double wallHeight = 25.0;
  static const double groundWidth = 20.0;
}
