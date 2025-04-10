import 'package:equatable/equatable.dart';

/// Статус объекта недвижимости
enum PropertyStatus {
  /// Доступно для бронирования
  available,
  
  /// Забронировано
  booked,
  
  /// На уборке
  cleaning,
  
  /// На ремонте
  maintenance,
  
  /// Недоступен
  unavailable,
  
  /// Заблокирован
  blocked
}

/// Подстатусы объекта недвижимости для детального отслеживания процесса
class PropertySubStatus {
  static const String none = 'none';
  static const String pendingRequest = 'pending_request';       // Ожидает подтверждения бронирования
  static const String approvedPendingPayment = 'approved_pending_payment'; // Подтверждено, ожидает оплаты
  static const String waitingPayment = 'waiting_payment';       // Ожидает оплаты (для обратной совместимости)
  static const String waitingCleaning = 'waiting_cleaning';     // Ожидает уборки
  static const String pendingCleaningRequest = 'pending_cleaning_request'; // Ожидает подтверждения уборки
}

/// Тип объекта недвижимости
enum PropertyType {
  /// Квартира
  apartment,
  
  /// Дом
  house,
  
  /// Комната
  room,
  
  /// Хостел
  hostel
}

/// Класс, представляющий объект недвижимости в системе
class Property extends Equatable {
  /// Уникальный идентификатор объекта
  final String id;
  
  /// Название объекта
  final String title;
  
  /// Описание объекта
  final String description;
  
  /// Идентификатор владельца
  final String ownerId;
  
  /// Тип объекта
  final PropertyType type;
  
  /// Статус объекта
  final PropertyStatus status;
  
  /// Подстатус объекта для более детального отслеживания
  final String subStatus;
  
  /// Время окончания бронирования для таймера обратного отсчета
  final DateTime? bookingEndTime;
  
  /// ID текущего активного бронирования
  final String? bookingId;
  
  /// URL изображений объекта
  final List<String> imageUrls;
  
  /// Основное изображение объекта
  final String imageUrl;
  
  /// Адрес объекта
  final String address;
  
  /// Город
  final String city;
  
  /// Страна
  final String country;
  
  /// Географическая широта
  final double latitude;
  
  /// Географическая долгота
  final double longitude;
  
  /// Цена за ночь (в тенге)
  final double pricePerNight;
  
  /// Цена за час (в тенге)
  final double pricePerHour;
  
  /// Площадь объекта (в кв. метрах)
  final double area;
  
  /// Количество комнат
  final int rooms;
  
  /// Количество ванных комнат
  final int bathrooms;
  
  /// Максимальное количество гостей
  final int maxGuests;
  
  /// Флаг добавления в избранное
  final bool isFavorite;
  
  /// Наличие Wi-Fi
  final bool hasWifi;
  
  /// Наличие кондиционера
  final bool hasAirConditioning;
  
  /// Наличие кухни
  final bool hasKitchen;
  
  /// Наличие телевизора
  final bool hasTV;
  
  /// Наличие стиральной машины
  final bool hasWashingMachine;
  
  /// Наличие парковки
  final bool hasParking;
  
  /// Разрешены ли домашние животные
  final bool petFriendly;
  
  /// Время заселения (формат: чч:мм)
  final String checkInTime;
  
  /// Время выселения (формат: чч:мм)
  final String checkOutTime;
  
  /// Рейтинг объекта (от 0 до 5)
  final double rating;
  
  /// Количество отзывов об объекте
  final int reviewsCount;
  
  /// Является ли объект рекомендуемым/избранным
  final bool isFeatured;
  
  /// Находится ли объект на модерации
  final bool isOnModeration;
  
  /// Активен ли объект (доступен для бронирования)
  final bool isActive;
  
  /// Количество просмотров объекта
  final int views;
  
  /// Создает экземпляр [Property]
  const Property({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.type,
    required this.status,
    this.subStatus = PropertySubStatus.none,
    this.bookingEndTime,
    this.bookingId,
    required this.imageUrls,
    this.imageUrl = '',
    required this.address,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.pricePerNight,
    required this.pricePerHour,
    required this.area,
    required this.rooms,
    this.bathrooms = 1,
    required this.maxGuests,
    this.isFavorite = false,
    this.hasWifi = false,
    this.hasAirConditioning = false,
    this.hasKitchen = false,
    this.hasTV = false,
    this.hasWashingMachine = false,
    this.hasParking = false,
    this.petFriendly = false,
    required this.checkInTime,
    required this.checkOutTime,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.isFeatured = false,
    this.isOnModeration = false,
    this.isActive = true,
    this.views = 0,
  });
  
