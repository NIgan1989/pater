import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/auth/role_manager.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/notification.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для управления уведомлениями в приложении
class NotificationService {
  static NotificationService? _instance;

  final FirebaseFirestore _firestore;
  late final AuthService _authService;
  late final PropertyService _propertyService;
  late final UserService _userService;
  bool _isInitialized = false;

  /// Создает экземпляр сервиса с необходимыми зависимостями
  NotificationService({
    required FirebaseFirestore firestore,
    required SharedPreferences prefs,
    required RoleManager roleManager,
  }) : _firestore = firestore {
    _authService = AuthService(
      auth: firebase.FirebaseAuth.instance,
      firestore: firestore,
      prefs: prefs,
      roleManager: roleManager,
    );
  }

  /// Фабричный метод для создания экземпляра с использованием GetIt
  factory NotificationService.withDependencies({
    required FirebaseFirestore firestore,
    required SharedPreferences prefs,
    required RoleManager roleManager,
  }) {
    return NotificationService(
      firestore: firestore,
      prefs: prefs,
      roleManager: roleManager,
    );
  }

  /// Возвращает экземпляр синглтона
  static NotificationService getInstance() {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  /// Приватный конструктор для реализации паттерна Singleton
  NotificationService._internal() : _firestore = FirebaseFirestore.instance;

  /// Инициализирует сервис уведомлений
  Future<void> init() async {
    try {
      _propertyService = PropertyService();
      _userService = UserService();
      _isInitialized = true;

      // Создание коллекции notifications, если её нет
      final notificationsRef = _firestore.collection('notifications');
      final snapshot = await notificationsRef.limit(1).get();
      debugPrint(
        'Сервис уведомлений инициализирован. Уведомлений в базе: ${snapshot.docs.length}',
      );
    } catch (e) {
      debugPrint('Ошибка при инициализации сервиса уведомлений: $e');
    }
  }

  /// Отправляет уведомление о новом бронировании
  Future<void> sendNewBookingNotification({required Booking booking}) async {
    try {
      // Убедимся, что сервисы инициализированы
      await _ensureInitialized();

      // Получаем данные свойства и пользователей
      final property = await _propertyService.getPropertyById(
        booking.propertyId,
      );
      final client = await _userService.getUserById(booking.clientId);
      final owner = await _userService.getUserById(booking.ownerId);

      if (property == null) {
        debugPrint('Не удалось найти свойство по ID: ${booking.propertyId}');
        return;
      }

      // Формируем сообщение владельцу
      String ownerMessage = 'Клиент бронирует "${property.title}"';
      if (client != null) {
        ownerMessage =
            'Клиент ${client.firstName} ${client.lastName} бронирует "${property.title}"';
      }

      // Уведомление для владельца
      final ownerNotification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: booking.ownerId,
        title: 'Новое бронирование',
        message: ownerMessage,
        type: NotificationType.newBooking,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление для владельца
      await _firestore
          .collection('notifications')
          .doc(ownerNotification.id)
          .set(ownerNotification.toJson());

      // Формируем сообщение клиенту
      String clientMessage =
          'Ваш запрос на бронирование "${property.title}" отправлен владельцу';
      if (owner != null) {
        clientMessage =
            'Ваш запрос на бронирование "${property.title}" отправлен владельцу ${owner.firstName} ${owner.lastName}';
      }

      // Уведомление для клиента
      final clientNotification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: booking.clientId,
        title: 'Запрос на бронирование отправлен',
        message: clientMessage,
        type:
            NotificationType
                .newBooking, // Используем существующий тип уведомления
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление для клиента
      await _firestore
          .collection('notifications')
          .doc(clientNotification.id)
          .set(clientNotification.toJson());

      debugPrint(
        'Уведомления о новом бронировании отправлены владельцу и клиенту',
      );
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления о новом бронировании: $e');
    }
  }

  /// Убеждается, что сервис инициализирован
  Future<void> _ensureInitialized() async {
    try {
      // Проверяем, были ли инициализированы поля, и если нет, инициализируем их
      if (!_isInitialized) {
        _propertyService = PropertyService();
        _userService = UserService();
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('Ошибка при инициализации сервисов: $e');
    }
  }

  /// Отправляет уведомление клиенту о подтверждении бронирования
  Future<void> sendBookingApprovedNotification({
    required Booking booking,
    String? recipientId,
  }) async {
    try {
      final userId = recipientId ?? booking.userId;

      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId, // ID клиента
        title: 'Бронирование одобрено',
        message:
            'Владелец одобрил ваше бронирование с ${booking.checkInDate.day}.${booking.checkInDate.month}.${booking.checkInDate.year} по ${booking.checkOutDate.day}.${booking.checkOutDate.month}.${booking.checkOutDate.year}. Пожалуйста, оплатите его в течение 24 часов.',
        type: NotificationType.bookingApproved,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление о подтверждении бронирования отправлено клиенту $userId',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления о подтверждении бронирования: $e',
      );
    }
  }

  /// Отправляет уведомление об оплате бронирования
  Future<void> sendBookingPaidNotification({
    required Booking booking,
    String? recipientId,
  }) async {
    try {
      final userId = recipientId ?? booking.ownerId;

      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: 'Бронирование оплачено',
        message:
            'Клиент оплатил бронирование с ${booking.checkInDate.day}.${booking.checkInDate.month}.${booking.checkInDate.year} по ${booking.checkOutDate.day}.${booking.checkOutDate.month}.${booking.checkOutDate.year}.',
        type: NotificationType.bookingPaid,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint('Уведомление об оплате бронирования отправлено $userId');
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления об оплате бронирования: $e');
    }
  }

  /// Отправляет уведомление об активации бронирования
  Future<void> sendBookingActivatedNotification({
    required Booking booking,
    String? recipientId,
  }) async {
    try {
      // Отправляем уведомление и клиенту, и владельцу
      final clientId = booking.userId;
      final ownerId = booking.ownerId;

      // Сообщение для клиента
      final clientNotification = AppNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}_client',
        userId: clientId,
        title: 'Бронирование активировано',
        message:
            'Ваше бронирование активировано. Время заезда: ${booking.checkInDate.day}.${booking.checkInDate.month}.${booking.checkInDate.year} в ${booking.checkInDate.hour}:${booking.checkInDate.minute.toString().padLeft(2, '0')}.',
        type: NotificationType.bookingActivated,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сообщение для владельца
      final ownerNotification = AppNotification(
        id: '${DateTime.now().millisecondsSinceEpoch}_owner',
        userId: ownerId,
        title: 'Бронирование активировано',
        message:
            'Бронирование вашего объекта активировано. Время заезда гостя: ${booking.checkInDate.day}.${booking.checkInDate.month}.${booking.checkInDate.year} в ${booking.checkInDate.hour}:${booking.checkInDate.minute.toString().padLeft(2, '0')}.',
        type: NotificationType.bookingActivated,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомления в Firestore
      await _firestore
          .collection('notifications')
          .doc(clientNotification.id)
          .set(clientNotification.toJson());

      await _firestore
          .collection('notifications')
          .doc(ownerNotification.id)
          .set(ownerNotification.toJson());

      debugPrint(
        'Уведомления об активации бронирования отправлены клиенту и владельцу',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления об активации бронирования: $e',
      );
    }
  }

  /// Отправляет уведомление об отмене бронирования
  Future<void> sendBookingCancelledNotification({
    required Booking booking,
    String? reason,
  }) async {
    try {
      final userId = booking.ownerId;

      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: 'Бронирование отменено',
        message:
            'Клиент отменил бронирование с ${booking.checkInDate.day}.${booking.checkInDate.month}.${booking.checkInDate.year} по ${booking.checkOutDate.day}.${booking.checkOutDate.month}.${booking.checkOutDate.year}. Причина: ${reason ?? "Не указана"}',
        type: NotificationType.bookingCancelled,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint('Уведомление об отмене бронирования отправлено $userId');
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления об отмене бронирования: $e');
    }
  }

  /// Отправляет уведомление клиенту об отклонении бронирования
  Future<void> sendBookingRejectedNotification(
    String userId,
    Booking booking,
  ) async {
    try {
      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: 'Бронирование отклонено',
        message:
            'Ваше бронирование на объект "${booking.propertyId}" было отклонено владельцем.',
        type: NotificationType.bookingRejected,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Отправлено уведомление об отклонении бронирования клиенту: $userId',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления об отклонении бронирования: $e',
      );
    }
  }

