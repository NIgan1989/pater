import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/cleaning_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/datasources/user_service.dart';
import 'package:pater/domain/entities/cleaning_request.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/presentation/widgets/common/app_button.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Экран деталей заявки на уборку
class CleaningRequestDetailsScreen extends StatefulWidget {
  /// Идентификатор заявки на уборку
  final String requestId;

  const CleaningRequestDetailsScreen({super.key, required this.requestId});

  @override
  State<CleaningRequestDetailsScreen> createState() =>
      _CleaningRequestDetailsScreenState();
}

class _CleaningRequestDetailsScreenState
    extends State<CleaningRequestDetailsScreen> {
  final _cleaningService = CleaningService();
  final _propertyService = PropertyService();
  final _userService = UserService();

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;

  CleaningRequest? _request;
  Property? _property;
  User? _cleaner;
  User? _owner;

  // Список предложений от клинеров (в случае активной заявки)
  final List<Map<String, dynamic>> _cleanerOffers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Загружает данные заявки
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Получаем заявку по ID
      final request = await _cleaningService.getCleaningRequestById(
        widget.requestId,
      );

      if (request == null) {
        setState(() {
          _errorMessage = 'Заявка не найдена';
          _isLoading = false;
        });
        return;
      }

      // Получаем данные о собственнике
      User? owner;
      owner = await _userService.getUserById(request.ownerId);

      // Если заявка принята клинером, получаем данные о клинере
      User? cleaner;
      if (request.cleanerId != null) {
        cleaner = await _userService.getUserById(request.cleanerId!);
      }

      // Получаем данные о объекте недвижимости
      Property? property;
      try {
        property = await _propertyService.getPropertyById(request.propertyId);
      } catch (e) {
        debugPrint('Ошибка при загрузке объекта недвижимости: $e');
      }

      setState(() {
        _request = request;
        _owner = owner;
        _cleaner = cleaner;
        _property = property;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при загрузке данных: $e';
        _isLoading = false;
      });
    }
  }

  /// Отменяет заявку на уборку
  Future<void> _cancelRequest() async {
    setState(() {
      _isActionLoading = true;
    });

    try {
      await _cleaningService.cancelCleaning(
        widget.requestId,
        'Отменено пользователем',
      );

      // Обновляем данные заявки
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка успешно отменена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isActionLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отмене заявки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Принимает предложение клинера
  Future<void> _acceptOffer(String offerId, String cleanerId) async {
    setState(() {
      _isActionLoading = true;
    });

    try {
      await _cleaningService.acceptOffer(widget.requestId, offerId);

      // Обновляем данные заявки
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Предложение принято'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isActionLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при принятии предложения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Открывает диалог подтверждения отмены заявки
  void _showCancelDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Отменить заявку?'),
            content: const Text(
              'Вы уверены, что хотите отменить заявку на уборку? '
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
                  _cancelRequest();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Да, отменить'),
              ),
            ],
          ),
    );
  }

  /// Открывает диалог подтверждения принятия предложения
  void _showAcceptOfferDialog(CleaningOffer offer) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Принять предложение?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Клинер: ${offer.cleanerName}'),
                Text('Стоимость: ${offer.price} ₽'),
                const SizedBox(height: AppConstants.paddingM),
                const Text(
                  'После принятия предложения статус заявки изменится на "Принята", '
                  'и клинер будет назначен для выполнения уборки.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  context.pop();
                  _acceptOffer(offer.id, offer.cleanerId);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: const Text('Принять'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали заявки'),
        centerTitle: true,
        actions: [
          // Показываем кнопку отмены, если заявка активная
          if (_request != null &&
              ((_request!.status == CleaningRequestStatus.active ||
                      _request!.status == CleaningRequestStatus.withOffers) &&
                  _cleanerOffers.isNotEmpty)) ...[
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Отменить заявку',
              onPressed: _isActionLoading ? null : _showCancelDialog,
            ),
          ],
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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

  /// Строит отображение ошибки
  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: AppConstants.paddingL),
            Text(
              'Произошла ошибка',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingM),
            Text(
              _errorMessage ?? 'Неизвестная ошибка',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingL),
            AppButton.primary(
              text: 'Попробовать снова',
              onPressed: _loadData,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  /// Строит основной контент экрана
  Widget _buildContent(ThemeData theme) {
    // Форматирование даты
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'ru_RU');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Статус заявки
            _buildRequestStatusInfo(),

            const SizedBox(height: AppConstants.paddingM),

            // Общая информация о заявке
            _buildRequestGeneralInfo(theme, dateFormat),

            const SizedBox(height: AppConstants.paddingM),

            // Информация о владельце
            _buildOwnerInfo(theme),

            const SizedBox(height: AppConstants.paddingM),

            // Информация об объекте
            if (_property != null) _buildPropertyInfo(theme),

            const SizedBox(height: AppConstants.paddingM),

            // Информация о клинере, если назначен
            if (_cleaner != null) _buildCleanerInfo(theme),

            // Предложения от клинеров, если есть и заявка активна
            if (_request!.status == CleaningRequestStatus.active ||
                _request!.status == CleaningRequestStatus.withOffers) ...[
              if (_cleanerOffers.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingL),
                _buildCleanerOffers(theme),
              ] else ...[
                const SizedBox(height: AppConstants.paddingL),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingM),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingM),
                        const Text(
                          'Пока нет предложений от клинеров',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppConstants.paddingS),
                        const Text(
                          'Клинеры увидят вашу заявку и скоро откликнутся на нее',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Строит статус заявки
  Widget _buildRequestStatusInfo() {
    // Определяем цвет и текст статуса
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_request!.status) {
      case CleaningRequestStatus.pendingApproval:
        statusColor = Colors.amber;
        statusText = 'Ожидает подтверждения';
        statusIcon = Icons.approval;
        break;
      case CleaningRequestStatus.active:
        statusColor = Colors.green;
        statusText = 'Активная заявка';
        statusIcon = Icons.access_time;
        break;
      case CleaningRequestStatus.withOffers:
        statusColor = Colors.blue;
        statusText = 'Есть предложения';
        statusIcon = Icons.list_alt;
        break;
      case CleaningRequestStatus.accepted:
        statusColor = Colors.orange;
        statusText = 'Принята клинером';
        statusIcon = Icons.check_circle_outline;
        break;
      case CleaningRequestStatus.inProgress:
        statusColor = Colors.purple;
        statusText = 'В процессе';
        statusIcon = Icons.engineering;
        break;
      case CleaningRequestStatus.completed:
        statusColor = Colors.teal;
        statusText = 'Завершена';
        statusIcon = Icons.done_all;
        break;
      case CleaningRequestStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Отменена';
        statusIcon = Icons.cancel;
        break;
      case CleaningRequestStatus.pending:
        statusColor = Colors.amber;
        statusText = 'Ожидает';
        statusIcon = Icons.hourglass_empty;
        break;
      case CleaningRequestStatus.waitingCleaner:
        statusColor = Colors.amber;
        statusText = 'Ожидает клинера';
        statusIcon = Icons.person_search;
        break;
      case CleaningRequestStatus.approved:
        statusColor = Colors.green;
        statusText = 'Подтверждена';
        statusIcon = Icons.verified;
        break;
      case CleaningRequestStatus.assigned:
        statusColor = Colors.blue;
        statusText = 'Назначена';
        statusIcon = Icons.assignment_ind;
        break;
      case CleaningRequestStatus.rejected:
        statusColor = Colors.red;
        statusText = 'Отклонена';
        statusIcon = Icons.block;
        break;
    }

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        side: BorderSide(color: statusColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: AppConstants.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  if (_request!.status == CleaningRequestStatus.active)
                    Text(
                      'Ожидает откликов от клинеров',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    )
                  else if (_request!.status == CleaningRequestStatus.withOffers)
                    Text(
                      'Выберите подходящее предложение',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    )
                  else if (_request!.status == CleaningRequestStatus.accepted)
                    Text(
                      'Клинер скоро приступит к работе',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    )
                  else
                    Text(
                      'Статус заявки обновлен',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
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

  /// Строит информацию о заявке
  Widget _buildRequestGeneralInfo(ThemeData theme, DateFormat dateFormat) {
    // Получаем текст для типа уборки
    String typeText = _getCleaningTypeText(_request!.cleaningType);

    // Получаем текст для срочности
    String urgencyText = _getUrgencyText(_request!.urgency);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Информация о заявке',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.paddingM),

            // Тип уборки
            _buildInfoRow(
              theme,
              label: 'Тип уборки',
              value: typeText,
              icon: Icons.cleaning_services,
            ),

            const SizedBox(height: AppConstants.paddingM),

            // Срочность
            _buildInfoRow(
              theme,
              label: 'Срочность',
              value: urgencyText,
              icon: Icons.alarm,
            ),

            const SizedBox(height: AppConstants.paddingM),

            // Дата и время
            _buildInfoRow(
              theme,
              label: 'Дата и время',
              value: dateFormat.format(_request!.scheduledDate),
              icon: Icons.calendar_today,
            ),

            const SizedBox(height: AppConstants.paddingM),

            // Стоимость
            _buildInfoRow(
              theme,
              label: 'Стоимость',
              value: '${_request!.estimatedPrice.toInt()} ₽',
              icon: Icons.attach_money,
              isHighlighted: true,
            ),

            // Дополнительные услуги
            if (_request!.additionalServices.isNotEmpty) ...[
              const SizedBox(height: AppConstants.paddingM),
              const Text(
                'Дополнительные услуги:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppConstants.paddingS),
              Wrap(
                spacing: AppConstants.paddingS,
                runSpacing: AppConstants.paddingXS,
                children:
                    _request!.additionalServices.map((service) {
                      return Chip(
                        label: Text(service, style: theme.textTheme.bodySmall),
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
              ),
            ],

            const SizedBox(height: AppConstants.paddingM),

            // Комментарий
            Text(
              'Комментарий:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppConstants.paddingXS),
            Text(_request!.description, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  /// Возвращает текстовое представление типа уборки
  String _getCleaningTypeText(CleaningType type) {
    switch (type) {
      case CleaningType.basic:
        return 'Базовая уборка';
      case CleaningType.deep:
        return 'Генеральная уборка';
      case CleaningType.postConstruction2:
        return 'Уборка после ремонта';
      case CleaningType.window:
        return 'Мытьё окон';
      case CleaningType.carpet:
        return 'Чистка ковров';
      case CleaningType.regular:
        return 'Обычная уборка';
      case CleaningType.general:
        return 'Генеральная уборка';
      case CleaningType.postConstruction:
        return 'Уборка после ремонта';
      case CleaningType.afterGuests:
        return 'После выезда гостей';
    }
  }

  /// Возвращает текстовое представление срочности
  String _getUrgencyText(CleaningUrgency urgency) {
    switch (urgency) {
      case CleaningUrgency.low:
        return 'Обычная (в течение недели)';
      case CleaningUrgency.medium:
        return 'Средняя (в течение 3-4 дней)';
      case CleaningUrgency.high:
        return 'Высокая (в течение 1-2 дней)';
      case CleaningUrgency.urgent:
        return 'Срочная (в течение 24 часов)';
    }
  }

  /// Строит строку информации
  Widget _buildInfoRow(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppConstants.paddingXS),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 18),
        ),
        const SizedBox(width: AppConstants.paddingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                value,
                style:
                    isHighlighted
                        ? theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        )
                        : theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Строит информацию об объекте недвижимости
  Widget _buildPropertyInfo(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: InkWell(
        onTap: () {
          // Переход к детальной информации об объекте
          context.pushNamed(
            'property_details',
            pathParameters: {'id': _property!.id.toString()},
            extra: _property,
          );
        },
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Объект недвижимости',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.paddingM),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Изображение объекта
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                      image:
                          _property!.imageUrls.isNotEmpty
                              ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  _property!.imageUrls.first,
                                ),
                                fit: BoxFit.cover,
                              )
                              : null,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child:
                        _property!.imageUrls.isEmpty
                            ? Icon(
                              Icons.home,
                              color: theme.colorScheme.primary,
                              size: 32,
                            )
                            : null,
                  ),
                  const SizedBox(width: AppConstants.paddingM),

                  // Информация об объекте
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _property!.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppConstants.paddingXS),
                        Text(
                          _property!.address,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppConstants.paddingXS),
                        Text(
                          '${_property!.area} м² • ${_property!.rooms} комн.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingS),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    context.pushNamed(
                      'property_details',
                      pathParameters: {'id': _property!.id.toString()},
                      extra: _property,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Подробнее'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строит информацию о клинере
  Widget _buildCleanerInfo(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Клинер',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.paddingM),
            Row(
              children: [
                // Аватар клинера
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      _cleaner?.avatarUrl != null &&
                              _cleaner?.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(_cleaner?.avatarUrl ?? '')
                          : null,
                  child:
                      _cleaner?.avatarUrl == null ||
                              _cleaner?.avatarUrl?.isEmpty == true
                          ? const Icon(Icons.person, size: 30)
                          : null,
                ),
                const SizedBox(width: AppConstants.paddingM),

                // Информация о клинере
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_cleaner!.firstName} ${_cleaner!.lastName}',
                        style: theme.textTheme.titleMedium,
                      ),
                      if (_cleaner!.rating > 0) ...[
                        const SizedBox(height: AppConstants.paddingXS),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_cleaner!.rating.toStringAsFixed(1)} (${_cleaner!.reviewsCount} отзывов)',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppConstants.paddingXS),
                      if (_request!.status ==
                              CleaningRequestStatus.inProgress ||
                          _request!.status == CleaningRequestStatus.accepted)
                        TextButton.icon(
                          onPressed: () {
                            // Переходим в чат с клинером
                            context.pushNamed(
                              'chat',
                              pathParameters: {'chatId': _cleaner!.id},
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Написать сообщение'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Строит список предложений от клинеров
  Widget _buildCleanerOffers(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Предложения от клинеров',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingS),
        Text(
          'Выберите клинера для выполнения уборки',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppConstants.paddingM),
        ...List.generate(
          _cleanerOffers.length,
          (index) => _buildCleanerOfferCard(theme, _cleanerOffers[index]),
        ),
      ],
    );
  }

  /// Строит карточку предложения от клинера
  Widget _buildCleanerOfferCard(ThemeData theme, Map<String, dynamic> offer) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информация о клинере
            Row(
              children: [
                // Аватар клинера
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      offer['cleaner_avatar'] != null
                          ? NetworkImage(offer['cleaner_avatar'])
                          : null,
                  child:
                      offer['cleaner_avatar'] == null
                          ? const Icon(Icons.person, size: 24)
                          : null,
                ),
                const SizedBox(width: AppConstants.paddingM),

                // Имя и рейтинг клинера
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer['cleaner_name'],
                        style: theme.textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${offer['cleaner_rating'].toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Цена
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${offer['price']} ₽',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (offer['price'] < _request!.estimatedPrice)
                      Text(
                        'Скидка ${(_request!.estimatedPrice - offer['price']).toInt()} ₽',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingM),

            // Комментарий клинера
            if (offer['comment'] != null && offer['comment'].isNotEmpty) ...[
              Text(
                'Комментарий:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppConstants.paddingXS),
              Text(offer['comment'], style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppConstants.paddingM),
            ],

            // Кнопка принятия предложения
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed:
                    _isActionLoading
                        ? null
                        : () => _showAcceptOfferDialog(
                          CleaningOffer(
                            id: offer['id'],
                            cleanerId: offer['cleaner_id'],
                            cleanerName: offer['cleaner_name'],
                            price: (offer['price'] as num).toDouble(),
                            message: offer['comment'],
                            status: offer['status'],
                            createdAt: DateTime.parse(offer['created_at']),
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: const Text('Выбрать клинера'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Строит информацию о владельце объекта
  Widget _buildOwnerInfo(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      _owner?.avatarUrl != null
                          ? NetworkImage(_owner!.avatarUrl!)
                          : null,
                  child:
                      _owner?.avatarUrl == null
                          ? const Icon(Icons.person)
                          : null,
                ),
                const SizedBox(width: AppConstants.paddingM),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _owner?.fullName ?? 'Владелец',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Владелец', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
