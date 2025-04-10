import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/presentation/widgets/auth/pin_code_input.dart';
import 'package:pater/presentation/widgets/common/error_message.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Экран создания PIN-кода для входа
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePin = true;
  bool _isPinCreated = false;
  int _step = 0;
  String? _firstPin;
  String? _errorMessage;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _pinController.dispose();
    super.dispose();
  }

  /// Безопасно обновляет состояние, проверяя, не уничтожен ли виджет
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  /// Обработчик успешного создания PIN-кода
  void _onPinCreated() async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        _safeSetState(() {
          _errorMessage = 'Ошибка: ID пользователя не найден';
        });
        return;
      }

      final success = await _authService.savePinCode(userId, _firstPin!);

      if (!success) {
        _safeSetState(() {
          _errorMessage = 'Не удалось сохранить PIN-код';
        });
        return;
      }

      _safeSetState(() {
        _isPinCreated = true;
      });

      // Задержка перед переходом
      await Future.delayed(const Duration(seconds: 1));

      final role = _authService.currentUser?.role;

      // Проверяем, что виджет все еще существует перед навигацией
      if (mounted && !_isDisposed) {
        if (role != null) {
          context.go('/home');
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Ошибка: $e';
      });
    }
  }

  /// Очищает поле ввода PIN-кода
  void _clearField() {
    if (!_isDisposed) {
      _pinController.clear();
    }
  }

  /// Проверяет введенный PIN-код
  void _verifyAndSavePin() {
    final pin = _pinController.text;

    // Проверка на простые PIN-коды
    final simplePins = [
      '0000',
      '1111',
      '2222',
      '3333',
      '4444',
      '5555',
      '6666',
      '7777',
      '8888',
      '9999',
      '1234',
      '4321',
      '2580',
      '0852',
    ];

    if (simplePins.contains(pin)) {
      _safeSetState(() {
        _errorMessage = 'Слишком простой PIN-код. Придумайте более надежный.';
      });
      return;
    }

    if (_step == 0) {
      // Сохраняем первый введенный PIN
      _firstPin = pin;
      _safeSetState(() {
        _step = 1;
        _errorMessage = null;
      });
      _clearField();
    } else {
      // Проверяем совпадение с первым PIN
      if (pin == _firstPin) {
        _errorMessage = null;
        _onPinCreated();
      } else {
        _safeSetState(() {
          _errorMessage = 'PIN-коды не совпадают. Попробуйте снова.';
          _step = 0;
          _firstPin = null;
        });
        _clearField();
      }
    }
  }

  /// Пропускает создание PIN-кода
  void _skipPinCreation() async {
    // Просто переходим на главный экран без создания PIN
    if (mounted && !_isDisposed) {
      context.goNamed('home');
    }
  }

  void _onCancel() {
    if (!_isDisposed) {
      _pinController.clear();
    }
    _errorMessage = null;

    if (mounted && !_isDisposed) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PIN-КОД',
          style: TextStyle(fontSize: 16, letterSpacing: 1.2),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _skipPinCreation,
            icon: const Icon(Icons.skip_next, size: 16),
            label: const Text('ПРОПУСТИТЬ', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Индикатор прогресса и заголовок
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // Иконка и статус
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color:
                            _isPinCreated
                                ? Colors.green.withAlpha(26)
                                : theme.colorScheme.primary.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _isPinCreated
                              ? Icons.check
                              : (_step == 0
                                  ? Icons.lock_outline
                                  : Icons.lock_reset),
                          size: 40,
                          color:
                              _isPinCreated
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Индикатор шагов
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < 2; i++)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  (i <= _step) || _isPinCreated
                                      ? theme.colorScheme.primary
                                      : Colors.grey.shade300,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Заголовок
                    Text(
                      _isPinCreated
                          ? 'PIN-код создан'
                          : _step == 0
                          ? 'Создание PIN-кода'
                          : 'Подтверждение PIN-кода',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Описание
                    if (!_isPinCreated) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _step == 0
                              ? 'Создайте 4-значный PIN для быстрого входа'
                              : 'Введите PIN-код повторно',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Форма ввода PIN-кода
            if (!_isPinCreated)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // Поле ввода PIN-кода
                      PinCodeInput(
                        controller: _pinController,
                        onCompleted: (value) {
                          if (_step == 0) {
                            _verifyAndSavePin();
                          } else {
                            _verifyAndSavePin();
                          }
                        },
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            _safeSetState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                        obscureText: _obscurePin,
                        shape: PinCodeFieldShape.circle,
                        borderRadius: 50,
                        activeColor: theme.colorScheme.primary,
                      ),

                      // Переключатель видимости PIN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _obscurePin
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              _safeSetState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
                          Text(
                            _obscurePin ? 'Показать PIN' : 'Скрыть PIN',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      // Сообщения об ошибках
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        ErrorMessageWidget(
                          message: _errorMessage!,
                          dismissible: true,
                          onDismiss: _clearField,
                        ),
                      ],

                      const Spacer(),

                      // Кнопки действий
                      Row(
                        children: [
                          // Кнопка отмены/назад
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _step == 1
                                      ? () {
                                        _safeSetState(() {
                                          _step = 0;
                                          _errorMessage = null;
                                        });
                                      }
                                      : _onCancel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                              child: Text(
                                _step == 1 ? 'НАЗАД' : 'ОТМЕНА',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Кнопка продолжения
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isPinCreated ? null : _verifyAndSavePin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              child:
                                  _isPinCreated
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : Text(
                                        _step == 0 ? 'ДАЛЕЕ' : 'ГОТОВО',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

            // Экран успеха
            if (_isPinCreated)
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Вы можете использовать PIN-код\nдля быстрого входа в приложение',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text(
                        'Переход на главный экран...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
