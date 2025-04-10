import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/repositories/booking_repository.dart';

/// Реализация репозитория для работы с бронированиями через Firebase
class BookingRepositoryImpl implements BookingRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'bookings';

  BookingRepositoryImpl(this._firestore);

  @override
  Future<List<Booking>> getAllBookings() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Booking.fromJson(data);
    }).toList();
  }

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'status': status.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateCleaningStatus(String bookingId, bool isCompleted) async {
    await _firestore.collection(_collection).doc(bookingId).update({
      'isCleaningCompleted': isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
