import 'dart:async';

import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart' as domain;
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/cleaning_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pater/data/services/notification_service.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pater/core/di/service_locator.dart';

/// Сервис для работы с бронированиями
class BookingService {
  static final BookingService _instance = BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  PropertyService _propertyService = PropertyService();
  final bool _isInitialized = false;
  late final AuthService _authService;
  late final NotificationService _notificationService;
  final CleaningService _cleaningService = CleaningService();

  // Приватный конструктор
  BookingService._internal();

  /// Фабричный конструктор
  factory BookingService() {
    return _instance;
  }

  /// Инициализирует сервис и его зависимости
  Future<void> initializeDependencies() async {
    // Инициализируем PropertyService через GetIt
    _propertyService = getIt<PropertyService>();

    // Инициализируем AuthService через GetIt
    _authService = getIt<AuthService>();

    // Инициализируем NotificationService через GetIt
    _notificationService = getIt<NotificationService>();
  }

  /// Инициализирует сервис
  Future<void> init() async {
    try {
      // Инициализируем зависимости
      await initializeDependencies();

      // Проверяем, существует ли коллекция bookings
      final bookingsSnapshot =
          await _firestore.collection('bookings').limit(1).get();
      debugPrint(
        'Сервис бронирований инициализирован. Найдено бронирований: ${bookingsSnapshot.docs.length}',
      );
    } catch (e) {
      debugPrint('Ошибка при инициализации сервиса бронирований: $e');
    }
  }

  /// Получает список бронирований текущего пользователя
  Future<List<Booking>> getCurrentUserBookings() async {
    await _ensureInitialized();

    try {
      final userId = _authService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }

      debugPrint(
        'Загрузка бронирований для текущего пользователя (ID: $userId)',
      );
      // Получаем бронирования пользователя из Firestore
      final querySnapshot =
          await _firestore
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .get();

      // Преобразуем документы в объекты Booking
      return querySnapshot.docs
          .map((doc) => Booking.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении бронирований пользователя: $e');
      throw Exception('Ошибка при получении бронирований пользователя: $e');
    }
  }

