import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

/// JSONパース用のエクステンションメソッド
extension JsonHelpers on Map<String, dynamic> {
  /// double値を取得（型安全）
  double getDouble(String key, [double defaultValue = 0.0]) {
    return (this[key] as num?)?.toDouble() ?? defaultValue;
  }

  /// int値を取得（型安全）
  int getInt(String key, [int defaultValue = 0]) {
    return (this[key] as num?)?.toInt() ?? defaultValue;
  }

  /// String値を取得（型安全）
  String getString(String key, [String defaultValue = '']) {
    return this[key] as String? ?? defaultValue;
  }

  /// bool値を取得（型安全）
  bool getBool(String key, [bool defaultValue = false]) {
    return this[key] as bool? ?? defaultValue;
  }

  /// Color値を取得（型安全）
  Color getColor(String key, [Color defaultValue = Colors.grey]) {
    final value = this[key];
    if (value == null) return defaultValue;
    return Color(value as int);
  }

  /// Vector2を取得（x, yキーから）
  Vector2 getVector2({
    String xKey = 'x',
    String yKey = 'y',
    double defaultX = 0.0,
    double defaultY = 0.0,
  }) {
    return Vector2(
      getDouble(xKey, defaultX),
      getDouble(yKey, defaultY),
    );
  }
}
