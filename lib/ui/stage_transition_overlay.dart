import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// ステージ遷移時のフェードオーバーレイ
class StageTransitionOverlay extends StatefulWidget {
  /// フェードアウト完了後のコールバック（ステージロード開始）
  final Future<void> Function() onFadeOutComplete;

  /// 遷移完了後のコールバック
  final VoidCallback onTransitionComplete;

  const StageTransitionOverlay({
    super.key,
    required this.onFadeOutComplete,
    required this.onTransitionComplete,
  });

  @override
  State<StageTransitionOverlay> createState() => _StageTransitionOverlayState();
}

class _StageTransitionOverlayState extends State<StageTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  /// フェードイン開始を遅延させるためのフラグ
  bool _holdBlack = false;

  static const _fadeDuration = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startTransition();
  }

  Future<void> _startTransition() async {
    // 1. フェードアウト（画面が暗くなる）
    await _controller.forward();

    // 2. フェードアウト完了後、数フレーム待機（アニメーション処理を完全に終わらせる）
    await _waitForFrames(2);

    // 3. ステージロード（画面真っ暗の状態で実行）
    await widget.onFadeOutComplete();

    // 4. 黒画面を維持するフラグを立てる（フェードインアニメーション中もalpha=1.0を維持）
    setState(() => _holdBlack = true);

    // 5. 十分な時間待機（物理エンジン、レンダリング、音声の初期化完了を待つ）
    // 1秒の余裕を持って全ての初期化処理が完了するのを待つ
    await Future.delayed(const Duration(milliseconds: 1000));

    // 6. 黒画面維持フラグを解除してフェードイン開始
    setState(() => _holdBlack = false);

    // 7. フェードイン（画面が明るくなる）
    await _controller.reverse();

    // 8. 完了通知
    widget.onTransitionComplete();
  }

  /// 指定フレーム数待機
  Future<void> _waitForFrames(int frames) async {
    for (int i = 0; i < frames; i++) {
      await _waitForNextFrame();
    }
  }

  /// 次のフレームを待機
  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        // _holdBlackフラグが立っている間は完全不透明を維持
        final alpha = _holdBlack ? 1.0 : _fadeAnimation.value;
        return IgnorePointer(
          ignoring: alpha == 0,
          child: Container(
            color: Colors.black.withValues(alpha: alpha),
          ),
        );
      },
    );
  }
}
