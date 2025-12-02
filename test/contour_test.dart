import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter_test/flutter_test.dart';

// ContourExtractorの簡略化ロジックだけテスト
void main() {
  group('Douglas-Peucker Iterative', () {
    test('簡単な直線は2点に簡略化', () {
      final points = [
        Vector2(0, 0),
        Vector2(1, 0),
        Vector2(2, 0),
        Vector2(3, 0),
        Vector2(4, 0),
      ];

      final result = douglasPeuckerIterative(points, 0.1);

      expect(result.length, 2);
      expect(result[0].x, 0);
      expect(result[1].x, 4);
    });

    test('三角形は3点を維持', () {
      final points = [
        Vector2(0, 0),
        Vector2(2, 4),  // 頂点
        Vector2(4, 0),
      ];

      final result = douglasPeuckerIterative(points, 0.1);

      expect(result.length, 3);
    });

    test('多数の点でもメモリ枯渇しない', () {
      // 1万点の円
      final points = <Vector2>[];
      for (int i = 0; i < 10000; i++) {
        final angle = (i / 10000) * math.pi * 2;
        points.add(Vector2(
          100 * (1 + 0.01 * (i % 10)) * math.cos(angle),
          100 * (1 + 0.01 * (i % 10)) * math.sin(angle),
        ));
      }

      final result = douglasPeuckerIterative(points, 5.0);

      print('10000点 → ${result.length}点に簡略化');
      expect(result.length, lessThan(5000)); // 大幅に削減されている
      expect(result.length, greaterThan(3));
    });
  });
}

// テスト用にContourExtractorから抜粋
List<Vector2> douglasPeuckerIterative(List<Vector2> points, double tolerance) {
  if (points.length < 3) return points;

  final n = points.length;
  final keep = List.filled(n, false);
  keep[0] = true;
  keep[n - 1] = true;

  final stack = <List<int>>[];
  stack.add([0, n - 1]);

  while (stack.isNotEmpty) {
    final range = stack.removeLast();
    final start = range[0];
    final end = range[1];

    if (end - start < 2) continue;

    double maxDist = 0;
    int maxIdx = start;

    for (int i = start + 1; i < end; i++) {
      final dist = perpendicularDistance(points[i], points[start], points[end]);
      if (dist > maxDist) {
        maxDist = dist;
        maxIdx = i;
      }
    }

    if (maxDist > tolerance) {
      keep[maxIdx] = true;
      stack.add([start, maxIdx]);
      stack.add([maxIdx, end]);
    }
  }

  final result = <Vector2>[];
  for (int i = 0; i < n; i++) {
    if (keep[i]) result.add(points[i]);
  }

  return result;
}

double perpendicularDistance(Vector2 point, Vector2 lineStart, Vector2 lineEnd) {
  final dx = lineEnd.x - lineStart.x;
  final dy = lineEnd.y - lineStart.y;

  if (dx == 0 && dy == 0) {
    return (point - lineStart).length;
  }

  final t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy);
  final nearest = Vector2(
    lineStart.x + t * dx,
    lineStart.y + t * dy,
  );

  return (point - nearest).length;
}
