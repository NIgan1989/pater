import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/data/services/payment_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/payment_receipt.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/data/services/property_service.dart';

/// Экран подтверждения успешной оплаты
class PaymentConfirmationScreen extends StatefulWidget {
  final String bookingId;

  const PaymentConfirmationScreen({super.key, required this.bookingId});

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final PropertyService _propertyService = PropertyService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = true;
  Booking? _booking;
  Property? _property;
  PaymentReceipt? _receipt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Загружает данные бронирования и объекта
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Получаем данные о бронировании
      final booking = await _bookingService.getBookingById(widget.bookingId);

      if (booking == null) {
        throw Exception('Бронирование не найдено');
      }

      // Получаем данные об объекте
      final property = await _propertyService.getPropertyById(
        booking.propertyId,
      );

      if (property == null) {
        throw Exception('Объект не найден');
      }

      // Получаем чек оплаты (если есть)
      final receipts = await _paymentService.getReceiptsByBookingId(
        widget.bookingId,
      );
      final receipt = receipts.isNotEmpty ? receipts.first : null;

      setState(() {
        _booking = booking;
        _property = property;
        _receipt = receipt;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Показывает чек оплаты
  Future<void> _showReceipt() async {
    if (_receipt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Чек не найден'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Получаем форматтер для дат и денег
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    // Определяем название метода оплаты для отображения
    final paymentMethodName = _getPaymentMethodName(_receipt!.paymentMethod);

    await showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Чек оплаты',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildReceiptRow('Номер чека:', _receipt!.id),
                  _buildReceiptRow(
                    'Дата и время:',
                    dateFormat.format(_receipt!.createdAt),
                  ),
                  _buildReceiptRow('Способ оплаты:', paymentMethodName),
                  _buildReceiptRow('ID бронирования:', _receipt!.bookingId),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Детали оплаты',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._receipt!.items.map(
                    (item) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          item['description'] as String,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            currencyFormat.format(item['amount']),
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Итого:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currencyFormat.format(_receipt!.amount),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: _shareReceipt,
                      icon: const Icon(Icons.share),
                      label: const Text('Поделиться чеком'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Создает строку данных чека
  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Получает название метода оплаты из кода
  String _getPaymentMethodName(String methodCode) {
    switch (methodCode) {
      case 'card':
        return 'Банковская карта';
      case 'kaspi':
        return 'Kaspi Bank';
      case 'halyk':
        return 'Халык Банк';
      case 'transfer':
        return 'Банковский перевод';
      default:
        return methodCode;
    }
  }

  /// Делится чеком (в реальном приложении здесь будет экспорт PDF)
  void _shareReceipt() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Функция "Поделиться чеком" будет доступна в следующей версии',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Бронирование подтверждено'),
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: _navigateToHome),
        ],
      ),
      body:
          _isLoading || _booking == null || _property == null
              ? _buildLoadingState()
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Анимированная иконка успеха
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.paddingXL,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(26),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingL),
                          Text(
                            'Оплата прошла успешно',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingS),
                          Text(
                            'Номер бронирования: ${_booking!.id}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                          if (_receipt != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppConstants.paddingM,
                              ),
                              child: TextButton.icon(
                                onPressed: _showReceipt,
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Просмотреть чек'),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Детали бронирования
                    Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Информация об объекте
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusM,
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.outline.withAlpha(51),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                AppConstants.paddingM,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _property!.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(
                                    height: AppConstants.paddingXS,
                                  ),
                                  Text(
                                    _property!.address,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withAlpha(153),
                                    ),
                                  ),
                                  const Divider(height: 32),
                                  // Даты и гости в одной строке
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Даты',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${DateFormat('dd.MM.yyyy').format(_booking!.checkInDate)} - ${DateFormat('dd.MM.yyyy').format(_booking!.checkOutDate)}',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Гости',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_booking!.guestsCount} ${_getGuestsWord(_booking!.guestsCount)}',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppConstants.paddingM),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Итого оплачено:',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'ru_RU',
                                          symbol: '₸',
                                          decimalDigits: 0,
                                        ).format(_booking!.totalPrice),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: AppConstants.paddingL),

                          // Следующие шаги
                          Text(
                            'Следующие шаги',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingM),

                          // Шаги в виде карточек
                          _buildStepCard(
                            theme,
                            icon: Icons.email_outlined,
                            title: 'Проверьте почту',
                            description:
                                'Мы отправили детали бронирования на вашу электронную почту',
                          ),
                          const SizedBox(height: AppConstants.paddingS),
                          _buildStepCard(
                            theme,
                            icon: Icons.notifications_outlined,
                            title: 'Ожидайте инструкции',
                            description:
                                'За день до заезда вы получите инструкции по заселению',
                          ),
                          const SizedBox(height: AppConstants.paddingS),
                          _buildStepCard(
                            theme,
                            icon: Icons.support_agent_outlined,
                            title: 'Поддержка 24/7',
                            description:
                                'При возникновении вопросов обращайтесь в поддержку',
                          ),

                          const SizedBox(height: AppConstants.paddingXL),

                          // Кнопки действий
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _navigateToBookings,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                  ),
                                  child: const Text('Мои бронирования'),
                                ),
                              ),
                              const SizedBox(width: AppConstants.paddingM),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _navigateToHome,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: const Text('На главную'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  /// Отображает состояние загрузки
  Widget _buildLoadingState() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'Ошибка: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: AppConstants.paddingM),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  /// Возвращает правильное склонение для слова "гость"
  String _getGuestsWord(int count) {
    if (count == 1) {
      return 'гость';
    } else if (count >= 2 && count <= 4) {
      return 'гостя';
    } else {
      return 'гостей';
    }
  }

  void _navigateToHome() {
    context.goNamed('home');
  }

  void _navigateToBookings() {
    if (mounted) {
      context.goNamed('all_bookings');
    }
  }

  Widget _buildStepCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(51)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppConstants.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
