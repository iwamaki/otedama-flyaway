import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

import '../config/otedama_skin_config.dart';
import '../services/audio_service.dart';
import '../services/logger_service.dart';
import '../services/performance_monitor.dart';
import '../services/texture_manager.dart';
import 'particle_physics_solver.dart';
import 'particle_renderer.dart';

/// 粒子ベースのお手玉
/// 外殻（8点）+ 内部ビーズ（15個）で構成
class ParticleOtedama extends BodyComponent {
  final Vector2 initialPosition;
  final Color color;

  /// 現在のスキン設定
  OtedamaSkin _skin;

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
  static int shellCount = 25;
  static int beadCount = 0;
  static double shellRadius = 0.30;
  static double beadRadius = 0.40;
  static double overallRadius = 1.70;
  static double shellDensity = 5.0;
  static double beadDensity = 2.99;
  static double shellFriction = 0.25;
  static double beadFriction = 1.0;
  static double shellRestitution = 0.05;
  static double beadRestitution = 0.0;
  static double jointFrequency = 23.65; // 0=硬い接続（伸びない）、>0=バネ
  static double jointDamping = 0.0;
  static double shellRelativeDamping = 0.0; // 節同士の相対運動の減衰（重力に影響しない）
  static double gravityScale = 3.0; // 重力スケール（1.0 = 通常）

  // 距離制約の補正（PBDアプローチ）
  static int distanceConstraintIterations = 6; // 補正の反復回数
  static double distanceConstraintStiffness = 1.0; // 補正の強さ（0.0-1.0）

  // ビーズ封じ込め制約
  static bool beadContainmentEnabled = true; // 封じ込め有効
  static double beadContainmentMargin = 0.0; // 外殻境界からのマージン

  // 外殻反転防止パラメータ
  static double inversionCheckVelocityThreshold = 5.0; // この速度以下は反転チェックをスキップ
  static double inversionCrossThreshold = -0.01; // 凹み検出の外積閾値（負の値）
  static double inversionPushStartRatio = 0.7; // 押し出し開始の距離比率
  static double inversionPushTargetRatio = 0.9; // 押し出し先の距離比率

  // 曲げ制約パラメータ（反転を根本的に防ぐ）
  static double minBendingAngleDegrees = 60.0; // 最小角度（度）
  static double bendingStiffness = 0.0; // 曲げ剛性（0.0-1.0）

  // ビーズサイズのバリエーション（0.0〜1.0、大きいほどバラつく）
  static double beadSizeVariation = 0.62;

  // 外殻の内側突起（ビーズとの接触を確保）
  static bool shellSpikeEnabled = true; // 突起を有効化
  static double shellSpikeLength = 0.38; // 突起の長さ（内側方向へのオフセット）
  static double shellSpikeRadius = 0.09; // 突起の半径

  // 初期ジョイント長を記録
  final List<double> _initialJointLengths = [];

  // 衝突検出用（速度変化を監視）
  List<Vector2> _previousVelocities = [];
  bool _velocityBufferInitialized = false;
  static const double _impactThreshold = 12.0; // 衝突判定の速度変化閾値
  static const double _maxImpactIntensity = 30.0; // 最大強度（正規化用）

  // 発射制限用
  int _launchCount = 0; // 発射回数（0: 未発射, 1: 初回発射済み, 2: 空中発射済み）
  bool _isGrounded = false; // 接地中フラグ
  static const double _groundedVelocityThreshold = 1.5; // 接地判定の速度閾値

  // 静止判定用（ドリフト防止）
  bool _isAtRest = false; // 静止状態フラグ
  int _restFrameCount = 0; // 連続静止フレーム数
  static const double _restVelocityThreshold = 1.5; // 静止判定の速度閾値
  static const int _restFramesRequired = 10; // 静止確定に必要なフレーム数

  /// 発射力の倍率（スワイプ→力の変換係数）
  static double launchMultiplier = 2.25;

  /// 空中発射の力の倍率（初回の何倍か）
  static double airLaunchMultiplier = 0.5;

  /// 発射可能かどうか
  bool get canLaunch => _launchCount < 2;

  /// 空中発射かどうか（UI表示用）
  bool get isAirLaunch => _launchCount == 1 && !_isGrounded;

  ParticleOtedama({
    required Vector2 position,
    this.color = const Color(0xFFCC3333),
    OtedamaSkin? skin,
  })  : initialPosition = position,
        _skin = skin ?? OtedamaSkinConfig.defaultSkin;

  /// 現在のスキンを取得
  OtedamaSkin get skin => _skin;

