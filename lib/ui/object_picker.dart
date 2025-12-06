import 'package:flutter/material.dart';

/// 挿入可能なオブジェクトの種類
enum ObjectType {
  /// 基本オブジェクト（足場など）
  primitive,

  /// 画像オブジェクト
  image,
}

/// 挿入可能なオブジェクトの定義
class InsertableObject {
  final String id;
  final String name;
  final ObjectType type;

  /// 画像オブジェクトの場合のアセットパス（例: 'branch.png'）
  final String? imagePath;

  /// プリミティブオブジェクトの場合のアイコン
  final IconData? icon;

  const InsertableObject({
    required this.id,
    required this.name,
    required this.type,
    this.imagePath,
    this.icon,
  });
}

/// 挿入可能なオブジェクトのレジストリ
/// 新しい画像を追加する場合はここに追加するだけ
class ObjectRegistry {
  /// 基本オブジェクト
  static const List<InsertableObject> primitives = [
    InsertableObject(
      id: 'platform',
      name: '足場',
      type: ObjectType.primitive,
      icon: Icons.horizontal_rule,
    ),
    InsertableObject(
      id: 'trampoline',
      name: 'トランポリン',
      type: ObjectType.primitive,
      icon: Icons.arrow_upward,
    ),
    InsertableObject(
      id: 'goal',
      name: 'ゴール',
      type: ObjectType.primitive,
      icon: Icons.sports_score,
    ),
  ];

  /// 画像オブジェクト
  /// 新しい画像を追加する場合はここにエントリを追加
  static const List<InsertableObject> images = [
    InsertableObject(
      id: 'branch',
      name: 'branch.png',
      type: ObjectType.image,
      imagePath: 'branch.png',
    ),
    // 新しい画像を追加する場合:
    // InsertableObject(
    //   id: 'rock',
    //   name: 'rock.png',
    //   type: ObjectType.image,
    //   imagePath: 'rock.png',
    // ),
  ];

  /// 全てのオブジェクト
  static List<InsertableObject> get all => [...primitives, ...images];
}

/// オブジェクト選択ピッカー（ボトムシート用）
class ObjectPicker extends StatelessWidget {
  final void Function(InsertableObject object) onSelect;

  const ObjectPicker({
    super.key,
    required this.onSelect,
  });

  /// ボトムシートとして表示
  static Future<InsertableObject?> show(BuildContext context) {
    return showModalBottomSheet<InsertableObject>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ObjectPicker(
        onSelect: (obj) => Navigator.of(ctx).pop(obj),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              'オブジェクトを追加',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 基本オブジェクトセクション
                  if (ObjectRegistry.primitives.isNotEmpty) ...[
                    _buildSectionHeader('基本オブジェクト'),
                    const SizedBox(height: 8),
                    _buildPrimitiveGrid(),
                    const SizedBox(height: 16),
                  ],
                  // 画像オブジェクトセクション
                  if (ObjectRegistry.images.isNotEmpty) ...[
                    _buildSectionHeader('画像オブジェクト'),
                    const SizedBox(height: 8),
                    _buildImageGrid(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPrimitiveGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ObjectRegistry.primitives.map((obj) {
        return _ObjectTile(
          object: obj,
          onTap: () => onSelect(obj),
        );
      }).toList(),
    );
  }

  Widget _buildImageGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ObjectRegistry.images.map((obj) {
        return _ObjectTile(
          object: obj,
          onTap: () => onSelect(obj),
        );
      }).toList(),
    );
  }
}

/// 個別オブジェクトのタイル
class _ObjectTile extends StatelessWidget {
  final InsertableObject object;
  final VoidCallback onTap;

  const _ObjectTile({
    required this.object,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // サムネイル
            SizedBox(
              width: 64,
              height: 64,
              child: _buildThumbnail(),
            ),
            const SizedBox(height: 8),
            // ファイル名
            Text(
              object.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (object.type == ObjectType.image && object.imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/${object.imagePath}',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(Icons.broken_image);
          },
        ),
      );
    } else {
      return _buildPlaceholder(object.icon ?? Icons.category);
    }
  }

  Widget _buildPlaceholder(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        color: Colors.white70,
        size: 32,
      ),
    );
  }
}
