import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/stage/goal.dart';
import 'components/stage/image_object.dart';
import 'components/stage/platform.dart';
import 'game/otedama_game.dart';
import 'ui/physics_tuner.dart';
import 'ui/stage_editor.dart';

void main() {
  // ステージオブジェクトのファクトリを登録
  registerPlatformFactory();
  registerImageObjectFactory();
  registerGoalFactory();

  runApp(const OtedamaApp());
}

class OtedamaApp extends StatefulWidget {
  const OtedamaApp({super.key});

  @override
  State<OtedamaApp> createState() => _OtedamaAppState();
}

class _OtedamaAppState extends State<OtedamaApp> {
  late OtedamaGame _game;

  @override
  void initState() {
    super.initState();
    _game = OtedamaGame(backgroundImage: 'tatami.jpg');
    _game.onEditModeChanged = () {
      setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            // ゲーム本体
            GameWidget(game: _game),
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
        ),
      ),
    );
  }
}
