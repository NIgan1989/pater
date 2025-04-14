import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/cleaning_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/cleaning_request.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/core/di/service_locator.dart';

/// Экран для клинеров, где они могут управлять своими заявками на уборку
class CleanerWorkboardScreen extends StatefulWidget {
  const CleanerWorkboardScreen({super.key});

  @override
  State<CleanerWorkboardScreen> createState() => _CleanerWorkboardScreenState();
}

class _CleanerWorkboardScreenState extends State<CleanerWorkboardScreen>
    with SingleTickerProviderStateMixin {
  final CleaningService _cleaningService = CleaningService();
  late final AuthService _authService;
  final _propertyService = PropertyService();

  late TabController _tabController;

  List<CleaningRequest> _cleaningRequests = [];
  Map<String, Property> _propertiesMap = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _authService = getIt<AuthService>();
    _loadCleaningRequests();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  /// Обрабатывает изменение выбранной вкладки
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  /// Загружает заявки на уборку для текущего клинера
  Future<void> _loadCleaningRequests() async {
    if (_authService.currentUser == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Пользователь не авторизован';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Получаем все заявки, принятые клинером
      final cleanerId = _authService.currentUser!.id;
      final requests = await _cleaningService.getCleaningRequestsByCleanerId(
        cleanerId,
      );

      // Дополнительно получаем доступные заявки, которые клинер может взять
      final availableRequests =
          await _cleaningService.getAvailableCleaningRequests();

      // Получаем информацию об объектах недвижимости
      final allRequests = [...requests, ...availableRequests];
      final propertyIds = allRequests.map((r) => r.propertyId).toSet().toList();
      final propertiesMap = <String, Property>{};

      for (final propertyId in propertyIds) {
        try {
          final property = await _propertyService.getPropertyById(propertyId);
          if (property != null) {
            propertiesMap[propertyId] = property;
          }
        } catch (e) {
          debugPrint('Ошибка при загрузке объекта: $e');
        }
      }

      if (mounted) {
        setState(() {
          _cleaningRequests = allRequests;
          _propertiesMap = propertiesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка при загрузке заявок: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Отправляет предложение на заявку
  Future<void> _sendOffer(String requestId, double price) async {
    try {
      final cleanerId = _authService.currentUser!.id;
      await _cleaningService.createOffer(cleanerId, requestId, price, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Предложение успешно отправлено'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCleaningRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отправке предложения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Обновляет статус заявки на "в процессе"
  Future<void> _startCleaning(String requestId) async {
    try {
      await _cleaningService.updateCleaningRequestStatus(
        requestId,
        CleaningRequestStatus.inProgress,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Уборка начата'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCleaningRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении статуса: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Завершает уборку
  Future<void> _completeCleaning(String requestId) async {
    try {
      await _cleaningService.updateCleaningRequestStatus(
        requestId,
        CleaningRequestStatus.completed,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Уборка завершена'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCleaningRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при завершении уборки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель клинера'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Доступные'),
            Tab(text: 'Мои заявки'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildErrorState(theme)
              : _buildContent(theme),
    );
  }

  /// Строит сообщение об ошибке
  Widget _buildErrorState(ThemeData theme) {
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

  /// Строит основной контент экрана в зависимости от выбранной вкладки
  Widget _buildContent(ThemeData theme) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Доступные заявки
        _buildAvailableRequests(theme),

        // Мои заявки
        _buildMyRequests(theme),

        // История заявок
        _buildHistoryRequests(theme),
      ],
    );
  }

  /// Строит список доступных заявок на уборку
  Widget _buildAvailableRequests(ThemeData theme) {
    final availableRequests =
        _cleaningRequests
            .where(
              (request) =>
                  request.status == CleaningRequestStatus.waitingCleaner ||
                  request.status == CleaningRequestStatus.withOffers,
            )
            .toList();

    if (availableRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cleaning_services_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'Нет доступных заявок на уборку',
              style: theme.textTheme.titleMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCleaningRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        itemCount: availableRequests.length,
        itemBuilder: (context, index) {
          final request = availableRequests[index];
          final property = _propertiesMap[request.propertyId];

          return Card(
            margin: const EdgeInsets.only(bottom: AppConstants.paddingM),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Адрес и дата
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.address,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              request.city,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(AppConstants.paddingXS),
                        decoration: BoxDecoration(
                          color: _getUrgencyColor(
                            request.urgency,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusS,
                          ),
                        ),
                        child: Text(
                          _getUrgencyText(request.urgency),
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: _getUrgencyColor(request.urgency),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(),

                  // Детали заявки
                  Row(
                    children: [
                      _buildInfoItem(
                        theme,
                        Icons.calendar_today,
                        'Дата',
                        DateFormat('dd.MM.yyyy').format(request.scheduledDate),
                      ),
                      const SizedBox(width: AppConstants.paddingM),
                      _buildInfoItem(
                        theme,
                        Icons.access_time,
                        'Время',
                        DateFormat('HH:mm').format(request.scheduledDate),
                      ),
                      const SizedBox(width: AppConstants.paddingM),
                      _buildInfoItem(
                        theme,
                        Icons.home_work_outlined,
                        'Тип',
                        _getCleaningTypeText(request.cleaningType),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.paddingM),

                  // Стоимость
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Предложенная цена',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${request.estimatedPrice.toInt()} ₸',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.paddingM),

                  // Кнопки действий
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          _showDetailsDialog(request, property);
                        },
                        child: const Text('Подробнее'),
                      ),
                      const SizedBox(width: AppConstants.paddingM),
                      ElevatedButton(
                        onPressed: () {
                          _showOfferDialog(request);
                        },
                        child: const Text('Откликнуться'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Строит список заявок, принятых клинером
  Widget _buildMyRequests(ThemeData theme) {
    final cleanerId = _authService.currentUser!.id;
    final myRequests =
        _cleaningRequests
            .where(
              (request) =>
                  request.cleanerId == cleanerId &&
                  (request.status == CleaningRequestStatus.approved ||
                      request.status == CleaningRequestStatus.inProgress),
            )
            .toList();

    if (myRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cleaning_services_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'У вас нет активных заявок на уборку',
              style: theme.textTheme.titleMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCleaningRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        itemCount: myRequests.length,
        itemBuilder: (context, index) {
          final request = myRequests[index];

          return Card(
            margin: const EdgeInsets.only(bottom: AppConstants.paddingM),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статус заявки
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingS,
                      vertical: AppConstants.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        request.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    child: Text(
                      _getStatusText(request.status),
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: _getStatusColor(request.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingS),

                  // Адрес
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.address,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              request.city,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd.MM.yyyy HH:mm',
                        ).format(request.scheduledDate),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const Divider(),

                  // Стоимость
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Стоимость уборки',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${request.estimatedPrice.toInt()} ₸',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppConstants.paddingM),

                  // Кнопки действий
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          _navigateToRequestDetails(request.id);
                        },
                        child: const Text('Подробнее'),
                      ),
                      const SizedBox(width: AppConstants.paddingM),
                      if (request.status == CleaningRequestStatus.approved)
                        ElevatedButton(
                          onPressed: () => _startCleaning(request.id),
                          child: const Text('Начать уборку'),
                        )
                      else if (request.status ==
                          CleaningRequestStatus.inProgress)
                        ElevatedButton(
                          onPressed: () => _showCompleteDialog(request.id),
                          child: const Text('Завершить'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Строит список завершенных заявок клинера
  Widget _buildHistoryRequests(ThemeData theme) {
    final cleanerId = _authService.currentUser!.id;
    final historyRequests =
        _cleaningRequests
            .where(
              (request) =>
                  request.cleanerId == cleanerId &&
                  (request.status == CleaningRequestStatus.completed ||
                      request.status == CleaningRequestStatus.cancelled),
            )
            .toList();

    if (historyRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              'История заявок пуста',
              style: theme.textTheme.titleMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCleaningRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        itemCount: historyRequests.length,
        itemBuilder: (context, index) {
          final request = historyRequests[index];

          return Card(
            margin: const EdgeInsets.only(bottom: AppConstants.paddingM),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статус заявки
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingS,
                      vertical: AppConstants.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        request.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    child: Text(
                      _getStatusText(request.status),
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: _getStatusColor(request.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingS),

                  // Адрес и дата
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.address,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              request.city,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('dd.MM.yyyy').format(
                          request.completedAt ??
                              request.cancelledAt ??
                              request.createdAt,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),

                  const Divider(),

                  // Детали завершенной заявки
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Стоимость', style: theme.textTheme.bodyMedium),
                      Text(
                        '${(request.actualPrice ?? request.estimatedPrice).toInt()} ₸',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              request.status == CleaningRequestStatus.completed
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),

                  if (request.rating != null) ...[
                    const SizedBox(height: AppConstants.paddingS),
                    Row(
                      children: [
                        Text('Оценка: ', style: theme.textTheme.bodyMedium),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < (request.rating ?? 0).floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppConstants.paddingS),

                  // Кнопка для просмотра деталей
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () {
                        _navigateToRequestDetails(request.id);
                      },
                      child: const Text('Детали'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Вспомогательный метод для создания элемента информации
  Widget _buildInfoItem(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Отображает диалог с подробной информацией о заявке
  void _showDetailsDialog(CleaningRequest request, Property? property) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Детали заявки'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (property != null) ...[
                    Text(
                      'Объект: ${property.title}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text('Адрес: ${request.address}, ${request.city}'),
                  const SizedBox(height: 8),
                  Text(
                    'Дата и время: ${DateFormat('dd.MM.yyyy HH:mm').format(request.scheduledDate)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Тип уборки: ${_getCleaningTypeText(request.cleaningType)}',
                  ),
                  const SizedBox(height: 8),
                  Text('Срочность: ${_getUrgencyText(request.urgency)}'),
                  const SizedBox(height: 8),
                  Text(
                    'Ожидаемая стоимость: ${request.estimatedPrice.toInt()} ₸',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Описание:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(request.description),
                  if (request.additionalServices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Дополнительные услуги:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...request.additionalServices.map(
                      (service) => Text('• $service'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Закрыть'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.pop();
                  _showOfferDialog(request);
                },
                child: const Text('Откликнуться'),
              ),
            ],
          ),
    );
  }

  /// Отображает диалог для отправки предложения
  void _showOfferDialog(CleaningRequest request) {
    final priceController = TextEditingController(
      text: request.estimatedPrice.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отправить предложение'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Укажите цену, за которую вы готовы выполнить уборку:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Цена (₸)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  final price = double.tryParse(priceController.text);
                  if (price != null && price > 0) {
                    context.pop();
                    _sendOffer(request.id, price);
                  }
                },
                child: const Text('Отправить'),
              ),
            ],
          ),
    );
  }

  /// Отображает диалог подтверждения завершения уборки
  void _showCompleteDialog(String requestId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Завершить уборку'),
            content: const Text(
              'Вы уверены, что хотите завершить уборку? '
              'После этого владелец сможет оставить отзыв о вашей работе.',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.pop();
                  _completeCleaning(requestId);
                },
                child: const Text('Завершить'),
              ),
            ],
          ),
    );
  }

  /// Переходит к деталям заявки на уборку
  void _navigateToRequestDetails(String requestId) {
    context
        .pushNamed(
          'cleaning_request_details',
          pathParameters: {'id': requestId},
        )
        .then((_) => _loadCleaningRequests());
  }

  /// Возвращает цвет для статуса заявки
  Color _getStatusColor(CleaningRequestStatus status) {
    switch (status) {
      case CleaningRequestStatus.waitingCleaner:
      case CleaningRequestStatus.pendingApproval:
      case CleaningRequestStatus.withOffers:
        return Colors.orange;
      case CleaningRequestStatus.approved:
        return Colors.blue;
      case CleaningRequestStatus.inProgress:
        return Colors.purple;
      case CleaningRequestStatus.completed:
        return Colors.green;
      case CleaningRequestStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Возвращает текст для статуса заявки
  String _getStatusText(CleaningRequestStatus status) {
    switch (status) {
      case CleaningRequestStatus.waitingCleaner:
        return 'Ожидает клинера';
      case CleaningRequestStatus.pendingApproval:
        return 'Ожидает подтверждения';
      case CleaningRequestStatus.withOffers:
        return 'Есть предложения';
      case CleaningRequestStatus.approved:
        return 'Подтверждена';
      case CleaningRequestStatus.inProgress:
        return 'В процессе';
      case CleaningRequestStatus.completed:
        return 'Завершена';
      case CleaningRequestStatus.cancelled:
        return 'Отменена';
      case CleaningRequestStatus.active:
        return 'Активна';
      case CleaningRequestStatus.accepted:
        return 'Принята';
      default:
        return 'Неизвестно';
    }
  }

  /// Возвращает цвет для срочности заявки
  Color _getUrgencyColor(CleaningUrgency urgency) {
    switch (urgency) {
      case CleaningUrgency.low:
        return Colors.green;
      case CleaningUrgency.medium:
        return Colors.blue;
      case CleaningUrgency.high:
        return Colors.orange;
      case CleaningUrgency.urgent:
        return Colors.red;
    }
  }

  /// Возвращает текст для срочности заявки
  String _getUrgencyText(CleaningUrgency urgency) {
    switch (urgency) {
      case CleaningUrgency.low:
        return 'Низкая срочность';
      case CleaningUrgency.medium:
        return 'Средняя срочность';
      case CleaningUrgency.high:
        return 'Высокая срочность';
      case CleaningUrgency.urgent:
        return 'Срочная';
    }
  }

  /// Возвращает текст для типа уборки
  String _getCleaningTypeText(CleaningType type) {
    switch (type) {
      case CleaningType.regular:
        return 'Обычная';
      case CleaningType.general:
        return 'Генеральная';
      case CleaningType.postConstruction:
      case CleaningType.postConstruction2:
        return 'После ремонта';
      case CleaningType.afterGuests:
        return 'После гостей';
      case CleaningType.basic:
        return 'Базовая';
      case CleaningType.deep:
        return 'Глубокая';
      case CleaningType.window:
        return 'Мытьё окон';
      case CleaningType.carpet:
        return 'Чистка ковров';
    }
  }
}
