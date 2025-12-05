import 'package:flutter/material.dart';

import '../config/otedama_skin_config.dart';

/// スキン選択モーダル（サムネイル一覧）
class SkinPickerModal extends StatelessWidget {
  final int selectedIndex;
  final void Function(int index, OtedamaSkin skin) onSelect;

  const SkinPickerModal({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  /// モーダルを表示
  static Future<void> show(
    BuildContext context, {
    required int selectedIndex,
    required void Function(int index, OtedamaSkin skin) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SkinPickerModal(
        selectedIndex: selectedIndex,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skins = OtedamaSkinConfig.availableSkins;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // タイトル
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'スキンを選択',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            // スキン一覧
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: skins.length,
                itemBuilder: (context, index) {
                  final skin = skins[index];
                  final isSelected = index == selectedIndex;

                  return _SkinThumbnail(
                    skin: skin,
                    isSelected: isSelected,
                    onTap: () {
                      onSelect(index, skin);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// スキンのサムネイル
class _SkinThumbnail extends StatelessWidget {
  final OtedamaSkin skin;
  final bool isSelected;
  final VoidCallback onTap;

  const _SkinThumbnail({
    required this.skin,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // サムネイル内容
              _buildThumbnailContent(),
              // スキン名
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    skin.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // 選択マーク
              if (isSelected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailContent() {
    switch (skin.type) {
      case OtedamaSkinType.solidColor:
        // 単色スキン：グラデーションで表示
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.4),
              radius: 1.2,
              colors: [
                skin.baseColor!,
                Color.lerp(skin.baseColor!, Colors.black, 0.4)!,
              ],
            ),
          ),
        );
      case OtedamaSkinType.texture:
        // テクスチャスキン：画像で表示
        return Image.asset(
          skin.texturePath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 読み込みエラー時はプレースホルダー
            return Container(
              color: Colors.grey[800],
              child: const Icon(
                Icons.image_not_supported,
                color: Colors.white54,
              ),
            );
          },
        );
    }
  }
}
