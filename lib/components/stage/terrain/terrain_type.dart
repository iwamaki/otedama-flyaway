import 'package:flutter/material.dart';

/// 地形の素材タイプ
enum TerrainType {
  grass,
  dirt,
  rock,
  ice,
  wood,
  metal,
}

/// TerrainType拡張メソッド
extension TerrainTypeExtension on TerrainType {
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
    }
  }

  /// デフォルトの輪郭色
  Color get defaultStrokeColor {
    switch (this) {
      case TerrainType.grass:
        return const Color(0xFF5D3A1A);
      case TerrainType.dirt:
        return const Color(0xFF5D3A1A);
      case TerrainType.rock:
        return const Color(0xFF404040);
      case TerrainType.ice:
        return const Color(0xFF87CEEB);
      case TerrainType.wood:
        return const Color(0xFF5D2906);
      case TerrainType.metal:
        return const Color(0xFF4A5568);
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
