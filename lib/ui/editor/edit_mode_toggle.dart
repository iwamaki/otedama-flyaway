import 'package:flutter/material.dart';

/// 編集モード切り替えボタン
class EditModeToggle extends StatelessWidget {
  final bool isEditMode;
  final VoidCallback onToggle;

  const EditModeToggle({
    super.key,
    required this.isEditMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onToggle,
      backgroundColor: isEditMode ? Colors.orange : Colors.black54,
      child: Icon(
        isEditMode ? Icons.play_arrow : Icons.edit,
        color: Colors.white,
      ),
    );
  }
}
