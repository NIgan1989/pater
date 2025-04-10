import 'package:equatable/equatable.dart';

/// Статус заявки на уборку
enum CleaningRequestStatus {
  /// Ожидает предложений от клинеров
  withOffers,
  
  /// Ожидает назначения клинера
  waitingCleaner,
  
  /// Ожидает подтверждения от владельца
  pendingApproval,
  
  /// Подтверждено, ожидает выполнения
  approved,
  
  /// В процессе выполнения
  inProgress,
  
  /// Завершена
  completed,
  
  /// Отменена
  cancelled,
  
  /// Активная заявка
  active,
  
  /// Принята клинером
  accepted,
  
  /// Ожидает (для совместимости со старым кодом)
  pending,
  
  /// Назначена клинеру (для совместимости со старым кодом)
  assigned,
  
  /// Отклонена 
  rejected
}

/// Тип уборки
enum CleaningType {
  /// Обычная уборка
  regular,
  
  /// Генеральная уборка
  general,
  
  /// Уборка после ремонта
  postConstruction,
  
  /// После выезда гостей
  afterGuests,
  
  /// Базовая уборка
  basic,
  
  /// Глубокая уборка
  deep,
  
  /// Уборка после ремонта (альтернативное название)
  postConstruction2,
  
  /// Мытьё окон
  window,
  
  /// Чистка ковров
  carpet
}

/// Срочность уборки
enum CleaningUrgency {
  /// Низкая срочность (в течение недели)
  low,
  
  /// Средняя срочность (в течение 3-4 дней)
  medium,
  
  /// Высокая срочность (в течение 1-2 дней)
  high,
  
  /// Срочная (в течение 24 часов)
  urgent
}

/// Класс, представляющий заявку на уборку
class CleaningRequest extends Equatable {
  /// Уникальный идентификатор заявки
  final String id;
  
  /// Идентификатор объекта недвижимости
  final String propertyId;
  
  /// Идентификатор владельца
  final String ownerId;
  
  /// Идентификатор клинера (если назначен)
  final String? cleanerId;
  
  /// Статус заявки
  final CleaningRequestStatus status;
  
  /// Тип уборки
  final CleaningType cleaningType;
  
  /// Запланированная дата и время уборки
  final DateTime scheduledDate;
  
  /// Предполагаемая стоимость уборки
  final double estimatedPrice;
  
  /// Фактическая стоимость (после выполнения)
  final double? actualPrice;
  
  /// Описание/комментарий к заявке
  final String description;
  
  /// Дополнительные услуги
  final List<String> additionalServices;
  
  /// Срочность заявки
  final CleaningUrgency urgency;
  
  /// Адрес объекта
  final String address;
  
  /// Город
  final String city;
  
  /// Предложения от клинеров
  final List<CleaningOffer>? offers;
  
  /// Рейтинг уборки (0-5)
  final double? rating;
  
  /// Текст отзыва
  final String? reviewText;
  
  /// Дата создания заявки
  final DateTime createdAt;
  
  /// Дата подтверждения владельцем
  final DateTime? approvedAt;
  
  /// Дата начала уборки
  final DateTime? startedAt;
  
  /// Дата завершения уборки
  final DateTime? completedAt;
  
  /// Дата отмены
  final DateTime? cancelledAt;
  
  /// Причина отмены
  final String? cancellationReason;
  
  /// Фотографии "до" уборки
  final List<String>? beforePhotos;
  
  /// Фотографии "после" уборки
  final List<String>? afterPhotos;
  
  /// Создает экземпляр [CleaningRequest]
  const CleaningRequest({
    required this.id,
    required this.propertyId,
    required this.ownerId,
    this.cleanerId,
    required this.status,
    required this.cleaningType,
    required this.scheduledDate,
    required this.estimatedPrice,
    this.actualPrice,
    required this.description,
    required this.address,
    required this.city,
    this.additionalServices = const [],
    this.urgency = CleaningUrgency.low,
    this.offers,
    this.rating,
    this.reviewText,
    required this.createdAt,
    this.approvedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.beforePhotos,
    this.afterPhotos,
  });
  
