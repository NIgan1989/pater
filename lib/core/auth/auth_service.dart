import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:pater/domain/entities/user.dart' as domain;
import 'package:pater/core/auth/role_manager.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/core/auth/account_manager.dart';
import 'package:pater/core/auth/user_adapter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final firebase.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final RoleManager _roleManager;
  final SharedPreferences _prefs;
  final AccountManager _accountManager;

  AuthService({
    required firebase.FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required RoleManager roleManager,
    required SharedPreferences prefs,
    required AccountManager accountManager,
  }) : _auth = auth,
       _firestore = firestore,
       _roleManager = roleManager,
       _prefs = prefs,
       _accountManager = accountManager;

  // Фабричный метод для создания экземпляра с параметрами по умолчанию
  static Future<AuthService> instance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    AccountManager accountManager = AccountManager();
    return AuthService(
      auth: firebase.FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      roleManager: await RoleManager.instance(),
      prefs: prefs,
      accountManager: accountManager,
    );
  }

  // Синхронный фабричный конструктор для обратной совместимости
  factory AuthService.withDefaults() {
    SharedPreferences prefs = _getDefaultPrefs();
    AccountManager accountManager = AccountManager();
    return AuthService(
      auth: firebase.FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      roleManager: _getDefaultRoleManager(),
      prefs: prefs,
      accountManager: accountManager,
    );
  }

  // Временный метод для получения RoleManager
  static RoleManager _getDefaultRoleManager() {
    return RoleManager(
      firestore: FirebaseFirestore.instance,
      prefs: _getDefaultPrefs(),
    );
  }

  // Временный метод для получения SharedPreferences
  static SharedPreferences _getDefaultPrefs() {
    try {
      return SharedPreferences.getInstance() as SharedPreferences;
    } catch (e) {
      throw Exception(
        'Невозможно получить SharedPreferences: $e. Пожалуйста, используйте async метод instance() или GetIt.',
      );
    }
  }

  bool _isFirebaseInitialized = false;
  bool get isFirebaseInitialized => _isFirebaseInitialized;

  Stream<domain.User?> get userStream {
    return _auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return UserAdapter.fromFirebase(firebaseUser);
    });
  }

  domain.User? get currentUser {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return UserAdapter.fromFirebase(firebaseUser);
  }

  // Проверка аутентификации с учетом Firebase Auth и локальных данных
  bool get isAuthenticated {
    // Проверяем Firebase Auth пользователя
    if (currentUser != null) {
      return true;
    }

    // Проверяем локальный флаг аутентификации и наличие user_id
    try {
      bool isAuthByPin = _prefs.getBool('is_authenticated') ?? false;
      String? userId = _prefs.getString('user_id');

      if (isAuthByPin && userId != null && userId.isNotEmpty) {
        debugPrint(
          'Пользователь аутентифицирован по локальному флагу: $userId',
        );
        return true;
      }
    } catch (e) {
      debugPrint('Ошибка при проверке локального флага аутентификации: $e');
    }

    return false;
  }

  bool get isPinSet => _accountManager.isPinSet;

  // Инициализация сервиса
  Future<void> init() async {
    _isFirebaseInitialized = true;

    // Прослушивание изменений аутентификации
    _auth.authStateChanges().listen((firebaseUser) {
      if (firebaseUser != null) {
        notifyListeners();
      } else {
        notifyListeners();
      }
    });
  }

  // Восстановление сессии пользователя
  Future<bool> restoreUserSession() async {
    if (_auth.currentUser != null) {
      notifyListeners();
      return true;
    }
    return false;
  }

  // Восстановление сессии пользователя по ID
  Future<bool> restoreUserSessionById(String userId) async {
    try {
      // Здесь должен быть код для восстановления сессии по userId
      // Например, можно попытаться получить токен из хранилища и авторизоваться

      // В данной реализации просто проверяем, совпадает ли ID текущего пользователя
      if (_auth.currentUser != null && _auth.currentUser!.uid == userId) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Ошибка при восстановлении сессии пользователя: $e');
      return false;
    }
  }

  // Проверка и восстановление авторизации
  Future<bool> checkAndRestoreAuth() async {
    if (_auth.currentUser != null) {
      return await restoreUserSession();
    }
    return false;
  }

  // Возвращает ID текущего пользователя
  String? getUserId() {
    return currentUser?.id;
  }

  // Для совместимости с другими сервисами
  Future<String> getCurrentUserId() async {
    try {
      return getUserId() ?? '';
    } catch (e) {
      debugPrint('Ошибка при получении ID пользователя: $e');
      return '';
    }
  }

  // Проверка существования пользователя по номеру телефона
  Future<bool> checkUserExistsByPhone(String phoneNumber) async {
    try {
      // Добавляем дополнительное логирование
      debugPrint('Проверка пользователя с номером телефона: $phoneNumber');

      // Нормализуем номер телефона, удаляя все пробелы, скобки и дефисы
      String normalizedPhone = phoneNumber.replaceAll(
        RegExp(r'[\s\(\)\-]'),
        '',
      );
      debugPrint('Нормализованный номер телефона: $normalizedPhone');

      // Также пробуем вариант без кода страны, если номер начинается с +7
      String? phoneWithoutCode;
      if (normalizedPhone.startsWith('+7')) {
        phoneWithoutCode = normalizedPhone.substring(2); // Убираем +7
        debugPrint('Альтернативный номер без кода: $phoneWithoutCode');
      }

      // Поиск пользователя по номеру телефона в Firestore (проверяем оба варианта)
      final querySnapshot =
          await _firestore
              .collection('users')
              .where(
                'phone_number',
                whereIn: [
                  normalizedPhone,
                  if (phoneWithoutCode != null) phoneWithoutCode,
                ],
              )
              .limit(1)
              .get();

      bool userExists = querySnapshot.docs.isNotEmpty;
      debugPrint(
        'Пользователь ${userExists ? "найден" : "не найден"} в Firestore',
      );

      return userExists;
    } catch (e) {
      debugPrint('Ошибка при проверке существования пользователя: $e');
      return false;
    }
  }

  Future<domain.User?> signInWithPhoneNumber(String phoneNumber) async {
    try {
      // Проверяем наличие пользователя
      final userExists = await checkUserExistsByPhone(phoneNumber);
      debugPrint(
        'Статус проверки пользователя: ${userExists ? "Существует" : "Не существует"}',
      );

      // Нормализуем номер телефона для сохранения
      String normalizedPhone = phoneNumber.replaceAll(
        RegExp(r'[\s\(\)\-]'),
        '',
      );

      // Упрощенный метод без использования Firebase Auth
      debugPrint('Упрощенная авторизация без Firebase Auth');

      // Для существующего пользователя
      if (userExists) {
        debugPrint('Авторизация существующего пользователя');

        // Получаем данные пользователя из Firestore
        final querySnapshot =
            await _firestore
                .collection('users')
                .where('phone_number', isEqualTo: normalizedPhone)
                .limit(1)
                .get();

        if (querySnapshot.docs.isEmpty) {
          debugPrint(
            'Ошибка: пользователь существует, но не найден в Firestore',
          );
          throw Exception('Пользователь не найден');
        }

        // Получаем документ пользователя
        final userDoc = querySnapshot.docs.first;
        final userData = userDoc.data();
        final userId = userDoc.id;

        debugPrint('Получены данные пользователя с ID: $userId');

        // Создаем объект пользователя
        final user = domain.User.simplified(
          id: userId,
          email: userData['email'] as String? ?? '',
          firstName: userData['first_name'] as String? ?? 'Пользователь',
          lastName: userData['last_name'] as String? ?? '',
          phoneNumber: normalizedPhone,
          role: _parseRole(userData['role'] as String? ?? 'client'),
        );

        // Сохраняем данные пользователя локально
        await _prefs.setString('user_id', userId);
        await _prefs.setString('user_phone', normalizedPhone);

        // Уведомляем слушателей об изменении состояния
        notifyListeners();

        return user;
      } else {
        debugPrint('Симуляция отправки SMS кода для нового пользователя');

        // Генерируем временный ID для нового пользователя
        final tempUserId =
            'temp-user-${normalizedPhone.replaceAll(RegExp(r'[^0-9]'), '')}-${DateTime.now().millisecondsSinceEpoch}';

        // Сохраняем временный ID и номер телефона
        await _prefs.setString('temp_user_id', tempUserId);
        await _prefs.setString('temp_phone', normalizedPhone);

        // Сохраняем тестовый верификационный ID для последующей проверки SMS
        final verificationId = 'verification-$tempUserId';
        await _prefs.setString('verificationId', verificationId);

        // Имитируем отправку SMS
        await Future.delayed(const Duration(seconds: 1));

        // Сохраняем тестовый код для последующей проверки
        await _prefs.setString('sms_code', '123456');

        // Показываем тестовый код в консоли
        debugPrint('Тестовый SMS код: 123456');

        // Для новых пользователей возвращаем null, чтобы перейти к экрану ввода SMS
        return null;
      }
    } catch (e) {
      debugPrint('Ошибка в signInWithPhoneNumber: $e');
      rethrow;
    }
  }

  // Парсинг роли из строки
  UserRole _parseRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'cleaner':
        return UserRole.cleaner;
      case 'admin':
        return UserRole.admin;
      case 'support':
        return UserRole.support;
      case 'client':
      default:
        return UserRole.client;
    }
  }

  Future<domain.User?> verifyPhoneNumber(String smsCode) async {
    try {
      final verificationId = _prefs.getString('verificationId');
      if (verificationId == null) {
        throw Exception('Verification ID not found');
      }

      debugPrint('Проверка SMS кода: $smsCode');

      // Получаем сохраненный тестовый код
      final testSmsCode = _prefs.getString('sms_code') ?? '123456';
      debugPrint(
        'Сравнение кодов: введено "$smsCode", ожидалось "$testSmsCode"',
      );

      // Проверяем код
      if (smsCode != testSmsCode) {
        debugPrint('Неверный SMS код');
        throw Exception('Неверный SMS код');
      }

      // Получаем временный ID и номер телефона пользователя
      final tempUserId = _prefs.getString('temp_user_id');
      final userPhone = _prefs.getString('temp_phone');

      if (tempUserId == null || userPhone == null) {
        debugPrint(
          'Ошибка: не найдены данные пользователя в SharedPreferences',
        );
        throw Exception('Данные пользователя не найдены');
      }

      // Проверяем, существует ли уже пользователь с таким номером
      final existingUserQuery =
          await _firestore
              .collection('users')
              .where('phone_number', isEqualTo: userPhone)
              .limit(1)
              .get();

      String userId;

      // Если пользователь еще не существует, создаем его в Firestore
      if (existingUserQuery.docs.isEmpty) {
        debugPrint('Создаем нового пользователя в Firestore');

        // Генерируем уникальный ID для пользователя
        userId = 'user-${DateTime.now().millisecondsSinceEpoch}';

        // Создаем документ пользователя
        await _firestore.collection('users').doc(userId).set({
          'phone_number': userPhone,
          'first_name': 'Пользователь',
          'last_name': '',
          'email': '',
          'role': 'client',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        debugPrint('Новый пользователь создан с ID: $userId');
      } else {
        // Если пользователь существует, используем его ID
        userId = existingUserQuery.docs.first.id;
        debugPrint('Найден существующий пользователь с ID: $userId');
      }

      // Создаем объект пользователя
      final user = domain.User.simplified(
        id: userId,
        email: '',
        firstName: 'Пользователь',
        lastName: '',
        phoneNumber: userPhone,
        role: UserRole.client,
      );

      // Сохраняем данные пользователя локально
      await _prefs.setString('user_id', userId);
      await _prefs.setString('user_phone', userPhone);

      // Удаляем временные данные
      await _prefs.remove('temp_user_id');
      await _prefs.remove('temp_phone');
      await _prefs.remove('verificationId');
      await _prefs.remove('sms_code');

      // Уведомляем слушателей об изменении состояния
      notifyListeners();

      return user;
    } catch (e) {
      debugPrint('Ошибка в verifyPhoneNumber: $e');
      rethrow;
    }
  }

  // Установка PIN-кода
  Future<void> setPin(String pin) async {
    await _accountManager.setPin(pin);
    notifyListeners();
  }

  // Сохранение PIN-кода (для совместимости)
  Future<void> savePinCode(String pin) async {
    return setPin(pin);
  }

  // Проверка существования PIN-кода
  bool hasPinCode() {
    return isPinSet;
  }

  // Проверка PIN-кода
  Future<bool> verifyPin(String pin) async {
    debugPrint('Проверка PIN-кода: $pin');
    final result = await _accountManager.verifyPin(pin);
    debugPrint('Результат проверки PIN-кода: $result');
    return result;
  }

  // Для совместимости со старым кодом
  Future<bool> checkPinCode(String pin) async {
    return verifyPin(pin);
  }

  // Проверяет, находится ли объект в избранном у пользователя
  Future<bool> isPropertyInFavorites(String userId, String propertyId) async {
    try {
      final doc =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .doc(propertyId)
              .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Ошибка при проверке избранного: $e');
      return false;
    }
  }

  // Вход с использованием PIN-кода
  Future<bool> signInWithPinCode(String pin) async {
    bool isValid = await verifyPin(pin);

    if (isValid) {
      // Сохраняем состояние аутентификации
      await _prefs.setBool('is_authenticated', true);

      // Сохраняем дату последней авторизации
      await _prefs.setString(
        'last_auth_date',
        DateTime.now().toIso8601String(),
      );

      // Восстанавливаем сессию, если необходимо
      final userId = _prefs.getString('user_id');
      if (userId != null && _auth.currentUser == null) {
        await restoreUserSessionById(userId);
      }

      // Уведомляем об изменении состояния
      notifyListeners();
    }

    return isValid;
  }

  // Обновление роли пользователя
  Future<void> updateUserRole(String uid, UserRole newRole) async {
    // Преобразуем роль из domain в auth
    UserRole authRole;
    switch (newRole) {
      case UserRole.owner:
        authRole = UserRole.owner;
        break;
      case UserRole.cleaner:
        authRole = UserRole.cleaner;
        break;
      case UserRole.support:
        authRole = UserRole.admin;
        break;
      case UserRole.client:
      default:
        authRole = UserRole.client;
        break;
    }

    try {
      await _roleManager.changeUserRole(uid, authRole);
      if (currentUser != null && currentUser!.id == uid) {
        notifyListeners();
      }
      return;
    } catch (e) {
      rethrow;
    }
  }

  // Выход из аккаунта
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  // Получение текущей роли пользователя
  Future<UserRole> getCurrentUserRole() async {
    if (currentUser == null) return UserRole.client;

    UserRole authRole = await _roleManager.getUserRole(currentUser!.id);

    // Преобразуем роль из auth в domain
    switch (authRole) {
      case UserRole.owner:
        return UserRole.owner;
      case UserRole.cleaner:
        return UserRole.cleaner;
      case UserRole.admin:
        return UserRole.support;
      case UserRole.client:
      default:
        return UserRole.client;
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      final displayName = "$firstName $lastName".trim();
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(avatarUrl);

      // Обновляем данные в Firestore
      final userRef = _firestore.collection('users').doc(user.uid);
      await userRef.update({
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  Future<void> reloadUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  // Получить текущую роль пользователя
  Future<String> getCurrentUserRoleName() async {
    try {
      final userId = getUserId();
      if (userId == null) return 'Клиент';

      UserRole authRole = await _roleManager.getUserRole(userId);

      switch (authRole) {
        case UserRole.owner:
          return 'Владелец';
        case UserRole.cleaner:
          return 'Исполнитель';
        case UserRole.admin:
          return 'Администратор';
        case UserRole.client:
          return 'Клиент';
        case UserRole.support:
          return 'Поддержка';
      }
    } catch (e) {
      debugPrint('Ошибка при получении роли пользователя: $e');
      return 'Клиент';
    }
  }

  /// Принудительно обновить состояние аутентификации
  Future<void> forceAuthenticationState(bool isAuthenticated) async {
    debugPrint(
      'Принудительное обновление состояния аутентификации: $isAuthenticated',
    );

    await _prefs.setBool('is_authenticated', isAuthenticated);

    if (isAuthenticated) {
      // Если у нас есть ID пользователя, сохраняем его
      if (currentUser != null) {
        await _prefs.setString('user_id', currentUser!.id);
        debugPrint('Сохранен ID пользователя: ${currentUser!.id}');
      } else {
        // Если текущего пользователя нет, но есть ID в параметрах, используем его
        String? userId =
            _prefs.getString('last_user_id') ??
            _prefs.getString('temp_user_id');
        if (userId != null) {
          await _prefs.setString('user_id', userId);
          debugPrint('Сохранен временный ID пользователя: $userId');
        }
      }

      await _prefs.setString(
        'last_auth_date',
        DateTime.now().toIso8601String(),
      );
    } else {
      // При выходе из системы очищаем дополнительные данные
      await _prefs.remove('last_auth_date');
    }

    // Вызываем уведомление слушателей
    notifyListeners();

    debugPrint('Текущее состояние аутентификации: ${this.isAuthenticated}');
  }
}
