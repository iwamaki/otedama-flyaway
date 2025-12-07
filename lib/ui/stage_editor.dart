import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/otedama_game.dart';
import '../models/stage_data.dart';
import '../services/logger_service.dart';
import 'background_picker.dart';
import 'editor/object_panel.dart';
import 'object_picker.dart';
import 'stage_picker.dart';

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
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 編集モード切り替えボタン（左上）
        Positioned(
          top: 40,
          left: 10,
          child: _EditModeToggle(
            isEditMode: widget.game.isEditMode,
            onToggle: () {
              widget.game.toggleEditMode();
              setState(() {});
            },
          ),
        ),

        // 編集モード時のみ操作UIを表示
        if (widget.game.isEditMode) ...[
          // 上部ツールバー
          Positioned(
            top: 100,
            left: 10,
            child: _EditorToolbar(
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

/// 編集モード切り替えボタン
class _EditModeToggle extends StatelessWidget {
  final bool isEditMode;
  final VoidCallback onToggle;

  const _EditModeToggle({
    required this.isEditMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onToggle,
      backgroundColor: isEditMode ? Colors.orange : Colors.black54,
      child: Icon(
        isEditMode ? Icons.play_arrow : Icons.edit,
        color: Colors.white,
      ),
    );
  }
}

/// エディタツールバー
class _EditorToolbar extends StatelessWidget {
  final OtedamaGame game;
  final VoidCallback onStateChanged;

  const _EditorToolbar({
    required this.game,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ステージ管理ボタン
        FloatingActionButton.small(
          heroTag: 'stage_manager',
          onPressed: () => _showStagePicker(context),
          backgroundColor: Colors.amber,
          child: const Icon(Icons.folder_open, color: Colors.white),
        ),
        const SizedBox(height: 8),
        // オブジェクト追加ボタン
        FloatingActionButton.small(
          heroTag: 'add_object',
          onPressed: () => _showObjectPicker(context),
          backgroundColor: Colors.green,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        const SizedBox(height: 8),
        // 背景変更ボタン
        FloatingActionButton.small(
          heroTag: 'change_bg',
          onPressed: () => _showBackgroundPicker(context),
          backgroundColor: Colors.purple,
          child: const Icon(Icons.image, color: Colors.white),
        ),
        const SizedBox(height: 8),
        // エクスポートボタン
        FloatingActionButton.small(
          heroTag: 'export',
          onPressed: () => _showExportDialog(context),
          backgroundColor: Colors.blue,
          child: const Icon(Icons.save, color: Colors.white),
        ),
        const SizedBox(height: 8),
        // 選択解除ボタン
        if (game.selectedObject != null)
          FloatingActionButton.small(
            heroTag: 'deselect',
            onPressed: () {
              game.deselectObject();
              onStateChanged();
            },
            backgroundColor: Colors.grey,
            child: const Icon(Icons.deselect, color: Colors.white),
          ),
      ],
    );
  }

  Future<void> _showBackgroundPicker(BuildContext context) async {
    final selected = await BackgroundPicker.show(
      context,
      currentBackground: game.currentBackground,
    );
    if (selected != game.currentBackground) {
      await game.changeBackground(selected);
      onStateChanged();
    }
  }

  Future<void> _showStagePicker(BuildContext context) async {
    final result = await StagePicker.show(
      context,
      unsavedStageAssets: game.unsavedStageAssets,
    );
    if (result == null) return;

    if (result.isNewStage) {
      game.clearStage();
      onStateChanged();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('新しいステージを作成しました'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (result.selectedEntry != null) {
      try {
        final assetPath = result.selectedEntry!.assetPath;
        final unsavedData = game.getUnsavedStage(assetPath);
        final StageData stageData;
        final bool isUnsaved;

        if (unsavedData != null) {
          stageData = unsavedData;
          isUnsaved = true;
        } else {
          stageData = await StageData.loadFromAsset(assetPath);
          isUnsaved = false;
        }

        await game.loadStage(stageData, assetPath: assetPath);
        onStateChanged();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUnsaved
                  ? '${result.selectedEntry!.name} を読み込みました（未保存の変更あり）'
                  : '${result.selectedEntry!.name} を読み込みました',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showExportDialog(BuildContext context) async {
    final levelController = TextEditingController(
      text: game.currentStageLevel.toString(),
    );
    final nameController = TextEditingController(
      text: game.currentStageName,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ステージをエクスポート'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: levelController,
              decoration: const InputDecoration(
                labelText: 'ステージレベル',
                hintText: '1, 2, 3...',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ステージ名',
                hintText: 'ステージ1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('エクスポート'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      game.currentStageLevel = int.tryParse(levelController.text) ?? 0;
      game.currentStageName = nameController.text.isNotEmpty
          ? nameController.text
          : 'New Stage';

      _exportStage(context);
    }

    levelController.dispose();
    nameController.dispose();
  }

  void _exportStage(BuildContext context) {
    final stageData = game.exportStage();
    final jsonString = stageData.toJsonString();

    Clipboard.setData(ClipboardData(text: jsonString));
    logger.debug(LogCategory.stage, 'Stage exported: $jsonString');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ステージ「${game.currentStageName}」をクリップボードにコピーしました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showObjectPicker(BuildContext context) async {
    final selected = await ObjectPicker.show(context);
    if (selected == null) return;

    switch (selected.type) {
      case ObjectType.primitive:
        if (selected.id == 'platform') {
          await game.addPlatform();
        } else if (selected.id == 'trampoline') {
          await game.addTrampoline();
        } else if (selected.id == 'iceFloor') {
          await game.addIceFloor();
        } else if (selected.id == 'goal') {
          await game.addGoal();
        } else if (selected.id == 'terrain') {
          await game.addTerrain();
        } else if (selected.id == 'transitionZone') {
          await game.addTransitionZone();
        }
        break;
      case ObjectType.image:
        if (selected.imagePath != null) {
          await game.addImageObject(selected.imagePath!);
        }
        break;
    }
    onStateChanged();
  }
}
