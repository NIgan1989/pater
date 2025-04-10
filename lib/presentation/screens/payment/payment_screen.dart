// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/data/services/payment_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/data/services/property_service.dart';
import 'dart:async';

/// Экран оплаты бронирования
class PaymentScreen extends StatefulWidget {
  final String bookingId;

  const PaymentScreen({super.key, required this.bookingId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PropertyService _propertyService = PropertyService();
  final BookingService _bookingService = BookingService();
  final PaymentService _paymentService = PaymentService();

  bool _isLoading = true;
  bool _isProcessingPayment = false;
  Booking? _booking;
  Property? _property;
  String? _errorMessage;

  // Выбранный способ оплаты
  String _selectedPaymentMethod = 'card';

  // Идентификатор текущей транзакции
  String? _currentTransactionId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Загружает данные бронирования и объекта
  Future<void> _loadData() async {
    if (!mounted) return;
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

      if (mounted) {
        setState(() {
          _booking = booking;
          _property = property;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Обрабатывает оплату бронирования
  Future<void> _processPayment() async {
    if (_selectedPaymentMethod.isEmpty) {
      setState(() {
        _errorMessage = 'Пожалуйста, выберите метод оплаты';
      });
      return;
    }

    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      // Конвертируем строковое значение в PaymentMethod
      final paymentMethod = _getPaymentMethodFromString(_selectedPaymentMethod);

      // Инициируем платеж с выбранным методом
      final result = await _paymentService.initiatePayment(
        bookingId: widget.bookingId,
        method: paymentMethod,
        amount: _booking!.totalPrice,
      );

      // Сохраняем ID транзакции
      _currentTransactionId = result['transactionId'];

      // Проверяем, нужно ли перенаправление
      if (result['needsRedirect'] == true) {
        // Для методов оплаты, требующих перехода в другое приложение
        if (mounted) {
          final redirectUrl = result['redirectUrl'] as String;
          final appScheme = result['appScheme'] as String;

          // Показываем диалог подтверждения
          final shouldProceed = await _showRedirectDialog(
            title: 'Переход к оплате',
            message:
                'Для продолжения оплаты вы будете перенаправлены в приложение банка или на его сайт.',
          );

          // Проверяем, что виджет все еще примонтирован
          if (!mounted) return;

          if (shouldProceed) {
            // Запускаем приложение для оплаты
            final launched = await _paymentService.launchPaymentApp(
              redirectUrl,
              appScheme,
            );

            if (!mounted) return;

            if (!launched) {
              // Если не удалось открыть приложение или страницу
              setState(() {
                _isProcessingPayment = false;
                _errorMessage =
                    'Не удалось открыть приложение для оплаты. Пожалуйста, попробуйте другой способ оплаты.';
              });
              return;
            }

            // После возвращения из приложения показываем страницу подтверждения
            _navigateToPaymentConfirmation();
          } else {
            // Пользователь отменил переход
            setState(() {
              _isProcessingPayment = false;
            });
          }
        }
      } else if (_selectedPaymentMethod == 'transfer') {
        // Для банковского перевода показываем инструкции
        if (mounted) {
          // Сохраняем контекст до асинхронной операции
          await _showBankTransferInstructions(result['transferDetails']);

          if (!mounted) return;

          // Теперь вызываем метод навигации
          _navigateToPaymentConfirmation();
        }
      } else {
        // Для прямых способов оплаты (например, карта)
        await Future.delayed(const Duration(seconds: 2)); // Имитация процесса

        if (mounted) {
          // Создаем чек и обновляем статус бронирования
          await _paymentService.confirmPayment(
            transactionId: _currentTransactionId!,
            bookingId: widget.bookingId,
          );

          // Обновляем статус бронирования
          await _bookingService.processPayment(widget.bookingId);

          // Проверяем, что виджет все еще примонтирован
          if (!mounted) return;

          // Показываем сообщение об успешной оплате через глобальный ключ
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Оплата прошла успешно!'),
              backgroundColor: Colors.green,
            ),
          );

          // Перенаправляем на экран подтверждения оплаты
          _navigateToPaymentConfirmation();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          _errorMessage = 'Ошибка при обработке платежа: ${e.toString()}';
        });

        // Создаем локальную переменную для безопасного использования
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Конвертирует строковое значение метода оплаты в enum
  PaymentMethod _getPaymentMethodFromString(String methodString) {
    switch (methodString) {
      case 'card':
        return PaymentMethod.card;
      case 'kaspi':
        return PaymentMethod.kaspi;
      case 'halyk':
        return PaymentMethod.halyk;
      case 'transfer':
        return PaymentMethod.transfer;
      default:
        return PaymentMethod.card;
    }
  }

  /// Показывает диалог перед перенаправлением в банковское приложение
  Future<bool> _showRedirectDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return false;

    // Способ 1: Создадим функцию с замыканием, которая безопасно использует context
    Future<bool> showDialogSafely(BuildContext localContext) {
      if (!mounted) return Future.value(false);
      return showDialog<bool>(
        context: localContext,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Продолжить'),
                ),
              ],
            ),
      ).then((value) => value ?? false);
    }

    // Сохраняем текущий контекст и вызываем функцию
    final currentContext = context;
    // Вызываем диалог синхронно с текущим контекстом
    return await showDialogSafely(currentContext);
  }

  /// Показывает инструкции для банковского перевода
  Future<void> _showBankTransferInstructions(
    Map<String, dynamic> details,
  ) async {
    if (!mounted) return;

    // Сохраняем текущий контекст до асинхронной операции
    final currentContext = context;

    // Используем сохраненный контекст для отображения диалога
    await showDialog(
      context: currentContext,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Инструкции по переводу'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Банк: ${details['bankName']}'),
                  const SizedBox(height: 8),
                  Text('Номер счета: ${details['accountNumber']}'),
                  const SizedBox(height: 8),
                  Text('Получатель: ${details['recipient']}'),
                  const SizedBox(height: 8),
                  Text('Сумма: ${details['amount'].toStringAsFixed(2)} ₸'),
                  const SizedBox(height: 8),
                  Text('Назначение платежа: ${details['reference']}'),
                  const SizedBox(height: 16),
                  const Text(
                    'Пожалуйста, убедитесь, что вы указали точное назначение платежа, '
                    'чтобы мы могли идентифицировать ваш платеж.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Понятно'),
              ),
            ],
          ),
    );
  }

  /// Перенаправляет на экран подтверждения оплаты
  void _navigateToPaymentConfirmation() {
    if (mounted) {
      context.goNamed(
        'payment_confirmation',
        queryParameters: {'booking_id': widget.bookingId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка оплаты'), elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppConstants.paddingL),
                Text(
                  'Ошибка при загрузке данных о бронировании',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingM),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingXL),
                ElevatedButton.icon(
                  onPressed: () => context.goNamed('all_bookings'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Вернуться к бронированиям'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (!didPop) {
          context.pop();
        }
        return;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Оплата бронирования'),
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Карточка информации о бронировании
                    _buildBookingInfoCard(theme),

                    const SizedBox(height: AppConstants.paddingL),

                    // Секция способов оплаты
                    _buildPaymentMethodsSection(theme),
                  ],
                ),
              ),
            ),
            // Итоговая секция с кнопкой оплаты
            _buildPaymentFooter(theme),
          ],
        ),
      ),
    );
  }

  /// Карточка информации о бронировании
  Widget _buildBookingInfoCard(ThemeData theme) {
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'ru');

    return Card(
      margin: const EdgeInsets.all(AppConstants.paddingM),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 128)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _property?.title ?? 'Объект недвижимости',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_property?.address != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _property!.address,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),

            const Divider(height: 32),

            // Даты заезда и выезда
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Заезд: ',
                          style: TextStyle(color: theme.hintColor),
                        ),
                        TextSpan(
                          text: dateFormat.format(_booking!.checkInDate),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Выезд: ',
                          style: TextStyle(color: theme.hintColor),
                        ),
                        TextSpan(
                          text: dateFormat.format(_booking!.checkOutDate),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Количество гостей
            Row(
              children: [
                const Icon(Icons.people, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Гости: ',
                          style: TextStyle(color: theme.hintColor),
                        ),
                        TextSpan(
                          text:
                              '${_booking!.guestsCount} ${_getGuestsText(_booking!.guestsCount)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Секция способов оплаты
  Widget _buildPaymentMethodsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Способ оплаты',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.paddingM),

          // Контейнер для методов оплаты
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 128),
              ),
            ),
            child: Column(
              children: [
                // Кредитная карта
                _buildPaymentMethodTile(
                  theme: theme,
                  value: 'card',
                  title: 'Банковская карта',
                  subtitle: 'Visa, Mastercard, American Express',
                  icon: Icons.credit_card,
                  showDivider: true,
                ),

                // Kaspi
                _buildPaymentMethodWithLogo(
                  theme: theme,
                  value: 'kaspi',
                  title: 'Kaspi.kz',
                  subtitle: 'Будет выполнен переход в приложение Kaspi.kz',
                  logoPath: 'assets/images/payment/kaspi_logo.png',
                  backgroundColor: const Color(0xFFFEF0E9),
                  showDivider: true,
                ),

                // Halyk Bank
                _buildPaymentMethodWithLogo(
                  theme: theme,
                  value: 'halyk',
                  title: 'Халык Банк',
                  subtitle: 'Оплата через приложение Homebank',
                  logoPath: 'assets/images/payment/halyk_logo.png',
                  backgroundColor: const Color(0xFFEBF7F1),
                  showDivider: true,
                ),

                // Банковский перевод
                _buildPaymentMethodTile(
                  theme: theme,
                  value: 'transfer',
                  title: 'Банковский перевод',
                  subtitle: 'Перевод со счета на счет',
                  icon: Icons.account_balance,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Плитка способа оплаты
  Widget _buildPaymentMethodTile({
    required ThemeData theme,
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        RadioListTile<String>(
          value: value,
          groupValue: _selectedPaymentMethod,
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedPaymentMethod = newValue;
              });
            }
          },
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? theme.colorScheme.primary).withValues(
                    alpha: 26,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingM,
            vertical: AppConstants.paddingS,
          ),
          controlAffinity: ListTileControlAffinity.trailing,
          activeColor: theme.colorScheme.primary,
        ),
        if (showDivider) Divider(height: 1, indent: 68, endIndent: 20),
      ],
    );
  }

  /// Плитка способа оплаты с логотипом
  Widget _buildPaymentMethodWithLogo({
    required ThemeData theme,
    required String value,
    required String title,
    required String subtitle,
    required String logoPath,
    Color? backgroundColor,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        RadioListTile<String>(
          value: value,
          groupValue: _selectedPaymentMethod,
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedPaymentMethod = newValue;
              });
            }
          },
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      backgroundColor ??
                      theme.colorScheme.primary.withValues(alpha: 26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  logoPath,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      value == 'kaspi'
                          ? Icons.payments_rounded
                          : Icons.account_balance_rounded,
                      color:
                          value == 'kaspi'
                              ? const Color(0xFFDD2E44)
                              : const Color(0xFF008055),
                      size: 24,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingM,
            vertical: AppConstants.paddingS,
          ),
          controlAffinity: ListTileControlAffinity.trailing,
          activeColor: theme.colorScheme.primary,
        ),
        if (showDivider) Divider(height: 1, indent: 68, endIndent: 20),
      ],
    );
  }

  /// Нижняя часть экрана с кнопкой оплаты
  Widget _buildPaymentFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 13),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Итого к оплате:', style: theme.textTheme.titleMedium),
                Text(
                  '${_booking!.totalPrice.toInt()} ₸',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingM),
            ElevatedButton(
              onPressed: _isProcessingPayment ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 153,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isProcessingPayment
                      ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Обработка...'),
                        ],
                      )
                      : const Text('Оплатить'),
            ),
          ],
        ),
      ),
    );
  }

  String _getGuestsText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'гость';
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'гостя';
    } else {
      return 'гостей';
    }
  }
}