  /// スキンを変更
  Future<void> setSkin(OtedamaSkin newSkin) async {
    _skin = newSkin;
    _renderer.setSkin(newSkin);

    // テクスチャスキンの場合は画像を読み込み
    if (newSkin.type == OtedamaSkinType.texture && newSkin.texturePath != null) {
      final image = await TextureManager.instance.loadTexture(newSkin.texturePath!);
      _renderer.setTextureImage(image);
    } else {
      _renderer.setTextureImage(null);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 静止判定を更新
    _updateRestState();

    // 静止状態ならPBD補正をスキップ（ドリフト防止）
    if (_isAtRest) {
      // ダミーボディを粒子の重心に追従させる
      if (shellBodies.isNotEmpty || beadBodies.isNotEmpty) {
        body.setTransform(centerPosition, 0);
      }
      // 接地判定と発射カウントリセット
      _updateGroundedState();
      return;
    }

    // 衝突検出（速度変化を監視）
    _detectImpact();

    // 節同士の相対運動に減衰を適用（重力には影響しない）
    _physicsSolver.applyRelativeDamping(shellBodies, dt, shellRelativeDamping);

    // 距離制約を強制（PBD：位置ベースで補正）
    PerformanceMonitor.instance.startSection('pbd');
    _physicsSolver.enforceDistanceConstraints(shellBodies, _initialJointLengths);
    PerformanceMonitor.instance.endSection('pbd');

    // 曲げ制約を強制（外殻が内側に折れ曲がることを防ぐ）
    _physicsSolver.enforceBendingConstraints(shellBodies);

    // 外殻の反転（クロス）を防止（曲げ制約で防げなかった場合のフォールバック）
    _physicsSolver.preventShellInversion(shellBodies);

    // ビーズ封じ込め制約（外殻の内側に留める）
    PerformanceMonitor.instance.startSection('bead');
    _physicsSolver.enforceBeadContainment(shellBodies, beadBodies);
    PerformanceMonitor.instance.endSection('bead');

    // ダミーボディを粒子の重心に追従させる
    if (shellBodies.isNotEmpty || beadBodies.isNotEmpty) {
      body.setTransform(centerPosition, 0);
    }

    // 接地判定（速度ベース）と発射カウントリセット
    _updateGroundedState();

    // 現在の速度を保存（次フレームの衝突検出用）
    _storePreviousVelocities();
  }

  /// 衝突検出（外殻粒子の速度変化を監視）
  void _detectImpact() {
    if (!_velocityBufferInitialized || shellBodies.isEmpty) return;

    double maxImpact = 0;
    for (int i = 0; i < shellBodies.length && i < _previousVelocities.length; i++) {
      final prevVel = _previousVelocities[i];
      final currVel = shellBodies[i].linearVelocity;
      // Vector2生成を避け、成分ごとに計算
      final dx = currVel.x - prevVel.x;
      final dy = currVel.y - prevVel.y;
      final velocityChangeSq = dx * dx + dy * dy;
      if (velocityChangeSq > maxImpact) {
        maxImpact = velocityChangeSq;
      }
    }

    // 閾値を超える速度変化があれば衝突音を再生（2乗で比較）
    final thresholdSq = _impactThreshold * _impactThreshold;
    if (maxImpact > thresholdSq) {
      final velocityChange = math.sqrt(maxImpact);
      final intensity = ((velocityChange - _impactThreshold) / _maxImpactIntensity).clamp(0.0, 1.0);
      AudioService.instance.playHit(intensity: intensity);
    }
  }

  /// 現在の速度を保存（バッファを再利用）
  void _storePreviousVelocities() {
    // バッファサイズが合わない場合のみ再作成
    if (_previousVelocities.length != shellBodies.length) {
      _previousVelocities = List.generate(
        shellBodies.length,
        (_) => Vector2.zero(),
      );
    }
    // setFrom()で既存のVector2を上書き（メモリ割り当てなし）
    for (int i = 0; i < shellBodies.length; i++) {
      _previousVelocities[i].setFrom(shellBodies[i].linearVelocity);
    }
    _velocityBufferInitialized = true;
  }

  /// 静止状態の更新（ドリフト防止）
  void _updateRestState() {
    // お手玉全体の速度で判定
    final velocity = getVelocity();
    final speed = velocity.length;

    if (speed < _restVelocityThreshold) {
      _restFrameCount++;
      if (_restFrameCount >= _restFramesRequired && !_isAtRest) {
        // 静止確定：全粒子の速度をゼロに固定
        _isAtRest = true;
        _freezeAllVelocities();
      }
    } else {
      // 動いているので静止解除
      _restFrameCount = 0;
      _isAtRest = false;
    }
  }

  /// 全粒子の速度をゼロに固定
  void _freezeAllVelocities() {
    for (final body in shellBodies) {
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
    }
    for (final body in beadBodies) {
      body.linearVelocity = Vector2.zero();
      body.angularVelocity = 0;
    }
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

  /// 外殻粒子の平均速度を取得（スカラー値）
  double _getAverageVelocity() {
    if (shellBodies.isEmpty) return 0;

    double totalSpeed = 0;
    for (final body in shellBodies) {
      totalSpeed += body.linearVelocity.length;
    }
    return totalSpeed / shellBodies.length;
  }

  /// お手玉全体の平均速度ベクトルを取得
  Vector2 getVelocity() {
    if (shellBodies.isEmpty && beadBodies.isEmpty) return Vector2.zero();

    var sum = Vector2.zero();
    var count = 0;

    for (final body in shellBodies) {
      sum += body.linearVelocity;
      count++;
    }
    for (final body in beadBodies) {
      sum += body.linearVelocity;
      count++;
    }

    return count > 0 ? sum / count.toDouble() : Vector2.zero();
  }

  /// お手玉全体に速度を設定
  void setVelocity(Vector2 velocity) {
    for (final body in shellBodies) {
      body.linearVelocity = velocity.clone();
    }
    for (final body in beadBodies) {
      body.linearVelocity = velocity.clone();
    }
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
      skin: _skin,
    );

    // テクスチャスキンの場合は画像を読み込み
    if (_skin.type == OtedamaSkinType.texture && _skin.texturePath != null) {
      final image = await TextureManager.instance.loadTexture(_skin.texturePath!);
      _renderer.setTextureImage(image);
    }

    _physicsSolver = ParticlePhysicsSolver(
      constraintIterations: distanceConstraintIterations,
      constraintStiffness: distanceConstraintStiffness,
      beadContainmentEnabled: beadContainmentEnabled,
      beadContainmentMargin: beadContainmentMargin,
      beadRadius: beadRadius,
      shellRadius: shellRadius,
      inversionCheckVelocityThreshold: inversionCheckVelocityThreshold,
      inversionCrossThreshold: inversionCrossThreshold,
      inversionPushStartRatio: inversionPushStartRatio,
      inversionPushTargetRatio: inversionPushTargetRatio,
      minBendingAngle: minBendingAngleDegrees * math.pi / 180.0,
      bendingStiffness: bendingStiffness,
    );
    _createParticleBodies();
  }

  void _createParticleBodies() {
    // 外殻を作成（円形に配置）
    for (int i = 0; i < shellCount; i++) {
      final angle = (i / shellCount) * 2 * math.pi;
      final x = initialPosition.x + math.cos(angle) * overallRadius * 0.7;
      final y = initialPosition.y + math.sin(angle) * overallRadius * 0.7;

      final body = _createShellBody(
        Vector2(x, y),
        angle,
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

    // 内部ビーズを作成（ランダムに配置、サイズもバリエーション）
    final random = math.Random();
    for (int i = 0; i < beadCount; i++) {
      // 中心付近にランダム配置
      final r = random.nextDouble() * overallRadius * 0.4;
      final angle = random.nextDouble() * 2 * math.pi;
      final x = initialPosition.x + math.cos(angle) * r;
      final y = initialPosition.y + math.sin(angle) * r;

      // ビーズサイズにバリエーション（小さいビーズは外殻の隙間に入りやすい）
      // 範囲: beadRadius * (1 - variation) 〜 beadRadius
      final sizeMultiplier = 1.0 - random.nextDouble() * beadSizeVariation;
      final actualRadius = beadRadius * sizeMultiplier;

      final body = _createCircleBody(
        Vector2(x, y),
        actualRadius,
        beadDensity,
        beadFriction,
        beadRestitution,
      );
      beadBodies.add(body);
    }
  }

  /// 外殻粒子のボディを作成（内側突起付き）
  Body _createShellBody(Vector2 position, double angle) {
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = position
      ..angularDamping = 1.0
      ..linearDamping = 0.1;

    final body = world.createBody(bodyDef);

    // メインの円形状
    final mainShape = CircleShape()..radius = shellRadius;
    body.createFixture(FixtureDef(mainShape)
      ..density = shellDensity
      ..friction = shellFriction
      ..restitution = shellRestitution);

    // 内側向きの突起を追加（ビーズとの接触用）
    if (shellSpikeEnabled && shellSpikeLength > 0 && shellSpikeRadius > 0) {
      // 内側方向（中心に向かう方向）= angleの逆方向
      final spikeOffsetX = -math.cos(angle) * shellSpikeLength;
      final spikeOffsetY = -math.sin(angle) * shellSpikeLength;

      final spikeShape = CircleShape()
        ..radius = shellSpikeRadius
        ..position.setValues(spikeOffsetX, spikeOffsetY);

      body.createFixture(FixtureDef(spikeShape)
        ..density = shellDensity * 0.5 // 突起は軽めに
        ..friction = shellFriction
        ..restitution = shellRestitution);
    }

    return body;
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

  /// ビーズを1つ追加（小豆を拾った時に呼ばれる）
  void addBead() {
    final random = math.Random();
    final center = centerPosition;

    // 中心付近にランダム配置
    final r = random.nextDouble() * overallRadius * 0.3;
    final angle = random.nextDouble() * 2 * math.pi;
    final x = center.x + math.cos(angle) * r;
    final y = center.y + math.sin(angle) * r;

    // ビーズサイズにバリエーション
    final sizeMultiplier = 1.0 - random.nextDouble() * beadSizeVariation;
    final actualRadius = beadRadius * sizeMultiplier;

    final body = _createCircleBody(
      Vector2(x, y),
      actualRadius,
      beadDensity,
      beadFriction,
      beadRestitution,
    );
    beadBodies.add(body);

    logger.debug(LogCategory.game, 'Bead added, total: ${beadBodies.length}');
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
      beadRadii: beadBodies.map((b) {
        // 各ビーズの実際の半径を取得（CircleShapeから）
        final fixture = b.fixtures.first;
        final shape = fixture.shape as CircleShape;
        return shape.radius;
      }).toList(),
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
      logger.debug(LogCategory.input, 'Launch blocked: max launches reached');
      return; // 発射回数制限に達している
    }

    // 静止状態を解除
    _isAtRest = false;
    _restFrameCount = 0;

    // 空中発射かどうかで力を調整
    final powerMultiplier = (_launchCount >= 1) ? airLaunchMultiplier : 1.0;
    final launchType = _launchCount == 0 ? 'initial' : 'air';
    logger.info(LogCategory.input, 'Launch ($launchType): impulse=${impulse.length.toStringAsFixed(2)}, power=$powerMultiplier');
    final scaledImpulse = impulse * launchMultiplier * powerMultiplier;

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
    logger.debug(LogCategory.game, 'Otedama reset');
    _destroyAllBodies();
    _createParticleBodies();
    _launchCount = 0;
    _isGrounded = true;
    _velocityBufferInitialized = false;
    _isAtRest = false;
    _restFrameCount = 0;
  }

  /// 指定位置にリセット（オプションで速度を維持）
  void resetToPosition(Vector2 newPosition, {Vector2? velocity}) {
    // 現在位置との差分を計算
    final diff = newPosition - centerPosition;
    final newVelocity = velocity ?? Vector2.zero();

    // 全ボディを移動
    for (final body in shellBodies) {
      body.setTransform(body.position + diff, body.angle);
      body.linearVelocity = newVelocity.clone();
      body.angularVelocity = 0;
    }
    for (final body in beadBodies) {
      body.setTransform(body.position + diff, body.angle);
      body.linearVelocity = newVelocity.clone();
      body.angularVelocity = 0;
    }

    // 速度がある場合は発射済み扱い、それ以外はリセット
    if (velocity != null && velocity.length > _groundedVelocityThreshold) {
      _launchCount = 1; // 空中発射1回分として扱う
      _isGrounded = false;
      _isAtRest = false;
      _restFrameCount = 0;
    } else {
      _launchCount = 0;
      _isGrounded = true;
      _isAtRest = false;
      _restFrameCount = 0;
    }
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
    // レンダラーを再作成（半径などのパラメータ変更を反映）
    _renderer = ParticleRenderer(
      color: color,
      shellRadius: shellRadius,
      beadRadius: beadRadius,
      skin: _skin,
    );

    // テクスチャスキンの場合は画像を再設定
    if (_skin.type == OtedamaSkinType.texture && _skin.texturePath != null) {
      TextureManager.instance.loadTexture(_skin.texturePath!).then((image) {
        _renderer.setTextureImage(image);
      });
    }

    // 物理ソルバーも再作成
    _physicsSolver = ParticlePhysicsSolver(
      constraintIterations: distanceConstraintIterations,
      constraintStiffness: distanceConstraintStiffness,
      beadContainmentEnabled: beadContainmentEnabled,
      beadContainmentMargin: beadContainmentMargin,
      beadRadius: beadRadius,
      shellRadius: shellRadius,
      inversionCheckVelocityThreshold: inversionCheckVelocityThreshold,
      inversionCrossThreshold: inversionCrossThreshold,
      inversionPushStartRatio: inversionPushStartRatio,
      inversionPushTargetRatio: inversionPushTargetRatio,
      minBendingAngle: minBendingAngleDegrees * math.pi / 180.0,
      bendingStiffness: bendingStiffness,
    );

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
