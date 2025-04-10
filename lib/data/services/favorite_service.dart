import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/saved_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:flutter/foundation.dart';

/// Сервис для работы с избранными объектами недвижимости
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PropertyService _propertyService = PropertyService();
  
  factory FavoriteService() {
    return _instance;
  }
  
  FavoriteService._internal();
  
  /// Получает список избранных объектов пользователя
  Future<List<Property>> getFavoriteProperties(String userId) async {
    try {
      debugPrint('Запрашиваем избранные объекты для пользователя: $userId');
      
      // Получаем ID избранных объектов из коллекции favorites
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('user_id', isEqualTo: userId)
          .get();
      
      debugPrint('Получено ${favoritesSnapshot.docs.length} документов из коллекции favorites');
      
      if (favoritesSnapshot.docs.isEmpty) {
        debugPrint('У пользователя $userId нет объектов в избранном');
        return [];
      }
      
      // Извлекаем идентификаторы избранных объектов
      final propertyIds = favoritesSnapshot.docs
          .map((doc) => doc.data()['property_id'] as String)
          .toList();
      
      debugPrint('Найдено ${propertyIds.length} ID объектов в избранном пользователя $userId: $propertyIds');
      
      // Загружаем данные о каждом объекте
      final properties = <Property>[];
      for (final id in propertyIds) {
        try {
          final property = await _propertyService.getPropertyById(id);
          if (property != null) {
            // Устанавливаем флаг избранного для объекта
            final propertyWithFavorite = property.copyWith(isFavorite: true);
            properties.add(propertyWithFavorite);
            debugPrint('Загружен объект из избранного: ${property.id} - ${property.title}');
          } else {
            debugPrint('Объект с ID $id не найден в базе данных');
            
            // Удаляем несуществующий объект из избранного
            try {
              await removeFromFavorites(userId, id);
              debugPrint('Удален неактуальный объект с ID $id из избранного пользователя $userId');
            } catch (e) {
              debugPrint('Ошибка при удалении неактуального объекта из избранного: $e');
            }
          }
        } catch (e) {
          debugPrint('Ошибка при загрузке объекта с ID $id: $e');
        }
      }
      
      debugPrint('Загружено ${properties.length} избранных объектов');
      return properties;
    } catch (e) {
      debugPrint('Ошибка при загрузке избранных объектов: $e');
      return [];
    }
  }
  
  /// Проверяет, есть ли объект в избранном у пользователя
  Future<bool> isPropertyInFavorites(String userId, String propertyId) async {
    try {
      debugPrint('Проверка наличия объекта $propertyId в избранном пользователя $userId');
      
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('user_id', isEqualTo: userId)
          .where('property_id', isEqualTo: propertyId)
          .get();
      
      final isInFavorites = favoritesSnapshot.docs.isNotEmpty;
      debugPrint('Объект $propertyId ${isInFavorites ? "находится" : "не находится"} в избранном пользователя $userId');
      
      return isInFavorites;
    } catch (e) {
      debugPrint('Ошибка при проверке наличия объекта в избранном: $e');
      return false;
    }
  }
  
  /// Получает список сохраненных поисков пользователя
  Future<List<SavedSearch>> getSavedSearches(String userId) async {
    try {
      debugPrint('Запрашиваем сохраненные поиски для пользователя: $userId');
      
      final savedSearchesSnapshot = await _firestore
          .collection('saved_searches')
          .where('user_id', isEqualTo: userId)
          .get();
      
      debugPrint('Получено ${savedSearchesSnapshot.docs.length} сохраненных поисков');
      
      final savedSearches = savedSearchesSnapshot.docs.map((doc) {
        final data = doc.data();
        return SavedSearch(
          id: doc.id,
          name: data['title'] as String? ?? 'Сохраненный поиск',
          city: data['city'] as String?,
          checkInDate: (data['check_in_date'] as Timestamp?)?.toDate(),
          checkOutDate: (data['check_out_date'] as Timestamp?)?.toDate(),
          guestsCount: data['guests_count'] as int?,
          minPrice: data['min_price'] != null ? (data['min_price'] as num).toDouble() : null,
          maxPrice: data['max_price'] != null ? (data['max_price'] as num).toDouble() : null,
          propertyType: data['property_type'] as String?,
          createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      
      return savedSearches;
    } catch (e) {
      debugPrint('Ошибка при загрузке сохраненных поисков: $e');
      return [];
    }
  }
  
  /// Добавляет объект в избранное
  Future<void> addToFavorites(String userId, String propertyId) async {
    debugPrint('Добавляем объект $propertyId в избранное пользователя $userId');
    
    // Проверяем, что объект существует перед добавлением в избранное
    final property = await _propertyService.getPropertyById(propertyId);
    if (property == null) {
      debugPrint('Объект $propertyId не найден при попытке добавления в избранное');
      throw Exception('Объект не найден');
    }
    
    await _propertyService.addToFavorites(userId, propertyId);
    debugPrint('Объект $propertyId успешно добавлен в избранное пользователя $userId');
  }
  
  /// Удаляет объект из избранного
  Future<void> removeFromFavorites(String userId, String propertyId) async {
    debugPrint('Удаляем объект $propertyId из избранного пользователя $userId');
    await _propertyService.removeFromFavorites(userId, propertyId);
    debugPrint('Объект $propertyId успешно удален из избранного пользователя $userId');
  }
  
  /// Очищает список избранных объектов пользователя
  Future<void> clearFavorites(String userId) async {
    try {
      debugPrint('Очищаем все избранные объекты пользователя $userId');
      
      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (favoritesSnapshot.docs.isEmpty) {
        debugPrint('У пользователя нет объектов в избранном, нечего очищать');
        return;
      }
      
      // Используем пакетную операцию для удаления всех документов
      final batch = _firestore.batch();
      for (final doc in favoritesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('Очищены все избранные объекты пользователя $userId');
    } catch (e) {
      debugPrint('Ошибка при очистке избранного: $e');
      throw Exception('Ошибка при очистке избранного: $e');
    }
  }
  
  /// Сохраняет поисковый запрос
  Future<void> saveSearch(String userId, SavedSearch search) async {
    try {
      await _firestore.collection('saved_searches').add({
        'user_id': userId,
        'title': search.name,
        'city': search.city,
        'check_in_date': search.checkInDate != null ? Timestamp.fromDate(search.checkInDate!) : null,
        'check_out_date': search.checkOutDate != null ? Timestamp.fromDate(search.checkOutDate!) : null,
        'guests_count': search.guestsCount,
        'min_price': search.minPrice,
        'max_price': search.maxPrice,
        'property_type': search.propertyType,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Ошибка при сохранении поискового запроса: $e');
      throw Exception('Не удалось сохранить поисковый запрос');
    }
  }
  
  /// Удаляет сохраненный поисковый запрос
  Future<void> removeSavedSearch(String userId, String searchId) async {
    try {
      await _firestore.collection('saved_searches').doc(searchId).delete();
    } catch (e) {
      debugPrint('Ошибка при удалении сохраненного поиска: $e');
      throw Exception('Не удалось удалить сохраненный поиск');
    }
  }
} 