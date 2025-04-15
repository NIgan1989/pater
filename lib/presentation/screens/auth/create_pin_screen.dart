import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/presentation/widgets/auth/pin_code_input.dart';
import 'package:pater/presentation/widgets/common/error_message.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:pater/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран создания PIN-кода для входа
class CreatePinScreen extends StatefulWidget {
  final String? userId;
  final String? phoneNumber;

  const CreatePinScreen({super.key, this.userId, this.phoneNumber});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  // Обертка для контроллера, которая блокирует доступ после dispose
  final _pinControllerWrapper = _SafeTextEditingController(
    TextEditingController(),
  );

  late final AuthService _authService;

  String _userId = '';
  // ignore: unused_field
  String _phoneNumber = '';

  bool _obscurePin = true;
  bool _isPinCreated = false;
  int _step = 0;
  String? _firstPin;
  String? _errorMessage;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _authService = getIt<AuthService>();

    // Инициализируем userId и phoneNumber из параметров или получаем из сервиса
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _userId = widget.userId ?? '';
    _phoneNumber = widget.phoneNumber ?? '';

    // Если userId не был передан, пробуем получить из AuthService или SharedPreferences
    if (_userId.isEmpty) {
      _userId = _authService.getUserId() ?? '';

      if (_userId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          _userId =
              prefs.getString('user_id') ??
              prefs.getString('temp_user_id') ??
              prefs.getString('last_user_id') ??
              '';

          if (_userId.isNotEmpty) {
            debugPrint('Получен userId из SharedPreferences: $_userId');
          }
        } catch (e) {
          debugPrint('Ошибка при получении userId из SharedPreferences: $e');
        }
      } else {
        debugPrint('Получен userId из AuthService: $_userId');
      }
    } else {
      debugPrint('Использован userId из параметров: $_userId');

      // Сохраняем ID пользователя для последующего использования
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', _userId);
        await prefs.setString('temp_user_id', _userId);
        await prefs.setString('last_user_id', _userId);
      } catch (e) {
        debugPrint('Ошибка при сохранении userId: $e');
      }
    }
  }

  @override
  void dispose() {
    // Сначала устанавливаем флаг, чтобы другие методы знали, что State уничтожается
    _isDisposed = true;

    // Безопасное уничтожение контроллера
    _pinControllerWrapper.dispose();

    super.dispose();
  }

  /// Безопасно обновляет состояние, проверяя, не уничтожен ли виджет
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  /// Обработчик успешного создания PIN-кода
  Future<void> _onPinCreated() async {
    if (_isDisposed) return; // Ранний выход, если виджет уже уничтожен

    try {
      if (_userId.isEmpty) {
        _safeSetState(() {
          _errorMessage = 'Ошибка: ID пользователя не найден';
        });
        debugPrint('CreatePinScreen: Ошибка - ID пользователя пустой');
        return;
      }

      debugPrint(
        'CreatePinScreen: Сохранение PIN-кода для пользователя: $_userId',
      );

      // Сохраняем информацию, необходимую для навигации
      final currentRole = _authService.currentUser?.role;
      final navigateToHome = currentRole != null;

      await _authService.savePinCode(_firstPin!);

      // Сохраняем состояние аутентификации
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_authenticated', true);
        await prefs.setString('user_id', _userId);
        await _authService.forceAuthenticationState(true);
        debugPrint(
          'CreatePinScreen: Состояние аутентификации сохранено для $_userId',
        );

        // Обновляем состояние аутентификации
        await _authService.refreshAuthenticationState();
      } catch (e) {
        debugPrint(
          'CreatePinScreen: Ошибка при сохранении состояния аутентификации: $e',
        );
      }

      // Используем сохраненный контекст только после проверки, что виджет все еще активен
      if (mounted && !_isDisposed) {
        _safeSetState(() {
          _isPinCreated = true;
        });

        // Задержка перед переходом
        await Future.delayed(const Duration(seconds: 1));

        // Теперь используем переменную navigateToHome, а не запрашиваем роль снова
        if (mounted && !_isDisposed) {
          try {
            // Используем context напрямую - он безопасен, так как проверили mounted
            final router = GoRouter.of(context);
            if (navigateToHome) {
              debugPrint('CreatePinScreen: Переход на /home');
              router.go('/home');
            } else {
              debugPrint('CreatePinScreen: Переход на /');
              router.go('/');
            }
          } catch (e) {
            debugPrint('CreatePinScreen: Ошибка при навигации: $e');
          }
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _safeSetState(() {
          _errorMessage = 'Ошибка: $e';
        });
      }
      debugPrint('CreatePinScreen: Ошибка создания PIN-кода: $e');
    }
  }

  /// Очищает поле ввода PIN-кода
  void _clearField() {
    if (!_isDisposed) {
      _pinControllerWrapper.clear();
    }
  }

  /// Проверяет введенный PIN-код
  void _verifyAndSavePin() {
    if (_isDisposed) return; // Ранний выход, если виджет уже уничтожен

    final pin = _pinControllerWrapper.text;
    if (pin.isEmpty) return;

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
  Future<void> _skipPinCreation() async {
    if (_isDisposed || !mounted) return;

    try {
      debugPrint(
        'CreatePinScreen: Пропускаем создание PIN, переход на главный экран',
      );

      await _authService.forceAuthenticationState(true);

      // Обновляем состояние аутентификации
      await _authService.refreshAuthenticationState();

      // Проверяем еще раз перед навигацией
      if (mounted && !_isDisposed) {
        try {
          // Используем context напрямую - он безопасен, так как проверили mounted
          final router = GoRouter.of(context);
          router.goNamed('home');
        } catch (e) {
          debugPrint('CreatePinScreen: Ошибка при навигации: $e');
        }
      }
    } catch (e) {
      debugPrint('CreatePinScreen: Ошибка при пропуске создания PIN: $e');
    }
  }

  Future<void> _onCancel() async {
    if (_isDisposed || !mounted) return;

    try {
      _pinControllerWrapper.clear();
      _errorMessage = null;

      // Выполняем навигацию сразу, без асинхронных операций
      debugPrint(
        'CreatePinScreen: Отмена создания PIN, возврат на предыдущий экран',
      );
      try {
        GoRouter.of(context).go('/');
      } catch (e) {
        debugPrint('CreatePinScreen: Ошибка при навигации: $e');
      }
    } catch (e) {
      debugPrint('CreatePinScreen: Ошибка при отмене: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      // Если State уже помечен как уничтоженный, возвращаем пустой контейнер
      return Container();
    }

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
                        controller: _pinControllerWrapper.controller,
                        onCompleted: (value) {
                          if (_isDisposed) return;
                          _verifyAndSavePin();
                        },
                        onChanged: (_) {
                          if (_isDisposed) return;
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
                              if (_isDisposed) return;
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
                                        if (_isDisposed) return;
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

/// Безопасная обертка для TextEditingController, предотвращающая использование после удаления
class _SafeTextEditingController {
  TextEditingController? _controller;
  bool _isDisposed = false;

  _SafeTextEditingController(TextEditingController controller) {
    _controller = controller;
  }

  TextEditingController get controller {
    if (_isDisposed || _controller == null) {
      // Возвращаем временный контроллер, если основной уже уничтожен
      debugPrint('⚠️ Попытка доступа к уничтоженному контроллеру');
      return TextEditingController();
    }
    return _controller!;
  }

  String get text =>
      _isDisposed || _controller == null ? '' : _controller!.text;

  void clear() {
    if (!_isDisposed && _controller != null) {
      try {
        _controller!.clear();
      } catch (e) {
        debugPrint('Ошибка при очистке PIN-контроллера: $e');
      }
    }
  }

  void dispose() {
    if (!_isDisposed && _controller != null) {
      // Сначала помечаем как уничтоженный, чтобы блокировать дальнейший доступ
      _isDisposed = true;

      // Сохраняем ссылку на контроллер и обнуляем поле
      final controllerToDispose = _controller;
      _controller = null;

      // Выполняем dispose в отдельном микротаске,
      // чтобы отсоединить его от текущего цикла событий
      Future.microtask(() {
        try {
          controllerToDispose?.dispose();
        } catch (e) {
          debugPrint('Ошибка при уничтожении PIN-контроллера: $e');
        }
      });
    }
  }
}
