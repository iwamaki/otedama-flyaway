# Otedama Flyaway ステージ構築ガイド

このドキュメントは、AIまたは開発者がステージを効果的に構築するためのリファレンスです。

## 概要

ステージは `assets/stages/` 配下のJSONファイルで定義されます。各ステージには地形、オブジェクト、環境音、背景などの設定が含まれます。

**注意**: Goal（ゴール）はゲームクリア地点であり、開発者が最終的に配置します。ステージ構築時はGoalを含めないでください。

---

## ステージ作成ワークフロー

ステージは一度に作成せず、以下のステップに分けて段階的に構築します。

### Step 1: コンセプト確認

開発者からステージのコンセプト指示を受けます。

確認事項：
- ステージ番号・レベル番号（例: ステージ1-2 = ステージ番号1、レベル番号2）
- ステージのテーマ・雰囲気
- 難易度の目安
- 特徴的なギミック

### Step 2: 基本地形の設計

コンセプトに基づいてTerrainで基本地形を作成します。

この段階では：
- メインの地形（Terrain）のみ配置
- 斜面、段差、谷などの基本構造を決定
- スポーン位置を設定

### Step 3: オブジェクト配置

基本地形が完成したら、ステージの進行度に応じてオブジェクトを配置します。

| ゲーム進行 | 使用オブジェクト |
|-----------|-----------------|
| 序盤 | Platform中心。シンプルな足場配置 |
| 中盤 | Trampoline、IceFloorを追加 |
| 終盤 | 全オブジェクトを駆使した複合ギミック |

### Step 2・3 の調整サイクル

地形やオブジェクトは、まず大雑把に配置します。その後、開発者が実際にプレイしながらフィードバックを行い、AIが修正を加えていきます。

```
配置 → プレイテスト → フィードバック → 修正 → プレイテスト → ...
```

このサイクルを繰り返すことで、ステージ設計の練度を上げていきます。

### Step 4: ステージ間の遷移設定

TransitionZoneを使って複数のレベルを接続します。

**命名規則**

| 表記 | 意味 | 例 |
|------|------|-----|
| ステージX-Y | ステージ番号X、レベル番号Y | ステージ2-3 |
| ファイル名 | `stage{ステージ番号}-{レベル番号}.json` | `stage2-3.json` |

```
例: ステージ2の構成
├── stage2-1.json  （レベル1: 入口エリア）
├── stage2-2.json  （レベル2: 中間エリア）
└── stage2-3.json  （レベル3: 最終エリア・ゴール配置予定）
```

**同じステージ番号内のルール**

| 項目 | ルール |
|------|--------|
| 背景画像 | 同じステージ番号内で統一 |
| BGM | 同じステージ番号内で統一 |
| 地形タイプ | 同じステージ番号内で統一推奨 |

**例外について**: ステージの演出上、同じステージ番号内でもBGMや背景を変えることがあります（例: ステージ2-3でボス戦用BGMに切り替え、隠しエリアで雰囲気を変えるなど）。創造性を優先してください。

### ワークフロー例

```
1. 開発者: 「ステージ2は洞窟テーマで、3レベル構成で作成」

2. AI: Step 2 - stage2-1.json の基本地形を作成
   → 開発者確認・フィードバック

3. AI: Step 3 - stage2-1.json にオブジェクト配置
   → 開発者確認・フィードバック

4. AI: Step 2 - stage2-2.json の基本地形を作成
   → 以下繰り返し...

5. AI: Step 4 - 各レベル間のTransitionZoneを設定

6. 開発者: Goalを最終レベルに配置
```

---

## ステージJSON構造

```json
{
  "level": 1,
  "name": "ステージ1",
  "background": "tatami.jpg",
  "ambientSound": "morning_sparrows.mp3",
  "ambientSoundVolume": 0.5,
  "spawnX": 0.0,
  "spawnY": 5.0,
  "boundaries": {
    "fallThreshold": 50.0,
    "transitions": []
  },
  "objects": []
}
```

### 基本フィールド

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `level` | int | Yes | ステージ番号（識別・表示順序用） |
| `name` | string | Yes | ステージ名（UI表示用） |
| `background` | string | No | 背景画像ファイル名（`assets/background/`配下） |
| `ambientSound` | string | No | BGMファイル名（`assets/audio/environmental_sounds/`配下） |
| `ambientSoundVolume` | double | No | BGM音量（0.0〜1.0、デフォルト0.5） |
| `spawnX` | double | Yes | お手玉の初期X座標 |
| `spawnY` | double | Yes | お手玉の初期Y座標（上がマイナス） |
| `boundaries` | object | Yes | ステージ境界設定 |
| `objects` | array | Yes | ステージオブジェクトの配列 |

