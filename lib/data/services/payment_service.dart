import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/domain/entities/payment_receipt.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:pater/core/di/service_locator.dart';

/// Enum для методов оплаты
enum PaymentMethod {
  /// Банковская карта
  card,

  /// Kaspi Bank
  kaspi,

  /// Halyk Bank
  halyk,

  /// Банковский перевод
  transfer,
}

/// Сервис для работы с платежами
class PaymentService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  /// Конструктор с DI
  PaymentService({FirebaseFirestore? firestore, AuthService? authService})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _authService = authService ?? getIt<AuthService>();

  /// Инициализирован ли сервис
  bool _isInitialized = false;

  /// Инициализирует сервис
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // No need to set _authService since it's already initialized in the constructor
      _isInitialized = true;
    } catch (e) {
      debugPrint('Ошибка при инициализации сервиса платежей: $e');
    }
  }

  /// Убеждается, что сервис инициализирован
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// Инициирует платеж с выбранным методом
  Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    required PaymentMethod method,
    required double amount,
  }) async {
    await _ensureInitialized();

    // Проверяем авторизацию
    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    // Создаем новый идентификатор транзакции
    final transactionId = const Uuid().v4();

    // Записываем информацию о начале транзакции в Firestore
    await _firestore.collection('payment_transactions').doc(transactionId).set({
      'id': transactionId,
      'bookingId': bookingId,
      'userId': user.id,
      'amount': amount,
      'method': method.toString().split('.').last,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // В зависимости от метода оплаты выполняем соответствующее действие
    switch (method) {
      case PaymentMethod.card:
        // Обработка оплаты картой
        return _processCardPayment(transactionId, amount);

      case PaymentMethod.kaspi:
        // Подготовка перехода в Kaspi
        return _prepareKaspiPayment(transactionId, amount);

      case PaymentMethod.halyk:
        // Подготовка перехода в Halyk Bank
        return _prepareHalykPayment(transactionId, amount);

      case PaymentMethod.transfer:
        // Подготовка банковского перевода
        return _prepareBankTransferPayment(transactionId, amount);
    }
  }

  /// Обрабатывает оплату банковской картой
  Future<Map<String, dynamic>> _processCardPayment(
    String transactionId,
    double amount,
  ) async {
    // Здесь должна быть интеграция с провайдером платежей (Stripe, Paypal и т.д.)
    // В данном примере имитируем успешную оплату

    // Обновляем статус транзакции
    await _firestore
        .collection('payment_transactions')
        .doc(transactionId)
        .update({
          'status': 'completed',
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Возвращаем результат оплаты
    return {
      'success': true,
      'transactionId': transactionId,
      'message': 'Оплата картой выполнена успешно',
      'needsRedirect': false,
    };
  }

  /// Подготавливает оплату через Kaspi Bank
  Future<Map<String, dynamic>> _prepareKaspiPayment(
    String transactionId,
    double amount,
  ) async {
    // Генерация URL для перехода в Kaspi Pay
    // Реальная интеграция потребует регистрации в Kaspi Pay API
    final redirectUrl =
        'https://kaspi.kz/pay?amount=$amount&service=pater&transaction=$transactionId';

    return {
      'success': true,
      'transactionId': transactionId,
      'message': 'Перенаправление в Kaspi Bank',
      'needsRedirect': true,
      'redirectUrl': redirectUrl,
      'appScheme': 'kaspi://', // Для открытия приложения Kaspi
    };
  }

  /// Подготавливает оплату через Halyk Bank
  Future<Map<String, dynamic>> _prepareHalykPayment(
    String transactionId,
    double amount,
  ) async {
    // Генерация URL для перехода в Homebank
    // Реальная интеграция потребует регистрации в Halyk API
    final redirectUrl =
        'https://homebank.kz/payment?amount=$amount&service=pater&transaction=$transactionId';

    return {
      'success': true,
      'transactionId': transactionId,
      'message': 'Перенаправление в Halyk Bank',
      'needsRedirect': true,
      'redirectUrl': redirectUrl,
      'appScheme': 'homebank://', // Для открытия приложения Homebank
    };
  }

  /// Подготавливает банковский перевод
  Future<Map<String, dynamic>> _prepareBankTransferPayment(
    String transactionId,
    double amount,
  ) async {
    // Информация для банковского перевода
    final transferDetails = {
      'bankName': 'Pater Bank',
      'accountNumber': '1234567890',
      'recipient': 'ООО "Патер"',
      'amount': amount,
      'reference': 'Оплата бронирования, ID: $transactionId',
    };

    return {
      'success': true,
      'transactionId': transactionId,
      'message': 'Подготовлена информация для банковского перевода',
      'needsRedirect': false,
      'transferDetails': transferDetails,
    };
  }

  /// Проверяет статус платежа
  Future<Map<String, dynamic>> checkPaymentStatus(String transactionId) async {
    await _ensureInitialized();

    final transactionDoc =
        await _firestore
            .collection('payment_transactions')
            .doc(transactionId)
            .get();

    if (!transactionDoc.exists) {
      throw Exception('Транзакция не найдена');
    }

    final transactionData = transactionDoc.data()!;

    return {
      'status': transactionData['status'],
      'transactionId': transactionId,
      'bookingId': transactionData['bookingId'],
      'amount': transactionData['amount'],
    };
  }

  /// Подтверждает успешную оплату и создает чек
  Future<PaymentReceipt> confirmPayment({
    required String transactionId,
    required String bookingId,
  }) async {
    await _ensureInitialized();

    // Проверяем авторизацию
    final user = _authService.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    // Получаем документ транзакции
    final transactionDoc =
        await _firestore
            .collection('payment_transactions')
            .doc(transactionId)
            .get();

    if (!transactionDoc.exists) {
      throw Exception('Транзакция не найдена');
    }

    final transactionData = transactionDoc.data()!;

    // Создаем уникальный номер чека
    final receiptId = 'R-${DateTime.now().millisecondsSinceEpoch}';

    // Создаем объект чека
    final receipt = PaymentReceipt(
      id: receiptId,
      transactionId: transactionId,
      bookingId: bookingId,
      userId: user.id,
      amount: transactionData['amount'],
      paymentMethod: transactionData['method'],
      createdAt: DateTime.now(),
      items: [
        {
          'name': 'Оплата бронирования',
          'description': 'Оплата бронирования №$bookingId',
          'amount': transactionData['amount'],
        },
      ],
    );

    // Сохраняем чек в Firestore
    await _firestore
        .collection('payment_receipts')
        .doc(receiptId)
        .set(receipt.toJson());

    // Обновляем статус транзакции
    await _firestore
        .collection('payment_transactions')
        .doc(transactionId)
        .update({
          'status': 'completed',
          'receiptId': receiptId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    return receipt;
  }

  /// Получает список чеков пользователя
  Future<List<PaymentReceipt>> getUserReceipts(String userId) async {
    await _ensureInitialized();

    final receiptsSnapshot =
        await _firestore
            .collection('payment_receipts')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

    return receiptsSnapshot.docs
        .map((doc) => PaymentReceipt.fromJson(doc.data()))
        .toList();
  }

  /// Получает чек по ID
  Future<PaymentReceipt?> getReceiptById(String receiptId) async {
    await _ensureInitialized();

    final receiptDoc =
        await _firestore.collection('payment_receipts').doc(receiptId).get();

    if (!receiptDoc.exists) {
      return null;
    }

    return PaymentReceipt.fromJson(receiptDoc.data()!);
  }

  /// Получает чеки по ID бронирования
  Future<List<PaymentReceipt>> getReceiptsByBookingId(String bookingId) async {
    await _ensureInitialized();

    final receiptsSnapshot =
        await _firestore
            .collection('payment_receipts')
            .where('bookingId', isEqualTo: bookingId)
            .orderBy('createdAt', descending: true)
            .get();

    return receiptsSnapshot.docs
        .map((doc) => PaymentReceipt.fromJson(doc.data()))
        .toList();
  }

  /// Открывает внешнюю ссылку или приложение
  Future<bool> launchPaymentApp(String url, String appScheme) async {
    // Сначала пробуем открыть приложение
    try {
      final appUri = Uri.parse(appScheme);
      final canLaunchApp = await canLaunchUrl(appUri);
      if (canLaunchApp) {
        return await launchUrl(appUri);
      }
    } catch (e) {
      debugPrint('Ошибка при попытке открыть приложение: $e');
    }

    // Если не получилось открыть приложение, открываем веб-страницу
    try {
      final webUri = Uri.parse(url);
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Ошибка при попытке открыть веб-страницу: $e');
      return false;
    }
  }
}
