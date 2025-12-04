import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../components/stage/image_object.dart';
import '../game/otedama_game.dart';
import 'object_picker.dart';

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
        // オブジェクト追加ボタン
        FloatingActionButton.small(
          heroTag: 'add_object',
          onPressed: () => _showObjectPicker(context),
          backgroundColor: Colors.green,
          child: const Icon(Icons.add, color: Colors.white),
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

  Future<void> _showObjectPicker(BuildContext context) async {
    final selected = await ObjectPicker.show(context);
    if (selected == null) return;

    // 選択されたオブジェクトを追加
    switch (selected.type) {
      case ObjectType.primitive:
        if (selected.id == 'platform') {
          await widget.game.addPlatform();
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

          // 回転スライダー
          Row(
            children: [
              const Icon(Icons.rotate_left, color: Colors.white70, size: 20),
              Expanded(
                child: Slider(
                  value: _normalizeAngle(obj.angle),
                  min: -math.pi,
                  max: math.pi,
                  onChanged: (value) {
                    obj.applyProperties({'angle': value});
                    setState(() {});
                  },
                  activeColor: Colors.amber,
                ),
              ),
              const Icon(Icons.rotate_right, color: Colors.white70, size: 20),
            ],
          ),

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
              // 水平反転（ImageObjectのみ）
              if (obj is ImageObject)
                _buildActionButton(
                  Icons.flip,
                  'H反転',
                  () {
                    obj.toggleFlipX();
                    setState(() {});
                  },
                ),
              // 垂直反転（ImageObjectのみ）
              if (obj is ImageObject)
                _buildActionButton(
                  Icons.flip,
                  'V反転',
                  () {
                    obj.toggleFlipY();
                    setState(() {});
                  },
                  rotated: true,
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
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Transform.rotate(
        angle: rotated ? math.pi / 2 : 0,
        child: Icon(icon, size: 18),
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  double _normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }
}
