import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
/// assets/images/backgrounds/ フォルダ内の画像を自動で読み込む
class BackgroundRegistry {
  static List<BackgroundItem>? _cachedBackgrounds;

  /// 背景画像のパスのプレフィックス
  static const String _backgroundsPath = 'assets/images/backgrounds/';

  /// サポートする画像拡張子
  static const List<String> _supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  ];

  /// 背景画像リストを取得（非同期）
  static Future<List<BackgroundItem>> loadBackgrounds() async {
    if (_cachedBackgrounds != null) {
      return _cachedBackgrounds!;
    }

    final backgrounds = <BackgroundItem>[
      // デフォルト背景は常に先頭
      const BackgroundItem(imagePath: null, name: 'デフォルト'),
    ];

    try {
      // AssetManifestからアセット一覧を取得
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = assetManifest.listAssets();

      // backgrounds フォルダ内の画像をフィルタリング
      final backgroundAssets = allAssets.where((path) {
        if (!path.startsWith(_backgroundsPath)) return false;
        final lowerPath = path.toLowerCase();
        return _supportedExtensions.any((ext) => lowerPath.endsWith(ext));
      }).toList();

      // ソート（ファイル名順）
      backgroundAssets.sort();

      // BackgroundItemに変換
      for (final assetPath in backgroundAssets) {
        final fileName = assetPath.split('/').last;
        final name = _generateDisplayName(fileName);
        // imagePath は backgrounds/ 以下の相対パス
        final relativePath = 'backgrounds/$fileName';
        backgrounds.add(BackgroundItem(imagePath: relativePath, name: name));
      }
    } catch (e) {
      debugPrint('背景画像の読み込みに失敗: $e');
    }

    _cachedBackgrounds = backgrounds;
    return backgrounds;
  }

  /// ファイル名から表示名を生成
  static String _generateDisplayName(String fileName) {
    // 拡張子を除去
    var name = fileName;
    for (final ext in _supportedExtensions) {
      if (name.toLowerCase().endsWith(ext)) {
        name = name.substring(0, name.length - ext.length);
        break;
      }
    }
    // アンダースコアとハイフンをスペースに変換
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    // 先頭を大文字に
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }

  /// キャッシュをクリア（開発時に使用）
  static void clearCache() {
    _cachedBackgrounds = null;
  }
}

/// 背景選択ピッカー（ボトムシート用）
class BackgroundPicker extends StatefulWidget {
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
  State<BackgroundPicker> createState() => _BackgroundPickerState();
}

class _BackgroundPickerState extends State<BackgroundPicker> {
  late Future<List<BackgroundItem>> _backgroundsFuture;

  @override
  void initState() {
    super.initState();
    _backgroundsFuture = BackgroundRegistry.loadBackgrounds();
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
            child: FutureBuilder<List<BackgroundItem>>(
              future: _backgroundsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Colors.cyan),
                    ),
                  );
                }

                final backgrounds = snapshot.data ?? [];
                if (backgrounds.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '背景画像が見つかりません',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: backgrounds.map((bg) {
                      final isSelected = bg.imagePath == widget.currentBackground;
                      return _BackgroundTile(
                        background: bg,
                        isSelected: isSelected,
                        onTap: () => widget.onSelect(bg.imagePath),
                      );
                    }).toList(),
                  ),
                );
              },
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
