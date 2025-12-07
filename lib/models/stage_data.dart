import 'dart:convert';

import 'package:flutter/services.dart';

/// 境界の辺
enum BoundaryEdge {
  top, // Y座標が threshold 未満で発動
  bottom, // Y座標が threshold 超過で発動
  left, // X座標が threshold 未満で発動
  right, // X座標が threshold 超過で発動
}

/// 遷移境界の定義
class TransitionBoundary {
  /// どの辺か
  final BoundaryEdge edge;

  /// 座標のしきい値
  final double threshold;

  /// 次ステージのassetPath
  final String nextStage;

  const TransitionBoundary({
    required this.edge,
    required this.threshold,
    required this.nextStage,
  });

  factory TransitionBoundary.fromJson(Map<String, dynamic> json) {
    return TransitionBoundary(
      edge: BoundaryEdge.values.firstWhere(
        (e) => e.name == json['edge'],
        orElse: () => BoundaryEdge.top,
      ),
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      nextStage: json['nextStage'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'edge': edge.name,
      'threshold': threshold,
      'nextStage': nextStage,
    };
  }
}

/// ステージ境界設定
class StageBoundaries {
  /// 落下リセット境界（Y座標がこの値を超えたらリセット）
  final double fallThreshold;

  /// 遷移境界のリスト
  final List<TransitionBoundary> transitions;

  const StageBoundaries({
    this.fallThreshold = 50.0,
    this.transitions = const [],
  });

  factory StageBoundaries.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const StageBoundaries();
    }
    return StageBoundaries(
      fallThreshold: (json['fallThreshold'] as num?)?.toDouble() ?? 50.0,
      transitions: (json['transitions'] as List<dynamic>?)
              ?.map((e) => TransitionBoundary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fallThreshold': fallThreshold,
      'transitions': transitions.map((e) => e.toJson()).toList(),
    };
  }

  /// 遷移先がないか（最終ステージか）
  bool get isFinalStage => transitions.isEmpty;
}

/// ステージデータモデル
/// JSONファイルからステージ情報を読み込み・保存する
class StageData {
  /// ステージレベル（表示順・識別用）
  final int level;

  /// ステージ名
  final String name;

  /// 背景画像パス（nullならデフォルト背景）
  final String? background;

  /// 環境音/BGMのファイル名（nullなら環境音なし）
  /// 例: 'morning_sparrows.mp3'
  final String? ambientSound;

  /// 環境音の音量（0.0〜1.0）
  final double ambientSoundVolume;

  /// お手玉スポーン位置X
  final double spawnX;

  /// お手玉スポーン位置Y
  final double spawnY;

  /// ステージオブジェクトのJSON配列
  final List<Map<String, dynamic>> objects;

  /// ステージ境界設定
  final StageBoundaries boundaries;

  const StageData({
    required this.level,
    required this.name,
    this.background,
    this.ambientSound,
    this.ambientSoundVolume = 0.5,
    required this.spawnX,
    required this.spawnY,
    required this.objects,
    this.boundaries = const StageBoundaries(),
  });

  /// JSONからStageDataを生成
  factory StageData.fromJson(Map<String, dynamic> json) {
    return StageData(
      level: (json['level'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Unnamed Stage',
      background: json['background'] as String?,
      ambientSound: json['ambientSound'] as String?,
      ambientSoundVolume:
          (json['ambientSoundVolume'] as num?)?.toDouble() ?? 0.5,
      spawnX: (json['spawnX'] as num?)?.toDouble() ?? 0.0,
      spawnY: (json['spawnY'] as num?)?.toDouble() ?? 5.0,
      objects: (json['objects'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      boundaries:
          StageBoundaries.fromJson(json['boundaries'] as Map<String, dynamic>?),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      'background': background,
      'ambientSound': ambientSound,
      'ambientSoundVolume': ambientSoundVolume,
      'spawnX': spawnX,
      'spawnY': spawnY,
      'objects': objects,
      'boundaries': boundaries.toJson(),
    };
  }

  /// JSON文字列に変換（整形済み）
  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  /// アセットからステージを読み込み
  static Future<StageData> loadFromAsset(String assetPath) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return StageData.fromJson(json);
  }

  /// 空のステージを作成
  factory StageData.empty({int? level, String? name, String? background}) {
    return StageData(
      level: level ?? 0,
      name: name ?? 'New Stage',
      background: background,
      spawnX: 0.0,
      spawnY: 5.0,
      objects: [],
    );
  }

  /// コピーして一部のフィールドを変更
  StageData copyWith({
    int? level,
    String? name,
    String? background,
    String? ambientSound,
    double? ambientSoundVolume,
    double? spawnX,
    double? spawnY,
    List<Map<String, dynamic>>? objects,
    StageBoundaries? boundaries,
  }) {
    return StageData(
      level: level ?? this.level,
      name: name ?? this.name,
      background: background ?? this.background,
      ambientSound: ambientSound ?? this.ambientSound,
      ambientSoundVolume: ambientSoundVolume ?? this.ambientSoundVolume,
      spawnX: spawnX ?? this.spawnX,
      spawnY: spawnY ?? this.spawnY,
      objects: objects ?? this.objects,
      boundaries: boundaries ?? this.boundaries,
    );
  }
}

/// ステージエントリ（一覧表示用）
class StageEntry {
  final int level;
  final String name;
  final String assetPath;

  const StageEntry({
    required this.level,
    required this.name,
    required this.assetPath,
  });
}

/// 利用可能なステージのレジストリ
/// 新しいステージを追加する場合はここに追加
class StageRegistry {
  /// 登録済みステージ一覧（レベル順）
  static const List<StageEntry> entries = [
    StageEntry(level: 1, name: 'ステージ1', assetPath: 'assets/stages/stage1.json'),
    StageEntry(level: 2, name: 'ステージ2', assetPath: 'assets/stages/stage2.json'),
  ];

  /// 全ステージを読み込み（レベル順）
  static Future<List<StageData>> loadAll() async {
    final result = <StageData>[];
    for (final entry in entries) {
      try {
        final stage = await StageData.loadFromAsset(entry.assetPath);
        result.add(stage);
      } catch (e) {
        // ファイルが見つからない場合はスキップ
      }
    }
    // レベル順にソート
    result.sort((a, b) => a.level.compareTo(b.level));
    return result;
  }

  /// エントリ一覧を取得（レベル順）
  static List<StageEntry> get sortedEntries {
    final sorted = List<StageEntry>.from(entries);
    sorted.sort((a, b) => a.level.compareTo(b.level));
    return sorted;
  }
}
