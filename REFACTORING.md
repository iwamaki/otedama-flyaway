# リファクタリング計画

## 完了済み

### 1. JSONシリアライズヘルパー
- `lib/utils/json_helpers.dart` を作成
- Platform, Goal, ImageObject の `fromJson` を簡潔化

### 2. 選択ハイライト描画の共通化
- `lib/utils/selection_highlight.dart` を作成
- 3ファイルで ~60行の重複コードを削除

### 3. CameraController の抽出
- `lib/game/camera_controller.dart` を作成
- OtedamaGame から `_updateCameraFollow` を分離
- カメラ追従ロジックを独立クラスに

### 4. ImageObject の未使用コード削除
- `_splitContourIntoChunks` (未使用) を削除
- `_convexHull`, `_cross`, `_calculateCenter` (上記に依存) を削除
- `_debugDrawContours` (デバッグ用) を削除
- 不要な `dart:math` import を削除
- **削減: 約80行**

---

## 次のステップ（優先度順）

### Phase 1: OtedamaGame の分割 (530行 → 3クラス)

**現状の問題**: ゲーム状態、入力処理、編集モードが1ファイルに混在

**残りの分割案**:
```
lib/game/
├── otedama_game.dart       # メインゲームクラス（軽量化）
├── camera_controller.dart  # ✅ 完了
├── stage_manager.dart      # Mixin作成済み、統合は保留
└── game_input_handler.dart # 入力処理（OtedamaGameと密結合、要検討）
```

**備考**: `StageManagerMixin` を作成したが、OtedamaGameとのフィールド競合が多いため統合を保留。

### Phase 2: ParticleOtedama の分割 (730行 → 3クラス)

**現状の問題**: 物理シミュレーション、レンダリング、発射機構が混在

**分割案**:
```
lib/components/
├── particle_otedama.dart           # メインクラス（軽量化）
├── particle_physics_solver.dart    # 距離拘束・ビーズ制御
└── particle_renderer.dart          # 描画ロジック
```

### Phase 3: ImageObject の整理 (400行)

**分割案**:
- 凸包計算が必要になった場合 → `lib/utils/geometry.dart` に抽出

---

## コード品質の改善

- [ ] stage_object.dart: 不要なgetter/setter警告を修正
- [ ] stage_editor.dart: BuildContext非同期警告を修正
