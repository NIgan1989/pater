import 'package:pater/core/error/app_exception.dart';
import 'package:pater/core/util/logger.dart';

/// Класс для обработки ошибок в приложении
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  
  ErrorHandler._internal();
  
  final AppLogger _logger = AppLogger();
  
  /// Обработка ошибок сетевых запросов
  AppException handleApiError(dynamic error) {
    if (error is AppException) {
      _logger.error('API Error: ${error.message}', error);
      return error;
    } else {
      final exception = NetworkException(
        'Неизвестная ошибка сети',
        data: error.toString(),
      );
      _logger.error('Unknown API Error', error);
      return exception;
    }
  }
  
  /// Обработка общих ошибок
  void handleGeneralError(dynamic error, {String message = 'Произошла ошибка'}) {
    if (error is AppException) {
      _logger.error('${error.message} (${error.code})', error, error.stackTrace);
    } else {
      _logger.error(message, error, error is Error ? error.stackTrace : null);
    }
  }
  
  /// Возвращает понятное сообщение для пользователя из исключения
  String getUserFriendlyMessage(dynamic error) {
    if (error is AuthException) {
      return 'Ошибка авторизации: ${error.message}';
    } else if (error is NetworkException) {
      return 'Проблема с сетью: ${error.message}';
    } else if (error is ValidationException) {
      return 'Ошибка валидации: ${error.message}';
    } else if (error is DataException) {
      return 'Ошибка с данными: ${error.message}';
    } else if (error is BusinessException) {
      return error.message;
    } else if (error is AppException) {
      return 'Ошибка приложения: ${error.message}';
    } else {
      return 'Произошла непредвиденная ошибка. Пожалуйста, попробуйте позже.';
    }
  }
} 