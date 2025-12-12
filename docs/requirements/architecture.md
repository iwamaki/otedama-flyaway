# Otedama Flyaway - アーキテクチャ & 実装計画

## ゲームコンセプト

**Getting Over It風の縦スクロールお手玉ゲーム**
- 上を目指して飛び跳ねる
- 落ちたら進捗を失う（ショック演出）
- 遊びながらステージを編集できる

---

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────┐
│                    main.dart                     │
│            MaterialApp + GameWidget              │
└─────────────────────────────────────────────────┘
                        │
        ┌───────────────┴───────────────┐
        ▼                               ▼
┌───────────────┐               ┌───────────────┐
│  OtedamaGame  │◄─────────────►│   UI Layer    │
│  (Forge2D)    │               │  (Flutter)    │
└───────────────┘               └───────────────┘
        │                               │
        ▼                               ▼
┌───────────────┐               ┌───────────────┐
│  Components   │               │  EditorUI     │
│  - Otedama    │               │  - Palette    │
│  - Platform   │               │  - Properties │
│  - Goal       │               │  - Toolbar    │
└───────────────┘               └───────────────┘
        │
        ▼
┌───────────────┐
│  StageData    │ ←→ JSON保存/読み込み
└───────────────┘
```

---

## コア設計方針

### 1. プレイ/編集モードの切り替え
- 同じ画面で切り替え可能
- 編集中も物理演算は動く（リアルタイムプレビュー）
- 編集モード時はお手玉をリセット可能

### 2. ステージオブジェクトの共通インターフェース
```dart
// すべての配置可能オブジェクトが実装
abstract class StageObject {
  String get type;           // "platform", "wall", "goal" など
  Vector2 get position;
  double get angle;
  Map<String, dynamic> toJson();
  void applyProperties(Map<String, dynamic> props);
}
```

### 3. ステージデータ形式（JSON）
```json
{
  "version": 1,
  "name": "ステージ1",
  "spawnPoint": { "x": 0, "y": 0 },
  "objects": [
    { "type": "platform", "x": 0, "y": 5, "width": 3, "angle": 0 },
    { "type": "platform", "x": 2, "y": 10, "width": 2, "angle": -15 },
    { "type": "goal", "x": 0, "y": 100 }
  ]
}
```

### 4. カメラシステム
- お手玉の位置を追従（縦横両方向）
- スムーズな追従（lerp補間）
- 編集モード時はドラッグでカメラ移動可能
- ズーム機能（ピンチ操作）も将来的に検討

---

## ディレクトリ構成（予定）

```
lib/
├── main.dart
├── game/
│   ├── otedama_game.dart      # ゲームメイン
│   └── game_mode.dart         # プレイ/編集モード管理
├── components/
│   ├── otedama/
│   │   └── particle_otedama.dart
│   ├── stage/                 # 配置オブジェクト
│   │   ├── stage_object.dart  # 共通インターフェース
│   │   ├── platform.dart      # 足場
│   │   └── goal.dart          # ゴール
│   ├── background.dart
│   └── drag_line.dart
├── stage/                     # ステージデータ
│   ├── stage_data.dart        # データモデル
│   └── stage_repository.dart  # 保存/読み込み
├── editor/                    # エディタ機能
│   ├── editor_controller.dart # 編集操作
│   ├── object_palette.dart    # オブジェクト選択
│   └── editor_overlay.dart    # エディタUI
├── ui/
│   └── physics_tuner.dart     # 開発用パラメータ調整
└── config/
    └── physics_config.dart
```

---

## 実装フェーズ

### Phase 1: 基盤 ✅
- [x] カメラ追従システム（お手玉を追う、縦横両方向）
- [x] 開放的なワールド（壁を削除、自由に移動可能）
- [x] 落下判定とリスポーン
- [x] デモ用の足場配置

### Phase 2: ステージオブジェクト
- [ ] Platform（足場）コンポーネント
  - 位置、幅、角度を持つ
  - 物理衝突あり
- [ ] StageObjectインターフェース定義
- [ ] Goal（ゴール籠）コンポーネント

### Phase 3: ステージデータ
- [ ] StageDataモデル（JSON変換）
- [ ] ステージ読み込み→ゲームに反映
- [ ] ステージ保存（ローカルストレージ）

### Phase 4: エディタ基本
- [ ] 編集モード切り替えUI
- [ ] オブジェクトのタップ選択
- [ ] 選択オブジェクトのドラッグ移動
- [ ] オブジェクトの削除

### Phase 5: エディタ発展
- [ ] オブジェクトパレット（新規追加）
- [ ] プロパティ編集（幅、角度など）
- [ ] ステージ保存/読み込みUI

### Phase 6: ゲーム体験
- [ ] ショック演出（画面揺れ、効果音）
- [ ] ゴール到達演出

---

## 技術メモ

### Flame/Forge2D での注意点
- `BodyComponent`は物理演算付き、`PositionComponent`は描画のみ
- カメラは`camera.viewfinder`で制御
- ワールド座標とスクリーン座標の変換に注意

### エディタでの選択・ドラッグ
- `DragCallbacks`をゲームクラスで処理
- 編集モード時はお手玉発射を無効化
- オブジェクト選択はワールド座標でヒットテスト

### 保存形式
- 開発中はJSON（可読性重視）
- SharedPreferencesまたはファイル保存
- 将来的にはFirebase等も検討可能

---

## 柔軟性のためのガイドライン

1. **厳密な設計より動くものを優先**
   - インターフェースは必要になったら抽出
   - 最初はシンプルに、リファクタは後から

2. **ハードコードOK**
   - 最初は定数値でOK、設定化は必要に応じて
   - プロトタイプ段階では柔軟に

3. **1つずつ動くようにする**
   - 大きな変更より小さな追加
   - 常に実行可能な状態を維持

---

## 次のアクション

**Phase 2 or 4**: 足場コンポーネント整備 or ステージエディタ実装
