import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/auth/account_manager.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _authService = GetIt.instance.get<AuthService>();
  final _accountManager = GetIt.instance.get<AccountManager>();

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
      final userExists = await _authService.checkUserExistsByPhone(phoneNumber);

      // Для входа проверяем, что пользователь существует
      if (!userExists) {
        throw Exception('Пользователь с таким номером телефона не найден');
      }

      // Получаем ID пользователя напрямую из Firestore по номеру телефона
      String userId = '';
      try {
        // Нормализуем номер телефона
        String normalizedPhone = phoneNumber.replaceAll(
          RegExp(r'[\s\(\)\-]'),
          '',
        );
        if (normalizedPhone.startsWith('+')) {
          normalizedPhone = normalizedPhone.substring(1);
        }

        // Поиск пользователя в Firestore
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where('phoneNumber', isEqualTo: normalizedPhone)
                .limit(1)
                .get();

        if (querySnapshot.docs.isNotEmpty) {
          userId = querySnapshot.docs.first.id;
          debugPrint('Найден ID пользователя в Firestore: $userId');

          // Сохраняем ID для использования в других экранах
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
          await prefs.setString('temp_user_id', userId);
        } else {
          // Альтернативный поиск по другому полю
          final altQuery =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('phone_number', isEqualTo: normalizedPhone)
                  .limit(1)
                  .get();

          if (altQuery.docs.isNotEmpty) {
            userId = altQuery.docs.first.id;
            debugPrint(
              'Найден ID пользователя в Firestore (альтернативный поиск): $userId',
            );

            // Сохраняем ID
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_id', userId);
            await prefs.setString('temp_user_id', userId);
          } else {
            debugPrint('Пользователь не найден в Firestore по номеру телефона');
          }
        }
      } catch (e) {
        debugPrint('Ошибка при поиске пользователя в Firestore: $e');
      }

      // Отправляем SMS или создаем пользователя
      debugPrint('Пользователь существует, перенаправляем на экран PIN-кода');

      // Выполняем вход по номеру телефона без SMS
      final errorMessage = await _authService.signInWithPhoneNumber(
        phoneNumber,
      );

      if (errorMessage != null) {
        throw Exception(errorMessage);
      }

      // Получаем ID пользователя (используем уже найденный или запрашиваем из сервиса)
      userId = userId.isNotEmpty ? userId : (_authService.getUserId() ?? '');

      // Если ID все еще пустой, пробуем получить из SharedPreferences
      if (userId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        userId =
            prefs.getString('user_id') ?? prefs.getString('temp_user_id') ?? '';
        debugPrint('Используем ID пользователя из SharedPreferences: $userId');
      }

      // Проверяем, есть ли PIN-код
      final hasPinCode = _authService.hasPinCode();

      // Если PIN нет, устанавливаем временный
      if (!hasPinCode) {
        debugPrint(
          'У пользователя нет PIN-кода, перенаправляем на экран создания PIN-кода',
        );

        // Сохраним данные для экрана создания PIN
        final pinData = {
          'extra': {'userId': userId, 'phoneNumber': phoneNumber},
        };

        debugPrint('Передаем на экран создания PIN: userId=$userId');

        // Проверим, что контекст всё ещё привязан
        if (mounted) {
          context.push('/auth/create-pin', extra: pinData);
        }
        return;
      }

      // Создаем или обновляем аккаунт в системе мультиаккаунта
      try {
        final accountExists = await _accountManager.accountExists(userId);

        if (!accountExists) {
          // Получаем роль пользователя и преобразуем в строку
          final userRole = await _authService.getCurrentUserRole();
          final roleStr = userRole.toString().split('.').last;

          // Передаем id и строковое представление роли
          await _accountManager.createAccount(userId, roleStr);
          debugPrint('Создан новый аккаунт для пользователя $userId');
        } else {
          debugPrint('Аккаунт пользователя $userId уже существует');
        }
      } catch (e) {
        debugPrint('Ошибка при работе с аккаунтом: $e');
        // Продолжаем вход даже если не удалось сохранить данные аккаунта
      }

      // Сохраним данные для PIN-экрана
      final pinData = {
        'extra': {'userId': userId, 'phoneNumber': phoneNumber},
      };

      // Проверим, что контекст всё ещё привязан
      if (mounted) {
        context.push('/auth/pin', extra: pinData);
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
        actions: [],
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
                color: theme.primaryColor,
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
                    child: Center(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 70,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  Positioned(
                    top: size.height * 0.22,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        "ВХОД",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: theme.colorScheme.onPrimary,
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
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withAlpha(26),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Поле ввода телефона
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Номер телефона',
                                hintText: '+7 (___) ___-__-__',
                                prefixIcon: Icon(
                                  Icons.phone,
                                  color: theme.primaryColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.primaryColor,
                                    width: 2,
                                  ),
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
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child:
                                    _isLoading
                                        ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        )
                                        : Text(
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withAlpha(
                          178,
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
