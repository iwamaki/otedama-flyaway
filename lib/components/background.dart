import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

/// 背景画像コンポーネント（パララックス効果付き）
class Background extends PositionComponent {
  final String? imagePath;
  final Color fallbackColor;
  final double parallaxFactor; // 0.0〜1.0: 小さいほどゆっくり動く

  ui.Image? _image;
  Vector2 _offset = Vector2.zero();

  Background({
    this.imagePath,
    this.fallbackColor = const Color(0xFFE8DCC8),
    this.parallaxFactor = 0.1, // デフォルト: お手玉の10%の速さで動く
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (imagePath != null) {
      try {
        _image = await Flame.images.load(imagePath!);
      } catch (e) {
        debugPrint('Background image not found: $imagePath');
      }
    }
  }

  /// パララックス用のオフセットを更新
  void updateParallax(Vector2 targetPosition) {
    _offset = targetPosition * parallaxFactor;
  }

  @override
  void render(Canvas canvas) {
    final screenSize = size;

    if (_image != null) {
      _renderImageCover(canvas, screenSize);
    } else {
      _renderFallback(canvas, screenSize);
    }
  }

  /// 画像を画面全体にカバー（アスペクト比を保ちつつ全体を覆う）
  void _renderImageCover(Canvas canvas, Vector2 screenSize) {
    final imgWidth = _image!.width.toDouble();
    final imgHeight = _image!.height.toDouble();

    // 画面を覆うためのスケールを計算（cover方式）
    final scaleX = screenSize.x / imgWidth;
    final scaleY = screenSize.y / imgHeight;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    // スケール後のサイズ
    final scaledWidth = imgWidth * scale;
    final scaledHeight = imgHeight * scale;

    // 中央に配置 + パララックスオフセット
    final offsetX = (screenSize.x - scaledWidth) / 2 - _offset.x;
    final offsetY = (screenSize.y - scaledHeight) / 2 - _offset.y;

    // 描画
    final srcRect = Rect.fromLTWH(0, 0, imgWidth, imgHeight);
    final dstRect = Rect.fromLTWH(offsetX, offsetY, scaledWidth, scaledHeight);

    canvas.drawImageRect(_image!, srcRect, dstRect, Paint());
  }

  void _renderFallback(Canvas canvas, Vector2 screenSize) {
    // ベース色
    final basePaint = Paint()..color = fallbackColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenSize.x, screenSize.y),
      basePaint,
    );

    // 畳風の線を描画（パララックス付き）
    final linePaint = Paint()
      ..color = const Color(0xFFD4C4A8)
      ..strokeWidth = 0.5;

    const spacing = 20.0;
    final startX = (-_offset.x % spacing) - spacing;
    final startY = (-_offset.y % spacing) - spacing;

    for (var x = startX; x < screenSize.x + spacing; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, screenSize.y),
        linePaint,
      );
    }
    for (var y = startY; y < screenSize.y + spacing; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(screenSize.x, y),
        linePaint,
      );
    }
  }
}
