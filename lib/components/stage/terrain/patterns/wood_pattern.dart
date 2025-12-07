import 'dart:ui';
import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import 'terrain_pattern.dart';

/// 木パターン（横方向の木目線）
class WoodPattern extends TerrainPattern {
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

    // 木目線（暗い）
    final darkGrainPaint = Paint()
      ..color = const Color(0xFF5D2906).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.1;

    // 木目線（明るい）
    final lightGrainPaint = Paint()
      ..color = const Color(0xFFA0724B).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;

    // 節
    final knotPaint = Paint()
      ..color = const Color(0xFF4A2808).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (final (start, end, normal) in edges) {
      final edgeLength = (end - start).length;
      final direction = (end - start).normalized();

      // 暗い木目線
      final darkLineCount = (edgeLength * 0.6).clamp(2, 15).toInt();
      for (int i = 0; i < darkLineCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final lineStart = alongEdge + normal * depth;

        _drawWoodGrainLine(canvas, lineStart, currentSeed, darkGrainPaint);
      }

      // 明るい木目線
      final lightLineCount = (edgeLength * 0.4).clamp(1, 10).toInt();
      for (int i = 0; i < lightLineCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final lineStart = alongEdge + normal * depth;

        _drawWoodGrainLine(canvas, lineStart, currentSeed, lightGrainPaint);
      }

      // 節（まれに）
      final knotCount = (edgeLength * 0.1).clamp(0, 3).toInt();
      for (int i = 0; i < knotCount; i++) {
        currentSeed = nextSeed(currentSeed);
        final t = seedToDouble(currentSeed);
        final alongEdge = start + direction * (edgeLength * t);

        currentSeed = nextSeed(currentSeed);
        final depth = seedToDouble(currentSeed) * TerrainPattern.textureDepth;

        final pos = alongEdge + normal * depth;

        currentSeed = nextSeed(currentSeed);
        final radius = 0.3 + seedToDouble(currentSeed) * 0.4;

        _drawKnot(canvas, pos, radius, currentSeed, knotPaint);
      }
    }

    canvas.restore();
  }

  void _drawWoodGrainLine(
      Canvas canvas, Vector2 start, int seed, Paint paint) {
    var currentSeed = seed;

    currentSeed = nextSeed(currentSeed);
    final length = 1.0 + seedToDouble(currentSeed) * 3.0;

    currentSeed = nextSeed(currentSeed);
    final baseAngle = seedToDouble(currentSeed) * 0.3 - 0.15; // ほぼ水平

    final path = Path();
    path.moveTo(start.x, start.y);

    var current = start.clone();
    const segments = 4;
    final segmentLength = length / segments;

    for (int i = 0; i < segments; i++) {
      currentSeed = nextSeed(currentSeed);
      final wobble = (seedToDouble(currentSeed) - 0.5) * 0.3;
      final angle = baseAngle + wobble;

      current = current +
          Vector2(
            segmentLength * math.cos(angle),
            segmentLength * math.sin(angle),
          );

      path.lineTo(current.x, current.y);
    }

    canvas.drawPath(path, paint);
  }

  void _drawKnot(
      Canvas canvas, Vector2 center, double radius, int seed, Paint paint) {
    // 楕円形の節
    var currentSeed = seed;
    currentSeed = nextSeed(currentSeed);
    final scaleX = 0.8 + seedToDouble(currentSeed) * 0.4;

    canvas.save();
    canvas.translate(center.x, center.y);
    canvas.scale(scaleX, 1.0);
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();

    // 内側の輪
    final innerPaint = Paint()
      ..color = const Color(0xFF3A1805).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05;

    canvas.save();
    canvas.translate(center.x, center.y);
    canvas.scale(scaleX, 1.0);
    canvas.drawCircle(Offset.zero, radius * 0.6, innerPaint);
    canvas.restore();
  }
}
