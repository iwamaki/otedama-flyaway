import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/stage/image_object.dart';
import '../../components/stage/stage_object.dart';
import '../../components/stage/transition_zone.dart';
import '../../game/otedama_game.dart';
import 'transition_zone_settings.dart';

/// オブジェクト操作パネル
class ObjectPanel extends StatefulWidget {
  final StageObject object;
  final OtedamaGame game;

  const ObjectPanel({
    super.key,
    required this.object,
    required this.game,
  });

  @override
  State<ObjectPanel> createState() => _ObjectPanelState();
}

class _ObjectPanelState extends State<ObjectPanel> {
  @override
  Widget build(BuildContext context) {
    final obj = widget.object;

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
          _PositionControls(
            onMove: (dx, dy) {
              const moveAmount = 0.5;
              obj.applyProperties({
                'x': obj.position.x + dx * moveAmount,
                'y': obj.position.y + dy * moveAmount,
              });
              setState(() {});
            },
          ),
          const SizedBox(height: 12),

          // 回転スライダー
          _AngleSlider(
            angle: obj.angle,
            onChanged: (value) {
              obj.applyProperties({'angle': value});
              setState(() {});
            },
          ),

          // サイズ変更スライダー
          if (obj.canResize && obj.width != null)
            _SizeSlider(
              label: '幅',
              value: obj.width!,
              min: 1.0,
              max: 15.0,
              onChanged: (value) {
                obj.applyProperties({'width': value});
                setState(() {});
              },
            ),
          if (obj.canResize && obj.height != null)
            _SizeSlider(
              label: '高さ',
              value: obj.height!,
              min: 0.2,
              max: 3.0,
              onChanged: (value) {
                obj.applyProperties({'height': value});
                setState(() {});
              },
            ),

          // スケールスライダー（ImageObjectのみ）
          if (obj is ImageObject)
            _ScaleSlider(
              scale: obj.scale,
              onChanged: (value) {
                obj.applyProperties({'scale': value});
                setState(() {});
              },
            ),

          // 遷移ゾーン設定
          if (obj is TransitionZone) ...[
            const SizedBox(height: 8),
            TransitionZoneSettings(
              zone: obj,
              game: widget.game,
              onChanged: () => setState(() {}),
            ),
          ],

          const SizedBox(height: 8),

          // アクションボタン
          _ActionButtons(
            object: obj,
            onFlipX: () {
              if (obj is ImageObject) {
                obj.toggleFlipX();
              } else {
                obj.applyProperties({'flipX': !obj.flipX});
              }
              setState(() {});
            },
            onFlipY: () {
              if (obj is ImageObject) {
                obj.toggleFlipY();
              } else {
                obj.applyProperties({'flipY': !obj.flipY});
              }
              setState(() {});
            },
            onDelete: () {
              widget.game.deleteSelectedObject();
            },
          ),
        ],
      ),
    );
  }
}

/// 位置調整ボタン
class _PositionControls extends StatelessWidget {
  final void Function(int dx, int dy) onMove;

  const _PositionControls({required this.onMove});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MoveButton(icon: Icons.arrow_back, onPressed: () => onMove(-1, 0)),
        Column(
          children: [
            _MoveButton(icon: Icons.arrow_upward, onPressed: () => onMove(0, -1)),
            const SizedBox(height: 4),
            _MoveButton(icon: Icons.arrow_downward, onPressed: () => onMove(0, 1)),
          ],
        ),
        _MoveButton(icon: Icons.arrow_forward, onPressed: () => onMove(1, 0)),
      ],
    );
  }
}

class _MoveButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MoveButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
      iconSize: 32,
      padding: const EdgeInsets.all(4),
    );
  }
}

/// 回転スライダー
class _AngleSlider extends StatelessWidget {
  final double angle;
  final ValueChanged<double> onChanged;

  const _AngleSlider({
    required this.angle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final angleDegrees = (angle * 180 / math.pi).round();
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
              onChanged(angleRadians);
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
}

/// サイズ変更スライダー
class _SizeSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SizeSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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

/// スケールスライダー
class _ScaleSlider extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;

  const _ScaleSlider({
    required this.scale,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
        Expanded(
          child: Slider(
            value: scale.clamp(0.02, 0.2),
            min: 0.02,
            max: 0.2,
            onChanged: onChanged,
            activeColor: Colors.green,
          ),
        ),
        const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
      ],
    );
  }
}

/// アクションボタン群
class _ActionButtons extends StatelessWidget {
  final StageObject object;
  final VoidCallback onFlipX;
  final VoidCallback onFlipY;
  final VoidCallback onDelete;

  const _ActionButtons({
    required this.object,
    required this.onFlipX,
    required this.onFlipY,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // 水平反転
        if (object.canFlip || object is ImageObject)
          _ActionButton(
            icon: Icons.flip,
            label: 'H反転',
            onPressed: onFlipX,
            isActive: object.flipX,
          ),
        // 垂直反転
        if (object.canFlip || object is ImageObject)
          _ActionButton(
            icon: Icons.flip,
            label: 'V反転',
            onPressed: onFlipY,
            rotated: true,
            isActive: object.flipY,
          ),
        // 削除
        _ActionButton(
          icon: Icons.delete,
          label: '削除',
          onPressed: onDelete,
          color: Colors.red,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool rotated;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Colors.blue,
    this.rotated = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
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
}
