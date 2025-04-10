import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pater/data/providers/booking_repository_provider.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/repositories/booking_repository.dart';

/// Сервис для управления таймерами и автоматическими действиями
class TimerService {
  static final TimerService _instance = TimerService._internal();

  /// Таймер для проверки бронирований
  Timer? _bookingCheckTimer;

  /// Таймер для проверки уборки
  Timer? _cleaningCheckTimer;

  /// Репозиторий бронирований
  late final BookingRepository _bookingRepository;

  /// Приватный конструктор
  TimerService._internal();

  /// Фабричный конструктор
  factory TimerService(Ref ref) {
    _instance._bookingRepository = ref.read(bookingRepositoryProvider);
    return _instance;
  }

  /// Инициализирует сервис
  void initialize() {
    _startBookingCheckTimer();
    _startCleaningCheckTimer();
  }

  /// Освобождает ресурсы
  void dispose() {
    _bookingCheckTimer?.cancel();
    _cleaningCheckTimer?.cancel();
  }

  void _startBookingCheckTimer() {
    _bookingCheckTimer?.cancel();
    _bookingCheckTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _checkBookings(),
    );
  }

  void _startCleaningCheckTimer() {
    _cleaningCheckTimer?.cancel();
    _cleaningCheckTimer = Timer.periodic(
      const Duration(hours: 2),
      (_) => _checkCleaningStatus(),
    );
  }

  Future<void> _checkBookings() async {
    final now = DateTime.now();
    final bookings = await _bookingRepository.getAllBookings();

    for (final booking in bookings) {
      // Проверяем просроченные бронирования
      if (booking.status == BookingStatus.pending &&
          now.isAfter(booking.checkInDate)) {
        await _bookingRepository.updateBookingStatus(
          booking.id,
          BookingStatus.expired,
        );
      }

      // Проверяем завершенные бронирования
      if (booking.status == BookingStatus.active &&
          now.isAfter(booking.checkOutDate)) {
        await _bookingRepository.updateBookingStatus(
          booking.id,
          BookingStatus.completed,
        );
      }
    }
  }

  Future<void> _checkCleaningStatus() async {
    final now = DateTime.now();
    final bookings = await _bookingRepository.getAllBookings();

    for (final booking in bookings) {
      if (booking.status == BookingStatus.completed &&
          !booking.isCleaningCompleted &&
          now.difference(booking.checkOutDate).inHours >= 24) {
        await _bookingRepository.updateCleaningStatus(booking.id, true);
      }
    }
  }
}
