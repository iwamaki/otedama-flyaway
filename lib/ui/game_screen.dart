import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/otedama_game.dart' show OtedamaGame, TransitionInfo;
import '../models/stage_data.dart';
import '../services/audio_service.dart';
import '../services/logger_service.dart';
import '../services/settings_service.dart';
import 'clear_screen.dart';
import 'physics_tuner.dart';
import 'stage_editor.dart';
import 'stage_transition_overlay.dart';

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

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late OtedamaGame _game;
  bool _isLoading = true;
  bool _showClearScreen = false;

  /// 遷移中の情報
  TransitionInfo? _pendingTransition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 画面を離れるときにBGMを停止
    AudioService.instance.stopBgmImmediate();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがバックグラウンドに移行したときにBGMを一時停止
    if (state == AppLifecycleState.paused) {
      AudioService.instance.pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.instance.resumeBgm();
    }
  }

  Future<void> _initGame() async {
    logger.info(LogCategory.game, 'Initializing game screen');

    // 設定からスキンを取得
    final skin = SettingsService.instance.selectedSkin;

    _game = OtedamaGame(
      backgroundImage: 'tatami.jpg',
      initialStageAsset: widget.initialStage?.assetPath,
      otedamaSkin: skin,
    );
    _game.onEditModeChanged = () {
      setState(() {});
    };
    // ゴール到達時のコールバック
    _game.onGoalReachedCallback = _onGoalReached;
    // ステージ遷移コールバック
    _game.onStageTransition = _onStageTransition;

    logger.debug(LogCategory.game, 'Stage: ${widget.initialStage?.name ?? "default"}');
    logger.debug(LogCategory.game, 'Developer mode: ${widget.developerMode}');

    setState(() {
      _isLoading = false;
    });
  }

  void _onStageTransition(TransitionInfo info) {
    logger.info(LogCategory.game, 'Stage transition requested: ${info.nextStage}, velocity: ${info.velocity.length.toStringAsFixed(2)}');
    // ビルド中にsetStateが呼ばれる可能性があるため、次フレームに遅延
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _pendingTransition = info;
        });
      }
    });
  }

  Future<void> _loadNextStage() async {
    if (_pendingTransition == null) {
      logger.warning(LogCategory.game, '_loadNextStage: _pendingTransition is null');
      return;
    }

    final info = _pendingTransition!;
    logger.info(LogCategory.game,
        '_loadNextStage: nextStage=${info.nextStage}, velocity=${info.velocity.length.toStringAsFixed(2)}');

    try {
      // 一時保存データがあればそれを使用、なければアセットからロード
      StageData stageData;
      final unsavedData = _game.getUnsavedStage(info.nextStage);
      if (unsavedData != null) {
        stageData = unsavedData;
        logger.debug(LogCategory.stage, 'Using unsaved stage data: ${info.nextStage}');
      } else {
        logger.debug(LogCategory.stage, 'Loading stage from asset: ${info.nextStage}');
        stageData = await StageData.loadFromAsset(info.nextStage);
      }
      logger.debug(LogCategory.stage, 'Stage data loaded: ${stageData.name}, objects: ${stageData.objects.length}');

      await _game.loadStage(
        stageData,
        assetPath: info.nextStage,
        transitionInfo: info,
      );
      _game.resetTransitionState();
      logger.info(LogCategory.game, 'Stage loaded successfully: ${stageData.name}');
    } catch (e, stackTrace) {
      logger.error(LogCategory.stage, 'Failed to load stage: ${info.nextStage}',
          error: e);
      logger.debug(LogCategory.stage, 'Stack trace: $stackTrace');
      _game.resetTransitionState();
      widget.onBackToStart();
    }
  }

  void _onTransitionComplete() {
    setState(() {
      _pendingTransition = null;
    });
  }

  void _onGoalReached() {
    logger.info(LogCategory.game, 'Goal reached - showing clear screen');
    setState(() {
      _showClearScreen = true;
    });
  }

  void _onRetry() {
    logger.info(LogCategory.game, 'Retry requested');
    setState(() {
      _showClearScreen = false;
    });
    _game.resetOtedama();
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

          // クリア画面
          if (_showClearScreen && _game.clearTime != null)
            ClearScreen(
              clearTime: _game.clearTime!,
              onRetry: _onRetry,
              onBackToStart: widget.onBackToStart,
            ),

          // ステージ遷移オーバーレイ
          if (_pendingTransition != null)
            StageTransitionOverlay(
              onFadeOutComplete: _loadNextStage,
              onTransitionComplete: _onTransitionComplete,
            ),
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
