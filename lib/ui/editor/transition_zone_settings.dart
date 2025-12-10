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
          // リンクID表示（出現位置はlinkIdで自動解決される）
          if (widget.zone.nextStage.isNotEmpty) ...[
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
            // 戻りゾーン追加ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final success = await widget.game.addReturnTransitionZoneToTargetStage(
                    targetStageAsset: widget.zone.nextStage,
                    currentZonePosition: widget.zone.position.clone(),
                    linkId: widget.zone.linkId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '戻りゾーンを追加しました'
                            : '戻りゾーンの追加に失敗しました'),
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
                icon: const Icon(Icons.add_link, size: 16),
                label: const Text(
                  '戻りゾーンを追加',
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
