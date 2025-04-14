import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/auth/account_manager.dart';
import 'package:pater/core/auth/role_manager.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';
import 'package:pater/core/di/service_locator.dart';

/// Экран авторизации с помощью PIN-кода
class PinAuthScreen extends StatefulWidget {
  /// Данные для PIN-авторизации
  final Map<String, dynamic> pinData;

  /// Создает экземпляр [PinAuthScreen]
  const PinAuthScreen({super.key, required this.pinData});

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> {
  final _pinController = TextEditingController();
  late final AuthService _authService;
  late final AccountManager _accountManager;
  late final RoleManager _roleManager;

  late String _userId;
  late String _userName = '';
  String? _avatarUrl;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  int _attempts = 0;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();

    // Инициализируем сервисы через GetIt
    _authService = getIt<AuthService>();
    _accountManager = getIt<AccountManager>();
    _roleManager = getIt<RoleManager>();

    // Получаем параметры, переданные через конструктор или загружаем из SharedPreferences
    _loadUserInfo();
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Безопасная очистка контроллера перед его уничтожением
    try {
      if (!_isDisposed && _pinController.text.isNotEmpty) {
        _pinController.clear();
      }
      if (!_isDisposed) {
        _pinController.dispose();
      }
    } catch (e) {
      debugPrint('Ошибка при очистке контроллера PIN: $e');
    }

    super.dispose();
  }

  /// Загружает информацию о пользователе и попытках входа
  Future<void> _loadUserInfo() async {
    try {
      _userId = widget.pinData['userId'] ?? '';

      if (_userId.isEmpty) {
        if (mounted) {
          context.go('/auth');
        }
        return;
      }

      // Загружаем данные пользователя из Firestore для гарантии актуальности
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .get();

        if (!mounted) return;

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';

          _userName = firstName;
          if (lastName.isNotEmpty) {
            _userName += ' $lastName';
          }

          _avatarUrl = userData['avatarUrl'];

          // Если имя все еще пустое, используем данные из AccountManager
          if (_userName.isEmpty) {
            final prefs = await SharedPreferences.getInstance();
            _userName = prefs.getString('user_display_name') ?? 'Пользователь';
          }
        } else {
          // Если документ не найден в Firestore, используем имя из SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          _userName = prefs.getString('user_display_name') ?? 'Пользователь';
        }
      } catch (e) {
        debugPrint('Ошибка при загрузке данных пользователя из Firestore: $e');

        if (!mounted) return;

        // При ошибке используем данные из SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        _userName = prefs.getString('user_display_name') ?? 'Пользователь';
      }

      // Загружаем текущее количество попыток входа
      final prefs = await SharedPreferences.getInstance();
      _attempts = prefs.getInt('pin_auth_attempts') ?? 0;

      debugPrint('Пользователь $_userName загружен для авторизации по PIN');
    } catch (e) {
      debugPrint('Ошибка при загрузке данных пользователя: $e');
    }
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.length != 4) {
      setState(() {
        _errorMessage = 'Введите 4-значный PIN-код';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pinCode = _pinController.text;

      // Проверяем PIN-код
      final isValid = await _authService.checkPinCode(pinCode);

      if (!mounted) return;

      if (!isValid) {
        _attempts++;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('pin_auth_attempts', _attempts);

        if (_attempts >= _maxAttempts) {
          await prefs.setBool('skip_pin_auth', true);
          if (mounted) {
            context.go('/auth');
          }
          return;
        }
        throw Exception('Неверный PIN-код');
      }

      // Выполняем вход
      final success = await _authService.signInWithPinCode(pinCode);

      if (!mounted) return;

      if (!success) {
        throw Exception('Ошибка при входе в систему');
      }

      // Сбрасываем счетчик попыток
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pin_auth_attempts', 0);

      // Сохраняем данные аккаунта в AccountManager
      try {
        // Получаем текущего пользователя
        final user = _authService.currentUser;
        if (user != null) {
          // Создаем аккаунт, если его еще нет в системе
          final accountExists = await _accountManager.accountExists(user.id);

          if (!accountExists) {
            await _accountManager.createAccount(
              user.id,
              user.role.toString().split('.').last,
            );
          }

          // Создаем объект аккаунта для установки как последнего использованного
          final accounts = await _accountManager.loadAccounts();
          final account = accounts.firstWhere(
            (a) =>
                a['id'] == user.id &&
                a['role'] == user.role.toString().split('.').last,
            orElse: () => throw Exception('Аккаунт не найден'),
          );

          // Устанавливаем последний использованный аккаунт
          await _accountManager.setLastAccount(account['id']);

          // Проверяем, есть ли у пользователя разные роли
          final userRoles = await _roleManager.getUserRoles(user.id);

          // Устанавливаем активную роль
          if (userRoles.contains(user.role)) {
            await _roleManager.setActiveRole(user.role);
          } else if (userRoles.isNotEmpty) {
            // Если текущая роль пользователя не совпадает с сохраненными ролями,
            // устанавливаем первую доступную роль как активную
            await _roleManager.setActiveRole(userRoles.first);
          }
        }
      } catch (e) {
        debugPrint('Ошибка при сохранении данных аккаунта: $e');
        // Продолжаем вход даже если не удалось сохранить данные аккаунта
      }

      if (!mounted) return;

      // Переходим на домашнюю страницу
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: CustomAppBar(title: 'PIN-код', isAuthScreen: true),
      body: Stack(
        children: [
          // Фоновое изображение
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.4,
            child: Container(
              decoration: BoxDecoration(
                color: AppConstants.darkBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: size.height * 0.12,
                    left: 0,
                    right: 0,
                    child: const Center(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    top: size.height * 0.22,
                    left: 0,
                    right: 0,
                    child: const Center(
                      child: Text(
                        "PIN-код",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Основной контент
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.3),

                    // Карточка ввода PIN-кода
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Информация о пользователе
                          if (_userName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  // Аватар или иконка пользователя
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withAlpha(30),
                                      shape: BoxShape.circle,
                                    ),
                                    child:
                                        _avatarUrl != null
                                            ? ClipOval(
                                              child: Image.network(
                                                _avatarUrl!,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) => Icon(
                                                      Icons.person,
                                                      size: 24,
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .primary,
                                                    ),
                                              ),
                                            )
                                            : Icon(
                                              Icons.person,
                                              size: 24,
                                              color: theme.colorScheme.primary,
                                            ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Имя пользователя
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _userName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'Введите PIN-код для входа',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withAlpha(180),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Поле ввода PIN-кода
                          TextFormField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'PIN-код',
                              hintText: 'Введите 4 цифры',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Кнопка подтверждения
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyPin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.darkBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Text(
                                        'ПОДТВЕРДИТЬ',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                            ),
                          ),

                          // Кнопка возврата на экран выбора аккаунта
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Center(
                              child: TextButton(
                                onPressed: () => context.go('/'),
                                child: const Text(
                                  'Выбрать другой аккаунт',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
