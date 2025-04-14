import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';
import 'package:pater/presentation/widgets/bookings/universal_booking_card.dart';
import 'package:pater/domain/entities/user_role.dart';

/// Экран календаря бронирований для владельца
class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({super.key});

  @override
  State<BookingCalendarScreen> createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  final PropertyService _propertyService = PropertyService();
  final BookingService _bookingService = BookingService();

  List<Property> _properties = [];
  List<Booking> _bookings = [];
  Property? _selectedProperty;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Загружает данные о недвижимости и бронированиях
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем недвижимость текущего владельца
      final properties = await _propertyService.getOwnerProperties();

      if (properties.isNotEmpty) {
        final selectedProperty = properties.first;

        // Инициализируем сервис бронирований
        await _bookingService.init();

        // Получаем бронирования для выбранного объекта
        final bookings = await _bookingService.getPropertyBookings(
          selectedProperty.id,
        );

        setState(() {
          _properties = properties;
          _selectedProperty = selectedProperty;
          _bookings = bookings;
        });
      } else {
        setState(() {
          _properties = [];
          _selectedProperty = null;
          _bookings = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Обрабатывает изменение выбранной недвижимости
  Future<void> _onPropertyChanged(Property? property) async {
    if (property == null || property.id == _selectedProperty?.id) return;

    setState(() {
      _isLoading = true;
      _selectedProperty = property;
    });

    try {
      // Инициализируем сервис бронирований, если это еще не сделано
      await _bookingService.init();

      // Получаем бронирования для выбранного объекта
      final bookings = await _bookingService.getPropertyBookings(property.id);

      setState(() {
        _bookings = bookings;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке бронирований: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: CustomAppBar(
        title: 'Календарь бронирований',
        backgroundColor: theme.colorScheme.surface,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _properties.isEmpty
              ? _buildEmptyState(theme)
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Выбор недвижимости
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingL,
                      vertical: AppConstants.paddingM,
                    ),
                    child: _buildPropertySelector(theme),
                  ),

                  // Календарь
                  _buildCalendar(theme),

                  // Список бронирований на выбранный день
                  Expanded(child: _buildBookingsList(theme)),
                ],
              ),
    );
  }

  /// Строит выбор недвижимости
  Widget _buildPropertySelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите объект',
          style: TextStyle(
            fontSize: AppConstants.fontSizeBody,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppConstants.paddingS),
        DropdownButtonFormField<Property>(
          value: _selectedProperty,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingM,
              vertical: AppConstants.paddingS,
            ),
          ),
          items:
              _properties.map((property) {
                return DropdownMenuItem<Property>(
                  value: property,
                  child: Text(property.title, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
          onChanged: (Property? property) => _onPropertyChanged(property),
        ),
      ],
    );
  }

  /// Строит календарь
  Widget _buildCalendar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingM),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          child: TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary),
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              formatButtonTextStyle: TextStyle(
                color: theme.colorScheme.primary,
              ),
              formatButtonShowsNext: false,
            ),
          ),
        ),
      ),
    );
  }

  /// Строит список бронирований на выбранный день
  Widget _buildBookingsList(ThemeData theme) {
    final bookingsForSelectedDay =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingL,
        vertical: AppConstants.paddingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedDay != null
                ? 'Бронирования на ${DateFormat('dd.MM.yyyy').format(_selectedDay!)}'
                : 'Выберите дату для просмотра бронирований',
            style: TextStyle(
              fontSize: AppConstants.fontSizeBody,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppConstants.paddingM),
          Expanded(
            child:
                bookingsForSelectedDay.isEmpty
                    ? Center(
                      child: Text(
                        'Нет бронирований на выбранную дату',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    )
                    : ListView.separated(
                      itemCount: bookingsForSelectedDay.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final booking = bookingsForSelectedDay[index];
                        return _buildBookingCard(theme, booking);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// Строит карточку бронирования
  Widget _buildBookingCard(ThemeData theme, Booking booking) {
    if (_selectedProperty == null) return const SizedBox.shrink();

    return UniversalBookingCard(
      booking: booking,
      property: _selectedProperty!,
      userRole: UserRole.owner,
      initiallyExpanded: false,
      onTap: () {},
      onConfirm:
          booking.status == BookingStatus.pendingApproval
              ? () => _updateBookingStatus(booking, BookingStatus.confirmed)
              : null,
      onReject:
          booking.status == BookingStatus.pendingApproval
              ? () =>
                  _updateBookingStatus(booking, BookingStatus.rejectedByOwner)
              : null,
      onCancel:
          (booking.status == BookingStatus.confirmed ||
                  booking.status == BookingStatus.waitingPayment ||
                  booking.status == BookingStatus.paid)
              ? () => _updateBookingStatus(booking, BookingStatus.cancelled)
              : null,
      onComplete:
          booking.status == BookingStatus.active
              ? () => _updateBookingStatus(booking, BookingStatus.completed)
              : null,
    );
  }

  /// Обновляет статус бронирования
  Future<void> _updateBookingStatus(
    Booking booking,
    BookingStatus newStatus,
  ) async {
    try {
      await _bookingService.updateBookingStatus(booking.id, newStatus);

      // Обновляем список бронирований
      final updatedBookings = await _bookingService.getPropertyBookings(
        _selectedProperty!.id,
      );

      setState(() {
        _bookings = updatedBookings;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус бронирования обновлен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении статуса: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Возвращает события (бронирования) для указанного дня
  List<Booking> _getEventsForDay(DateTime day) {
    if (_selectedProperty == null || _bookings.isEmpty) return [];

    return _bookings.where((booking) {
      final checkInDate = DateTime(
        booking.checkInDate.year,
        booking.checkInDate.month,
        booking.checkInDate.day,
      );
      final checkOutDate = DateTime(
        booking.checkOutDate.year,
        booking.checkOutDate.month,
        booking.checkOutDate.day,
      );
      final currentDate = DateTime(day.year, day.month, day.day);

      // Проверяем, попадает ли текущая дата в диапазон бронирования
      return (currentDate.isAtSameMomentAs(checkInDate) ||
              currentDate.isAfter(checkInDate)) &&
          (currentDate.isAtSameMomentAs(checkOutDate) ||
              currentDate.isBefore(checkOutDate));
    }).toList();
  }

  /// Строит состояние при отсутствии объектов
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_outlined,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.paddingM),
          Text(
            'У вас пока нет объектов',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingS),
          Text(
            'Добавьте объект недвижимости, чтобы\nуправлять бронированиями',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: AppConstants.fontSizeBody,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingL),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/profile/property_edit');
            },
            icon: const Icon(Icons.add),
            label: const Text('Добавить объект'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingL,
                vertical: AppConstants.paddingM,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
