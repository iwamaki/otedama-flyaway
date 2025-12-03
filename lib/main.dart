import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/otedama_game.dart';
import 'ui/physics_tuner.dart';
import 'ui/stage_editor.dart';

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
            StageEditor(
              game: _game,
              onImportImage: _showImagePicker,
            ),
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

  /// 画像選択ダイアログを表示
  void _showImagePicker() async {
    // assets/images内の画像リストを表示
    final images = ['branch.png']; // TODO: 動的に取得

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画像を選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: images.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.image),
              title: Text(images[index]),
              onTap: () => Navigator.pop(context, images[index]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _game.addImageObject(selected);
      setState(() {});
    }
  }
}
