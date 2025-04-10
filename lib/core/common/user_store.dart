import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Хранилище данных текущего пользователя (синглтон)
class UserStore {
  static final UserStore _instance = UserStore._internal();
  String _userId = '';
  
  /// Конструктор
  factory UserStore() {
    return _instance;
  }
  
  UserStore._internal() {
    _initializeFromPrefs();
  }
  
  /// Инициализация из SharedPreferences
  Future<void> _initializeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('last_user_id') ?? '';
    } catch (e) {
      debugPrint('Ошибка при инициализации UserStore: $e');
    }
  }
  
  /// Идентификатор текущего пользователя
  String get userId => _userId;
  
  /// Установка идентификатора текущего пользователя
  set userId(String id) {
    _userId = id;
    _saveToPrefs();
  }
  
  /// Сохранение в SharedPreferences
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_user_id', _userId);
    } catch (e) {
      debugPrint('Ошибка при сохранении UserStore: $e');
    }
  }
} 