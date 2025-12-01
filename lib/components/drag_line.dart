import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// スワイプ中の引っ張り線を表示するコンポーネント
class DragLine extends Component {
  Vector2? start;
  Vector2? end;

  void update_({Vector2? start, Vector2? end}) {
    this.start = start;
    this.end = end;
  }

  void clear() {
    start = null;
    end = null;
  }

  @override
  void render(Canvas canvas) {
    if (start == null || end == null) return;

    final direction = start! - end!;
    final length = direction.length;

    // 引っ張り線（ゴムバンド風）
    final linePaint = Paint()
      ..color = Colors.brown.withOpacity(0.7)
      ..strokeWidth = 0.3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(start!.x, start!.y),
      Offset(end!.x, end!.y),
      linePaint,
    );

    // 発射方向を示す矢印（お手玉位置から）
    if (length > 1) {
      final arrowPaint = Paint()
        ..color = Colors.red.withOpacity(0.6)
        ..strokeWidth = 0.2
        ..style = PaintingStyle.stroke;

      final normalized = direction.normalized();
      final arrowLength = (length * 0.3).clamp(1.0, 5.0);
      final arrowEnd = start! + normalized * arrowLength;

      canvas.drawLine(
        Offset(start!.x, start!.y),
        Offset(arrowEnd.x, arrowEnd.y),
        arrowPaint,
      );
    }

    // パワーインジケーター（点々で表示）
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.8);

    final dotCount = (length / 3).clamp(0, 5).toInt();
    for (var i = 0; i < dotCount; i++) {
      final t = (i + 1) / 6;
      final dotPos = end! + direction * t;
      canvas.drawCircle(Offset(dotPos.x, dotPos.y), 0.15, dotPaint);
    }
  }
}
