enum LogLevel {
  info,
  warning,
  error,
}

class Logger {
  static void info(String message) {
    _log(LogLevel.info, message);
  }

  static void warning(String message) {
    _log(LogLevel.warning, message);
  }

  static void error(String message) {
    _log(LogLevel.error, message);
  }

  static void _log(LogLevel level, String message) {
    final timestamp = DateTime.now().toIso8601String().split('.')[0];
    final prefix = switch (level) {
      LogLevel.info => '🔵 INFO',
      LogLevel.warning => '⚠️ WARN',
      LogLevel.error => '❌ ERR ',
    };
    print('[$timestamp] $prefix $message');
  }
}
