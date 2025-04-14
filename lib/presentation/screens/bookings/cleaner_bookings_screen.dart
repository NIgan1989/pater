import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/data/services/cleaning_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/cleaning_request.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/core/di/service_locator.dart';

/// Модель, объединяющая заявку на уборку и данные об объекте
class CleaningRequestWithProperty {
  final CleaningRequest request;
  final Property property;

  CleaningRequestWithProperty({required this.request, required this.property});
}

/// Экран для просмотра заявок на уборку для клинеров
class CleanerBookingsScreen extends StatefulWidget {
  const CleanerBookingsScreen({super.key});

  @override
  State<CleanerBookingsScreen> createState() => _CleanerBookingsScreenState();
}

class _CleanerBookingsScreenState extends State<CleanerBookingsScreen>
    with SingleTickerProviderStateMixin {
  final CleaningService _cleaningService = CleaningService();
  final PropertyService _propertyService = PropertyService();
  late final AuthService _authService;

  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  // Списки заявок по категориям
  List<CleaningRequestWithProperty> _availableRequests = [];
  List<CleaningRequestWithProperty> _activeRequests = [];
  List<CleaningRequestWithProperty> _completedRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _authService = getIt<AuthService>();
    _loadCleaningRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Загружает заявки на уборку
  Future<void> _loadCleaningRequests() async {
    if (_authService.currentUser == null) {
      setState(() {
        _errorMessage = 'Пользователь не авторизован';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cleanerId = _authService.currentUser!.id;

      // Получаем доступные заявки (не принятые никем)
      final availableRequests =
          await _cleaningService.getAvailableCleaningRequests();

      // Получаем активные заявки для текущего клинера
      final activeRequests = await _cleaningService.getCleanerActiveRequests(
        cleanerId,
      );

      // Получаем завершенные заявки для текущего клинера
      final completedRequests = await _cleaningService
          .getCleanerCompletedRequests(cleanerId);

      // Списки для хранения заявок с данными об объектах
      final List<CleaningRequestWithProperty> availableWithProperty = [];
      final List<CleaningRequestWithProperty> activeWithProperty = [];
      final List<CleaningRequestWithProperty> completedWithProperty = [];

      // Для каждой заявки получаем данные об объекте
      for (final request in availableRequests) {
        final property = await _propertyService.getPropertyById(
          request.propertyId,
        );
        if (property != null) {
          availableWithProperty.add(
            CleaningRequestWithProperty(request: request, property: property),
          );
        }
      }

      for (final request in activeRequests) {
        final property = await _propertyService.getPropertyById(
          request.propertyId,
        );
        if (property != null) {
          activeWithProperty.add(
            CleaningRequestWithProperty(request: request, property: property),
          );
        }
      }

      for (final request in completedRequests) {
        final property = await _propertyService.getPropertyById(
          request.propertyId,
        );
        if (property != null) {
          completedWithProperty.add(
            CleaningRequestWithProperty(request: request, property: property),
          );
        }
      }

      // Сортируем заявки по дате
      availableWithProperty.sort(
        (a, b) => b.request.createdAt.compareTo(a.request.createdAt),
      );

      activeWithProperty.sort(
        (a, b) => b.request.createdAt.compareTo(a.request.createdAt),
      );

      completedWithProperty.sort(
        (a, b) =>
            b.request.completedAt?.compareTo(
              a.request.completedAt ?? DateTime(2000),
            ) ??
            -1,
      );

      if (mounted) {
        setState(() {
          _availableRequests = availableWithProperty;
          _activeRequests = activeWithProperty;
          _completedRequests = completedWithProperty;
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

  /// Переход к деталям заявки на уборку
  void _navigateToCleaningDetails(String requestId) {
    context
        .pushNamed('cleaning_details', pathParameters: {'id': requestId})
        .then((_) => _loadCleaningRequests());
  }

  /// Переход к деталям объекта
  void _navigateToPropertyDetails(String propertyId) {
    context.pushNamed('property_details', pathParameters: {'id': propertyId});
  }

  /// Принимает заявку на уборку
  Future<void> _acceptCleaningRequest(String requestId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }

      await _cleaningService.acceptCleaningRequest(requestId, user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заявка успешно принята'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCleaningRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Завершает заявку на уборку
  Future<void> _completeCleaningRequest(String requestId) async {
    try {
      await _cleaningService.completeCleaningRequest(requestId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Уборка отмечена как завершенная'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCleaningRequests();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Контакт с владельцем
  void _contactOwner(String ownerId) {
    context.pushNamed('chat', pathParameters: {'chatId': ownerId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уборки'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Доступные'),
            Tab(text: 'Активные'),
            Tab(text: 'Завершенные'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildRequestsList(_availableRequests, true),
                  _buildRequestsList(_activeRequests, false),
                  _buildRequestsList(_completedRequests, false),
                ],
              ),
    );
  }

  /// Отображает сообщение об ошибке
  Widget _buildErrorState() {
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
            onPressed: _loadCleaningRequests,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }

  /// Отображает список заявок на уборку
  Widget _buildRequestsList(
    List<CleaningRequestWithProperty> requests,
    bool isAvailable,
  ) {
    if (requests.isEmpty) {
      return _buildEmptyState(isAvailable);
    }

    return RefreshIndicator(
      onRefresh: _loadCleaningRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(requests[index], isAvailable);
        },
      ),
    );
  }

  /// Отображает пустое состояние для категории заявок
  Widget _buildEmptyState(bool isAvailable) {
    IconData icon;
    String title;
    String message;

    if (isAvailable) {
      icon = Icons.cleaning_services_outlined;
      title = 'Нет доступных заявок';
      message =
          'В данный момент нет доступных заявок на уборку. Проверьте позже.';
    } else {
      icon = Icons.history;
      title = 'Нет заявок';
      message = 'У вас пока нет активных или выполненных заявок на уборку.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppConstants.paddingM),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.paddingS),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingL,
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  /// Отображает карточку заявки на уборку
  Widget _buildRequestCard(
    CleaningRequestWithProperty requestWithProperty,
    bool isAvailable,
  ) {
    final request = requestWithProperty.request;
    final property = requestWithProperty.property;

    // Форматирование дат
    final dateFormatter = DateFormat('dd.MM.yyyy');

    // Цвет и текст статуса
    Color statusColor;
    String statusText;

    // Определяем цвет и текст статуса
    switch (request.status) {
      case CleaningRequestStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Ожидает клинера';
        break;
      case CleaningRequestStatus.assigned:
        statusColor = Colors.indigo;
        statusText = 'Назначено';
        break;
      case CleaningRequestStatus.inProgress:
        statusColor = Colors.blue;
        statusText = 'В процессе';
        break;
      case CleaningRequestStatus.completed:
        statusColor = Colors.green;
        statusText = 'Выполнено';
        break;
      case CleaningRequestStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Отменено';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Неизвестно';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingM),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: InkWell(
        onTap: () => _navigateToCleaningDetails(request.id),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение объекта
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusM),
                topRight: Radius.circular(AppConstants.radiusM),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Изображение
                    property.imageUrls.isNotEmpty
                        ? Image.network(
                          property.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => const Center(
                                child: Icon(Icons.image_not_supported),
                              ),
                        )
                        : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.home,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),

                    // Затемнение
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),

                    // Заголовок
                    Positioned(
                      left: AppConstants.paddingM,
                      right: AppConstants.paddingM,
                      bottom: AppConstants.paddingM,
                      child: Text(
                        property.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Статус
                    Positioned(
                      top: AppConstants.paddingM,
                      right: AppConstants.paddingM,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingS,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusS,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Информация о заявке
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Дата создания
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Создано: ${dateFormatter.format(request.createdAt)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.paddingXS),

                  // Адрес
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.address,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.paddingXS),

                  // Площадь
                  Row(
                    children: [
                      const Icon(
                        Icons.square_foot,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Площадь: ${property.area.toInt()} м²',
                        style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      ),
                      const Spacer(),
                      Text(
                        '${request.estimatedPrice.toInt()} ₸',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.darkBlue,
                        ),
                      ),
                    ],
                  ),

                  // Описание
                  if (request.description.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.paddingS),
                    Container(
                      padding: const EdgeInsets.all(AppConstants.paddingS),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusS,
                        ),
                      ),
                      child: Text(
                        request.description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  // Кнопки действий
                  const SizedBox(height: AppConstants.paddingM),
                  _buildActionButtons(request, isAvailable),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Отображает кнопки действий для заявки
  Widget _buildActionButtons(CleaningRequest request, bool isAvailable) {
    if (isAvailable) {
      // Кнопки для доступных заявок
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateToPropertyDetails(request.propertyId),
              icon: const Icon(Icons.visibility),
              label: const Text('Детали объекта'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.paddingM),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _acceptCleaningRequest(request.id),
              icon: const Icon(Icons.check_circle),
              label: const Text('Принять'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    } else if (request.status == CleaningRequestStatus.assigned ||
        request.status == CleaningRequestStatus.inProgress) {
      // Кнопки для назначенных заявок
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _contactOwner(request.ownerId),
              icon: const Icon(Icons.message),
              label: const Text('Связаться'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.paddingM),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _completeCleaningRequest(request.id),
              icon: const Icon(Icons.check_circle),
              label: const Text('Завершить'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    } else {
      // Кнопка просмотра деталей для завершенных заявок
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateToCleaningDetails(request.id),
              icon: const Icon(Icons.info_outline),
              label: const Text('Детали уборки'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }
  }
}
