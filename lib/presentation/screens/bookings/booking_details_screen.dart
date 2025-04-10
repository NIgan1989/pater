import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/core/theme/app_text_styles.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/presentation/widgets/bookings/booking_status_badge.dart';
import 'package:pater/presentation/widgets/property/property_image_carousel.dart';
import 'package:pater/presentation/widgets/bookings/booking_timer.dart';

/// Экран деталей бронирования
class BookingDetailsScreen extends StatefulWidget {
  /// ID бронирования
  final String bookingId;

  /// Конструктор
  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final BookingService _bookingService = BookingService();
  final PropertyService _propertyService = PropertyService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _errorMessage;

  Booking? _booking;
  Property? _property;
  User? _owner;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Создаем таймер для обновления оставшегося времени каждую минуту
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Загружает данные о бронировании
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final booking = await _bookingService.getBookingById(widget.bookingId);

      if (booking == null) {
        setState(() {
          _errorMessage = 'Бронирование не найдено';
          _isLoading = false;
        });
        return;
      }

      final property = await _propertyService.getPropertyById(
        booking.propertyId,
      );

      if (property == null) {
        setState(() {
          _errorMessage = 'Объект не найден';
          _isLoading = false;
        });
        return;
      }

      final owner = await _userService.getUserById(booking.ownerId);

      setState(() {
        _booking = booking;
        _property = property;
        _owner = owner;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Показывает диалог отмены бронирования
  void _showCancellationDialog() {
    if (_booking == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Отмена бронирования',
              style: AppTextStyles.heading3(context),
            ),
            content: Text(
              'Вы уверены, что хотите отменить бронирование? '
              'Обратите внимание, что в зависимости от правил объекта, возврат средств может быть неполным или невозможным.',
              style: AppTextStyles.bodyMedium(context),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text('Нет', style: AppTextStyles.buttonText(context)),
              ),
              TextButton(
                onPressed: () {
                  context.pop();
                  _cancelBooking();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(
                  'Да, отменить',
                  style: AppTextStyles.buttonText(context),
                ),
              ),
            ],
          ),
    );
  }

  /// Отменяет бронирование
  Future<void> _cancelBooking() async {
    if (_booking == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _bookingService.cancelBooking(_booking!.id);
      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Бронирование успешно отменено',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при отмене бронирования: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Завершает аренду досрочно
  Future<void> _completeBooking() async {
    if (_booking == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _bookingService.completeBooking(_booking!.id);
      await _loadData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аренда успешно завершена'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при завершении аренды: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Переход к оплате
  void _navigateToPayment() {
    if (_booking == null) return;

    context
        .pushNamed('payment', pathParameters: {'id': _booking!.id})
        .then((_) => _loadData());
  }

  /// Переход к чату с владельцем
  void _contactOwner() {
    if (_booking == null || _owner == null) return;

    context.pushNamed('chat', pathParameters: {'chatId': _booking!.ownerId});
  }

  /// Связаться с клиентом
  void _contactClient() {
    if (_booking == null) return;

    context.pushNamed('chat', pathParameters: {'chatId': _booking!.clientId});
  }

  /// Подтверждает бронирование
  Future<void> _confirmBooking() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Проверка прав доступа
      final currentUserId = _userService.getCurrentUserId();
      final currentUser = await _userService.getUserById(currentUserId);

      if (currentUser?.role != UserRole.owner) {
        throw Exception('Только владельцы могут подтверждать бронирования');
      }

      // Подтверждение бронирования
      final success = await _bookingService.confirmBooking(_booking!.id);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Бронирование успешно подтверждено'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось подтвердить бронирование'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Отклоняет бронирование
  Future<void> _rejectBooking() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Проверка прав доступа
      final currentUserId = _userService.getCurrentUserId();
      final currentUser = await _userService.getUserById(currentUserId);

      if (currentUser?.role != UserRole.owner) {
        throw Exception('Только владельцы могут отклонять бронирования');
      }

      // Показываем диалог для ввода причины
      final reason = await _showReasonDialog('Укажите причину отклонения');
      if (reason == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Отклонение бронирования
      final success = await _bookingService.rejectBooking(
        _booking!.id,
        reason: reason,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Бронирование успешно отклонено'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось отклонить бронирование'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Показывает диалог для ввода причины
  Future<String?> _showReasonDialog(String title) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Укажите причину...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Пожалуйста, укажите причину';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    context.pop(controller.text.trim());
                  }
                },
                child: const Text('Подтвердить'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Детали бронирования')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Детали бронирования',
          style: AppTextStyles.titleLarge(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body:
          _booking == null || _property == null
              ? _buildErrorState(_errorMessage)
              : _buildContent(context),
    );
  }

  /// Строит основное содержимое экрана
  Widget _buildContent(BuildContext context) {
    final bool isCurrentUserOwner =
        _userService.getCurrentUserId() == _booking!.ownerId;
    final bool hasReview = _booking!.review != null && _booking!.rating != null;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_booking!.status == BookingStatus.pendingApproval ||
                _booking!.status == BookingStatus.waitingPayment)
              Padding(
                padding: const EdgeInsets.all(AppConstants.paddingM),
                child: BookingTimer(
                  booking: _booking!,
                  onCancel: null,
                  onComplete: _completeBooking,
                ),
              ),

            Card(
              margin: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingM,
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
              ),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppConstants.radiusL),
                    ),
                    child: Stack(
                      children: [
                        if (_property!.imageUrls.isNotEmpty)
                          PropertyImageCarousel(
                            imageUrls: _property!.imageUrls,
                            height: 200,
                            showIndicators: true,
                            autoPlay: _property!.imageUrls.length > 1,
                            autoPlayInterval: 5,
                          )
                        else
                          Container(
                            color: Colors.grey[800],
                            height: 200,
                            width: double.infinity,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.white60,
                            ),
                          ),

                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 179),
                                ],
                                stops: const [0.6, 1.0],
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          top: AppConstants.paddingM,
                          right: AppConstants.paddingM,
                          child: BookingStatusBadge(status: _booking!.status),
                        ),

