import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/stage/image_object.dart';
import '../game/otedama_game.dart';
import '../models/stage_data.dart';
import '../services/logger_service.dart';
import 'background_picker.dart';
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
          child: _buildEditModeToggle(),
        ),

        // 編集モード時のみ操作UIを表示
        if (widget.game.isEditMode) ...[
          // 上部ツールバー
          Positioned(
            top: 100,
            left: 10,
            child: _buildToolbar(),
          ),

          // 選択オブジェクトの操作パネル（下部）
          if (widget.game.selectedObject != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildObjectPanel(),
            ),
        ],
      ],
    );
  }

  Widget _buildEditModeToggle() {
    final isEditMode = widget.game.isEditMode;
    return FloatingActionButton(
      onPressed: () {
        widget.game.toggleEditMode();
        setState(() {});
      },
      backgroundColor: isEditMode ? Colors.orange : Colors.black54,
      child: Icon(
        isEditMode ? Icons.play_arrow : Icons.edit,
        color: Colors.white,
      ),
    );
  }

  Widget _buildToolbar() {
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
        if (widget.game.selectedObject != null)
          FloatingActionButton.small(
            heroTag: 'deselect',
            onPressed: () {
              widget.game.deselectObject();
              setState(() {});
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
      currentBackground: widget.game.currentBackground,
    );
    // nullの場合はデフォルト背景、それ以外は選択された背景
    // キャンセル時は何も返されないのでそのまま
    if (selected != widget.game.currentBackground) {
      await widget.game.changeBackground(selected);
      setState(() {});
    }
  }

  /// ステージ管理ピッカーを表示
  Future<void> _showStagePicker(BuildContext context) async {
    final result = await StagePicker.show(context);
    if (result == null) return;

    if (result.isNewStage) {
      // 新規作成
      widget.game.clearStage();
      setState(() {});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('新しいステージを作成しました'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (result.selectedEntry != null) {
      // 既存ステージを読み込み
      try {
        final stageData = await StageData.loadFromAsset(result.selectedEntry!.assetPath);
        await widget.game.loadStage(stageData);
        setState(() {});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.selectedEntry!.name} を読み込みました'),
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

  /// エクスポートダイアログを表示
  Future<void> _showExportDialog(BuildContext context) async {
    final levelController = TextEditingController(
      text: widget.game.currentStageLevel.toString(),
    );
    final nameController = TextEditingController(
      text: widget.game.currentStageName,
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
      // 入力値をゲームに反映
      widget.game.currentStageLevel = int.tryParse(levelController.text) ?? 0;
      widget.game.currentStageName = nameController.text.isNotEmpty
          ? nameController.text
          : 'New Stage';

      // エクスポート実行
      _exportStage();
    }

    levelController.dispose();
    nameController.dispose();
  }

  /// ステージをエクスポート
  void _exportStage() {
    final stageData = widget.game.exportStage();
    final jsonString = stageData.toJsonString();

    // クリップボードにコピー
    Clipboard.setData(ClipboardData(text: jsonString));

    // コンソールにも出力
    logger.debug(LogCategory.stage, 'Stage exported: $jsonString');

    // フィードバック
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ステージ「${widget.game.currentStageName}」をクリップボードにコピーしました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showObjectPicker(BuildContext context) async {
    final selected = await ObjectPicker.show(context);
    if (selected == null) return;

    // 選択されたオブジェクトを追加
    switch (selected.type) {
      case ObjectType.primitive:
        if (selected.id == 'platform') {
          await widget.game.addPlatform();
        } else if (selected.id == 'trampoline') {
          await widget.game.addTrampoline();
        } else if (selected.id == 'iceFloor') {
          await widget.game.addIceFloor();
        } else if (selected.id == 'goal') {
          await widget.game.addGoal();
        } else if (selected.id == 'terrain') {
          await widget.game.addTerrain();
        }
        break;
      case ObjectType.image:
        if (selected.imagePath != null) {
          await widget.game.addImageObject(selected.imagePath!);
        }
        break;
    }
    setState(() {});
  }

  Widget _buildObjectPanel() {
    final obj = widget.game.selectedObject;
    if (obj == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // オブジェクトタイプ
          Text(
            obj.type.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 位置調整（微調整ボタン）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMoveButton(Icons.arrow_back, -1, 0),
              Column(
                children: [
                  _buildMoveButton(Icons.arrow_upward, 0, -1),
                  const SizedBox(height: 4),
                  _buildMoveButton(Icons.arrow_downward, 0, 1),
                ],
              ),
              _buildMoveButton(Icons.arrow_forward, 1, 0),
            ],
          ),
          const SizedBox(height: 12),

          // 回転スライダー（1度刻み）
          _buildAngleSlider(obj),

          // サイズ変更スライダー（対応オブジェクトのみ）
          if (obj.canResize && obj.width != null) ...[
            _buildSizeSlider('幅', obj.width!, 1.0, 15.0, (value) {
              obj.applyProperties({'width': value});
              setState(() {});
            }),
          ],
          if (obj.canResize && obj.height != null) ...[
            _buildSizeSlider('高さ', obj.height!, 0.2, 3.0, (value) {
              obj.applyProperties({'height': value});
              setState(() {});
            }),
          ],

          // スケールスライダー（ImageObjectのみ）
          if (obj is ImageObject) ...[
            Row(
              children: [
                const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                Expanded(
                  child: Slider(
                    value: obj.scale.clamp(0.02, 0.2),
                    min: 0.02,
                    max: 0.2,
                    onChanged: (value) {
                      obj.applyProperties({'scale': value});
                      setState(() {});
                    },
                    activeColor: Colors.green,
                  ),
                ),
                const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // アクションボタン
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // 水平反転（対応オブジェクト）
              if (obj.canFlip || obj is ImageObject)
                _buildActionButton(
                  Icons.flip,
                  'H反転',
                  () {
                    if (obj is ImageObject) {
                      obj.toggleFlipX();
                    } else {
                      obj.applyProperties({'flipX': !obj.flipX});
                    }
                    setState(() {});
                  },
                  isActive: obj.flipX,
                ),
              // 垂直反転（対応オブジェクト）
              if (obj.canFlip || obj is ImageObject)
                _buildActionButton(
                  Icons.flip,
                  'V反転',
                  () {
                    if (obj is ImageObject) {
                      obj.toggleFlipY();
                    } else {
                      obj.applyProperties({'flipY': !obj.flipY});
                    }
                    setState(() {});
                  },
                  rotated: true,
                  isActive: obj.flipY,
                ),
              // 削除
              _buildActionButton(
                Icons.delete,
                '削除',
                () {
                  widget.game.deleteSelectedObject();
                  setState(() {});
                },
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoveButton(IconData icon, int dx, int dy) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: () {
        final obj = widget.game.selectedObject;
        if (obj != null) {
          final moveAmount = 0.5;
          obj.applyProperties({
            'x': obj.position.x + dx * moveAmount,
            'y': obj.position.y + dy * moveAmount,
          });
          setState(() {});
        }
      },
      iconSize: 32,
      padding: const EdgeInsets.all(4),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    Color color = Colors.blue,
    bool rotated = false,
    bool isActive = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.green : color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Transform.rotate(
        angle: rotated ? math.pi / 2 : 0,
        child: Icon(icon, size: 18),
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  /// 回転スライダー（1度刻み）
  Widget _buildAngleSlider(dynamic obj) {
    final angleDegrees = (obj.angle * 180 / math.pi).round();
    return Row(
      children: [
        const Icon(Icons.rotate_left, color: Colors.white70, size: 20),
        Expanded(
          child: Slider(
            value: angleDegrees.toDouble(),
            min: -180,
            max: 180,
            divisions: 360,
            onChanged: (value) {
              final angleRadians = value * math.pi / 180;
              obj.applyProperties({'angle': angleRadians});
              setState(() {});
            },
            activeColor: Colors.amber,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$angleDegrees°',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// サイズ変更スライダー
  Widget _buildSizeSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.cyan,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

}
