import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/data/services/notification_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:pater/domain/entities/cleaning_request.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart';

/// Сервис для управления заявками на уборку
class CleaningService {
  static final CleaningService _instance = CleaningService._internal();
  
  factory CleaningService() {
    return _instance;
  }
  
  CleaningService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final PropertyService _propertyService = PropertyService();
  final UserService _userService = UserService();
  
  /// Инициализирует сервис
  Future<void> init() async {
    try {
      // Проверяем наличие коллекции cleaning_requests
      final requestsRef = _firestore.collection('cleaning_requests');
      final snapshot = await requestsRef.limit(1).get();
      debugPrint('Сервис уборки инициализирован. Заявок в базе: ${snapshot.docs.length}');
    } catch (e) {
      debugPrint('Ошибка при инициализации сервиса уборки: $e');
    }
  }
  
  /// Создает новую заявку на уборку
  Future<CleaningRequest> createCleaningRequest({
    required String propertyId,
    required String ownerId,
    required CleaningType cleaningType,
    required DateTime scheduledDate,
    required double estimatedPrice,
    required String description,
    required String address,
    required String city,
    List<String> additionalServices = const [],
    CleaningUrgency urgency = CleaningUrgency.medium,
  }) async {
    try {
      // Получаем информацию о пользователе
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      // Проверяем, что пользователь является владельцем объекта
      if (user.id != ownerId) {
        throw Exception('Вы не можете создать заявку для объекта, который вам не принадлежит');
      }
      
      // Получаем информацию об объекте
      final property = await _propertyService.getPropertyById(propertyId);
      if (property == null) {
        throw Exception('Объект не найден');
      }
      
      // Создаем новую заявку
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      final request = CleaningRequest(
        id: requestId,
        propertyId: propertyId,
        ownerId: ownerId,
        status: CleaningRequestStatus.active,
        cleaningType: cleaningType,
        scheduledDate: scheduledDate,
        estimatedPrice: estimatedPrice,
        description: description,
        address: address,
        city: city,
        additionalServices: additionalServices,
        urgency: urgency,
        createdAt: DateTime.now(),
      );
      
      // Сохраняем заявку в Firestore
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .set(request.toMap());
      
      // Отправляем уведомления клинерам
      await _notifyCleanersAboutNewRequest(request, property);
      
      return request;
    } catch (e) {
      debugPrint('Ошибка при создании заявки на уборку: $e');
      throw Exception('Не удалось создать заявку на уборку: $e');
    }
  }
  
  /// Получает заявку на уборку по ID
  Future<CleaningRequest?> getCleaningRequestById(String requestId) async {
    try {
      final documentSnapshot = await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .get();
      
      if (documentSnapshot.exists) {
        return CleaningRequest.fromMap(documentSnapshot.data()!);
      }
      
      return null;
    } catch (e) {
      debugPrint('Ошибка при получении заявки на уборку: $e');
      throw Exception('Не удалось получить заявку на уборку: $e');
    }
  }
  
  /// Получает все заявки на уборку владельца
  Future<List<CleaningRequest>> getCleaningRequestsByOwnerId(String ownerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('cleaning_requests')
          .where('owner_id', isEqualTo: ownerId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => CleaningRequest.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении заявок владельца: $e');
      throw Exception('Не удалось получить заявки владельца: $e');
    }
  }
  
  /// Получает активные заявки на уборку клинера
  Future<List<CleaningRequest>> getCleanerActiveRequests(String cleanerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('cleaning_requests')
          .where('cleaner_id', isEqualTo: cleanerId)
          .where('status', whereIn: [
            CleaningRequestStatus.accepted.toString().split('.').last,
            CleaningRequestStatus.inProgress.toString().split('.').last,
          ])
          .get();
      
      return querySnapshot.docs
          .map((doc) => CleaningRequest.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении активных заявок клинера: $e');
      throw Exception('Не удалось получить активные заявки клинера: $e');
    }
  }
  
