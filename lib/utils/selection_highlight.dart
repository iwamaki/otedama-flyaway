import 'package:flutter/material.dart';

/// 選択状態のハイライト描画ユーティリティ
class SelectionHighlight {
  /// 選択枠とコーナーハンドルを描画
  /// [canvas] 描画先
  /// [halfWidth] 矩形の半分の幅
  /// [halfHeight] 矩形の半分の高さ
  /// [borderWidth] 枠線の太さ（デフォルト: 0.15）
  /// [handleRadius] ハンドル円の半径（デフォルト: 0.25）
  /// [color] ハイライト色（デフォルト: cyan）
  static void draw(
    Canvas canvas, {
    required double halfWidth,
    required double halfHeight,
    double borderWidth = 0.15,
    double handleRadius = 0.25,
    Color color = Colors.cyan,
  }) {
    final rect = Rect.fromLTRB(-halfWidth, -halfHeight, halfWidth, halfHeight);

    // 選択枠
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRect(rect, borderPaint);

    // コーナーハンドル
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(-halfWidth, -halfHeight), handleRadius, handlePaint);
    canvas.drawCircle(Offset(halfWidth, -halfHeight), handleRadius, handlePaint);
    canvas.drawCircle(Offset(-halfWidth, halfHeight), handleRadius, handlePaint);
    canvas.drawCircle(Offset(halfWidth, halfHeight), handleRadius, handlePaint);
  }
}
