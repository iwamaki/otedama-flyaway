import 'package:audioplayers/audioplayers.dart';

import 'logger_service.dart';

/// 効果音を管理するサービス
/// AudioPoolを使用して効率的に再生
class AudioService {
  AudioService._();
  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;

  bool _initialized = false;
  bool _enabled = true;

  /// 効果音プレイヤー（再利用）
  final AudioPlayer _launchPlayer = AudioPlayer();
  final AudioPlayer _hitPlayer = AudioPlayer();
  final AudioPlayer _goalPlayer = AudioPlayer();
  final AudioPlayer _fallPlayer = AudioPlayer();

  /// 効果音の有効/無効
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    logger.info(LogCategory.audio, 'Audio ${value ? "enabled" : "disabled"}');
  }

  /// 衝突音のクールダウン（連続再生を防ぐ）
  double _hitCooldown = 0;
  static const double _hitCooldownDuration = 0.15; // 150ms

  /// 発射後の衝突検出を無視する時間
  double _launchImmunity = 0;
  static const double _launchImmunityDuration = 0.1; // 100ms

  /// 初期化
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // プレイヤーを設定（アセットをセット）
      await _launchPlayer.setSource(AssetSource('audio/launch.wav'));
      await _hitPlayer.setSource(AssetSource('audio/hit.wav'));
      await _goalPlayer.setSource(AssetSource('audio/win.wav'));
      await _fallPlayer.setSource(AssetSource('audio/lose.wav'));

      // リリースモードを設定（再生後も保持）
      await _launchPlayer.setReleaseMode(ReleaseMode.stop);
      await _hitPlayer.setReleaseMode(ReleaseMode.stop);
      await _goalPlayer.setReleaseMode(ReleaseMode.stop);
      await _fallPlayer.setReleaseMode(ReleaseMode.stop);

      _initialized = true;
      logger.info(LogCategory.audio, 'Audio service initialized');
    } catch (e) {
      logger.error(LogCategory.audio, 'Failed to initialize audio', error: e);
    }
  }

  /// フレーム更新（クールダウン管理）
  void update(double dt) {
    // クールダウンがない場合は早期リターン
    if (_hitCooldown <= 0 && _launchImmunity <= 0) return;
    if (_hitCooldown > 0) _hitCooldown -= dt;
    if (_launchImmunity > 0) _launchImmunity -= dt;
  }

  /// 発射音を再生
  void playLaunch() {
    if (!_enabled || !_initialized) return;
    _launchPlayer.setVolume(0.7);
    _launchPlayer.seek(Duration.zero);
    _launchPlayer.resume();
    // 発射直後の衝突検出を無視
    _launchImmunity = _launchImmunityDuration;
    logger.debug(LogCategory.audio, 'Play: launch');
  }

  /// 衝突音を再生（衝撃の強さに応じて音量調整）
  void playHit({double intensity = 1.0}) {
    if (!_enabled || !_initialized) return;
    if (_hitCooldown > 0) return; // クールダウン中
    if (_launchImmunity > 0) return; // 発射直後は無視

    // 衝撃の強さを0.0-1.0にクランプ
    final clampedIntensity = intensity.clamp(0.0, 1.0);
    // 最小音量0.2、最大0.6
    final volume = 0.2 + clampedIntensity * 0.4;

    _hitPlayer.setVolume(volume);
    _hitPlayer.seek(Duration.zero);
    _hitPlayer.resume();
    _hitCooldown = _hitCooldownDuration;
  }

  /// ゴール音を再生
  void playGoal() {
    if (!_enabled || !_initialized) return;
    _goalPlayer.setVolume(0.8);
    _goalPlayer.seek(Duration.zero);
    _goalPlayer.resume();
    logger.info(LogCategory.audio, 'Play: goal');
  }

  /// 落下/リセット音を再生
  void playFall() {
    if (!_enabled || !_initialized) return;
    _fallPlayer.setVolume(0.5);
    _fallPlayer.seek(Duration.zero);
    _fallPlayer.resume();
    logger.debug(LogCategory.audio, 'Play: fall');
  }

  /// リソース解放
  void dispose() {
    _launchPlayer.dispose();
    _hitPlayer.dispose();
    _goalPlayer.dispose();
    _fallPlayer.dispose();
  }
}
