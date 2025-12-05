import 'package:flutter/material.dart';

import '../models/stage_data.dart';

/// ステージ選択の結果
class StagePickerResult {
  /// 選択されたステージ（新規作成の場合はnull）
  final StageEntry? selectedEntry;

  /// 新規作成が選択されたか
  final bool isNewStage;

  const StagePickerResult({
    this.selectedEntry,
    this.isNewStage = false,
  });

  /// 新規作成
  static const StagePickerResult newStage = StagePickerResult(isNewStage: true);
}

/// ステージ選択ピッカー（ボトムシート）
class StagePicker extends StatelessWidget {
  final void Function(StagePickerResult result) onSelect;

  const StagePicker({
    super.key,
    required this.onSelect,
  });

  /// ボトムシートとして表示
  static Future<StagePickerResult?> show(BuildContext context) {
    return showModalBottomSheet<StagePickerResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StagePicker(
        onSelect: (result) => Navigator.of(ctx).pop(result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = StageRegistry.sortedEntries;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // タイトル
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ステージ管理',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.grey, height: 1),
          // コンテンツ
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 新規作成タイル
                  _buildNewStageTile(),
                  const SizedBox(height: 16),
                  // セクションヘッダー
                  if (entries.isNotEmpty) ...[
                    const Text(
                      '登録済みステージ',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ステージ一覧
                    ...entries.map((entry) => _buildStageTile(entry)),
                  ] else
                    const Center(
                      child: Text(
                        'ステージがありません',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewStageTile() {
    return InkWell(
      onTap: () => onSelect(StagePickerResult.newStage),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text(
              '新規ステージを作成',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageTile(StageEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSelect(StagePickerResult(selectedEntry: entry)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: Row(
            children: [
              // レベル番号
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${entry.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ステージ名
              Expanded(
                child: Text(
                  entry.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              // 矢印
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
