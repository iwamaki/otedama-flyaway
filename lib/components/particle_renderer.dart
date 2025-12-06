import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/otedama_skin_config.dart';

/// ParticleOtedama の描画ヘルパー
/// 外殻・ビーズの描画ロジックを担当
class ParticleRenderer {
  final double shellRadius;
  final double beadRadius;

  /// 現在のスキン設定
  OtedamaSkin _skin;

  /// テクスチャ画像（テクスチャスキン時に使用）
  ui.Image? _textureImage;

  ParticleRenderer({
    Color color = const Color(0xFFCC3333),
    required this.shellRadius,
    required this.beadRadius,
    OtedamaSkin? skin,
  }) : _skin = skin ??
            OtedamaSkin.solid(
              name: 'カスタム',
              color: color,
            );

  /// スキンを更新
  void setSkin(OtedamaSkin skin) {
    _skin = skin;
  }

  /// テクスチャ画像を設定
  void setTextureImage(ui.Image? image) {
    _textureImage = image;
  }

  /// 現在のスキンを取得
  OtedamaSkin get skin => _skin;

  /// ベースカラーを取得（単色スキンまたはフォールバック）
  Color get _baseColor => _skin.baseColor ?? const Color(0xFFCC3333);

  /// 縁取り色を取得
  Color get _borderColor =>
      _skin.borderColor ?? Color.lerp(_baseColor, Colors.black, 0.25)!;

  /// 外殻とビーズを描画
  /// [canvas] 描画先
  /// [bodyPos] ボディの位置（座標変換の基準）
  /// [shellPositions] 外殻粒子のワールド座標リスト
  /// [beadPositions] ビーズのワールド座標リスト
  /// [beadRadii] 各ビーズの半径リスト（省略時はデフォルトのbeadRadiusを使用）
  void render(
    Canvas canvas, {
    required Offset bodyPos,
    required List<Offset> shellPositions,
    required List<Offset> beadPositions,
    List<double>? beadRadii,
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

    final bounds = smoothPath.getBounds();
    if (bounds.isEmpty) return;

    // スキンタイプに応じて描画
    switch (_skin.type) {
      case OtedamaSkinType.solidColor:
        _drawSolidFill(canvas, smoothPath, bounds);
        break;
      case OtedamaSkinType.texture:
        // 回転角度を計算（最初の外殻粒子の位置から）
        final rotationAngle = _calculateRotationAngle(points, centerX, centerY);
        _drawTextureFill(canvas, smoothPath, bounds, rotationAngle);
        break;
    }

    // 縁取り
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.12;
    canvas.drawPath(smoothPath, borderPaint);

    // ビーズを描画（スキン設定で有効な場合のみ）
    if (_skin.showBeads) {
      final beadPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      for (int i = 0; i < beadPositions.length; i++) {
        final beadPos = beadPositions[i];
        // 各ビーズの実際の半径を使用（リストがない場合はデフォルト値）
        final radius = (beadRadii != null && i < beadRadii.length)
            ? beadRadii[i]
            : beadRadius;
        canvas.drawCircle(
          Offset(
            beadPos.dx - bodyPos.dx,
            beadPos.dy - bodyPos.dy,
          ),
          radius,
          beadPaint,
        );
      }
    }

    // 縫い目模様
    if (_skin.showStitchPattern) {
      _drawPattern(canvas, bounds);
    }
  }

  /// 単色グラデーションで塗りつぶし
  void _drawSolidFill(Canvas canvas, Path path, Rect bounds) {
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.2,
      colors: [
        _baseColor,
        Color.lerp(_baseColor, Colors.black, 0.4)!,
      ],
    );

    final paint = Paint()..shader = gradient.createShader(bounds);
    canvas.drawPath(path, paint);
  }

  /// 外殻粒子から回転角度を計算
  /// 最初の粒子と中心を結ぶ線の角度を返す
  double _calculateRotationAngle(List<Offset> points, double centerX, double centerY) {
    if (points.isEmpty) return 0;

    // 最初の外殻粒子の位置から回転角を計算
    final firstPoint = points[0];
    final dx = firstPoint.dx - centerX;
    final dy = firstPoint.dy - centerY;

    // 初期状態では最初の粒子は右側（角度0）にあるので、
    // 現在の角度がそのまま回転量になる
    return math.atan2(dy, dx);
  }

  /// テクスチャで塗りつぶし
  void _drawTextureFill(Canvas canvas, Path path, Rect bounds, double rotationAngle) {
    if (_textureImage == null) {
      // テクスチャが未読み込みの場合はフォールバック色で描画
      _drawSolidFill(canvas, path, bounds);
      return;
    }

    canvas.save();
    canvas.clipPath(path);

    // テクスチャを袋の形状にフィットさせる
    final srcRect = Rect.fromLTWH(
      0,
      0,
      _textureImage!.width.toDouble(),
      _textureImage!.height.toDouble(),
    );

    // 袋の中心
    final center = bounds.center;

    // テクスチャを正方形で描画するために大きい方のサイズを使用
    final size = math.max(bounds.width, bounds.height) * 1.2;
    final dstRect = Rect.fromCenter(
      center: center,
      width: size,
      height: size,
    );

    // 中心を原点に移動してから回転
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawImageRect(
      _textureImage!,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    canvas.restore();

    // 立体感を出すための半透明グラデーションオーバーレイ
    final overlayGradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.2,
      colors: [
        Colors.white.withValues(alpha: 0.1),
        Colors.black.withValues(alpha: 0.3),
      ],
    );

    final overlayPaint = Paint()..shader = overlayGradient.createShader(bounds);
    canvas.drawPath(path, overlayPaint);
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
