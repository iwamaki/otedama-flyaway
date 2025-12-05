import 'dart:convert';

import 'package:flutter/services.dart';

/// ステージデータモデル
/// JSONファイルからステージ情報を読み込み・保存する
class StageData {
  /// ステージレベル（表示順・識別用）
  final int level;

  /// ステージ名
  final String name;

  /// 背景画像パス（nullならデフォルト背景）
  final String? background;

  /// お手玉スポーン位置X
  final double spawnX;

  /// お手玉スポーン位置Y
  final double spawnY;

  /// ステージオブジェクトのJSON配列
  final List<Map<String, dynamic>> objects;

  const StageData({
    required this.level,
    required this.name,
    this.background,
    required this.spawnX,
    required this.spawnY,
    required this.objects,
  });

  /// JSONからStageDataを生成
  factory StageData.fromJson(Map<String, dynamic> json) {
    return StageData(
      level: (json['level'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Unnamed Stage',
      background: json['background'] as String?,
      spawnX: (json['spawnX'] as num?)?.toDouble() ?? 0.0,
      spawnY: (json['spawnY'] as num?)?.toDouble() ?? 5.0,
      objects: (json['objects'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'name': name,
      'background': background,
      'spawnX': spawnX,
      'spawnY': spawnY,
      'objects': objects,
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
    double? spawnX,
    double? spawnY,
    List<Map<String, dynamic>>? objects,
  }) {
    return StageData(
      level: level ?? this.level,
      name: name ?? this.name,
      background: background ?? this.background,
      spawnX: spawnX ?? this.spawnX,
      spawnY: spawnY ?? this.spawnY,
      objects: objects ?? this.objects,
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
