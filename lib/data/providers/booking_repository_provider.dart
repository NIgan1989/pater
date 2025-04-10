import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pater/data/repositories/booking_repository_impl.dart';
import 'package:pater/domain/repositories/booking_repository.dart';

/// Провайдер для репозитория бронирований
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return BookingRepositoryImpl(firestore);
});
