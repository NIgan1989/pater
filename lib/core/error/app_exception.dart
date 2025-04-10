/// Базовый класс для исключений приложения
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic data;
  final StackTrace? stackTrace;

  AppException(this.message, {
    this.code,
    this.data,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: [$code] $message';
}

/// Ошибка авторизации
class AuthException extends AppException {
  AuthException(super.message, {super.code = 'auth_error', super.data, super.stackTrace});
}

/// Ошибка сети
class NetworkException extends AppException {
  final int? statusCode;
  
  NetworkException(super.message, {
    this.statusCode,
    super.code = 'network_error',
    super.data,
    super.stackTrace,
  });
}

/// Ошибка валидации
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;
  
  ValidationException(super.message, {
    this.fieldErrors,
    super.code = 'validation_error',
    super.data,
    super.stackTrace,
  });
}

/// Ошибка доступа к данным
class DataException extends AppException {
  DataException(super.message, {super.code = 'data_error', super.data, super.stackTrace});
}

/// Ошибка бизнес-логики
class BusinessException extends AppException {
  BusinessException(super.message, {super.code = 'business_error', super.data, super.stackTrace});
} 