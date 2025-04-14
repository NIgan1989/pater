import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pater/presentation/widgets/property/property_image_carousel.dart';
import 'package:pater/presentation/widgets/bookings/booking_timer.dart';

/// Универсальная карточка для отображения информации о бронировании
/// Работает как для клиентов, так и для владельцев жилья
class UniversalBookingCard extends StatefulWidget {
  /// Бронирование
  final Booking booking;

  /// Объект недвижимости
  final Property property;

  /// Данные о клиенте (для владельца)
  final User? client;

  /// Данные о владельце (для клиента)
  final User? owner;

  /// Роль текущего пользователя
  final UserRole userRole;

  /// Флаг нового бронирования (подсветка)
  final bool isNew;

  /// Колбэк при нажатии на карточку
  final VoidCallback? onTap;

  /// Колбэк при нажатии на кнопку подтверждения (для владельца)
  final VoidCallback? onConfirm;

  /// Колбэк при нажатии на кнопку связаться
  final VoidCallback? onContact;

  /// Колбэк при нажатии на кнопку оплатить (для клиента)
  final VoidCallback? onPayment;

  /// Колбэк при нажатии на кнопку отмены
  final VoidCallback? onCancel;

  /// Колбэк при нажатии на кнопку завершения
  final VoidCallback? onComplete;

  /// Колбэк при нажатии на кнопку отклонения (для владельца)
  final VoidCallback? onReject;

  /// Колбэк при нажатии на аватар пользователя
  final VoidCallback? onUserTap;

  /// Инициальное состояние разворачивания
  final bool initiallyExpanded;

  const UniversalBookingCard({
    super.key,
    required this.booking,
    required this.property,
    required this.userRole,
    this.client,
    this.owner,
    this.isNew = false,
    this.onTap,
    this.onConfirm,
    this.onContact,
    this.onPayment,
    this.onCancel,
    this.onComplete,
    this.onReject,
    this.onUserTap,
    this.initiallyExpanded = true,
  });

  @override
  State<UniversalBookingCard> createState() => _UniversalBookingCardState();
}

