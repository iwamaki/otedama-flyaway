import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../config/physics_config.dart';
import 'particle_physics_solver.dart';
import 'particle_renderer.dart';

/// 粒子ベースのお手玉
/// 外殻（8点）+ 内部ビーズ（15個）で構成
class ParticleOtedama extends BodyComponent {
  final Vector2 initialPosition;
  final Color color;

  // 外殻のボディ（袋を形成）
  final List<Body> shellBodies = [];
  // 内部ビーズのボディ
  final List<Body> beadBodies = [];
  // ジョイント（外殻を繋ぐ）
  final List<Joint> shellJoints = [];

  // ダミーボディ（BodyComponentの要件を満たすため）
  Body? _dummyBody;

  // 描画ヘルパー
  late ParticleRenderer _renderer;

  // 物理ソルバー
  late ParticlePhysicsSolver _physicsSolver;

  // 設定可能なパラメータ（調整済みデフォルト値）
  static int shellCount = 13;
  static int beadCount = 20;
  static double shellRadius = 0.28;
  static double beadRadius = 0.3;
  static double overallRadius = 2.50;
  static double shellDensity = 5.0;
  static double beadDensity = 5.0;
  static double shellFriction = 0.51;
  static double beadFriction = 1.0;
  static double shellRestitution = 0.0;
  static double beadRestitution = 0.0;
  static double jointFrequency = 0.0; // 0=硬い接続（伸びない）、>0=バネ
  static double jointDamping = 0.0;
  static double shellRelativeDamping = 0.0; // 節同士の相対運動の減衰（重力に影響しない）
  static double gravityScale = 2.0; // 重力スケール（1.0 = 通常）

  // 距離制約の補正（PBDアプローチ）
  static int distanceConstraintIterations = 10; // 補正の反復回数
  static double distanceConstraintStiffness = 1.0; // 補正の強さ（0.0-1.0）

  // ビーズ封じ込め制約
  static bool beadContainmentEnabled = true; // 封じ込め有効
  static double beadContainmentMargin = 0.25; // 外殻境界からのマージン

  // 初期ジョイント長を記録
  final List<double> _initialJointLengths = [];

  // 発射制限用
  int _launchCount = 0; // 発射回数（0: 未発射, 1: 初回発射済み, 2: 空中発射済み）
  bool _isGrounded = false; // 接地中フラグ
  static const double _groundedVelocityThreshold = 1.5; // 接地判定の速度閾値

  /// 空中発射の力の倍率（初回の何倍か）
  static double airLaunchMultiplier = 0.5;

  /// 発射可能かどうか
  bool get canLaunch => _launchCount < 2;

  /// 空中発射かどうか（UI表示用）
  bool get isAirLaunch => _launchCount == 1 && !_isGrounded;

  ParticleOtedama({
    required Vector2 position,
    this.color = const Color(0xFFCC3333),
  }) : initialPosition = position;

  @override
  void update(double dt) {
    super.update(dt);

    // 節同士の相対運動に減衰を適用（重力には影響しない）
    _physicsSolver.applyRelativeDamping(shellBodies, dt, shellRelativeDamping);

    // 距離制約を強制（PBD：位置ベースで補正）
    _physicsSolver.enforceDistanceConstraints(shellBodies, _initialJointLengths);

    // ビーズ封じ込め制約（外殻の内側に留める）
    _physicsSolver.enforceBeadContainment(shellBodies, beadBodies);

    // ダミーボディを粒子の重心に追従させる
    if (shellBodies.isNotEmpty || beadBodies.isNotEmpty) {
      body.setTransform(centerPosition, 0);
    }

    // 接地判定（速度ベース）と発射カウントリセット
    _updateGroundedState();
  }

  /// 接地状態の更新と発射カウントのリセット
  void _updateGroundedState() {
    // 平均速度を計算
    final avgVelocity = _getAverageVelocity();

    // 速度が閾値以下なら接地とみなす
    final wasGrounded = _isGrounded;
    _isGrounded = avgVelocity < _groundedVelocityThreshold;

    // 接地した瞬間に発射カウントをリセット
    if (_isGrounded && !wasGrounded && _launchCount > 0) {
      _launchCount = 0;
    }
  }

