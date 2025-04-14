import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Класс, представляющий отзыв о жилье
class Review extends Equatable {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String text;
  final double rating;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Review({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.text,
    required this.rating,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    userName,
    userAvatarUrl,
    text,
    rating,
    createdAt,
    updatedAt,
  ];

  /// Создает копию отзыва с измененными параметрами
  Review copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? text,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      text: text ?? this.text,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Создает объект из JSON
  factory Review.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    DateTime? updatedAt;

    if (json['createdAt'] is Timestamp) {
      createdAt = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int);
    }

    if (json['updatedAt'] is Timestamp) {
      updatedAt = (json['updatedAt'] as Timestamp).toDate();
    } else if (json['updatedAt'] is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int);
    }

    return Review(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      text: json['text'] as String? ?? '',
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : 0.0,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt,
    );
  }

  /// Преобразует объект в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'text': text,
      'rating': rating,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
    };
  }
}