  /// Получает список бронирований для указанного пользователя
  Future<List<Booking>> getUserBookings(String userId) async {
    await _ensureInitialized();

    try {
      // Получаем бронирования пользователя из Firestore
      final querySnapshot =
          await _firestore
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .get();

      // Преобразуем документы в объекты Booking
      return querySnapshot.docs
          .map((doc) => Booking.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Ошибка при получении бронирований пользователя: $e');
    }
  }

  /// Получает список бронирований для объекта
  Future<List<Booking>> getPropertyBookings(String propertyId) async {
    try {
      debugPrint('Загрузка бронирований для объекта $propertyId...');

      // Получаем все бронирования для объекта
      final bookingsSnapshot =
          await _firestore
              .collection('bookings')
              .where('propertyId', isEqualTo: propertyId)
              .get();

      // Преобразуем снимок в список объектов Booking
      final bookings =
          bookingsSnapshot.docs
              .map((doc) => Booking.fromJson(doc.data()))
              .where(
                (booking) =>
                    // Фильтруем неактуальные бронирования
                    ![
                      BookingStatus.cancelled,
                      BookingStatus.cancelledByClient,
                      BookingStatus.rejectedByOwner,
                      BookingStatus.completed,
                    ].contains(booking.status),
              )
              .toList();

      // Подробное логирование для отладки
      debugPrint(
        'Найдено ${bookings.length} бронирований для объекта $propertyId',
      );

      // Проверяем наличие запросов на подтверждение
      final pendingBookings =
          bookings
              .where((b) => b.status == BookingStatus.pendingApproval)
              .toList();
      debugPrint('Из них запросов на подтверждение: ${pendingBookings.length}');

      if (pendingBookings.isNotEmpty) {
        // Обновляем статус объекта, если есть запросы и объект доступен
        final propertyDoc =
            await _firestore.collection('properties').doc(propertyId).get();
        if (propertyDoc.exists) {
          final property = Property.fromJson(propertyDoc.data()!);

          // Только если объект доступен и не имеет подстатуса pendingRequest
          if (property.status == PropertyStatus.available &&
              property.subStatus != PropertySubStatus.pendingRequest) {
            debugPrint(
              'Обновляем подстатус объекта $propertyId на pendingRequest',
            );

            await _firestore.collection('properties').doc(propertyId).update({
              'subStatus':
                  PropertySubStatus.pendingRequest.toString().split('.').last,
              'updatedAt': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      return bookings;
    } catch (e) {
      debugPrint(
        'Ошибка при получении бронирований для объекта $propertyId: $e',
      );
      return [];
    }
  }

  /// Получает список бронирований для владельца
  Future<List<Booking>> getOwnerBookings() async {
    await _ensureInitialized();

    try {
      final userId = _authService.getUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }

      debugPrint('Загрузка бронирований для владельца (ID: $userId)');
      // Получаем бронирования владельца из Firestore
      final querySnapshot =
          await _firestore
              .collection('bookings')
              .where('ownerId', isEqualTo: userId)
              .get();

      // Преобразуем документы в объекты Booking
      return querySnapshot.docs
          .map((doc) => Booking.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении бронирований владельца: $e');
      throw Exception('Ошибка при получении бронирований владельца: $e');
    }
  }

  /// Получает бронирование по ID
  Future<Booking?> getBookingById(String id) async {
    await _ensureInitialized();

    try {
      final docSnapshot = await _firestore.collection('bookings').doc(id).get();

      if (docSnapshot.exists) {
        return Booking.fromJson(docSnapshot.data()!);
      }

      return null;
    } catch (e) {
      throw Exception('Ошибка при получении бронирования: $e');
    }
  }

  /// Создает новое бронирование
  Future<Booking> createBooking({
    required String propertyId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required int guestsCount,
    String? clientComment,
    bool isHourly = false,
  }) async {
    await _ensureInitialized();

    // Проверяем авторизацию и пытаемся восстановить сессию при необходимости
    domain.User? user = _authService.currentUser;
    if (user == null) {
      debugPrint(
        'BookingService: Пользователь не авторизован, пытаемся восстановить сессию',
      );

      // Пытаемся восстановить сессию из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('last_user_id');

      if (savedUserId != null && savedUserId.isNotEmpty) {
        debugPrint(
          'BookingService: Найден сохраненный ID пользователя: $savedUserId',
        );

        // Инициализируем сервис авторизации, если необходимо
        if (!_authService.isFirebaseInitialized) {
          await _authService.init();
        }

        // Восстанавливаем сессию
        final restored = await _authService.restoreUserSessionById(savedUserId);
        if (restored) {
          debugPrint(
            'BookingService: Сессия пользователя успешно восстановлена',
          );
          user = _authService.currentUser;
        } else {
          debugPrint(
            'BookingService: Не удалось восстановить сессию пользователя',
          );
          throw Exception('Пользователь не авторизован');
        }
      } else {
        debugPrint('BookingService: Сохраненный ID пользователя не найден');
        throw Exception('Пользователь не авторизован');
      }
    }

    // Проверяем, что пользователь действительно авторизован после попытки восстановления
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    debugPrint(
      'Начинаем создание бронирования для объекта $propertyId, '
      'даты: ${checkInDate.toString()} - ${checkOutDate.toString()}',
    );

    // Получение информации о жилье
    final property = await _propertyService.getPropertyById(propertyId);
    if (property == null) {
      throw Exception('Объект не найден');
    }

    debugPrint(
      'Объект найден: ${property.title}, статус: ${property.status}, '
      'подстатус: ${property.subStatus}',
    );

    // Проверка доступности дат
    try {
      final isAvailable = await checkAvailability(
        propertyId: propertyId,
        checkInDate: checkInDate,
        checkOutDate: checkOutDate,
      );

      if (!isAvailable) {
        throw Exception('Выбранные даты недоступны для бронирования');
      }

      debugPrint('Проверка доступности дат успешно пройдена');
    } catch (e) {
      debugPrint('Ошибка при проверке доступности дат: $e');
      throw Exception('Ошибка при проверке доступности дат: $e');
    }

    // Проверка максимального количества гостей
    if (guestsCount > property.maxGuests) {
      throw Exception(
        'Превышено максимальное количество гостей (${property.maxGuests})',
      );
    }

    // Расчет продолжительности в днях
    final duration = checkOutDate.difference(checkInDate).inDays;

    // Расчет общей стоимости
    var totalPrice = 0.0;
    if (isHourly) {
      // Расчет для почасовой аренды
      final durationHours = checkOutDate.difference(checkInDate).inHours;
      totalPrice = property.pricePerHour * durationHours;
    } else {
      // Расчет для посуточной аренды
      totalPrice = property.pricePerNight * duration;
    }

    debugPrint(
      'Расчет стоимости: ${isHourly ? "почасовая" : "посуточная"} аренда, '
      'длительность: ${isHourly ? "${checkOutDate.difference(checkInDate).inHours} часов" : "$duration дней"}, '
      'стоимость: $totalPrice тенге',
    );

    // Создание нового бронирования
    final booking = Booking(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      propertyId: propertyId,
      userId: user.id,
      ownerId: property.ownerId,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      guestsCount: guestsCount,
      status: BookingStatus.pendingApproval,
      totalPrice: totalPrice,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      clientComment: clientComment,
      isHourly: isHourly,
    );

    // Сохранение бронирования в Firestore
    try {
      await _firestore
          .collection('bookings')
          .doc(booking.id)
          .set(booking.toJson());

      debugPrint('Бронирование сохранено в базе данных с ID: ${booking.id}');

      // Отправка уведомления владельцу о новом бронировании
      await _notificationService.sendNewBookingNotification(booking: booking);

      // Обновляем статус объекта на "в ожидании запроса"
      await _propertyService.updatePropertyStatusAndSubStatus(
        propertyId,
        PropertyStatus.available,
        PropertySubStatus.pendingRequest,
      );

      debugPrint(
        'Создано новое бронирование с ID: ${booking.id}, '
        'статус объекта обновлен на pendingRequest',
      );
    } catch (e) {
      debugPrint('Ошибка при создании бронирования: $e');
      throw Exception('Не удалось создать бронирование: $e');
    }

    return booking;
  }

  /// Отменяет бронирование
  Future<Booking> cancelBooking(
    String bookingId, {
    String? cancelReason,
  }) async {
    try {
      // Получаем текущее бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      // Получаем данные текущего пользователя
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Преобразуем в объект Booking
      final booking = Booking.fromJson(bookingDoc.data()!);

      // Определяем статус отмены в зависимости от того, кто отменяет
      BookingStatus cancelStatus;
      String? reason = cancelReason;

      if (booking.userId == user.id) {
        cancelStatus = BookingStatus.cancelledByClient;
        reason ??= 'Отменено клиентом';
      } else if (booking.ownerId == user.id) {
        cancelStatus = BookingStatus.rejectedByOwner;
        reason ??= 'Отклонено владельцем';
      } else {
        throw Exception('У вас нет прав для отмены этого бронирования');
      }

      // Получаем объект для сброса его статуса
      final property = await _propertyService.getPropertyById(
        booking.propertyId,
      );
      if (property == null) {
        throw Exception('Объект не найден');
      }

      // Обновляем статус бронирования
      final updatedBooking = booking.copyWith(
        status: cancelStatus,
        cancellationReason: reason,
        updatedAt: DateTime.now(),
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Сбрасываем статус объекта на "доступен"
      await _propertyService.updatePropertyStatusAndSubStatus(
        booking.propertyId,
        PropertyStatus.available,
        PropertySubStatus.none,
      );

      // Отправляем уведомления
      if (booking.userId == user.id) {
        await _notificationService.sendBookingCancelledNotification(
          booking: updatedBooking,
        );
      } else {
        await _notificationService.sendBookingRejectedNotification(
          booking.userId,
          booking,
        );
      }

      return updatedBooking;
    } catch (e) {
      throw Exception('Ошибка при отмене бронирования: $e');
    }
  }

  /// Завершает бронирование досрочно или по истечении срока
  Future<Booking> completeBooking(String bookingId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Получаем текущее бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      // Преобразуем в объект Booking
      final booking = Booking.fromJson(bookingDoc.data()!);

      // Проверяем, может ли пользователь завершить бронирование (клиент или владелец)
      if (booking.userId != user.id && booking.ownerId != user.id) {
        throw Exception('У вас нет прав для завершения этого бронирования');
      }

      // Проверяем статус бронирования
      if (booking.status != BookingStatus.active &&
          booking.status != BookingStatus.paid) {
        throw Exception(
          'Можно завершить только активное или оплаченное бронирование',
        );
      }

      debugPrint(
        'Завершение бронирования ${booking.id} для объекта ${booking.propertyId}',
      );

      // Обновляем статус бронирования
      final updatedBooking = booking.copyWith(
        status: BookingStatus.completed,
        updatedAt: DateTime.now(),
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Обновляем статус объекта на "на уборке"
      await _propertyService.updatePropertyStatusAndSubStatus(
        booking.propertyId,
        PropertyStatus.cleaning,
        PropertySubStatus.waitingCleaning,
      );

      // Очищаем информацию о текущем бронировании в объекте
      await _firestore.collection('properties').doc(booking.propertyId).update({
        'currentBookingId': '',
        'bookingEndTime': null,
      });

      // Создаем автоматическую заявку на уборку
      await _cleaningService.createAutomaticCleaningRequest(
        booking.propertyId,
        booking.ownerId,
      );

      // Отправляем уведомление о завершении бронирования
      await _notificationService.sendBookingCompletedNotification(
        booking: updatedBooking,
      );

      debugPrint(
        'Бронирование ${booking.id} успешно завершено, объект переведен на уборку',
      );

      return updatedBooking;
    } catch (e) {
      debugPrint('Ошибка при завершении бронирования: $e');
      throw Exception('Ошибка при завершении бронирования: $e');
    }
  }

  /// Подтверждает бронирование
  Future<bool> confirmBooking(String bookingId) async {
    try {
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      final booking = Booking.fromJson(bookingDoc.data()!);

      if (booking.status != BookingStatus.pendingApproval) {
        throw Exception('Нельзя подтвердить бронирование в текущем статусе');
      }

      final now = DateTime.now();

      // Обновляем статус бронирования на "ожидает оплаты"
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.waitingPayment.toString().split('.').last,
        'approvedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      // Отправляем уведомление клиенту
      await _notificationService.sendBookingConfirmationNotification(
        booking.userId,
        booking,
      );

      return true;
    } catch (e) {
      debugPrint('Ошибка при подтверждении бронирования: $e');
      return false;
    }
  }

  /// Создает карту обновлений для объекта недвижимости
  Map<String, dynamic> _createPropertyUpdates(
    String bookingId,
    DateTime checkInDate,
    DateTime checkOutDate,
  ) {
    return {
      // CamelCase
      'currentBookingId': bookingId,
      'bookingStartTime': checkInDate.millisecondsSinceEpoch,
      'bookingEndTime': checkOutDate.millisecondsSinceEpoch,
      'timerActive': true,
      'lastStatusUpdate': DateTime.now().millisecondsSinceEpoch,
      'bookingId': bookingId,

      // Snake_case
      'current_booking_id': bookingId,
      'booking_start_time': checkInDate.millisecondsSinceEpoch,
      'booking_end_time': checkOutDate.millisecondsSinceEpoch,
      'timer_active': true,
      'last_status_update': DateTime.now().millisecondsSinceEpoch,
      'booking_id': bookingId,
    };
  }

  /// Обновляет статус объекта после оплаты
  Future<void> _updatePropertyStatusAfterPayment(String propertyId) async {
    // Обновляем статус объекта на "забронирован"
    await _propertyService.updatePropertyStatusAndSubStatus(
      propertyId,
      PropertyStatus.booked,
      PropertySubStatus.none,
    );

    // Также принудительно обновляем статус объекта напрямую
    await _firestore.collection('properties').doc(propertyId).update({
      'status': PropertyStatus.booked.toString().split('.').last,
      'sub_status': PropertySubStatus.none,
    });

    // Проверка, что статус объекта обновился
    final updatedPropertyDoc =
        await _firestore.collection('properties').doc(propertyId).get();
    if (updatedPropertyDoc.exists) {
      final updatedPropertyData = updatedPropertyDoc.data()!;
      debugPrint(
        'Статус объекта после оплаты: ${updatedPropertyData['status']}, подстатус: ${updatedPropertyData['sub_status']}',
      );
    }
  }

  /// Обрабатывает оплату бронирования
  Future<Booking> processPayment(String bookingId) async {
    try {
      // Проверяем авторизацию
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Получаем текущее бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      // Преобразуем в объект Booking
      final booking = Booking.fromJson(bookingDoc.data()!);

      // Проверяем, является ли пользователь клиентом
      if (booking.userId != user.id) {
        throw Exception('Только клиент может оплатить бронирование');
      }

      // Проверяем, что бронирование ожидает оплаты
      if (booking.status != BookingStatus.waitingPayment) {
        throw Exception('Бронирование не может быть оплачено: неверный статус');
      }

      // Здесь должна быть логика работы с платежной системой
      // ...

      debugPrint('Обработка оплаты для бронирования $bookingId');

      // Обновляем статус бронирования
      final updatedBooking = booking.copyWith(
        status: BookingStatus.paid,
        isPaid: true,
        paidAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Получаем объект недвижимости для обновления его статуса
      final propertyDoc =
          await _firestore
              .collection('properties')
              .doc(booking.propertyId)
              .get();
      if (!propertyDoc.exists) {
        throw Exception('Объект недвижимости не найден');
      }

      // Обновляем время окончания бронирования в объекте
      await _propertyService.setBookingEndTime(
        booking.propertyId,
        booking.checkOutDate,
      );

      // Также обновляем информацию о текущем бронировании в объекте
      final propertyUpdates = _createPropertyUpdates(
        bookingId,
        booking.checkInDate,
        booking.checkOutDate,
      );

      await _firestore
          .collection('properties')
          .doc(booking.propertyId)
          .update(propertyUpdates);

      debugPrint(
        'Установлено время бронирования для объекта ${booking.propertyId}: '
        'Начало: ${booking.checkInDate.toString()}, '
        'Окончание: ${booking.checkOutDate.toString()}',
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Обновляем статус объекта
      await _updatePropertyStatusAfterPayment(booking.propertyId);

      // Отправляем уведомление владельцу
      await _notificationService.sendBookingPaidNotification(
        booking: updatedBooking,
      );

      // Проверяем, нужно ли активировать бронирование немедленно
      final now = DateTime.now();
      if (now.isAfter(booking.checkInDate) &&
          now.isBefore(booking.checkOutDate)) {
        debugPrint(
          'Время начала бронирования уже наступило, активируем его немедленно',
        );

        // Создаем новое обновленное бронирование со статусом active
        final activatedBooking = updatedBooking.copyWith(
          status: BookingStatus.active,
          updatedAt: DateTime.now(),
        );

        // Обновляем бронирование
        await _firestore
            .collection('bookings')
            .doc(bookingId)
            .update(activatedBooking.toJson());

        // Отправляем уведомление об активации
        await _notificationService.sendBookingActivatedNotification(
          booking: activatedBooking,
        );

        return activatedBooking;
      }

      return updatedBooking;
    } catch (e) {
      throw Exception('Ошибка при обработке оплаты: $e');
    }
  }

  /// Получает список бронирований по статусу
  Future<List<Booking>> getBookingsByStatus(BookingStatus status) async {
    await _ensureInitialized();

    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Получаем бронирования с заданным статусом из Firestore
      final querySnapshot =
          await _firestore
              .collection('bookings')
              .where('status', isEqualTo: status.toString().split('.').last)
              .get();

      // Преобразуем документы в объекты Booking
      return querySnapshot.docs
          .map((doc) => Booking.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Ошибка при получении бронирований по статусу: $e');
    }
  }

  /// Получает список бронирований владельца по статусу
  Future<List<Booking>> getOwnerBookingsByStatus(BookingStatus status) async {
    await _ensureInitialized();

    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Получаем бронирования владельца с заданным статусом из Firestore
      final querySnapshot =
          await _firestore
              .collection('bookings')
              .where('ownerId', isEqualTo: user.id)
              .where('status', isEqualTo: status.toString().split('.').last)
              .get();

      // Преобразуем документы в объекты Booking
      return querySnapshot.docs
          .map((doc) => Booking.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception(
        'Ошибка при получении бронирований владельца по статусу: $e',
      );
    }
  }

  /// Получает список бронирований пользователя по статусу
  Future<List<Booking>> getUserBookingsByStatus(BookingStatus status) async {
    await _ensureInitialized();

    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Получаем бронирования пользователя с заданным статусом из Firestore
      final querySnapshot =
          await _firestore
              .collection('bookings')
              .where('userId', isEqualTo: user.id)
              .where('status', isEqualTo: status.toString().split('.').last)
              .get();

      // Преобразуем документы в объекты Booking
      return querySnapshot.docs
          .map((doc) => Booking.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception(
        'Ошибка при получении бронирований пользователя по статусу: $e',
      );
    }
  }

  /// Обновляет статус бронирования
  Future<Booking> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    await _ensureInitialized();

    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Получаем текущее бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      // Преобразуем в объект Booking
      final booking = Booking.fromJson(bookingDoc.data()!);

      // Проверяем, является ли пользователь владельцем объекта
      if (booking.ownerId != user.id) {
        throw Exception('Только владелец может обновить статус бронирования');
      }

      // Обновляем статус бронирования
      final updatedBooking = booking.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Отправляем уведомление об обновлении бронирования
      await _notificationService.sendBookingUpdatedNotification(
        booking: updatedBooking,
      );

      return updatedBooking;
    } catch (e) {
      throw Exception('Ошибка при обновлении статуса бронирования: $e');
    }
  }

  /// Проверяет и обновляет статусы просроченных бронирований
  Future<void> checkAndUpdateExpiredBookings() async {
    try {
      final now = DateTime.now();

      // Получаем все бронирования в ожидании оплаты
      final querySnapshot =
          await _firestore
              .collection('bookings')
              .where(
                'status',
                isEqualTo:
                    BookingStatus.waitingPayment.toString().split('.').last,
              )
              .get();

      // Проверяем каждое бронирование на истечение срока
      for (final doc in querySnapshot.docs) {
        final booking = Booking.fromJson(doc.data());

        // Проверяем, истекло ли время оплаты с учетом правил для разных типов аренды
        if (booking.approvedAt != null) {
          final expireTime = booking.getPaymentExpirationTime();

          if (now.isAfter(expireTime)) {
            // Формируем причину отмены в зависимости от типа бронирования
            String cancellationReason;
            if (booking.isHourly && booking.durationHours <= 2) {
              cancellationReason = 'Истекло время ожидания оплаты (15 минут)';
            } else {
              cancellationReason = 'Истекло время ожидания оплаты';
            }

            // Обновляем статус бронирования
            final updatedBooking = booking.copyWith(
              status: BookingStatus.expired,
              updatedAt: now,
              cancellationReason: cancellationReason,
            );

            // Сохраняем изменения в Firestore
            await _firestore
                .collection('bookings')
                .doc(booking.id)
                .update(updatedBooking.toJson());

            // Сбрасываем статус объекта на "доступен"
            await _propertyService.updatePropertyStatusAndSubStatus(
              booking.propertyId,
              PropertyStatus.available,
              PropertySubStatus.none,
            );

            // Отправляем уведомления
            await _notificationService.sendBookingExpiredNotification(
              booking: updatedBooking,
              recipientId: booking.userId,
            );

            await _notificationService.sendBookingExpiredNotification(
              booking: updatedBooking,
              recipientId: booking.ownerId,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка при проверке просроченных бронирований: $e');
    }
  }

  /// Проверяет доступность объекта в указанные даты
  Future<bool> checkAvailability({
    required String propertyId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? excludeBookingId,
  }) async {
    await _ensureInitialized();

    // Проверка корректности дат
    if (checkInDate.isAfter(checkOutDate)) {
      throw Exception('Дата заезда не может быть позже даты выезда');
    }

    // Нормализуем даты, отбрасывая время
    final normalizedCheckInDate = DateTime(
      checkInDate.year,
      checkInDate.month,
      checkInDate.day,
    );
    final normalizedCheckOutDate = DateTime(
      checkOutDate.year,
      checkOutDate.month,
      checkOutDate.day,
    );

    // Создаем DateTime на начало текущего дня для корректного сравнения
    final now = DateTime.now();
    final currentDay = DateTime(now.year, now.month, now.day);

    // Проверяем, что дата заезда не раньше сегодняшнего дня
    if (normalizedCheckInDate.isBefore(currentDay)) {
      throw Exception('Дата заезда не может быть в прошлом');
    }

    // Получение объекта
    final property = await _propertyService.getPropertyById(propertyId);
    if (property == null) {
      throw Exception('Объект не найден');
    }

    // Добавляем более подробный вывод о статусе объекта
    debugPrint(
      'Объект $propertyId статус: ${property.status}, подстатус: ${property.subStatus}',
    );

    // Проверка статуса объекта
    if (property.status != PropertyStatus.available) {
      debugPrint('Объект $propertyId недоступен: статус = ${property.status}');
      return false;
    }

    // Получение всех бронирований для объекта
    final bookings = await getPropertyBookings(propertyId);

    // Проверка пересечения с другими бронированиями
    for (final booking in bookings) {
      // Пропускаем исключенное бронирование и отмененные/отклоненные
      if ((excludeBookingId != null && booking.id == excludeBookingId) ||
          booking.status == BookingStatus.cancelledByClient ||
          booking.status == BookingStatus.rejectedByOwner ||
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.expired) {
        continue;
      }

      // Нормализуем даты бронирования, отбрасывая время
      final bookingCheckInDate = DateTime(
        booking.checkInDate.year,
        booking.checkInDate.month,
        booking.checkInDate.day,
      );

      final bookingCheckOutDate = DateTime(
        booking.checkOutDate.year,
        booking.checkOutDate.month,
        booking.checkOutDate.day,
      );

      // Проверка пересечения периодов
      if (_doPeriodsCross(
        startA: normalizedCheckInDate,
        endA: normalizedCheckOutDate,
        startB: bookingCheckInDate,
        endB: bookingCheckOutDate,
      )) {
        debugPrint(
          'Даты $normalizedCheckInDate - $normalizedCheckOutDate пересекаются с существующим бронированием: '
          '$bookingCheckInDate - $bookingCheckOutDate (ID: ${booking.id}, статус: ${booking.status})',
        );
        return false;
      }
    }

    debugPrint(
      'Даты $normalizedCheckInDate - $normalizedCheckOutDate доступны для бронирования объекта $propertyId',
    );
    return true;
  }

  /// Проверяет пересечение периодов
  bool _doPeriodsCross({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    // Периоды пересекаются, если один период не заканчивается до начала другого
    // и не начинается после окончания другого
    return !(endA.isBefore(startB) || startA.isAfter(endB));
  }

  /// Убеждается, что сервис инициализирован
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// Обновляет бронирование после оплаты
  Future<Booking> updateBookingAfterPayment(String bookingId) async {
    try {
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      final booking = Booking.fromJson(bookingDoc.data()!);

      if (booking.status != BookingStatus.waitingPayment) {
        throw Exception('Бронирование не в статусе ожидания оплаты');
      }

      final updatedBooking = booking.copyWith(
        status: BookingStatus.paid,
        isPaid: true,
        paidAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Также обновляем информацию о текущем бронировании в объекте
      final propertyUpdates = _createPropertyUpdates(
        bookingId,
        booking.checkInDate,
        booking.checkOutDate,
      );

      await _firestore
          .collection('properties')
          .doc(booking.propertyId)
          .update(propertyUpdates);

      // Обновляем статус объекта
      await _updatePropertyStatusAfterPayment(booking.propertyId);

      await _notificationService.sendBookingPaidNotification(
        booking: updatedBooking,
      );

      return updatedBooking;
    } catch (e) {
      throw Exception('Ошибка при обновлении бронирования после оплаты: $e');
    }
  }

  /// Обновляет параметры бронирования
  Future<Booking> updateBookingDates({
    required String bookingId,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    bool? isHourly,
  }) async {
    try {
      // Получаем текущее бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      final booking = Booking.fromJson(bookingDoc.data()!);

      // Обновляем параметры бронирования, если они предоставлены
      final updatedBooking = booking.copyWith(
        checkInDate: checkInDate ?? booking.checkInDate,
        checkOutDate: checkOutDate ?? booking.checkOutDate,
        isHourly: isHourly ?? booking.isHourly,
        updatedAt: DateTime.now(),
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Отправляем уведомление об обновлении бронирования
      await _notificationService.sendBookingUpdatedNotification(
        booking: updatedBooking,
      );

      return updatedBooking;
    } catch (e) {
      throw Exception('Ошибка при обновлении бронирования: $e');
    }
  }

  /// Отклоняет бронирование владельцем
  Future<bool> rejectBooking(
    String bookingId, {
    String reason = 'Отклонено владельцем',
  }) async {
    try {
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      final booking = Booking.fromJson(bookingDoc.data()!);

      if (booking.status != BookingStatus.pendingApproval) {
        throw Exception('Нельзя отклонить бронирование в текущем статусе');
      }

      // Обновляем статус бронирования на "отклонено"
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': BookingStatus.rejectedByOwner.toString().split('.').last,
        'cancellationReason': reason,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Отправляем уведомление клиенту
      await _notificationService.sendBookingRejectedNotification(
        booking.userId,
        booking,
      );

      return true;
    } catch (e) {
      debugPrint('Ошибка при отклонении бронирования: $e');
      return false;
    }
  }

  /// Обновляет информацию о бронировании
  Future<Booking> updateBooking({
    required String bookingId,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? guestsCount,
    String? clientComment,
  }) async {
    try {
      // Получаем текущее бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      // Преобразуем в объект Booking
      final booking = Booking.fromJson(bookingDoc.data()!);

      // Проверка статуса бронирования - можно изменять только в статусе "ожидает подтверждения"
      if (booking.status != BookingStatus.pendingApproval) {
        throw Exception(
          'Изменить можно только бронирование в статусе "Ожидает подтверждения"',
        );
      }

      // Если изменяются даты, проверяем их доступность
      if (checkInDate != null || checkOutDate != null) {
        final newCheckInDate = checkInDate ?? booking.checkInDate;
        final newCheckOutDate = checkOutDate ?? booking.checkOutDate;

        // Проверка корректности дат
        if (newCheckInDate.isAfter(newCheckOutDate)) {
          throw Exception('Дата заезда не может быть позже даты выезда');
        }

        // Проверка доступности
        final isAvailable = await checkAvailability(
          propertyId: booking.propertyId,
          checkInDate: newCheckInDate,
          checkOutDate: newCheckOutDate,
          excludeBookingId: bookingId, // Исключаем текущее бронирование
        );

        if (!isAvailable) {
          throw Exception('Выбранные даты недоступны для бронирования');
        }
      }

      // Формируем обновленное бронирование
      final updatedBooking = booking.copyWith(
        checkInDate: checkInDate ?? booking.checkInDate,
        checkOutDate: checkOutDate ?? booking.checkOutDate,
        guestsCount: guestsCount ?? booking.guestsCount,
        clientComment: clientComment ?? booking.clientComment,
        updatedAt: DateTime.now(),
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Отправляем уведомление об обновлении бронирования
      await _notificationService.sendBookingUpdatedNotification(
        booking: updatedBooking,
      );

      return updatedBooking;
    } catch (e) {
      throw Exception('Ошибка при обновлении бронирования: $e');
    }
  }

  /// Обновляет бронирование вместе со статусом
  /// Используется для подтверждения бронирования владельцем и других изменений статуса
  Future<Booking> updateBookingWithStatus(Booking booking) async {
    try {
      debugPrint(
        'Обновление бронирования #${booking.id} со статусом: ${booking.status}',
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(booking.id)
          .update(booking.toJson());

      // В зависимости от статуса, отправляем соответствующее уведомление
      switch (booking.status) {
        case BookingStatus.waitingPayment:
          await _notificationService.sendBookingApprovedNotification(
            booking: booking,
          );
          // Обновляем статус объекта при необходимости
          await _updatePropertyStatusIfNeeded(
            propertyId: booking.propertyId,
            status: PropertyStatus.available,
            subStatus: PropertySubStatus.approvedPendingPayment,
          );
          break;

        case BookingStatus.paid:
          await _notificationService.sendBookingPaidNotification(
            booking: booking,
          );
          break;

        case BookingStatus.active:
          await _notificationService.sendBookingActivatedNotification(
            booking: booking,
          );
          break;

        case BookingStatus.completed:
          await _notificationService.sendBookingCompletedNotification(
            booking: booking,
          );
          break;

        case BookingStatus.cancelled:
        case BookingStatus.cancelledByClient:
        case BookingStatus.rejectedByOwner:
          await _notificationService.sendBookingCancelledNotification(
            booking: booking,
          );
          break;

        default:
          // Для других статусов отправляем общее уведомление об обновлении
          await _notificationService.sendBookingUpdatedNotification(
            booking: booking,
          );
      }

      return booking;
    } catch (e) {
      throw Exception('Ошибка при обновлении бронирования со статусом: $e');
    }
  }

  /// Обновляет статус объекта недвижимости при необходимости
  Future<void> _updatePropertyStatusIfNeeded({
    required String propertyId,
    required PropertyStatus status,
    String? subStatus,
  }) async {
    try {
      debugPrint(
        'Обновление статуса объекта $propertyId на $status, подстатус: $subStatus',
      );

      // Получаем ссылку на сервис объектов
      final propertyService = PropertyService();

      // Обновляем статус объекта
      await propertyService.updatePropertyStatusAndSubStatus(
        propertyId,
        status,
        subStatus ?? PropertySubStatus.none,
      );

      debugPrint('Статус объекта $propertyId успешно обновлен');
    } catch (e) {
      debugPrint('Ошибка при обновлении статуса объекта: $e');
      // Не выбрасываем исключение дальше, чтобы не прерывать основной процесс
    }
  }

  /// Активирует бронирование (переводит из статуса paid в active)
  Future<Booking> activateBooking(String bookingId) async {
    await _ensureInitialized();

    try {
      // Получаем текущее бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      // Преобразуем в объект Booking
      final booking = Booking.fromJson(bookingDoc.data()!);

      // Проверяем, что бронирование оплачено
      if (booking.status != BookingStatus.paid) {
        throw Exception(
          'Бронирование не может быть активировано: неверный статус',
        );
      }

      // Обновляем статус бронирования
      final activatedBooking = booking.copyWith(
        status: BookingStatus.active,
        updatedAt: DateTime.now(),
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(activatedBooking.toJson());

      // Отправляем уведомление об активации
      await _notificationService.sendBookingActivatedNotification(
        booking: activatedBooking,
      );

      return activatedBooking;
    } catch (e) {
      throw Exception('Ошибка при активации бронирования: $e');
    }
  }

  /// Добавляет отзыв к бронированию
  Future<Booking> addReviewToBooking({
    required String bookingId,
    required double rating,
    String? reviewText,
  }) async {
    try {
      await _ensureInitialized();

      // Проверяем авторизацию
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Получаем бронирование
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        throw Exception('Бронирование не найдено');
      }

      final booking = Booking.fromJson(bookingDoc.data()!);

      // Проверяем, что пользователь является клиентом бронирования
      if (booking.userId != user.id) {
        throw Exception('Только клиент может оставить отзыв о бронировании');
      }

      // Проверяем, что бронирование завершено
      if (booking.status != BookingStatus.completed) {
        throw Exception(
          'Оставить отзыв можно только о завершенном бронировании',
        );
      }

      // Проверяем, что отзыв еще не был оставлен
      if (booking.hasReview) {
        throw Exception('Отзыв уже был оставлен для этого бронирования');
      }

      // Текущая дата
      final now = DateTime.now();

      // Обновляем бронирование
      final updatedBooking = booking.copyWith(
        rating: rating,
        review: reviewText,
        hasReview: true,
        updatedAt: now,
      );

      // Сохраняем изменения в Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update(updatedBooking.toJson());

      // Обновляем рейтинг объекта недвижимости
      await _updatePropertyRating(booking.propertyId, rating);

      // Обновляем рейтинг владельца
      final userService = UserService();
      await userService.addReview(
        cleanerId:
            booking
                .ownerId, // В данном случае cleanerId используется для владельца
        reviewerId: user.id,
        requestId: bookingId,
        rating: rating,
        text: reviewText,
      );

      // Отправляем уведомление владельцу о новом отзыве
      await _notificationService.sendNewReviewNotification(
        recipientId: booking.ownerId,
        bookingId: bookingId,
        rating: rating,
      );

      return updatedBooking;
    } catch (e) {
      debugPrint('Ошибка при добавлении отзыва к бронированию: $e');
      throw Exception('Не удалось добавить отзыв: $e');
    }
  }

  /// Обновляет рейтинг объекта недвижимости
  Future<void> _updatePropertyRating(
    String propertyId,
    double newRating,
  ) async {
    try {
      // Получаем объект
      final propertyDoc =
          await _firestore.collection('properties').doc(propertyId).get();
      if (!propertyDoc.exists) {
        throw Exception('Объект недвижимости не найден');
      }

      final data = propertyDoc.data()!;

      // Получаем текущий рейтинг и количество отзывов
      final currentRating =
          data['rating'] != null ? (data['rating'] as num).toDouble() : 0.0;
      final reviewsCount =
          data['reviewsCount'] != null
              ? (data['reviewsCount'] as num).toInt()
              : 0;

      // Вычисляем новый средний рейтинг
      final updatedRating =
          (currentRating * reviewsCount + newRating) / (reviewsCount + 1);

      // Обновляем данные объекта
      await _firestore.collection('properties').doc(propertyId).update({
        'rating': updatedRating,
        'reviewsCount': reviewsCount + 1,
      });

      debugPrint(
        'Рейтинг объекта $propertyId обновлен: $updatedRating ($reviewsCount + 1 отзывов)',
      );
    } catch (e) {
      debugPrint('Ошибка при обновлении рейтинга объекта: $e');
    }
  }
}
