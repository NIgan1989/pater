import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/core/theme/app_text_styles.dart';

/// Современный виджет таймера обратного отсчета для бронирований
class BookingTimer extends StatefulWidget {
  /// Бронирование, для которого отображается таймер
  final Booking booking;

  /// Колбэк для отмены бронирования
  final VoidCallback? onCancel;

  /// Колбэк для завершения бронирования
  final VoidCallback? onComplete;

  const BookingTimer({
    super.key,
    required this.booking,
    this.onCancel,
    this.onComplete,
  });

  @override
  State<BookingTimer> createState() => _BookingTimerState();
}

class _BookingTimerState extends State<BookingTimer>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isActive = false;
  double _progress = 0.0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppConstants.animationDurationMedium,
    );
    _calculateRemainingTime();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Рассчитывает прогресс для визуального отображения (время на оплату варьируется)
  void _calculateRemainingTimeForPayment(DateTime expirationTime) {
    final now = DateTime.now();
    if (now.isBefore(expirationTime)) {
      _remainingTime = expirationTime.difference(now);
      _isActive = false;

      // Определяем общую продолжительность таймера для расчета прогресса
      Duration totalDuration;

      // Если это почасовое бронирование на 2 часа или меньше - 15 минут на оплату
      if (widget.booking.isHourly && widget.booking.durationHours <= 2) {
        totalDuration = const Duration(minutes: 15);
      } else if (now.difference(widget.booking.approvedAt!).inHours < 24) {
        // Если прошло меньше 24 часов с момента подтверждения, используем фактическое время
        totalDuration = expirationTime.difference(widget.booking.approvedAt!);
      } else {
        // По умолчанию - 24 часа
        totalDuration = const Duration(hours: 24);
      }

      // Рассчитываем прогресс (сколько времени прошло по отношению к общему времени)
      final elapsedTime = totalDuration - _remainingTime;
      _progress =
          elapsedTime.inSeconds /
          totalDuration.inSeconds.clamp(1, double.infinity);
    }
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();

    // Проверяем статус для таймера подтверждения/оплаты
    if (widget.booking.status == BookingStatus.pendingApproval) {
      final expirationTime = widget.booking.getApprovalExpirationTime();
      if (now.isBefore(expirationTime)) {
        _remainingTime = expirationTime.difference(now);
        _isActive = false;

        // Рассчитываем прогресс для визуального отображения
        final totalDuration = expirationTime.difference(
          widget.booking.createdAt,
        );
        _progress =
            1.0 -
            (_remainingTime.inSeconds /
                totalDuration.inSeconds.clamp(1, double.infinity));
        return;
      }
    } else if (widget.booking.status == BookingStatus.waitingPayment &&
        widget.booking.approvedAt != null) {
      final expirationTime = widget.booking.getPaymentExpirationTime();
      // Используем специальный метод для расчета времени оплаты
      if (now.isBefore(expirationTime)) {
        _calculateRemainingTimeForPayment(expirationTime);
        return;
      }
    }

    // Если нет активного таймера подтверждения/оплаты, проверяем даты заезда/выезда
    if (now.isBefore(widget.booking.checkInDate)) {
      // Время до начала бронирования
      _remainingTime = widget.booking.checkInDate.difference(now);
      _isActive = false;

      // Рассчитываем прогресс (за 24 часа до заезда)
      final totalDuration = const Duration(hours: 24);
      if (_remainingTime < totalDuration) {
        _progress = 1.0 - (_remainingTime.inSeconds / totalDuration.inSeconds);
      } else {
        _progress = 0.0;
      }
    } else if (now.isBefore(widget.booking.checkOutDate)) {
      // Время до окончания бронирования
      _remainingTime = widget.booking.checkOutDate.difference(now);
      _isActive = true;

      // Рассчитываем прогресс на основе общей продолжительности бронирования
      final totalDuration = widget.booking.checkOutDate.difference(
        widget.booking.checkInDate,
      );
      final elapsed = now.difference(widget.booking.checkInDate);
      _progress =
          elapsed.inSeconds / totalDuration.inSeconds.clamp(1, double.infinity);
    } else {
      // Бронирование завершено
      _remainingTime = Duration.zero;
      _isActive = false;
      _progress = 1.0;

      // Вызываем колбэк завершения только если статус бронирования подходящий
      // и только если бронирование не завершено
      if (widget.onComplete != null &&
          (widget.booking.status == BookingStatus.active ||
              widget.booking.status == BookingStatus.paid) &&
          widget.booking.status != BookingStatus.completed) {
        widget.onComplete!();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _calculateRemainingTime();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    Duration? remaining;
    String text = '';
    String statusText = '';

    if (widget.booking.status == BookingStatus.pendingApproval) {
      final expirationTime = widget.booking.getApprovalExpirationTime();
      if (now.isBefore(expirationTime)) {
        remaining = expirationTime.difference(now);
        text = 'Ожидание';
        statusText = 'Владелец рассматривает запрос';
      }
    } else if (widget.booking.status == BookingStatus.waitingPayment &&
        widget.booking.approvedAt != null) {
      final expirationTime = widget.booking.getPaymentExpirationTime();
      if (now.isBefore(expirationTime)) {
        remaining = expirationTime.difference(now);
        text = 'Оплата';
        statusText = 'Необходимо оплатить бронирование';
      }
    }

    // Если таймер для подтверждения/оплаты не активен, используем _remainingTime и _isActive
    if (remaining == null) {
      if (_remainingTime.inSeconds > 0) {
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 0.0,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(
                  red: theme.colorScheme.primary.r,
                  green: theme.colorScheme.primary.g,
                  blue: theme.colorScheme.primary.b,
                  alpha: 0.3 * 255,
                ),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            red: theme.colorScheme.primary.r,
                            green: theme.colorScheme.primary.g,
                            blue: theme.colorScheme.primary.b,
                            alpha: 0.2 * 255,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isActive ? Icons.timer : Icons.av_timer,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isActive ? 'Идёт бронирование' : 'До начала',
                              style: AppTextStyles.bookingStatus(context),
                            ),
                            Text(
                              _isActive
                                  ? 'Осталось времени до выезда'
                                  : 'Времени до заезда',
                              style: AppTextStyles.bookingStatusDescription(
                                context,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Линейный индикатор прогресса с анимацией
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            red: theme.colorScheme.primary.r,
                            green: theme.colorScheme.primary.g,
                            blue: theme.colorScheme.primary.b,
                            alpha: 0.12 * 255,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      if (_progress > 0.05 && _progress < 0.95)
                        Positioned(
                          left:
                              MediaQuery.of(context).size.width *
                                  _progress *
                                  0.8 -
                              6,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                red: 255.0,
                                green: 255.0,
                                blue: 255.0,
                                alpha: 0.7 * 255,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Показываем время в современном стиле с теневыми блоками
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTimeBlock(
                          _remainingTime.inDays > 0
                              ? _remainingTime.inDays.toString()
                              : _remainingTime.inHours.toString().padLeft(
                                2,
                                '0',
                              ),
                          'часов',
                          theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        ':',
                        style: AppTextStyles.timerValue(
                          context,
                        ).copyWith(fontSize: 18),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildTimeBlock(
                          _remainingTime.inMinutes
                              .remainder(60)
                              .toString()
                              .padLeft(2, '0'),
                          'минут',
                          theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        ':',
                        style: AppTextStyles.timerValue(
                          context,
                        ).copyWith(fontSize: 18),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildTimeBlock(
                          _remainingTime.inSeconds
                              .remainder(60)
                              .toString()
                              .padLeft(2, '0'),
                          'секунд',
                          theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!_isActive && widget.onCancel != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Отменить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade600),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                if (_isActive && widget.onComplete != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onComplete,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Завершить'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppConstants.darkBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    }

    // Для таймеров подтверждения/оплаты - полностью обновленный современный дизайн
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0.0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(
              red: theme.colorScheme.primary.r,
              green: theme.colorScheme.primary.g,
              blue: theme.colorScheme.primary.b,
              alpha: 0.3 * 255,
            ),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(
                        red: theme.colorScheme.primary.r,
                        green: theme.colorScheme.primary.g,
                        blue: theme.colorScheme.primary.b,
                        alpha: 0.2 * 255,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      text == 'Ожидание' ? Icons.hourglass_top : Icons.payments,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text, style: AppTextStyles.bookingStatus(context)),
                        Text(
                          statusText,
                          style: AppTextStyles.bookingStatusDescription(
                            context,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Линейный индикатор прогресса с анимацией
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        red: theme.colorScheme.primary.r,
                        green: theme.colorScheme.primary.g,
                        blue: theme.colorScheme.primary.b,
                        alpha: 0.12 * 255,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  if (_progress > 0.05 && _progress < 0.95)
                    Positioned(
                      left:
                          MediaQuery.of(context).size.width * _progress * 0.8 -
                          6,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            red: 255.0,
                            green: 255.0,
                            blue: 255.0,
                            alpha: 0.7 * 255,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Цифровой таймер в современном стиле
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTimeBlock(
                      remaining.inDays > 0
                          ? remaining.inDays.toString()
                          : remaining.inHours.toString().padLeft(2, '0'),
                      'часов',
                      theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    ':',
                    style: AppTextStyles.timerValue(
                      context,
                    ).copyWith(fontSize: 18),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildTimeBlock(
                      remaining.inMinutes
                          .remainder(60)
                          .toString()
                          .padLeft(2, '0'),
                      'минут',
                      theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    ':',
                    style: AppTextStyles.timerValue(
                      context,
                    ).copyWith(fontSize: 18),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildTimeBlock(
                      remaining.inSeconds
                          .remainder(60)
                          .toString()
                          .padLeft(2, '0'),
                      'секунд',
                      theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            if (widget.onCancel != null && text == 'Ожидание')
              Padding(
                padding: const EdgeInsets.only(
                  top: 16.0,
                  left: 16.0,
                  right: 16.0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Отменить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade600),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Строит блок времени для таймера
  Widget _buildTimeBlock(String value, String label, Color color) {
    // Правильное определение текста подписи в зависимости от типа
    String updatedLabel = label;
    if (label == 'часов' && value.length <= 2) {
      if (value == '01' || value == '21') {
        updatedLabel = 'час';
      } else if ((int.tryParse(value) ?? 0) >= 2 &&
              (int.tryParse(value) ?? 0) <= 4 ||
          (int.tryParse(value) ?? 0) >= 22 &&
              (int.tryParse(value) ?? 0) <= 24) {
        updatedLabel = 'часа';
      }
    } else if (label == 'минут') {
      final intValue = int.tryParse(value) ?? 0;
      if (intValue % 10 == 1 && intValue != 11) {
        updatedLabel = 'минута';
      } else if ((intValue % 10 >= 2 && intValue % 10 <= 4) &&
          (intValue < 10 || intValue > 20)) {
        updatedLabel = 'минуты';
      }
    } else if (label == 'секунд') {
      final intValue = int.tryParse(value) ?? 0;
      if (intValue % 10 == 1 && intValue != 11) {
        updatedLabel = 'секунда';
      } else if ((intValue % 10 >= 2 && intValue % 10 <= 4) &&
          (intValue < 10 || intValue > 20)) {
        updatedLabel = 'секунды';
      }
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
          margin: const EdgeInsets.symmetric(horizontal: 0.0),
          decoration: BoxDecoration(
            color: color.withValues(
              red: color.r,
              green: color.g,
              blue: color.b,
              alpha: 0.85 * 255,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  red: 0.0,
                  green: 0.0,
                  blue: 0.0,
                  alpha: 0.05 * 255,
                ),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.timerValue(context),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          updatedLabel,
          style: AppTextStyles.timerLabel(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
