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
  final AccountManager _accountManager = AccountManager();

  AuthService({
    required firebase.FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required RoleManager roleManager,
    required SharedPreferences prefs,
  }) : _auth = auth,
       _firestore = firestore,
       _roleManager = roleManager,
       _prefs = prefs;

  // Фабричный метод для создания экземпляра с параметрами по умолчанию
  static Future<AuthService> instance() async {
    return AuthService(
      auth: firebase.FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      roleManager: await RoleManager.instance(),
      prefs: await SharedPreferences.getInstance(),
    );
  }

  // Синхронный фабричный конструктор для обратной совместимости
  factory AuthService.withDefaults() {
    return AuthService(
      auth: firebase.FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      roleManager: _getDefaultRoleManager(),
      prefs: _getDefaultPrefs(),
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

  bool get isAuthenticated => currentUser != null;
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
      // Поиск пользователя по номеру телефона в Firestore
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('phoneNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<domain.User?> signInWithPhoneNumber(String phoneNumber) async {
    try {
      final completer = Completer<domain.User?>();

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          try {
            final result = await _auth.signInWithCredential(credential);
            final user = UserAdapter.fromFirebase(result.user);
            completer.complete(user);
          } catch (e) {
            completer.completeError(e);
          }
        },
        verificationFailed: (e) {
          completer.completeError(e);
        },
        codeSent: (verificationId, resendToken) {
          _prefs.setString('verificationId', verificationId);
          completer.complete(null);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      );

      return await completer.future;
    } catch (e) {
      rethrow;
    }
  }

  Future<domain.User?> verifyPhoneNumber(String smsCode) async {
    try {
      final verificationId = _prefs.getString('verificationId');
      if (verificationId == null) {
        throw Exception('Verification ID not found');
      }

      final credential = firebase.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final result = await _auth.signInWithCredential(credential);
      return UserAdapter.fromFirebase(result.user);
    } catch (e) {
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
    return await _accountManager.verifyPin(pin);
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
}
