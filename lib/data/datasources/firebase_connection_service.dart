import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pater/data/config/firebase_error_handler.dart';

/// Сервис для мониторинга и управления соединением с Firebase Firestore
class FirebaseConnectionService {
  static final FirebaseConnectionService _instance = FirebaseConnectionService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _connectionCheckTimer;
  bool _isMonitoring = false;
  bool _isConnected = true;
  DateTime? _lastCheckTime;
  final List<StreamSubscription> _subscriptions = [];
  
  factory FirebaseConnectionService() {
    return _instance;
  }
  
  FirebaseConnectionService._internal();
  
  /// Начинает мониторинг соединения
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _checkConnection();
    
    // Проверяем соединение каждые 30 секунд
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkConnection();
    });
  }
  
  /// Останавливает мониторинг соединения
  void stopMonitoring() {
    _isMonitoring = false;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    
    // Отписываемся от всех подписок
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
  
  /// Проверяет текущее состояние соединения
  Future<void> _checkConnection() async {
    if (!_isMonitoring) return;
    
    try {
      // Создаем тестовый документ локально
      final testDoc = _firestore.collection('connection_test').doc();
      
      // Пытаемся записать данные
      await testDoc.set({
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'mobile',
      });
      
      // Если запись прошла успешно, значит соединение есть
      _isConnected = true;
      _lastCheckTime = DateTime.now();
      
      // Удаляем тестовый документ
      await testDoc.delete();
      
      debugPrint('Соединение с Firebase установлено');
    } catch (e) {
      _isConnected = false;
      debugPrint('Ошибка соединения с Firebase: $e');
      
      // Обрабатываем ошибку через FirebaseErrorHandler
      FirebaseErrorHandler.handleError(e, context: 'Проверка соединения');
    }
  }
  
  /// Принудительно восстанавливает соединение
  Future<bool> forceReconnect({bool silent = false}) async {
    if (!silent) {
      debugPrint('Попытка принудительного восстановления соединения...');
    }
    
    try {
      // Останавливаем текущий мониторинг
      stopMonitoring();
      
      // Очищаем все подписки
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();
      
      // Сбрасываем настройки Firestore
      _firestore.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Проверяем соединение
      await _checkConnection();
      
      // Если соединение восстановлено, перезапускаем мониторинг
      if (_isConnected) {
        startMonitoring();
        if (!silent) {
          debugPrint('Соединение успешно восстановлено');
        }
        return true;
      }
      
      if (!silent) {
        debugPrint('Не удалось восстановить соединение');
      }
      return false;
    } catch (e) {
      if (!silent) {
        debugPrint('Ошибка при восстановлении соединения: $e');
      }
      return false;
    }
  }
  
  /// Возвращает текущее состояние соединения
  bool get isConnected => _isConnected;
  
  /// Возвращает время последней проверки соединения
  DateTime? get lastCheckTime => _lastCheckTime;
  
  /// Добавляет подписку для отслеживания
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }
  
  /// Удаляет подписку из отслеживания
  void removeSubscription(StreamSubscription subscription) {
    _subscriptions.remove(subscription);
  }
  
  /// Очищает все ресурсы
  void dispose() {
    stopMonitoring();
    _subscriptions.clear();
  }
} 