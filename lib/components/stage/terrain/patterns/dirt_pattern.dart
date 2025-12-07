import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'terrain_pattern.dart';

/// 土パターン（不規則な土粒と小石）
class DirtPattern extends TerrainPattern {
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

    // 土粒（明るい）
    final lightDirtPaint = Paint()
      ..color = const Color(0xFFA0724B).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // 土粒（暗い）
    final darkDirtPaint = Paint()
      ..color = const Color(0xFF4A3520).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // 小石
    final pebblePaint = Paint()
      ..color = const Color(0xFF3D2817).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (final (start, end, normal) in edges) {
      final edgeLength = (end - start).length;
      final direction = (end - start).normalized();

      // 明るい土粒
      final lightCount = (edgeLength * 3).clamp(6, 50).toInt();
      for (int i = 0; i < lightCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.08 + seedToDouble(currentSeed) * 0.12;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, lightDirtPaint);
      }

      // 暗い土粒
      final darkCount = (edgeLength * 3).clamp(6, 50).toInt();
      for (int i = 0; i < darkCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.1 + seedToDouble(currentSeed) * 0.15;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, darkDirtPaint);
      }

      // 小石
      final pebbleCount = (edgeLength * 0.5).clamp(1, 10).toInt();
      for (int i = 0; i < pebbleCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.25 + seedToDouble(currentSeed) * 0.35;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, pebblePaint);
      }
    }

    canvas.restore();
  }
}
