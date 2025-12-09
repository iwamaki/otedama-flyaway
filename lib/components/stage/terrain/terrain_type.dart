import 'package:flutter/material.dart';

/// 地形の素材タイプ
enum TerrainType {
  grass,
  dirt,
  rock,
  ice,
  wood,
  metal,
  snow,
  snowIce,
  stoneTiles,
  // エッジ装飾専用（透過テクスチャ）
  grassEdge,
  snowEdge,
}

/// TerrainType拡張メソッド
extension TerrainTypeExtension on TerrainType {
  /// 摩擦係数（素材ごとの滑りやすさ）
  double get friction {
    switch (this) {
      case TerrainType.ice:
        return 0.02; // 非常に滑りやすい
      case TerrainType.snowIce:
        return 0.05; // 滑りやすい
      case TerrainType.metal:
        return 0.3; // やや滑りやすい
      case TerrainType.rock:
        return 0.6; // やや摩擦が高い
      case TerrainType.wood:
        return 0.7; // 摩擦が高い
      case TerrainType.grass:
      case TerrainType.dirt:
      case TerrainType.snow:
        return 0.5; // 標準
      case TerrainType.stoneTiles:
        return 0.6; // やや摩擦が高い（rockと同等）
      case TerrainType.grassEdge:
      case TerrainType.snowEdge:
        return 0.5; // 装飾専用（使用されない）
    }
  }

  /// 反発係数（素材ごとの跳ね返りやすさ）
  double get restitution {
    switch (this) {
      case TerrainType.ice:
      case TerrainType.snowIce:
        return 0.1; // ほとんど跳ねない
      case TerrainType.metal:
        return 0.4; // やや跳ねる
      case TerrainType.rock:
        return 0.3; // 少し跳ねる
      case TerrainType.wood:
        return 0.25; // 少し吸収
      case TerrainType.grass:
      case TerrainType.dirt:
      case TerrainType.snow:
        return 0.2; // 標準
      case TerrainType.stoneTiles:
        return 0.3; // 少し跳ねる（rockと同等）
      case TerrainType.grassEdge:
      case TerrainType.snowEdge:
        return 0.2; // 装飾専用（使用されない）
    }
  }

  /// デフォルトの塗りつぶし色（内側の色）
  Color get defaultFillColor {
    switch (this) {
      case TerrainType.grass:
        return const Color(0xFF8B5A2B); // 茶色（土）
      case TerrainType.dirt:
        return const Color(0xFF8B5A2B);
      case TerrainType.rock:
        return const Color(0xFF696969);
      case TerrainType.ice:
        return const Color(0xFFB0E0E6);
      case TerrainType.wood:
        return const Color(0xFF8B4513);
      case TerrainType.metal:
        return const Color(0xFF708090);
      case TerrainType.snow:
        return const Color(0xFF8B5A2B); // 茶色（土）- 草と同様
      case TerrainType.snowIce:
        return const Color(0xFFB0E0E6); // 氷と同様
      case TerrainType.stoneTiles:
        return const Color(0xFF808080); // グレー（石タイル）
      case TerrainType.grassEdge:
        return const Color(0xFF4CAF50); // 緑（装飾専用）
      case TerrainType.snowEdge:
        return const Color(0xFFFFFFFF); // 白（装飾専用）
    }
  }

  /// 文字列から変換
  static TerrainType fromString(String value) {
    return TerrainType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TerrainType.dirt,
    );
  }
}
