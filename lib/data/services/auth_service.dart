import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:pater/domain/entities/user.dart';

class AuthService {
  final UserService _userService = UserService();
  User? _currentUser;
  String? _cachedUserId;

  // Геттер для получения текущего пользователя
  User? get currentUser => _currentUser;

  /// Получение ID текущего авторизованного пользователя
  Future<String> getCurrentUserId() async {
    // Сначала проверяем кэшированный ID
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) {
      debugPrint(
        'getCurrentUserId: возвращаем кэшированный userId = "$_cachedUserId"',
      );
      return _cachedUserId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var userId = prefs.getString('last_user_id') ?? '';
      debugPrint(
        'getCurrentUserId: получен userId из SharedPreferences = "$userId"',
      );

      // Если ID пустой, проверяем резервную копию
      if (userId.isEmpty) {
        final backupId = prefs.getString('userId_backup') ?? '';
        debugPrint('ID пустой, проверяем резервную копию: $backupId');

        if (backupId.isNotEmpty) {
          // Восстанавливаем из резервной копии
          userId = backupId;
          await prefs.setString('last_user_id', userId);
          debugPrint(
            'ID пользователя восстановлен из резервной копии: $userId',
          );
        }
      }

      // Кэшируем ID для повторного использования
      if (userId.isNotEmpty) {
        _cachedUserId = userId;

        // Если текущий пользователь ещё не загружен, но у нас есть ID
        if (_currentUser == null) {
          _loadCurrentUser(userId);
        }
      }

      return userId;
    } catch (e) {
      debugPrint('Ошибка при получении ID пользователя: $e');
      return '';
    }
  }

  /// Принудительно сохраняет ID пользователя
  Future<void> setUserId(String userId) async {
    try {
      if (userId.isEmpty) return;

      debugPrint('Сохраняем ID пользователя: $userId');

      // Сначала проверяем, не совпадает ли ID с кэшированным
      if (_cachedUserId == userId) {
        debugPrint('ID пользователя уже кэширован в памяти: $userId');
        return;
      }

      // Сохраняем в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_user_id', userId);
      _cachedUserId = userId;

      // Сохраняем резервную копию для надежности
      try {
        await prefs.setString('userId_backup', userId);
        debugPrint('Создана резервная копия ID пользователя');
      } catch (e) {
        debugPrint('Ошибка при создании резервной копии ID: $e');
      }

      // Загружаем данные пользователя
      await _loadCurrentUser(userId);

      // Проверяем успешность сохранения
      final savedId = prefs.getString('last_user_id');
      if (savedId == userId) {
        debugPrint('ID пользователя успешно сохранен в SharedPreferences');
      } else {
        debugPrint(
          'ВНИМАНИЕ: ID пользователя не сохранен: сохранено=$savedId, ожидалось=$userId',
        );
        // Пробуем еще раз
        await prefs.setString('last_user_id', userId);
      }
    } catch (e) {
      debugPrint('Ошибка при сохранении ID пользователя: $e');
    }
  }

  /// Загружает данные текущего пользователя
  Future<void> _loadCurrentUser(String userId) async {
    try {
      debugPrint('Загружаем данные пользователя по ID: $userId');
      final user = await _userService.getUserById(userId);

      if (user != null) {
        _currentUser = user;
        debugPrint('Пользователь ${user.fullName} загружен успешно');
      } else {
        debugPrint('Пользователь с ID: $userId не найден в базе данных');
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке данных пользователя: $e');
    }
  }

  /// Проверяет авторизован ли пользователь
  Future<bool> isUserLoggedIn() async {
    final userId = await getCurrentUserId();
    debugPrint(
      'isUserLoggedIn: userId = "$userId", currentUser = $_currentUser',
    );
    return userId.isNotEmpty;
  }
}
