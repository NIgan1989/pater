import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:get_it/get_it.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';

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

  late String _userId;
  late String _userName = '';

  String? _errorMessage;
  bool _isDisposed = false;

  int _attempts = 0;
  static const int _maxAttempts = 3;

  // ignore: unused_field
  late String
  _phoneNumber; // сохраняется для возможного использования в будущих обновлениях
  late bool _setupPin;
  late String _title;

  @override
  void initState() {
    super.initState();

    // Получаем данные, переданные с предыдущего экрана
    final Map<String, dynamic>? extra =
        widget.pinData['extra'] as Map<String, dynamic>?;
    _userId = extra?['userId'] as String? ?? '';
    _phoneNumber = extra?['phoneNumber'] as String? ?? '';
    _setupPin = extra?['setupPin'] as bool? ?? false;

    // Устанавливаем заголовок в зависимости от режима
    _title = _setupPin ? 'Установка PIN-кода' : 'Введите PIN-код';

    _authService = GetIt.instance<AuthService>();

    debugPrint(
      'PinAuthScreen: userId=$_userId, setupPin=$_setupPin, phoneNumber=$_phoneNumber',
    );

    // Если указан флаг setupPin, сохраняем ID пользователя для последующего использования
    if (_setupPin && _userId.isNotEmpty) {
      _saveUserId(_userId);
    }

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
      // Получаем ID из переданных данных
      _userId = widget.pinData['userId'] ?? '';

      // Получаем номер телефона для поиска пользователя
      _phoneNumber = widget.pinData['extra']?['phoneNumber'] as String? ?? '';

      debugPrint('Начальный _userId: $_userId, phoneNumber: $_phoneNumber');

      // Если ID пустой, пробуем получить из SharedPreferences
      if (_userId.isEmpty) {
        debugPrint(
          'ID пользователя пуст, пробуем получить из SharedPreferences',
        );
        final prefs = await SharedPreferences.getInstance();
        _userId =
            prefs.getString('user_id') ?? prefs.getString('temp_user_id') ?? '';

        if (_userId.isNotEmpty) {
          debugPrint('Получен ID пользователя из SharedPreferences: $_userId');
          // Сохраняем повторно для надежности
          await prefs.setString('user_id', _userId);
        }
      }

      // Если ID все еще пуст и флаг setupPin=true, пытаемся найти пользователя по номеру телефона
      if (_userId.isEmpty && _phoneNumber.isNotEmpty) {
        debugPrint(
          'Пытаемся найти пользователя по номеру телефона: $_phoneNumber',
        );

        // Нормализуем номер телефона
        String normalizedPhone = _phoneNumber.replaceAll(
          RegExp(r'[\s\(\)\-]'),
          '',
        );
        if (normalizedPhone.startsWith('+')) {
          normalizedPhone = normalizedPhone.substring(1);
        }

        debugPrint('Нормализованный номер телефона: $normalizedPhone');

        // Поиск пользователя в Firestore
        try {
          // Поиск по полю phoneNumber
          final querySnapshot =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('phoneNumber', isEqualTo: normalizedPhone)
                  .limit(1)
                  .get();

          if (querySnapshot.docs.isNotEmpty) {
            _userId = querySnapshot.docs.first.id;
            debugPrint('Найден ID пользователя в Firestore: $_userId');

            // Сохраняем ID
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_id', _userId);
            await prefs.setString('temp_user_id', _userId);
            await prefs.setString('last_user_id', _userId);
          } else {
            // Альтернативный поиск по phone_number
            final altQuery =
                await FirebaseFirestore.instance
                    .collection('users')
                    .where('phone_number', isEqualTo: normalizedPhone)
                    .limit(1)
                    .get();

            if (altQuery.docs.isNotEmpty) {
              _userId = altQuery.docs.first.id;
              debugPrint(
                'Найден ID пользователя в Firestore (альтернативно): $_userId',
              );

              // Сохраняем ID
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user_id', _userId);
              await prefs.setString('temp_user_id', _userId);
              await prefs.setString('last_user_id', _userId);
            } else {
              // Третья попытка - проверка с добавлением кода страны
              final thirdQuery =
                  await FirebaseFirestore.instance
                      .collection('users')
                      .where('phoneNumber', isEqualTo: '7$normalizedPhone')
                      .limit(1)
                      .get();

              if (thirdQuery.docs.isNotEmpty) {
                _userId = thirdQuery.docs.first.id;
                debugPrint('Найден ID пользователя с кодом страны: $_userId');

                // Сохраняем ID
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_id', _userId);
                await prefs.setString('temp_user_id', _userId);
                await prefs.setString('last_user_id', _userId);
              } else {
                debugPrint(
                  'Пользователь не найден в Firestore по номеру телефона',
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Ошибка при поиске пользователя в Firestore: $e');
        }
      }

      // Если после всех попыток ID все еще пуст и не в режиме установки PIN, возвращаемся на экран авторизации
      if (_userId.isEmpty && !_setupPin) {
        if (mounted) {
          debugPrint('ID пользователя не найден, возврат на экран авторизации');
          context.go('/auth');
        }
        return;
      }

      // Загружаем данные пользователя из Firestore для гарантии актуальности
      try {
        if (_userId.isNotEmpty) {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_userId)
                  .get();

          if (!mounted) return;

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final firstName =
                userData['firstName'] ?? userData['first_name'] ?? '';
            final lastName =
                userData['lastName'] ?? userData['last_name'] ?? '';

            _userName = firstName;
            if (lastName.isNotEmpty) {
              _userName += ' $lastName';
            }

            // Сохраняем данные пользователя для использования в других экранах
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_display_name', _userName);

            debugPrint(
              'Загружены данные пользователя $_userName с ID $_userId',
            );
          }
        }
      } catch (e) {
        debugPrint('Ошибка при загрузке данных пользователя из Firestore: $e');
      }

      // Загружаем текущее количество попыток входа
      final prefs = await SharedPreferences.getInstance();
      _attempts = prefs.getInt('pin_auth_attempts') ?? 0;
    } catch (e) {
      debugPrint('Ошибка при загрузке данных пользователя: $e');
    }
  }

  // Сохраняем идентификатор пользователя для восстановления сессии
  Future<void> _saveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('temp_user_id', userId);
      debugPrint('Сохранен ID пользователя: $userId');
    } catch (e) {
      debugPrint('Ошибка при сохранении ID пользователя: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(title: _title, showBackButton: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 70, color: theme.primaryColor),
            const SizedBox(height: 30),
            Text(
              _setupPin
                  ? 'Создайте PIN-код для входа в приложение'
                  : 'Введите PIN-код для доступа к аккаунту',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 30),
            PinCodeTextField(
              appContext: context,
              length: 4,
              obscureText: true,
              animationType: AnimationType.fade,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(5),
                fieldHeight: 50,
                fieldWidth: 40,
                activeFillColor: Colors.white,
                inactiveFillColor: Colors.white,
                selectedFillColor: Colors.white,
                activeColor: theme.primaryColor,
                inactiveColor: theme.primaryColor.withAlpha(127),
                selectedColor: theme.primaryColor,
              ),
              animationDuration: const Duration(milliseconds: 300),
              backgroundColor: Colors.transparent,
              enableActiveFill: true,
              controller: _pinController,
              onCompleted: (pin) {
                _verifyPin(pin);
              },
              onChanged: (value) {
                setState(() {
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: theme.primaryColor,
              ),
              onPressed: () {
                if (_pinController.text.length == 4) {
                  _verifyPin(_pinController.text);
                } else {
                  setState(() {
                    _errorMessage = 'Введите 4 цифры';
                  });
                }
              },
              child: Text(
                _setupPin ? 'Установить PIN-код' : 'Войти',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPin(String pin) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      // Если userId пустой, необходимо его найти перед продолжением
      if (_userId.isEmpty) {
        // Перезагружаем данные пользователя для поиска userId
        await _loadUserInfo();

        if (_userId.isEmpty) {
          throw Exception(
            'Невозможно продолжить без идентификатора пользователя',
          );
        }
      }

      if (_setupPin) {
        // Режим установки нового PIN-кода
        await _authService.setPin(pin);

        // Устанавливаем флаг авторизации
        await _forceAuthenticationState(true);

        if (!mounted) return;

        // Показываем сообщение об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN-код успешно установлен'),
            backgroundColor: Colors.green,
          ),
        );

        // Делаем небольшую задержку, чтобы изменения состояния успели примениться
        await Future.delayed(const Duration(milliseconds: 500));

        // Проверяем, что статус аутентификации установлен правильно
        final prefs = await SharedPreferences.getInstance();
        final isAuth = prefs.getBool('is_authenticated') ?? false;
        debugPrint(
          'Перед переходом: is_authenticated = $isAuth, userId = $_userId',
        );

        // Проверяем mounted перед использованием context
        if (!mounted) return;

        // Принудительно обновляем состояние аутентификации перед переходом
        await _authService.refreshAuthenticationState();

        // Продолжаем авторизацию
        if (mounted) {
          context.go('/home');
        }
        return;
      }

      // Проверяем количество попыток
      if (_attempts >= _maxAttempts) {
        setState(() {
          _errorMessage = 'Превышено количество попыток. Попробуйте позже.';
        });
        return;
      }

      // Режим проверки существующего PIN-кода
      final bool isValid = await _authService.signInWithPinCode(pin);

      if (!mounted) return;

      if (isValid) {
        // Устанавливаем флаг авторизации для уверенности
        await _forceAuthenticationState(true);

        // Делаем небольшую задержку
        await Future.delayed(const Duration(milliseconds: 500));

        // Принудительно обновляем состояние аутентификации перед переходом
        await _authService.refreshAuthenticationState();

        // Проверяем mounted перед использованием context
        if (!mounted) return;

        // Переходим на главный экран
        context.go('/home');
        return;
      } else {
        // Увеличиваем счетчик попыток
        _attempts++;

        // Сохраняем количество попыток
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('pin_auth_attempts', _attempts);

        setState(() {
          _errorMessage =
              'Неверный PIN-код. Осталось попыток: ${_maxAttempts - _attempts}';
        });
      }
    } catch (e) {
      // Проверяем mounted перед обновлением состояния
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Ошибка проверки PIN-кода: $e';
      });
    }
  }

  // Принудительно устанавливает состояние авторизации
  Future<void> _forceAuthenticationState(bool isAuthenticated) async {
    try {
      // Используем обновленный метод AuthService для установки состояния авторизации
      // Этот метод инкапсулирует всю логику работы с идентификатором пользователя
      bool success = await _authService.forceAuthenticationState(
        isAuthenticated,
      );

      // Проверяем результат после асинхронной операции
      if (!mounted) return;

      if (success) {
        debugPrint('Состояние авторизации успешно установлено');
      } else {
        debugPrint('Ошибка при установке состояния авторизации');

        // Обновляем UI при неудачной установке состояния
        setState(() {
          _errorMessage = 'Ошибка при установке состояния авторизации';
        });
      }
    } catch (e) {
      // Проверяем mounted перед обновлением UI
      if (!mounted) return;

      debugPrint('Ошибка при установке состояния авторизации: $e');

      // Обновляем UI при ошибке
      setState(() {
        _errorMessage = 'Ошибка авторизации: $e';
      });
    }
  }
}
