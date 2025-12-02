import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/otedama_game.dart';
import 'ui/physics_tuner.dart';

void main() {
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
            // パラメータ調整UI（開発用）
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
