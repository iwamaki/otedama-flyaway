import 'package:flutter/material.dart';

/// クリア画面（ゲームクリア時に表示）
class ClearScreen extends StatelessWidget {
  /// クリアタイム（秒）
  final double clearTime;

  /// リトライコールバック
  final VoidCallback onRetry;

  /// スタート画面に戻るコールバック
  final VoidCallback onBackToStart;

  const ClearScreen({
    super.key,
    required this.clearTime,
    required this.onRetry,
    required this.onBackToStart,
  });

  /// クリアタイムをフォーマット（mm:ss.xx）
  String _formatTime(double seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).floor().toString().padLeft(2, '0');
    final ms = ((seconds % 1) * 100).floor().toString().padLeft(2, '0');
    return '$minutes:$secs.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // クリアタイトル
              const Text(
                'CLEAR!',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 24),

              // クリアタイム
              const Text(
                'TIME',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(clearTime),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 40),

              // ボタン
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // リトライボタン
                  _ClearButton(
                    icon: Icons.refresh_rounded,
                    label: 'Retry',
                    onTap: onRetry,
                    isPrimary: true,
                  ),
                  const SizedBox(width: 16),
                  // 戻るボタン
                  _ClearButton(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: onBackToStart,
                    isPrimary: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// クリア画面のボタン
class _ClearButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ClearButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.orange : Colors.grey[700],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
