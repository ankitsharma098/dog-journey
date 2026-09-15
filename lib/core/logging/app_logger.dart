import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Single [Logger] instance for the whole app. Every repository funnels
/// its Postgres/Supabase Auth calls through this instead of bare
/// `print`/`debugPrint`, so log output is structured, leveled, and easy
/// to filter — and release builds don't get flooded with a line for
/// every successful read/write.
abstract final class AppLogger {
  static final Logger _logger = Logger(
    level: kReleaseMode ? Level.warning : Level.debug,
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      colors: !kReleaseMode,
      printEmojis: !kReleaseMode,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);

  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