  /// Получает завершенные заявки на уборку клинера
  Future<List<CleaningRequest>> getCleanerCompletedRequests(String cleanerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('cleaning_requests')
          .where('cleaner_id', isEqualTo: cleanerId)
          .where('status', isEqualTo: CleaningRequestStatus.completed.toString().split('.').last)
          .get();
      
      return querySnapshot.docs
          .map((doc) => CleaningRequest.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении завершенных заявок клинера: $e');
      throw Exception('Не удалось получить завершенные заявки клинера: $e');
    }
  }
  
  /// Получает доступные заявки на уборку (не назначенные ни на кого)
  Future<List<CleaningRequest>> getAvailableCleaningRequests() async {
    try {
      final querySnapshot = await _firestore
          .collection('cleaning_requests')
          .where('status', isEqualTo: CleaningRequestStatus.active.toString().split('.').last)
          .where('cleaner_id', isNull: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => CleaningRequest.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении доступных заявок: $e');
      throw Exception('Не удалось получить доступные заявки: $e');
    }
  }
  
  /// Принимает заявку на уборку (клинером)
  Future<void> acceptCleaningRequest(String requestId, String cleanerId) async {
    try {
      // Получаем текущую заявку
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Проверяем, что заявка в активном состоянии
      if (request.status != CleaningRequestStatus.active) {
        throw Exception('Эта заявка уже не доступна');
      }
      
      // Проверяем, что заявка не назначена на другого клинера
      if (request.cleanerId != null && request.cleanerId != cleanerId) {
        throw Exception('Эта заявка уже назначена на другого клинера');
      }
      
      // Обновляем заявку
      final updatedRequest = request.copyWith(
        cleanerId: cleanerId,
        status: CleaningRequestStatus.accepted,
        approvedAt: DateTime.now(),
      );
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
      // Отправляем уведомление владельцу
      await _notificationService.sendCleaningApprovedNotification(
        requestId: requestId,
        propertyTitle: (await _propertyService.getPropertyById(request.propertyId))?.title ?? 'Объект',
        cleanerId: cleanerId,
      );
      
    } catch (e) {
      debugPrint('Ошибка при принятии заявки на уборку: $e');
      throw Exception('Не удалось принять заявку на уборку: $e');
    }
  }
  
  /// Начинает выполнение уборки
  Future<void> startCleaningRequest(String requestId) async {
    try {
      // Получаем текущую заявку
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Проверяем, что заявка назначена
      if (request.status != CleaningRequestStatus.accepted) {
        throw Exception('Нельзя начать выполнение заявки в текущем статусе');
      }
      
      // Проверяем, что текущий пользователь - клинер для этой заявки
      final user = _authService.currentUser;
      if (user == null || user.id != request.cleanerId) {
        throw Exception('Вы не назначены на эту заявку');
      }
      
      // Обновляем заявку
      final updatedRequest = request.copyWith(
        status: CleaningRequestStatus.inProgress,
        startedAt: DateTime.now(),
      );
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
    } catch (e) {
      debugPrint('Ошибка при начале выполнения уборки: $e');
      throw Exception('Не удалось начать выполнение уборки: $e');
    }
  }
  
  /// Завершает уборку
  Future<void> completeCleaningRequest(String requestId) async {
    try {
      // Получаем текущую заявку
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Проверяем, что заявка в процессе выполнения
      if (request.status != CleaningRequestStatus.inProgress && 
          request.status != CleaningRequestStatus.accepted) {
        throw Exception('Нельзя завершить заявку в текущем статусе');
      }
      
      // Проверяем, что текущий пользователь - клинер для этой заявки
      final user = _authService.currentUser;
      if (user == null || user.id != request.cleanerId) {
        throw Exception('Вы не назначены на эту заявку');
      }
      
      // Обновляем заявку
      final updatedRequest = request.copyWith(
        status: CleaningRequestStatus.completed,
        completedAt: DateTime.now(),
      );
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
      // Обновляем статус объекта
      await _propertyService.updatePropertyStatusAndSubStatus(
        request.propertyId, 
        PropertyStatus.available, 
        PropertySubStatus.none
      );
      
      // Отправляем уведомление владельцу
      final property = await _propertyService.getPropertyById(request.propertyId);
      if (property != null) {
        await _notificationService.sendCleaningCompletedNotification(
          requestId: requestId,
          propertyTitle: property.title,
          ownerId: request.ownerId,
        );
      }
      
    } catch (e) {
      debugPrint('Ошибка при завершении уборки: $e');
      throw Exception('Не удалось завершить уборку: $e');
    }
  }
  
  /// Отменяет заявку на уборку
  Future<void> cancelCleaning(String requestId, String cancellationReason) async {
    try {
      // Получаем текущую заявку
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Проверяем, что заявка в активном состоянии или назначена
      if (request.status != CleaningRequestStatus.active && 
          request.status != CleaningRequestStatus.withOffers &&
          request.status != CleaningRequestStatus.accepted) {
        throw Exception('Нельзя отменить заявку в текущем статусе');
      }
      
      // Получаем текущего пользователя
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      // Проверяем права на отмену (может отменить владелец или клинер, если он назначен)
      if (user.id != request.ownerId && user.id != request.cleanerId) {
        throw Exception('У вас нет прав для отмены этой заявки');
      }
      
      // Обновляем заявку
      final updatedRequest = request.copyWith(
        status: CleaningRequestStatus.cancelled,
        cancelledAt: DateTime.now(),
        cancellationReason: cancellationReason,
      );
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
      // Если это основная заявка после выезда гостей, обновляем статус объекта
      if (request.cleaningType == CleaningType.afterGuests) {
        await _propertyService.updatePropertyStatusAndSubStatus(
          request.propertyId,
          PropertyStatus.available,
          PropertySubStatus.none,
        );
      }
      
      // Отправляем уведомление противоположной стороне
      final property = await _propertyService.getPropertyById(request.propertyId);
      if (property != null) {
        if (user.id == request.ownerId && request.cleanerId != null) {
          // Владелец отменил - уведомляем клинера
          await _notificationService.sendCleaningCancelledNotification(
            requestId: requestId,
            propertyTitle: property.title,
            recipientId: request.cleanerId!,
            cancellationReason: cancellationReason,
          );
        } else if (user.id == request.cleanerId) {
          // Клинер отменил - уведомляем владельца
          await _notificationService.sendCleaningCancelledNotification(
            requestId: requestId,
            propertyTitle: property.title,
            recipientId: request.ownerId,
            cancellationReason: cancellationReason,
          );
        }
      }
      
    } catch (e) {
      debugPrint('Ошибка при отмене заявки на уборку: $e');
      throw Exception('Не удалось отменить заявку на уборку: $e');
    }
  }
  
  /// Обновляет статус заявки на уборку
  Future<void> updateCleaningRequestStatus(String requestId, CleaningRequestStatus newStatus) async {
    try {
      // Получаем текущую заявку
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Обновляем заявку с новым статусом
      final updatedRequest = request.copyWith(
        status: newStatus,
      );
      
      // Дополнительно устанавливаем связанные даты в зависимости от статуса
      switch (newStatus) {
        case CleaningRequestStatus.accepted:
          updatedRequest.copyWith(approvedAt: DateTime.now());
          break;
        case CleaningRequestStatus.inProgress:
          updatedRequest.copyWith(startedAt: DateTime.now());
          break;
        case CleaningRequestStatus.completed:
          updatedRequest.copyWith(completedAt: DateTime.now());
          break;
        case CleaningRequestStatus.cancelled:
          updatedRequest.copyWith(cancelledAt: DateTime.now());
          break;
        default:
          break;
      }
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
    } catch (e) {
      debugPrint('Ошибка при обновлении статуса заявки: $e');
      throw Exception('Не удалось обновить статус заявки: $e');
    }
  }
  
  /// Добавляет рейтинг и отзыв к заявке на уборку
  Future<void> addReviewToCleaningRequest(
    String requestId, 
    double rating, 
    String reviewText
  ) async {
    try {
      // Получаем текущую заявку
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Проверяем, что заявка завершена
      if (request.status != CleaningRequestStatus.completed) {
        throw Exception('Нельзя оставить отзыв для незавершенной заявки');
      }
      
      // Проверяем, что текущий пользователь - владелец объекта
      final user = _authService.currentUser;
      if (user == null || user.id != request.ownerId) {
        throw Exception('Только владелец объекта может оставить отзыв');
      }
      
      // Обновляем заявку
      final updatedRequest = request.copyWith(
        rating: rating,
        reviewText: reviewText,
      );
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
    } catch (e) {
      debugPrint('Ошибка при добавлении отзыва: $e');
      throw Exception('Не удалось добавить отзыв: $e');
    }
  }
  
  /// Отправляет уведомления клинерам о новой заявке
  Future<void> _notifyCleanersAboutNewRequest(CleaningRequest request, Property property) async {
    try {
      // Получаем список клинеров
      final cleanersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: UserRole.cleaner.toString().split('.').last)
          .get();
      
      final cleanerIds = cleanersSnapshot.docs.map((doc) => doc.id).toList();
      
      // Отправляем уведомления
      if (cleanerIds.isNotEmpty) {
        await _notificationService.sendCleaningRequestNotification(
          requestId: request.id,
          propertyTitle: property.title,
          cleanerIds: cleanerIds,
        );
      }
    } catch (e) {
      debugPrint('Ошибка при отправке уведомлений клинерам: $e');
      // Не выбрасываем исключение, чтобы не прерывать основной процесс
    }
  }
  
