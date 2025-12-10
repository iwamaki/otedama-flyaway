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
  late TextEditingController _idController;
  List<TransitionZoneInfo> _targetZones = [];
  bool _loadingZones = false;
  int _dropdownKey = 0; // ドロップダウンを強制更新するためのキー

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.zone.id);
    _loadTargetZones();
  }

  @override
  void didUpdateWidget(covariant TransitionZoneSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone.id != widget.zone.id) {
      _idController.text = widget.zone.id;
    }
    if (oldWidget.zone.nextStage != widget.zone.nextStage) {
      _loadTargetZones();
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _loadTargetZones() async {
    if (widget.zone.nextStage.isEmpty) {
      setState(() {
        _targetZones = [];
        _dropdownKey++;
      });
      return;
    }

    setState(() {
      _loadingZones = true;
    });

    try {
      List<TransitionZoneInfo> zones;

      // 現在編集中のステージと同じ場合は、stageObjectsから直接取得
      if (widget.zone.nextStage == widget.game.currentStageAsset) {
        zones = widget.game.stageObjects
            .whereType<TransitionZone>()
            .where((z) => z.id != widget.zone.id) // 自分自身は除外
            .map((z) => TransitionZoneInfo(
                  id: z.id,
                  x: z.position.x,
                  y: z.position.y,
                  nextStage: z.nextStage,
                  targetZoneId: z.targetZoneId,
                ))
            .toList();
      } else {
        // 別のステージの場合は一時保存データかアセットから取得
        final unsaved = widget.game.getUnsavedStage(widget.zone.nextStage);
        final StageData targetStage;
        if (unsaved != null) {
          targetStage = unsaved;
        } else {
          targetStage = await StageData.loadFromAsset(widget.zone.nextStage);
        }
        zones = targetStage.transitionZones;
      }

      if (mounted) {
        setState(() {
          _targetZones = zones;
          _loadingZones = false;
          _dropdownKey++; // キーを更新してドロップダウンを再構築
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _targetZones = [];
          _loadingZones = false;
          _dropdownKey++;
        });
      }
    }
  }

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
          // ヘッダー（右上に更新ボタン）
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.teal, size: 16),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  '遷移ゾーン設定',
                  style: TextStyle(
                    color: Colors.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.zone.nextStage.isNotEmpty)
                _loadingZones
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                      )
                    : InkWell(
                        onTap: _loadTargetZones,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.refresh, size: 16, color: Colors.teal),
                        ),
                      ),
            ],
          ),
          const SizedBox(height: 8),
          // このゾーンのID入力
          _buildIdInput(),
          const SizedBox(height: 12),
          // 遷移先ステージ選択
          const Text(
            '遷移先ステージ',
            style: TextStyle(color: Colors.teal, fontSize: 10),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            key: ValueKey('stage_${widget.zone.nextStage}'),
            value: StageRegistry.entries.any((e) => e.assetPath == widget.zone.nextStage)
                ? widget.zone.nextStage
                : '',
            items: stageOptions,
            onChanged: (value) {
              widget.zone.applyProperties({
                'nextStage': value ?? '',
                'targetZoneId': null, // 遷移先が変わったらリセット
              });
              widget.onChanged();
              // 遷移先が変わったら再読み込み
              _loadTargetZones();
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
          // 遷移先ゾーン設定
          // リスポーン位置（respawnSide）
          const SizedBox(height: 12),
          _buildRespawnSideSelector(),
          if (widget.zone.nextStage.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTargetZoneSelector(),
            const SizedBox(height: 8),
            // 戻りゾーン追加ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final returnZoneId = await widget.game.addReturnTransitionZoneToTargetStage(
                    targetStageAsset: widget.zone.nextStage,
                    currentZonePosition: widget.zone.position.clone(),
                    sourceZoneId: widget.zone.id,
                  );
                  if (returnZoneId != null) {
                    // 元ゾーンのtargetZoneIdを戻りゾーンのIDに設定
                    widget.zone.applyProperties({'targetZoneId': returnZoneId});
                    // ゾーン一覧を再読み込み
                    await _loadTargetZones();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(returnZoneId != null
                            ? '戻りゾーンを追加し、遷移先を設定しました'
                            : '戻りゾーンの追加に失敗しました'),
                        backgroundColor: returnZoneId != null ? Colors.green : Colors.red,
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

  Widget _buildIdInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'このゾーンID',
          style: TextStyle(color: Colors.teal, fontSize: 10),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _idController,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: () {
                final newId = TransitionZone.generateId();
                _idController.text = newId;
                widget.zone.applyProperties({'id': newId});
                widget.onChanged();
              },
              tooltip: '新しいIDを生成',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.zone.applyProperties({'id': value});
              widget.onChanged();
            }
          },
          onEditingComplete: () {
            final value = _idController.text;
            if (value.isNotEmpty) {
              widget.zone.applyProperties({'id': value});
              widget.onChanged();
            }
          },
        ),
      ],
    );
  }

  Widget _buildRespawnSideSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'リスポーン位置',
          style: TextStyle(color: Colors.teal, fontSize: 10),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String?>(
          value: widget.zone.respawnSide,
          items: const [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('なし（遷移先ゾーン位置）', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            DropdownMenuItem<String?>(
              value: 'left',
              child: Text('左側', style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
            DropdownMenuItem<String?>(
              value: 'right',
              child: Text('右側', style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
          onChanged: (value) {
            widget.zone.applyProperties({'respawnSide': value});
            widget.onChanged();
          },
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(),
          ),
          dropdownColor: Colors.grey[850],
          style: const TextStyle(fontSize: 11),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '他ステージからこのゾーンに飛んできた時のスポーン位置',
            style: TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetZoneSelector() {
    // 現在選択されているtargetZoneIdが一覧に存在するか確認
    final currentTargetZoneId = widget.zone.targetZoneId;
    final hasValidSelection = currentTargetZoneId != null &&
        _targetZones.any((z) => z.id == currentTargetZoneId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '遷移先ゾーンID',
          style: TextStyle(color: Colors.teal, fontSize: 10),
        ),
        const SizedBox(height: 4),
        if (_loadingZones)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                '読み込み中...',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          )
        else if (_targetZones.isEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '遷移先ステージにゾーンがありません',
                    style: TextStyle(color: Colors.orange, fontSize: 10),
                  ),
                ),
                InkWell(
                  onTap: _loadTargetZones,
                  child: const Icon(Icons.refresh, size: 14, color: Colors.orange),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey('targetZone_$_dropdownKey'),
            value: hasValidSelection ? currentTargetZoneId : null,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('未選択', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              ..._targetZones.map((zone) => DropdownMenuItem<String>(
                    value: zone.id,
                    child: Text(
                      '${zone.id} (${zone.x.toStringAsFixed(0)}, ${zone.y.toStringAsFixed(0)})',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: (value) {
              widget.zone.applyProperties({'targetZoneId': value});
              widget.onChanged();
              setState(() {}); // 選択後にUIを更新
            },
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            dropdownColor: Colors.grey[850],
            style: const TextStyle(fontSize: 11),
            isExpanded: true,
          ),
        if (widget.zone.targetZoneId == null && _targetZones.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '遷移先ゾーンが未設定です',
              style: TextStyle(color: Colors.orange, fontSize: 10),
            ),
          ),
      ],
    );
  }
}