### 座標系

- **原点**: 画面中央
- **X軸**: 右がプラス、左がマイナス
- **Y軸**: 下がプラス、上がマイナス（物理エンジン座標系）
- **単位**: ワールド単位（1単位 ≈ 64ピクセル）

---

## 利用可能なオブジェクト

### 1. Terrain（地形）

複雑な形状の地形を作成できます。メインの足場や壁として使用。

**基本例（斜面と段差のある地形）:**

```json
{
  "type": "terrain",
  "x": 0.0,
  "y": 0.0,
  "vertices": [
    {"x": -30.0, "y": 5.0},
    {"x": -15.0, "y": 5.0},
    {"x": -10.0, "y": 8.0},
    {"x": 5.0, "y": 8.0},
    {"x": 10.0, "y": 3.0},
    {"x": 25.0, "y": 3.0},
    {"x": 25.0, "y": 20.0},
    {"x": -30.0, "y": 20.0}
  ],
  "isLoop": true,
  "terrainType": "grass"
}
```

**丘陵地形の例:**

```json
{
  "type": "terrain",
  "x": 0.0,
  "y": 0.0,
  "vertices": [
    {"x": -25.0, "y": 10.0},
    {"x": -18.0, "y": 6.0},
    {"x": -10.0, "y": 8.0},
    {"x": 0.0, "y": 4.0},
    {"x": 8.0, "y": 7.0},
    {"x": 15.0, "y": 5.0},
    {"x": 25.0, "y": 10.0},
    {"x": 25.0, "y": 20.0},
    {"x": -25.0, "y": 20.0}
  ],
  "isLoop": true,
  "terrainType": "grass"
}
```

**L字型の壁:**

```json
{
  "type": "terrain",
  "x": 0.0,
  "y": 0.0,
  "vertices": [
    {"x": -5.0, "y": -15.0},
    {"x": 0.0, "y": -15.0},
    {"x": 0.0, "y": 0.0},
    {"x": 10.0, "y": 0.0},
    {"x": 10.0, "y": 5.0},
    {"x": -5.0, "y": 5.0}
  ],
  "isLoop": true,
  "terrainType": "rock"
}
```

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `x`, `y` | double | 地形の基準位置 |
| `vertices` | array | 頂点座標の配列（反時計回り推奨） |
| `isLoop` | bool | true: 閉じた形状、false: 開いた線 |
| `terrainType` | string | 地形タイプ（下記参照） |

#### 地形タイプ（terrainType）

| タイプ | 見た目 | 用途 |
|--------|--------|------|
| `grass` | 茶色の土（草付き） | 基本的な地面 |
| `dirt` | 茶色の土 | 土の地面 |
| `rock` | グレーの岩 | 岩場、洞窟 |
| `ice` | 水色の氷 | 滑りやすい場所 |
| `wood` | 茶色の木目 | 木製の足場 |
| `metal` | スレートグレー | 金属製の構造物 |

### 2. Platform（足場）

シンプルな矩形の足場。木目テクスチャで描画されます。

```json
{
  "type": "platform",
  "x": 10.0,
  "y": -5.0,
  "width": 6.0,
  "height": 0.5,
  "angle": 0.0,
  "color": 4285238819
}
```

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| `x`, `y` | double | - | 中心座標 |
| `width` | double | 6.0 | 幅 |
| `height` | double | 0.5 | 高さ |
| `angle` | double | 0.0 | 回転角度（ラジアン） |
| `color` | int | - | 色（ARGB形式、省略可） |

### 3. TransitionZone（遷移ゾーン）

別のステージ、または同じステージ内の別の場所へ移動するためのトリガーゾーン。

```json
{
  "type": "transitionZone",
  "x": 18.0,
  "y": -4.0,
  "width": 5.0,
  "height": 5.0,
  "angle": 0.0,
  "nextStage": "assets/stages/stage1.json",
  "spawnX": 10.0,
  "spawnY": 3.5,
  "linkId": "unique_id_123"
}
```

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `x`, `y` | double | 中心座標 |
| `width`, `height` | double | サイズ（デフォルト5.0） |
| `nextStage` | string | 遷移先ステージのアセットパス |
| `spawnX`, `spawnY` | double | 遷移先でのスポーン位置（省略時はステージデフォルト） |
| `linkId` | string | ペアゾーンを結びつけるID（双方向遷移用） |

