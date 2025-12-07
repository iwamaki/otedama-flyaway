import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'terrain_pattern.dart';

/// 金属パターン（規則的な細かいドットとスクラッチ）
class MetalPattern extends TerrainPattern {
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

    // ざらつき（細かいドット）
    final grainPaint = Paint()
      ..color = const Color(0xFF4A5568).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // 光沢点
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // スクラッチ線
    final scratchPaint = Paint()
      ..color = const Color(0xFF3A4555).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.04;

    for (final (start, end, normal) in edges) {
      final edgeLength = (end - start).length;
      final direction = (end - start).normalized();

      // ざらつき（多めに配置）
      final grainCount = (edgeLength * 6).clamp(15, 100).toInt();
      for (int i = 0; i < grainCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.04 + seedToDouble(currentSeed) * 0.06;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, grainPaint);
      }

      // 光沢点
      final shineCount = (edgeLength * 1.5).clamp(3, 25).toInt();
      for (int i = 0; i < shineCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.06 + seedToDouble(currentSeed) * 0.08;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, shinePaint);
      }

      // スクラッチ
      final scratchCount = (edgeLength * 0.2).clamp(0, 5).toInt();
      for (int i = 0; i < scratchCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final scratchStart = alongEdge + normal * depth;

        _drawScratch(canvas, scratchStart, currentSeed, scratchPaint);
      }
    }

    canvas.restore();
  }

  void _drawScratch(Canvas canvas, Vector2 start, int seed, Paint paint) {
    var currentSeed = seed;

    currentSeed = nextSeed(currentSeed);
    final angle = seedToDouble(currentSeed) * math.pi; // 0〜180度

    currentSeed = nextSeed(currentSeed);
    final length = 0.5 + seedToDouble(currentSeed) * 1.5;

    final end = start +
        Vector2(
          length * math.cos(angle),
          length * math.sin(angle),
        );

    canvas.drawLine(
      Offset(start.x, start.y),
      Offset(end.x, end.y),
      paint,
    );
  }
}
