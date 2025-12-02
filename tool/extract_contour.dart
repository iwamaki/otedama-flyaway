// 画像から輪郭を抽出してJSONに保存するツール
// 使い方: dart run tool/extract_contour.dart assets/images/branch.png
//
// 出力: assets/physics/branch.json

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main(List<String> args) async {
  if (args.isEmpty) {
    print('使い方: dart run tool/extract_contour.dart <画像パス>');
    print('例: dart run tool/extract_contour.dart assets/images/branch.png');
    exit(1);
  }

  final imagePath = args[0];
  final file = File(imagePath);

  if (!file.existsSync()) {
    print('エラー: ファイルが見つかりません: $imagePath');
    exit(1);
  }

  print('画像を読み込み中: $imagePath');
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('エラー: 画像を読み込めませんでした');
    exit(1);
  }

  print('サイズ: ${image.width} x ${image.height}');

  // 輪郭を抽出
  final contours = extractContours(
    image,
    threshold: 128,
    downsample: 4,
    simplifyTolerance: 5.0,
    maxPoints: 30,
  );

  print('輪郭数: ${contours.length}');
  for (int i = 0; i < contours.length; i++) {
    print('  輪郭$i: ${contours[i].length}点');
  }

  // JSON形式で出力
  final outputData = {
    'image': imagePath.split('/').last,
    'width': image.width,
    'height': image.height,
    'contours': contours.map((c) => c.map((p) => {'x': p.x, 'y': p.y}).toList()).toList(),
  };

  // 出力先を決定
  final baseName = imagePath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
  final outputDir = Directory('assets/physics');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }
  final outputPath = 'assets/physics/$baseName.json';

  File(outputPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(outputData),
  );

  print('保存完了: $outputPath');
}

class Point {
  final double x;
  final double y;
  Point(this.x, this.y);
}

/// 画像から輪郭を抽出
List<List<Point>> extractContours(
  img.Image image, {
  int threshold = 128,
  int downsample = 2,
  double simplifyTolerance = 2.0,
  int maxPoints = 50,
}) {
  final origWidth = image.width;
  final origHeight = image.height;

  // ダウンサンプリング
  final width = origWidth ~/ downsample;
  final height = origHeight ~/ downsample;

  // 二値化
  final binary = List.generate(
    height,
    (y) => List.generate(width, (x) {
      final ox = x * downsample;
      final oy = y * downsample;
      final pixel = image.getPixel(ox, oy);
      final alpha = pixel.a.toInt();
      return alpha >= threshold;
    }),
  );

  // 輪郭を追跡
  final contours = traceContours(binary, width, height);

  // 簡略化してスケールを戻す
  final result = <List<Point>>[];
  for (final contour in contours) {
    var simplified = simplifyContour(contour, simplifyTolerance);

    // 点数制限
    if (simplified.length > maxPoints) {
      final step = simplified.length ~/ maxPoints;
      simplified = [for (int i = 0; i < simplified.length; i += step) simplified[i]];
    }

    if (simplified.length >= 3) {
      // 元のスケールに戻す
      result.add(simplified.map((p) => Point(p.x * downsample, p.y * downsample)).toList());
    }
  }

  return result;
}

/// 輪郭追跡
List<List<Point>> traceContours(List<List<bool>> binary, int width, int height) {
  final visited = List.generate(height, (_) => List.filled(width, false));
  final contours = <List<Point>>[];

  const dx = [1, 1, 0, -1, -1, -1, 0, 1];
  const dy = [0, 1, 1, 1, 0, -1, -1, -1];

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (!binary[y][x] || visited[y][x]) continue;

      // 境界チェック
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
      final contour = <Point>[];
      int cx = x, cy = y;
      int dir = 0;

      do {
        contour.add(Point(cx.toDouble(), cy.toDouble()));
        visited[cy][cx] = true;

        bool found = false;
        for (int i = 0; i < 8; i++) {
          final newDir = (dir + 6 + i) % 8;
          final nx = cx + dx[newDir];
          final ny = cy + dy[newDir];

          if (nx >= 0 && nx < width && ny >= 0 && ny < height && binary[ny][nx]) {
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

      if (contour.length >= 10) {
        contours.add(contour);
      }
    }
  }

  return contours;
}

/// Douglas-Peucker簡略化
List<Point> simplifyContour(List<Point> points, double tolerance) {
  if (points.length < 3) return points;

  // 点数が多すぎる場合は間引く
  var workingPoints = points;
  if (workingPoints.length > 1000) {
    final step = workingPoints.length ~/ 500;
    workingPoints = [for (int i = 0; i < workingPoints.length; i += step) workingPoints[i]];
  }

  final n = workingPoints.length;
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
      final dist = perpendicularDistance(workingPoints[i], workingPoints[start], workingPoints[end]);
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

  final result = <Point>[];
  for (int i = 0; i < n; i++) {
    if (keep[i]) result.add(workingPoints[i]);
  }

  return result;
}

double perpendicularDistance(Point point, Point lineStart, Point lineEnd) {
  final dx = lineEnd.x - lineStart.x;
  final dy = lineEnd.y - lineStart.y;

  if (dx == 0 && dy == 0) {
    return _distance(point, lineStart);
  }

  final t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (dx * dx + dy * dy);
  final nearest = Point(lineStart.x + t * dx, lineStart.y + t * dy);

  return _distance(point, nearest);
}

double _distance(Point a, Point b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
