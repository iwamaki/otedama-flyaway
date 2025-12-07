import 'package:flutter/material.dart';

import '../../components/stage/transition_zone.dart';
import '../../game/otedama_game.dart';
import '../../models/stage_data.dart';

/// 遷移ゾーン設定UI
class TransitionZoneSettings extends StatefulWidget {
  final TransitionZone zone;
  final OtedamaGame game;
  final VoidCallback onChanged;

  const TransitionZoneSettings({
    super.key,
    required this.zone,
    required this.game,
    required this.onChanged,
  });

  @override
  State<TransitionZoneSettings> createState() => _TransitionZoneSettingsState();
}

class _TransitionZoneSettingsState extends State<TransitionZoneSettings> {
  @override
  Widget build(BuildContext context) {
    // 選択肢を構築（未選択 + 登録済みステージ）
    final stageOptions = [
      const DropdownMenuItem<String>(
        value: '',
        child: Text('未選択', style: TextStyle(color: Colors.white38)),
      ),
      ...StageRegistry.entries.map((entry) => DropdownMenuItem<String>(
            value: entry.assetPath,
            child: Text(
              entry.name,
              style: const TextStyle(color: Colors.white),
            ),
          )),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.teal, size: 16),
              SizedBox(width: 4),
              Text(
                '遷移先',
                style: TextStyle(
                  color: Colors.teal,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: StageRegistry.entries.any((e) => e.assetPath == widget.zone.nextStage)
                ? widget.zone.nextStage
                : '',
            items: stageOptions,
            onChanged: (value) {
              widget.zone.applyProperties({'nextStage': value ?? ''});
              widget.onChanged();
            },
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            dropdownColor: Colors.grey[850],
            style: const TextStyle(fontSize: 12),
          ),
          if (widget.zone.nextStage.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '遷移先が未設定です',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                ),
              ),
            ),
          // スポーン位置設定
          if (widget.zone.nextStage.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '出現位置（空欄でデフォルト）',
              style: TextStyle(color: Colors.teal, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _SpawnInput(
                    label: 'X',
                    value: widget.zone.spawnX,
                    onChanged: (value) {
                      widget.zone.applyProperties({'spawnX': value});
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SpawnInput(
                    label: 'Y',
                    value: widget.zone.spawnY,
                    onChanged: (value) {
                      widget.zone.applyProperties({'spawnY': value});
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // リンクID表示
            Row(
              children: [
                const Text(
                  'リンクID: ',
                  style: TextStyle(color: Colors.teal, fontSize: 9),
                ),
                Expanded(
                  child: Text(
                    widget.zone.linkId.length > 12
                        ? '${widget.zone.linkId.substring(0, 12)}...'
                        : widget.zone.linkId,
                    style: TextStyle(
                      color: Colors.teal.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 戻りゾーン追加/更新ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final (success, returnZonePosition) = await widget.game.addReturnTransitionZoneToTargetStage(
                    targetStageAsset: widget.zone.nextStage,
                    currentZonePosition: widget.zone.position.clone(),
                    linkId: widget.zone.linkId,
                  );
                  if (success && returnZonePosition != null) {
                    // 元ゾーンのspawnX/Yを戻りゾーンの位置に更新
                    widget.zone.applyProperties({
                      'spawnX': returnZonePosition.x,
                      'spawnY': returnZonePosition.y,
                    });
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '戻りゾーンを追加/更新しました'
                            : '戻りゾーンの追加/更新に失敗しました'),
                        backgroundColor: success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    widget.onChanged();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.sync_alt, size: 16),
                label: const Text(
                  '戻りゾーンを追加/更新',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// スポーン位置入力フィールド
class _SpawnInput extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  const _SpawnInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toStringAsFixed(1) ?? '',
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: const OutlineInputBorder(),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 11),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (text) {
        if (text.isEmpty) {
          onChanged(null);
        } else {
          final parsed = double.tryParse(text);
          if (parsed != null) {
            onChanged(parsed);
          }
        }
      },
    );
  }
}
