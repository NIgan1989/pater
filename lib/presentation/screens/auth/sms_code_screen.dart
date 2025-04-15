import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/presentation/widgets/common/error_message.dart';
import 'package:pater/core/di/service_locator.dart';

/// Экран для ввода SMS-кода
class SmsCodeScreen extends StatefulWidget {
  /// ID верификации, полученный при отправке кода
  final String verificationId;

  /// Номер телефона, на который был отправлен код
  final String phoneNumber;

  const SmsCodeScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends State<SmsCodeScreen> {
  // Контроллер для ввода SMS-кода
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final AuthService _authService;

  String? _errorMessage;

  int _resendTimer = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _authService = getIt<AuthService>();
    _startResendTimer();
    _codeController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _resendTimer--;
        });

        if (_resendTimer > 0) {
          _startResendTimer();
        } else {
          setState(() {
            _canResend = true;
          });
        }
      }
    });
  }

  void _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      await _authService.signInWithPhoneNumber(widget.phoneNumber);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Код отправлен'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка: $e';
        });
      }
    }
  }

  // Метод для проверки SMS-кода
  void _verifyCode() async {
    // Получаем чистый код без пробелов
    final smsCode = _codeController.text.replaceAll(' ', '');

    if (smsCode.length != 6) {
      setState(() {
        _errorMessage = 'Введите полный 6-значный код';
      });
      return;
    }

    try {
      // Используем существующий метод верификации
      final result = await _authService.verifyPhoneNumber(smsCode);

      if (mounted) {
        if (result != null) {
          // Если успешно, перенаправляем пользователя
          // Проверяем наличие PIN
          if (_authService.hasPinCode()) {
            final userId = result.id;

            // Переходим на экран ввода PIN
            context.go(
              '/auth/pin',
              extra: {'userId': userId, 'phoneNumber': widget.phoneNumber},
            );
          } else {
            // Если PIN нет, направляем на экран создания PIN
            context.go('/auth/create-pin');
          }
        } else {
          // Что-то пошло не так
          setState(() {
            _errorMessage = 'Ошибка проверки кода';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'ПОДТВЕРЖДЕНИЕ',
          style: TextStyle(fontSize: 16, letterSpacing: 1.5),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 80),

                // Заголовок и инструкция
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Введите код из SMS',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Код отправлен на номер ${widget.phoneNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Поля ввода кода
                TextFormField(
                  key: const Key('sms_code_input'),
                  controller: _codeController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofillHints: const <String>['one-time-code'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    semanticCounterText: 'sms_code',
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 0,
                    ),
                    hintText: '0 0 0 0 0 0',
                    label: Text('Код'),
                    labelStyle: const TextStyle(fontSize: 0, height: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    if (value.length == 6) {
                      _verifyCode();
                    }
                  },
                  textInputAction: TextInputAction.done,
                ),

                const SizedBox(height: 24),

                // Сообщение об ошибке
                if (_errorMessage != null)
                  ErrorMessageWidget(message: _errorMessage!),

                const SizedBox(height: 24),

                // Кнопка "Отправить повторно"
                TextButton(
                  onPressed: _canResend ? _resendCode : null,
                  child: Text(
                    _canResend
                        ? 'Отправить код повторно'
                        : 'Отправить повторно через $_resendTimer с',
                    style: TextStyle(
                      color:
                          _canResend ? theme.colorScheme.primary : Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
