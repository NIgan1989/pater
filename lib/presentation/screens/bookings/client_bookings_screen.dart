import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/di/service_locator.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/presentation/widgets/bookings/universal_booking_card.dart';
import 'dart:async';

/// Тип списка бронирований
enum BookingListType { all, active, booking, cancelled }

/// Модель, объединяющая бронирование и данные об объекте
class BookingWithProperty {
  final Booking booking;
  final Property property;
  final User? owner;

  BookingWithProperty({
    required this.booking,
    required this.property,
    this.owner,
  });
}

/// Экран для просмотра бронирований клиента
class ClientBookingsScreen extends StatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen>
    with SingleTickerProviderStateMixin {
  final PropertyService _propertyService = PropertyService();
  final BookingService _bookingService = BookingService();
  late final AuthService _authService;
  final UserService _userService = UserService();

  /// Контроллер табов
  late TabController _tabController;

  /// Флаг загрузки
  bool _isLoading = true;

  /// Сообщение об ошибке
  String? _errorMessage;

  /// Список всех бронирований
  List<BookingWithProperty> _allBookings = [];

  /// Список активных бронирований (в процессе)
  List<BookingWithProperty> _activeBookings = [];

  /// Список бронирований в статусе ожидания
  List<BookingWithProperty> _pendingBookings = [];

  /// Список отмененных бронирований
  List<BookingWithProperty> _cancelledBookings = [];

  /// Идентификаторы новых бронирований (для подсветки)
  final Set<String> _newBookingIds = {};

  /// Таймер для обновления статусов бронирований
  Timer? _updateTimer;

  /// Выбранные фильтры для активных бронирований
  Set<BookingStatus> _activeFilters = {
    BookingStatus.active,
    BookingStatus.confirmed,
  };

  /// Выбранные фильтры для ожидающих бронирований
  Set<BookingStatus> _pendingFilters = {
    BookingStatus.pendingApproval,
    BookingStatus.waitingPayment,
    BookingStatus.paid,
  };

  /// Выбранные фильтры для отмененных бронирований
  Set<BookingStatus> _cancelledFilters = {
    BookingStatus.cancelled,
    BookingStatus.cancelledByClient,
    BookingStatus.rejectedByOwner,
    BookingStatus.expired,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _authService = getIt<AuthService>();
    _loadBookings();

    // Проверяем и обновляем статусы бронирований каждую минуту
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _checkAndUpdateBookingStatuses();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Загружает бронирования пользователя
  Future<void> _loadBookings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.currentUser?.id ?? '';
      if (userId.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }

      final bookings = await _bookingService.getUserBookings(userId);

      // Создаем списки для разных типов бронирований
      List<BookingWithProperty> allBookingsList = [];
      List<BookingWithProperty> activeBookingsList = [];
      List<BookingWithProperty> pendingBookingsList = [];
      List<BookingWithProperty> cancelledBookingsList = [];

      for (var booking in bookings) {
        try {
          // Получаем данные об объекте
          final property = await _propertyService.getPropertyById(
            booking.propertyId,
          );

          // Пропускаем бронирования, для которых не найдено свойство
          if (property == null) {
            debugPrint('Свойство не найдено для бронирования ${booking.id}');
            continue;
          }

          // Получаем данные о владельце
          final owner = await _userService.getUserById(booking.ownerId);

          final bookingWithProperty = BookingWithProperty(
            booking: booking,
            property: property,
            owner: owner,
          );

          // Добавляем во все бронирования
          allBookingsList.add(bookingWithProperty);

          // Распределяем бронирования по категориям
          if (_activeFilters.contains(booking.status)) {
            activeBookingsList.add(bookingWithProperty);
          } else if (_pendingFilters.contains(booking.status)) {
            pendingBookingsList.add(bookingWithProperty);
          } else if (_cancelledFilters.contains(booking.status)) {
            cancelledBookingsList.add(bookingWithProperty);
          }

          // Отмечаем новые бронирования
          // if (booking.isNewForClient) {
          //   _newBookingIds.add(booking.id);
          // }
        } catch (e) {
          debugPrint(
            'Ошибка при загрузке данных для бронирования ${booking.id}: $e',
          );
          // Пропускаем бронирование с ошибкой и продолжаем загрузку
          continue;
        }
      }

      // Сортируем бронирования по дате обновления
      allBookingsList.sort(
        (a, b) => b.booking.updatedAt.compareTo(a.booking.updatedAt),
      );
      activeBookingsList.sort(
        (a, b) => b.booking.updatedAt.compareTo(a.booking.updatedAt),
      );
      pendingBookingsList.sort(
        (a, b) => b.booking.updatedAt.compareTo(a.booking.updatedAt),
      );
      cancelledBookingsList.sort(
        (a, b) => b.booking.updatedAt.compareTo(a.booking.updatedAt),
      );

      if (mounted) {
        setState(() {
          _allBookings = allBookingsList;
          _activeBookings = activeBookingsList;
          _pendingBookings = pendingBookingsList;
          _cancelledBookings = cancelledBookingsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при загрузке бронирований: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Переход к деталям бронирования
  void _navigateToBookingDetails(String bookingId) {
    context
        .pushNamed('booking_details', pathParameters: {'id': bookingId})
        .then((_) => _loadBookings()); // Перезагружаем данные при возврате
  }

  /// Контакт с владельцем по его ID напрямую (открывает чат)
  void _contactOwnerById(String ownerId) {
    context.pushNamed('chat', pathParameters: {'chatId': ownerId});
  }

  /// Показывает диалог отмены бронирования
  void _showCancellationDialog(BookingWithProperty bookingWithProperty) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отмена бронирования'),
            content: const Text(
              'Вы уверены, что хотите отменить бронирование? '
              'Это действие нельзя будет отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () {
                  context.pop();
                  _cancelBooking(bookingWithProperty.booking.id);
                },
                child: const Text('Да, отменить'),
              ),
            ],
          ),
    );
  }

  /// Показывает информацию о владельце
  void _showOwnerInfo(User? owner) {
    if (owner == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 26),
                    child: Text(
                      owner.initials,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owner.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              owner.rating.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Закрыть'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.pop();
                        _contactOwnerById(owner.id);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Написать'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Отменяет бронирование
  Future<void> _cancelBooking(String bookingId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Отменяем бронирование
      await _bookingService.cancelBooking(bookingId);

      // Перезагружаем данные
      await _loadBookings();

      // Показываем сообщение об успехе
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Бронирование успешно отменено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отмене бронирования: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Переход к оплате бронирования
  void _navigateToPayment(String bookingId) {
    context
        .pushNamed('payment', pathParameters: {'bookingId': bookingId})
        .then((_) => _loadBookings());
  }

  /// Завершает аренду досрочно
  Future<void> _completeBooking(String bookingId) async {
    try {
      await _bookingService.completeBooking(bookingId);
      _loadBookings();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аренда успешно завершена'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при завершении аренды: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Показывает диалог завершения бронирования
  void _showCompletionDialog(BookingWithProperty bookingWithProperty) {
    // Проверяем, можно ли завершить бронирование
    if (bookingWithProperty.booking.status != BookingStatus.active &&
        bookingWithProperty.booking.status != BookingStatus.paid) {
      // Если бронирование нельзя завершить, показываем сообщение об ошибке
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Можно завершить только активное или оплаченное бронирование',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Завершение бронирования'),
            content: const Text(
              'Вы уверены, что хотите отметить бронирование как завершенное? '
              'Это действие нельзя будет отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () {
                  context.pop();
                  _completeBooking(bookingWithProperty.booking.id);
                },
                child: const Text('Да, завершить'),
              ),
            ],
          ),
    );
  }

  /// Проверяет и обновляет статусы бронирований
  Future<void> _checkAndUpdateBookingStatuses() async {
    if (!mounted) return;

    try {
      // Запускаем обновление просроченных бронирований через сервис
      await _bookingService.checkAndUpdateExpiredBookings();

      // После обновления статусов в БД, перезагружаем список бронирований
      if (mounted) {
        _loadBookings(); // Перезагружаем все данные
      }

      // Локально проверяем бронирования, которые могут истечь
      setState(() {
        // Проверяем статусы активных бронирований
        List<BookingWithProperty> expiredBookings =
            _pendingBookings.where((bookingWithProperty) {
              final booking = bookingWithProperty.booking;
              return (booking.status == BookingStatus.pendingApproval &&
                      booking.isApprovalExpired) ||
                  (booking.status == BookingStatus.waitingPayment &&
                      booking.isPaymentExpired);
            }).toList();

        // Если найдены просроченные бронирования, обновляем данные
        if (expiredBookings.isNotEmpty) {
          debugPrint(
            'Найдены просроченные бронирования: ${expiredBookings.length}',
          );
          _loadBookings();
        }
      });
    } catch (e) {
      debugPrint('Ошибка при проверке статусов бронирования: $e');
    }
  }

  /// Построитель элемента списка бронирований
  Widget _buildBookingItem(
    BookingWithProperty bookingWithProperty,
    BookingListType type,
  ) {
    final booking = bookingWithProperty.booking;
    final property = bookingWithProperty.property;
    final owner = bookingWithProperty.owner;

    // Проверяем, является ли бронирование новым
    final isNew = _newBookingIds.contains(booking.id);

    return UniversalBookingCard(
      booking: booking,
      property: property,
      owner: owner,
      userRole: UserRole.client,
      isNew: isNew,
      initiallyExpanded: false, // Устанавливаем свернутый вид по умолчанию
      onTap: () => _navigateToBookingDetails(booking.id),
      onContact: () => _showOwnerInfo(owner),
      onPayment:
          booking.status == BookingStatus.waitingPayment
              ? () => _navigateToPayment(booking.id)
              : null,
      onCancel:
          _canCancelBooking(booking)
              ? () => _showCancellationDialog(bookingWithProperty)
              : null,
      onComplete:
          _canCompleteBooking(booking)
              ? () => _showCompletionDialog(bookingWithProperty)
              : null,
      onUserTap: owner != null ? () => _showOwnerInfo(owner) : null,
    );
  }

  /// Проверяет, можно ли отменить бронирование
  bool _canCancelBooking(Booking booking) {
    return booking.status == BookingStatus.pendingApproval ||
        booking.status == BookingStatus.waitingPayment ||
        (booking.status == BookingStatus.paid &&
            DateTime.now().isBefore(booking.checkInDate));
  }

  /// Проверяет, можно ли завершить бронирование
  bool _canCompleteBooking(Booking booking) {
    final now = DateTime.now();
    return (booking.status == BookingStatus.paid ||
            booking.status == BookingStatus.active) &&
        now.isAfter(booking.checkInDate) &&
        now.isBefore(booking.checkOutDate);
  }

  /// Показывает фильтры для текущего таба
  void _showFilters(BuildContext context) {
    final currentTab = _tabController.index;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Set<BookingStatus> currentFilters;
            List<BookingStatus> availableStatuses;

            // Определяем текущие фильтры и доступные статусы в зависимости от выбранного таба
            if (currentTab == 0) {
              // Все бронирования
              currentFilters = {
                ..._activeFilters,
                ..._pendingFilters,
                ..._cancelledFilters,
              };
              availableStatuses = [
                BookingStatus.pendingApproval,
                BookingStatus.waitingPayment,
                BookingStatus.paid,
                BookingStatus.active,
                BookingStatus.confirmed,
                BookingStatus.completed,
                BookingStatus.cancelled,
                BookingStatus.cancelledByClient,
                BookingStatus.rejectedByOwner,
                BookingStatus.expired,
              ];
            } else if (currentTab == 1) {
              // Активные бронирования
              currentFilters = _activeFilters;
              availableStatuses = [
                BookingStatus.active,
                BookingStatus.confirmed,
              ];
            } else if (currentTab == 2) {
              // Ожидающие бронирования
              currentFilters = _pendingFilters;
              availableStatuses = [
                BookingStatus.pendingApproval,
                BookingStatus.waitingPayment,
                BookingStatus.paid,
              ];
            } else {
              // Отмененные бронирования
              currentFilters = _cancelledFilters;
              availableStatuses = [
                BookingStatus.cancelled,
                BookingStatus.cancelledByClient,
                BookingStatus.rejectedByOwner,
                BookingStatus.expired,
              ];
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Фильтры',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          // Сбрасываем выбранные фильтры к исходным
                          if (currentTab == 0) {
                            setState(() {
                              _activeFilters = {
                                BookingStatus.active,
                                BookingStatus.confirmed,
                              };
                              _pendingFilters = {
                                BookingStatus.pendingApproval,
                                BookingStatus.waitingPayment,
                                BookingStatus.paid,
                              };
                              _cancelledFilters = {
                                BookingStatus.cancelled,
                                BookingStatus.cancelledByClient,
                                BookingStatus.rejectedByOwner,
                                BookingStatus.expired,
                              };
                            });
                          } else if (currentTab == 1) {
                            setState(() {
                              _activeFilters = availableStatuses.toSet();
                            });
                          } else if (currentTab == 2) {
                            setState(() {
                              _pendingFilters = availableStatuses.toSet();
                            });
                          } else {
                            setState(() {
                              _cancelledFilters = availableStatuses.toSet();
                            });
                          }
                          // Обновляем и списки бронирований
                          _loadBookings();
                        },
                        child: const Text('Сбросить'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Список статусов с чекбоксами
                  Expanded(
                    child: ListView(
                      children:
                          availableStatuses.map((status) {
                            return CheckboxListTile(
                              title: Text(_getStatusText(status)),
                              value: currentFilters.contains(status),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    // Добавляем статус в фильтр
                                    _addStatusToFilter(status, currentTab);
                                  } else {
                                    // Убираем статус из фильтра
                                    _removeStatusFromFilter(status, currentTab);
                                  }
                                });

                                // Обновляем списки бронирований в основном состоянии
                                _loadBookings();
                              },
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Добавляет статус в соответствующий фильтр
  void _addStatusToFilter(BookingStatus status, int currentTab) {
    if (currentTab == 0) {
      // Все бронирования
      if ([BookingStatus.active, BookingStatus.confirmed].contains(status)) {
        _activeFilters.add(status);
      } else if ([
        BookingStatus.pendingApproval,
        BookingStatus.waitingPayment,
        BookingStatus.paid,
      ].contains(status)) {
        _pendingFilters.add(status);
      } else {
        _cancelledFilters.add(status);
      }
    } else if (currentTab == 1) {
      // Активные бронирования
      _activeFilters.add(status);
    } else if (currentTab == 2) {
      // Ожидающие бронирования
      _pendingFilters.add(status);
    } else {
      // Отмененные бронирования
      _cancelledFilters.add(status);
    }
  }

  /// Удаляет статус из соответствующего фильтра
  void _removeStatusFromFilter(BookingStatus status, int currentTab) {
    if (currentTab == 0) {
      // Все бронирования
      if ([BookingStatus.active, BookingStatus.confirmed].contains(status)) {
        _activeFilters.remove(status);
      } else if ([
        BookingStatus.pendingApproval,
        BookingStatus.waitingPayment,
        BookingStatus.paid,
      ].contains(status)) {
        _pendingFilters.remove(status);
      } else {
        _cancelledFilters.remove(status);
      }
    } else if (currentTab == 1) {
      // Активные бронирования
      _activeFilters.remove(status);
    } else if (currentTab == 2) {
      // Ожидающие бронирования
      _pendingFilters.remove(status);
    } else {
      // Отмененные бронирования
      _cancelledFilters.remove(status);
    }
  }

  /// Отображает сообщение об ошибке
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Произошла ошибка',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBookings,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  /// Список бронирований
  Widget _buildBookingsList(BookingListType type) {
    final List<BookingWithProperty> bookings;

    switch (type) {
      case BookingListType.all:
        bookings = _allBookings;
        break;
      case BookingListType.active:
        bookings = _activeBookings;
        break;
      case BookingListType.booking:
        bookings = _pendingBookings;
        break;
      case BookingListType.cancelled:
        bookings = _cancelledBookings;
        break;
    }

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              switch (type) {
                BookingListType.all => 'У вас пока нет поездок',
                BookingListType.active => 'У вас пока нет активных поездок',
                BookingListType.booking => 'У вас пока нет ожидающих поездок',
                BookingListType.cancelled =>
                  'У вас пока нет отменённых поездок',
              },
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingItem(bookings[index], type);
        },
      ),
    );
  }

  /// Возвращает текстовое описание статуса бронирования
  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pendingApproval:
        return 'Ожидает подтверждения';
      case BookingStatus.confirmed:
        return 'Подтверждено';
      case BookingStatus.waitingPayment:
        return 'Ожидает оплаты';
      case BookingStatus.paid:
        return 'Оплачено';
      case BookingStatus.active:
        return 'Активно';
      case BookingStatus.completed:
        return 'Завершено';
      case BookingStatus.cancelled:
        return 'Отменено';
      case BookingStatus.cancelledByClient:
        return 'Отменено вами';
      case BookingStatus.rejectedByOwner:
        return 'Отклонено владельцем';
      case BookingStatus.expired:
        return 'Истекло';
      default:
        return 'Неизвестный статус';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Определение статуса пользователя
    final userRole = _authService.currentUser?.role ?? UserRole.client;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          userRole == UserRole.client ? 'Мои поездки' : 'Мои бронирования',
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.all_inclusive)),
            Tab(icon: Icon(Icons.directions_car)),
            Tab(icon: Icon(Icons.pending_actions)),
            Tab(icon: Icon(Icons.cancel_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(context),
            tooltip: 'Фильтры',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
              : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                controller: _tabController,
                children: [
                  // Вкладка "Все" - показывает все бронирования
                  _buildBookingsList(BookingListType.all),
                  // Вкладка "Активные" - показывает активные бронирования
                  _buildBookingsList(BookingListType.active),
                  // Вкладка "Бронирование" - показывает ожидающие бронирования
                  _buildBookingsList(BookingListType.booking),
                  // Вкладка "Отмененные" - показывает отмененные бронирования
                  _buildBookingsList(BookingListType.cancelled),
                ],
              ),
    );
  }
}
