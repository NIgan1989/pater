import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Статусы бронирования
enum BookingStatus {
  /// Ожидает подтверждения владельцем
  pendingApproval,

  /// Подтверждено владельцем, ожидает оплаты
  waitingPayment,

  /// Оплачено, но еще не активно
  paid,

  /// Активно (клиент заселился)
  active,

  /// Завершено
  completed,

  /// Отменено
  cancelled,

  /// Отменено клиентом
  cancelledByClient,

  /// Отклонено владельцем
  rejectedByOwner,

  /// Ожидает (для совместимости с существующим кодом)
  pending,

  /// Подтверждено (для совместимости с существующим кодом)
  confirmed,

  /// Истекло время бронирования
  expired,
}

/// Класс, представляющий бронирование жилья
class Booking extends Equatable {
  /// Уникальный идентификатор бронирования
  final String id;

  /// Идентификатор пользователя (клиента)
  final String userId;

  /// Идентификатор клиента (для совместимости)
  String get clientId => userId;

  /// Идентификатор объекта
  final String propertyId;

  /// Идентификатор владельца
  final String ownerId;

  /// Дата заезда
  final DateTime checkInDate;

  /// Дата выезда
  final DateTime checkOutDate;

  /// Рассчитывает продолжительность бронирования в часах
  int get durationHours {
    return checkOutDate.difference(checkInDate).inHours;
  }

  /// Рассчитывает продолжительность бронирования в днях
  int get durationDays {
    final duration = checkOutDate.difference(checkInDate);
    return (duration.inHours / 24).ceil();
  }

  /// Количество гостей
  final int guestsCount;

  /// Дополнительные запросы клиента
  final String? specialRequests;

  /// Комментарий клиента
  final String? clientComment;

  /// Общая стоимость бронирования
  final double totalPrice;

  /// Стоимость уборки
  final double cleaningFee;

  /// Стоимость сервисного сбора
  final double serviceFee;

  /// Размер скидки (если есть)
  final double discount;

  /// Статус бронирования
  final BookingStatus status;

  /// Причина отмены или отклонения
  final String? cancellationReason;

  /// Флаг оплаты (true - оплачено, false - не оплачено)
  final bool isPaid;

  /// Флаг почасовой аренды (true - почасовая, false - посуточная)
  final bool isHourly;

  /// Система оплаты
  final String? paymentMethod;

  /// Идентификатор платежной транзакции
  final String? paymentTransactionId;

  /// Дата подтверждения бронирования владельцем
  final DateTime? approvedAt;

  /// Дата оплаты бронирования
  final DateTime? paidAt;

  /// Дата создания бронирования
  final DateTime createdAt;

  /// Дата последнего обновления
  final DateTime updatedAt;

  /// Рейтинг (оценка пользователя)
  final double? rating;

  /// Рейтинг клиента
  final double? clientRating;

  /// Текст отзыва
  final String? review;

  /// Отзыв клиента
  final String? clientReview;

  /// Дата отзыва клиента
  final DateTime? clientReviewDate;

  /// Флаг наличия отзыва
  final bool hasReview;

  /// Статус уборки
  final bool isCleaningCompleted;

  /// Проверяет, истекло ли время бронирования
  bool get isExpired {
    final now = DateTime.now();
    return checkOutDate.isBefore(now);
  }

  /// Возвращает время истечения для подтверждения бронирования
  DateTime getApprovalExpirationTime() {
    final now = DateTime.now();
    final timeToCheckIn = checkInDate.difference(now);

    // Если до начала бронирования меньше 24 часов
    if (timeToCheckIn.inHours < 24) {
      // Время на подтверждение = время до начала минус 1 час
      return checkInDate.subtract(const Duration(hours: 1));
    } else {
      // Иначе 24 часа с момента создания
      return createdAt.add(const Duration(hours: 24));
    }
  }

  /// Возвращает время истечения для оплаты бронирования
  DateTime getPaymentExpirationTime() {
    if (approvedAt == null) return DateTime.now();

    final now = DateTime.now();
    final timeToCheckIn = checkInDate.difference(now);

    // Если это почасовая аренда и длительность <= 2 часов
    if (isHourly && durationHours <= 2) {
      // Даем только 15 минут на оплату с момента подтверждения
      return approvedAt!.add(const Duration(minutes: 15));
    }

    // Если до начала бронирования меньше 24 часов
    if (timeToCheckIn.inHours < 24) {
      // Время на оплату = время до начала минус 30 минут
      return checkInDate.subtract(const Duration(minutes: 30));
    } else {
      // Стандартное время - 24 часа с момента подтверждения
      return approvedAt!.add(const Duration(hours: 24));
    }
  }

