import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// ステージ遷移時のフェードオーバーレイ
class StageTransitionOverlay extends StatefulWidget {
  /// フェードアウト完了後のコールバック（ステージロード開始）
  final Future<void> Function() onFadeOutComplete;

  /// 遷移完了後のコールバック
  final VoidCallback onTransitionComplete;

  /// 物理演算を一時停止するコールバック
  final VoidCallback? onPausePhysics;

  /// 物理演算を再開するコールバック
  final VoidCallback? onResumePhysics;

  const StageTransitionOverlay({
    super.key,
    required this.onFadeOutComplete,
    required this.onTransitionComplete,
    this.onPausePhysics,
    this.onResumePhysics,
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
    // 注: 物理演算は遷移検出時点で既に停止済み（TransitionHandlerMixin）

    // 1. フェードアウト（画面が暗くなる、物理は停止中）
    await _controller.forward();

    // 2. 数フレーム待機（アニメーション処理を完全に終わらせる）
    await _waitForFrames(2);

    // 3. ステージロード（画面真っ暗の状態で実行、物理は停止中）
    await widget.onFadeOutComplete();

    // 4. 黒画面を維持するフラグを立てる
    setState(() => _holdBlack = true);

    // 5. 物理を一時的に再開して新しいステージを描画（黒画面中）
    widget.onResumePhysics?.call();
    await _waitForFrames(5);
    widget.onPausePhysics?.call();

    // 6. 安定化のための待機
    await Future.delayed(const Duration(milliseconds: 300));

    // 7. 黒画面維持フラグを解除
    setState(() => _holdBlack = false);

    // 8. フェードイン（画面が明るくなる）
    await _controller.reverse();

    // 9. フェードイン完了後、物理演算を再開
    widget.onResumePhysics?.call();

    // 10. 完了通知
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
