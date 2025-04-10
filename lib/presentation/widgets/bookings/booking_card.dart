import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/presentation/widgets/bookings/booking_status_badge.dart';

/// Карточка для отображения информации о бронировании
class BookingCard extends StatelessWidget {
  final Booking booking;
  final String propertyName;
  final bool isOwner;
  final bool isNew;
  final VoidCallback? onTap;

  const BookingCard({
    super.key,
    required this.booking,
    required this.propertyName,
    this.isOwner = false,
    this.isNew = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Форматирование дат
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final formattedDates = '${dateFormatter.format(booking.checkInDate)} - ${dateFormatter.format(booking.checkOutDate)}';
    
    // Форматирование цены
    final priceFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );
    
    return Card(
      elevation: isNew ? 2 : 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        side: isNew
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Название объекта
              Text(
                propertyName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: AppConstants.paddingXS),
              
              // Даты бронирования
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDates,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Количество гостей
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${booking.guestsCount} ${_getGuestsText(booking.guestsCount)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              // Стоимость
              Row(
                children: [
                  Icon(
                    Icons.payments,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    priceFormatter.format(booking.totalPrice),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Статус бронирования (используем BookingStatusBadge)
              BookingStatusBadge(
                status: booking.status,
                size: BookingStatusBadgeSize.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Возвращает правильное склонение для слова "гость"
  String _getGuestsText(int count) {
    if (count % 100 >= 11 && count % 100 <= 19) {
      return 'гостей';
    }
    
    switch (count % 10) {
      case 1:
        return 'гость';
      case 2:
      case 3:
      case 4:
        return 'гостя';
      default:
        return 'гостей';
    }
  }
} 