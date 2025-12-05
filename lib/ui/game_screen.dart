import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/otedama_game.dart';
import '../models/stage_data.dart' show StageEntry;
import 'physics_tuner.dart';
import 'stage_editor.dart';

/// ゲーム画面
/// 通常モードと開発者モードをサポート
class GameScreen extends StatefulWidget {
  /// 選択されたステージ
  final StageEntry? initialStage;

  /// 開発者モードで起動するか
  final bool developerMode;

  /// スタート画面に戻る
  final VoidCallback onBackToStart;

  const GameScreen({
    super.key,
    this.initialStage,
    this.developerMode = false,
    required this.onBackToStart,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late OtedamaGame _game;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    _game = OtedamaGame(
      backgroundImage: 'tatami.jpg',
      initialStageAsset: widget.initialStage?.assetPath,
    );
    _game.onEditModeChanged = () {
      setState(() {});
    };

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.orange,
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ゲーム本体
          GameWidget(game: _game),

          // 開発者モードUI
          if (widget.developerMode) ...[
            // ステージエディタUI
            StageEditor(game: _game),
            // パラメータ調整UI（開発用）- 編集モード中は非表示
            if (!_game.isEditMode)
              PhysicsTuner(
                onRebuild: () {
                  _game.otedama?.rebuild();
                },
                onReset: () {
                  _game.resetOtedama();
                },
              ),
          ],

          // 通常モードUI
          if (!widget.developerMode) ...[
            // 戻るボタン
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: _BackButton(onTap: widget.onBackToStart),
            ),
            // リセットボタン
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: _ResetButton(
                onTap: () {
                  _game.resetOtedama();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 戻るボタン
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

/// リセットボタン
class _ResetButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ResetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.refresh_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
