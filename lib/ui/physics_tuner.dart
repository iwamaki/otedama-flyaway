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
            50,
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
          _buildToggle(
            'Spike',
            ParticleOtedama.shellSpikeEnabled,
            (v) {
              ParticleOtedama.shellSpikeEnabled = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'SpikeLen',
            ParticleOtedama.shellSpikeLength,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.shellSpikeLength = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'SpikeRad',
            ParticleOtedama.shellSpikeRadius,
            0.05,
            0.3,
            (v) {
              ParticleOtedama.shellSpikeRadius = v;
              _rebuild();
            },
          ),
          _buildToggle(
            'Bridge',
            ParticleOtedama.shellBridgeEnabled,
            (v) {
              ParticleOtedama.shellBridgeEnabled = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'BridgeW',
            ParticleOtedama.shellBridgeWidth,
            0.05,
            0.5,
            (v) {
              ParticleOtedama.shellBridgeWidth = v;
              _rebuild();
            },
          ),

          const Divider(color: Colors.white24),

          // スキップ制約パラメータ
          _buildSectionHeader('Skip (折れ曲がり防止)'),
          _buildToggle(
            'Enabled',
            ParticleOtedama.skipConstraintEnabled,
            (v) {
              ParticleOtedama.skipConstraintEnabled = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Step',
            ParticleOtedama.skipConstraintStep.toDouble(),
            1,
            5,
            (v) {
              ParticleOtedama.skipConstraintStep = v.round();
              _rebuild();
            },
            isInt: true,
          ),
          _buildSlider(
            'MinRatio',
            ParticleOtedama.skipConstraintRatio,
            0.5,
            1.0,
            (v) {
              ParticleOtedama.skipConstraintRatio = v;
              setState(() {});
            },
          ),

          const Divider(color: Colors.white24),

          // 速度制限パラメータ（鞭効果・反転防止）
          _buildSectionHeader('Velocity Limit (速度制限)'),
          _buildToggle(
            'AbsLimit',
            ParticleOtedama.absoluteVelocityLimitEnabled,
            (v) {
              ParticleOtedama.absoluteVelocityLimitEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'MaxVel',
            ParticleOtedama.maxShellVelocity,
            10.0,
            50.0,
            (v) {
              ParticleOtedama.maxShellVelocity = v;
              setState(() {});
            },
          ),
          _buildToggle(
            'Neighbor',
            ParticleOtedama.neighborVelocityLimitEnabled,
            (v) {
              ParticleOtedama.neighborVelocityLimitEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'MaxDiff',
            ParticleOtedama.maxNeighborVelocityDiff,
            2.0,
            20.0,
            (v) {
              ParticleOtedama.maxNeighborVelocityDiff = v;
              setState(() {});
            },
          ),
          _buildToggle(
            'Deviation',
            ParticleOtedama.impactDampingEnabled,
            (v) {
              ParticleOtedama.impactDampingEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'MaxDev',
            ParticleOtedama.maxSpeedDeviation,
            2.0,
            30.0,
            (v) {
              ParticleOtedama.maxSpeedDeviation = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'DevDamp',
            ParticleOtedama.deviationDampingFactor,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.deviationDampingFactor = v;
              setState(() {});
            },
          ),

          const Divider(color: Colors.white24),

          // 角度順序維持パラメータ
          _buildSectionHeader('AngleOrder (クロス防止)'),
          _buildToggle(
            'Enabled',
            ParticleOtedama.angleOrderEnabled,
            (v) {
              ParticleOtedama.angleOrderEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'Strength',
            ParticleOtedama.angleOrderStrength,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.angleOrderStrength = v;
              setState(() {});
            },
          ),

          const Divider(color: Colors.white24),

          // CCD・サブステップ・衝突半径パラメータ（根本対策）
          _buildSectionHeader('CCD/Substep (すり抜け防止)'),
          _buildToggle(
            'CCD',
            ParticleOtedama.shellCcdEnabled,
            (v) {
              ParticleOtedama.shellCcdEnabled = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'Substeps',
            ParticleOtedama.physicsSubsteps.toDouble(),
            1,
            10,
            (v) {
              ParticleOtedama.physicsSubsteps = v.round();
              setState(() {});
            },
            isInt: true,
          ),
          _buildToggle(
            'CollisionR',
            ParticleOtedama.shellCollisionEnabled,
            (v) {
              ParticleOtedama.shellCollisionEnabled = v;
              _rebuild();
            },
          ),
          _buildSlider(
            'ColMult',
            ParticleOtedama.shellCollisionRadiusMultiplier,
            1.0,
            4.0,
            (v) {
              ParticleOtedama.shellCollisionRadiusMultiplier = v;
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
          _buildSlider(
            'Damping',
            ParticleOtedama.beadLinearDamping,
            0.0,
            3.0,
            (v) {
              ParticleOtedama.beadLinearDamping = v;
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
            50.0,
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
          _buildSectionHeader('Constraint (距離制約)'),
          _buildToggle(
            'Enabled',
            ParticleOtedama.distanceConstraintEnabled,
            (v) {
              ParticleOtedama.distanceConstraintEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'Iterations',
            ParticleOtedama.distanceConstraintIterations.toDouble(),
            0,
            20,
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

          // 曲げ制約パラメータ
          _buildSectionHeader('Bending (曲げ制約)'),
          _buildToggle(
            'Enabled',
            ParticleOtedama.bendingConstraintEnabled,
            (v) {
              ParticleOtedama.bendingConstraintEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'MinAngle',
            ParticleOtedama.minBendingAngleDegrees,
            60.0,
            170.0,
            (v) {
              ParticleOtedama.minBendingAngleDegrees = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'Stiffness',
            ParticleOtedama.bendingStiffness,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.bendingStiffness = v;
              setState(() {});
            },
          ),

          const Divider(color: Colors.white24),

          // 反転防止パラメータ（フォールバック）
          _buildSectionHeader('Inversion (反転補正)'),
          _buildToggle(
            'Enabled',
            ParticleOtedama.inversionPreventionEnabled,
            (v) {
              ParticleOtedama.inversionPreventionEnabled = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'VelThresh',
            ParticleOtedama.inversionCheckVelocityThreshold,
            0.0,
            10.0,
            (v) {
              ParticleOtedama.inversionCheckVelocityThreshold = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'CrossThr',
            ParticleOtedama.inversionCrossThreshold,
            -0.1,
            0.0,
            (v) {
              ParticleOtedama.inversionCrossThreshold = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'PushStart',
            ParticleOtedama.inversionPushStartRatio,
            0.3,
            0.9,
            (v) {
              ParticleOtedama.inversionPushStartRatio = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'PushTarget',
            ParticleOtedama.inversionPushTargetRatio,
            0.5,
            1.0,
            (v) {
              ParticleOtedama.inversionPushTargetRatio = v;
              setState(() {});
            },
          ),

          const Divider(color: Colors.white24),

          // 発射パラメータ
          _buildSectionHeader('Launch (発射)'),
          _buildSlider(
            'Power',
            ParticleOtedama.launchMultiplier,
            1.0,
            15.0,
            (v) {
              ParticleOtedama.launchMultiplier = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'AirPower',
            ParticleOtedama.airLaunchMultiplier,
            0.0,
            1.0,
            (v) {
              ParticleOtedama.airLaunchMultiplier = v;
              setState(() {});
            },
          ),
          _buildSlider(
            'TouchRadius',
            ParticleOtedama.touchEffectRadius,
            0.1,
            3.0,
            (v) {
              ParticleOtedama.touchEffectRadius = v;
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
          const SizedBox(height: 8),
          // パラメータ出力ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _printParameters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
              ),
              icon: const Icon(Icons.terminal, size: 16),
              label: const Text('Print to Console'),
            ),
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
      // Shell
      ParticleOtedama.shellCount = 25;
      ParticleOtedama.shellRadius = 0.30;
      ParticleOtedama.shellDensity = 5.0;
      ParticleOtedama.shellFriction = 0.25;
      ParticleOtedama.shellRestitution = 0.05;
      ParticleOtedama.shellSpikeEnabled = true;
      ParticleOtedama.shellSpikeLength = 0.38;
      ParticleOtedama.shellSpikeRadius = 0.09;
      ParticleOtedama.shellBridgeEnabled = false;
      ParticleOtedama.shellBridgeWidth = 0.15;

      // Skip
      ParticleOtedama.skipConstraintEnabled = true;
      ParticleOtedama.skipConstraintStep = 2;
      ParticleOtedama.skipConstraintRatio = 0.9;

      // Velocity Limit
      ParticleOtedama.absoluteVelocityLimitEnabled = true;
      ParticleOtedama.maxShellVelocity = 25.0;
      ParticleOtedama.neighborVelocityLimitEnabled = true;
      ParticleOtedama.maxNeighborVelocityDiff = 8.0;
      ParticleOtedama.impactDampingEnabled = true;
      ParticleOtedama.maxSpeedDeviation = 10.0;
      ParticleOtedama.deviationDampingFactor = 0.5;

      // AngleOrder
      ParticleOtedama.angleOrderEnabled = true;
      ParticleOtedama.angleOrderStrength = 0.8;

      // CCD/Substep
      ParticleOtedama.shellCcdEnabled = true;
      ParticleOtedama.physicsSubsteps = 3;
      ParticleOtedama.shellCollisionEnabled = false;
      ParticleOtedama.shellCollisionRadiusMultiplier = 2.0;

      // Beads
      ParticleOtedama.beadCount = 0;
      ParticleOtedama.beadRadius = 0.40;
      ParticleOtedama.beadSizeVariation = 0.62;
      ParticleOtedama.beadDensity = 2.99;
      ParticleOtedama.beadFriction = 1.0;
      ParticleOtedama.beadRestitution = 0.0;
      ParticleOtedama.beadLinearDamping = 0.8;

      // Joints
      ParticleOtedama.jointFrequency = 23.65;
      ParticleOtedama.jointDamping = 0.0;

      // Constraint
      ParticleOtedama.distanceConstraintEnabled = true;
      ParticleOtedama.distanceConstraintIterations = 6;
      ParticleOtedama.distanceConstraintStiffness = 1.0;
      ParticleOtedama.shellRelativeDamping = 0.0;

      // Containment
      ParticleOtedama.beadContainmentEnabled = true;
      ParticleOtedama.beadContainmentMargin = 0.0;

      // Bending
      ParticleOtedama.bendingConstraintEnabled = false;
      ParticleOtedama.minBendingAngleDegrees = 60.0;
      ParticleOtedama.bendingStiffness = 0.5;

      // Inversion
      ParticleOtedama.inversionPreventionEnabled = true;
      ParticleOtedama.inversionCheckVelocityThreshold = 5.0;
      ParticleOtedama.inversionCrossThreshold = -0.01;
      ParticleOtedama.inversionPushStartRatio = 0.7;
      ParticleOtedama.inversionPushTargetRatio = 0.9;

      // Launch
      ParticleOtedama.launchMultiplier = 2.25;
      ParticleOtedama.airLaunchMultiplier = 0.5;
      ParticleOtedama.touchEffectRadius = 1.0;

      // Overall
      ParticleOtedama.overallRadius = 1.70;
      ParticleOtedama.gravityScale = 3.0;
    });
    widget.onRebuild();
  }

  void _printParameters() {
    debugPrint('''
=== Otedama Parameters ===
// Shell
shellCount: ${ParticleOtedama.shellCount}
shellRadius: ${ParticleOtedama.shellRadius}
shellDensity: ${ParticleOtedama.shellDensity}
shellFriction: ${ParticleOtedama.shellFriction}
shellRestitution: ${ParticleOtedama.shellRestitution}
shellSpikeEnabled: ${ParticleOtedama.shellSpikeEnabled}
shellSpikeLength: ${ParticleOtedama.shellSpikeLength}
shellSpikeRadius: ${ParticleOtedama.shellSpikeRadius}
shellBridgeEnabled: ${ParticleOtedama.shellBridgeEnabled}
shellBridgeWidth: ${ParticleOtedama.shellBridgeWidth}

// Skip
skipConstraintEnabled: ${ParticleOtedama.skipConstraintEnabled}
skipConstraintStep: ${ParticleOtedama.skipConstraintStep}
skipConstraintRatio: ${ParticleOtedama.skipConstraintRatio}

// Velocity Limit
absoluteVelocityLimitEnabled: ${ParticleOtedama.absoluteVelocityLimitEnabled}
maxShellVelocity: ${ParticleOtedama.maxShellVelocity}
neighborVelocityLimitEnabled: ${ParticleOtedama.neighborVelocityLimitEnabled}
maxNeighborVelocityDiff: ${ParticleOtedama.maxNeighborVelocityDiff}
impactDampingEnabled: ${ParticleOtedama.impactDampingEnabled}
maxSpeedDeviation: ${ParticleOtedama.maxSpeedDeviation}
deviationDampingFactor: ${ParticleOtedama.deviationDampingFactor}

// AngleOrder
angleOrderEnabled: ${ParticleOtedama.angleOrderEnabled}
angleOrderStrength: ${ParticleOtedama.angleOrderStrength}

// CCD/Substep
shellCcdEnabled: ${ParticleOtedama.shellCcdEnabled}
physicsSubsteps: ${ParticleOtedama.physicsSubsteps}
shellCollisionEnabled: ${ParticleOtedama.shellCollisionEnabled}
shellCollisionRadiusMultiplier: ${ParticleOtedama.shellCollisionRadiusMultiplier}

// Beads
beadCount: ${ParticleOtedama.beadCount}
beadRadius: ${ParticleOtedama.beadRadius}
beadSizeVariation: ${ParticleOtedama.beadSizeVariation}
beadDensity: ${ParticleOtedama.beadDensity}
beadFriction: ${ParticleOtedama.beadFriction}
beadRestitution: ${ParticleOtedama.beadRestitution}
beadLinearDamping: ${ParticleOtedama.beadLinearDamping}

// Joints
jointFrequency: ${ParticleOtedama.jointFrequency}
jointDamping: ${ParticleOtedama.jointDamping}

// Constraint
distanceConstraintEnabled: ${ParticleOtedama.distanceConstraintEnabled}
distanceConstraintIterations: ${ParticleOtedama.distanceConstraintIterations}
distanceConstraintStiffness: ${ParticleOtedama.distanceConstraintStiffness}
shellRelativeDamping: ${ParticleOtedama.shellRelativeDamping}

// Containment
beadContainmentEnabled: ${ParticleOtedama.beadContainmentEnabled}
beadContainmentMargin: ${ParticleOtedama.beadContainmentMargin}

// Bending
bendingConstraintEnabled: ${ParticleOtedama.bendingConstraintEnabled}
minBendingAngleDegrees: ${ParticleOtedama.minBendingAngleDegrees}
bendingStiffness: ${ParticleOtedama.bendingStiffness}

// Inversion
inversionPreventionEnabled: ${ParticleOtedama.inversionPreventionEnabled}
inversionCheckVelocityThreshold: ${ParticleOtedama.inversionCheckVelocityThreshold}
inversionCrossThreshold: ${ParticleOtedama.inversionCrossThreshold}
inversionPushStartRatio: ${ParticleOtedama.inversionPushStartRatio}
inversionPushTargetRatio: ${ParticleOtedama.inversionPushTargetRatio}

// Launch
launchMultiplier: ${ParticleOtedama.launchMultiplier}
airLaunchMultiplier: ${ParticleOtedama.airLaunchMultiplier}
touchEffectRadius: ${ParticleOtedama.touchEffectRadius}

// Overall
overallRadius: ${ParticleOtedama.overallRadius}
gravityScale: ${ParticleOtedama.gravityScale}
==========================
''');
  }
}
