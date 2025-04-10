import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/cleaning_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/cleaning_request.dart';
import 'package:pater/domain/entities/property.dart';

/// Экран управления заявками на уборку для владельцев
class CleaningRequestsScreen extends StatefulWidget {
  const CleaningRequestsScreen({super.key});

  @override
  State<CleaningRequestsScreen> createState() => _CleaningRequestsScreenState();
}

class _CleaningRequestsScreenState extends State<CleaningRequestsScreen>
    with SingleTickerProviderStateMixin {
  final CleaningService _cleaningService = CleaningService();
  final PropertyService _propertyService = PropertyService();
  final AuthService authService = AuthService();

  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<CleaningRequest> _cleaningRequests = [];
  Map<String, Property> _propertiesMap = {};

  // Добавляем поля для фильтрации
  CleaningType? _selectedCleaningType;
  DateTime? _selectedDate;
  double? _minPrice;
  double? _maxPrice;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);

    _loadCleaningRequests();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  /// Обработчик изменения вкладки
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  /// Загружает заявки на уборку
  Future<void> _loadCleaningRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Получаем ID пользователя
      final userId = authService.currentUser?.id;
      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }

      // Получаем заявки пользователя
      List<CleaningRequest> requests = await _cleaningService
          .getCleaningRequestsByOwnerId(userId);

      // Получаем данные об объектах недвижимости
      Map<String, Property> propertiesMap = {};

      // Собираем уникальные ID объектов
      Set<String> propertyIds = requests.map((r) => r.propertyId).toSet();

      // Загружаем данные для каждого объекта
      for (String propertyId in propertyIds) {
        final property = await _propertyService.getPropertyById(propertyId);
        if (property != null) {
          propertiesMap[propertyId] = property;
        }
      }

      setState(() {
        _cleaningRequests = requests;
        _propertiesMap = propertiesMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Показывает диалог создания новой заявки на уборку
  void _showCreateCleaningRequest() {
    context.pushNamed('create_cleaning_request');
  }

  /// Показывает диалог фильтрации
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Фильтрация заявок'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Фильтр по типу уборки
                    const Text(
                      'Тип уборки',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          CleaningType.values.map((type) {
                            final isSelected = _selectedCleaningType == type;
                            String label;
                            switch (type) {
                              case CleaningType.regular:
                                label = 'Стандартная';
                                break;
                              case CleaningType.general:
                                label = 'Генеральная';
                                break;
                              case CleaningType.postConstruction:
                                label = 'После ремонта';
                                break;
                              case CleaningType.afterGuests:
                                label = 'После гостей';
                                break;
                              default:
                                label = 'Другое';
                            }

                            return FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCleaningType = type;
                                  } else {
                                    _selectedCleaningType = null;
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Фильтр по дате
                    Row(
                      children: [
                        const Text(
                          'Дата: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? DateFormat(
                                  'dd.MM.yyyy',
                                ).format(_selectedDate!)
                                : 'Не выбрана',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedDate = date;
                              });
                            }
                          },
                        ),
                        if (_selectedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Фильтр по цене
                    const Text(
                      'Цена',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'От',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _minPrice = double.tryParse(value);
                              });
                            },
                            controller: TextEditingController(
                              text: _minPrice?.toString() ?? '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'До',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _maxPrice = double.tryParse(value);
                              });
                            },
                            controller: TextEditingController(
                              text: _maxPrice?.toString() ?? '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Сбрасываем все фильтры
                    this.setState(() {
                      _selectedCleaningType = null;
                      _selectedDate = null;
                      _minPrice = null;
                      _maxPrice = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Сбросить'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Обновляем UI с новыми фильтрами
                    this.setState(() {});
                  },
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Заявки на уборку'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Фильтры',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Все'),
              Tab(text: 'Активные'),
              Tab(text: 'В работе'),
              Tab(text: 'Завершенные'),
            ],
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorState(theme)
                : _buildContent(theme),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateCleaningRequest,
          backgroundColor: theme.colorScheme.primary,
          tooltip: 'Создать заявку на уборку',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Строит отображение ошибки
  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Произошла ошибка',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Неизвестная ошибка',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCleaningRequests,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Попробовать снова'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строит основное содержимое экрана
  Widget _buildContent(ThemeData theme) {
    // Фильтруем заявки в зависимости от выбранной вкладки
    final List<CleaningRequest> filteredRequests;

    switch (_tabController.index) {
      case 1: // Активные
        filteredRequests =
            _cleaningRequests
                .where(
                  (r) =>
                      r.status == CleaningRequestStatus.active ||
                      r.status == CleaningRequestStatus.withOffers ||
                      r.status == CleaningRequestStatus.accepted,
                )
                .toList();
        break;
      case 2: // В работе
        filteredRequests =
            _cleaningRequests
                .where((r) => r.status == CleaningRequestStatus.inProgress)
                .toList();
        break;
      case 3: // Завершенные
        filteredRequests =
            _cleaningRequests
                .where(
                  (r) =>
                      r.status == CleaningRequestStatus.completed ||
                      r.status == CleaningRequestStatus.cancelled,
                )
                .toList();
        break;
      case 0: // Все
      default:
        filteredRequests = _cleaningRequests;
        break;
    }

    // Если нет заявок
    if (filteredRequests.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Сортируем по дате (сначала новые)
    filteredRequests.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    return RefreshIndicator(
      onRefresh: _loadCleaningRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        itemCount: filteredRequests.length,
        itemBuilder: (context, index) {
          return _buildCleaningRequestCard(
            context,
            filteredRequests[index],
            theme,
          );
        },
      ),
    );
  }

  /// Строит состояние, когда нет заявок
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cleaning_services_outlined,
              size: 48, // Уменьшаем размер иконки
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'У вас пока нет заявок на уборку',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте новую заявку, нажав на кнопку "+" внизу экрана',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateCleaningRequest,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Создать заявку'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строит карточку заявки на уборку
  Widget _buildCleaningRequestCard(
    BuildContext context,
    CleaningRequest request,
    ThemeData theme,
  ) {
    // Получаем объект недвижимости
    final property = _propertiesMap[request.propertyId];

    // Форматирование даты
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'ru_RU');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1, // Уменьшаем тень
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок и статус
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Уборка: ${_getCleaningTypeText(request.cleaningType)}',
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(request.status, theme),
                ],
              ),

              const SizedBox(height: 12),

              // Информация об объекте
              if (property != null) ...[
                Text(
                  'Объект: ${property.title}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),
              ],

              // Адрес
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${request.address}, ${request.city}',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Дата и время
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(request.scheduledDate),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Цена
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${request.estimatedPrice.toInt()} ₽',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Кнопки действий
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Кнопка отмены (только для активных заявок)
                  if (request.status == CleaningRequestStatus.active ||
                      request.status == CleaningRequestStatus.withOffers ||
                      request.status == CleaningRequestStatus.accepted)
                    OutlinedButton(
                      onPressed: () => _showCancelDialog(request.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                        minimumSize: const Size(0, 36), // Уменьшаем высоту
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ), // Уменьшаем отступы
                      ),
                      child: Text(
                        'Отменить',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Кнопка просмотра деталей
                  ElevatedButton(
                    onPressed: () => _navigateToRequestDetails(request),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 36), // Уменьшаем высоту
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ), // Уменьшаем отступы
                    ),
                    child: Text(
                      'Подробнее',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строит чип статуса заявки
  Widget _buildStatusChip(CleaningRequestStatus status, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(status), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 12,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 4),
          Text(
            _getStatusText(status),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Возвращает цвет статуса заявки
  Color _getStatusColor(CleaningRequestStatus status) {
    switch (status) {
      case CleaningRequestStatus.pendingApproval:
        return Colors.amber;
      case CleaningRequestStatus.active:
        return Colors.green;
      case CleaningRequestStatus.withOffers:
        return Colors.blue;
      case CleaningRequestStatus.accepted:
        return Colors.orange;
      case CleaningRequestStatus.inProgress:
        return Colors.purple;
      case CleaningRequestStatus.completed:
        return Colors.teal;
      case CleaningRequestStatus.cancelled:
        return Colors.red;
      case CleaningRequestStatus.pending:
        return Colors.amber;
      case CleaningRequestStatus.waitingCleaner:
        return Colors.amber;
      case CleaningRequestStatus.approved:
        return Colors.green;
      case CleaningRequestStatus.assigned:
        return Colors.blue;
      case CleaningRequestStatus.rejected:
        return Colors.red;
    }
  }

  /// Возвращает текст статуса заявки
  String _getStatusText(CleaningRequestStatus status) {
    switch (status) {
      case CleaningRequestStatus.pendingApproval:
        return 'Ожидает подтверждения';
      case CleaningRequestStatus.active:
        return 'Активная';
      case CleaningRequestStatus.withOffers:
        return 'Есть предложения';
      case CleaningRequestStatus.accepted:
        return 'Принята';
      case CleaningRequestStatus.inProgress:
        return 'В процессе';
      case CleaningRequestStatus.completed:
        return 'Завершена';
      case CleaningRequestStatus.cancelled:
        return 'Отменена';
      case CleaningRequestStatus.pending:
        return 'Ожидает';
      case CleaningRequestStatus.waitingCleaner:
        return 'Ожидает клинера';
      case CleaningRequestStatus.approved:
        return 'Подтверждена';
      case CleaningRequestStatus.assigned:
        return 'Назначена';
      case CleaningRequestStatus.rejected:
        return 'Отклонена';
    }
  }

  /// Возвращает иконку статуса заявки
  IconData _getStatusIcon(CleaningRequestStatus status) {
    switch (status) {
      case CleaningRequestStatus.pendingApproval:
        return Icons.approval;
      case CleaningRequestStatus.active:
        return Icons.access_time;
      case CleaningRequestStatus.withOffers:
        return Icons.people;
      case CleaningRequestStatus.accepted:
        return Icons.check_circle;
      case CleaningRequestStatus.inProgress:
        return Icons.cleaning_services;
      case CleaningRequestStatus.completed:
        return Icons.done_all;
      case CleaningRequestStatus.cancelled:
        return Icons.cancel;
      case CleaningRequestStatus.pending:
        return Icons.hourglass_empty;
      case CleaningRequestStatus.waitingCleaner:
        return Icons.person_search;
      case CleaningRequestStatus.approved:
        return Icons.verified;
      case CleaningRequestStatus.assigned:
        return Icons.assignment_ind;
      case CleaningRequestStatus.rejected:
        return Icons.block;
    }
  }

  /// Возвращает текст типа уборки
  String _getCleaningTypeText(CleaningType type) {
    switch (type) {
      case CleaningType.basic:
        return 'Базовая';
      case CleaningType.deep:
        return 'Глубокая';
      case CleaningType.postConstruction2:
        return 'Уборка после ремонта';
      case CleaningType.window:
        return 'Окна';
      case CleaningType.carpet:
        return 'Ковры';
      case CleaningType.regular:
        return 'Обычная';
      case CleaningType.general:
        return 'Генеральная';
      case CleaningType.postConstruction:
        return 'После ремонта';
      case CleaningType.afterGuests:
        return 'После гостей';
    }
  }

  /// Показывает диалог подтверждения отмены заявки
  void _showCancelDialog(String requestId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отменить заявку?'),
            content: const Text(
              'Вы уверены, что хотите отменить эту заявку на уборку? Это действие нельзя будет отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  context.pop();
                  _cancelCleaningRequest(requestId);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Да, отменить'),
              ),
            ],
          ),
    );
  }

  void _navigateToRequestDetails(CleaningRequest request) {
    context.pushNamed(
      'cleaning_request_details',
      pathParameters: {'id': request.id.toString()},
    );
  }

  /// Отменяет заявку на уборку
  Future<void> _cancelCleaningRequest(String requestId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _cleaningService.cancelCleaning(requestId, 'Отменено владельцем');

      // Перезагружаем список заявок
      await _loadCleaningRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заявка успешно отменена')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
