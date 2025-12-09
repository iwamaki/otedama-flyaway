import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'components/stage/goal.dart';
import 'components/stage/ice_floor.dart';
import 'components/stage/image_object.dart';
import 'components/stage/platform.dart';
import 'components/stage/terrain.dart';
import 'components/stage/trampoline.dart';
import 'components/stage/transition_zone.dart';
import 'models/stage_data.dart';
import 'services/asset_preloader.dart';
import 'services/logger_service.dart';
import 'services/settings_service.dart';
import 'ui/game_screen.dart';
import 'ui/start_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 環境設定ファイルを読み込み（.envはNext.jsでブロックされるためリネーム）
  await dotenv.load(fileName: 'config.txt');

  // ロガーを初期化
  // LOG_LEVEL で制御: debug, info, warning, error, none
  // 未指定の場合はkDebugModeに従う
  final logLevel = dotenv.env['LOG_LEVEL'] ?? '';
  final debugMode = _resolveDebugMode(logLevel);
  logger.setDebugMode(debugMode);
  logger.info(LogCategory.system, 'App starting...');
  logger.config(LogCategory.system, 'Debug mode: $debugMode (LOG_LEVEL: ${logLevel.isEmpty ? "not set" : logLevel})');

  // ステージオブジェクトのファクトリを登録
  registerPlatformFactory();
  registerImageObjectFactory();
  registerGoalFactory();
  registerTrampolineFactory();
  registerIceFloorFactory();
  registerTerrainFactory();
  registerTransitionZoneFactory();

  // 設定サービスを初期化
  await SettingsService.instance.init();
  logger.info(LogCategory.system, 'Settings service initialized');

  // 地形テクスチャをプリロード
  await TerrainTextureCache.instance.loadAll();
  logger.info(LogCategory.system, 'Terrain textures preloaded');

  // 背景画像をプリロード
  await AssetPreloader.instance.loadAll();

  runApp(const OtedamaApp());
}

class OtedamaApp extends StatefulWidget {
  const OtedamaApp({super.key});

  @override
  State<OtedamaApp> createState() => _OtedamaAppState();
}

class _OtedamaAppState extends State<OtedamaApp> {
  /// 現在の画面状態
  _ScreenState _screenState = _ScreenState.start;

  /// 選択されたステージ
  StageEntry? _selectedStage;

  /// 開発者モード
  bool _developerMode = false;

  void _onStartGame(StartScreenResult result) {
    setState(() {
      _selectedStage = result.selectedStage;
      _developerMode = result.developerMode;
      _screenState = _ScreenState.game;
    });
  }

  void _onBackToStart() {
    setState(() {
      _screenState = _ScreenState.start;
      _selectedStage = null;
      _developerMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.orange,
      ),
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_screenState) {
      case _ScreenState.start:
        return StartScreen(onStart: _onStartGame);
      case _ScreenState.game:
        return GameScreen(
          initialStage: _selectedStage,
          developerMode: _developerMode,
          onBackToStart: _onBackToStart,
        );
    }
  }
}

/// 画面状態
enum _ScreenState {
  start,
  game,
}

/// 環境変数からデバッグモードを解決
bool _resolveDebugMode(String logLevel) {
  switch (logLevel.toLowerCase()) {
    case 'debug':
    case 'info':
    case 'all':
      return true;
    case 'warning':
    case 'error':
    case 'none':
      return false;
    default:
      // 未指定の場合はFlutterのデフォルトに従う
      return kDebugMode;
  }
}
