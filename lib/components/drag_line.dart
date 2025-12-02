import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// スワイプ中の引っ張り線を表示するコンポーネント
/// camera.viewportに追加して最前面に表示
class DragLine extends Component {
  /// スクリーン座標での開始位置
  Vector2? _startScreen;
  /// スクリーン座標での終了位置
  Vector2? _endScreen;

  DragLine();

  /// スクリーン座標で更新
  void updateScreen({required Vector2 start, required Vector2 end}) {
    _startScreen = start;
    _endScreen = end;
  }

  void clear() {
    _startScreen = null;
    _endScreen = null;
  }

  @override
  void render(Canvas canvas) {
    if (_startScreen == null || _endScreen == null) return;

    final start = _startScreen!;
    final end = _endScreen!;

    final direction = start - end;
    final length = direction.length;

    // 引っ張り線（ゴムバンド風）
    final linePaint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.7)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(start.x, start.y),
      Offset(end.x, end.y),
      linePaint,
    );

    // 発射方向を示す矢印（タップ位置から）
    if (length > 20) {
      final arrowPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final normalized = direction.normalized();
      final arrowLength = (length * 0.3).clamp(20.0, 100.0);
      final arrowEnd = start + normalized * arrowLength;

      canvas.drawLine(
        Offset(start.x, start.y),
        Offset(arrowEnd.x, arrowEnd.y),
        arrowPaint,
      );
    }

    // パワーインジケーター（点々で表示）
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8);

    final dotCount = (length / 50).clamp(0, 5).toInt();
    for (var i = 0; i < dotCount; i++) {
      final t = (i + 1) / 6;
      final dotPos = end + direction * t;
      canvas.drawCircle(Offset(dotPos.x, dotPos.y), 4, dotPaint);
    }
  }
}
