import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'terrain_pattern.dart';

/// 岩パターン（大小の不規則な多角形）
class RockPattern extends TerrainPattern {
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

    // 明るい岩模様
    final lightRockPaint = Paint()
      ..color = const Color(0xFF8A8A8A).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // 暗い岩模様
    final darkRockPaint = Paint()
      ..color = const Color(0xFF404040).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // ひび線
    final crackPaint = Paint()
      ..color = const Color(0xFF303030).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;

    for (final (start, end, normal) in edges) {
      final edgeLength = (end - start).length;
      final direction = (end - start).normalized();

      // 明るい石片
      final lightCount = (edgeLength * 2).clamp(4, 30).toInt();
      for (int i = 0; i < lightCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final size = 0.3 + seedToDouble(currentSeed) * 0.5;

        _drawIrregularShape(canvas, pos, size, currentSeed, lightRockPaint);
      }

      // 暗い石片
      final darkCount = (edgeLength * 1.5).clamp(3, 25).toInt();
      for (int i = 0; i < darkCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final size = 0.2 + seedToDouble(currentSeed) * 0.4;

        _drawIrregularShape(canvas, pos, size, currentSeed, darkRockPaint);
      }

      // ひび
      final crackCount = (edgeLength * 0.3).clamp(1, 8).toInt();
      for (int i = 0; i < crackCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final startPos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final crackLength = 0.5 + seedToDouble(currentSeed) * 1.5;

        currentSeed = nextSeed(currentSeed);
        final angle = seedToDouble(currentSeed) * 3.14159 * 2;

        final endPos = startPos +
            Vector2(
              crackLength * cos(angle),
              crackLength * sin(angle),
            );

        canvas.drawLine(
          Offset(startPos.x, startPos.y),
          Offset(endPos.x, endPos.y),
          crackPaint,
        );
      }
    }

    canvas.restore();
  }

  void _drawIrregularShape(
      Canvas canvas, Vector2 center, double size, int seed, Paint paint) {
    final path = Path();
    var currentSeed = seed;

    final points = <Offset>[];
    const sides = 5;

    for (int i = 0; i < sides; i++) {
      final angle = (i / sides) * 3.14159 * 2;
      currentSeed = nextSeed(currentSeed);
      final radius = size * (0.6 + seedToDouble(currentSeed) * 0.4);

      points.add(Offset(
        center.x + radius * cos(angle),
        center.y + radius * sin(angle),
      ));
    }

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  double cos(double x) => _cos(x);
  double sin(double x) => _sin(x);

  static double _cos(double x) {
    x = x % (3.14159 * 2);
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _sin(double x) {
    x = x % (3.14159 * 2);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}
