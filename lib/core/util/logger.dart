import 'package:flutter/foundation.dart';

/// Уровни логирования
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Класс для централизованного логирования в приложении
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  
  AppLogger._internal();
  
  /// Минимальный уровень логов для вывода
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  
  /// Установка минимального уровня логирования
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }
  
  /// Логирование отладочной информации
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.debug.index) {
      _log('DEBUG', message, error, stackTrace);
    }
  }
  
  /// Логирование информационных сообщений
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.info.index) {
      _log('INFO', message, error, stackTrace);
    }
  }
  
  /// Логирование предупреждений
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.warning.index) {
      _log('WARNING', message, error, stackTrace);
      // В реальном проекте можно добавить интеграцию с Crashlytics
      // _reportToCrashlytics(message, error, stackTrace, isFatal: false);
    }
  }
  
  /// Логирование ошибок
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.error.index) {
      _log('ERROR', message, error, stackTrace);
      // В реальном проекте можно добавить интеграцию с Crashlytics
      // _reportToCrashlytics(message, error, stackTrace, isFatal: false);
    }
  }
  
  /// Логирование критических ошибок
  void critical(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_minLevel.index <= LogLevel.critical.index) {
      _log('CRITICAL', message, error, stackTrace);
      // В реальном проекте можно добавить интеграцию с Crashlytics
      // _reportToCrashlytics(message, error, stackTrace, isFatal: true);
    }
  }
  
  /// Внутренний метод для форматированного вывода логов
  void _log(String level, String message, [dynamic error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final errorMsg = error != null ? ' | Error: $error' : '';
    final stackMsg = stackTrace != null ? '\n$stackTrace' : '';
    
    debugPrint('[$timestamp] $level: $message$errorMsg$stackMsg');
  }
  
  /// Для интеграции с Firebase Crashlytics (закомментировано для избежания ошибок компиляции)
  /*
  void _reportToCrashlytics(String message, dynamic error, StackTrace? stackTrace, {bool isFatal = false}) {
    try {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(
          error ?? message,
          stackTrace,
          reason: message,
          fatal: isFatal,
        );
      }
    } catch (e) {
      debugPrint('Ошибка при отправке в Crashlytics: $e');
    }
  }
  */
} 