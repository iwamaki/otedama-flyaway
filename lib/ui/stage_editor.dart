import 'dart:async';

import 'package:flutter/material.dart';

import '../game/otedama_game.dart';
import 'editor/debug_info.dart';
import 'editor/edit_mode_toggle.dart';
import 'editor/editor_toolbar.dart';
import 'editor/object_panel.dart';

/// ステージエディタUI
/// 編集モードの切り替えと、選択オブジェクトの操作パネルを提供
class StageEditor extends StatefulWidget {
  final OtedamaGame game;

  const StageEditor({
    super.key,
    required this.game,
  });

  @override
  State<StageEditor> createState() => _StageEditorState();
}

class _StageEditorState extends State<StageEditor> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // 編集モード時に座標表示を更新するタイマー
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (widget.game.isEditMode && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 編集モード切り替えボタン（左上）
        Positioned(
          top: 40,
          left: 10,
          child: EditModeToggle(
            isEditMode: widget.game.isEditMode,
            onToggle: () {
              widget.game.toggleEditMode();
              setState(() {});
            },
          ),
        ),

        // 編集モード時のみ操作UIを表示
        if (widget.game.isEditMode) ...[
          // お手玉座標デバッグ表示（右上）
          Positioned(
            top: 40,
            right: 10,
            child: OtedamaDebugInfo(game: widget.game),
          ),

          // 上部ツールバー
          Positioned(
            top: 100,
            left: 10,
            child: EditorToolbar(
              game: widget.game,
              onStateChanged: () => setState(() {}),
            ),
          ),

          // 選択オブジェクトの操作パネル（下部）
          if (widget.game.selectedObject != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: ObjectPanel(
                object: widget.game.selectedObject!,
                game: widget.game,
              ),
            ),
        ],
      ],
    );
  }
}
