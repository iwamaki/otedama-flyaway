import 'package:shared_preferences/shared_preferences.dart';

import '../config/otedama_skin_config.dart';

/// 設定の永続化サービス
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _skinIndexKey = 'otedama_skin_index';

  SharedPreferences? _prefs;

  /// 初期化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 選択中のスキンインデックスを取得
  int get selectedSkinIndex {
    return _prefs?.getInt(_skinIndexKey) ?? 0;
  }

  /// 選択中のスキンを取得
  OtedamaSkin get selectedSkin {
    return OtedamaSkinConfig.getSkinByIndex(selectedSkinIndex);
  }

  /// スキンインデックスを保存
  Future<void> setSkinIndex(int index) async {
    await _prefs?.setInt(_skinIndexKey, index);
  }

  /// スキンを保存（インデックスで）
  Future<void> setSkin(OtedamaSkin skin) async {
    final index = OtedamaSkinConfig.availableSkins.indexOf(skin);
    if (index >= 0) {
      await setSkinIndex(index);
    }
  }
}