  /// Получает заявки на уборку по идентификатору клинера
  Future<List<CleaningRequest>> getCleaningRequestsByCleanerId(String cleanerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('cleaning_requests')
          .where('cleaner_id', isEqualTo: cleanerId)
          .orderBy('created_at', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => CleaningRequest.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении заявок по идентификатору клинера: $e');
      throw Exception('Не удалось получить заявки клинера: $e');
    }
  }
  
  /// Создает предложение на выполнение уборки
  Future<void> createOffer(String cleanerId, String requestId, double price, String? message) async {
    try {
      // Получаем текущий запрос
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Проверяем, что заявка в активном состоянии
      if (request.status != CleaningRequestStatus.active && 
          request.status != CleaningRequestStatus.withOffers) {
        throw Exception('Эта заявка не принимает предложения');
      }
      
      // Получаем данные клинера
      final cleaner = await _userService.getUserById(cleanerId);
      if (cleaner == null) {
        throw Exception('Клинер не найден');
      }
      
      // Создаем новое предложение
      final offer = CleaningOffer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cleanerId: cleanerId,
        cleanerName: cleaner.fullName,
        price: price,
        message: message,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      
      // Добавляем предложение к заявке
      List<CleaningOffer> offers = request.offers ?? [];
      offers.add(offer);
      
      // Обновляем статус заявки, если это первое предложение
      CleaningRequestStatus newStatus = request.status;
      if (request.status == CleaningRequestStatus.active) {
        newStatus = CleaningRequestStatus.withOffers;
      }
      
      // Обновляем заявку
      final updatedRequest = request.copyWith(
        offers: offers,
        status: newStatus,
      );
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
      // Отправляем уведомление владельцу
      await _notificationService.sendCleaningOfferNotification(
        requestId: requestId,
        ownerId: request.ownerId,
        cleanerName: cleaner.fullName,
        price: price,
        message: message,
      );
      
    } catch (e) {
      debugPrint('Ошибка при создании предложения на уборку: $e');
      throw Exception('Не удалось создать предложение: $e');
    }
  }
  
