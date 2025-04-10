import 'package:flutter/foundation.dart';
import 'package:pater/data/datasources/firebase_connection_service.dart';
import 'dart:async';

/// Обработчик ошибок Firebase для разных платформ
class FirebaseErrorHandler {
  // Счетчик ошибок офлайн-режима
  static int _offlineErrorCount = 0;
  
  // Таймер для предотвращения слишком частых вызовов восстановления
  static Timer? _reconnectThrottleTimer;
  
  // Время последней попытки восстановления
  static DateTime? _lastReconnectAttempt;
  
  // Время последнего лога ошибки для предотвращения спама
  static final Map<String, DateTime> _lastErrorLogTime = {};
  
  // Минимальный интервал между восстановлениями (в секундах)
  static const int _minReconnectIntervalSec = 30; // Увеличиваем до 30 секунд
  
  // Минимальный интервал между логами одинаковых ошибок (в секундах)
  static const int _minLogIntervalSec = 10;
  
  /// Обрабатывает и логирует ошибки Firebase
  static void handleError(Object error, {String? context}) {
    final errorMessage = error.toString();
    final source = context != null ? '[$context] ' : '';
    final errorType = _getErrorType(errorMessage);
    
    // Ограничиваем частоту логирования одинаковых ошибок
    if (!_shouldLogError(errorType)) {
      return;
    }
    
    // Обновляем время последнего лога для этого типа ошибки
    _lastErrorLogTime[errorType] = DateTime.now();
    
    // Обработка ошибок таймаута
    if (errorMessage.contains('TimeoutException') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('timed out')) {
      debugPrint('$source Ошибка таймаута: $errorMessage');
      _handleOfflineError('Timeout: $errorMessage', source);
      return;
    }
    
    // Обработка ошибок WebChannelConnection (jd) специальным образом
    if (errorMessage.contains('WebChannelConnection') || errorMessage.contains('jd')) {
      debugPrint('$source Ошибка WebChannel соединения: $errorMessage');
      // Используем более длительную задержку для WebChannel ошибок
      _tryForceReconnect(delay: const Duration(seconds: 30), isWebChannelError: true);
      return;
    }
    
    // Обработка ошибок офлайн-режима
    if (errorMessage.contains('offline') ||
        errorMessage.contains('client is offline') ||
        errorMessage.contains('unavailable') ||
        errorMessage.contains('network-request-failed')) {
      _handleOfflineError(errorMessage, source);
      return;
    }
    
    if (kIsWeb) {
      // Специфичные для веб-ошибки
      if (errorMessage.contains('cors') || 
          errorMessage.contains('CORS') || 
          errorMessage.contains('XMLHttpRequest') ||
          errorMessage.contains('Failed to fetch') ||
          errorMessage.contains('net::ERR')) {
        debugPrint('$source Ошибка CORS/сетевого подключения: $errorMessage');
        _tryForceReconnect(delay: const Duration(seconds: 10));
        return;
      }
      
      if (errorMessage.contains('QuotaExceededError') || 
          errorMessage.contains('quota') ||
          errorMessage.contains('storage')) {
        debugPrint('$source Ошибка квоты локального хранилища: $errorMessage');
        return;
      }
      
      if (errorMessage.contains('network') || 
          errorMessage.contains('Network')) {
        debugPrint('$source Сетевая ошибка: $errorMessage');
        _tryForceReconnect(delay: const Duration(seconds: 10));
        return;
      }
      
      if (errorMessage.contains('initialization') || 
          errorMessage.contains('init') ||
          errorMessage.contains('firebase-app') ||
          errorMessage.contains('SDK')) {
        debugPrint('$source Ошибка инициализации Firebase: $errorMessage');
        return;
      }

      // Обработка ошибок 400/403
      if (errorMessage.contains('400') || 
          errorMessage.contains('403') ||
          errorMessage.contains('PERMISSION_DENIED')) {
        debugPrint('$source Ошибка авторизации/доступа: $errorMessage');
        return;
      }
    }
    
    // Общие ошибки для всех платформ
    if (errorMessage.contains('permission-denied') || 
        errorMessage.contains('PERMISSION_DENIED')) {
      debugPrint('$source Ошибка доступа: $errorMessage');
      return;
    }
    
    if (errorMessage.contains('not-found') || 
        errorMessage.contains('NOT_FOUND')) {
      debugPrint('$source Ресурс не найден: $errorMessage');
      return;
    }
    
    // Другие ошибки логируем как есть
    debugPrint('$source Ошибка Firebase: $errorMessage');
  }
  
  /// Извлекает тип ошибки из сообщения для группировки похожих ошибок
  static String _getErrorType(String errorMessage) {
    if (errorMessage.contains('WebChannelConnection') || errorMessage.contains('jd')) {
      return 'webchannel';
    } else if (errorMessage.contains('TimeoutException') || errorMessage.contains('timeout')) {
      return 'timeout';
    } else if (errorMessage.contains('offline') || errorMessage.contains('unavailable')) {
      return 'offline';
    } else if (errorMessage.contains('CORS') || errorMessage.contains('cors')) {
      return 'cors';
    } else if (errorMessage.contains('permission') || errorMessage.contains('PERMISSION')) {
      return 'permission';
    } else {
      // Берем первые 20 символов как идентификатор типа ошибки
      return errorMessage.length > 20 ? errorMessage.substring(0, 20) : errorMessage;
    }
  }
  
