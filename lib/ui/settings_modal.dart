import 'package:flutter/material.dart';

import '../config/otedama_skin_config.dart';
import '../services/settings_service.dart';
import 'skin_picker_modal.dart';

/// 設定画面モーダル
class SettingsModal extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const SettingsModal({
    super.key,
    this.onSettingsChanged,
  });

  /// モーダルを表示
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSettingsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SettingsModal(
        onSettingsChanged: onSettingsChanged,
      ),
    );
  }

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  int _selectedSkinIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedSkinIndex = SettingsService.instance.selectedSkinIndex;
  }

  void _openSkinPicker() {
    SkinPickerModal.show(
      context,
      selectedIndex: _selectedSkinIndex,
      onSelect: (index, skin) async {
        setState(() {
          _selectedSkinIndex = index;
        });
        await SettingsService.instance.setSkinIndex(index);
        widget.onSettingsChanged?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSkin = OtedamaSkinConfig.getSkinByIndex(_selectedSkinIndex);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ハンドル
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // タイトル
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    '設定',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // スキンセクション
            _SettingsSection(
              title: 'お手玉のスキン',
              child: GestureDetector(
                onTap: _openSkinPicker,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      // 現在のスキンプレビュー
                      _SkinPreview(skin: currentSkin),
                      const SizedBox(width: 12),
                      // スキン名
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSkin.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentSkin.type == OtedamaSkinType.texture
                                  ? 'テクスチャ'
                                  : '単色',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 矢印
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// 設定セクション
class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// スキンプレビュー（小さいサムネイル）
class _SkinPreview extends StatelessWidget {
  final OtedamaSkin skin;

  const _SkinPreview({required this.skin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (skin.type) {
      case OtedamaSkinType.solidColor:
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
        return Image.asset(
          skin.texturePath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[800],
              child: const Icon(
                Icons.image_not_supported,
                size: 20,
                color: Colors.white54,
              ),
            );
          },
        );
    }
  }
}