  /// Отправляет уведомление об истечении срока ожидания оплаты
  Future<void> sendBookingExpiredNotification({
    required Booking booking,
    String? recipientId,
  }) async {
    try {
      final userId = recipientId ?? booking.userId;

      // Определяем подходящее сообщение в зависимости от типа бронирования
      String messageText;
      if (booking.isHourly && booking.durationHours <= 2) {
        messageText =
            'Время на оплату бронирования (15 минут) с ${booking.checkInDate.day}.${booking.checkInDate.month}.${booking.checkInDate.year} по ${booking.checkOutDate.day}.${booking.checkOutDate.month}.${booking.checkOutDate.year} истекло.';
      } else {
        messageText =
            'Время на оплату бронирования с ${booking.checkInDate.day}.${booking.checkInDate.month}.${booking.checkInDate.year} по ${booking.checkOutDate.day}.${booking.checkOutDate.month}.${booking.checkOutDate.year} истекло.';
      }

      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: 'Срок бронирования истек',
        message: messageText,
        type: NotificationType.bookingExpired,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление об истечении срока бронирования отправлено $userId',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления об истечении срока бронирования: $e',
      );
    }
  }

  /// Отправляет уведомление владельцу о необходимости уборки
  Future<void> sendCleaningNeededNotification({
    required String requestId,
    required String propertyTitle,
    required String ownerId,
  }) async {
    try {
      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: ownerId,
        title: 'Требуется уборка',
        message:
            'Для объекта "$propertyTitle" требуется уборка после выезда гостей.',
        type: NotificationType.cleaningNeeded,
        relatedId: requestId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление о необходимости уборки отправлено владельцу $ownerId',
      );
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления о необходимости уборки: $e');
    }
  }

  /// Отправляет уведомление о запросе на уборку
  Future<void> sendCleaningRequestNotification({
    required String requestId,
    required String propertyTitle,
    required List<String> cleanerIds,
  }) async {
    try {
      for (final cleanerId in cleanerIds) {
        // Создаем новое уведомление для каждого клинера
        final notification = AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: cleanerId,
          title: 'Новый запрос на уборку',
          message: 'Доступен новый запрос на уборку объекта "$propertyTitle".',
          type: NotificationType.cleaningRequest,
          relatedId: requestId,
          isRead: false,
          createdAt: DateTime.now(),
        );

        // Сохраняем уведомление в Firestore
        await _firestore
            .collection('notifications')
            .doc(notification.id)
            .set(notification.toJson());

        debugPrint(
          'Уведомление о запросе на уборку отправлено клинеру $cleanerId',
        );
      }
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления о запросе на уборку: $e');
    }
  }

  /// Отправляет уведомление клинеру о принятии заявки на уборку
  Future<void> sendCleaningApprovedNotification({
    required String requestId,
    required String propertyTitle,
    required String cleanerId,
  }) async {
    try {
      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: cleanerId,
        title: 'Ваше предложение принято',
        message:
            'Владелец принял ваше предложение на уборку объекта "$propertyTitle".',
        type: NotificationType.cleaningApproved,
        relatedId: requestId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление о принятии предложения отправлено клинеру: $cleanerId',
      );
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления о принятии предложения: $e');
    }
  }

  /// Отправляет уведомление о завершении уборки
  Future<void> sendCleaningCompletedNotification({
    required String requestId,
    required String propertyTitle,
    required String ownerId,
  }) async {
    try {
      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: ownerId,
        title: 'Уборка завершена',
        message:
            'Уборка объекта "$propertyTitle" завершена. Пожалуйста, проверьте результат.',
        type: NotificationType.cleaningCompleted,
        relatedId: requestId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление о завершении уборки отправлено владельцу $ownerId',
      );
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления о завершении уборки: $e');
    }
  }

  /// Отправляет уведомление об отмене заявки на уборку
  Future<void> sendCleaningCancelledNotification({
    required String requestId,
    required String propertyTitle,
    required String recipientId,
    String? cancellationReason,
  }) async {
    try {
      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: recipientId,
        title: 'Заявка на уборку отменена',
        message:
            'Заявка на уборку объекта "$propertyTitle" была отменена. ${cancellationReason != null ? 'Причина: $cancellationReason' : ''}',
        type: NotificationType.cleaningCancelled,
        relatedId: requestId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление об отмене заявки на уборку отправлено: $recipientId',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления об отмене заявки на уборку: $e',
      );
    }
  }

  /// Отправляет уведомление владельцу о завершении бронирования
  Future<void> sendBookingCompletedNotification({
    required Booking booking,
  }) async {
    try {
      // Убедимся, что сервисы инициализированы
      await _ensureInitialized();

      // Получаем данные об объекте
      final property = await _propertyService.getPropertyById(
        booking.propertyId,
      );
      if (property == null) {
        throw Exception('Объект не найден');
      }

      // Получаем данные о клиенте
      final client = await _userService.getUserById(booking.userId);
      if (client == null) {
        throw Exception('Клиент не найден');
      }

      // Формируем текст уведомления
      final title = 'Досрочное завершение брони';
      final body =
          'Клиент ${client.fullName} досрочно завершил бронирование объекта "${property.title}". '
          'Теперь объект требует уборки перед следующими гостями.';

      // Создаем уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: booking.ownerId, // Отправляем владельцу
        title: title,
        message: body,
        type: NotificationType.bookingCompleted,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      // Отправляем пуш-уведомление владельцу, если возможно
      await _sendPushNotificationIfPossible(
        userId: booking.ownerId,
        title: title,
        body: body,
        data: {
          'type': notification.type.toString().split('.').last,
          'bookingId': booking.id,
          'propertyId': booking.propertyId,
        },
      );

      debugPrint(
        'Отправлено уведомление о завершении бронирования владельцу: ${booking.ownerId}',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления о завершении бронирования: $e',
      );
    }
  }

  /// Метод для отправки пуш-уведомлений если устройство подключено
  Future<void> _sendPushNotificationIfPossible({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Здесь должна быть логика отправки пуш-уведомлений
      // Используйте Firebase Cloud Messaging или другой сервис
      debugPrint('Отправка пуш-уведомления пользователю $userId: $title');
    } catch (e) {
      debugPrint('Ошибка при отправке пуш-уведомления: $e');
    }
  }

  /// Получает список непрочитанных уведомлений пользователя
  Future<List<AppNotification>> getUnreadNotifications() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Пользователь не авторизован');
      }

      final querySnapshot =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: currentUser.id)
              .where('isRead', isEqualTo: false)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => AppNotification.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении непрочитанных уведомлений: $e');
      return [];
    }
  }

  /// Получает все уведомления пользователя
  Future<List<AppNotification>> getAllNotifications() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Пользователь не авторизован');
      }

      final querySnapshot =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: currentUser.id)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => AppNotification.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении всех уведомлений: $e');
      return [];
    }
  }

  /// Помечает уведомление как прочитанное
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Ошибка при пометке уведомления как прочитанного: $e');
    }
  }

  /// Помечает все уведомления пользователя как прочитанные
  Future<void> markAllAsRead() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Пользователь не авторизован');
      }

      final batch = _firestore.batch();
      final querySnapshot =
          await _firestore
              .collection('notifications')
              .where('userId', isEqualTo: currentUser.id)
              .where('isRead', isEqualTo: false)
              .get();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Ошибка при пометке всех уведомлений как прочитанных: $e');
    }
  }

  /// Удаляет уведомление
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Ошибка при удалении уведомления: $e');
    }
  }

  /// Отправляет уведомление владельцу о новом предложении на уборку
  Future<void> sendCleaningOfferNotification({
    required String requestId,
    required String ownerId,
    required String cleanerName,
    required double price,
    String? message,
  }) async {
    try {
      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: ownerId,
        title: 'Новое предложение на уборку',
        message:
            'Клинер $cleanerName предлагает выполнить уборку за ${price.toStringAsFixed(2)} ₽.${message != null && message.isNotEmpty ? ' Комментарий: $message' : ''}',
        type: NotificationType.cleaningRequest,
        relatedId: requestId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление о новом предложении на уборку отправлено владельцу $ownerId',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления о новом предложении на уборку: $e',
      );
    }
  }

  /// Отправляет уведомление владельцу об обновлении бронирования
  Future<void> sendBookingUpdatedNotification({
    required Booking booking,
  }) async {
    try {
      // Убедимся, что сервисы инициализированы
      await _ensureInitialized();

      final ownerUserId = booking.ownerId;

      // Получаем информацию о свойстве для формирования сообщения
      String propertyInfo = '';
      try {
        final property = await _propertyService.getPropertyById(
          booking.propertyId,
        );
        if (property != null) {
          propertyInfo = ' для объекта "${property.title}"';
        }
      } catch (e) {
        debugPrint('Ошибка при получении данных о собственности: $e');
      }

      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: ownerUserId,
        title: 'Бронирование обновлено',
        message: 'Клиент изменил параметры бронирования$propertyInfo',
        type: NotificationType.bookingUpdated,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Уведомление об обновлении бронирования отправлено владельцу $ownerUserId',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления об обновлении бронирования: $e',
      );
    }
  }

  /// Отправляет уведомление о подтверждении бронирования клиенту
  Future<void> sendBookingConfirmationNotification(
    String userId,
    Booking booking,
  ) async {
    try {
      // Создаем новое уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: 'Бронирование подтверждено',
        message:
            'Ваше бронирование на объект "${booking.propertyId}" было подтверждено владельцем. Пожалуйста, оплатите его в течение 24 часов.',
        type: NotificationType.bookingConfirmed,
        relatedId: booking.id,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint(
        'Отправлено уведомление о подтверждении бронирования клиенту: $userId',
      );
    } catch (e) {
      debugPrint(
        'Ошибка при отправке уведомления о подтверждении бронирования: $e',
      );
    }
  }

  /// Отправляет уведомление о новом отзыве
  Future<void> sendNewReviewNotification({
    required String recipientId,
    required String bookingId,
    required double rating,
  }) async {
    try {
      // Убедимся, что сервисы инициализированы
      await _ensureInitialized();

      // Получаем данные о бронировании
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) {
        debugPrint('Бронирование не найдено: $bookingId');
        return;
      }

      final booking = Booking.fromJson(bookingDoc.data()!);

      // Получаем данные о клиенте
      final client = await _userService.getUserById(booking.userId);
      if (client == null) {
        debugPrint('Клиент не найден: ${booking.userId}');
        return;
      }

      // Получаем данные о свойстве
      final property = await _propertyService.getPropertyById(
        booking.propertyId,
      );
      if (property == null) {
        debugPrint('Свойство не найдено: ${booking.propertyId}');
        return;
      }

      // Формируем сообщение
      String message =
          '${client.firstName} ${client.lastName} оставил отзыв о бронировании "${property.title}" с оценкой ${rating.toStringAsFixed(1)}';

      // Создаем уведомление
      final notification = AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: recipientId,
        title: 'Новый отзыв',
        message: message,
        type: NotificationType.newReview,
        relatedId: bookingId,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Сохраняем уведомление в Firestore
      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      debugPrint('Уведомление о новом отзыве отправлено $recipientId');
    } catch (e) {
      debugPrint('Ошибка при отправке уведомления о новом отзыве: $e');
    }
  }
}
