# リファクタリング計画

## 完了済み

### 1. JSONシリアライズヘルパー
- `lib/utils/json_helpers.dart` を作成
- Platform, Goal, ImageObject の `fromJson` を簡潔化

### 2. 選択ハイライト描画の共通化
- `lib/utils/selection_highlight.dart` を作成
- 3ファイルで ~60行の重複コードを削除

---

## 次のステップ（優先度順）

### Phase 1: OtedamaGame の分割 (550行 → 4クラス)

**現状の問題**: ゲーム状態、入力処理、カメラ、編集モードが1ファイルに混在

**分割案**:
```
lib/game/
├── otedama_game.dart       # メインゲームクラス（軽量化）
├── game_input_handler.dart # ドラッグ入力処理
├── camera_controller.dart  # カメラ追従ロジック
└── stage_manager.dart      # ステージ読み込み/保存
```

### Phase 2: ParticleOtedama の分割 (730行 → 3クラス)

**現状の問題**: 物理シミュレーション、レンダリング、発射機構が混在

**分割案**:
```
lib/components/
├── particle_otedama.dart           # メインクラス（軽量化）
├── particle_physics_solver.dart    # 距離拘束・ビーズ制御
└── particle_renderer.dart          # 描画ロジック
```

### Phase 3: ImageObject の整理 (521行)

**分割案**:
- 凸包計算 (`_convexHull`, `_cross`) → `lib/utils/geometry.dart`
- 輪郭分割ロジック → `lib/utils/contour_processor.dart`

---

## 削除候補（未使用コード）

- `ImageObject._splitContourIntoChunks` (未使用)
- `ImageObject._debugDrawContours` (デバッグ用、コメントアウト中)

---

## コード品質の改善

- [ ] stage_object.dart: 不要なgetter/setter警告を修正
- [ ] stage_editor.dart: BuildContext非同期警告を修正
