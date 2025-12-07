import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'terrain_pattern.dart';

/// 草地パターン（内側は茶色の土感）
class GrassPattern extends TerrainPattern {
  @override
  void draw({
    required Canvas canvas,
    required Path clipPath,
    required List<(Vector2 start, Vector2 end, Vector2 normal)> edges,
    required int seed,
  }) {
    canvas.save();
    canvas.clipPath(clipPath);

    if (edges.isEmpty) {
      canvas.restore();
      return;
    }

    var currentSeed = seed;

    // 土粒（小さなドット）
    final dirtPaint = Paint()
      ..color = const Color(0xFF6B4423).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // 小石（やや大きめのドット）
    final pebblePaint = Paint()
      ..color = const Color(0xFF5D3A1A).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    for (final (start, end, normal) in edges) {
      final edgeLength = (end - start).length;
      final direction = (end - start).normalized();

      // 土粒を描画
      final dirtCount = (edgeLength * 4).clamp(8, 60).toInt();
      for (int i = 0; i < dirtCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.1 + seedToDouble(currentSeed) * 0.15;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, dirtPaint);
      }

      // 小石を散らばせる
      final pebbleCount = (edgeLength * 0.8).clamp(2, 15).toInt();
      for (int i = 0; i < pebbleCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.2 + seedToDouble(currentSeed) * 0.3;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, pebblePaint);
      }
    }

    canvas.restore();
  }
}
