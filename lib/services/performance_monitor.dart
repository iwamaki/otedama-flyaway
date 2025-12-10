import 'logger_service.dart';

/// パフォーマンスモニター
/// フレームタイムを監視し、異常値を検出してログ出力
class PerformanceMonitor {
  PerformanceMonitor._();
  static final PerformanceMonitor instance = PerformanceMonitor._();

  /// 有効/無効
  bool enabled = true;

  /// フレームタイム履歴（直近N件）
  final List<double> _frameTimes = [];
  static const int _historySize = 60; // 約1秒分

  /// スパイク検出の閾値（秒）
  /// 60FPS = 16.67ms, 30FPS = 33.33ms
  double spikeThreshold = 0.025; // 25ms（40FPS以下でスパイク）

  /// 連続スパイク検出用
  int _consecutiveSpikes = 0;
  static const int _consecutiveSpikeThreshold = 3;

  /// 連続スパイク時のログ抑制（N回ごとにログ出力）
  static const int _spikeLogInterval = 30; // 約0.5秒ごと

  /// セクション計測用
  final Map<String, Stopwatch> _sectionTimers = {};
  final Map<String, List<double>> _sectionHistory = {};
  static const int _sectionHistorySize = 30;

  /// 統計情報
  double _totalTime = 0;
  int _frameCount = 0;
  double _maxFrameTime = 0;
  double _minFrameTime = double.infinity;

  /// 最後のレポート時刻
  DateTime _lastReportTime = DateTime.now();
  static const Duration _reportInterval = Duration(seconds: 5);

  /// フレーム更新を記録
  void recordFrame(double dt) {
    if (!enabled) return;

    _frameTimes.add(dt);
    if (_frameTimes.length > _historySize) {
      _frameTimes.removeAt(0);
    }

    _totalTime += dt;
    _frameCount++;
    if (dt > _maxFrameTime) _maxFrameTime = dt;
    if (dt < _minFrameTime) _minFrameTime = dt;

    // スパイク検出
    if (dt > spikeThreshold) {
      _consecutiveSpikes++;
      // 最初の連続スパイク検出時、またはその後は一定間隔でのみログ出力
      if (_consecutiveSpikes == _consecutiveSpikeThreshold ||
          (_consecutiveSpikes > _consecutiveSpikeThreshold &&
              _consecutiveSpikes % _spikeLogInterval == 0)) {
        _logSpike(dt);
      }
    } else {
      // スパイク終了時にログ出力
      if (_consecutiveSpikes >= _consecutiveSpikeThreshold) {
        logger.info(
          LogCategory.performance,
          'Spike ended after $_consecutiveSpikes frames',
        );
      }
      _consecutiveSpikes = 0;
    }

    // 定期レポート
    final now = DateTime.now();
    if (now.difference(_lastReportTime) > _reportInterval) {
      _logPeriodicReport();
      _lastReportTime = now;
    }
  }

  /// セクション計測開始
  void startSection(String name) {
    if (!enabled) return;
    _sectionTimers[name] ??= Stopwatch();
    _sectionTimers[name]!.reset();
    _sectionTimers[name]!.start();
  }

  /// セクション計測終了
  void endSection(String name) {
    if (!enabled) return;
    final timer = _sectionTimers[name];
    if (timer == null || !timer.isRunning) return;

    timer.stop();
    final elapsed = timer.elapsedMicroseconds / 1000.0; // ms

    _sectionHistory[name] ??= [];
    _sectionHistory[name]!.add(elapsed);
    if (_sectionHistory[name]!.length > _sectionHistorySize) {
      _sectionHistory[name]!.removeAt(0);
    }

    // セクションが異常に長い場合
    if (elapsed > spikeThreshold * 1000 * 0.5) {
      // 閾値の50%以上
      logger.warning(
        LogCategory.performance,
        'Slow section "$name": ${elapsed.toStringAsFixed(2)}ms',
      );
    }
  }

  /// スパイクをログ出力
  void _logSpike(double dt) {
    final fps = 1.0 / dt;
    final avgDt = _frameTimes.isNotEmpty
        ? _frameTimes.reduce((a, b) => a + b) / _frameTimes.length
        : dt;
    final avgFps = 1.0 / avgDt;

    logger.warning(
      LogCategory.performance,
      'Frame spike: ${(dt * 1000).toStringAsFixed(1)}ms '
      '(${fps.toStringAsFixed(0)}FPS), '
      'avg: ${(avgDt * 1000).toStringAsFixed(1)}ms '
      '(${avgFps.toStringAsFixed(0)}FPS), '
      'consecutive: $_consecutiveSpikes',
    );

    // セクション情報も出力
    _logSectionSummary();
  }

  /// 定期レポート
  void _logPeriodicReport() {
    if (_frameCount == 0) return;

    final avgDt = _totalTime / _frameCount;
    final avgFps = 1.0 / avgDt;

    logger.info(
      LogCategory.performance,
      'Performance: avg ${avgFps.toStringAsFixed(0)}FPS '
      '(${(avgDt * 1000).toStringAsFixed(1)}ms), '
      'min ${(1.0 / _maxFrameTime).toStringAsFixed(0)}FPS, '
      'max ${(1.0 / _minFrameTime).toStringAsFixed(0)}FPS, '
      'frames: $_frameCount',
    );

    // セクション情報も出力
    _logSectionSummary();

    // リセット
    _resetStats();
  }

  /// セクションサマリーをログ出力
  void _logSectionSummary() {
    if (_sectionHistory.isEmpty) return;

    final buffer = StringBuffer('Sections: ');
    for (final entry in _sectionHistory.entries) {
      if (entry.value.isEmpty) continue;
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      final max = entry.value.reduce((a, b) => a > b ? a : b);
      buffer.write('${entry.key}=${avg.toStringAsFixed(1)}ms(max:${max.toStringAsFixed(1)}), ');
    }
    logger.debug(LogCategory.performance, buffer.toString());
  }

  /// 統計リセット
  void _resetStats() {
    _totalTime = 0;
    _frameCount = 0;
    _maxFrameTime = 0;
    _minFrameTime = double.infinity;
  }

  /// 現在のFPSを取得
  double get currentFps {
    if (_frameTimes.isEmpty) return 0;
    final avgDt = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    return 1.0 / avgDt;
  }

  /// 現在の平均フレームタイム（ms）
  double get averageFrameTimeMs {
    if (_frameTimes.isEmpty) return 0;
    return (_frameTimes.reduce((a, b) => a + b) / _frameTimes.length) * 1000;
  }
}
