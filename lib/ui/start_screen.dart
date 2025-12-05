import 'package:flutter/material.dart';

import '../models/stage_data.dart';

/// スタート画面の結果
class StartScreenResult {
  /// 選択されたステージ
  final StageEntry? selectedStage;

  /// 開発者モードで開始するか
  final bool developerMode;

  const StartScreenResult({
    this.selectedStage,
    this.developerMode = false,
  });
}

/// ゲームのスタート画面
class StartScreen extends StatefulWidget {
  final void Function(StartScreenResult result) onStart;

  const StartScreen({
    super.key,
    required this.onStart,
  });

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _titleTapCount = 0;
  DateTime? _lastTitleTap;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTitleTap() {
    final now = DateTime.now();
    if (_lastTitleTap != null &&
        now.difference(_lastTitleTap!).inMilliseconds < 500) {
      _titleTapCount++;
      if (_titleTapCount >= 5) {
        // 5回連続タップで開発者モード
        widget.onStart(const StartScreenResult(developerMode: true));
        _titleTapCount = 0;
      }
    } else {
      _titleTapCount = 1;
    }
    _lastTitleTap = now;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景画像
          Image.asset(
            'assets/images/backgroundArt.jpeg',
            fit: BoxFit.cover,
          ),
          // グラデーションオーバーレイ
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // コンテンツ
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // タイトル
                    GestureDetector(
                      onTap: _onTitleTap,
                      child: const Column(
                        children: [
                          Text(
                            'お手玉',
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(2, 2),
                                  blurRadius: 8,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Flyaway',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: Colors.white70,
                              letterSpacing: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                    // ステージセレクト
                    _StageSelectPanel(
                      onStageSelected: (entry) {
                        widget.onStart(StartScreenResult(selectedStage: entry));
                      },
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ステージセレクトパネル
class _StageSelectPanel extends StatelessWidget {
  final void Function(StageEntry entry) onStageSelected;

  const _StageSelectPanel({
    required this.onStageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final entries = StageRegistry.sortedEntries;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ステージを選択',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // ステージボタン
          ...entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _StageButton(
                  entry: entry,
                  onTap: () => onStageSelected(entry),
                ),
              )),
        ],
      ),
    );
  }
}

/// ステージボタン
class _StageButton extends StatefulWidget {
  final StageEntry entry;
  final VoidCallback onTap;

  const _StageButton({
    required this.entry,
    required this.onTap,
  });

  @override
  State<_StageButton> createState() => _StageButtonState();
}

class _StageButtonState extends State<_StageButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.orange.withValues(alpha: 0.8)
              : Colors.orange.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange,
            width: 2,
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
        ),
        transform: _isPressed
            ? Matrix4.translationValues(0, 2, 0)
            : Matrix4.identity(),
        child: Row(
          children: [
            // レベル番号
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${widget.entry.level}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // ステージ名
            Expanded(
              child: Text(
                widget.entry.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            // 矢印
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}