**ポイント**:
- **別ステージへの遷移**: `nextStage`に別のステージファイルを指定
- **同じステージ内の遷移**: `nextStage`に自身のステージファイルを指定し、`spawnX`/`spawnY`で別の場所を指定（ワープ機能として使用可能）
- **双方向遷移**: 2つのTransitionZoneに同じ`linkId`を設定

### 4. Trampoline（トランポリン）

接触するとお手玉を上方に弾くオブジェクト。

```json
{
  "type": "trampoline",
  "x": 0.0,
  "y": 0.0,
  "width": 6.0,
  "height": 0.4,
  "angle": 0.0,
  "bounceForce": 120.0
}
```

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| `width` | double | 6.0 | 幅 |
| `height` | double | 0.4 | 高さ |
| `bounceForce` | double | 120.0 | 弾く力の強さ |

### 5. IceFloor（氷床）

摩擦がほぼゼロの滑りやすい床。

```json
{
  "type": "iceFloor",
  "x": 0.0,
  "y": 0.0,
  "width": 5.0,
  "height": 0.4,
  "angle": 0.0,
  "friction": 0.01
}
```

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| `width` | double | 5.0 | 幅 |
| `height` | double | 0.4 | 高さ |
| `friction` | double | 0.01 | 摩擦係数 |

### 6. ImageObject（画像オブジェクト）

透過画像をベースにした物理オブジェクト。画像の輪郭が衝突形状になります。

```json
{
  "type": "image_object",
  "imagePath": "path/to/image.png",
  "x": 0.0,
  "y": 0.0,
  "angle": 0.0,
  "scale": 0.05,
  "friction": 0.5,
  "restitution": 0.2,
  "flipX": false,
  "flipY": false
}
```

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|-----------|------|
| `imagePath` | string | - | 画像ファイルパス |
| `scale` | double | 0.05 | スケール |
| `friction` | double | 0.5 | 摩擦係数 |
| `restitution` | double | 0.2 | 反発係数 |
| `flipX`, `flipY` | bool | false | 反転フラグ |

**注意**: 画像には対応する物理データ（`assets/physics/*.json`）が必要です。

### 7. Goal（ゴール）- 参考情報

ゲームクリア地点となる竹籠風のオブジェクト。**開発者が最終的に配置するため、ステージ構築時は含めないでください。**

---

## 環境音システム

### 利用可能なBGM

BGMファイルは `assets/audio/environmental_sounds/` に配置されています。ステージの雰囲気に合わせて選択してください。

| ファイル名 | 雰囲気 |
|-----------|--------|
| `morning_sparrows.mp3` | 朝の小鳥のさえずり |
| `summer_countryside_night.mp3` | 夏の田舎の夜（虫の声） |
| `summer_mountain_cicadas.mp3` | 夏の山（蝉の声） |
| `mountain in spring.mp3` | 春の山 |
| `mountain_pond.mp3` | 山の池 |
| `rustling_plants.mp3` | 植物のざわめき |
| `wind.mp3` | 風の音 |
| `rain.mp3` | 雨の音 |
| `thunderstorm.mp3` | 雷雨 |
| `blizzard.mp3` | 吹雪 |
| `dripping_cave.mp3` | 洞窟（水滴） |
| `sewer.mp3` | 下水道 |
| `giant_robot_factory.mp3` | 巨大ロボット工場 |
| `magical_room.mp3` | 魔法の部屋 |
| `dimensional_space.mp3` | 異次元空間 |
| `afterlife.mp3` | あの世 |

### BGM設定例

```json
{
  "ambientSound": "dripping_cave.mp3",
  "ambientSoundVolume": 0.5
}
```

**クロスフェード**: ステージ間でBGMが変わる場合、自動的にクロスフェードします。

---

## 背景画像

背景は `assets/background/` に配置されています。

| ファイル名 | 説明 |
|-----------|------|
| `tatami.jpg` | 畳の背景 |

**注意**: 背景画像は今後追加予定です。現時点では `tatami.jpg` を使用してください。

---

