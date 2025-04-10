import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/auth/account_manager.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';
import 'dart:math' as math;

/// Экран авторизации в приложении
class AuthScreen extends StatefulWidget {
  /// Создает экземпляр [AuthScreen]
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  final _accountManager = AccountManager();

  bool _isLoading = false;
  String? _errorMessage;

  // Маска для ввода телефона в формате +7 (XXX) XXX-XX-XX
  final _maskFormatter = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Отправляет код подтверждения на указанный номер телефона
  Future<void> _sendSmsCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final phoneNumber = _phoneController.text.trim();
      debugPrint('Проверка номера телефона: $phoneNumber');

      // Проверяем, существует ли пользователь с таким номером
      final userInfo = await _authService.checkUserExistsByPhone(phoneNumber);
      final userExists = userInfo != null && userInfo['exists'] == true;

      if (userExists) {
        debugPrint('Пользователь существует, перенаправляем на экран PIN-кода');

        // Выполняем вход по номеру телефона без SMS
        final user = await _authService.signInByPhoneNumber(phoneNumber);

        if (user == null) {
          throw Exception('Ошибка при авторизации');
        }

        // Проверяем, есть ли PIN-код
        final hasPinCode = await _authService.hasPinCode(user.id);

        // Если PIN нет, устанавливаем временный
        if (!hasPinCode) {
          debugPrint(
            'У пользователя нет PIN-кода, устанавливаем временный случайный PIN-код',
          );
          // Генерируем случайный PIN-код вместо фиксированного значения
          final random = math.Random.secure();
          final tempPin = List.generate(4, (_) => random.nextInt(10)).join();

          final success = await _authService.savePinCode(user.id, tempPin);

          if (!success) {
            throw Exception('Ошибка при сохранении временного PIN-кода');
          }

          // Показываем временный PIN пользователю
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ваш временный PIN-код: $tempPin'),
              duration: const Duration(seconds: 10),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }

        // Создаем или обновляем аккаунт в системе мультиаккаунта
        try {
          final accountExists = await _accountManager.accountExists(
            user.id,
            user.role,
          );

          if (!accountExists) {
            await _accountManager.createAccount(user, user.role);
            debugPrint('Создан новый аккаунт для пользователя ${user.id}');
          } else {
            debugPrint('Аккаунт пользователя ${user.id} уже существует');
          }
        } catch (e) {
          debugPrint('Ошибка при работе с аккаунтом: $e');
          // Продолжаем вход даже если не удалось сохранить данные аккаунта
        }

        // Сохраним данные для PIN-экрана
        final pinData = {'userId': user.id, 'phoneNumber': user.phoneNumber};

        // Проверим, что контекст всё ещё привязан
        if (mounted) {
          context.push('/auth/pin', extra: pinData);
        }
      } else {
        debugPrint('Пользователь не существует, отправляем код SMS');

        // Отправляем SMS-код для нового пользователя
        await _authService.sendPhoneVerificationCode(
          phoneNumber,
          (String verificationId) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
            });

            // Переходим на экран ввода кода из SMS
            context.go(
              '/auth/sms',
              extra: {
                'phoneNumber': phoneNumber,
                'verificationId': verificationId,
                'isRegistration': true,
              },
            );
          },
          (String message) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
            });

            // Автоматически подтвержденный код
            context.go('/home');
          },
          (String errorMessage) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _errorMessage = errorMessage;
            });
          },
        );
      }
    } catch (e) {
      debugPrint('Ошибка при отправке кода: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'ВХОД',
        isAuthScreen: true,
        showBackButton: true,
        onBackPressed: () => context.go('/home'),
        actions: [
          TextButton(
            onPressed: () => context.go('/auth/register'),
            child: const Text('РЕГИСТРАЦИЯ'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Фоновое изображение в верхней части
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
                        "ВХОД",
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

                    // Карточка ввода номера
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Введите ваш номер телефона',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Поле ввода телефона
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Номер телефона',
                                hintText: '+7 (___) ___-__-__',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                errorText: _errorMessage,
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [_maskFormatter],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Пожалуйста, введите номер телефона';
                                }
                                if (value.length < 18) {
                                  // +7 (123) 456-78-90 = 18 символов
                                  return 'Введите полный номер телефона';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Кнопка входа
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _sendSmsCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child:
                                    _isLoading
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Text(
                                          'ВОЙТИ',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Текст о преимуществах авторизации
                    Text(
                      'Войдите, чтобы получить доступ ко всем функциям приложения',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withAlpha(
                          178, // 0.7 * 255 = 178
                        ),
                      ),
                    ),
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

/// Экран подтверждения SMS-кода
class SmsConfirmationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? forceResendingToken;

  const SmsConfirmationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.forceResendingToken,
  });

  @override
  State<SmsConfirmationScreen> createState() => SmsConfirmationScreenState();
}

class SmsConfirmationScreenState extends State<SmsConfirmationScreen> {
  // Add any necessary state variables here

  @override
  Widget build(BuildContext context) {
    // Implement the build method for the SmsConfirmationScreen
    return Scaffold(
      // Implement the layout for the SmsConfirmationScreen
    );
  }
}
