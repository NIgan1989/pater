import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pater/data/services/booking_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/presentation/widgets/common/error_view.dart';
import 'package:pater/presentation/widgets/common/empty_state.dart';
import 'dart:async';

// Импортируем недостающие сервисы и сущности
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/presentation/widgets/bookings/universal_booking_card.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';

/// Экран управления бронированиями для владельца.
/// Позволяет просматривать список бронирований и управлять ими.
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

/// Тип фильтра для бронирований владельца
enum BookingFilterType { active, booked, cleaning }

class PropertyWithBookings {
  final Property property;
  final List<Booking> bookings;

  PropertyWithBookings({required this.property, required this.bookings});

  // Геттеры для упрощения доступа к свойствам Property
  String get id => property.id;
  String get title => property.title;
  PropertyStatus get status => property.status;
  String get subStatus => property.subStatus;
  List<String> get imageUrls => property.imageUrls;
  String get ownerId => property.ownerId;
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen>
    with TickerProviderStateMixin {
  final PropertyService _propertyService = PropertyService();
  final AuthService _authService = AuthService();
  final BookingService _bookingService = BookingService();

  /// Контроллер табов
  late TabController _tabController;

  bool _isLoading = true;
  List<PropertyWithBookings> _properties = [];
  final Map<String, List<Booking>> _propertyBookings = {};
  final Map<String, User?> _bookingClients = {};
  String? _errorMessage;

  // Текущий выбранный фильтр
  BookingFilterType _currentFilter = BookingFilterType.active;

  // Добавляем таймер для обновления статусов бронирований
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // 3 вкладки вместо 4
    _loadData();

    // Обработчик изменения вкладки
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // При переключении вкладок мы просто обновляем состояние интерфейса
        setState(() {
          switch (_tabController.index) {
            case 0:
              _currentFilter = BookingFilterType.active;
              break;
            case 1:
              _currentFilter = BookingFilterType.booked;
              break;
            case 2:
              _currentFilter = BookingFilterType.cleaning;
              break;
          }
        });
      }
    });

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

  /// Загружает данные объектов и бронирований
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Получаем текущего пользователя
      final currentUser = _authService.currentUser;

      // Если пользователь не авторизован, пробуем восстановить сессию
      if (currentUser == null) {
        debugPrint(
          'Пользователь не авторизован, пробуем восстановить сессию...',
        );

        // Пробуем восстановить сессию через лист ID
        final prefs = await SharedPreferences.getInstance();
        final lastUserId = prefs.getString('last_user_id');

        if (lastUserId != null && lastUserId.isNotEmpty) {
          // Восстанавливаем сессию используя ID последнего пользователя
          final success = await _authService.restoreUserSession(lastUserId);

          if (!success) {
            throw Exception('Не удалось восстановить сессию пользователя');
          }

          debugPrint('Сессия восстановлена для пользователя: $lastUserId');
        } else {
          throw Exception('Нет сохраненной сессии для восстановления');
        }
      }

      // Загружаем объекты пользователя
      final properties = await _propertyService.getUserProperties(
        _authService.currentUser!.id,
      );

      // Загружаем бронирования пользователя
      final bookings = await _bookingService.getOwnerBookings();

      // Сгруппируем бронирования по ID объекта
      final Map<String, List<Booking>> bookingsByProperty = {};
      for (final booking in bookings) {
        if (!bookingsByProperty.containsKey(booking.propertyId)) {
          bookingsByProperty[booking.propertyId] = [];
        }
        bookingsByProperty[booking.propertyId]!.add(booking);
      }

      // Создаем список объектов с их бронированиями
      final List<PropertyWithBookings> propertiesWithBookings = [];
      for (final property in properties) {
        propertiesWithBookings.add(
          PropertyWithBookings(
            property: property,
            bookings: bookingsByProperty[property.id] ?? [],
          ),
        );
      }

      // Обновляем состояние
      if (mounted) {
        setState(() {
          _properties = propertiesWithBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке данных: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при загрузке данных: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Показывает снэкбар с сообщением
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Подтверждает бронирование
  Future<void> _confirmBooking(Booking booking) async {
    try {
      // Обновляем статус бронирования на "ожидает оплаты"
      final success = await _bookingService.confirmBooking(booking.id);

      if (success) {
        // Обновляем список бронирований
        await _loadData();

        // Показываем сообщение об успехе
        _showSnackBar('Бронирование подтверждено, ожидает оплаты');

        // Переключаемся на вкладку "Активные" (где теперь будет отображаться бронирование)
        _tabController.animateTo(
          0,
        ); // Индекс 0 соответствует вкладке "Активные"
      } else {
        _showSnackBar('Ошибка при подтверждении бронирования');
      }
    } catch (e) {
      _showSnackBar('Ошибка при подтверждении бронирования: ${e.toString()}');
    }
  }

  /// Отклоняет бронирование
  Future<void> _rejectBooking(Booking booking) async {
    try {
      // Обновляем статус бронирования
      final success = await _bookingService.rejectBooking(booking.id);

      if (success) {
        // Обновляем список бронирований
        await _loadData();

        // Показываем сообщение об успехе
        _showSnackBar('Бронирование отклонено');

        // Остаемся на текущей вкладке, так как отклоненные бронирования не отображаются в списке
      } else {
        _showSnackBar('Ошибка при отклонении бронирования');
      }
    } catch (e) {
      _showSnackBar('Ошибка при отклонении бронирования: ${e.toString()}');
    }
  }

  /// Отменяет бронирование
  Future<void> _cancelBooking(Booking booking) async {
    try {
      // Обновляем статус бронирования
      await _bookingService.cancelBooking(booking.id);

      // Обновляем список бронирований
      await _loadData();

      // Показываем сообщение об успехе
      _showSnackBar('Бронирование отменено');

      // Остаемся на текущей вкладке, так как отмененные бронирования не отображаются в списке
    } catch (e) {
      _showSnackBar('Ошибка при отмене бронирования: ${e.toString()}');
    }
  }

  /// Завершает бронирование
  Future<void> _completeBooking(Booking booking) async {
    try {
      // Обновляем статус бронирования
      await _bookingService.completeBooking(booking.id);

      // Обновляем список бронирований
      await _loadData();

      // Показываем сообщение об успехе
      _showSnackBar('Бронирование завершено');

      // Если текущая вкладка "Брони", после завершения бронирования
      // оно пропадет из списка, поэтому проверяем, остались ли другие бронирования
      if (_currentFilter == BookingFilterType.booked) {
        final bookedProperties = _getFilteredPropertiesForTab(
          BookingFilterType.booked,
        );
        if (bookedProperties.isEmpty) {
          // Если бронирований не осталось, переключаемся на вкладку "Активные"
          _tabController.animateTo(0);
        }
      }
    } catch (e) {
      _showSnackBar('Ошибка при завершении бронирования: ${e.toString()}');
    }
  }

  /// Показывает диалог подтверждения перед отменой бронирования
  void _showCancellationDialog(Booking booking) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отмена бронирования'),
            content: const Text(
              'Вы уверены, что хотите отменить это бронирование?',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () {
                  context.pop();
                  _cancelBooking(booking);
                },
                child: const Text('Да'),
              ),
            ],
          ),
    );
  }

  /// Показывает диалог подтверждения перед завершением бронирования
  void _showCompletionDialog(Booking booking) {
    // Проверяем, можно ли завершить бронирование
    if (booking.status != BookingStatus.active &&
        booking.status != BookingStatus.paid) {
      // Если бронирование нельзя завершить, показываем сообщение об ошибке
      _showSnackBar(
        'Можно завершить только активное или оплаченное бронирование',
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Завершение бронирования'),
            content: const Text(
              'Вы уверены, что хотите отметить это бронирование как завершенное?',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Нет'),
              ),
              TextButton(
                onPressed: () {
                  context.pop();
                  _completeBooking(booking);
                },
                child: const Text('Да'),
              ),
            ],
          ),
    );
  }

  /// Показывает диалог подтверждения бронирования
  void _showConfirmationDialog(Booking booking) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Подтвердить бронирование'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Вы уверены, что хотите подтвердить бронирование?'),
                const SizedBox(height: 8),
                Text(
                  'После подтверждения статус бронирования изменится на "Ожидает оплаты". '
                  'Клиент получит уведомление с просьбой оплатить бронирование.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 153),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _confirmBooking(booking);
                },
                child: const Text('Подтвердить'),
              ),
            ],
          ),
    );
  }

  /// Показывает диалог отклонения бронирования
  void _showRejectionDialog(Booking booking) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отклонение бронирования'),
            content: const Text(
              'Вы уверены, что хотите отклонить это бронирование?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _rejectBooking(booking);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Отклонить'),
              ),
            ],
          ),
    );
  }

  /// Показывает информацию о клиенте
  void _showUserInfo(User? user) {
    if (user == null) return;

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
                    ).colorScheme.primary.withValues(alpha: 66),
                    child: Text(
                      user.initials,
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
                          user.fullName,
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
                              user.rating.toStringAsFixed(1),
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
                        _contactClient(user.id);
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

  /// Контакт с клиентом
  void _contactClient(String clientId) {
    context.pushNamed('chat', pathParameters: {'chatId': clientId});
  }

  /// Навигация к деталям бронирования
  void _navigateToBookingDetails(String bookingId) {
    context.pushNamed('booking_details', pathParameters: {'id': bookingId});
  }

  /// Навигация к редактированию объекта
  void _navigateToEditProperty(String propertyId) {
    context.pushNamed('edit_property', pathParameters: {'id': propertyId});
  }

  /// Проверяет и обновляет статусы бронирований
  Future<void> _checkAndUpdateBookingStatuses() async {
    if (!mounted) return;

    try {
      // Запускаем обновление просроченных бронирований через сервис
      await _bookingService.checkAndUpdateExpiredBookings();

      // После обновления статусов в БД, перезагружаем данные, если экран все еще активен
      if (mounted) {
        _loadData(); // Перезагружаем все данные
      }
    } catch (e) {
      debugPrint('Ошибка при проверке статусов бронирования владельца: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Мои бронирования',
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_outlined)),
            Tab(icon: Icon(Icons.event_available_outlined)),
            Tab(icon: Icon(Icons.cleaning_services_outlined)),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 179),
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorView(error: _errorMessage!, onRetry: _loadData);
    }

    if (_properties.isEmpty) {
      return EmptyState(
        title: 'Нет объектов',
        message: 'У вас пока нет объектов недвижимости для бронирований',
        icon: Icons.home,
        action: ElevatedButton.icon(
          onPressed: () => context.goNamed('owner_properties'),
          icon: const Icon(Icons.add),
          label: const Text('Добавить объект'),
        ),
      );
    }

    // Предварительно вычисляем результаты для каждой вкладки, чтобы избежать ошибок доступа к пустым массивам
    final activeProperties = _getFilteredPropertiesForTab(
      BookingFilterType.active,
    );
    final bookedProperties = _getFilteredPropertiesForTab(
      BookingFilterType.booked,
    );
    final cleaningProperties = _getFilteredPropertiesForTab(
      BookingFilterType.cleaning,
    );

    debugPrint(
      'Предварительно вычисленные списки - '
      'Активные: ${activeProperties.length}, '
      'Бронирование: ${bookedProperties.length}, '
      'Уборка: ${cleaningProperties.length}',
    );

    return TabBarView(
      controller: _tabController,
      children: [
        // Вкладка "Активные" - объекты с активными бронированиями и запросами на бронирование
        activeProperties.isEmpty
            ? _buildEmptyTabView('Нет активных объектов')
            : _buildPropertiesListView(
              BookingFilterType.active,
              activeProperties,
            ),

        // Вкладка "Брони" - объекты с подтверждёнными и оплаченными бронированиями
        bookedProperties.isEmpty
            ? _buildEmptyTabView('Нет объектов с бронированиями')
            : _buildPropertiesListView(
              BookingFilterType.booked,
              bookedProperties,
            ),

        // Вкладка "Уборка" - объекты в статусе уборки
        cleaningProperties.isEmpty
            ? _buildEmptyTabView(
              'У вас пока нет объектов в статусе уборки',
              icon: Icons.cleaning_services_outlined,
            )
            : _buildPropertiesListView(
              BookingFilterType.cleaning,
              cleaningProperties,
            ),
      ],
    );
  }

  /// Получает предварительно отфильтрованный список объектов для указанной вкладки
  List<PropertyWithBookings> _getFilteredPropertiesForTab(
    BookingFilterType tabType,
  ) {
    // Сохраняем текущий фильтр
    final currentFilter = _currentFilter;

    // Временно устанавливаем фильтр для нужной вкладки
    _currentFilter = tabType;

    // Создаем временный список для фильтрации
    List<PropertyWithBookings> tempFilteredProperties = [];

    // Проверяем, есть ли вообще свойства
    if (_properties.isEmpty) {
      return [];
    }

    // Проверяем каждый объект
    for (final propertyWithBookings in _properties) {
      try {
        // Получаем бронирования для текущего объекта (защита от null)
        final bookings = _propertyBookings[propertyWithBookings.id] ?? [];

        // Применяем фильтр
        List<Booking> filteredBookings = [];

        switch (tabType) {
          case BookingFilterType.active:
            // Во вкладку "Активные" попадают запросы на бронирование (pendingApproval)
            // и подтвержденные, но неоплаченные (confirmed, waitingPayment)
            filteredBookings =
                bookings
                    .where(
                      (b) =>
                          b.status == BookingStatus.pendingApproval ||
                          b.status == BookingStatus.confirmed ||
                          b.status == BookingStatus.waitingPayment,
                    )
                    .toList();

            // Выводим в дебаг информацию о найденных бронированиях в статусе ожидания
            final pendingBookings =
                bookings
                    .where((b) => b.status == BookingStatus.pendingApproval)
                    .toList();

            if (pendingBookings.isNotEmpty) {
              debugPrint(
                'Найдены ожидающие подтверждения бронирования: ${pendingBookings.length}',
              );
              for (var booking in pendingBookings) {
                debugPrint(
                  'Бронирование ${booking.id} от ${booking.clientId} ожидает подтверждения',
                );
              }
            }
            break;
          case BookingFilterType.booked:
            // Во вкладку "Брони" попадают только оплаченные и активные бронирования
            filteredBookings =
                bookings
                    .where(
                      (b) =>
                          b.status == BookingStatus.paid ||
                          b.status == BookingStatus.active,
                    )
                    .toList();
            break;
          case BookingFilterType.cleaning:
            // Для вкладки уборки проверяем статус объекта
            if (propertyWithBookings.status == PropertyStatus.cleaning) {
              // Также проверяем на наличие бронирований, которые завершены
              final completedBookings =
                  bookings
                      .where((b) => b.status == BookingStatus.completed)
                      .toList();

              if (completedBookings.isNotEmpty) {
                tempFilteredProperties.add(
                  PropertyWithBookings(
                    property: propertyWithBookings.property,
                    bookings: completedBookings,
                  ),
                );
              } else {
                // Добавляем объект, даже если бронирований нет
                tempFilteredProperties.add(
                  PropertyWithBookings(
                    property: propertyWithBookings.property,
                    bookings: [],
                  ),
                );
              }
            }
            continue; // Переходим к следующему объекту
        }

        // Добавляем только при наличии бронирований
        if (filteredBookings.isNotEmpty) {
          tempFilteredProperties.add(
            PropertyWithBookings(
              property: propertyWithBookings.property,
              bookings: filteredBookings,
            ),
          );
        }
      } catch (e) {
        debugPrint(
          'Ошибка при фильтрации объекта ${propertyWithBookings.id}: $e',
        );
        // Пропускаем объект в случае ошибки
      }
    }

    // Сортировка: сначала объекты с бронированиями, ожидающими подтверждения
    try {
      tempFilteredProperties.sort((a, b) {
        try {
          // Проверяем наличие запросов на подтверждение
          bool hasRequestsA = a.bookings.any(
            (b) => b.status == BookingStatus.pendingApproval,
          );
          bool hasRequestsB = b.bookings.any(
            (b) => b.status == BookingStatus.pendingApproval,
          );

          if (hasRequestsA && !hasRequestsB) return -1;
          if (!hasRequestsA && hasRequestsB) return 1;

          // Если оба объекта имеют (или не имеют) запросы на подтверждение,
          // сортируем по дате последнего бронирования
          if (a.bookings.isNotEmpty && b.bookings.isNotEmpty) {
            // Сортируем бронирования каждого объекта по дате обновления
            a.bookings.sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
            b.bookings.sort((x, y) => y.updatedAt.compareTo(x.updatedAt));

            // Сравниваем даты самых последних бронирований
            return b.bookings.first.updatedAt.compareTo(
              a.bookings.first.updatedAt,
            );
          }

          // Если у одного объекта есть бронирования, а у другого нет
          if (a.bookings.isNotEmpty) return -1;
          if (b.bookings.isNotEmpty) return 1;

          // Если ни у одного объекта нет бронирований, сортируем по имени
          return a.title.compareTo(b.title);
        } catch (e) {
          debugPrint('Ошибка при сравнении объектов: $e');
          return 0;
        }
      });
    } catch (e) {
      debugPrint('Ошибка при сортировке списка объектов: $e');
    }

    // Восстанавливаем исходный фильтр
    _currentFilter = currentFilter;

    // Выводим отладочную информацию
    debugPrint(
      'Отфильтровано объектов для вкладки $tabType: ${tempFilteredProperties.length}',
    );

    return tempFilteredProperties;
  }

  /// Отображает пустое состояние вкладки с указанным сообщением
  Widget _buildEmptyTabView(
    String message, {
    IconData icon = Icons.home_outlined,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 179),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Отображает список объектов для конкретной вкладки
  Widget _buildPropertiesListView(
    BookingFilterType filterType,
    List<PropertyWithBookings> properties,
  ) {
    // Сначала сортируем сами объекты с бронированиями
    if (filterType == BookingFilterType.active) {
      // Для активных бронирований сначала показываем объекты с запросами на подтверждение
      properties.sort((a, b) {
        // Проверяем, есть ли запросы на подтверждение в объекте A
        bool hasPendingA = a.bookings.any(
          (booking) => booking.status == BookingStatus.pendingApproval,
        );

        // Проверяем, есть ли запросы на подтверждение в объекте B
        bool hasPendingB = b.bookings.any(
          (booking) => booking.status == BookingStatus.pendingApproval,
        );

        // Если A имеет ожидающие запросы, а B нет, то A идет первым
        if (hasPendingA && !hasPendingB) return -1;

        // Если B имеет ожидающие запросы, а A нет, то B идет первым
        if (!hasPendingA && hasPendingB) return 1;

        // Если оба имеют или оба не имеют ожидающих запросов,
        // сортируем по дате последнего обновления бронирований
        if (a.bookings.isNotEmpty && b.bookings.isNotEmpty) {
          a.bookings.sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
          b.bookings.sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
          return b.bookings.first.updatedAt.compareTo(
            a.bookings.first.updatedAt,
          );
        }

        // Если нет бронирований для сравнения, сортируем по имени объекта
        return a.title.compareTo(b.title);
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final propertyWithBookings = properties[index];
          final property = propertyWithBookings.property;
          final bookings = propertyWithBookings.bookings;

          // Если нет бронирований, показываем пустую карточку объекта
          if (bookings.isEmpty) {
            return Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(bottom: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Изображение объекта
                  if (property.imageUrls.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        property.imageUrls.first,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _navigateToEditProperty(property.id),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Редактировать'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          try {
            // Сортируем бронирования в зависимости от типа вкладки
            if (bookings.isNotEmpty) {
              if (filterType == BookingFilterType.active) {
                // Во вкладке "Активные" сначала показываем запросы на бронирование
                bookings.sort((a, b) {
                  if (a.status == BookingStatus.pendingApproval &&
                      b.status != BookingStatus.pendingApproval) {
                    return -1;
                  }
                  if (a.status != BookingStatus.pendingApproval &&
                      b.status == BookingStatus.pendingApproval) {
                    return 1;
                  }
                  // Потом сортируем по дате
                  return b.updatedAt.compareTo(a.updatedAt);
                });
              } else if (filterType == BookingFilterType.booked) {
                // Во вкладке "Брони" сначала показываем активные бронирования
                bookings.sort((a, b) {
                  if (a.status == BookingStatus.active &&
                      b.status != BookingStatus.active) {
                    return -1;
                  }
                  if (a.status != BookingStatus.active &&
                      b.status == BookingStatus.active) {
                    return 1;
                  }
                  // Потом сортируем по дате
                  return b.updatedAt.compareTo(a.updatedAt);
                });
              } else {
                // В остальных вкладках просто сортируем по дате
                bookings.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              }
            }

            // Проверяем, что список не пуст после сортировки
            if (bookings.isEmpty) {
              return const SizedBox.shrink();
            }

            // Берем самое актуальное бронирование для отображения
            final booking = bookings.first;
            final client = _bookingClients[booking.id];

            return UniversalBookingCard(
              booking: booking,
              property: property,
              client: client,
              userRole: UserRole.owner,
              isNew: booking.status == BookingStatus.pendingApproval,
              initiallyExpanded:
                  booking.status == BookingStatus.pendingApproval,
              onTap: () => _navigateToBookingDetails(booking.id),
              // Кнопка подтверждения только для запросов в статусе pendingApproval
              onConfirm:
                  booking.status == BookingStatus.pendingApproval
                      ? () => _showConfirmationDialog(booking)
                      : null,
              // Кнопка отклонения только для запросов в статусе pendingApproval
              onReject:
                  booking.status == BookingStatus.pendingApproval
                      ? () => _showRejectionDialog(booking)
                      : null,
              // Кнопка отмены для определенных статусов
              onCancel:
                  (booking.status == BookingStatus.confirmed ||
                          booking.status == BookingStatus.waitingPayment ||
                          booking.status == BookingStatus.paid)
                      ? () => _showCancellationDialog(booking)
                      : null,
              // Кнопка завершения только для активных бронирований
              onComplete:
                  booking.status == BookingStatus.active
                      ? () => _showCompletionDialog(booking)
                      : null,
              // Кнопка связаться доступна всегда
              onContact: () => _contactClient(booking.clientId),
              onUserTap: () => _showUserInfo(client),
            );
          } catch (e) {
            // Сохраняем обработку ошибок
            debugPrint('Ошибка при создании карточки бронирования: $e');
            return Card(
              color: Colors.red.shade100,
              margin: const EdgeInsets.only(bottom: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ошибка отображения карточки для объекта: ${property.title}',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loadData,
                      child: const Text('Обновить'),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Утилита для форматирования дат
class AppDateUtils {
  static String formatDateWithTime(DateTime dateTime) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return dateFormat.format(dateTime);
  }
}
