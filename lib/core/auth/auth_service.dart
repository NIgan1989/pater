import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pater/domain/entities/user.dart' as domain;
import 'package:pater/core/auth/role_manager.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/core/auth/account_manager.dart';
import 'package:pater/core/auth/user_adapter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final RoleManager _roleManager;
  final SharedPreferences _prefs;
  final AccountManager _accountManager;

  AuthService({
    required FirebaseAuth auth,
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
      auth: FirebaseAuth.instance,
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
      auth: FirebaseAuth.instance,
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

      // Удаляем "+" если он есть в начале номера
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
        debugPrint('Номер без "+": $normalizedPhone');
      }

      // Создаем список всех возможных форматов номера
      // В том числе, пробуем варианты с кодом страны и без кода
      List<String> possibleFormats = [normalizedPhone];
      
      // Вариант без кода страны 7
      if (normalizedPhone.startsWith('7')) {
        possibleFormats.add(normalizedPhone.substring(1));
        debugPrint('Добавлен формат без кода страны: ${normalizedPhone.substring(1)}');
      }
      
      // Вариант с префиксом +
      possibleFormats.add('+$normalizedPhone');
      debugPrint('Добавлен формат с префиксом +: +$normalizedPhone');
      
      debugPrint('Поиск по возможным форматам: $possibleFormats');
      
      // Ищем по всем возможным полям в Firestore
      final fields = ['phoneNumber', 'phone_number'];
      
      for (final field in fields) {
        for (final format in possibleFormats) {
          final query = await _firestore
              .collection('users')
              .where(field, isEqualTo: format)
              .limit(1)
              .get();
              
          if (query.docs.isNotEmpty) {
            debugPrint('Пользователь найден в Firestore по полю $field со значением $format');
            return true;
          }
        }
      }
      
      // Если предыдущие проверки не сработали, пробуем whereIn
      for (final field in fields) {
        final query = await _firestore
            .collection('users')
            .where(field, whereIn: possibleFormats)
            .limit(1)
            .get();
            
        if (query.docs.isNotEmpty) {
          debugPrint('Пользователь найден в Firestore по полю $field с одним из форматов');
          return true;
        }
      }
      
      debugPrint('Пользователь не найден в Firestore');
      return false;
    } catch (e) {
      debugPrint('Ошибка при проверке существования пользователя: $e');
      return false;
    }
  }

  String? _verificationId;
  String? _phoneNumber;

  Future<String?> signInWithPhoneNumber(String phoneNumber) async {
    try {
      // Нормализуем номер телефона (удаляем пробелы, скобки, дефисы)
      String normalizedPhone = phoneNumber.replaceAll(
        RegExp(r'[\s\(\)\-]'),
        '',
      );
      debugPrint('Нормализованный номер для входа: $normalizedPhone');

      // Проверяем, существует ли пользователь с этим номером телефона
      bool userExists = await checkUserExistsByPhone(normalizedPhone);
      debugPrint('Пользователь существует: $userExists');

      if (!userExists) {
        // Если пользователя нет, информируем пользователя
        return 'Пользователь с таким номером телефона не найден';
      }

      // Очищаем предыдущий номер телефона
      _verificationId = null;
      _phoneNumber = null;

      // Сохраняем нормализованный номер в переменную экземпляра
      _phoneNumber = normalizedPhone;

      // Убедимся, что номер имеет правильный формат для Firebase Auth
      // Если номер не начинается с +, добавляем +
      String phoneNumberForAuth = normalizedPhone.startsWith('+') 
          ? normalizedPhone 
          : '+$normalizedPhone';

      debugPrint('Номер для Firebase Auth: $phoneNumberForAuth');

      // Отправляем SMS для верификации номера телефона
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumberForAuth,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Автоматическая верификация (только для Android)
          debugPrint('Автоматическая верификация');
          await _auth.signInWithCredential(credential);
          notifyListeners();
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Ошибка верификации: ${e.message}');
          throw Exception('Ошибка отправки СМС: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('СМС отправлено, ID верификации: $verificationId');
          _verificationId = verificationId;
          // Сохраняем ID верификации для использования в verifyPhoneNumber
          _prefs.setString('verificationId', verificationId);
          _prefs.setString('phoneNumberForAuth', phoneNumberForAuth);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Таймаут автоматического получения кода');
          _verificationId = verificationId;
          _prefs.setString('verificationId', verificationId);
        },
        timeout: const Duration(seconds: 60),
        // Указываем forceResendingToken: null
        forceResendingToken: null,
      );

      // Сообщаем, что верификация началась и пользователь должен ввести код из СМС
      return null;
    } catch (e) {
      debugPrint('Ошибка при входе с номером телефона: $e');
      return 'Ошибка при входе: $e';
    }
  }

  Future<domain.User?> verifyPhoneNumber(String smsCode) async {
    try {
      // Получаем сохраненный ID верификации
      final verificationId = _verificationId ?? _prefs.getString('verificationId');
      if (verificationId == null) {
        throw Exception('ID верификации не найден');
      }

      debugPrint('Верификация SMS кода');
      
      // Создаем учетные данные для аутентификации
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Авторизуемся с полученными данными
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        throw Exception('Ошибка авторизации');
      }
      
      // Получаем номер телефона из Firebase User или из сохраненного ранее
      String? phoneNumber = firebaseUser.phoneNumber ?? _phoneNumber ?? _prefs.getString('phoneNumberForAuth');
      if (phoneNumber == null || phoneNumber.isEmpty) {
        throw Exception('Номер телефона не найден');
      }
      
      debugPrint('Номер телефона после верификации: $phoneNumber');
      
      // Нормализуем номер для поиска в Firestore
      String normalizedPhone = phoneNumber.replaceAll(
        RegExp(r'[\s\(\)\-]'),
        '',
      );
      
      // Удаляем "+" если он есть в начале номера для поиска в Firestore
      if (normalizedPhone.startsWith('+')) {
        normalizedPhone = normalizedPhone.substring(1);
      }
      
      debugPrint('Нормализованный номер для поиска в Firestore: $normalizedPhone');
      
      // Создаем список возможных форматов для поиска
      List<String> possibleFormats = [
        normalizedPhone,
        '+$normalizedPhone',
      ];
      
      if (normalizedPhone.startsWith('7')) {
        possibleFormats.add(normalizedPhone.substring(1));
      }
      
      debugPrint('Поиск пользователя по возможным форматам: $possibleFormats');
      
      // Поиск пользователя в Firestore
      QuerySnapshot? existingUserQuery;
      String? userId;
      final fields = ['phoneNumber', 'phone_number'];
      
      // Проверяем каждый возможный формат номера в каждом поле
      for (final field in fields) {
        for (final format in possibleFormats) {
          final query = await _firestore
              .collection('users')
              .where(field, isEqualTo: format)
              .limit(1)
              .get();
              
          if (query.docs.isNotEmpty) {
            existingUserQuery = query;
            userId = query.docs.first.id;
            debugPrint('Найден пользователь по полю $field со значением $format, ID: $userId');
            break;
          }
        }
        
        if (existingUserQuery != null) break;
      }
      
      // Если пользователя не нашли через поля, пробуем whereIn
      if (existingUserQuery == null) {
        for (final field in fields) {
          final query = await _firestore
              .collection('users')
              .where(field, whereIn: possibleFormats)
              .limit(1)
              .get();
              
          if (query.docs.isNotEmpty) {
            existingUserQuery = query;
            userId = query.docs.first.id;
            debugPrint('Найден пользователь по полю $field с одним из форматов, ID: $userId');
            break;
          }
        }
      }

      // Если пользователь еще не существует, создаем его в Firestore
      if (existingUserQuery == null || existingUserQuery.docs.isEmpty) {
        debugPrint('Создаем нового пользователя в Firestore');

        // Используем Firebase Auth UID как ID пользователя
        userId = firebaseUser.uid;

        // Создаем документ пользователя
        await _firestore.collection('users').doc(userId).set({
          'phone_number': normalizedPhone,
          'phoneNumber': normalizedPhone,
          'first_name': 'Пользователь',
          'last_name': '',
          'email': '',
          'role': 'client',
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        debugPrint('Новый пользователь создан с ID: $userId');
      } else if (userId == null) {
        // Если не удалось найти ID пользователя, используем UID из Firebase
        userId = firebaseUser.uid;
        debugPrint('Используем Firebase UID как ID пользователя: $userId');
      }

      // Получаем информацию о пользователе из Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      String firstName = 'Пользователь';
      String lastName = '';
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          firstName = userData['first_name'] ?? userData['firstName'] ?? 'Пользователь';
          lastName = userData['last_name'] ?? userData['lastName'] ?? '';
        }
      }

      // Создаем объект пользователя
      final user = domain.User.simplified(
        id: userId,
        email: firebaseUser.email ?? '',
        firstName: firstName,
        lastName: lastName,
        phoneNumber: normalizedPhone,
        role: UserRole.client,
      );

      // Сохраняем данные пользователя локально
      await _prefs.setString('user_id', userId);
      await _prefs.setString('user_phone', normalizedPhone);
      await _prefs.setBool('is_authenticated', true);
      await _prefs.setString('last_auth_date', DateTime.now().toIso8601String());

      // Удаляем временные данные
      await _prefs.remove('verificationId');
      await _prefs.remove('phoneNumberForAuth');

      // Устанавливаем флаг для верификации по телефону
      await _prefs.setBool('verified_by_phone', true);
      
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
