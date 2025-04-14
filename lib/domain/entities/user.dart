import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/domain/entities/user_role.dart';

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

  /// Флаг, указывающий, подтверждена ли электронная почта пользователя
  final bool emailVerified;

  /// Флаг, указывающий, является ли пользователь анонимным
  final bool isAnonymous;

  /// Метаданные пользователя
  final UserMetadata metadata;

  /// Данные провайдеров аутентификации
  final List<UserInfo> providerData;

  /// Роль пользователя
  final UserRole role;

  /// Список ролей пользователя
  final List<UserRole> roles;

  /// Активная роль пользователя
  final UserRole activeRole;

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
    required this.emailVerified,
    required this.isAnonymous,
    required this.metadata,
    required this.providerData,
    required this.role,
    required this.roles,
    required this.activeRole,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.isVerified = false,
    this.balance = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Упрощенный конструктор с значениями по умолчанию
  User.simplified({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.role,
    this.avatarUrl,
  }) : emailVerified = false,
       isAnonymous = false,
       metadata = UserMetadata(),
       providerData = [],
       roles = [role],
       activeRole = role,
       rating = 0.0,
       reviewsCount = 0,
       isVerified = false,
       balance = 0.0,
       createdAt = DateTime.now(),
       updatedAt = DateTime.now();

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
    bool? emailVerified,
    bool? isAnonymous,
    UserMetadata? metadata,
    List<UserInfo>? providerData,
    UserRole? role,
    List<UserRole>? roles,
    UserRole? activeRole,
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
      emailVerified: emailVerified ?? this.emailVerified,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      metadata: metadata ?? this.metadata,
      providerData: providerData ?? this.providerData,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
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
    emailVerified,
    isAnonymous,
    metadata,
    providerData,
    role,
    roles,
    activeRole,
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
      'avatarUrl': avatarUrl,
      'emailVerified': emailVerified,
      'isAnonymous': isAnonymous,
      'metadata': metadata.toJson(),
      'providerData': providerData.map((e) => e.toJson()).toList(),
      'role': role.toString().split('.').last,
      'roles': roles.map((e) => e.toString().split('.').last).toList(),
      'activeRole': activeRole.toString().split('.').last,
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
      createdAtDate = DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int,
      );
    }

    if (json['updatedAt'] is Timestamp) {
      updatedAtDate = (json['updatedAt'] as Timestamp).toDate();
    } else if (json['updatedAt'] is int) {
      updatedAtDate = DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int,
      );
    }

    return User(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      metadata: UserMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
      providerData:
          (json['providerData'] as List<dynamic>?)
              ?.map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      role: _parseRole(json['role'] as String? ?? 'client'),
      roles:
          (json['roles'] as List<dynamic>?)
              ?.map((e) => _parseRole(e as String))
              .toList() ??
          [UserRole.client],
      activeRole: _parseRole(json['activeRole'] as String? ?? 'client'),
      isVerified: json['isVerified'] as bool? ?? false,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      reviewsCount: json['reviewsCount'] as int? ?? 0,
      balance:
          json['balance'] != null ? (json['balance'] as num).toDouble() : 0.0,
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
  factory User.fromJsonString(String source) =>
      User.fromJson(json.decode(source) as Map<String, dynamic>);

  /// Преобразует объект в строку JSON
  String toJsonString() => json.encode(toJson());
}

class UserMetadata {
  final DateTime? creationTime;
  final DateTime? lastSignInTime;

  UserMetadata({this.creationTime, this.lastSignInTime});

  factory UserMetadata.fromJson(Map<String, dynamic> json) {
    return UserMetadata(
      creationTime:
          json['creationTime'] != null
              ? DateTime.parse(json['creationTime'])
              : null,
      lastSignInTime:
          json['lastSignInTime'] != null
              ? DateTime.parse(json['lastSignInTime'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creationTime': creationTime?.toIso8601String(),
      'lastSignInTime': lastSignInTime?.toIso8601String(),
    };
  }
}

class UserInfo {
  final String? uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final String? providerId;

  UserInfo({
    this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    this.providerId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      uid: json['uid'],
      email: json['email'],
      displayName: json['displayName'],
      phoneNumber: json['phoneNumber'],
      photoURL: json['photoURL'],
      providerId: json['providerId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'providerId': providerId,
    };
  }
}
