import 'package:audioplayers/audioplayers.dart';

import 'logger_service.dart';

/// 効果音とBGM/環境音を管理するサービス
/// AudioPoolを使用して効率的に再生
class AudioService {
  AudioService._();
  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;

  bool _initialized = false;
  bool _enabled = true;
  bool _bgmEnabled = true;

  /// 効果音プレイヤー（再利用）
  final AudioPlayer _launchPlayer = AudioPlayer();
  final AudioPlayer _hitPlayer = AudioPlayer();
  final AudioPlayer _goalPlayer = AudioPlayer();
  final AudioPlayer _fallPlayer = AudioPlayer();

  /// BGM/環境音プレイヤー
  final AudioPlayer _bgmPlayer = AudioPlayer();

  /// 現在再生中のBGMパス
  String? _currentBgmPath;

  /// BGMの目標音量
  double _bgmTargetVolume = 0.5;

  /// フェード管理
  double _bgmCurrentVolume = 0.0;
  double _fadeStartVolume = 0.0;
  double _fadeEndVolume = 0.0;
  double _fadeElapsed = 0.0;
  double _fadeDuration = 0.0;
  bool _isFading = false;
  String? _pendingBgmPath;

  /// 効果音の有効/無効
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    logger.info(LogCategory.audio, 'Audio ${value ? "enabled" : "disabled"}');
  }

  /// BGMの有効/無効
  bool get bgmEnabled => _bgmEnabled;
  set bgmEnabled(bool value) {
    _bgmEnabled = value;
    if (!value) {
      _bgmPlayer.pause();
    } else if (_currentBgmPath != null) {
      _bgmPlayer.resume();
    }
    logger.info(LogCategory.audio, 'BGM ${value ? "enabled" : "disabled"}');
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
      await _launchPlayer.setSource(AssetSource('audio/effect/otedama_swipe.wav'));
      await _hitPlayer.setSource(AssetSource('audio/effect/otedama_landing.wav'));
      await _goalPlayer.setSource(AssetSource('audio/win.wav'));
      await _fallPlayer.setSource(AssetSource('audio/lose.wav'));

      // リリースモードを設定（再生後も保持）
      await _launchPlayer.setReleaseMode(ReleaseMode.stop);
      await _hitPlayer.setReleaseMode(ReleaseMode.stop);
      await _goalPlayer.setReleaseMode(ReleaseMode.stop);
      await _fallPlayer.setReleaseMode(ReleaseMode.stop);

      // BGMプレイヤーの設定（ループ再生）
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.0);

      _initialized = true;
      logger.info(LogCategory.audio, 'Audio service initialized');
    } catch (e) {
      logger.error(LogCategory.audio, 'Failed to initialize audio', error: e);
    }
  }

  /// フレーム更新（クールダウン管理、フェード処理）
  void update(double dt) {
    // 効果音クールダウン管理
    if (_hitCooldown > 0) _hitCooldown -= dt;
    if (_launchImmunity > 0) _launchImmunity -= dt;

    // BGMフェード処理
    if (_isFading && _fadeDuration > 0) {
      _fadeElapsed += dt;
      final progress = (_fadeElapsed / _fadeDuration).clamp(0.0, 1.0);

      // イーズアウト補間
      final easedProgress = 1.0 - (1.0 - progress) * (1.0 - progress);
      _bgmCurrentVolume =
          _fadeStartVolume + (_fadeEndVolume - _fadeStartVolume) * easedProgress;
      _bgmPlayer.setVolume(_bgmCurrentVolume);

      // フェード完了時のログ
      if (progress >= 1.0) {
        logger.info(LogCategory.audio, 'BGM fade complete: volume=$_bgmCurrentVolume');
        _isFading = false;
        _bgmCurrentVolume = _fadeEndVolume;

        // フェードアウト完了後、次のBGMがあれば再生開始
        if (_pendingBgmPath != null) {
          _startBgm(_pendingBgmPath!);
          _pendingBgmPath = null;
        } else if (_fadeEndVolume == 0.0 && _currentBgmPath != null) {
          // フェードアウト完了でBGM停止
          _bgmPlayer.stop();
          _currentBgmPath = null;
        }
      }
    }
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

  // ========== BGM/環境音メソッド ==========

  /// BGM/環境音を再生（クロスフェード対応）
  /// [assetPath] アセットパス（例: 'audio/environmental_sounds/morning_sparrows.mp3'）
  /// [volume] 音量（0.0〜1.0）
  /// [fadeDuration] フェード時間（秒）
  Future<void> playBgm(
    String assetPath, {
    double volume = 0.5,
    double fadeDuration = 1.0,
  }) async {
    if (!_initialized) return;

    _bgmTargetVolume = volume.clamp(0.0, 1.0);

    // 同じBGMが再生中なら何もしない
    if (_currentBgmPath == assetPath && !_isFading) {
      return;
    }

    logger.info(LogCategory.audio, 'Play BGM: $assetPath (volume: $volume)');

    // 現在BGMが再生中ならクロスフェード
    if (_currentBgmPath != null && _bgmCurrentVolume > 0) {
      _pendingBgmPath = assetPath;
      _startFade(0.0, fadeDuration);
    } else {
      // BGMがないので直接再生してフェードイン
      await _startBgm(assetPath);
      _startFade(_bgmTargetVolume, fadeDuration);
    }
  }

  /// BGMを停止（フェードアウト）
  Future<void> stopBgm({double fadeDuration = 1.0}) async {
    if (_currentBgmPath == null) return;

    logger.info(LogCategory.audio, 'Stop BGM with fade');
    _pendingBgmPath = null;
    _startFade(0.0, fadeDuration);
  }

  /// BGMを即時停止
  void stopBgmImmediate() {
    _bgmPlayer.stop();
    _currentBgmPath = null;
    _bgmCurrentVolume = 0.0;
    _isFading = false;
    _pendingBgmPath = null;
    logger.info(LogCategory.audio, 'BGM stopped immediately');
  }

  /// BGMを一時停止
  void pauseBgm() {
    _bgmPlayer.pause();
    logger.debug(LogCategory.audio, 'BGM paused');
  }

  /// BGMを再開
  void resumeBgm() {
    if (_currentBgmPath != null && _bgmEnabled) {
      _bgmPlayer.resume();
      logger.debug(LogCategory.audio, 'BGM resumed');
    }
  }

  /// 内部: BGMを開始
  Future<void> _startBgm(String assetPath) async {
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      // オーディオフォーカスを要求しない（他の音と共存）
      await _bgmPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
      await _bgmPlayer.setVolume(0.0);
      await _bgmPlayer.play(AssetSource(assetPath));
      _currentBgmPath = assetPath;
      _bgmCurrentVolume = 0.0;
      logger.debug(LogCategory.audio, 'BGM started: $assetPath');
    } catch (e) {
      logger.error(LogCategory.audio, 'Failed to start BGM: $assetPath', error: e);
    }
  }

  /// 内部: フェードを開始
  void _startFade(double targetVolume, double duration) {
    _fadeStartVolume = _bgmCurrentVolume;
    _fadeEndVolume = targetVolume;
    _fadeDuration = duration;
    _fadeElapsed = 0.0;
    _isFading = true;
  }

  /// リソース解放
  void dispose() {
    _launchPlayer.dispose();
    _hitPlayer.dispose();
    _goalPlayer.dispose();
    _fallPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