## 境界設定

### fallThreshold

お手玉がこのY座標を超えると落下扱いになりリスポーンします。

```json
{
  "boundaries": {
    "fallThreshold": 50.0,
    "transitions": []
  }
}
```

### transitions（境界遷移）

ステージの端に到達した際の自動遷移を設定できます。

```json
{
  "boundaries": {
    "fallThreshold": 50.0,
    "transitions": [
      {
        "edge": "right",
        "threshold": 30.0,
        "nextStage": "assets/stages/stage2.json"
      }
    ]
  }
}
```

| edge値 | 説明 |
|--------|------|
| `left` | 左端（X < -threshold） |
| `right` | 右端（X > threshold） |
| `top` | 上端（Y < -threshold） |
| `bottom` | 下端（Y > threshold） |

---

## 設計のベストプラクティス

### お手玉の移動能力

ステージ設計時は、お手玉の移動能力を考慮してください：

- **最大ジャンプ高さ**: 約16マス（ワールド単位）
- **最大ジャンプ幅**: 約4マス（ワールド単位）

これらの制約を超える距離には、トランポリンや中間足場を配置してください。

### 地形設計

1. **メイン地面**: 大きなTerrainを配置してベースとなる地面を作成
2. **障害物**: 小さなTerrainやPlatformで足場を追加
3. **高低差**: 異なるY座標に複数の足場を配置してジャンプを促す
4. **到達可能性**: 全ての足場がお手玉の移動能力で到達可能か確認

### スポーン位置

- お手玉が安全に着地できる場所に設定
- 地面より少し上（Y座標が小さい値）に設定

### TransitionZone

- ステージの端や特定エリアに配置
- 視覚的に分かりやすい位置に設置
- linkIdで双方向遷移を実現
- 同じステージ内でのワープにも活用可能

---

## ステージ新規作成手順

### 1. JSONファイルを作成

`assets/stages/stageN.json` を作成：

```json
{
  "level": 3,
  "name": "ステージ3",
  "background": "tatami.jpg",
  "ambientSound": "dripping_cave.mp3",
  "ambientSoundVolume": 0.5,
  "spawnX": -20.0,
  "spawnY": 0.0,
  "boundaries": {
    "fallThreshold": 50.0,
    "transitions": []
  },
  "objects": [
    {
      "type": "terrain",
      "x": 0.0,
      "y": 0.0,
      "vertices": [
        {"x": -25.0, "y": 5.0},
        {"x": -10.0, "y": 5.0},
        {"x": -5.0, "y": 10.0},
        {"x": 10.0, "y": 10.0},
        {"x": 15.0, "y": 5.0},
        {"x": 25.0, "y": 5.0},
        {"x": 25.0, "y": 20.0},
        {"x": -25.0, "y": 20.0}
      ],
      "isLoop": true,
      "terrainType": "rock"
    },
    {
      "type": "platform",
      "x": 0.0,
      "y": -5.0,
      "width": 8.0,
      "height": 0.5,
      "angle": 0.0
    },
    {
      "type": "trampoline",
      "x": -15.0,
      "y": 4.5,
      "width": 4.0,
      "height": 0.4,
      "bounceForce": 100.0
    }
  ]
}
```

### 2. StageRegistryに登録

`lib/models/stage_data.dart` の `StageRegistry.entries` に追加：

```dart
static final List<StageEntry> entries = [
  StageEntry(level: 1, name: 'ステージ1', assetPath: 'assets/stages/stage1.json'),
  StageEntry(level: 2, name: 'ステージ2', assetPath: 'assets/stages/stage2.json'),
  StageEntry(level: 3, name: 'ステージ3', assetPath: 'assets/stages/stage3.json'), // 追加
];
```

### 3. pubspec.yamlにアセット登録

```yaml
flutter:
  assets:
    - assets/stages/stage3.json
```

---

## 関連ファイル

| パス | 説明 |
|------|------|
| `lib/models/stage_data.dart` | ステージデータモデル、StageRegistry |
| `lib/game/stage/stage_manager.dart` | ステージ読み込み・管理 |
| `lib/components/stage/` | 各ステージオブジェクトの実装 |
| `lib/services/audio_service.dart` | 音声サービス |
| `assets/stages/` | ステージJSONファイル |
| `assets/background/` | 背景画像 |
| `assets/audio/environmental_sounds/` | BGMファイル |
