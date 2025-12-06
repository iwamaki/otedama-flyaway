import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// ログカテゴリ
enum LogCategory {
  /// ゲーム全般
  game('GAME'),

  /// 物理演算
  physics('PHYSICS'),

  /// UI関連
  ui('UI'),

  /// ステージ関連
  stage('STAGE'),

  /// オーディオ関連
  audio('AUDIO'),

  /// 入力関連
  input('INPUT'),

  /// システム関連
  system('SYSTEM');

  final String label;
  const LogCategory(this.label);
}

/// アプリケーションロガー
///
/// 使用例:
/// ```dart
/// final logger = AppLogger.instance;
/// logger.info(LogCategory.game, 'Game started');
/// logger.debug(LogCategory.physics, 'Velocity: $velocity');
/// logger.warning(LogCategory.stage, 'Stage not found');
/// logger.error(LogCategory.system, 'Failed to load', error: e);
/// ```
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  static AppLogger get instance => _instance;

  final Map<LogCategory, Logger> _loggers = {};

  /// デバッグモードかどうか（リリースビルドでは自動的にfalse）
  bool _debugMode = kDebugMode;

  /// 有効なカテゴリ（nullの場合は全て有効）
  Set<LogCategory>? _enabledCategories;

  /// 最小ログレベル
  Level _minimumLevel = Level.ALL;

  /// ログ履歴（デバッグ用）
  final List<LogRecord> _logHistory = [];
  static const int _maxHistorySize = 1000;

  /// ログ出力コールバック（カスタム出力用）
  void Function(LogRecord record)? onLog;

  AppLogger._internal() {
    _initializeLoggers();
  }

  void _initializeLoggers() {
    // 各カテゴリ用のロガーを作成
    for (final category in LogCategory.values) {
      final logger = Logger(category.label);
      _loggers[category] = logger;

      // ログ出力の設定
      logger.onRecord.listen(_handleLogRecord);
    }

    // ルートロガーのレベル設定
    Logger.root.level = _debugMode ? Level.ALL : Level.WARNING;
  }

  void _handleLogRecord(LogRecord record) {
    // 本番モードではWARNING以上のみ出力
    if (!_debugMode && record.level < Level.WARNING) {
      return;
    }

    // 最小レベル以下は無視
    if (record.level < _minimumLevel) {
      return;
    }

    // カテゴリフィルタ
    if (_enabledCategories != null) {
      final category = _getCategoryFromLoggerName(record.loggerName);
      if (category != null && !_enabledCategories!.contains(category)) {
        return;
      }
    }

    // 履歴に追加
    _logHistory.add(record);
    if (_logHistory.length > _maxHistorySize) {
      _logHistory.removeAt(0);
    }

    // コンソール出力
    _printLog(record);

    // カスタムコールバック
    onLog?.call(record);
  }

  LogCategory? _getCategoryFromLoggerName(String name) {
    for (final category in LogCategory.values) {
      if (category.label == name) {
        return category;
      }
    }
    return null;
  }

  void _printLog(LogRecord record) {
    final time = _formatTime(record.time);
    final level = _formatLevel(record.level);
    final message = '[$time] $level [${record.loggerName}] ${record.message}';

    if (record.error != null) {
      debugPrint('$message\n  Error: ${record.error}');
      if (record.stackTrace != null) {
        debugPrint('  StackTrace:\n${record.stackTrace}');
      }
    } else {
      debugPrint(message);
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  String _formatLevel(Level level) {
    if (level >= Level.SEVERE) return 'ERROR';
    if (level >= Level.WARNING) return 'WARN ';
    if (level >= Level.INFO) return 'INFO ';
    if (level >= Level.CONFIG) return 'CONF ';
    if (level >= Level.FINE) return 'DEBUG';
    return 'TRACE';
  }

  // ========== 設定メソッド ==========

  /// デバッグモードを設定
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    Logger.root.level = enabled ? Level.ALL : Level.WARNING;
  }

  /// 有効なカテゴリを設定（nullで全て有効）
  void setEnabledCategories(Set<LogCategory>? categories) {
    _enabledCategories = categories;
  }

  /// 特定のカテゴリを有効化
  void enableCategory(LogCategory category) {
    _enabledCategories ??= Set.from(LogCategory.values);
    _enabledCategories!.add(category);
  }

  /// 特定のカテゴリを無効化
  void disableCategory(LogCategory category) {
    _enabledCategories ??= Set.from(LogCategory.values);
    _enabledCategories!.remove(category);
  }

  /// 最小ログレベルを設定
  void setMinimumLevel(Level level) {
    _minimumLevel = level;
  }

  /// ログ履歴をクリア
  void clearHistory() {
    _logHistory.clear();
  }

  /// ログ履歴を取得
  List<LogRecord> getHistory({LogCategory? category, Level? minLevel}) {
    return _logHistory.where((record) {
      if (category != null) {
        final recordCategory = _getCategoryFromLoggerName(record.loggerName);
        if (recordCategory != category) return false;
      }
      if (minLevel != null && record.level < minLevel) {
        return false;
      }
      return true;
    }).toList();
  }

  // ========== ログ出力メソッド ==========

  /// 情報ログ
  void info(LogCategory category, String message) {
    _loggers[category]?.info(message);
  }

  /// デバッグログ
  void debug(LogCategory category, String message) {
    _loggers[category]?.fine(message);
  }

  /// 警告ログ
  void warning(LogCategory category, String message) {
    _loggers[category]?.warning(message);
  }

  /// エラーログ
  void error(
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _loggers[category]?.severe(message, error, stackTrace);
  }

  /// 設定ログ（初期化情報など）
  void config(LogCategory category, String message) {
    _loggers[category]?.config(message);
  }

  // ========== 便利メソッド ==========

  /// 現在の設定情報を出力
  void logCurrentSettings() {
    info(LogCategory.system, 'Logger Settings:');
    info(LogCategory.system, '  Debug mode: $_debugMode');
    info(LogCategory.system, '  Minimum level: $_minimumLevel');
    info(
        LogCategory.system,
        '  Enabled categories: ${_enabledCategories?.map((c) => c.label).join(', ') ?? 'ALL'}');
  }

  /// デバッグモードかどうか
  bool get isDebugMode => _debugMode;

  /// 有効なカテゴリ一覧
  Set<LogCategory>? get enabledCategories => _enabledCategories;
}

/// 簡易アクセス用のグローバルロガー
final logger = AppLogger.instance;
