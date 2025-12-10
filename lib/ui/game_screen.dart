import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/otedama_game.dart' show OtedamaGame, TransitionInfo;
import '../models/stage_data.dart';
import '../services/audio_service.dart';
import '../services/loading_manager.dart';
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
  OtedamaGame? _game;
  bool _showClearScreen = false;

  /// 遷移中の情報
  TransitionInfo? _pendingTransition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGame();
  }

  /// ゲームインスタンス（初期化後にアクセス）
  OtedamaGame get game => _game!;

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

  void _initGame() {
    logger.info(LogCategory.game, 'Initializing game screen');

    // 設定からスキンを取得
    final skin = SettingsService.instance.selectedSkin;

    final newGame = OtedamaGame(
      backgroundImage: 'tatami.jpg',
      initialStageAsset: widget.initialStage?.assetPath,
      otedamaSkin: skin,
    );
    newGame.onEditModeChanged = () {
      setState(() {});
    };
    // ゴール到達時のコールバック
    newGame.onGoalReachedCallback = _onGoalReached;
    // ステージ遷移コールバック
    newGame.onStageTransition = _onStageTransition;

    logger.debug(LogCategory.game, 'Stage: ${widget.initialStage?.name ?? "default"}');
    logger.debug(LogCategory.game, 'Developer mode: ${widget.developerMode}');

    setState(() {
      _game = newGame;
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
      // 開発者モードの場合、遷移前に現在のステージを一時保存
      // （編集中の変更が遷移先で反映されるようにする）
      if (widget.developerMode) {
        game.saveCurrentStageTemporarily();
        logger.debug(LogCategory.stage, 'Saved current stage before transition (developer mode)');
      }

      // 一時保存データがあればそれを使用
      StageData stageData;
      final unsavedData = game.getUnsavedStage(info.nextStage);
      if (unsavedData != null) {
        stageData = unsavedData;
        logger.debug(LogCategory.stage, 'Using unsaved stage data: ${info.nextStage}');
      } else {
        // LoadingManagerでプリロード（キャッシュがあればそれを使用）
        final preloaded = LoadingManager.instance.getPreloadedStage(info.nextStage);
        if (preloaded != null) {
          stageData = preloaded.stageData;
          logger.debug(LogCategory.stage, 'Using preloaded stage data: ${info.nextStage}');
        } else {
          // プリロードされていない場合はLoadingManagerでプリロード
          logger.debug(LogCategory.stage, 'Preloading stage: ${info.nextStage}');
          final result = await LoadingManager.instance.preloadStage(info.nextStage);
          stageData = result.stageData;
        }
      }
      logger.debug(LogCategory.stage, 'Stage data loaded: ${stageData.name}, objects: ${stageData.objects.length}');

      await game.loadStage(
        stageData,
        assetPath: info.nextStage,
        transitionInfo: info,
      );
      game.resetTransitionState();
      logger.info(LogCategory.game, 'Stage loaded successfully: ${stageData.name}');

      // 隣接ステージを先行プリロード（バックグラウンド）
      LoadingManager.instance.preloadAdjacentStages(stageData);
    } catch (e, stackTrace) {
      logger.error(LogCategory.stage, 'Failed to load stage: ${info.nextStage}',
          error: e);
      logger.debug(LogCategory.stage, 'Stack trace: $stackTrace');
      game.resetTransitionState();
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
    game.resetOtedama();
  }

  @override
  Widget build(BuildContext context) {
    // ゲームインスタンスがまだ作成されていない場合はローディング表示
    if (_game == null) {
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
          // ゲーム本体（onLoad完了までloadingBuilderを表示）
          GameWidget(
            game: game,
            loadingBuilder: (context) => const Center(
              child: CircularProgressIndicator(
                color: Colors.orange,
              ),
            ),
          ),

          // 開発者モードUI
          if (widget.developerMode) ...[
            // ステージエディタUI
            StageEditor(game: game),
            // パラメータ調整UI（開発用）- 編集モード中は非表示
            if (!game.isEditMode)
              PhysicsTuner(
                onRebuild: () {
                  game.otedama?.rebuild();
                },
                onReset: () {
                  game.resetOtedama();
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
                  game.resetOtedama();
                },
              ),
            ),
          ],

          // クリア画面
          if (_showClearScreen && game.clearTime != null)
            ClearScreen(
              clearTime: game.clearTime!,
              onRetry: _onRetry,
              onBackToStart: widget.onBackToStart,
            ),

          // ステージ遷移オーバーレイ
          if (_pendingTransition != null)
            StageTransitionOverlay(
              onFadeOutComplete: _loadNextStage,
              onTransitionComplete: _onTransitionComplete,
              onPausePhysics: () {
                game.paused = true;
                logger.debug(LogCategory.game, 'Physics paused for stage transition');
              },
              onResumePhysics: () {
                game.paused = false;
                logger.debug(LogCategory.game, 'Physics resumed after stage transition');
              },
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
