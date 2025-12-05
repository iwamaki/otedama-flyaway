import 'package:flutter/material.dart';

/// 利用可能な背景画像の定義
class BackgroundItem {
  final String? imagePath; // nullならデフォルト背景
  final String name;

  const BackgroundItem({
    this.imagePath,
    required this.name,
  });
}

/// 背景画像のレジストリ
/// 新しい背景画像を追加する場合はここに追加
class BackgroundRegistry {
  static const List<BackgroundItem> backgrounds = [
    BackgroundItem(
      imagePath: null,
      name: 'デフォルト',
    ),
    BackgroundItem(
      imagePath: 'tatami.jpg',
      name: '畳',
    ),
    // 新しい背景を追加する場合:
    // BackgroundItem(
    //   imagePath: 'sky.jpg',
    //   name: '空',
    // ),
  ];
}

/// 背景選択ピッカー（ボトムシート用）
class BackgroundPicker extends StatelessWidget {
  final String? currentBackground;
  final void Function(String? background) onSelect;

  const BackgroundPicker({
    super.key,
    this.currentBackground,
    required this.onSelect,
  });

  /// ボトムシートとして表示
  static Future<String?> show(BuildContext context, {String? currentBackground}) {
    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackgroundPicker(
        currentBackground: currentBackground,
        onSelect: (bg) => Navigator.of(ctx).pop(bg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
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
              '背景を選択',
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
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: BackgroundRegistry.backgrounds.map((bg) {
                  final isSelected = bg.imagePath == currentBackground;
                  return _BackgroundTile(
                    background: bg,
                    isSelected: isSelected,
                    onTap: () => onSelect(bg.imagePath),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 個別背景のタイル
class _BackgroundTile extends StatelessWidget {
  final BackgroundItem background;
  final bool isSelected;
  final VoidCallback onTap;

  const _BackgroundTile({
    required this.background,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyan : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // サムネイル
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _buildThumbnail(),
              ),
            ),
            // 名前
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                background.name,
                style: TextStyle(
                  color: isSelected ? Colors.cyan : Colors.white,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (background.imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/${background.imagePath}',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        ),
      );
    } else {
      return _buildDefaultBackground();
    }
  }

  Widget _buildDefaultBackground() {
    // デフォルト背景のプレビュー（畳風グリッド）
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8DCC8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        painter: _TatamiPatternPainter(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.broken_image,
        color: Colors.white70,
        size: 32,
      ),
    );
  }
}

/// 畳風パターンを描画するペインター
class _TatamiPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4C4A8)
      ..strokeWidth = 0.5;

    const spacing = 10.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
