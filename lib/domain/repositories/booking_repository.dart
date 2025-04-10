import 'package:pater/domain/entities/booking.dart';

/// Интерфейс репозитория для работы с бронированиями
abstract class BookingRepository {
  /// Получает все бронирования
  Future<List<Booking>> getAllBookings();

  /// Обновляет статус бронирования
  Future<void> updateBookingStatus(String bookingId, BookingStatus status);

  /// Обновляет статус уборки для бронирования
  Future<void> updateCleaningStatus(String bookingId, bool isCompleted);
}