  /// Создает копию объекта с измененными полями
  CleaningRequest copyWith({
    String? id,
    String? propertyId,
    String? ownerId,
    String? cleanerId,
    CleaningRequestStatus? status,
    CleaningType? cleaningType,
    DateTime? scheduledDate,
    double? estimatedPrice,
    double? actualPrice,
    String? description,
    String? address,
    String? city,
    List<String>? additionalServices,
    CleaningUrgency? urgency,
    List<CleaningOffer>? offers,
    double? rating,
    String? reviewText,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    List<String>? beforePhotos,
    List<String>? afterPhotos,
  }) {
    return CleaningRequest(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      ownerId: ownerId ?? this.ownerId,
      cleanerId: cleanerId ?? this.cleanerId,
      status: status ?? this.status,
      cleaningType: cleaningType ?? this.cleaningType,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      actualPrice: actualPrice ?? this.actualPrice,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      additionalServices: additionalServices ?? this.additionalServices,
      urgency: urgency ?? this.urgency,
      offers: offers ?? this.offers,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      beforePhotos: beforePhotos ?? this.beforePhotos,
      afterPhotos: afterPhotos ?? this.afterPhotos,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    propertyId,
    ownerId,
    cleanerId,
    status,
    cleaningType,
    scheduledDate,
    estimatedPrice,
    actualPrice,
    description,
    address,
    city,
    additionalServices,
    urgency,
    offers,
    rating,
    reviewText,
    createdAt,
    approvedAt,
    startedAt,
    completedAt,
    cancelledAt,
    cancellationReason,
    beforePhotos,
    afterPhotos,
  ];
  
  /// Преобразует объект в карту для хранения в Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'property_id': propertyId,
      'owner_id': ownerId,
      'cleaner_id': cleanerId,
      'status': status.toString().split('.').last,
      'cleaning_type': cleaningType.toString().split('.').last,
      'scheduled_date': scheduledDate.toIso8601String(),
      'estimated_price': estimatedPrice,
      'actual_price': actualPrice,
      'description': description,
      'address': address,
      'city': city,
      'additional_services': additionalServices,
      'urgency': urgency.toString().split('.').last,
      'offers': offers?.map((offer) => offer.toMap()).toList(),
      'rating': rating,
      'review_text': reviewText,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'before_photos': beforePhotos,
      'after_photos': afterPhotos,
    };
  }
  
  /// Создает объект [CleaningRequest] из карты
  factory CleaningRequest.fromMap(Map<String, dynamic> map) {
    final offersData = map['offers'] as List<dynamic>?;
    final List<CleaningOffer>? offers = offersData?.map((e) => CleaningOffer.fromMap(e as Map<String, dynamic>)).toList();

    return CleaningRequest(
      id: map['id'] as String,
      propertyId: map['property_id'] as String,
      ownerId: map['owner_id'] as String,
      cleanerId: map['cleaner_id'] as String?,
      status: _stringToStatus(map['status'] as String),
      cleaningType: _stringToType(map['cleaning_type'] as String),
      scheduledDate: DateTime.parse(map['scheduled_date'] as String),
      estimatedPrice: (map['estimated_price'] as num).toDouble(),
      actualPrice: map['actual_price'] != null ? (map['actual_price'] as num).toDouble() : null,
      description: map['description'] as String,
      address: map['address'] as String,
      city: map['city'] as String,
      additionalServices: (map['additional_services'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      urgency: _stringToUrgency(map['urgency'] as String),
      offers: offers,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      reviewText: map['review_text'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      approvedAt: map['approved_at'] != null ? DateTime.parse(map['approved_at'] as String) : null,
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at'] as String) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
      cancelledAt: map['cancelled_at'] != null ? DateTime.parse(map['cancelled_at'] as String) : null,
      cancellationReason: map['cancellation_reason'] as String?,
      beforePhotos: (map['before_photos'] as List<dynamic>?)?.map((e) => e as String).toList(),
      afterPhotos: (map['after_photos'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }
  
  /// Преобразует строковое представление в статус заявки на уборку
  static CleaningRequestStatus _stringToStatus(String status) {
    switch (status) {
      case 'withOffers':
        return CleaningRequestStatus.withOffers;
      case 'waitingCleaner':
        return CleaningRequestStatus.waitingCleaner;
      case 'pendingApproval':
        return CleaningRequestStatus.pendingApproval;
      case 'approved':
        return CleaningRequestStatus.approved;
      case 'inProgress':
        return CleaningRequestStatus.inProgress;
      case 'completed':
        return CleaningRequestStatus.completed;
      case 'cancelled':
        return CleaningRequestStatus.cancelled;
      case 'active':
        return CleaningRequestStatus.active;
      case 'accepted':
        return CleaningRequestStatus.accepted;
      case 'pending': // Для обратной совместимости
        return CleaningRequestStatus.pendingApproval;
      case 'assigned':
        return CleaningRequestStatus.assigned;
      case 'rejected':
        return CleaningRequestStatus.rejected;
      default:
        return CleaningRequestStatus.waitingCleaner;
    }
  }
  
  /// Преобразует строковое представление в тип уборки
  static CleaningType _stringToType(String type) {
    switch (type) {
      case 'regular':
        return CleaningType.regular;
      case 'general':
        return CleaningType.general;
      case 'postConstruction':
        return CleaningType.postConstruction;
      case 'afterGuests':
        return CleaningType.afterGuests;
      case 'basic':
        return CleaningType.basic;
      case 'deep':
        return CleaningType.deep;
      case 'postConstruction2':
        return CleaningType.postConstruction2;
      case 'window':
        return CleaningType.window;
      case 'carpet':
        return CleaningType.carpet;
      default:
        return CleaningType.regular;
    }
  }
  
  /// Преобразует строковое представление в срочность уборки
  static CleaningUrgency _stringToUrgency(String urgency) {
    switch (urgency) {
      case 'low':
        return CleaningUrgency.low;
      case 'medium':
        return CleaningUrgency.medium;
      case 'high':
        return CleaningUrgency.high;
      case 'urgent':
        return CleaningUrgency.urgent;
      default:
        return CleaningUrgency.low;
    }
  }
}

/// Класс для предложений от клинеров на выполнение уборки
class CleaningOffer {
  /// Идентификатор предложения
  final String id;
  
  /// Идентификатор клинера
  final String cleanerId;
  
  /// Имя клинера
  final String cleanerName;
  
  /// Предложенная цена
  final double price;
  
  /// Сообщение/комментарий к предложению
  final String? message;
  
  /// Статус предложения (pending, accepted, rejected)
  final String status;
  
  /// Дата создания предложения
  final DateTime createdAt;
  
  /// Конструктор
  CleaningOffer({
    required this.id,
    required this.cleanerId,
    required this.cleanerName,
    required this.price,
    this.message,
    required this.status,
    required this.createdAt,
  });
  
  /// Создает копию объекта с измененными полями
  CleaningOffer copyWith({
    String? id,
    String? cleanerId,
    String? cleanerName,
    double? price,
    String? message,
    String? status,
    DateTime? createdAt,
  }) {
    return CleaningOffer(
      id: id ?? this.id,
      cleanerId: cleanerId ?? this.cleanerId,
      cleanerName: cleanerName ?? this.cleanerName,
      price: price ?? this.price,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
  
  /// Преобразует в Map для сохранения в Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cleaner_id': cleanerId,
      'cleaner_name': cleanerName,
      'price': price,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  /// Создает объект из Map
  factory CleaningOffer.fromMap(Map<String, dynamic> map) {
    return CleaningOffer(
      id: map['id'] as String,
      cleanerId: map['cleaner_id'] as String,
      cleanerName: map['cleaner_name'] as String,
      price: (map['price'] as num).toDouble(),
      message: map['message'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
} 