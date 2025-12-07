import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

/// 地形パターン描画の基底クラス
abstract class TerrainPattern {
  /// 表面からのテクスチャ深度（ワールド座標単位）
  static const double textureDepth = 20.0;

  /// パターンを描画
  void draw({
    required Canvas canvas,
    required Path clipPath,
    required List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    required int seed,
  });

  /// シード値から次のシード値を生成
  int nextSeed(int seed) {
    return (seed * 1103515245 + 12345) & 0x7FFFFFFF;
  }

  /// シード値から0.0〜1.0の値を生成
  double seedToDouble(int seed) {
    return (seed % 1000) / 1000;
  }
}
