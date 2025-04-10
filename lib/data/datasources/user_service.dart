import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pater/data/datasources/firebase_connection_service.dart';

/// Сервис для работы с пользователями
class UserService {
  static final UserService _instance = UserService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Коллекция пользователей
  late final CollectionReference<Map<String, dynamic>> _usersCollection;
  
  /// Коллекция отзывов
  late final CollectionReference<Map<String, dynamic>> _reviewsCollection;
  
  factory UserService() {
    return _instance;
  }
  
  UserService._internal() {
    _usersCollection = _firestore.collection('users');
    _reviewsCollection = _firestore.collection('reviews');
    
    // Настройка обработки таймаутов и повторных попыток для Firestore
    _configureFirestoreSettings();
  }
  
  /// Дополнительная настройка Firestore
  void _configureFirestoreSettings() {
    // Увеличиваем таймаут и настраиваем кэширование
    _firestore.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      sslEnabled: true,
      ignoreUndefinedProperties: true,
    );
  }
  
  /// Инициализация сервиса
  Future<void> init() async {
    // Дополнительная инициализация, если потребуется
    try {
      // Проверяем соединение с Firestore с повторными попытками
      await _retryFirestoreOperation(() async {
        await _firestore.collection('system').doc('health').set({
          'lastCheck': FieldValue.serverTimestamp(),
          'status': 'ok'
        });
      });
      debugPrint('Соединение с Firestore установлено успешно');
    } catch (e) {
      debugPrint('Ошибка при инициализации Firestore: $e');
      // Продолжаем работу, даже если есть проблемы с соединением
      // Приложение будет использовать локальный кэш
    }
  }
  
  /// Вспомогательный метод для повторения операций с Firestore при ошибках транспортного уровня
  Future<T> _retryFirestoreOperation<T>(Future<T> Function() operation, {int maxRetries = 5}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await operation();
      } on FirebaseException catch (e) {
        attempts++;
        debugPrint('Ошибка Firestore (попытка $attempts/$maxRetries): ${e.code} - ${e.message}');
        
        // Ошибки CORS и транспортного уровня
        bool isNetworkError = e.code == 'unavailable' || 
            e.code == 'deadline-exceeded' || 
            e.code == 'failed-precondition' || 
            e.message?.contains('transport') == true ||
            e.message?.contains('WebChannelConnection') == true;
            
        if (isNetworkError) {
          // Если произошла ошибка WebChannelConnection, пытаемся восстановить соединение
          if (e.message?.contains('WebChannelConnection') == true) {
            debugPrint('Обнаружена ошибка WebChannelConnection, запрос восстановления соединения...');
            await FirebaseConnectionService().forceReconnect();
          }
          
          // Ждем перед повторной попыткой с увеличением времени ожидания
          await Future.delayed(Duration(milliseconds: 500 * attempts));
          continue;
        }
        
        // Для других ошибок просто пробрасываем исключение
        rethrow;
      } catch (e) {
        attempts++;
        debugPrint('Общая ошибка при работе с Firestore (попытка $attempts/$maxRetries): $e');
        
        // Для неизвестных ошибок тоже делаем повторную попытку
        await Future.delayed(Duration(milliseconds: 500 * attempts));
        
        // Если это последняя попытка - выбрасываем ошибку
        if (attempts >= maxRetries) rethrow;
      }
    }
    
    // Этот код не должен выполниться, но необходим для типизации
    throw Exception('Превышено максимальное число попыток операции Firestore');
  }
  
  /// Получает пользователя по ID с обработкой ошибок сети
  Future<User?> getUserById(String id) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(id)
          .get(GetOptions(source: Source.serverAndCache));
      
      if (docSnapshot.exists) {
        return User.fromJson(docSnapshot.data()!);
      }
      
      return null;
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException при получении пользователя: ${e.code} - ${e.message}');
      
      // При ошибке сети пробуем получить из кэша
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        try {
          final docSnapshot = await _firestore.collection('users').doc(id)
              .get(GetOptions(source: Source.cache));
              
          if (docSnapshot.exists) {
            debugPrint('Получены данные пользователя из кэша');
            return User.fromJson(docSnapshot.data()!);
          }
        } catch (cacheError) {
          debugPrint('Ошибка при получении данных из кэша: $cacheError');
        }
      }
      
      throw Exception('Ошибка при получении пользователя: ${e.message}');
    } catch (e) {
      throw Exception('Ошибка при получении пользователя: $e');
    }
  }
  
  /// Обновляет данные пользователя
  Future<User> updateUser(User user) async {
    try {
      await _retryFirestoreOperation(() async {
        await _firestore
            .collection('users')
            .doc(user.id)
            .update(user.toJson());
      });
      
      return user;
    } catch (e) {
      throw Exception('Ошибка при обновлении пользователя: $e');
    }
  }
  
  /// Создает нового пользователя
  Future<User> createUser(User user) async {
    try {
      await _retryFirestoreOperation(() async {
        await _firestore
            .collection('users')
            .doc(user.id)
            .set(user.toJson());
      });
      
      return user;
    } catch (e) {
      throw Exception('Ошибка при создании пользователя: $e');
    }
  }
  
  /// Проверяет существование пользователя
  Future<bool> userExists(String id) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(id).get();
      return docSnapshot.exists;
    } catch (e) {
      throw Exception('Ошибка при проверке существования пользователя: $e');
    }
  }
  
  /// Получает текущий баланс пользователя
  Future<double> getUserBalance(String userId) async {
    try {
      final user = await getUserById(userId);
      
      if (user == null) {
        throw Exception('Пользователь не найден');
      }
      
      return user.balance;
    } catch (e) {
      throw Exception('Ошибка при получении баланса пользователя: $e');
    }
  }
  
  /// Обновляет баланс пользователя
  Future<void> updateUserBalance(String userId, double newBalance) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'balance': newBalance});
    } catch (e) {
      throw Exception('Ошибка при обновлении баланса: $e');
    }
  }
  
  /// Получает список пользователей по ролям
  Future<List<User>> getUsersByRole(UserRole role) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role.toString())
          .get();
      
      return querySnapshot.docs
          .map((doc) => User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Ошибка при получении пользователей по роли: $e');
    }
  }
  
  /// Получает список клинеров
  Future<List<User>> getCleaners() async {
    try {
      final querySnapshot = await _usersCollection
          .where('role', isEqualTo: _roleToString(UserRole.cleaner))
          .get();
      
      return querySnapshot.docs
          .map((doc) => _mapDocumentToUser(doc))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении клинеров: $e');
      throw Exception('Не удалось получить список клинеров: $e');
    }
  }
  
  /// Оставляет отзыв о клинере
  Future<void> addReview({
    required String cleanerId,
    required String reviewerId,
    required String requestId,
    required double rating,
    String? text,
  }) async {
    try {
      // Добавляем отзыв
      final reviewId = _firestore.collection('temp').doc().id;
      
      await _reviewsCollection.doc(reviewId).set({
        'cleaner_id': cleanerId,
        'reviewer_id': reviewerId,
        'request_id': requestId,
        'rating': rating,
        'text': text ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Обновляем средний рейтинг клинера
      final cleanerDoc = await _usersCollection.doc(cleanerId).get();
      
      if (cleanerDoc.exists) {
        final data = cleanerDoc.data()!;
        final currentRating = data['rating'] != null
            ? (data['rating'] as num).toDouble()
            : 0.0;
        final reviewsCount = data['reviews_count'] != null
            ? (data['reviews_count'] as num).toInt()
            : 0;
        
        // Вычисляем новый средний рейтинг
        final newRating = (currentRating * reviewsCount + rating) / (reviewsCount + 1);
        
        // Обновляем данные клинера
        await _usersCollection.doc(cleanerId).update({
          'rating': newRating,
          'reviews_count': reviewsCount + 1,
        });
      }
    } catch (e) {
      debugPrint('Ошибка при добавлении отзыва: $e');
      throw Exception('Не удалось добавить отзыв: $e');
    }
  }
  
  /// Получает список отзывов о клинере
  Future<List<Map<String, dynamic>>> getReviewsByCleanerId(String cleanerId) async {
    try {
      final querySnapshot = await _reviewsCollection
          .where('cleaner_id', isEqualTo: cleanerId)
          .orderBy('created_at', descending: true)
          .get();
      
      List<Map<String, dynamic>> reviews = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final reviewerId = data['reviewer_id'] as String;
        
        try {
          // Получаем данные автора отзыва
          final userDoc = await _usersCollection.doc(reviewerId).get();
          
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            
            reviews.add({
              'id': doc.id,
              'cleaner_id': cleanerId,
              'reviewer_id': reviewerId,
              'request_id': data['request_id'],
              'rating': data['rating'],
              'text': data['text'] ?? '',
              'created_at': data['created_at'],
              'reviewer': {
                'id': reviewerId,
                'fullName': userData['full_name'] ?? 'Неизвестный пользователь',
                'avatarUrl': userData['avatar_url'],
              },
            });
          }
        } catch (e) {
          debugPrint('Ошибка при получении данных автора отзыва: $e');
        }
      }
      
      return reviews;
    } catch (e) {
      debugPrint('Ошибка при получении отзывов: $e');
      throw Exception('Не удалось получить отзывы: $e');
    }
  }
  
  /// Преобразует документ Firestore в объект User
  User _mapDocumentToUser(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    final fullName = data['full_name'] as String? ?? 'Неизвестный пользователь';
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : 'Неизвестный';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Пользователь';
    
    return User(
      id: doc.id,
      firstName: firstName,
      lastName: lastName,
      email: data['email'] as String? ?? '',
      phoneNumber: data['phone_number'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      role: _stringToRole(data['role'] as String? ?? 'client'),
      isVerified: data['is_verified'] as bool? ?? false,
      rating: data['rating'] != null ? (data['rating'] as num).toDouble() : 0.0,
      reviewsCount: data['reviews_count'] != null ? (data['reviews_count'] as num).toInt() : 0,
    );
  }
  
  /// Преобразует строку в роль пользователя
  UserRole _stringToRole(String role) {
    switch (role) {
      case 'client':
        return UserRole.client;
      case 'owner':
        return UserRole.owner;
      case 'cleaner':
        return UserRole.cleaner;
      default:
        return UserRole.client;
    }
  }
  
  /// Преобразует роль пользователя в строку
  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'client';
      case UserRole.owner:
        return 'owner';
      case UserRole.cleaner:
        return 'cleaner';
      case UserRole.support:
        return 'support';
    }
  }

  /// Загружает профиль пользователя из Firestore
  Future<User?> getUserProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        return User.fromMap({
          'id': userId,
          ...userDoc.data()!,
        });
      }
      
      return null;
    } catch (e) {
      debugPrint('Ошибка при загрузке профиля: $e');
      return null;
    }
  }

  /// Обновляет профиль пользователя
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(userId).update(userData);
      return true;
    } catch (e) {
      debugPrint('Ошибка при обновлении профиля: $e');
      return false;
    }
  }

  /// Загружает аватар пользователя
  Future<String?> uploadUserAvatar(String userId, String imagePath) async {
    try {
      final storageRef = _storage.ref().child('avatars/$userId.jpg');
      await storageRef.putFile(File(imagePath));
      
      // Проверяем успешность загрузки
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Обновляем профиль пользователя с новым URL аватара
      await _firestore.collection('users').doc(userId).update({
        'avatarUrl': downloadUrl,
      });
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Ошибка при загрузке аватара: $e');
      return null;
    }
  }

  /// Получает список клинеров, отсортированных по рейтингу
  Future<List<User>> getTopCleaners({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.cleaner.toString().split('.').last)
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs
          .map((doc) => User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении списка клинеров: $e');
      return [];
    }
  }
} 