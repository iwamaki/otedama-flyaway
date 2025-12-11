import 'package:flutter/material.dart';

import '../models/stage_data.dart';
import '../services/audio_service.dart';
import 'settings_modal.dart';

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

  int _titleTapCount = 0;
  DateTime? _lastTitleTap;

  /// デフォルトのタイトルBGM
  static const String _defaultBgm = 'audio/bgm/初茜.mp3';
  static const double _defaultBgmVolume = 0.3;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();

    // BGMを開始
    _initAudioAndPlayBgm();
  }

  Future<void> _initAudioAndPlayBgm() async {
    await AudioService.instance.initialize();
    // スタート画面ではゲームループがないのでフェードなしで即時再生
    AudioService.instance.playBgm(_defaultBgm, volume: _defaultBgmVolume, fadeDuration: 0);
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

  void _openSettings(BuildContext context) {
    SettingsModal.show(context);
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
              child: Stack(
                children: [
                  // メインコンテンツ
                  Column(
                    children: [
                      const Spacer(flex: 2),
                      // タイトル
                      GestureDetector(
                        onTap: _onTitleTap,
                        child: const Column(
                          children: [
                            Text(
                              'Otedama',
                              style: TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 4,
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
                      // ゲーム開始ボタン
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: _StartButton(
                          onTap: () {
                            // デフォルトステージ（level 1のステージ）で開始
                            final defaultStage = StageRegistry.entries.isNotEmpty
                                ? StageRegistry.entries.firstWhere(
                                    (e) => e.level >= 1,
                                    orElse: () => StageRegistry.entries.first,
                                  )
                                : null;
                            widget.onStart(StartScreenResult(selectedStage: defaultStage));
                          },
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                  // 設定ボタン（右上）
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _SettingsButton(
                      onTap: () => _openSettings(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ゲーム開始ボタン
class _StartButton extends StatefulWidget {
  final VoidCallback onTap;

  const _StartButton({required this.onTap});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _isPressed ? 0.6 : 1.0,
        child: const Text(
          'Tap to Start',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: 3,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 4,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 設定ボタン
class _SettingsButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _isPressed ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.settings,
            color: Colors.white70,
            size: 24,
          ),
        ),
      ),
    );
  }
}
