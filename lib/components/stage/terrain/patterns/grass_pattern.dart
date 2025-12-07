import 'package:flutter/material.dart';

import 'terrain_pattern.dart';

/// 草地パターン（タイルベース、土と小石のシンプルな表現）
class GrassPattern extends TiledTerrainPattern {
  @override
  double get tileSize => 5.0;

  @override
  void drawTile({
    required Canvas canvas,
    required int seed,
  }) {
    var currentSeed = seed;
    final size = tileSize;

    // 明るい土粒
    final lightDirtPaint = Paint()
      ..color = const Color(0xFF8B6914).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // 暗い土粒
    final darkDirtPaint = Paint()
      ..color = const Color(0xFF5C4033).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    // 小石
    final pebblePaint = Paint()
      ..color = const Color(0xFF7A6B5A).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // 明るい土粒
    for (int i = 0; i < 4; i++) {
      currentSeed = nextSeed(currentSeed);
      final x = seedToDouble(currentSeed) * size;
      currentSeed = nextSeed(currentSeed);
      final y = seedToDouble(currentSeed) * size;
      currentSeed = nextSeed(currentSeed);
      final radius = 0.2 + seedToDouble(currentSeed) * 0.25;

      canvas.drawCircle(Offset(x, y), radius, lightDirtPaint);
    }

    // 暗い土粒
    for (int i = 0; i < 3; i++) {
      currentSeed = nextSeed(currentSeed);
      final x = seedToDouble(currentSeed) * size;
      currentSeed = nextSeed(currentSeed);
      final y = seedToDouble(currentSeed) * size;
      currentSeed = nextSeed(currentSeed);
      final radius = 0.25 + seedToDouble(currentSeed) * 0.3;

      canvas.drawCircle(Offset(x, y), radius, darkDirtPaint);
    }

    // 小石（1〜2個）
    currentSeed = nextSeed(currentSeed);
    final pebbleCount = seedToDouble(currentSeed) > 0.5 ? 2 : 1;
    for (int i = 0; i < pebbleCount; i++) {
      currentSeed = nextSeed(currentSeed);
      final x = seedToDouble(currentSeed) * size;
      currentSeed = nextSeed(currentSeed);
      final y = seedToDouble(currentSeed) * size;
      currentSeed = nextSeed(currentSeed);
      final radius = 0.15 + seedToDouble(currentSeed) * 0.2;

      // 楕円形の小石
      canvas.save();
      canvas.translate(x, y);
      currentSeed = nextSeed(currentSeed);
      canvas.scale(1.0, 0.7 + seedToDouble(currentSeed) * 0.3);
      canvas.drawCircle(Offset.zero, radius, pebblePaint);
      canvas.restore();
    }
  }
}
