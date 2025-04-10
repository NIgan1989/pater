import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Сервис для работы с сообщениями и чатами
class MessagingService {
  static final MessagingService _instance = MessagingService._internal();

  factory MessagingService() {
    return _instance;
  }

  MessagingService._internal();

  /// Ключ для временного хранения удаленного чата
  static const String _lastDeletedChatKey = 'last_deleted_chat';

  /// Сохраняет удаленный чат для возможности восстановления
  Future<bool> saveDeletedChat(Map<String, dynamic> chatData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatJson = json.encode(chatData);
      return await prefs.setString(_lastDeletedChatKey, chatJson);
    } catch (e) {
      debugPrint('Ошибка при сохранении удаленного чата: $e');
      return false;
    }
  }

  /// Получает последний удаленный чат
  Future<Map<String, dynamic>?> getLastDeletedChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatJson = prefs.getString(_lastDeletedChatKey);

      if (chatJson != null) {
        return json.decode(chatJson) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint('Ошибка при получении удаленного чата: $e');
      return null;
    }
  }

  /// Очищает данные о последнем удаленном чате
  Future<bool> clearLastDeletedChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_lastDeletedChatKey);
    } catch (e) {
      debugPrint('Ошибка при очистке данных удаленного чата: $e');
      return false;
    }
  }

  /// Создает чат с пользователем поддержки
  Future<String?> createSupportChat(String userId) async {
    try {
      // В реальной реализации, здесь будет создание чата через Firebase
      // Возвращаем ID чата с поддержкой
      return 'support_chat_$userId';
    } catch (e) {
      debugPrint('Ошибка при создании чата с поддержкой: $e');
      return null;
    }
  }
}
