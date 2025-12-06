import 'package:flutter/material.dart';

import '../components/particle_otedama.dart';

/// 物理パラメータ調整UI
class PhysicsTuner extends StatefulWidget {
  final VoidCallback onRebuild;
  final VoidCallback onReset;

  const PhysicsTuner({
    super.key,
    required this.onRebuild,
    required this.onReset,
  });

  @override
  State<PhysicsTuner> createState() => _PhysicsTunerState();
}

class _PhysicsTunerState extends State<PhysicsTuner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      right: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // トグルボタン
          FloatingActionButton.small(
            onPressed: () => setState(() => _expanded = !_expanded),
            backgroundColor: Colors.black54,
            child: Icon(
              _expanded ? Icons.close : Icons.tune,
              color: Colors.white,
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            _buildPanel(),
          ],
        ],
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      width: 280,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - 120,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text(
            'Physics Parameters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white24),

          // 外殻パラメータ
          _buildSectionHeader('Shell (外殻)'),
          _buildSlider(
            'Count',
            ParticleOtedama.shellCount.toDouble(),
            8,
            24,
            (v) {
              ParticleOtedama.shellCount = v.round();
              _rebuild();
            },
            isInt: true,
          ),
          _buildSlider(
            'Radius',
            ParticleOtedama.shellRadius,
            0.2,
            0.6,
            (v) {
              ParticleOtedama.shellRadius = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Density',
            ParticleOtedama.shellDensity,
            0.1,
            5.0,
            (v) {
              ParticleOtedama.shellDensity = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Friction',
            ParticleOtedama.shellFriction,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.shellFriction = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Restitution',
            ParticleOtedama.shellRestitution,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.shellRestitution = v;
              _rebuild();
            },
          ),

          const Divider(color: Colors.white24),

          // ビーズパラメータ
          _buildSectionHeader('Beads (ビーズ)'),
          _buildSlider(
            'Count',
            ParticleOtedama.beadCount.toDouble(),
            5,
            40,
            (v) {
              ParticleOtedama.beadCount = v.round();
              _rebuild();
            },
            isInt: true,
          ),
          _buildSlider(
            'Radius',
            ParticleOtedama.beadRadius,
            0.1,
            0.4,
            (v) {
              ParticleOtedama.beadRadius = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'SizeVar',
            ParticleOtedama.beadSizeVariation,
            0.0,
            0.8,
            (v) {
              ParticleOtedama.beadSizeVariation = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Density',
            ParticleOtedama.beadDensity,
            0.1,
            5.0,
            (v) {
              ParticleOtedama.beadDensity = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Friction',
            ParticleOtedama.beadFriction,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.beadFriction = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Restitution',
            ParticleOtedama.beadRestitution,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.beadRestitution = v;
              _rebuild();
            },
          ),

          const Divider(color: Colors.white24),

          // ジョイントパラメータ
          _buildSectionHeader('Joints (バネ)'),
          _buildSlider(
            'Frequency',
            ParticleOtedama.jointFrequency,
            0.0,
            20.0,
            (v) {
              ParticleOtedama.jointFrequency = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Damping',
            ParticleOtedama.jointDamping,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.jointDamping = v;
              _rebuild();
            },
          ),

          const Divider(color: Colors.white24),

          // 距離制約パラメータ
          _buildSectionHeader('Constraint (制約)'),
          _buildSlider(
            'Iterations',
            ParticleOtedama.distanceConstraintIterations.toDouble(),
            0,
            10,
            (v) {
              ParticleOtedama.distanceConstraintIterations = v.round();
              setState(() {});
            },
            isInt: true,
          ),
          _buildSlider(
            'Stiffness',
            ParticleOtedama.distanceConstraintStiffness,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.distanceConstraintStiffness = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'RelDamp',
            ParticleOtedama.shellRelativeDamping,
            0.0,
            50.0,
            (v) {
              ParticleOtedama.shellRelativeDamping = v;
              setState(() {});
            },
          ),

          const Divider(color: Colors.white24),

          // ビーズ封じ込めパラメータ
          _buildSectionHeader('Containment (封じ込め)'),
          _buildToggle(
            'Enabled',
            ParticleOtedama.beadContainmentEnabled,
            (v) {
              ParticleOtedama.beadContainmentEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'Margin',
            ParticleOtedama.beadContainmentMargin,
            0.0,
            0.5,
            (v) {
              ParticleOtedama.beadContainmentMargin = v;
              setState(() {});
            },
          ),

          const Divider(color: Colors.white24),

          // 全体パラメータ
          _buildSectionHeader('Overall (全体)'),
          _buildSlider(
            'Size',
            ParticleOtedama.overallRadius,
            0.8,
            3.0,
            (v) {
              ParticleOtedama.overallRadius = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Gravity',
            ParticleOtedama.gravityScale,
            0.1,
            3.0,
            (v) {
              ParticleOtedama.gravityScale = v;
              setState(() {});
            },
          ),

          const SizedBox(height: 12),

          // リセットボタン
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Reset Position'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetToDefaults,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Default'),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildToggle(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Colors.amber,
          thumbColor: WidgetStateProperty.all(Colors.white),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    bool isInt = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.amber,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.amber,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            isInt ? value.round().toString() : value.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }

  void _rebuild() {
    setState(() {});
    widget.onRebuild();
  }

  void _resetToDefaults() {
    setState(() {
      ParticleOtedama.shellCount = 13;
      ParticleOtedama.beadCount = 20;
      ParticleOtedama.shellRadius = 0.28;
      ParticleOtedama.beadRadius = 0.3;
      ParticleOtedama.beadSizeVariation = 0.5;
      ParticleOtedama.overallRadius = 2.50;
      ParticleOtedama.shellDensity = 5.0;
      ParticleOtedama.beadDensity = 5.0;
      ParticleOtedama.shellFriction = 0.51;
      ParticleOtedama.beadFriction = 1.0;
      ParticleOtedama.shellRestitution = 0.0;
      ParticleOtedama.beadRestitution = 0.0;
      ParticleOtedama.jointFrequency = 0.0;
      ParticleOtedama.jointDamping = 0.0;
      ParticleOtedama.distanceConstraintIterations = 10;
      ParticleOtedama.distanceConstraintStiffness = 1.0;
      ParticleOtedama.shellRelativeDamping = 0.0;
      ParticleOtedama.gravityScale = 2.0;
      ParticleOtedama.beadContainmentEnabled = true;
      ParticleOtedama.beadContainmentMargin = 0.25;
    });
    widget.onRebuild();
  }
}