  /// 外殻粒子の平均速度を取得
  double _getAverageVelocity() {
    if (shellBodies.isEmpty) return 0;

    double totalSpeed = 0;
    for (final body in shellBodies) {
      totalSpeed += body.linearVelocity.length;
    }
    return totalSpeed / shellBodies.length;
  }

  @override
  Body createBody() {
    // ダミーボディ（センサー、衝突しない）
    final shape = CircleShape()..radius = 0.01;
    final fixtureDef = FixtureDef(shape)
      ..isSensor = true
      ..density = 0;
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = initialPosition;
    _dummyBody = world.createBody(bodyDef)..createFixture(fixtureDef);
    return _dummyBody!;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _renderer = ParticleRenderer(
      color: color,
      shellRadius: shellRadius,
      beadRadius: beadRadius,
    );
    _physicsSolver = ParticlePhysicsSolver(
      constraintIterations: distanceConstraintIterations,
      constraintStiffness: distanceConstraintStiffness,
      beadContainmentEnabled: beadContainmentEnabled,
      beadContainmentMargin: beadContainmentMargin,
      beadRadius: beadRadius,
    );
    _createParticleBodies();
  }

  void _createParticleBodies() {
    // 外殻を作成（円形に配置）
    for (int i = 0; i < shellCount; i++) {
      final angle = (i / shellCount) * 2 * math.pi;
      final x = initialPosition.x + math.cos(angle) * overallRadius * 0.7;
      final y = initialPosition.y + math.sin(angle) * overallRadius * 0.7;

      final body = _createCircleBody(
        Vector2(x, y),
        shellRadius,
        shellDensity,
        shellFriction,
        shellRestitution,
      );
      shellBodies.add(body);
    }

    // 外殻同士をDistance Jointで接続（隣接のみ、対角線なし）
    _initialJointLengths.clear();
    for (int i = 0; i < shellCount; i++) {
      final bodyA = shellBodies[i];
      final bodyB = shellBodies[(i + 1) % shellCount];

      // 初期長を記録（PBD補正用）
      final initialLength = (bodyA.position - bodyB.position).length;
      _initialJointLengths.add(initialLength);

      final jointDef = DistanceJointDef()
        ..initialize(bodyA, bodyB, bodyA.position, bodyB.position)
        ..frequencyHz = jointFrequency
        ..dampingRatio = jointDamping;

      final joint = DistanceJoint(jointDef);
      world.createJoint(joint);
      shellJoints.add(joint);
    }

    // 内部ビーズを作成（ランダムに配置）
    final random = math.Random();
    for (int i = 0; i < beadCount; i++) {
      // 中心付近にランダム配置
      final r = random.nextDouble() * overallRadius * 0.4;
      final angle = random.nextDouble() * 2 * math.pi;
      final x = initialPosition.x + math.cos(angle) * r;
      final y = initialPosition.y + math.sin(angle) * r;

      final body = _createCircleBody(
        Vector2(x, y),
        beadRadius,
        beadDensity,
        beadFriction,
        beadRestitution,
      );
      beadBodies.add(body);
    }
  }

  Body _createCircleBody(
    Vector2 position,
    double radius,
    double density,
    double friction,
    double restitution,
  ) {
    final shape = CircleShape()..radius = radius;

    final fixtureDef = FixtureDef(shape)
      ..density = density
      ..friction = friction
      ..restitution = restitution;

    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = position
      ..angularDamping = 1.0
      ..linearDamping = 0.1; // 最小限の減衰

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    if (shellBodies.isEmpty) return;

    final bodyPos = body.position;
    _renderer.render(
      canvas,
      bodyPos: Offset(bodyPos.x, bodyPos.y),
      shellPositions: shellBodies.map((b) => Offset(b.position.x, b.position.y)).toList(),
      beadPositions: beadBodies.map((b) => Offset(b.position.x, b.position.y)).toList(),
    );
  }

  /// 重心位置を取得
  Vector2 get centerPosition {
    if (shellBodies.isEmpty && beadBodies.isEmpty) return initialPosition;

    var sum = Vector2.zero();
    var count = 0;

    for (final body in shellBodies) {
      sum += body.position;
      count++;
    }
    for (final body in beadBodies) {
      sum += body.position;
      count++;
    }

    return count > 0 ? sum / count.toDouble() : initialPosition;
  }

