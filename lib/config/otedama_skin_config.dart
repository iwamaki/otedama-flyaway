import 'package:flutter/material.dart';

/// お手玉のスキン種別
enum OtedamaSkinType {
  /// 単色グラデーション（デフォルト）
  solidColor,

  /// テクスチャ画像
  texture,
}

/// お手玉のスキン設定
class OtedamaSkin {
  /// スキン名（表示用）
  final String name;

  /// スキン種別
  final OtedamaSkinType type;

  /// 単色スキン用のベースカラー
  final Color? baseColor;

  /// テクスチャスキン用のアセットパス
  final String? texturePath;

  /// 縁取りの色（nullの場合はbaseColorから自動生成）
  final Color? borderColor;

  /// 縫い目模様を表示するか
  final bool showStitchPattern;

  const OtedamaSkin._({
    required this.name,
    required this.type,
    this.baseColor,
    this.texturePath,
    this.borderColor,
    this.showStitchPattern = true,
  });

  /// 単色スキンを作成
  const OtedamaSkin.solid({
    required String name,
    required Color color,
    Color? borderColor,
    bool showStitchPattern = true,
  }) : this._(
          name: name,
          type: OtedamaSkinType.solidColor,
          baseColor: color,
          borderColor: borderColor,
          showStitchPattern: showStitchPattern,
        );

  /// テクスチャスキンを作成
  const OtedamaSkin.texture({
    required String name,
    required String assetPath,
    Color? borderColor,
    bool showStitchPattern = false,
  }) : this._(
          name: name,
          type: OtedamaSkinType.texture,
          texturePath: assetPath,
          borderColor: borderColor,
          showStitchPattern: showStitchPattern,
        );
}

/// お手玉スキンの設定管理
class OtedamaSkinConfig {
  /// 利用可能なスキン一覧
  static const List<OtedamaSkin> availableSkins = [
    // デフォルトの単色スキン
    OtedamaSkin.solid(
      name: '赤',
      color: Color(0xFFCC3333),
    ),
    OtedamaSkin.solid(
      name: '青',
      color: Color(0xFF3366CC),
    ),
    OtedamaSkin.solid(
      name: '緑',
      color: Color(0xFF33AA55),
    ),
    OtedamaSkin.solid(
      name: '紫',
      color: Color(0xFF9933CC),
    ),
    OtedamaSkin.solid(
      name: '橙',
      color: Color(0xFFDD6622),
    ),

    // テクスチャスキン
    OtedamaSkin.texture(
      name: '桜',
      assetPath: 'assets/texture/sakura.jpeg',
      borderColor: Color(0xFFFFB7C5),
    ),
  ];

  /// デフォルトのスキン
  static const OtedamaSkin defaultSkin = OtedamaSkin.solid(
    name: '赤',
    color: Color(0xFFCC3333),
  );

  /// 名前からスキンを取得
  static OtedamaSkin? getSkinByName(String name) {
    for (final skin in availableSkins) {
      if (skin.name == name) return skin;
    }
    return null;
  }

  /// インデックスからスキンを取得
  static OtedamaSkin getSkinByIndex(int index) {
    if (index < 0 || index >= availableSkins.length) {
      return defaultSkin;
    }
    return availableSkins[index];
  }
}
