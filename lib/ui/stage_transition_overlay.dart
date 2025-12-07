import 'package:flutter/material.dart';

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
    // フェードアウト（画面が暗くなる）
    await _controller.forward();

    // ステージロード
    await widget.onFadeOutComplete();

    // フェードイン（画面が明るくなる）
    await _controller.reverse();

    // 完了通知
    widget.onTransitionComplete();
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
        return IgnorePointer(
          ignoring: _fadeAnimation.value == 0,
          child: Container(
            color: Colors.black.withValues(alpha: _fadeAnimation.value),
          ),
        );
      },
    );
  }
}