  /// Проверяет, нужно ли логировать ошибку в зависимости от частоты повторения
  static bool _shouldLogError(String errorType) {
    final now = DateTime.now();
    
    // Если этот тип ошибки уже логировался недавно
    if (_lastErrorLogTime.containsKey(errorType)) {
      final lastTime = _lastErrorLogTime[errorType]!;
      final elapsedSeconds = now.difference(lastTime).inSeconds;
      
      // Пропускаем, если прошло меньше минимального интервала
      if (elapsedSeconds < _minLogIntervalSec) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Обрабатывает ошибки при инициализации Firebase
  static bool handleInitializationError(Object error) {
    handleError(error, context: 'Инициализация Firebase');
    
    // Если это критическая ошибка, которая не позволяет запустить приложение,
    // возвращаем false. В других случаях возвращаем true, чтобы продолжить.
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('fatal') || 
        errorString.contains('critical') || 
        errorString.contains('cannot proceed')) {
      return false;
    }
    
    // Если ошибка в веб-платформе, пытаемся восстановить соединение с задержкой
    if (kIsWeb) {
      _tryForceReconnect(delay: const Duration(seconds: 15));
    }
    
    return true;
  }
  
  /// Обработка ошибок офлайн-режима
  static void _handleOfflineError(String errorMessage, String source) {
    // Регулярно логировать только первые несколько ошибок, чтобы не засорять лог
    if (_offlineErrorCount < 3 || _offlineErrorCount % 20 == 0) {
      debugPrint('$source Ошибка офлайн-режима (${_offlineErrorCount + 1}): $errorMessage');
    }
    
    _offlineErrorCount++;
    
    // Попытка восстановления соединения каждые 5 ошибок с экспоненциальной задержкой
    if (_offlineErrorCount % 10 == 0) {
      // Увеличиваем задержку в зависимости от количества ошибок, но не более 60 секунд
      final delaySeconds = (_offlineErrorCount ~/ 10) * 5;
      final delay = Duration(seconds: delaySeconds.clamp(5, 60));
      _tryForceReconnect(delay: delay);
    }
  }
  
  /// Попытка принудительного восстановления соединения с защитой от частых вызовов
  static void _tryForceReconnect({
    Duration delay = const Duration(seconds: 2),
    bool isWebChannelError = false
  }) {
    // Проверяем, не слишком ли рано для следующей попытки
    final now = DateTime.now();
    if (_lastReconnectAttempt != null) {
      final sinceLastAttempt = now.difference(_lastReconnectAttempt!).inSeconds;
      if (sinceLastAttempt < _minReconnectIntervalSec) {
        // При WebChannel ошибках логируем сообщение реже
        if (!isWebChannelError || sinceLastAttempt < 5) {
          return;
        }
      }
    }
    
    // Отменяем предыдущий таймер, если он существует и активен
    _cancelReconnectTimer();
    
    // Устанавливаем таймер для предотвращения слишком частых вызовов
    _reconnectThrottleTimer = Timer(delay, () {
      // При WebChannel ошибках не выводим это сообщение, чтобы не спамить логи
      if (!isWebChannelError) {
        debugPrint('Запуск восстановления соединения после ${delay.inSeconds}с задержки');
      }
      
      // Обновляем время последней попытки
      _lastReconnectAttempt = DateTime.now();
      
      if (kIsWeb) {
        // При WebChannel ошибках используем тихое переподключение без логов
        FirebaseConnectionService().forceReconnect(silent: isWebChannelError).then((success) {
          if (success && !isWebChannelError) {
            debugPrint('Принудительное восстановление соединения успешно');
            _offlineErrorCount = 0;
          } else if (!success && !isWebChannelError) {
            debugPrint('Не удалось восстановить соединение');
          }
        });
      } else {
        // Для не-веб платформ просто сбрасываем счетчик ошибок
        // и полагаемся на встроенный механизм reconnect Firebase
        if (!isWebChannelError) {
          debugPrint('Сброс счетчика ошибок для не-веб платформы');
        }
        _offlineErrorCount = 0;
      }
    });
  }
  
  /// Отменяет таймер восстановления, если он активен
  static void _cancelReconnectTimer() {
    if (_reconnectThrottleTimer != null && _reconnectThrottleTimer!.isActive) {
      _reconnectThrottleTimer!.cancel();
      _reconnectThrottleTimer = null;
    }
  }
  
  /// Очищает все ресурсы - вызывать при завершении работы приложения
  static void dispose() {
    _cancelReconnectTimer();
    _offlineErrorCount = 0;
    _lastReconnectAttempt = null;
    _lastErrorLogTime.clear();
  }
} 