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
  late String _phoneNumber; // сохраняется для возможного использования в будущих обновлениях
  late bool _setupPin;
  late String _title;

  @override
  void initState() {
    super.initState();
    
    // Получаем данные, переданные с предыдущего экрана
    final Map<String, dynamic>? extra = widget.pinData['extra'] as Map<String, dynamic>?;
    _userId = extra?['userId'] as String? ?? '';
    _phoneNumber = extra?['phoneNumber'] as String? ?? '';
    _setupPin = extra?['setupPin'] as bool? ?? false;
    
    // Устанавливаем заголовок в зависимости от режима
    _title = _setupPin ? 'Установка PIN-кода' : 'Введите PIN-код';
    
    _authService = GetIt.instance<AuthService>();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _title,
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 70,
              color: Colors.blue,
            ),
            const SizedBox(height: 30),
            Text(
              _setupPin 
                  ? 'Создайте PIN-код для входа в приложение' 
                  : 'Введите PIN-код для доступа к аккаунту',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
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
                activeColor: Colors.blue,
                inactiveColor: Colors.blue.withAlpha(127),
                selectedColor: Colors.blue,
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
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
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
                style: const TextStyle(fontSize: 16, color: Colors.white),
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
      if (_setupPin) {
        // Режим установки нового PIN-кода
        await _authService.setPin(pin);
        
        if (!mounted) return;
        
        // Показываем сообщение об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN-код успешно установлен'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Продолжаем авторизацию
        context.go('/home');
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
          _errorMessage = 'Неверный PIN-код. Осталось попыток: ${_maxAttempts - _attempts}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка проверки PIN-кода: $e';
      });
    }
  }
}
