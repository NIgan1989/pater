import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель чека оплаты
class PaymentReceipt extends Equatable {
  /// Идентификатор чека
  final String id;

  /// Идентификатор транзакции
  final String transactionId;

  /// Идентификатор бронирования
  final String bookingId;

  /// Идентификатор пользователя
  final String userId;

  /// Сумма оплаты
  final double amount;

  /// Метод оплаты (card, kaspi, halyk, transfer)
  final String paymentMethod;

  /// Дата создания чека
  final DateTime createdAt;

  /// Список элементов чека
  final List<Map<String, dynamic>> items;

  /// Конструктор
  const PaymentReceipt({
    required this.id,
    required this.transactionId,
    required this.bookingId,
    required this.userId,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
    required this.items,
  });

  /// Создает объект из JSON
  factory PaymentReceipt.fromJson(Map<String, dynamic> json) {
    return PaymentReceipt(
      id: json['id'] as String,
      transactionId: json['transactionId'] as String,
      bookingId: json['bookingId'] as String,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      items: List<Map<String, dynamic>>.from(json['items'] as List),
    );
  }

  /// Преобразует объект в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transactionId': transactionId,
      'bookingId': bookingId,
      'userId': userId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt,
      'items': items,
    };
  }

  @override
  List<Object?> get props => [
    id,
    transactionId,
    bookingId,
    userId,
    amount,
    paymentMethod,
    createdAt,
    items,
  ];
}