class _UniversalBookingCardState extends State<UniversalBookingCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwnerView = widget.userRole == UserRole.owner;

    return Card(
      elevation: widget.isNew ? 4 : 2,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side:
            widget.isNew
                ? BorderSide(
                  color: theme.colorScheme.primary.withValues(
                    red: theme.colorScheme.primary.r,
                    green: theme.colorScheme.primary.g,
                    blue: theme.colorScheme.primary.b,
                    alpha: 0.3 * 255,
                  ),
                  width: 2,
                )
                : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Статус бронирования - кликабельный для свернуть/развернуть
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.booking.status).withValues(
                  red: _getStatusColor(widget.booking.status).r,
                  green: _getStatusColor(widget.booking.status).g,
                  blue: _getStatusColor(widget.booking.status).b,
                  alpha: 0.3 * 255,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _getStatusText(widget.booking.status),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _getStatusColor(widget.booking.status),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: _getStatusColor(widget.booking.status),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Минимальная информация (всегда видна)
          if (!_expanded) _buildCollapsedContent(theme, isOwnerView),

          // Развернутое содержимое
          if (_expanded) ...[
            // Изображение объекта
            AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  widget.property.imageUrls.isNotEmpty
                      ? PropertyImageCarousel(
                        imageUrls: widget.property.imageUrls,
                        height: double.infinity,
                        showNavigationButtons: true,
                        showIndicators: true,
                        onImageTap: (index) {
                          // При нажатии на изображение открываем экран просмотра
                          widget.onTap?.call();
                        },
                      )
                      : Container(
                        color: theme.colorScheme.surface.withValues(
                          red: theme.colorScheme.surface.r,
                          green: theme.colorScheme.surface.g,
                          blue: theme.colorScheme.surface.b,
                          alpha: 0.3 * 255,
                        ),
                        child: Icon(
                          Icons.image_not_supported,
                          color: theme.colorScheme.onSurface.withValues(
                            red: theme.colorScheme.onSurface.r,
                            green: theme.colorScheme.onSurface.g,
                            blue: theme.colorScheme.onSurface.b,
                            alpha: 0.3 * 255,
                          ),
                        ),
                      ),
            ),

            // Основная информация
            InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок и цена
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.property.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatPrice(
                            widget.booking.isHourly
                                ? widget.booking.totalPrice
                                : widget.booking.totalPrice /
                                    widget.booking.durationDays,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Таймер на всю ширину карточки
                    if (widget.booking.status ==
                            BookingStatus.pendingApproval ||
                        widget.booking.status == BookingStatus.waitingPayment ||
                        widget.booking.status == BookingStatus.active ||
                        widget.booking.status == BookingStatus.paid)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _buildRemainingTime(context, widget.booking),
                      ),

                    const SizedBox(height: 16),

                    // Информация о клиенте
                    if (isOwnerView && widget.client != null)
                      _buildClientInfo(theme),

                    const SizedBox(height: 16),

                    // Даты и время
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: theme.colorScheme.primary.withValues(
                            red: theme.colorScheme.primary.r,
                            green: theme.colorScheme.primary.g,
                            blue: theme.colorScheme.primary.b,
                            alpha: 0.7 * 255,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'dd.MM.yyyy',
                          ).format(widget.booking.checkInDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              red: theme.colorScheme.onSurface.r,
                              green: theme.colorScheme.onSurface.g,
                              blue: theme.colorScheme.onSurface.b,
                              alpha: 0.7 * 255,
                            ),
                          ),
                        ),
                        Text(
                          ' - ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              red: theme.colorScheme.onSurface.r,
                              green: theme.colorScheme.onSurface.g,
                              blue: theme.colorScheme.onSurface.b,
                              alpha: 0.7 * 255,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat(
                            'dd.MM.yyyy',
                          ).format(widget.booking.checkOutDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              red: theme.colorScheme.onSurface.r,
                              green: theme.colorScheme.onSurface.g,
                              blue: theme.colorScheme.onSurface.b,
                              alpha: 0.7 * 255,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Количество гостей
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: theme.colorScheme.primary.withValues(
                            red: theme.colorScheme.primary.r,
                            green: theme.colorScheme.primary.g,
                            blue: theme.colorScheme.primary.b,
                            alpha: 0.7 * 255,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.booking.guestsCount} ${_getGuestsText(widget.booking.guestsCount)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              red: theme.colorScheme.onSurface.r,
                              green: theme.colorScheme.onSurface.g,
                              blue: theme.colorScheme.onSurface.b,
                              alpha: 0.7 * 255,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Время
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: theme.colorScheme.primary.withValues(
                            red: theme.colorScheme.primary.r,
                            green: theme.colorScheme.primary.g,
                            blue: theme.colorScheme.primary.b,
                            alpha: 0.7 * 255,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('HH:mm').format(widget.booking.checkInDate)} - ${DateFormat('HH:mm').format(widget.booking.checkOutDate)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              red: theme.colorScheme.onSurface.r,
                              green: theme.colorScheme.onSurface.g,
                              blue: theme.colorScheme.onSurface.b,
                              alpha: 0.7 * 255,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Кнопки действий
                    if (_shouldShowActions()) _buildActions(context),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Построение свернутого содержимого карточки
  Widget _buildCollapsedContent(ThemeData theme, bool isOwnerView) {
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Добавляем миниатюру, если есть изображения
            if (widget.property.imageUrls.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.property.imageUrls.first,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                      ),
                      // Индикатор количества изображений
                      if (widget.property.imageUrls.length > 1)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+${widget.property.imageUrls.length - 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.property.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd.MM.yyyy').format(widget.booking.checkInDate)} - ${DateFormat('dd.MM.yyyy').format(widget.booking.checkOutDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        red: theme.colorScheme.onSurface.r,
                        green: theme.colorScheme.onSurface.g,
                        blue: theme.colorScheme.onSurface.b,
                        alpha: 0.3 * 255,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatPrice(widget.booking.totalPrice),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'За ${widget.booking.durationDays} ${_getDaysText(widget.booking.durationDays)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(
                      red: theme.colorScheme.onSurface.r,
                      green: theme.colorScheme.onSurface.g,
                      blue: theme.colorScheme.onSurface.b,
                      alpha: 0.5 * 255,
                    ),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Проверяет, нужно ли показывать кнопки действий
  bool _shouldShowActions() {
    return widget.onConfirm != null ||
        widget.onContact != null ||
        widget.onPayment != null ||
        widget.onCancel != null ||
        widget.onComplete != null ||
        widget.onReject != null;
  }

  /// Построение кнопок действий
  Widget _buildActions(BuildContext context) {
    final now = DateTime.now();
    final hasStarted = now.isAfter(widget.booking.checkInDate);
    final isActive =
        widget.booking.status == BookingStatus.active ||
        widget.booking.status == BookingStatus.paid;

    final theme = Theme.of(context);

    // Проверяем сценарий владельца с кнопками подтверждения/отклонения
    if (widget.userRole == UserRole.owner &&
        widget.booking.status == BookingStatus.pendingApproval &&
        widget.onConfirm != null &&
        widget.onReject != null) {
      return Column(
        children: [
          // Кнопка связаться занимает всю ширину
          if (widget.onContact != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onContact,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Связаться'),
              ),
            ),

          const SizedBox(height: 12),

          // Кнопки подтвердить и отклонить в одном ряду
          Row(
            children: [
              // Кнопка отклонить
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onReject,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    backgroundColor: theme.colorScheme.error.withValues(
                      red: theme.colorScheme.error.r,
                      green: theme.colorScheme.error.g,
                      blue: theme.colorScheme.error.b,
                      alpha: 0.7 * 255,
                    ),
                    foregroundColor: theme.colorScheme.onError,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Отклонить'),
                ),
              ),

              const SizedBox(width: 12),

              // Кнопка подтвердить
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onConfirm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    backgroundColor: theme.colorScheme.primary.withValues(
                      red: theme.colorScheme.primary.r,
                      green: theme.colorScheme.primary.g,
                      blue: theme.colorScheme.primary.b,
                      alpha: 0.2 * 255,
                    ),
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Подтвердить'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Стандартное отображение кнопок
    return Row(
      children: [
        if (widget.onContact != null)
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onContact,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Связаться'),
            ),
          ),

        if (widget.onContact != null &&
            (widget.onConfirm != null ||
                widget.onPayment != null ||
                widget.onCancel != null ||
                widget.onComplete != null ||
                widget.onReject != null))
          const SizedBox(width: 12),

        if (widget.onConfirm != null)
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onConfirm,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: theme.colorScheme.primary.withValues(
                  red: theme.colorScheme.primary.r,
                  green: theme.colorScheme.primary.g,
                  blue: theme.colorScheme.primary.b,
                  alpha: 0.2 * 255,
                ),
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Подтвердить'),
            ),
          ),

        if (widget.onPayment != null)
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onPayment,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Оплатить', style: TextStyle(color: Colors.white)),
            ),
          ),

        // Отображаем кнопку отмены только для неначавшихся бронирований
        if (widget.onCancel != null && !hasStarted && isActive)
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onCancel,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: theme.colorScheme.error.withValues(
                  red: theme.colorScheme.error.r,
                  green: theme.colorScheme.error.g,
                  blue: theme.colorScheme.error.b,
                  alpha: 0.7 * 255,
                ),
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Отменить'),
            ),
          ),

        // Отображаем кнопку завершения только для начавшихся бронирований
        if (widget.onComplete != null && hasStarted && isActive)
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onComplete,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Завершить'),
            ),
          ),

        // Отображаем кнопку отклонения только для запросов на бронирование
        if (widget.onReject != null &&
            widget.booking.status == BookingStatus.pendingApproval)
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onReject,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: theme.colorScheme.error.withValues(
                  red: theme.colorScheme.error.r,
                  green: theme.colorScheme.error.g,
                  blue: theme.colorScheme.error.b,
                  alpha: 0.7 * 255,
                ),
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Отклонить'),
            ),
          ),
      ],
    );
  }

  /// Форматирует цену в удобочитаемом виде
  String _formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    return formatter.format(price);
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

  /// Возвращает правильное склонение для слова "день"
  String _getDaysText(int count) {
    if (count % 100 >= 11 && count % 100 <= 19) {
      return 'дней';
    }

    switch (count % 10) {
      case 1:
        return 'день';
      case 2:
      case 3:
      case 4:
        return 'дня';
      default:
        return 'дней';
    }
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pendingApproval:
        return Colors.green;
      case BookingStatus.waitingPayment:
        return Colors.orange;
      case BookingStatus.paid:
        return Colors.blue;
      case BookingStatus.active:
        return Colors.blue;
      case BookingStatus.completed:
        return Colors.grey;
      case BookingStatus.cancelled:
      case BookingStatus.cancelledByClient:
      case BookingStatus.rejectedByOwner:
        return Colors.red.withValues(
          red: Colors.red.r,
          green: Colors.red.g,
          blue: Colors.red.b,
          alpha: 0.7 * 255,
        );
      case BookingStatus.expired:
        return Colors.red.withValues(
          red: Colors.red.r,
          green: Colors.red.g,
          blue: Colors.red.b,
          alpha: 0.7 * 255,
        );
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pendingApproval:
        return 'Ожидает подтверждения';
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
        return 'Отменено клиентом';
      case BookingStatus.rejectedByOwner:
        return 'Отклонено';
      case BookingStatus.expired:
        return 'Время истекло';
      default:
        return 'Неизвестный статус';
    }
  }

  /// Строит виджет с оставшимся временем
  Widget _buildRemainingTime(BuildContext context, Booking booking) {
    if (booking.status == BookingStatus.pendingApproval ||
        booking.status == BookingStatus.waitingPayment ||
        booking.status == BookingStatus.paid ||
        booking.status == BookingStatus.active) {
      // Используем универсальный компонент таймера для всех случаев
      return BookingTimer(
        booking: booking,
        // Колбэк для отмены - только для клиентов и только для запросов на бронирование
        onCancel:
            widget.userRole == UserRole.owner ||
                    booking.status != BookingStatus.pendingApproval
                ? null
                : widget.onCancel,
        // Колбэк для завершения - только для владельцев и только для активных бронирований
        onComplete:
            widget.userRole != UserRole.owner ||
                    booking.status != BookingStatus.active
                ? null
                : widget.onComplete,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildClientInfo(ThemeData theme) {
    if (widget.client == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          red: theme.colorScheme.surface.r,
          green: theme.colorScheme.surface.g,
          blue: theme.colorScheme.surface.b,
          alpha: 0.2 * 255,
        ),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            red: theme.colorScheme.outline.r,
            green: theme.colorScheme.outline.g,
            blue: theme.colorScheme.outline.b,
            alpha: 0.2 * 255,
          ),
        ),
      ),
      child: InkWell(
        onTap: widget.onUserTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withValues(
                  red: theme.colorScheme.primary.r,
                  green: theme.colorScheme.primary.g,
                  blue: theme.colorScheme.primary.b,
                  alpha: 0.2 * 255,
                ),
                child: Text(
                  widget.client!.initials,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.client!.fullName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          widget.client!.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              red: theme.colorScheme.onSurface.r,
                              green: theme.colorScheme.onSurface.g,
                              blue: theme.colorScheme.onSurface.b,
                              alpha: 0.3 * 255,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(
                  red: theme.colorScheme.onSurface.r,
                  green: theme.colorScheme.onSurface.g,
                  blue: theme.colorScheme.onSurface.b,
                  alpha: 0.3 * 255,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
