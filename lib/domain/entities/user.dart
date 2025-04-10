import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Перечисление ролей пользователя
enum UserRole {
  /// Клиент (арендатор жилья)
  client,
  
  /// Владелец жилья
  owner,
  
  /// Уборщик
  cleaner,
  
  /// Служба поддержки
  support
}

/// Класс, представляющий пользователя в системе
class User extends Equatable {
  /// Уникальный идентификатор пользователя
  final String id;
  
  /// Электронная почта пользователя
  final String email;
  
  /// Имя пользователя
  final String firstName;
  
  /// Фамилия пользователя
  final String lastName;
  
  /// Номер телефона пользователя
  final String phoneNumber;
  
  /// URL аватара пользователя
  final String? avatarUrl;
  
  /// Роль пользователя
  final UserRole role;
  
  /// Рейтинг пользователя (от 0 до 5)
  final double rating;
  
  /// Количество отзывов о пользователе
  final int reviewsCount;
  
  /// Статус верификации пользователя
  final bool isVerified;
  
  /// Баланс пользователя
  final double balance;
  
  /// Дата создания аккаунта
  final DateTime createdAt;
  
  /// Дата последнего обновления
  final DateTime updatedAt;
  
  /// Создает экземпляр [User]
  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.avatarUrl,
    required this.role,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.isVerified = false,
    this.balance = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();
  
  /// Полное имя пользователя
  String get fullName => '$firstName $lastName';
  
  /// Инициалы пользователя (для отображения в аватаре)
  String get initials {
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$firstInitial$lastInitial';
  }
  
  /// Создает копию пользователя с измененными параметрами
  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? avatarUrl,
    UserRole? role,
    double? rating,
    int? reviewsCount,
    bool? isVerified,
    double? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isVerified: isVerified ?? this.isVerified,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    email,
    firstName,
    lastName,
    phoneNumber,
    avatarUrl,
    role,
    rating,
    reviewsCount,
    isVerified,
    balance,
    createdAt,
    updatedAt,
  ];

  /// Преобразует объект в карту для JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.toString().split('.').last,
      'avatarUrl': avatarUrl,
      'isVerified': isVerified,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'balance': balance,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
  
  /// Создает объект из карты JSON
  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? createdAtDate;
    DateTime? updatedAtDate;
    
    if (json['createdAt'] is Timestamp) {
      createdAtDate = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is int) {
      createdAtDate = DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int);
    }
    
    if (json['updatedAt'] is Timestamp) {
      updatedAtDate = (json['updatedAt'] as Timestamp).toDate();
    } else if (json['updatedAt'] is int) {
      updatedAtDate = DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int);
    }
    
    return User(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      role: _parseRole(json['role'] as String? ?? 'client'),
      avatarUrl: json['avatarUrl'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      balance: json['balance'] != null ? (json['balance'] as num).toDouble() : 0.0,
      createdAt: createdAtDate,
      updatedAt: updatedAtDate,
    );
  }
  
  /// Переводит строку в enum UserRole
  static UserRole _parseRole(String role) {
    // Проверяем, содержит ли строка "UserRole."
    if (role.contains('UserRole.')) {
      role = role.split('.').last;
    }
    
    switch (role) {
      case 'owner':
        return UserRole.owner;
      case 'cleaner':
        return UserRole.cleaner;
      case 'support':
        return UserRole.support;
      case 'client':
      default:
        return UserRole.client;
    }
  }
  
  /// Преобразует объект в Map
  Map<String, dynamic> toMap() {
    return toJson();
  }
  
  /// Создает объект из Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User.fromJson(map);
  }
  
  /// Преобразует строку JSON в объект
  factory User.fromJsonString(String source) => User.fromJson(json.decode(source) as Map<String, dynamic>);
  
  /// Преобразует объект в строку JSON
  String toJsonString() => json.encode(toJson());
} 