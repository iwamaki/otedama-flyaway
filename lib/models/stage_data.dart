import 'dart:convert';

import 'package:flutter/services.dart';

/// ステージデータモデル
/// JSONファイルからステージ情報を読み込み・保存する
class StageData {
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
    required this.name,
    this.background,
    required this.spawnX,
    required this.spawnY,
    required this.objects,
  });

  /// JSONからStageDataを生成
  factory StageData.fromJson(Map<String, dynamic> json) {
    return StageData(
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
  factory StageData.empty({String? name, String? background}) {
    return StageData(
      name: name ?? 'New Stage',
      background: background,
      spawnX: 0.0,
      spawnY: 5.0,
      objects: [],
    );
  }

  /// コピーして一部のフィールドを変更
  StageData copyWith({
    String? name,
    String? background,
    double? spawnX,
    double? spawnY,
    List<Map<String, dynamic>>? objects,
  }) {
    return StageData(
      name: name ?? this.name,
      background: background ?? this.background,
      spawnX: spawnX ?? this.spawnX,
      spawnY: spawnY ?? this.spawnY,
      objects: objects ?? this.objects,
    );
  }
}

/// 利用可能なステージのレジストリ
/// 新しいステージを追加する場合はここに追加
class StageRegistry {
  static const List<String> stages = [
    'assets/stages/stage1.json',
    // 新しいステージを追加:
    // 'assets/stages/stage2.json',
  ];

  /// 全ステージを読み込み
  static Future<List<StageData>> loadAll() async {
    final result = <StageData>[];
    for (final path in stages) {
      try {
        final stage = await StageData.loadFromAsset(path);
        result.add(stage);
      } catch (e) {
        // ファイルが見つからない場合はスキップ
      }
    }
    return result;
  }
}