  /// タップ位置に力を加える際の効果範囲（半径の倍率）
  /// 小さいほどタップ位置に集中、大きいほど全体に分散
  static double touchEffectRadius = 1.0;

  /// 発射（タップ位置に近い外殻粒子に強い力を加える）
  /// touchPointを指定すると、その位置に近い外殻粒子に強いインパルスが加わり
  /// 回転（トルク）が発生する
  /// ※内部ビーズには力を加えない
  ///
  /// 発射制限:
  /// - 初回発射: フルパワー
  /// - 空中発射: 1回だけ、半分のパワー（airLaunchMultiplier）
  /// - それ以降: 発射不可
  void launch(Vector2 impulse, {Vector2? touchPoint}) {
    // 発射可能かチェック
    if (!canLaunch) {
      return; // 発射回数制限に達している
    }

    // 空中発射かどうかで力を調整
    final powerMultiplier = (_launchCount >= 1) ? airLaunchMultiplier : 1.0;
    final scaledImpulse = impulse * PhysicsConfig.launchMultiplier * powerMultiplier;

    if (touchPoint == null || shellBodies.isEmpty) {
      // タップ位置がない場合は従来通り全体に均一に力を加える
      for (final body in shellBodies) {
        body.applyLinearImpulse(scaledImpulse * body.mass);
      }
    } else {
      // タップ位置に近い外殻粒子に強いインパルスを加える（ガウシアン重み付け）
      final sigma = overallRadius * touchEffectRadius;
      final sigma2 = sigma * sigma;

      double totalWeight = 0;
      final weights = <double>[];

      for (final body in shellBodies) {
        final distance = (body.position - touchPoint).length;
        // ガウシアン関数: exp(-d^2 / (2σ^2))
        final weight = math.exp(-(distance * distance) / (2 * sigma2));
        weights.add(weight);
        totalWeight += weight;
      }

      // 重みを正規化して、合計インパルスが一定になるようにする
      final normalizer = shellBodies.length / totalWeight;

      for (int i = 0; i < shellBodies.length; i++) {
        final body = shellBodies[i];
        final normalizedWeight = weights[i] * normalizer;
        body.applyLinearImpulse(scaledImpulse * body.mass * normalizedWeight);
      }
    }
    // beadBodiesには一切インパルスを加えない
    // → 外殻に閉じ込められているので、衝突で自然に動く

    // 発射カウントを増加
    _launchCount++;
  }

  /// リセット
  void reset() {
    _destroyAllBodies();
    _createParticleBodies();
    _launchCount = 0;
    _isGrounded = true;
  }

  /// 指定位置にリセット
  void resetToPosition(Vector2 newPosition) {
    // 現在位置との差分を計算
    final diff = newPosition - centerPosition;

    // 全ボディを移動
    for (final body in shellBodies) {
      body.setTransform(body.position + diff, body.angle);
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
    }
    for (final body in beadBodies) {
      body.setTransform(body.position + diff, body.angle);
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
    }

    // 発射カウントもリセット
    _launchCount = 0;
    _isGrounded = true;
  }

  /// 物理を一時停止（編集モード用）
  void freeze() {
    for (final body in shellBodies) {
      body.setType(BodyType.static);
    }
    for (final body in beadBodies) {
      body.setType(BodyType.static);
    }
  }

  /// 物理を再開（編集モード用）
  void unfreeze() {
    for (final body in shellBodies) {
      body.setType(BodyType.dynamic);
    }
    for (final body in beadBodies) {
      body.setType(BodyType.dynamic);
    }
  }

  /// パラメータ変更後の再構築
  void rebuild() {
    reset();
  }

  void _destroyAllBodies() {
    for (final joint in shellJoints) {
      world.destroyJoint(joint);
    }
    shellJoints.clear();

    for (final body in shellBodies) {
      world.destroyBody(body);
    }
    shellBodies.clear();

    for (final body in beadBodies) {
      world.destroyBody(body);
    }
    beadBodies.clear();
  }

  @override
  void onRemove() {
    _destroyAllBodies();
    super.onRemove();
  }
}
