import 'package:flutter/material.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Размеры бейджа со статусом
enum BookingStatusBadgeSize { small, medium, large }

/// Красивый бейдж для отображения статуса бронирования
class BookingStatusBadge extends StatelessWidget {
  /// Статус бронирования
  final BookingStatus status;

  /// Размер бейджа
  final BookingStatusBadgeSize size;

  /// Конструктор
  const BookingStatusBadge({
    super.key,
    required this.status,
    this.size = BookingStatusBadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = _getBackgroundColor(status);
    final TextStyle textStyle = _getTextStyle(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getPaddingHorizontal(),
        vertical: _getPaddingVertical(),
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_getBorderRadius()),
      ),
      child: Text(_getStatusText(status), style: textStyle),
    );
  }

  /// Получает горизонтальный отступ в зависимости от размера
  double _getPaddingHorizontal() {
    switch (size) {
      case BookingStatusBadgeSize.small:
        return 6.0;
      case BookingStatusBadgeSize.medium:
        return 10.0;
      case BookingStatusBadgeSize.large:
        return 14.0;
    }
  }

  /// Получает вертикальный отступ в зависимости от размера
  double _getPaddingVertical() {
    switch (size) {
      case BookingStatusBadgeSize.small:
        return 2.0;
      case BookingStatusBadgeSize.medium:
        return 4.0;
      case BookingStatusBadgeSize.large:
        return 6.0;
    }
  }

  /// Получает радиус границы в зависимости от размера
  double _getBorderRadius() {
    switch (size) {
      case BookingStatusBadgeSize.small:
        return 4.0;
      case BookingStatusBadgeSize.medium:
        return 6.0;
      case BookingStatusBadgeSize.large:
        return 8.0;
    }
  }

  /// Получает цвет фона для статуса бронирования
  Color _getBackgroundColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pendingApproval:
        return AppConstants.orange;
      case BookingStatus.waitingPayment:
        return AppConstants.darkBlue;
      case BookingStatus.paid:
        return AppConstants.green;
      case BookingStatus.active:
        return AppConstants.green;
      case BookingStatus.completed:
        return Colors.grey.shade700;
      case BookingStatus.cancelled:
      case BookingStatus.cancelledByClient:
        return Colors.red.shade600;
      case BookingStatus.rejectedByOwner:
        return Colors.red.shade900;
      case BookingStatus.expired:
        return Colors.grey.shade600;
      case BookingStatus.pending:
      case BookingStatus.confirmed:
        return Colors.grey;
    }
  }

  /// Получает текстовый стиль для бейджа
  TextStyle _getTextStyle(BuildContext context) {
    // Для всех статусов используем белый текст, чтобы обеспечить хороший контраст с фоном
    return TextStyle(
      color: Colors.white,
      fontSize: _getFontSize(),
      fontWeight: FontWeight.bold,
    );
  }

  /// Получает размер шрифта в зависимости от размера бейджа
  double _getFontSize() {
    switch (size) {
      case BookingStatusBadgeSize.small:
        return 10.0;
      case BookingStatusBadgeSize.medium:
        return 12.0;
      case BookingStatusBadgeSize.large:
        return 14.0;
    }
  }

  /// Получает текст статуса бронирования
  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pendingApproval:
        return 'На рассмотрении';
      case BookingStatus.waitingPayment:
        return 'Ожидает оплаты';
      case BookingStatus.paid:
        return 'Оплачено';
      case BookingStatus.active:
        return 'Активное';
      case BookingStatus.completed:
        return 'Завершено';
      case BookingStatus.cancelled:
      case BookingStatus.cancelledByClient:
        return 'Отменено';
      case BookingStatus.rejectedByOwner:
        return 'Отклонено';
      case BookingStatus.expired:
        return 'Истекло';
      case BookingStatus.pending:
        return 'В ожидании';
      case BookingStatus.confirmed:
        return 'Подтверждено';
    }
  }
}
