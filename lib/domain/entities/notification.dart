/// Типы уведомлений
enum NotificationType {
  /// Новое бронирование
  newBooking,
  
  /// Подтверждение бронирования
  bookingApproved,
  
  /// Отклонение бронирования
  bookingRejected,
  
  /// Отмена бронирования
  bookingCancelled,
  
  /// Бронирование оплачено
  bookingPaid,
  
  /// Бронирование активировано
  bookingActivated,
  
  /// Срок ожидания оплаты истек
  bookingExpired,
  
  /// Необходимость организовать уборку
  cleaningNeeded,
  
  /// Запрос на уборку
  cleaningRequest,
  
  /// Уборка подтверждена
  cleaningApproved,
  
  /// Уборка завершена
  cleaningCompleted,
  
  /// Уборка отменена
  cleaningCancelled,
  
  /// Уведомление о заезде
  checkIn,
  
  /// Уведомление о выезде
  checkOut,
  
  /// Уведомление об оплате
  payment,
  
  /// Новый отзыв
  newReview,
  
  /// Системное уведомление
  system,
  
  /// Новое сообщение
  newMessage,
  
  /// Бронирование подтверждено
  bookingConfirmed,
  
  /// Бронирование завершено
  bookingCompleted,
  
  /// Новый запрос на уборку
  newCleaningRequest,
  
  /// Уборка назначена
  cleaningAssigned,
  
  /// Изменение статуса объекта
  propertyStatusChange,
  
  /// Обновление бронирования
  bookingUpdated,
}

/// Класс уведомления пользователя
class AppNotification {
  /// Уникальный идентификатор уведомления
  final String id;
  
  /// Идентификатор пользователя
  final String userId;
  
  /// Заголовок уведомления
  final String title;
  
  /// Текст уведомления
  final String message;
  
  /// Тип уведомления
  final NotificationType type;
  
  /// Связанный идентификатор (например, ID бронирования или сообщения)
  final String relatedId;
  
  /// Прочитано ли уведомление
  final bool isRead;
  
  /// Дата создания уведомления
  final DateTime createdAt;
  
  /// Дополнительные данные уведомления
  final Map<String, dynamic>? extras;
  
  /// Конструктор
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.extras,
  });
  
  /// Создает JSON-представление объекта
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type.toString().split('.').last,
      'related_id': relatedId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'extras': extras,
    };
  }
  
  /// Создает объект из JSON
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType notificationType;
    
    try {
      final typeStr = json['type'];
      
      switch (typeStr) {
        case 'newBooking':
          notificationType = NotificationType.newBooking;
          break;
        case 'bookingApproved':
          notificationType = NotificationType.bookingApproved;
          break;
        case 'bookingRejected':
          notificationType = NotificationType.bookingRejected;
          break;
        case 'bookingCancelled':
          notificationType = NotificationType.bookingCancelled;
          break;
        case 'bookingPaid':
          notificationType = NotificationType.bookingPaid;
          break;
        case 'bookingActivated':
          notificationType = NotificationType.bookingActivated;
          break;
        case 'bookingExpired':
          notificationType = NotificationType.bookingExpired;
          break;
        case 'cleaningNeeded':
          notificationType = NotificationType.cleaningNeeded;
          break;
        case 'cleaningRequest':
          notificationType = NotificationType.cleaningRequest;
          break;
        case 'cleaningApproved':
          notificationType = NotificationType.cleaningApproved;
          break;
        case 'cleaningCompleted':
          notificationType = NotificationType.cleaningCompleted;
          break;
        case 'cleaningCancelled':
          notificationType = NotificationType.cleaningCancelled;
          break;
        case 'newMessage':
          notificationType = NotificationType.newMessage;
          break;
        case 'bookingConfirmed': // Для обратной совместимости
          notificationType = NotificationType.bookingApproved;
          break;
        case 'bookingCompleted':
          notificationType = NotificationType.bookingCompleted;
          break;
        case 'newCleaningRequest':
          notificationType = NotificationType.newCleaningRequest;
          break;
        case 'cleaningAssigned':
          notificationType = NotificationType.cleaningAssigned;
          break;
        case 'propertyStatusChange':
          notificationType = NotificationType.propertyStatusChange;
          break;
        case 'bookingUpdated':
          notificationType = NotificationType.bookingUpdated;
          break;
        default:
          notificationType = NotificationType.system;
      }
    } catch (e) {
      notificationType = NotificationType.system;
    }
    
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      type: notificationType,
      relatedId: json['related_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      extras: json['extras'],
    );
  }
  
  /// Создает копию объекта с новыми значениями
  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? relatedId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? extras,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      extras: extras ?? this.extras,
    );
  }
} 