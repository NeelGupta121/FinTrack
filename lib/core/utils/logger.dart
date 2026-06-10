import 'dart:developer' as dev;

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static LogLevel _level = LogLevel.debug;
  static void setLevel(LogLevel level) => _level = level;

  static void debug(String message, {String? tag, Object? error}) =>
      _log(LogLevel.debug, message, tag: tag, error: error);

  static void info(String message, {String? tag, Object? error}) =>
      _log(LogLevel.info, message, tag: tag, error: error);

  static void warning(String message, {String? tag, Object? error}) =>
      _log(LogLevel.warning, message, tag: tag, error: error);

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);

  static void _log(LogLevel level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (level.index < _level.index) return;
    final prefix = '[${level.name.toUpperCase()}]${tag != null ? ' [$tag]' : ''}';
    dev.log('$prefix $message', error: error, stackTrace: stackTrace, name: 'FinTrack');
  }
}
