import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

/// ソフトボディ（お手玉用）
/// ビーズの重心位置から形状を直接計算
class SoftBody {
  final double baseRadius;
  final int numPoints;

  // ビーズの重心（ローカル座標、正規化）
  Vector2 _beadCenter = Vector2(0, 0.5);
  Vector2 _beadVelocity = Vector2.zero();

  // 外部からの加速度追跡用
  Vector2 _prevVelocity = Vector2.zero();

  // パラメータ（調整しやすいように）
  double beadMass = 2.0;
  double gravity = 25.0; // 重力強め
  double inertiaFactor = 0.15; // 慣性強め
  double damping = 2.5;
  double maxOffset = 0.85; // 最大オフセット大きめ
  double bulgeAmount = 0.7; // 膨らみ強め
  double restoreForce = 0.5; // 復元力弱め

  SoftBody({
    required this.baseRadius,
    this.numPoints = 16,
  });

  /// 物理演算を実行
  void update(double dt, Vector2 currentVelocity) {
    if (dt <= 0 || dt > 0.1) return;

    // 加速度を計算
    final acceleration = (currentVelocity - _prevVelocity) / dt;
    _prevVelocity = currentVelocity.clone();

    // --- ビーズへの力 ---

    // 1. 重力（常に下向き = +Y方向）
    final gravityForce = Vector2(0, gravity);

    // 2. 慣性力（加速の逆方向にビーズが寄る）
    final inertiaForce = -acceleration * inertiaFactor;

    // 合計の力
    final totalForce = gravityForce + inertiaForce;

    // ビーズの加速度
    final beadAccel = totalForce / beadMass;

    // 速度と位置を更新
    _beadVelocity += beadAccel * dt;
    _beadVelocity *= (1.0 - damping * dt);
    _beadCenter += _beadVelocity * dt;

    // 弱い復元力（完全に中心には戻らない）
    _beadCenter *= (1.0 - restoreForce * dt);

    // 最大オフセットでクランプ
    if (_beadCenter.length > maxOffset) {
      _beadCenter = _beadCenter.normalized() * maxOffset;
      _beadVelocity *= 0.3;
    }
  }

  /// 外周の点を取得（描画用）
  /// 重心が(0,0)になるように補正済み
  List<Offset> getOuterPoints() {
    final points = <Offset>[];
    final beadMag = _beadCenter.length;
    final beadAngle = math.atan2(_beadCenter.y, _beadCenter.x);

    // まず変形した形状を計算
    final rawPoints = <Offset>[];
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi - math.pi / 2;

      // ビーズの位置に応じて半径を変化させる
      final angleDiff = angle - beadAngle;
      final influence = math.cos(angleDiff);

      // ビーズがある方向に膨らむ、反対は凹む
      final radiusMultiplier = 1.0 + influence * beadMag * bulgeAmount;

      final r = baseRadius * radiusMultiplier;
      rawPoints.add(Offset(
        math.cos(angle) * r,
        math.sin(angle) * r,
      ));
    }

    // 形状の重心を計算
    double cx = 0, cy = 0;
    for (final p in rawPoints) {
      cx += p.dx;
      cy += p.dy;
    }
    cx /= rawPoints.length;
    cy /= rawPoints.length;

    // 重心が(0,0)になるようにオフセット（当たり判定と合わせる）
    for (final p in rawPoints) {
      points.add(Offset(p.dx - cx, p.dy - cy));
    }

    return points;
  }

  /// 外周のPathを取得（滑らかな曲線）
  Path getOuterPath() {
    final points = getOuterPoints();
    if (points.isEmpty) return Path();

    final path = Path();

    // Catmull-Romスプラインで滑らかに
    for (int i = 0; i < points.length; i++) {
      final p0 = points[(i - 1 + points.length) % points.length];
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final p3 = points[(i + 2) % points.length];

      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      }

      // Catmull-Rom to Bezier
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  /// リセット
  void reset() {
    _beadCenter = Vector2(0, 0.5);
    _beadVelocity = Vector2.zero();
    _prevVelocity = Vector2.zero();
  }
}
