import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/presentation/widgets/common/app_button.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран бронирования объекта недвижимости
class BookingScreen extends StatefulWidget {
  final String propertyId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? guests;
  final String? bookingId; // Добавляем ID бронирования для редактирования

  const BookingScreen({
    super.key,
    required this.propertyId,
    this.startDate,
    this.endDate,
    this.guests,
    this.bookingId, // Параметр для редактирования существующего бронирования
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final PropertyService _propertyService = PropertyService();
  final BookingService _bookingService = BookingService();
  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();
  final _guestsController = TextEditingController();
  final _commentController = TextEditingController();

  bool _isLoading = true;
  Property? _property;
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  int _guestsCount = 1;
  double _totalPrice = 0;
  bool _isAvailable = true;
  bool _isBookingInProgress = false;
  String? _errorMessage;
  bool _isEditMode = false; // Флаг редактирования

  // Режим бронирования: true - на сутки, false - на часы
  bool _isDailyBooking = true;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.bookingId != null;

    if (_isEditMode) {
      // Если передан ID бронирования, загружаем данные для редактирования
      _loadBookingForEdit();
    } else {
      // Стандартная инициализация для нового бронирования
      _checkInDate =
          widget.startDate ?? DateTime.now().add(const Duration(days: 1));
      _checkOutDate =
          widget.endDate ?? DateTime.now().add(const Duration(days: 3));
      _checkInTime = const TimeOfDay(
        hour: 14,
        minute: 0,
      ); // Стандартное время заезда
      _checkOutTime = const TimeOfDay(
        hour: 12,
        minute: 0,
      ); // Стандартное время выезда
      _guestsController.text =
          widget.guests?.toString() ?? _guestsCount.toString();
      _loadPropertyData();
    }
  }

  @override
  void dispose() {
    _guestsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// Загружает данные бронирования для редактирования
  Future<void> _loadBookingForEdit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint(
        'Загрузка бронирования для редактирования: ${widget.bookingId}',
      );

      // Загружаем данные бронирования по ID
      final booking = await _bookingService.getBookingById(widget.bookingId!);

      if (booking == null) {
        throw Exception('Бронирование не найдено');
      }

      debugPrint(
        'Бронирование загружено: ${booking.id}, статус: ${booking.status}',
      );

      // Выполняем проверку, можно ли редактировать бронирование
      if (booking.status != BookingStatus.pendingApproval &&
          booking.status != BookingStatus.waitingPayment) {
        throw Exception('Нельзя редактировать бронирование в текущем статусе');
      }

      // Устанавливаем данные из бронирования
      _checkInDate = booking.checkInDate;
      _checkOutDate = booking.checkOutDate;

      // Определяем, является ли бронирование посуточным или почасовым
      _isDailyBooking = !booking.isHourly;

      // Извлекаем время заезда и выезда из дат
      _checkInTime = TimeOfDay(
        hour: booking.checkInDate.hour,
        minute: booking.checkInDate.minute,
      );
      _checkOutTime = TimeOfDay(
        hour: booking.checkOutDate.hour,
        minute: booking.checkOutDate.minute,
      );

      // Устанавливаем количество гостей и комментарий
      _guestsCount = booking.guestsCount;
      _guestsController.text = booking.guestsCount.toString();

      if (booking.clientComment != null) {
        _commentController.text = booking.clientComment!;
      }

      // Загружаем данные об объекте
      await _loadPropertyData();

      debugPrint('Данные бронирования успешно загружены для редактирования');
    } catch (e) {
      debugPrint('Ошибка при загрузке данных бронирования: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Загружает данные об объекте и проверяет доступность
  Future<void> _loadPropertyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Вывод отладочной информации
      debugPrint('Загрузка данных объекта с ID: ${widget.propertyId}');

      // Загружаем данные объекта
      final property = await _propertyService.getPropertyById(
        widget.propertyId,
      );

      // Проверка результата запроса
      if (property == null) {
        debugPrint('Объект с ID ${widget.propertyId} не найден');
        throw Exception('Объект не найден');
      }

      debugPrint('Объект успешно загружен: ${property.title}');

      // Для почасовой аренды _checkOutDate = _checkInDate
      if (!_isDailyBooking) {
        _checkOutDate = _checkInDate;
      }

      // Проверяем доступность в выбранные даты
      final isAvailable = await _bookingService.checkAvailability(
        propertyId: widget.propertyId,
        checkInDate: _checkInDate!,
        checkOutDate: _checkOutDate!,
      );

      // Рассчитываем цену в зависимости от режима бронирования
      double totalPrice = 0;

      if (_isDailyBooking) {
        // Расчет для посуточной аренды
        final nights = _checkOutDate!.difference(_checkInDate!).inDays;
        totalPrice = property.pricePerNight * nights;
      } else {
        // Расчет для почасовой аренды
        // Создаем полные DateTime с учетом времени
        if (_checkInTime != null && _checkOutTime != null) {
          final checkInDateTime = DateTime(
            _checkInDate!.year,
            _checkInDate!.month,
            _checkInDate!.day,
            _checkInTime!.hour,
            _checkInTime!.minute,
          );

          final checkOutDateTime = DateTime(
            _checkOutDate!.year,
            _checkOutDate!.month,
            _checkOutDate!.day,
            _checkOutTime!.hour,
            _checkOutTime!.minute,
          );

          // Разница в часах
          final hours = checkOutDateTime.difference(checkInDateTime).inHours;
          totalPrice = property.pricePerHour * (hours > 0 ? hours : 1);

          debugPrint(
            'Расчет почасовой аренды: заезд $checkInDateTime, выезд $checkOutDateTime, часов: $hours',
          );
        } else {
          // Если время не выбрано, ставим минимальную цену за 1 час
          totalPrice = property.pricePerHour;

          debugPrint(
            'Время не выбрано, цена за 1 час: ${property.pricePerHour}',
          );
        }
      }

      if (mounted) {
        setState(() {
          _property = property;
          _isAvailable = isAvailable;
          _totalPrice = totalPrice;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке данных: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Выбор даты заезда
  Future<void> _selectCheckInDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _checkInDate ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 1, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      // Для почасовой аренды дата выезда всегда равна дате заезда
      // Для суточной аренды корректируем дату выезда, если нужно
      DateTime newCheckOutDate;
      if (!_isDailyBooking) {
        newCheckOutDate = pickedDate; // Для почасовой аренды - тот же день
      } else {
        // Если дата выезда раньше новой даты заезда или равна ей, корректируем
        if (_checkOutDate == null ||
            _checkOutDate!.isBefore(pickedDate) ||
            _checkOutDate!.isAtSameMomentAs(pickedDate)) {
          newCheckOutDate = pickedDate.add(const Duration(days: 2));
        } else {
          newCheckOutDate = _checkOutDate!;
        }
      }

      // Проверяем, что виджет всё ещё монтирован
      if (!mounted) return;

      // Создаём полную дату с выбранным временем для проверки (если уже есть время заезда)
      if (!_isDailyBooking && _checkInTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _checkInTime!.hour,
          _checkInTime!.minute,
        );

        // Проверяем время только если выбран текущий день
        final isToday =
            pickedDate.year == now.year &&
            pickedDate.month == now.month &&
            pickedDate.day == now.day;

        // Проверяем, что выбранная дата/время не в прошлом
        if (isToday && selectedDateTime.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Время заезда не может быть в прошлом'),
              backgroundColor: Colors.red,
            ),
          );

          // Сбрасываем время заезда на текущее время + 1 час для текущего дня
          final newTime = TimeOfDay(hour: now.hour + 1, minute: now.minute);

          setState(() {
            _checkInDate = pickedDate;
            _checkOutDate = newCheckOutDate;
            _checkInTime = newTime;
          });

          return;
        }
      }

      setState(() {
        _checkInDate = pickedDate;
        _checkOutDate = newCheckOutDate;
      });

      // Если выбрана почасовая аренда, даем выбрать время заезда
      if (!_isDailyBooking) {
        _selectCheckInTime();
      } else {
        // Перезагружаем данные с новыми датами
        _loadPropertyData();
      }
    }
  }

  /// Выбор времени заезда
  Future<void> _selectCheckInTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _checkInTime ?? const TimeOfDay(hour: 14, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      // Проверяем, что виджет всё ещё монтирован
      if (!mounted) return;

      // Создаём полную дату с выбранным временем для проверки
      final now = DateTime.now();
      final selectedDateTime = DateTime(
        _checkInDate!.year,
        _checkInDate!.month,
        _checkInDate!.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // Проверяем, что выбранная дата/время не в прошлом
      // Если выбран текущий день, проверяем что время не в прошлом
      final isToday =
          _checkInDate!.year == now.year &&
          _checkInDate!.month == now.month &&
          _checkInDate!.day == now.day;

      if (isToday && selectedDateTime.isBefore(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Время заезда не может быть в прошлом'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _checkInTime = pickedTime;

        // Если время выезда раньше времени заезда и дата та же,
        // устанавливаем время выезда на 1 час позже
        if (_checkInDate!.year == _checkOutDate!.year &&
            _checkInDate!.month == _checkOutDate!.month &&
            _checkInDate!.day == _checkOutDate!.day) {
          if (_checkOutTime == null ||
              (_checkOutTime!.hour < _checkInTime!.hour ||
                  (_checkOutTime!.hour == _checkInTime!.hour &&
                      _checkOutTime!.minute <= _checkInTime!.minute))) {
            // Устанавливаем время выезда на час позже
            _checkOutTime = TimeOfDay(
              hour: (_checkInTime!.hour + 1) % 24,
              minute: _checkInTime!.minute,
            );
          }
        }
      });

      // Перезагружаем данные с новым временем
      _loadPropertyData();
    }
  }

  /// Выбор даты выезда
  Future<void> _selectCheckOutDate() async {
    final firstDate =
        _isDailyBooking
            ? _checkInDate!.add(const Duration(days: 1))
            : _checkInDate!; // Для почасовой аренды можно в тот же день

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _checkOutDate ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(
        _checkInDate!.year + 1,
        _checkInDate!.month,
        _checkInDate!.day,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      // Проверяем, что виджет всё ещё монтирован
      if (!mounted) return;

      setState(() {
        _checkOutDate = pickedDate;
      });

      // Если выбрана почасовая аренда, даем выбрать время выезда
      if (!_isDailyBooking) {
        _selectCheckOutTime();
      } else {
        // Перезагружаем данные с новыми датами
        _loadPropertyData();
      }
    }
  }

  /// Выбор времени выезда
  Future<void> _selectCheckOutTime() async {
    // Начальное время выезда
    TimeOfDay initialTime =
        _checkOutTime ?? const TimeOfDay(hour: 12, minute: 0);

    // Если дата выезда совпадает с датой заезда, проверяем, чтобы время выезда было позже времени заезда
    if (_checkInDate!.year == _checkOutDate!.year &&
        _checkInDate!.month == _checkOutDate!.month &&
        _checkInDate!.day == _checkOutDate!.day) {
      if (_checkInTime != null &&
          (initialTime.hour < _checkInTime!.hour ||
              (initialTime.hour == _checkInTime!.hour &&
                  initialTime.minute <= _checkInTime!.minute))) {
        // Устанавливаем время выезда на час позже времени заезда
        initialTime = TimeOfDay(
          hour: (_checkInTime!.hour + 1) % 24,
          minute: _checkInTime!.minute,
        );
      }
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      // Проверяем, что виджет всё ещё монтирован
      if (!mounted) return;

      // Проверка, что время выезда позже времени заезда в тот же день
      if (_checkInDate!.year == _checkOutDate!.year &&
          _checkInDate!.month == _checkOutDate!.month &&
          _checkInDate!.day == _checkOutDate!.day) {
        if (_checkInTime != null &&
            (pickedTime.hour < _checkInTime!.hour ||
                (pickedTime.hour == _checkInTime!.hour &&
                    pickedTime.minute <= _checkInTime!.minute))) {
          // Показываем ошибку
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Время выезда должно быть позже времени заезда'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _checkOutTime = pickedTime;
      });

      // Перезагружаем данные с новым временем
      _loadPropertyData();
    }
  }

  /// Обновление количества гостей
  void _updateGuestsCount(int count) {
    if (count < 1 || (_property != null && count > _property!.maxGuests)) {
      return;
    }

    setState(() {
      _guestsCount = count;
      _guestsController.text = count.toString();
    });
  }

  /// Отправляет запрос на бронирование
  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isBookingInProgress = true;
      _errorMessage = null;
    });

    try {
      // Более подробная проверка и восстановление авторизации
      debugPrint(
        'Проверка авторизации пользователя перед отправкой бронирования',
      );

      if (_authService.currentUser == null) {
        debugPrint(
          'Сессия пользователя не обнаружена, пытаемся восстановить сессию',
        );

        // Получаем сохраненный ID пользователя
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('last_user_id');

        if (savedUserId != null) {
          debugPrint('Найден сохраненный ID пользователя: $savedUserId');

          // Инициализируем сервис авторизации, если он еще не инициализирован
          if (!_authService.isFirebaseInitialized) {
            debugPrint('Инициализация сервиса авторизации...');
            await _authService.init();
          }

          // Пытаемся восстановить сессию пользователя
          final restored = await _authService.restoreUserSession(savedUserId);
          if (restored) {
            debugPrint('Сессия пользователя успешно восстановлена');
          } else {
            debugPrint('Не удалось восстановить сессию автоматически');
            throw Exception(
              'Сессия авторизации была потеряна. Пожалуйста, войдите в аккаунт заново.',
            );
          }
        } else {
          debugPrint('Сохраненный ID пользователя не найден');
          throw Exception(
            'Пользователь не авторизован. Пожалуйста, войдите в аккаунт.',
          );
        }
      }

      // Дополнительная проверка после попытки восстановления
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint(
          'Пользователь все еще не авторизован после попытки восстановления',
        );
        throw Exception(
          'Не удалось восстановить авторизацию. Пожалуйста, войдите заново.',
        );
      }

      debugPrint(
        'Создание бронирования от имени пользователя: ${currentUser.id}',
      );

      // Создаем полные даты с учетом времени
      DateTime checkInDateTime;
      DateTime checkOutDateTime;

      if (_isDailyBooking) {
        // Для посуточной аренды используем стандартное время
        checkInDateTime = DateTime(
          _checkInDate!.year,
          _checkInDate!.month,
          _checkInDate!.day,
          14, // Стандартное время заезда - 14:00
          0,
        );

        checkOutDateTime = DateTime(
          _checkOutDate!.year,
          _checkOutDate!.month,
          _checkOutDate!.day,
          12, // Стандартное время выезда - 12:00
          0,
        );
      } else {
        // Для почасовой аренды используем выбранное время
        if (_checkInTime == null || _checkOutTime == null) {
          throw Exception('Выберите время заезда и выезда');
        }

        checkInDateTime = DateTime(
          _checkInDate!.year,
          _checkInDate!.month,
          _checkInDate!.day,
          _checkInTime!.hour,
          _checkInTime!.minute,
        );

        checkOutDateTime = DateTime(
          _checkOutDate!.year,
          _checkOutDate!.month,
          _checkOutDate!.day,
          _checkOutTime!.hour,
          _checkOutTime!.minute,
        );
      }

      // Проверка корректности дат
      if (checkInDateTime.isAfter(checkOutDateTime)) {
        throw Exception('Дата заезда не может быть позже даты выезда');
      }

      // Проверка минимального срока бронирования для суточной аренды
      if (_isDailyBooking) {
        // Если разные даты, значит минимум 1 сутки - это нормально
        if (_checkInDate!.day != _checkOutDate!.day ||
            _checkInDate!.month != _checkOutDate!.month ||
            _checkInDate!.year != _checkOutDate!.year) {
          // все хорошо, разные даты
        } else {
          throw Exception('Минимальный срок аренды - 1 сутки');
        }
      } else {
        // Проверка минимального срока для почасовой аренды
        if (checkOutDateTime.difference(checkInDateTime).inHours < 1) {
          throw Exception('Минимальный срок аренды - 1 час');
        }
      }

      // Логируем для отладки
      debugPrint('Отправка бронирования:');
      debugPrint('Режим: ${_isDailyBooking ? "суточный" : "почасовой"}');
      debugPrint('Заезд: $checkInDateTime');
      debugPrint('Выезд: $checkOutDateTime');
      debugPrint('Гостей: $_guestsCount');
      debugPrint('ID пользователя: ${currentUser.id}');

      if (_isEditMode) {
        // Обновляем существующее бронирование
        final updatedBooking = await _bookingService.updateBooking(
          bookingId: widget.bookingId!,
          checkInDate: checkInDateTime,
          checkOutDate: checkOutDateTime,
          guestsCount: _guestsCount,
          clientComment:
              _commentController.text.isNotEmpty
                  ? _commentController.text
                  : null,
        );

        if (mounted) {
          setState(() {
            _isBookingInProgress = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Бронирование успешно обновлено'),
              backgroundColor: Colors.green,
            ),
          );

          // Переход на страницу деталей бронирования
          context.goNamed(
            'booking_details',
            pathParameters: {'id': updatedBooking.id},
            extra: updatedBooking,
          );
        }
      } else {
        // Создаем новое бронирование
        final newBooking = await _bookingService.createBooking(
          propertyId: widget.propertyId,
          checkInDate: checkInDateTime,
          checkOutDate: checkOutDateTime,
          guestsCount: _guestsCount,
          clientComment:
              _commentController.text.isNotEmpty
                  ? _commentController.text
                  : null,
          isHourly: !_isDailyBooking,
        );

        debugPrint('Бронирование успешно создано с ID: ${newBooking.id}');

        if (mounted) {
          setState(() {
            _isBookingInProgress = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Бронирование успешно создано'),
              backgroundColor: Colors.green,
            ),
          );

          // Переход на страницу "Поездки" вместо деталей бронирования
          context.goNamed('all_bookings');
        }
      }
    } catch (e) {
      debugPrint('Ошибка при отправке бронирования: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isBookingInProgress = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToProperty() async {
    try {
      // Используем goNamed для навигации вместо Navigator.push
      context.goNamed(
        'property_details',
        pathParameters: {'id': _property!.id.toString()},
        extra: _property,
      );
    } catch (e) {
      debugPrint('Ошибка при навигации к деталям объекта: $e');
      // Обрабатываем ошибку навигации
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при переходе: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, value) {
        if (didPop) return;
        // Обрабатываем возврат назад
        _handleBackNavigation();
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: _isEditMode ? 'Изменение бронирования' : 'Бронирование',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: _buildBookingForm(theme),
      ),
    );
  }

  /// Строит форму бронирования
  Widget _buildBookingForm(ThemeData theme) {
    // Если ещё идёт загрузка, показываем индикатор загрузки
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Если произошла ошибка загрузки, показываем экран с ошибкой
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isEditMode ? _loadBookingForEdit : _loadPropertyData,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      );
    }

    if (_property == null) {
      return const Center(
        child: Text('Не удалось загрузить информацию об объекте'),
      );
    }

    // Основной контент формы бронирования
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информация об объекте
            _buildPropertyInfo(theme),
            const SizedBox(height: 24),

            // Переключатель режима бронирования (суточное/почасовое)
            _buildBookingTypeSelector(theme),
            const SizedBox(height: 24),

            // Выбор даты заезда/выезда
            _buildDateTimeSelectors(theme),
            const SizedBox(height: 16),

            // Выбор времени заезда/выезда для почасовой аренды
            if (!_isDailyBooking) ...[
              _buildDateTimeSelectorsTime(theme),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 8),

            // Выбор количества гостей
            _buildGuestsSection(theme),
            const SizedBox(height: 24),

            // Комментарий (пожелания)
            _buildCommentSection(theme),
            const SizedBox(height: 32),

            // Показываем предупреждение, если даты недоступны
            if (!_isAvailable)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Выбранные даты недоступны для бронирования',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Информация о стоимости
            _buildPriceInfo(theme),
            const SizedBox(height: 32),

            // Кнопка отправки
            AppButton.primary(
              text: _isEditMode ? 'Сохранить изменения' : 'Отправить запрос',
              onPressed:
                  _isBookingInProgress || !_isAvailable ? null : _submitBooking,
              isLoading: _isBookingInProgress,
            ),
          ],
        ),
      ),
    );
  }

  /// Строит информацию об объекте
  Widget _buildPropertyInfo(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        // Используем метод _navigateToProperty для навигации к деталям объекта
        if (_property != null) {
          // Вместо удаления метода _navigateToProperty, используем его по клику на заголовок
          _navigateToProperty();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _property!.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            _property!.address,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 179),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Строит переключатель режима бронирования
  Widget _buildBookingTypeSelector(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (!_isDailyBooking) {
                setState(() {
                  _isDailyBooking = true;
                  // Корректируем даты если нужно
                  if (_checkInDate!.isAtSameMomentAs(_checkOutDate!)) {
                    _checkOutDate = _checkInDate!.add(const Duration(days: 1));
                  }
                  // Перезагружаем данные с новым режимом
                  _loadPropertyData();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isDailyBooking
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
              foregroundColor:
                  _isDailyBooking
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(AppConstants.radiusM),
                ),
              ),
            ),
            child: const Text('На сутки'),
          ),
        ),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_isDailyBooking) {
                setState(() {
                  _isDailyBooking = false;
                  // Для почасовой аренды дата выезда равна дате заезда
                  _checkOutDate = _checkInDate;
                  // Перезагружаем данные с новым режимом
                  _loadPropertyData();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  !_isDailyBooking
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
              foregroundColor:
                  !_isDailyBooking
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(AppConstants.radiusM),
                ),
              ),
            ),
            child: const Text('На часы'),
          ),
        ),
      ],
    );
  }

  /// Строит выбор даты и времени заезда/выезда
  Widget _buildDateTimeSelectors(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Дата заезда',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 179),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppConstants.paddingXS),
              InkWell(
                onTap: _selectCheckInDate,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.paddingM),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 76),
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppConstants.paddingS),
                      Text(
                        DateFormat('dd.MM.yyyy').format(_checkInDate!),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Показываем дату выезда только для суточной аренды
        if (_isDailyBooking) ...[
          const SizedBox(width: AppConstants.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дата выезда',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 179),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                InkWell(
                  onTap: _selectCheckOutDate,
                  child: Container(
                    padding: const EdgeInsets.all(AppConstants.paddingM),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 76),
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppConstants.paddingS),
                        Text(
                          DateFormat('dd.MM.yyyy').format(_checkOutDate!),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Строит выбор времени заезда/выезда
  Widget _buildDateTimeSelectorsTime(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Время заезда',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 179),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppConstants.paddingXS),
              InkWell(
                onTap: _selectCheckInTime,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.paddingM),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 76),
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppConstants.paddingS),
                      Text(
                        _checkInTime != null
                            ? '${_checkInTime!.hour.toString().padLeft(2, '0')}:${_checkInTime!.minute.toString().padLeft(2, '0')}'
                            : '14:00',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Время выезда только для почасовой аренды
        if (!_isDailyBooking) ...[
          const SizedBox(width: AppConstants.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Время выезда',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 179),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingXS),
                InkWell(
                  onTap: _selectCheckOutTime,
                  child: Container(
                    padding: const EdgeInsets.all(AppConstants.paddingM),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 76),
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppConstants.paddingS),
                        Text(
                          _checkOutTime != null
                              ? '${_checkOutTime!.hour.toString().padLeft(2, '0')}:${_checkOutTime!.minute.toString().padLeft(2, '0')}'
                              : '12:00',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Строит выбор количества гостей
  Widget _buildGuestsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Количество гостей',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 179),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXS),
        Row(
          children: [
            IconButton(
              onPressed: () => _updateGuestsCount(_guestsCount - 1),
              icon: Icon(
                Icons.remove_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _guestsController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                ),
                onChanged: (value) {
                  final count = int.tryParse(value);
                  if (count != null) {
                    _updateGuestsCount(count);
                  }
                },
              ),
            ),
            IconButton(
              onPressed: () => _updateGuestsCount(_guestsCount + 1),
              icon: Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        if (_property != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Максимально: ${_property!.maxGuests} гостей',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 128),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// Строит комментарий (пожелания)
  Widget _buildCommentSection(ThemeData theme) {
    return TextFormField(
      controller: _commentController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Напишите, если у вас есть особые пожелания',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 128),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 77),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 77),
          ),
        ),
      ),
    );
  }

  /// Строит информацию о стоимости
  Widget _buildPriceInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 77),
        ),
      ),
      child: Column(
        children: [
          if (_isDailyBooking) ...[
            // Информация для суточной аренды
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Стоимость за ночь', style: theme.textTheme.bodyMedium),
                Text(
                  '${_property?.pricePerNight.toInt()} ₸',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Количество ночей', style: theme.textTheme.bodyMedium),
                Text(
                  '${_checkOutDate!.difference(_checkInDate!).inDays}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ] else ...[
            // Информация для почасовой аренды
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Стоимость за час', style: theme.textTheme.bodyMedium),
                Text(
                  '${_property?.pricePerHour.toInt()} ₸',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Количество часов', style: theme.textTheme.bodyMedium),
                Text(
                  _calculateHours().toString(),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppConstants.paddingS),
          const Divider(),
          const SizedBox(height: AppConstants.paddingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Итого',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_totalPrice.toInt()} ₸',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Рассчитывает количество часов между временем заезда и выезда
  int _calculateHours() {
    if (_checkInDate == null ||
        _checkOutDate == null ||
        _checkInTime == null ||
        _checkOutTime == null) {
      return 0;
    }

    final checkInDateTime = DateTime(
      _checkInDate!.year,
      _checkInDate!.month,
      _checkInDate!.day,
      _checkInTime!.hour,
      _checkInTime!.minute,
    );

    final checkOutDateTime = DateTime(
      _checkOutDate!.year,
      _checkOutDate!.month,
      _checkOutDate!.day,
      _checkOutTime!.hour,
      _checkOutTime!.minute,
    );

    final difference = checkOutDateTime.difference(checkInDateTime);
    return difference.inHours > 0 ? difference.inHours : 0;
  }

  /// Обрабатывает навигацию при нажатии кнопки назад
  void _handleBackNavigation() {
    if (_isBookingInProgress) {
      // Если идет процесс бронирования, предотвращаем навигацию
      return;
    }

    debugPrint('Навигация назад из экрана бронирования');

    if (_isEditMode) {
      // Если мы в режиме редактирования, возвращаемся к деталям бронирования
      if (widget.bookingId != null) {
        context.goNamed(
          'booking_details',
          pathParameters: {'id': widget.bookingId!},
        );
        return;
      }
    }

    // Возвращаемся к деталям объекта
    try {
      context.goNamed(
        'property_details',
        pathParameters: {'id': widget.propertyId},
      );
    } catch (e) {
      // Если что-то пошло не так, возвращаемся на основную страницу поиска
      debugPrint('Ошибка при возврате к деталям объекта: $e');
      context.goNamed('search');
    }
  }
}
