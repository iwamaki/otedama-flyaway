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

  // 地形（Terrain）のパラメータ
  static const double terrainFriction = 0.5;
  static const double terrainRestitution = 0.2;

  // 発射パラメータ
  static const double launchMultiplier = 5.0; // スワイプ→力の変換係数
  static const double maxDragDistance = 24.0; // 最大引張距離（ワールド座標）
}

/// カメラ設定
class CameraConfig {
  static const double zoom = 15.0;

  /// カメラ追従の滑らかさ（0.0〜1.0、小さいほど滑らか）
  static const double followLerpSpeed = 0.05;

  /// カメラが追従を開始するデッドゾーン（この範囲内は追従しない）
  static const double deadZone = 0.5;
}

/// ステージの境界
class StageConfig {
  /// 初期地面の位置（Y座標、下が正）
  static const double groundY = 10.0;

  /// 地面の幅
  static const double groundWidth = 30.0;

  /// お手玉の初期位置
  static const double spawnX = 0.0;
  static const double spawnY = 5.0;

  /// 落下判定のY座標（これより下に行ったらリスポーン）
  static const double fallThreshold = 50.0;
}
