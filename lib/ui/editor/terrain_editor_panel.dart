import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../../components/stage/terrain.dart';

/// Terrain専用の編集パネル
/// 頂点編集とTerrainType変更が可能
class TerrainEditorPanel extends StatefulWidget {
  final Terrain terrain;
  final VoidCallback onChanged;

  const TerrainEditorPanel({
    super.key,
    required this.terrain,
    required this.onChanged,
  });

  @override
  State<TerrainEditorPanel> createState() => _TerrainEditorPanelState();
}

class _TerrainEditorPanelState extends State<TerrainEditorPanel> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // TerrainType選択
        _TerrainTypeSelector(
          currentType: widget.terrain.terrainType,
          onChanged: (type) {
            widget.terrain.setTerrainType(type);
            widget.onChanged();
            setState(() {});
          },
        ),
        const SizedBox(height: 12),

        // 頂点編集セクション
        _VerticesEditor(
          vertices: widget.terrain.vertices,
          onVertexChanged: (index, newPos) {
            widget.terrain.updateVertex(index, newPos);
            widget.onChanged();
            setState(() {});
          },
          onVertexAdded: (vertex) {
            widget.terrain.addVertex(vertex);
            widget.onChanged();
            setState(() {});
          },
          onVertexRemoved: (index) {
            widget.terrain.removeVertex(index);
            widget.onChanged();
            setState(() {});
          },
        ),
      ],
    );
  }
}

/// TerrainType選択ドロップダウン
class _TerrainTypeSelector extends StatelessWidget {
  final TerrainType currentType;
  final ValueChanged<TerrainType> onChanged;

  const _TerrainTypeSelector({
    required this.currentType,
    required this.onChanged,
  });

  String _getTypeLabel(TerrainType type) {
    switch (type) {
      case TerrainType.grass:
        return '草';
      case TerrainType.dirt:
        return '土';
      case TerrainType.rock:
        return '岩';
      case TerrainType.ice:
        return '氷';
      case TerrainType.wood:
        return '木';
      case TerrainType.metal:
        return '金属';
      case TerrainType.snow:
        return '雪';
      case TerrainType.snowIce:
        return '雪氷';
      case TerrainType.stoneTiles:
        return '石タイル';
      case TerrainType.grassEdge:
      case TerrainType.snowEdge:
        return ''; // エッジ装飾専用（選択不可）
    }
  }

  /// エディタで選択可能なTerrainType
  static const _selectableTypes = [
    TerrainType.grass,
    TerrainType.dirt,
    TerrainType.rock,
    TerrainType.ice,
    TerrainType.wood,
    TerrainType.metal,
    TerrainType.snow,
    TerrainType.snowIce,
    TerrainType.stoneTiles,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '種類',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButton<TerrainType>(
              value: currentType,
              isExpanded: true,
              dropdownColor: Colors.grey[850],
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: _selectableTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: type.defaultFillColor,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_getTypeLabel(type)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null) {
                  onChanged(type);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 頂点編集セクション
class _VerticesEditor extends StatelessWidget {
  final List<Vector2> vertices;
  final void Function(int index, Vector2 newPos) onVertexChanged;
  final void Function(Vector2 vertex) onVertexAdded;
  final void Function(int index) onVertexRemoved;

  const _VerticesEditor({
    required this.vertices,
    required this.onVertexChanged,
    required this.onVertexAdded,
    required this.onVertexRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '頂点 (${vertices.length})',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '頂点を追加',
              onPressed: () => _showAddVertexDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // 頂点リスト（スクロール可能）
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vertices.length,
            itemBuilder: (context, index) {
              return _VertexRow(
                index: index,
                vertex: vertices[index],
                canDelete: vertices.length > 3,
                onChanged: (newPos) => onVertexChanged(index, newPos),
                onDelete: () => onVertexRemoved(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddVertexDialog(BuildContext context) async {
    // 新しい頂点のデフォルト位置（最後の頂点の近く）
    final lastVertex = vertices.isNotEmpty ? vertices.last : Vector2.zero();
    final defaultX = lastVertex.x + 2;
    final defaultY = lastVertex.y;

    final result = await showDialog<Vector2>(
      context: context,
      builder: (ctx) {
        final xController = TextEditingController(text: defaultX.toStringAsFixed(1));
        final yController = TextEditingController(text: defaultY.toStringAsFixed(1));
        return AlertDialog(
          title: const Text('頂点を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: xController,
                decoration: const InputDecoration(labelText: 'X座標'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: yController,
                decoration: const InputDecoration(labelText: 'Y座標'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final x = double.tryParse(xController.text) ?? 0;
                final y = double.tryParse(yController.text) ?? 0;
                Navigator.of(ctx).pop(Vector2(x, y));
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      onVertexAdded(result);
    }
  }
}

/// 単一の頂点行
class _VertexRow extends StatelessWidget {
  final int index;
  final Vector2 vertex;
  final bool canDelete;
  final ValueChanged<Vector2> onChanged;
  final VoidCallback onDelete;

  const _VertexRow({
    required this.index,
    required this.vertex,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          // インデックス
          SizedBox(
            width: 20,
            child: Text(
              '$index',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          // X座標
          Expanded(
            child: _CoordinateInput(
              label: 'X',
              value: vertex.x,
              onChanged: (x) => onChanged(Vector2(x, vertex.y)),
            ),
          ),
          const SizedBox(width: 4),
          // Y座標
          Expanded(
            child: _CoordinateInput(
              label: 'Y',
              value: vertex.y,
              onChanged: (y) => onChanged(Vector2(vertex.x, y)),
            ),
          ),
          // 削除ボタン
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24),
              tooltip: '削除',
              onPressed: onDelete,
            )
          else
            const SizedBox(width: 24),
        ],
      ),
    );
  }
}

/// 座標入力フィールド
class _CoordinateInput extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _CoordinateInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showInputDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label:',
              style: const TextStyle(color: Colors.white38, fontSize: 9),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                value.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInputDialog(BuildContext context) async {
    final initialText = value.toStringAsFixed(1);

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: initialText);
        return AlertDialog(
          title: Text('$label座標を入力'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            autofocus: true,
            onSubmitted: (text) {
              final parsed = double.tryParse(text);
              Navigator.of(ctx).pop(parsed);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text);
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      onChanged(result);
    }
  }
}