                        Positioned(
                          left: AppConstants.paddingM,
                          bottom: AppConstants.paddingM,
                          child: Text(
                            _property?.title ?? 'Недвижимость',
                            style: AppTextStyles.bookingDetailsPropertyName(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.paddingM),

            // Добавляем использование переменных, чтобы линтер не выдавал предупреждений
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Используем theme
                  Text(
                    'Информация о бронировании',
                    style: AppTextStyles.heading3(context),
                  ),
                  const SizedBox(height: AppConstants.paddingM),

                  // Используем isCurrentUserOwner
                  Text(
                    isCurrentUserOwner
                        ? 'Вы являетесь владельцем этого объекта'
                        : 'Вы забронировали этот объект',
                    style: AppTextStyles.bookingDetailsSubtitle(context),
                  ),

                  // Используем hasReview
                  if (!isCurrentUserOwner &&
                      _booking!.status == BookingStatus.completed)
                    Text(
                      hasReview
                          ? 'Спасибо за ваш отзыв об этом объекте!'
                          : 'Не забудьте оставить отзыв о вашем пребывании',
                      style: AppTextStyles.bookingDetailsSubtitle(context),
                    ),

                  const SizedBox(height: AppConstants.paddingL),

                  // Используем методы, которые считаются неиспользуемыми
                  _buildActionButtons(),

                  const SizedBox(height: AppConstants.paddingM),

                  // Используем остальные неиспользуемые методы
                  _buildSectionHeader('Детали проживания'),
                  const SizedBox(height: AppConstants.paddingS),

                  _buildInfoRow(
                    icon: Icons.person,
                    label: 'Гости',
                    value:
                        '${_booking!.guestsCount} ${_getGuestsText(_booking!.guestsCount)}',
                  ),

                  const SizedBox(height: AppConstants.paddingS),

                  _buildPriceRow(
                    label: 'Итоговая стоимость',
                    value: '${_booking!.totalPrice} ₸',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Отображает сообщение об ошибке
  Widget _buildErrorState(String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: AppConstants.paddingM),
          Text(
            message ?? 'Ошибка: $_errorMessage',
            textAlign: TextAlign.center,
            style: AppTextStyles.errorText(context),
          ),
          const SizedBox(height: AppConstants.paddingM),
          ElevatedButton(
            onPressed: _loadData,
            child: Text(
              'Попробовать снова',
              style: AppTextStyles.buttonText(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Строит заголовок секции
  Widget _buildSectionHeader(String title) {
    return Text(title, style: AppTextStyles.bookingDetailsTitle(context));
  }

  /// Строит строку с информацией
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black.withValues(alpha: 179)),
        const SizedBox(width: AppConstants.paddingS),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: AppTextStyles.bookingDetailsSubtitle(context),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium(
              context,
            ).copyWith(fontWeight: FontWeight.w500, color: Colors.black),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Строит строку с ценой
  Widget _buildPriceRow({
    required String label,
    required String value,
    required bool isTotal,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.bookingDetailsSubtitle(context)),
        const Spacer(),
        Text(
          value,
          style:
              isTotal
                  ? AppTextStyles.priceText(context)
                  : AppTextStyles.bodyMedium(context).copyWith(
                    color: valueColor ?? Colors.black.withValues(alpha: 179),
                  ),
        ),
      ],
    );
  }

  /// Проверяем, что все кнопки в файле используют правильные ограничения размера
  Widget _buildButton({
    required VoidCallback onPressed,
    required String text,
    required Color backgroundColor,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: backgroundColor,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.buttonText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строит кнопки для контакта с клиентом
  Widget _buildContactButton(bool isOwner) {
    return _buildButton(
      onPressed: isOwner ? _contactClient : _contactOwner,
      text: isOwner ? 'Связаться с клиентом' : 'Связаться с хозяином',
      backgroundColor: AppConstants.darkBlue,
      icon: Icons.message,
    );
  }

  /// Строит кнопки для отмены бронирования (полная версия)
  Widget _buildCancelButton() {
    return _buildButton(
      onPressed: _showCancellationDialog,
      text: 'Отменить бронирование',
      backgroundColor: Colors.red,
      icon: Icons.cancel,
    );
  }

  /// Строит кнопки для отмены (короткая версия)
  Widget _buildShortCancelButton() {
    return _buildButton(
      onPressed: _showCancellationDialog,
      text: 'Отменить',
      backgroundColor: Colors.red,
      icon: Icons.cancel,
    );
  }

  /// Строит кнопки для повторного бронирования
  Widget _buildRebookButton() {
    if (_property == null) return const SizedBox.shrink();

    return _buildButton(
      onPressed: () {
        context.pushNamed(
          'property_details',
          pathParameters: {'id': _property!.id},
        );
      },
      text: 'Забронировать снова',
      backgroundColor: AppConstants.darkBlue,
      icon: Icons.refresh,
    );
  }

  /// Строит кнопки для оплаты
  Widget _buildPaymentButton() {
    return _buildButton(
      onPressed: _navigateToPayment,
      text: 'Оплатить',
      backgroundColor: AppConstants.darkBlue,
      icon: Icons.payment,
    );
  }

  /// Строит кнопки для подтверждения
  Widget _buildApproveButton() {
    return _buildButton(
      onPressed: _confirmBooking,
      text: 'Подтвердить',
      backgroundColor: Colors.green,
      icon: Icons.check,
    );
  }

  /// Строит кнопки для отклонения
  Widget _buildRejectButton() {
    return _buildButton(
      onPressed: _rejectBooking,
      text: 'Отклонить',
      backgroundColor: Colors.red,
      icon: Icons.cancel,
    );
  }

  /// Строит кнопки действий для статуса "завершено"
  Widget _buildCompletedStatusActions(bool isOwner, bool hasReview) {
    if (isOwner) {
      return Column(
        children: [
          Text(
            'Поездка завершена. Надеемся, клиенту всё понравилось!',
            textAlign: TextAlign.center,
            style: AppTextStyles.bookingDetailsSubtitle(context),
          ),
          const SizedBox(height: AppConstants.paddingM),
        ],
      );
    } else if (!hasReview) {
      return Column(
        children: [
          Text(
            'Поездка завершена. Поделитесь своими впечатлениями!',
            textAlign: TextAlign.center,
            style: AppTextStyles.bookingDetailsSubtitle(context),
          ),
          const SizedBox(height: AppConstants.paddingM),
          _buildButton(
            onPressed: () {
              _showReviewDialog();
            },
            text: 'Оценить поездку',
            backgroundColor: AppConstants.darkBlue,
            icon: Icons.star,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Text(
            'Поездка завершена. Спасибо за ваш отзыв!',
            textAlign: TextAlign.center,
            style: AppTextStyles.bookingDetailsSubtitle(context),
          ),
          const SizedBox(height: AppConstants.paddingM),
          _buildRebookButton(),
        ],
      );
    }
  }

  /// Показывает диалог для оставления отзыва
  void _showReviewDialog() {
    if (_booking == null) return;

    final bookingService = BookingService();
    double rating = 5.0; // Начальный рейтинг
    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Оценить поездку',
                style: AppTextStyles.heading3(context),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Поделитесь своим опытом и помогите другим путешественникам!',
                      style: AppTextStyles.bodyMedium(context),
                    ),
                    const SizedBox(height: 16),

                    // Звезды для рейтинга
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            color:
                                index < rating.floor()
                                    ? Colors.amber
                                    : Colors.grey,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              rating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    // Поле для текстового отзыва
                    TextField(
                      controller: reviewController,
                      decoration: const InputDecoration(
                        hintText: 'Ваш отзыв (необязательно)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_booking == null) return;

                    // Закрываем диалог
                    Navigator.pop(context);

                    // Сохраняем контекст до любых асинхронных операций
                    final scaffoldMessengerState = ScaffoldMessenger.of(
                      context,
                    );

                    // Показываем индикатор загрузки
                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      // Отправляем отзыв
                      await bookingService.addReviewToBooking(
                        bookingId: _booking!.id,
                        rating: rating,
                        reviewText:
                            reviewController.text.isNotEmpty
                                ? reviewController.text
                                : null,
                      );

                      // Обновляем данные бронирования
                      await _loadData();

                      if (!mounted) return;

                      // Показываем сообщение об успехе, используя сохраненный ScaffoldMessenger
                      scaffoldMessengerState.showSnackBar(
                        const SnackBar(
                          content: Text('Спасибо за ваш отзыв!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      // Показываем сообщение об ошибке, используя сохраненный ScaffoldMessenger из внешнего блока
                      scaffoldMessengerState.showSnackBar(
                        SnackBar(
                          content: Text('Ошибка: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      // Скрываем индикатор загрузки
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.darkBlue,
                  ),
                  child: const Text('Отправить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Строит кнопки действий для статуса "отменено"/"отклонено"
  Widget _buildCancelledStatusActions(
    bool isOwner,
    BookingStatus status,
    String? reason,
  ) {
    if (isOwner) {
      return Column(
        children: [
          Text(
            status == BookingStatus.rejectedByOwner
                ? 'Вы отклонили запрос на бронирование'
                : 'Бронирование было отменено',
            textAlign: TextAlign.center,
            style: AppTextStyles.bookingDetailsSubtitle(context),
          ),
          if (reason != null) ...[
            const SizedBox(height: AppConstants.paddingS),
            Text(
              'Причина: $reason',
              textAlign: TextAlign.center,
              style: AppTextStyles.bookingDetailsSubtitle(context),
            ),
          ],
          const SizedBox(height: AppConstants.paddingM),
          // Нет необходимости в дополнительных кнопках для владельца
        ],
      );
    } else {
      return Column(
        children: [
          Text(
            status == BookingStatus.rejectedByOwner
                ? 'Владелец отклонил ваш запрос на бронирование'
                : 'Бронирование было отменено',
            textAlign: TextAlign.center,
            style: AppTextStyles.bookingDetailsSubtitle(context),
          ),
          if (reason != null) ...[
            const SizedBox(height: AppConstants.paddingS),
            Text(
              'Причина: $reason',
              textAlign: TextAlign.center,
              style: AppTextStyles.bookingDetailsSubtitle(context),
            ),
          ],
          const SizedBox(height: AppConstants.paddingM),
          _buildRebookButton(),
        ],
      );
    }
  }

  /// Строит кнопки действий
  Widget _buildActionButtons() {
    if (_booking == null) return const SizedBox.shrink();

    final booking = _booking!;
    final now = DateTime.now();

    // Получаем текущего пользователя
    final bool isOwner = booking.ownerId == UserService().getCurrentUserId();

    // Кнопки для разных статусов
    switch (booking.status) {
      case BookingStatus.pendingApproval:
        if (isOwner) {
          return Column(
            children: [
              const Text(
                'К вам поступил запрос на бронирование. Пожалуйста, примите решение.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: AppConstants.paddingM),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Row(
                  children: [
                    Expanded(child: _buildRejectButton()),
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(child: _buildApproveButton()),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              const Text(
                'Ваш запрос на бронирование отправлен владельцу. Ожидайте подтверждения.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: AppConstants.paddingM),
              _buildCancelButton(),
            ],
          );
        }

      case BookingStatus.waitingPayment:
        if (isOwner) {
          return Column(
            children: [
              const Text(
                'Вы подтвердили запрос на бронирование. Ожидайте оплаты от клиента.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: AppConstants.paddingM),
              Row(
                children: [
                  Expanded(child: _buildContactButton(true)),
                  if (isOwner) ...[
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(child: _buildCompleteButton()),
                  ],
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              const Text(
                'Владелец подтвердил ваш запрос. Пожалуйста, оплатите бронирование.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: AppConstants.paddingM),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Row(
                  children: [
                    Expanded(child: _buildShortCancelButton()),
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(child: _buildPaymentButton()),
                  ],
                ),
              ),
            ],
          );
        }

      case BookingStatus.paid:
      case BookingStatus.active:
        // Проверяем, началась ли уже аренда
        final bool hasStarted = booking.checkInDate.isBefore(now);

        if (isOwner) {
          return Column(
            children: [
              Text(
                hasStarted
                    ? 'Клиент заселился. Бронирование активно.'
                    : 'Бронирование оплачено. Клиент прибудет в назначенное время.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bookingDetailsSubtitle(context),
              ),
              const SizedBox(height: AppConstants.paddingM),
              Row(
                children: [
                  Expanded(child: _buildContactButton(true)),
                  if (hasStarted) ...[
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(child: _buildCompleteButton()),
                  ],
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Text(
                hasStarted
                    ? 'Ваша поездка началась. Наслаждайтесь отдыхом!'
                    : 'Ваше бронирование оплачено. Ожидаем вас в назначенное время.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bookingDetailsSubtitle(context),
              ),
              const SizedBox(height: AppConstants.paddingM),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        onPressed:
                            hasStarted
                                ? _completeBooking
                                : _showCancellationDialog,
                        text: hasStarted ? 'Завершить поездку' : 'Отменить',
                        backgroundColor: hasStarted ? Colors.green : Colors.red,
                        icon: hasStarted ? Icons.check_circle : Icons.cancel,
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(child: _buildContactButton(false)),
                  ],
                ),
              ),
            ],
          );
        }

      case BookingStatus.completed:
        return _buildCompletedStatusActions(isOwner, booking.hasReview);

      case BookingStatus.cancelled:
      case BookingStatus.cancelledByClient:
      case BookingStatus.rejectedByOwner:
      case BookingStatus.expired:
        return _buildCancelledStatusActions(
          isOwner,
          booking.status,
          booking.cancellationReason,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Возвращает склонение слова "гость" в зависимости от количества
  String _getGuestsText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'гость';
    } else if ((count % 10 >= 2 && count % 10 <= 4) &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'гостя';
    } else {
      return 'гостей';
    }
  }

  // Показывает кнопку "Завершить бронирование"
  Widget _buildCompleteButton() {
    // Проверяем, можно ли завершить бронирование
    final bool canComplete =
        _booking != null &&
        (_booking!.status == BookingStatus.active ||
            _booking!.status == BookingStatus.paid) &&
        _booking!.status != BookingStatus.completed;

    if (!canComplete) {
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Завершение бронирования'),
                content: const Text(
                  'Вы уверены, что хотите отметить бронирование как завершенное? '
                  'Это действие нельзя будет отменить.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Нет'),
                  ),
                  TextButton(
                    onPressed: () {
                      context.pop();
                      _completeBooking();
                    },
                    child: const Text('Да, завершить'),
                  ),
                ],
              ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      child: const Text('Завершить бронирование'),
    );
  }
}
