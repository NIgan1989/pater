import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/domain/entities/review.dart';

/// Сервис для работы с отзывами
class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Получает отзывы для объекта недвижимости
  Future<List<Review>> getReviewsForProperty(
    String propertyId,
    AuthService authService,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .doc(propertyId)
              .collection('reviews')
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Review.fromJson({'id': doc.id, ...data});
      }).toList();
    } catch (e) {
      debugPrint('Ошибка при получении отзывов: $e');
      return [];
    }
  }

  /// Добавляет отзыв для объекта недвижимости
  Future<void> addReview({
    required String propertyId,
    required String userId,
    required String text,
    required double rating,
  }) async {
    try {
      await _firestore
          .collection('properties')
          .doc(propertyId)
          .collection('reviews')
          .add({
            'userId': userId,
            'text': text,
            'rating': rating,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Обновляем средний рейтинг объекта
      await _updatePropertyRating(propertyId);
    } catch (e) {
      debugPrint('Ошибка при добавлении отзыва: $e');
      rethrow;
    }
  }

  /// Обновляет отзыв
  Future<void> updateReview({
    required String propertyId,
    required String reviewId,
    String? text,
    double? rating,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (text != null) updateData['text'] = text;
      if (rating != null) updateData['rating'] = rating;

      await _firestore
          .collection('properties')
          .doc(propertyId)
          .collection('reviews')
          .doc(reviewId)
          .update(updateData);

      // Обновляем средний рейтинг объекта
      await _updatePropertyRating(propertyId);
    } catch (e) {
      debugPrint('Ошибка при обновлении отзыва: $e');
      rethrow;
    }
  }

  /// Удаляет отзыв
  Future<void> deleteReview({
    required String propertyId,
    required String reviewId,
  }) async {
    try {
      await _firestore
          .collection('properties')
          .doc(propertyId)
          .collection('reviews')
          .doc(reviewId)
          .delete();

      // Обновляем средний рейтинг объекта
      await _updatePropertyRating(propertyId);
    } catch (e) {
      debugPrint('Ошибка при удалении отзыва: $e');
      rethrow;
    }
  }

  /// Обновляет средний рейтинг объекта недвижимости
  Future<void> _updatePropertyRating(String propertyId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .doc(propertyId)
              .collection('reviews')
              .get();

      final reviews = querySnapshot.docs;
      final int reviewsCount = reviews.length;

      if (reviewsCount == 0) {
        await _firestore.collection('properties').doc(propertyId).update({
          'rating': 0.0,
          'reviewsCount': 0,
        });
        return;
      }

      // Вычисляем средний рейтинг
      double totalRating = 0;
      for (final review in reviews) {
        totalRating += (review.data()['rating'] as num).toDouble();
      }

      final double averageRating = totalRating / reviewsCount;

      await _firestore.collection('properties').doc(propertyId).update({
        'rating': averageRating,
        'reviewsCount': reviewsCount,
      });
    } catch (e) {
      debugPrint('Ошибка при обновлении рейтинга объекта: $e');
    }
  }
}
