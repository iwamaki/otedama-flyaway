# パフォーマンス最適化計画

## 調査日: 2025-12-07

## 問題点と最適化案

### 1. particle_otedama.dart - Vector2バッファの再利用

**問題箇所**: `_storePreviousVelocities()` (行174-177)
```dart
// 現状: 毎フレーム20個のVector2をclone()
_previousVelocities.clear();
for (final body in shellBodies) {
  _previousVelocities.add(body.linearVelocity.clone());
}
```

**影響**: 60FPSで1200回/秒のメモリ割り当て

**最適化案**:
```dart
// 固定サイズのバッファを再利用
if (_previousVelocities.length != shellBodies.length) {
  _previousVelocities = List.generate(
    shellBodies.length,
    (_) => Vector2.zero(),
  );
}
for (int i = 0; i < shellBodies.length; i++) {
  _previousVelocities[i].setFrom(shellBodies[i].linearVelocity);
}
```

**状態**: [x] 完了 (2025-12-07)

---

### 2. particle_physics_solver.dart - 制約ソルバーの最適化

**問題箇所**: `enforceDistanceConstraints()` (行67-124)

**影響**: 10反復 × 20ボディ = 200回/フレームのループ

**最適化案A**: 反復回数を10→5に削減（品質確認必要）
**最適化案B**: 平方根計算を2乗比較に変更

**状態**: [-] 反復回数削減は要テスト（現状維持）

---

### 3. particle_physics_solver.dart - ビーズ封じ込めの最適化

**問題箇所**: `enforceBeadContainment()` (行128-167)

**影響**: 15ビーズ × 20エッジ = 最大300判定/フレーム

**実施した最適化**:
- shellPositionCache を導入（毎フレームのリスト再作成を防止）
- 重心をキャッシュ（_centroidCache）して各ビーズで再利用
- 距離比較を2乗で行い、sqrtを削減

**状態**: [x] 完了 (2025-12-07)

---

### 4. otedama_game.dart - 重力の条件付き更新

**問題箇所**: `update()` (行165)

**実施した最適化**:
```dart
// gravityScaleが変わった時のみ更新
if (_lastGravityScale != ParticleOtedama.gravityScale) {
  world.gravity = Vector2(0, PhysicsConfig.gravityY * ParticleOtedama.gravityScale);
  _lastGravityScale = ParticleOtedama.gravityScale;
}
```

**状態**: [x] 完了 (2025-12-07)

---

### 5. particle_renderer.dart - スプラインパスのキャッシュ

**問題箇所**: `_createSmoothPath()` (行260-281)

**影響**: 毎フレーム20点のCatmull-Romスプライン計算

**最適化案**: 形状が安定している場合は数フレームキャッシュ
- 前フレームとの差分が小さければ再利用

**状態**: [ ] 未着手（複雑なため保留）

---

### 6. audio_service.dart - クールダウン更新の最適化

**問題箇所**: `update()` (行61-67)

**実施した最適化**:
```dart
void update(double dt) {
  // クールダウンがない場合は早期リターン
  if (_hitCooldown <= 0 && _launchImmunity <= 0) return;
  if (_hitCooldown > 0) _hitCooldown -= dt;
  if (_launchImmunity > 0) _launchImmunity -= dt;
}
```

**状態**: [x] 完了 (2025-12-07)

---

## 優先順位

1. **Vector2バッファ再利用** - 簡単で効果大 (推定5-10%改善)
2. **重力の条件付き更新** - 極めて簡単 (推定1-2%改善)
3. **AudioService最適化** - 簡単 (推定0.5-1%改善)
4. **制約ソルバー反復削減** - 効果大だが品質影響あり (推定10-15%改善)
5. **ビーズ封じ込め最適化** - 中程度の変更 (推定3-5%改善)
6. **スプラインキャッシュ** - 複雑 (推定2-4%改善)

**推定総合改善**: 20-35% FPS向上

## 注意事項

- 各最適化後にゲームプレイを確認すること
- 物理挙動が変わっていないかテストすること
- パフォーマンス計測を行うこと（Flutter DevTools）
