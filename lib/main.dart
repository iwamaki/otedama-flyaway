import 'package:flutter/material.dart';

import 'components/stage/goal.dart';
import 'components/stage/image_object.dart';
import 'components/stage/platform.dart';
import 'models/stage_data.dart';
import 'services/settings_service.dart';
import 'ui/game_screen.dart';
import 'ui/start_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ステージオブジェクトのファクトリを登録
  registerPlatformFactory();
  registerImageObjectFactory();
  registerGoalFactory();

  // 設定サービスを初期化
  await SettingsService.instance.init();

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
