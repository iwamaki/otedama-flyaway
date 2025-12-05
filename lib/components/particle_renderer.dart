import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ParticleOtedama の描画ヘルパー
/// 外殻・ビーズの描画ロジックを担当
class ParticleRenderer {
  final Color color;
  final double shellRadius;
  final double beadRadius;

  ParticleRenderer({
    required this.color,
    required this.shellRadius,
    required this.beadRadius,
  });

  /// 外殻とビーズを描画
  /// [canvas] 描画先
  /// [bodyPos] ボディの位置（座標変換の基準）
  /// [shellPositions] 外殻粒子のワールド座標リスト
  /// [beadPositions] ビーズのワールド座標リスト
  void render(
    Canvas canvas, {
    required Offset bodyPos,
    required List<Offset> shellPositions,
    required List<Offset> beadPositions,
  }) {
    if (shellPositions.isEmpty) return;

    // 外殻の重心を計算（外縁オフセット用）
    double centerX = 0, centerY = 0;
    for (final pos in shellPositions) {
      centerX += pos.dx - bodyPos.dx;
      centerY += pos.dy - bodyPos.dy;
    }
    centerX /= shellPositions.length;
    centerY /= shellPositions.length;

    // 袋の形状（外殻の外縁を結ぶPath）
    final points = <Offset>[];

    for (final pos in shellPositions) {
      final sx = pos.dx - bodyPos.dx;
      final sy = pos.dy - bodyPos.dy;

      // 中心から外側への方向ベクトル
      final dx = sx - centerX;
      final dy = sy - centerY;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist > 0.001) {
        // 外殻の外縁にオフセット（shellRadiusだけ外側へ）
        final nx = dx / dist;
        final ny = dy / dist;
        points.add(Offset(
          sx + nx * shellRadius,
          sy + ny * shellRadius,
        ));
      } else {
        points.add(Offset(sx, sy));
      }
    }

    if (points.isEmpty) return;

    // Catmull-Romスプラインで滑らかに
    final smoothPath = _createSmoothPath(points);

    // 袋の塗りつぶし
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.2,
      colors: [
        color,
        Color.lerp(color, Colors.black, 0.4)!,
      ],
    );
    final bounds = smoothPath.getBounds();
    if (bounds.isEmpty) return;

    final paint = Paint()..shader = gradient.createShader(bounds);
    canvas.drawPath(smoothPath, paint);

    // 縁取り
    final borderPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.25)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;
    canvas.drawPath(smoothPath, borderPaint);

    // ビーズを描画（半透明）
    final beadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    for (final beadPos in beadPositions) {
      canvas.drawCircle(
        Offset(
          beadPos.dx - bodyPos.dx,
          beadPos.dy - bodyPos.dy,
        ),
        beadRadius,
        beadPaint,
      );
    }

    // 縫い目模様
    _drawPattern(canvas, bounds);
  }

  /// Catmull-Romスプラインで滑らかなパスを生成
  Path _createSmoothPath(List<Offset> points) {
    if (points.length < 3) return Path();

    final path = Path();

    for (int i = 0; i < points.length; i++) {
      final p0 = points[(i - 1 + points.length) % points.length];
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final p3 = points[(i + 2) % points.length];

      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      }

      // Catmull-Rom to Bezier
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  /// 縫い目模様を描画
  void _drawPattern(Canvas canvas, Rect bounds) {
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final radiusX = bounds.width / 2 * 0.5;
    final radiusY = bounds.height / 2 * 0.5;

    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08;

    // 縦の縫い目
    canvas.drawLine(
      Offset(centerX, centerY - radiusY),
      Offset(centerX, centerY + radiusY),
      patternPaint,
    );

    // 横の縫い目
    canvas.drawLine(
      Offset(centerX - radiusX, centerY),
      Offset(centerX + radiusX, centerY),
      patternPaint,
    );

    // 中心の結び目
    final knotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: radiusX * 0.15,
        height: radiusY * 0.15,
      ),
      knotPaint,
    );
  }
}
