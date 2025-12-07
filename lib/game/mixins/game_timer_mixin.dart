import 'package:flame_forge2d/flame_forge2d.dart';

/// ゲームタイマー管理用Mixin
mixin GameTimerMixin on Forge2DGame {
  DateTime? _gameStartTime;
  DateTime? _gameEndTime;
  bool _timerStarted = false;
  double? _clearTime;

  /// タイマーが開始しているか
  bool get timerStarted => _timerStarted;

  /// クリアタイム（ゴール到達時の経過時間）
  double? get clearTime => _clearTime;

  /// ゲーム開始からの経過時間（秒）
  double get elapsedSeconds {
    if (_gameStartTime == null) return 0;
    final endTime = _gameEndTime ?? DateTime.now();
    return endTime.difference(_gameStartTime!).inMilliseconds / 1000;
  }

  /// タイマー開始
  void startTimer() {
    _timerStarted = true;
    _gameStartTime = DateTime.now();
    _gameEndTime = null;
    _clearTime = null;
  }

  /// タイマー停止（クリアタイム記録）
  void stopTimer() {
    _gameEndTime = DateTime.now();
    _clearTime = elapsedSeconds;
  }

  /// タイマーリセット
  void resetTimer() {
    _timerStarted = false;
    _gameStartTime = null;
    _gameEndTime = null;
    _clearTime = null;
  }
}
