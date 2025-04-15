import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class AccountManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPinSet = false;
  bool get isPinSet => _isPinSet;

  // Конструктор, который проверяет наличие PIN-кода
  AccountManager() {
    _checkPinExistence();
  }

  // Проверяет, установлен ли PIN-код
  Future<void> _checkPinExistence() async {
    if (_auth.currentUser == null) {
      _isPinSet = false;
      return;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _isPinSet = prefs.containsKey('pin_${_auth.currentUser!.uid}');
    } catch (e) {
      _isPinSet = false;
    }
  }

  // Проверяет, существует ли аккаунт с указанным ID
  Future<bool> accountExists(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Создает новый аккаунт в Firestore
  Future<void> createAccount(String uid, String role) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'role': role.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
        'hasPin': false,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Не удалось создать аккаунт: ${e.toString()}');
    }
  }

  // Загружает список аккаунтов пользователя
  Future<List<Map<String, dynamic>>> loadAccounts() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> accountIds = prefs.getStringList('accounts') ?? [];
      List<Map<String, dynamic>> accounts = [];

      for (String id in accountIds) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(id).get();
        if (doc.exists) {
          accounts.add({
            'id': id,
            'role': doc.get('role'),
            'name': doc.get('name') ?? 'Пользователь',
            'lastLogin': doc.get('lastLogin'),
          });
        }
      }

      return accounts;
    } catch (e) {
      return [];
    }
  }

  // Устанавливает последний использованный аккаунт
  Future<void> setLastAccount(String uid) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastAccount', uid);

      // Обновляем в Firestore lastLogin
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Добавляем ID в список аккаунтов, если его там нет
      List<String> accounts = prefs.getStringList('accounts') ?? [];
      if (!accounts.contains(uid)) {
        accounts.add(uid);
        await prefs.setStringList('accounts', accounts);
      }
    } catch (e) {
      // Игнорируем ошибку
    }
  }

  // Устанавливает PIN-код
  Future<void> setPin(String pin) async {
    if (_auth.currentUser == null) return;

    try {
      // Хеширование PIN-кода для безопасности
      String hashedPin = _hashPin(pin);

      // Сохранение в SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('pin_${_auth.currentUser!.uid}', hashedPin);

      // Сохранение метки в Firestore для проверки с других устройств
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'hasPin': true,
      });

      _isPinSet = true;
    } catch (e) {
      throw Exception('Не удалось установить PIN-код');
    }
  }

  // Проверка PIN-кода
  Future<bool> verifyPin(String pin) async {
    if (_auth.currentUser == null) {
      debugPrint('verifyPin: currentUser == null');
      // Альтернативная проверка PIN по последнему сохраненному пользователю
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? lastUserId = prefs.getString('user_id');

        if (lastUserId != null) {
          debugPrint(
            'verifyPin: используем последний сохраненный ID: $lastUserId',
          );
          String? storedPin = prefs.getString('pin_$lastUserId');

          if (storedPin == null) {
            debugPrint('verifyPin: для последнего ID нет сохраненного PIN');
            // Пробуем найти временный PIN
            storedPin = prefs.getString('temp_pin');
            debugPrint('verifyPin: временный PIN: ${storedPin != null}');
          }

          if (storedPin != null) {
            // Для временного PIN просто сравниваем значения
            if (storedPin == pin) {
              debugPrint('verifyPin: временный PIN совпал');
              return true;
            }

            // Для обычного PIN хешируем с солью
            var bytes = utf8.encode(pin + lastUserId);
            var digest = sha256.convert(bytes);
            String hashedPin = digest.toString();

            debugPrint('verifyPin: сравниваем хешированный PIN');
            return storedPin == hashedPin;
          }
        }
      } catch (e) {
        debugPrint('verifyPin: ошибка при альтернативной проверке: $e');
      }
      return false;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String uid = _auth.currentUser!.uid;
      debugPrint('verifyPin: проверка для пользователя $uid');

      String? storedPin = prefs.getString('pin_$uid');
      debugPrint('verifyPin: найден сохраненный PIN: ${storedPin != null}');

      if (storedPin == null) {
        // Пробуем найти временный PIN
        storedPin = prefs.getString('temp_pin');
        debugPrint('verifyPin: найден временный PIN: ${storedPin != null}');

        // Для временного PIN просто сравниваем значения
        if (storedPin != null && storedPin == pin) {
          debugPrint('verifyPin: временный PIN совпал');
          return true;
        }

        return false;
      }

      String hashedPin = _hashPin(pin);
      debugPrint('verifyPin: сравниваем хешированный PIN');
      return storedPin == hashedPin;
    } catch (e) {
      debugPrint('verifyPin: ошибка при проверке: $e');
      return false;
    }
  }

  // Сброс PIN-кода
  Future<void> resetPin() async {
    if (_auth.currentUser == null) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('pin_${_auth.currentUser!.uid}');

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'hasPin': false,
      });

      _isPinSet = false;
    } catch (e) {
      throw Exception('Не удалось сбросить PIN-код');
    }
  }

  // Хеширование PIN-кода
  String _hashPin(String pin) {
    var bytes = utf8.encode(pin + _auth.currentUser!.uid); // Добавляем соль
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
