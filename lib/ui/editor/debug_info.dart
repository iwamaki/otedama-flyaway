import 'package:flutter/material.dart';

import '../../game/otedama_game.dart';

/// お手玉デバッグ情報表示
class OtedamaDebugInfo extends StatelessWidget {
  final OtedamaGame game;

  const OtedamaDebugInfo({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final otedama = game.otedama;
    if (otedama == null) return const SizedBox.shrink();

    final pos = otedama.centerPosition;
    final vel = otedama.getVelocity();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'お手玉',
            style: TextStyle(
              color: Colors.amber.shade300,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '座標: (${pos.x.toStringAsFixed(1)}, ${pos.y.toStringAsFixed(1)})',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            '速度: (${vel.x.toStringAsFixed(1)}, ${vel.y.toStringAsFixed(1)})',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            'Spawn: (${game.spawnX.toStringAsFixed(1)}, ${game.spawnY.toStringAsFixed(1)})',
            style: TextStyle(color: Colors.teal.shade300, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