  /// Создает автоматическую заявку на уборку после выезда гостей
  Future<CleaningRequest> createAutomaticCleaningRequest(
    String propertyId,
    String ownerId,
  ) async {
    try {
      // Получаем данные объекта
      final property = await _propertyService.getPropertyById(propertyId);
      if (property == null) {
        throw Exception('Объект не найден');
      }
      
      // Генерируем идентификатор
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Создаем заявку на уборку
      final request = CleaningRequest(
        id: id,
        propertyId: propertyId,
        ownerId: ownerId,
        cleanerId: null,
        status: CleaningRequestStatus.active,
        cleaningType: CleaningType.afterGuests,
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
        estimatedPrice: 5000.0, // Стандартная стоимость уборки
        actualPrice: null,
        description: 'Автоматическая заявка на уборку после выезда гостей',
        address: property.address,
        city: property.city,
        additionalServices: [],
        urgency: CleaningUrgency.high,
        offers: [],
        rating: null,
        reviewText: null,
        createdAt: DateTime.now(),
        approvedAt: null,
        startedAt: null,
        completedAt: null,
        cancelledAt: null,
        cancellationReason: null,
      );
      
      // Сохраняем заявку в Firestore
      await _firestore
          .collection('cleaning_requests')
          .doc(id)
          .set(request.toMap());
      
      // Обновляем статус объекта
      await _propertyService.updatePropertyStatusAndSubStatus(
        propertyId,
        PropertyStatus.cleaning,
        PropertySubStatus.waitingCleaning,
      );
      
      // Отправляем уведомление владельцу
      await _notificationService.sendCleaningNeededNotification(
        requestId: id,
        propertyTitle: property.title,
        ownerId: ownerId,
      );
      
      return request;
    } catch (e) {
      debugPrint('Ошибка при создании автоматической заявки на уборку: $e');
      throw Exception('Не удалось создать автоматическую заявку на уборку: $e');
    }
  }
  
