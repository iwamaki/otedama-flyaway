import 'package:flame_forge2d/flame_forge2d.dart';

/// ステージに配置可能なオブジェクトの共通インターフェース
/// Platform, Goal など全ての配置オブジェクトが実装する
abstract mixin class StageObject {
  /// オブジェクトの種類（"platform", "goal" など）
  String get type;

  /// ワールド座標での位置
  Vector2 get position;

  /// 回転角度（ラジアン）
  double get angle;

  /// スケール
  double get scale => 1.0;

  /// 水平反転
  bool get flipX => false;

  /// 垂直反転
  bool get flipY => false;

  /// バウンディングボックス（選択判定用）
  /// 左上と右下をワールド座標で返す
  (Vector2 min, Vector2 max) get bounds;

  /// JSON形式にシリアライズ
  Map<String, dynamic> toJson();

  /// プロパティを適用（エディタでの編集用）
  void applyProperties(Map<String, dynamic> props);

  /// 選択中かどうか（エディタ用）
  bool isSelected = false;
}

/// StageObjectのファクトリ
/// JSONからオブジェクトを生成する
class StageObjectFactory {
  static final Map<String, StageObject Function(Map<String, dynamic>)>
      _creators = {};

  /// オブジェクト生成関数を登録
  static void register(
    String type,
    StageObject Function(Map<String, dynamic>) creator,
  ) {
    _creators[type] = creator;
  }

  /// JSONからStageObjectを生成
  static StageObject? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null || !_creators.containsKey(type)) {
      return null;
    }
    return _creators[type]!(json);
  }
}
