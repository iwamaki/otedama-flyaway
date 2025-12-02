import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame_forge2d/flame_forge2d.dart';

/// 透過PNG画像から輪郭を抽出するユーティリティ
class ContourExtractor {
  /// 画像からアルファチャンネルを取得
  static Future<Uint8List> getAlphaChannel(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Failed to get image byte data');
    }

    final pixels = byteData.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final alpha = Uint8List(width * height);

    // RGBAの4バイト目（A）を抽出
    for (int i = 0; i < width * height; i++) {
      alpha[i] = pixels[i * 4 + 3];
    }

    return alpha;
  }

  /// マーチングスクエアで輪郭を抽出
  /// threshold: アルファ値の閾値（0-255）
  /// simplifyTolerance: 簡略化の許容誤差（ピクセル単位）
  /// downsample: 画像を縮小する倍率（1=そのまま、2=半分）
  static Future<List<List<Vector2>>> extractContours(
    ui.Image image, {
    int threshold = 128,
    double simplifyTolerance = 2.0,
    int downsample = 2,
  }) async {
    final alpha = await getAlphaChannel(image);
    final origWidth = image.width;
    final origHeight = image.height;

    // ダウンサンプリング
    final width = origWidth ~/ downsample;
    final height = origHeight ~/ downsample;

    // 二値化（ダウンサンプル済み）
    final binary = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) {
          final ox = x * downsample;
          final oy = y * downsample;
          return alpha[oy * origWidth + ox] >= threshold;
        },
      ),
    );

    // 輪郭を追跡
    final contours = _traceContours(binary, width, height);

    // 輪郭を簡略化し、元のスケールに戻す
    final simplified = contours
        .map((c) => _simplifyContour(c, simplifyTolerance))
        .where((c) => c.length >= 3)
        .map((c) => c.map((p) => Vector2(p.x * downsample, p.y * downsample)).toList())
        .toList();

    return simplified;
  }

  /// 輪郭追跡（簡易版：外周のみ）
  static List<List<Vector2>> _traceContours(
    List<List<bool>> binary,
    int width,
    int height,
  ) {
    final visited = List.generate(
      height,
      (_) => List.filled(width, false),
    );
    final contours = <List<Vector2>>[];

    // 8方向の移動
    const dx = [1, 1, 0, -1, -1, -1, 0, 1];
    const dy = [0, 1, 1, 1, 0, -1, -1, -1];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // 不透明で未訪問の境界ピクセルを探す
        if (!binary[y][x] || visited[y][x]) continue;

        // 境界かどうか確認（隣に透明ピクセルがある）
        bool isBorder = false;
        for (int d = 0; d < 8; d++) {
          final nx = x + dx[d];
          final ny = y + dy[d];
          if (nx < 0 || nx >= width || ny < 0 || ny >= height || !binary[ny][nx]) {
            isBorder = true;
            break;
          }
        }

        if (!isBorder) continue;

        // 輪郭追跡
        final contour = <Vector2>[];
        int cx = x, cy = y;
        int dir = 0; // 開始方向

        do {
          contour.add(Vector2(cx.toDouble(), cy.toDouble()));
          visited[cy][cx] = true;

          // 次の境界ピクセルを探す
          bool found = false;
          for (int i = 0; i < 8; i++) {
            final newDir = (dir + 6 + i) % 8; // 左から探す
            final nx = cx + dx[newDir];
            final ny = cy + dy[newDir];

            if (nx >= 0 && nx < width && ny >= 0 && ny < height && binary[ny][nx]) {
              // 境界チェック
              bool nextIsBorder = false;
              for (int d = 0; d < 8; d++) {
                final nnx = nx + dx[d];
                final nny = ny + dy[d];
                if (nnx < 0 || nnx >= width || nny < 0 || nny >= height || !binary[nny][nnx]) {
                  nextIsBorder = true;
                  break;
                }
              }

              if (nextIsBorder) {
                cx = nx;
                cy = ny;
                dir = newDir;
                found = true;
                break;
              }
            }
          }

          if (!found) break;
        } while (!(cx == x && cy == y) && contour.length < width * height);

        if (contour.length >= 3) {
          contours.add(contour);
        }
      }
    }

    return contours;
  }

  /// 輪郭を簡略化（反復版、スタックオーバーフロー回避）
  static List<Vector2> _simplifyContour(List<Vector2> points, double tolerance) {
    if (points.length < 3) return points;

    // 点数が多すぎる場合は間引く
    var workingPoints = points;
    if (workingPoints.length > 1000) {
      final step = workingPoints.length ~/ 500;
      workingPoints = [
        for (int i = 0; i < workingPoints.length; i += step) workingPoints[i]
      ];
    }

    // Douglas-Peucker（反復版）
    return _douglasPeuckerIterative(workingPoints, tolerance);
  }

  /// Douglas-Peucker（反復版、再帰なし）
  static List<Vector2> _douglasPeuckerIterative(List<Vector2> points, double tolerance) {
    if (points.length < 3) return points;

    final n = points.length;
    final keep = List.filled(n, false);
    keep[0] = true;
    keep[n - 1] = true;

    // スタックで処理（再帰の代わり）
    final stack = <List<int>>[];
    stack.add([0, n - 1]);

    while (stack.isNotEmpty) {
      final range = stack.removeLast();
      final start = range[0];
      final end = range[1];

      if (end - start < 2) continue;

      // 最も遠い点を見つける
      double maxDist = 0;
      int maxIdx = start;

      for (int i = start + 1; i < end; i++) {
        final dist = _perpendicularDistance(points[i], points[start], points[end]);
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

    // 保持する点を収集
    final result = <Vector2>[];
    for (int i = 0; i < n; i++) {
      if (keep[i]) result.add(points[i]);
    }

    return result;
  }

  /// 点から線分への垂直距離
  static double _perpendicularDistance(Vector2 point, Vector2 lineStart, Vector2 lineEnd) {
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
}