  /// Получает активную заявку на уборку для заданного объекта
  Future<CleaningRequest?> getActiveCleaningRequestForProperty(String propertyId) async {
    try {
      final querySnapshot = await _firestore
          .collection('cleaning_requests')
          .where('property_id', isEqualTo: propertyId)
          .where('status', whereIn: [
            CleaningRequestStatus.active.toString().split('.').last,
            CleaningRequestStatus.withOffers.toString().split('.').last,
            CleaningRequestStatus.accepted.toString().split('.').last,
            CleaningRequestStatus.inProgress.toString().split('.').last,
          ])
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      return CleaningRequest.fromMap(querySnapshot.docs.first.data());
    } catch (e) {
      debugPrint('Ошибка при получении активной заявки на уборку: $e');
      return null;
    }
  }
  
  /// Принимает предложение на уборку
  Future<void> acceptOffer(String requestId, String offerId) async {
    try {
      // Получаем текущую заявку
      final request = await getCleaningRequestById(requestId);
      if (request == null) {
        throw Exception('Заявка не найдена');
      }
      
      // Проверяем, что заявка в активном состоянии с предложениями
      if (request.status != CleaningRequestStatus.withOffers && 
          request.status != CleaningRequestStatus.active) {
        throw Exception('Заявка не может принять предложение в текущем статусе');
      }
      
      // Проверяем, что текущий пользователь - владелец объекта
      final user = _authService.currentUser;
      if (user == null || user.id != request.ownerId) {
        throw Exception('Только владелец объекта может принять предложение');
      }
      
      // Ищем предложение с указанным ID
      final offer = request.offers?.firstWhere(
        (o) => o.id == offerId,
        orElse: () => throw Exception('Предложение не найдено'),
      );
      
      if (offer == null) {
        throw Exception('Предложение не найдено');
      }
      
      // Обновляем статусы всех предложений
      final updatedOffers = request.offers?.map((o) {
        if (o.id == offerId) {
          return CleaningOffer(
            id: o.id,
            cleanerId: o.cleanerId,
            cleanerName: o.cleanerName,
            price: o.price,
            message: o.message,
            status: 'accepted',
            createdAt: o.createdAt,
          );
        } else {
          return CleaningOffer(
            id: o.id,
            cleanerId: o.cleanerId,
            cleanerName: o.cleanerName,
            price: o.price,
            message: o.message,
            status: 'rejected',
            createdAt: o.createdAt,
          );
        }
      }).toList() ?? [];
      
      // Обновляем заявку
      final updatedRequest = request.copyWith(
        status: CleaningRequestStatus.accepted,
        cleanerId: offer.cleanerId,
        actualPrice: offer.price,
        offers: updatedOffers,
        approvedAt: DateTime.now(),
      );
      
      // Сохраняем обновленную заявку
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updatedRequest.toMap());
      
      // Отправляем уведомление клинеру
      final property = await _propertyService.getPropertyById(request.propertyId);
      if (property != null) {
        await _notificationService.sendCleaningApprovedNotification(
          requestId: requestId,
          propertyTitle: property.title,
          cleanerId: offer.cleanerId,
        );
      }
      
    } catch (e) {
      debugPrint('Ошибка при принятии предложения на уборку: $e');
      throw Exception('Не удалось принять предложение: $e');
    }
  }
} 