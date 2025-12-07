import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'terrain_pattern.dart';

/// 氷パターン（細い斜め線のひび）
class IcePattern extends TerrainPattern {
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

    // ひび（細い線）
    final crackPaint = Paint()
      ..color = const Color(0xFF4A90B0).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;

    // 光の反射（小さな点）
    final shimmerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // 暗い部分
    final shadowPaint = Paint()
      ..color = const Color(0xFF5080A0).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (final (start, end, normal) in edges) {
      final edgeLength = (end - start).length;
      final direction = (end - start).normalized();

      // ひび割れ線
      final crackCount = (edgeLength * 0.8).clamp(2, 20).toInt();
      for (int i = 0; i < crackCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final crackStart = alongEdge + normal * depth;

        // 分岐するひび
        _drawBranchingCrack(canvas, crackStart, currentSeed, crackPaint);
      }

      // 光の反射点
      final shimmerCount = (edgeLength * 1.5).clamp(3, 25).toInt();
      for (int i = 0; i < shimmerCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.05 + seedToDouble(currentSeed) * 0.1;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, shimmerPaint);
      }

      // 暗い影
      final shadowCount = (edgeLength * 0.5).clamp(1, 10).toInt();
      for (int i = 0; i < shadowCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.3 + seedToDouble(currentSeed) * 0.5;

        canvas.drawCircle(Offset(pos.x, pos.y), radius, shadowPaint);
      }
    }

    canvas.restore();
  }

  void _drawBranchingCrack(
      Canvas canvas, Vector2 start, int seed, Paint paint) {
    var currentSeed = seed;

    currentSeed = nextSeed(currentSeed);
    final mainAngle = seedToDouble(currentSeed) * math.pi * 2;

    currentSeed = nextSeed(currentSeed);
    final mainLength = 0.5 + seedToDouble(currentSeed) * 2.0;

    final mainEnd = start +
        Vector2(
          mainLength * math.cos(mainAngle),
          mainLength * math.sin(mainAngle),
        );

    canvas.drawLine(
      Offset(start.x, start.y),
      Offset(mainEnd.x, mainEnd.y),
      paint,
    );

    // 分岐
    currentSeed = nextSeed(currentSeed);
    if (seedToDouble(currentSeed) > 0.5) {
      final branchAngle = mainAngle + (seedToDouble(currentSeed) - 0.5) * 1.5;
      final branchLength = mainLength * 0.4;

      final midPoint = start + (mainEnd - start) * 0.6;
      final branchEnd = midPoint +
          Vector2(
            branchLength * math.cos(branchAngle),
            branchLength * math.sin(branchAngle),
          );

      canvas.drawLine(
        Offset(midPoint.x, midPoint.y),
        Offset(branchEnd.x, branchEnd.y),
        paint,
      );
    }
  }
}