  /// Проверяет, истекло ли время ожидания подтверждения
  bool get isApprovalExpired {
    final now = DateTime.now();
    return now.isAfter(getApprovalExpirationTime());
  }

  /// Проверяет, истекло ли время ожидания оплаты
  bool get isPaymentExpired {
    if (approvedAt == null) return false;
    final now = DateTime.now();
    return now.isAfter(getPaymentExpirationTime());
  }

  /// Конструктор
  const Booking({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.ownerId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.guestsCount,
    this.specialRequests,
    this.clientComment,
    required this.totalPrice,
    this.cleaningFee = 0,
    this.serviceFee = 0,
    this.discount = 0,
    this.status = BookingStatus.pendingApproval,
    this.cancellationReason,
    this.isPaid = false,
    this.isHourly = false,
    this.paymentMethod,
    this.paymentTransactionId,
    this.approvedAt,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
    this.rating,
    this.review,
    this.clientRating,
    this.clientReview,
    this.clientReviewDate,
    this.hasReview = false,
    this.isCleaningCompleted = false,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    propertyId,
    ownerId,
    checkInDate,
    checkOutDate,
    guestsCount,
    specialRequests,
    clientComment,
    totalPrice,
    cleaningFee,
    serviceFee,
    discount,
    status,
    cancellationReason,
    isPaid,
    isHourly,
    paymentMethod,
    paymentTransactionId,
    approvedAt,
    paidAt,
    createdAt,
    updatedAt,
    rating,
    review,
    clientRating,
    clientReview,
    clientReviewDate,
    hasReview,
    isCleaningCompleted,
  ];

  /// Копирует объект с новыми значениями
  Booking copyWith({
    String? id,
    String? userId,
    String? propertyId,
    String? ownerId,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    int? guestsCount,
    String? specialRequests,
    String? clientComment,
    double? totalPrice,
    double? cleaningFee,
    double? serviceFee,
    double? discount,
    BookingStatus? status,
    String? cancellationReason,
    bool? isPaid,
    bool? isHourly,
    String? paymentMethod,
    String? paymentTransactionId,
    DateTime? approvedAt,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? rating,
    String? review,
    double? clientRating,
    String? clientReview,
    DateTime? clientReviewDate,
    bool? hasReview,
    bool? isCleaningCompleted,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      propertyId: propertyId ?? this.propertyId,
      ownerId: ownerId ?? this.ownerId,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      guestsCount: guestsCount ?? this.guestsCount,
      specialRequests: specialRequests ?? this.specialRequests,
      clientComment: clientComment ?? this.clientComment,
      totalPrice: totalPrice ?? this.totalPrice,
      cleaningFee: cleaningFee ?? this.cleaningFee,
      serviceFee: serviceFee ?? this.serviceFee,
      discount: discount ?? this.discount,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isPaid: isPaid ?? this.isPaid,
      isHourly: isHourly ?? this.isHourly,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      approvedAt: approvedAt ?? this.approvedAt,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      clientRating: clientRating ?? this.clientRating,
      clientReview: clientReview ?? this.clientReview,
      clientReviewDate: clientReviewDate ?? this.clientReviewDate,
      hasReview: hasReview ?? this.hasReview,
      isCleaningCompleted: isCleaningCompleted ?? this.isCleaningCompleted,
    );
  }

  /// Преобразует объект в карту JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'propertyId': propertyId,
      'ownerId': ownerId,
      'checkInDate': Timestamp.fromDate(checkInDate),
      'checkOutDate': Timestamp.fromDate(checkOutDate),
      'guestsCount': guestsCount,
      'specialRequests': specialRequests,
      'clientComment': clientComment,
      'totalPrice': totalPrice,
      'cleaningFee': cleaningFee,
      'serviceFee': serviceFee,
      'discount': discount,
      'status': status.toString().split('.').last,
      'cancellationReason': cancellationReason,
      'isPaid': isPaid,
      'isHourly': isHourly,
      'paymentMethod': paymentMethod,
      'paymentTransactionId': paymentTransactionId,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'rating': rating,
      'review': review,
      'clientRating': clientRating,
      'clientReview': clientReview,
      'clientReviewDate':
          clientReviewDate != null
              ? Timestamp.fromDate(clientReviewDate!)
              : null,
      'hasReview': hasReview,
      'isCleaningCompleted': isCleaningCompleted,
    };
  }

  /// Создает объект из карты JSON
  factory Booking.fromJson(Map<String, dynamic> json) {
    DateTime? approvedAt;
    if (json['approvedAt'] != null) {
      approvedAt =
          (json['approvedAt'] is Timestamp)
              ? (json['approvedAt'] as Timestamp).toDate()
              : (json['approvedAt'] is String)
              ? DateTime.parse(json['approvedAt'] as String)
              : null;
    }

    DateTime? paidAt;
    if (json['paidAt'] != null) {
      paidAt =
          (json['paidAt'] is Timestamp)
              ? (json['paidAt'] as Timestamp).toDate()
              : (json['paidAt'] is String)
              ? DateTime.parse(json['paidAt'] as String)
              : null;
    }

    // Добавляем проверку типа для checkInDate и checkOutDate
    DateTime checkInDate;
    if (json['checkInDate'] is Timestamp) {
      checkInDate = (json['checkInDate'] as Timestamp).toDate();
    } else if (json['checkInDate'] is String) {
      checkInDate = DateTime.parse(json['checkInDate'] as String);
    } else {
      checkInDate = DateTime.now(); // Значение по умолчанию
      debugPrint('Ошибка типа в checkInDate: ${json['checkInDate']}');
    }

    DateTime checkOutDate;
    if (json['checkOutDate'] is Timestamp) {
      checkOutDate = (json['checkOutDate'] as Timestamp).toDate();
    } else if (json['checkOutDate'] is String) {
      checkOutDate = DateTime.parse(json['checkOutDate'] as String);
    } else {
      checkOutDate = DateTime.now().add(
        const Duration(days: 1),
      ); // Значение по умолчанию
      debugPrint('Ошибка типа в checkOutDate: ${json['checkOutDate']}');
    }

    // Проверка типа для createdAt
    DateTime createdAt;
    if (json['createdAt'] is Timestamp) {
      createdAt = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      createdAt = DateTime.parse(json['createdAt'] as String);
    } else {
      createdAt = DateTime.now(); // Значение по умолчанию
      debugPrint('Ошибка типа в createdAt: ${json['createdAt']}');
    }

    // Проверка типа для updatedAt
    DateTime updatedAt;
    if (json['updatedAt'] is Timestamp) {
      updatedAt = (json['updatedAt'] as Timestamp).toDate();
    } else if (json['updatedAt'] is String) {
      updatedAt = DateTime.parse(json['updatedAt'] as String);
    } else {
      updatedAt = DateTime.now(); // Значение по умолчанию
      debugPrint('Ошибка типа в updatedAt: ${json['updatedAt']}');
    }

    DateTime? clientReviewDate;
    if (json['clientReviewDate'] != null) {
      if (json['clientReviewDate'] is Timestamp) {
        clientReviewDate = (json['clientReviewDate'] as Timestamp).toDate();
      } else if (json['clientReviewDate'] is String) {
        clientReviewDate = DateTime.parse(json['clientReviewDate'] as String);
      }
    }

    return Booking(
      id: json['id'] as String,
      userId: json['userId'] as String,
      propertyId: json['propertyId'] as String,
      ownerId: json['ownerId'] as String,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      guestsCount: json['guestsCount'] as int,
      specialRequests: json['specialRequests'] as String?,
      clientComment: json['clientComment'] as String?,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      cleaningFee:
          json['cleaningFee'] != null
              ? (json['cleaningFee'] as num).toDouble()
              : 0,
      serviceFee:
          json['serviceFee'] != null
              ? (json['serviceFee'] as num).toDouble()
              : 0,
      discount:
          json['discount'] != null ? (json['discount'] as num).toDouble() : 0,
      status: _parseBookingStatus(json['status'] as String),
      cancellationReason: json['cancellationReason'] as String?,
      isPaid: json['isPaid'] as bool? ?? false,
      isHourly: json['isHourly'] as bool? ?? false,
      paymentMethod: json['paymentMethod'] as String?,
      paymentTransactionId: json['paymentTransactionId'] as String?,
      approvedAt: approvedAt,
      paidAt: paidAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      rating:
          json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      review: json['review'] as String?,
      clientRating:
          json['clientRating'] != null
              ? (json['clientRating'] as num).toDouble()
              : null,
      clientReview: json['clientReview'] as String?,
      clientReviewDate: clientReviewDate,
      hasReview: json['hasReview'] as bool? ?? false,
      isCleaningCompleted: json['isCleaningCompleted'] as bool? ?? false,
    );
  }

  /// Преобразует строку в статус бронирования
  static BookingStatus _parseBookingStatus(String status) {
    switch (status) {
      case 'pendingApproval':
        return BookingStatus.pendingApproval;
      case 'waitingPayment':
        return BookingStatus.waitingPayment;
      case 'paid':
        return BookingStatus.paid;
      case 'active':
        return BookingStatus.active;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'cancelledByClient':
        return BookingStatus.cancelledByClient;
      case 'rejectedByOwner':
        return BookingStatus.rejectedByOwner;
      case 'pending':
        return BookingStatus.pending;
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'expired':
        return BookingStatus.expired;
      default:
        return BookingStatus.pendingApproval;
    }
  }
}