  /// Получить цену за ночь (для совместимости с кодом)
  double get price => pricePerNight;
  
  /// Получить количество комнат
  int get roomCount => rooms;
  
  /// Получить количество ванных комнат
  int get bathroomCount => bathrooms;
  
  /// Получить максимальное количество гостей
  int get guestCount => maxGuests;
  
  /// Получить количество спален (предполагаем, что количество спален равно количеству комнат - 1)
  int get bedroomCount => rooms > 1 ? rooms - 1 : 1;
  
  /// Создает копию объекта с измененными параметрами
  Property copyWith({
    String? id,
    String? title,
    String? description,
    String? ownerId,
    PropertyType? type,
    PropertyStatus? status,
    String? subStatus,
    DateTime? bookingEndTime,
    String? bookingId,
    List<String>? imageUrls,
    String? imageUrl,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    double? pricePerNight,
    double? pricePerHour,
    double? area,
    int? rooms,
    int? bathrooms,
    int? maxGuests,
    bool? isFavorite,
    bool? hasWifi,
    bool? hasAirConditioning,
    bool? hasKitchen,
    bool? hasTV,
    bool? hasWashingMachine,
    bool? hasParking,
    bool? petFriendly,
    String? checkInTime,
    String? checkOutTime,
    double? rating,
    int? reviewsCount,
    bool? isFeatured,
    bool? isOnModeration,
    bool? isActive,
    int? views,
  }) {
    return Property(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      type: type ?? this.type,
      status: status ?? this.status,
      subStatus: subStatus ?? this.subStatus,
      bookingEndTime: bookingEndTime ?? this.bookingEndTime,
      bookingId: bookingId ?? this.bookingId,
      imageUrls: imageUrls ?? this.imageUrls,
      imageUrl: imageUrl ?? this.imageUrl,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      area: area ?? this.area,
      rooms: rooms ?? this.rooms,
      bathrooms: bathrooms ?? this.bathrooms,
      maxGuests: maxGuests ?? this.maxGuests,
      isFavorite: isFavorite ?? this.isFavorite,
      hasWifi: hasWifi ?? this.hasWifi,
      hasAirConditioning: hasAirConditioning ?? this.hasAirConditioning,
      hasKitchen: hasKitchen ?? this.hasKitchen,
      hasTV: hasTV ?? this.hasTV,
      hasWashingMachine: hasWashingMachine ?? this.hasWashingMachine,
      hasParking: hasParking ?? this.hasParking,
      petFriendly: petFriendly ?? this.petFriendly,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isFeatured: isFeatured ?? this.isFeatured,
      isOnModeration: isOnModeration ?? this.isOnModeration,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    title,
    description,
    ownerId,
    type,
    status,
    subStatus,
    bookingEndTime,
    bookingId,
    imageUrls,
    imageUrl,
    address,
    city,
    country,
    latitude,
    longitude,
    pricePerNight,
    pricePerHour,
    area,
    rooms,
    bathrooms,
    maxGuests,
    isFavorite,
    hasWifi,
    hasAirConditioning,
    hasKitchen,
    hasTV,
    hasWashingMachine,
    hasParking,
    petFriendly,
    checkInTime,
    checkOutTime,
    rating,
    reviewsCount,
    isFeatured,
    isOnModeration,
    isActive,
    views,
  ];
  
  /// Преобразует объект в Map для сохранения в Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'owner_id': ownerId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'sub_status': subStatus,
      'booking_end_time': bookingEndTime?.millisecondsSinceEpoch,
      'booking_id': bookingId,
      'image_urls': imageUrls,
      'image_url': imageUrl,
      'address': address,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'price_per_night': pricePerNight,
      'price_per_hour': pricePerHour,
      'area': area,
      'rooms': rooms,
      'max_guests': maxGuests,
      'is_favorite': isFavorite,
      'has_wifi': hasWifi,
      'has_air_conditioning': hasAirConditioning,
      'has_kitchen': hasKitchen,
      'has_tv': hasTV,
      'has_washing_machine': hasWashingMachine,
      'has_parking': hasParking,
      'pet_friendly': petFriendly,
      'check_in_time': checkInTime,
      'check_out_time': checkOutTime,
      'rating': rating,
      'reviews_count': reviewsCount,
      'bathrooms': bathrooms,
      'is_active': isActive,
      'is_on_moderation': isOnModeration,
      'views': views,
    };
  }
  
  /// Создает объект Property из Map
  factory Property.fromMap(Map<String, dynamic> map) {
    DateTime? bookingEndTime;
    if (map['booking_end_time'] != null) {
      bookingEndTime = DateTime.fromMillisecondsSinceEpoch(map['booking_end_time'] as int);
    }
    
    return Property(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['owner_id'] ?? '',
      type: _stringToPropertyType(map['type'] ?? 'apartment'),
      status: _stringToPropertyStatus(map['status'] ?? 'available'),
      subStatus: map['sub_status'] as String? ?? PropertySubStatus.none,
      bookingEndTime: bookingEndTime,
      bookingId: map['booking_id'] as String? ?? '',
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      imageUrl: map['image_url'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      pricePerNight: (map['price_per_night'] as num?)?.toDouble() ?? 0.0,
      pricePerHour: (map['price_per_hour'] as num?)?.toDouble() ?? 0.0,
      area: (map['area'] as num?)?.toDouble() ?? 0.0,
      rooms: map['rooms'] ?? 0,
      maxGuests: map['max_guests'] ?? 0,
      isFavorite: map['is_favorite'] ?? false,
      hasWifi: map['has_wifi'] ?? false,
      hasAirConditioning: map['has_air_conditioning'] ?? false,
      hasKitchen: map['has_kitchen'] ?? false,
      hasTV: map['has_tv'] ?? false,
      hasWashingMachine: map['has_washing_machine'] ?? false,
      hasParking: map['has_parking'] ?? false,
      petFriendly: map['pet_friendly'] ?? false,
      checkInTime: map['check_in_time'] ?? '14:00',
      checkOutTime: map['check_out_time'] ?? '12:00',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: map['reviews_count'] ?? 0,
      bathrooms: map['bathrooms'] ?? 1,
      isActive: map['is_active'] ?? true,
      isOnModeration: map['is_on_moderation'] ?? false,
      views: map['views'] ?? 0,
    );
  }
  
  /// Преобразует строку в тип объекта недвижимости
  static PropertyType _stringToPropertyType(String type) {
    switch (type) {
      case 'apartment':
        return PropertyType.apartment;
      case 'house':
        return PropertyType.house;
      case 'room':
        return PropertyType.room;
      case 'hostel':
        return PropertyType.hostel;
      default:
        return PropertyType.apartment;
    }
  }
  
  /// Преобразует строку в статус объекта недвижимости
  static PropertyStatus _stringToPropertyStatus(String status) {
    switch (status) {
      case 'available':
        return PropertyStatus.available;
      case 'booked':
        return PropertyStatus.booked;
      case 'cleaning':
        return PropertyStatus.cleaning;
      case 'maintenance':
        return PropertyStatus.maintenance;
      case 'unavailable':
        return PropertyStatus.unavailable;
      case 'blocked':
        return PropertyStatus.blocked;
      default:
        return PropertyStatus.available;
    }
  }
  
  /// Список удобств объекта
  List<String> get amenities {
    final list = <String>[];
    
    if (hasWifi) list.add('Wi-Fi');
    if (hasAirConditioning) list.add('Кондиционер');
    if (hasKitchen) list.add('Кухня');
    if (hasTV) list.add('Телевизор');
    if (hasWashingMachine) list.add('Стиральная машина');
    if (hasParking) list.add('Парковка');
    if (petFriendly) list.add('Разрешены животные');
    
    return list;
  }
  
  /// Преобразует объект в карту для JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'subStatus': subStatus,
      'bookingEndTime': bookingEndTime?.millisecondsSinceEpoch,
      'bookingId': bookingId,
      'imageUrls': imageUrls,
      'imageUrl': imageUrl,
      'address': address,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'pricePerNight': pricePerNight,
      'pricePerHour': pricePerHour,
      'area': area,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'maxGuests': maxGuests,
      'isFavorite': isFavorite,
      'hasWifi': hasWifi,
      'hasAirConditioning': hasAirConditioning,
      'hasKitchen': hasKitchen,
      'hasTV': hasTV,
      'hasWashingMachine': hasWashingMachine,
      'hasParking': hasParking,
      'petFriendly': petFriendly,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'isFeatured': isFeatured,
      'isOnModeration': isOnModeration,
      'isActive': isActive,
      'views': views,
    };
  }
  
  /// Создает объект из JSON
  factory Property.fromJson(Map<String, dynamic> json) {
    // Обрабатываем поля из Firestore (snake_case) и из локальных объектов (camelCase)
    DateTime? bookingEndTime;
    
    if (json.containsKey('booking_end_time') && json['booking_end_time'] != null) {
      bookingEndTime = DateTime.fromMillisecondsSinceEpoch(json['booking_end_time'] as int);
    } else if (json.containsKey('bookingEndTime') && json['bookingEndTime'] != null) {
      bookingEndTime = DateTime.fromMillisecondsSinceEpoch(json['bookingEndTime'] as int);
    }
    
    return Property(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? json['ownerId'] as String? ?? '',
      type: _parsePropertyType(json['type'] as String? ?? ''),
      status: _parsePropertyStatus(json['status'] as String? ?? ''),
      subStatus: json['sub_status'] as String? ?? json['subStatus'] as String? ?? PropertySubStatus.none,
      bookingEndTime: bookingEndTime,
      bookingId: json['booking_id'] as String? ?? '',
      imageUrls: json.containsKey('image_urls')
          ? (json['image_urls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? []
          : (json['imageUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      pricePerNight: json.containsKey('price_per_night')
          ? (json['price_per_night'] as num?)?.toDouble() ?? 0.0
          : (json['pricePerNight'] as num?)?.toDouble() ?? 0.0,
      pricePerHour: json.containsKey('price_per_hour')
          ? (json['price_per_hour'] as num?)?.toDouble() ?? 0.0
          : (json['pricePerHour'] as num?)?.toDouble() ?? 0.0,
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      rooms: json['rooms'] as int? ?? 1,
      bathrooms: json['bathrooms'] as int? ?? 1,
      maxGuests: json.containsKey('max_guests')
          ? json['max_guests'] as int? ?? 1
          : json['maxGuests'] as int? ?? 1,
      isFavorite: json['isFavorite'] as bool? ?? false,
      hasWifi: json.containsKey('has_wifi')
          ? json['has_wifi'] as bool? ?? false
          : json['hasWifi'] as bool? ?? false,
      hasAirConditioning: json.containsKey('has_air_conditioning')
          ? json['has_air_conditioning'] as bool? ?? false
          : json['hasAirConditioning'] as bool? ?? false,
      hasKitchen: json.containsKey('has_kitchen')
          ? json['has_kitchen'] as bool? ?? false
          : json['hasKitchen'] as bool? ?? false,
      hasTV: json.containsKey('has_tv')
          ? json['has_tv'] as bool? ?? false
          : json['hasTV'] as bool? ?? false,
      hasWashingMachine: json.containsKey('has_washing_machine')
          ? json['has_washing_machine'] as bool? ?? false
          : json['hasWashingMachine'] as bool? ?? false,
      hasParking: json.containsKey('has_parking')
          ? json['has_parking'] as bool? ?? false
          : json['hasParking'] as bool? ?? false,
      petFriendly: json.containsKey('pet_friendly')
          ? json['pet_friendly'] as bool? ?? false
          : json['petFriendly'] as bool? ?? false,
      checkInTime: json.containsKey('check_in_time')
          ? json['check_in_time'] as String? ?? '14:00'
          : json['checkInTime'] as String? ?? '14:00',
      checkOutTime: json.containsKey('check_out_time')
          ? json['check_out_time'] as String? ?? '12:00'
          : json['checkOutTime'] as String? ?? '12:00',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      isFeatured: json.containsKey('is_featured')
          ? json['is_featured'] as bool? ?? false
          : json['isFeatured'] as bool? ?? false,
      isOnModeration: json['isOnModeration'] as bool? ?? false,
      isActive: json.containsKey('is_active')
          ? json['is_active'] as bool? ?? true
          : json['isActive'] as bool? ?? true,
      views: json['views'] as int? ?? 0,
    );
  }
  
  /// Парсит тип объекта из строки
  static PropertyType _parsePropertyType(String typeStr) {
    if (typeStr.isEmpty) {
      return PropertyType.apartment; // Значение по умолчанию
    }
    return PropertyType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => PropertyType.apartment,
    );
  }
  
  /// Парсит статус объекта из строки
  static PropertyStatus _parsePropertyStatus(String statusStr) {
    if (statusStr.isEmpty) {
      return PropertyStatus.available; // Значение по умолчанию
    }
    return PropertyStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusStr,
      orElse: () => PropertyStatus.available,
    );
  }
} 