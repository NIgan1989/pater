import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/presentation/widgets/map/property_map.dart';
import 'package:pater/core/theme/app_text_styles.dart';

/// Экран отображения подробной информации о жилье
class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;
  final Property? property; // Объект может быть передан извне

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
    this.property,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final PropertyService _propertyService = PropertyService();
  Property? _property;
  bool _isLoading = true;
  bool _isFavorite = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Подробное логирование для отладки
    debugPrint('PropertyDetailsScreen: Инициализация экрана');
    debugPrint('PropertyDetailsScreen: ID объекта: ${widget.propertyId}');
    debugPrint(
      'PropertyDetailsScreen: Объект передан: ${widget.property != null}',
    );

    if (widget.property != null) {
      debugPrint(
        'PropertyDetailsScreen: Используем переданный объект: ${widget.property!.title}',
      );
      _property = widget.property;
      _isLoading = false;
      _checkFavoriteStatus(); // Проверяем статус избранного
    } else {
      // Иначе загружаем данные объекта по ID
      debugPrint('PropertyDetailsScreen: Загрузка данных объекта по ID');
      _loadPropertyDetails();
    }
  }

  /// Проверяет, находится ли объект в избранном
  Future<void> _checkFavoriteStatus() async {
    if (_property == null) return;

    final authService = AuthService();
    if (authService.currentUser == null) return;

    try {
      final propertyService = PropertyService();
      _isFavorite = await propertyService.isPropertyInFavorites(
        authService.currentUser!.id,
        _property!.id,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Ошибка при проверке статуса избранного: $e');
    }
  }

  /// Загружает детали объекта по ID
  Future<void> _loadPropertyDetails() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      debugPrint(
        'PropertyDetailsScreen: Запрос данных объекта с ID: ${widget.propertyId}',
      );
      final property = await _propertyService.getPropertyById(
        widget.propertyId,
      );

      if (property == null) {
        debugPrint(
          'PropertyDetailsScreen: Объект с ID ${widget.propertyId} не найден!',
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Объект не найден. Пожалуйста, вернитесь назад и попробуйте еще раз.';
          });
        }
        return;
      }

      debugPrint(
        'PropertyDetailsScreen: Объект успешно загружен: ${property.title}',
      );

      if (mounted) {
        setState(() {
          _property = property;
          _isLoading = false;
          _errorMessage = null;
        });
      }

      // Проверяем статус избранного
      _checkFavoriteStatus();
    } catch (e) {
      debugPrint('PropertyDetailsScreen: Ошибка загрузки данных объекта: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка загрузки данных: $e';
        });
      }
    }
  }

  /// Обновляет данные об объекте
  Future<void> _refreshPropertyDetails() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Очищаем кэш изображения перед обновлением
      if (_property != null) {
        // Очищаем кэш основного изображения, если оно есть
        if (_property!.imageUrls.isNotEmpty) {
          for (var url in _property!.imageUrls) {
            await CachedNetworkImage.evictFromCache(url);
          }
        }
      }

      final property = await _propertyService.getPropertyById(
        widget.propertyId,
      );
      if (mounted) {
        setState(() {
          _property = property;
          _isLoading = false;
          _errorMessage = null;
        });

        // Показываем сообщение об успешном обновлении
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Информация об объекте обновлена'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Проверяем статус избранного
      _checkFavoriteStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Ошибка загрузки данных: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Обрабатывает добавление/удаление из избранного
  Future<void> _toggleFavorite() async {
    final authService = AuthService();

    // Если пользователь не авторизован, перенаправляем на экран входа
    if (authService.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Войдите в аккаунт, чтобы добавить в избранное'),
          ),
        );

        // Перенаправляем на экран входа
        context.push('/auth');
      }
      return;
    }

    // Показываем индикатор загрузки в SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _isFavorite
                    ? 'Удаляем из избранного...'
                    : 'Добавляем в избранное...',
              ),
            ],
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final propertyService = PropertyService();

      // Меняем состояние избранного
      final newFavoriteState = !_isFavorite;

      if (mounted) {
        setState(() {
          _isFavorite = newFavoriteState;
        });
      }

      if (newFavoriteState) {
        await propertyService.addToFavorites(
          authService.currentUser!.id,
          _property!.id,
        );
      } else {
        await propertyService.removeFromFavorites(
          authService.currentUser!.id,
          _property!.id,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newFavoriteState
                  ? 'Объект добавлен в избранное'
                  : 'Объект удален из избранного',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // При ошибке возвращаем предыдущее состояние
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1000;

    return Scaffold(
      body:
          _isLoading
              ? _buildLoadingView()
              : (_property == null)
              ? _buildErrorView()
              : _buildPropertyView(theme, isDesktop),
    );
  }

  Widget _buildLoadingView() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildErrorView() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Переходим на экран поиска вместо возврата назад
            context.go('/search');
          },
        ),
        title: const Text('Ошибка'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Произошла неизвестная ошибка',
              textAlign: TextAlign.center,
              style: AppTextStyles.errorText(context),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadPropertyDetails(),
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyView(ThemeData theme, bool isDesktop) {
    // Проверка на null перед использованием _property
    if (_property == null) {
      return _buildErrorView();
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              leading: Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 179),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    try {
                      context.pop();
                    } catch (e) {
                      debugPrint('Ошибка при возврате: $e');
                      context.go('/search');
                    }
                  },
                ),
              ),
              expandedHeight: 250,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: CachedNetworkImage(
                  imageUrl:
                      _property!.imageUrls.isNotEmpty
                          ? _property!.imageUrls.first
                          : 'https://via.placeholder.com/800x600?text=Изображение+недоступно',
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey[300]!.withValues(alpha: 179),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey[300]!.withValues(alpha: 179),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Не удалось загрузить изображение',
                              style: AppTextStyles.errorText(context),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                // Обновляем данные объекта
                                _refreshPropertyDetails();
                              },
                              child: const Text('Обновить'),
                            ),
                          ],
                        ),
                      ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 204),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    color: _isFavorite ? Colors.red : Colors.black87,
                    onPressed: _toggleFavorite,
                  ),
                ),
              ],
            ),

            // Основное содержимое
            SliverPadding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Заголовок и рейтинг
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _property!.title,
                          style: AppTextStyles.propertyTitle(context),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _property!.rating.toString(),
                            style: AppTextStyles.priceText(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingS),

                  // Тип жилья и адрес
                  Row(
                    children: [
                      _buildPropertyType(theme),
                      const SizedBox(width: AppConstants.paddingS),
                      Expanded(
                        child: Text(
                          _property!.address,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.paddingM),

                  // Характеристики жилья
                  _buildFeaturesSection(theme),
                  const SizedBox(height: AppConstants.paddingM),

                  // Описание
                  Text('Описание', style: AppTextStyles.heading3(context)),
                  const SizedBox(height: AppConstants.paddingS),
                  Text(
                    _property!.description,
                    style: AppTextStyles.propertyDescription(context),
                  ),
                  const SizedBox(height: AppConstants.paddingM),

                  // Расположение
                  Text('Расположение', style: AppTextStyles.heading3(context)),
                  const SizedBox(height: AppConstants.paddingM),
                  // Проверяем, есть ли корректные координаты для отображения карты
                  _hasValidCoordinates()
                      ? // Контейнер для карты с единообразным отображением
                      Container(
                        height: 250, // Увеличиваем высоту карты
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusM,
                          ),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 66,
                            ),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // Используем PropertyMap как единый компонент для всего приложения
                            PropertyMap(
                              properties: [_property!],
                              initialLocation: LatLng(
                                _property!.latitude,
                                _property!.longitude,
                              ),
                              initialZoom: 14.0,
                              onMarkerTap: (_) {},
                              enableClustering: false,
                              showLocationButton: false,
                              showUserLocation: false,
                            ),
                            // Кнопка для открытия карты на полный экран
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: FloatingActionButton.small(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder:
                                        (context) => Container(
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.9,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(
                                                AppConstants.radiusL,
                                              ),
                                              topRight: Radius.circular(
                                                AppConstants.radiusL,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              // Заголовок
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  AppConstants.paddingM,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Местоположение',
                                                      style:
                                                          theme
                                                              .textTheme
                                                              .titleLarge,
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                      ),
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Информация об адресе
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal:
                                                          AppConstants.paddingM,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${_property!.address}, ${_property!.city}, ${_property!.country}',
                                                      style:
                                                          theme
                                                              .textTheme
                                                              .bodyMedium,
                                                    ),
                                                    const SizedBox(
                                                      height:
                                                          AppConstants.paddingS,
                                                    ),
                                                    Text(
                                                      'Координаты: ${_property!.latitude.toStringAsFixed(6)}, ${_property!.longitude.toStringAsFixed(6)}',
                                                      style:
                                                          theme
                                                              .textTheme
                                                              .bodySmall,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Divider(),
                                              // Карта на полный экран
                                              Expanded(
                                                child: PropertyMap(
                                                  properties: [_property!],
                                                  initialLocation: LatLng(
                                                    _property!.latitude,
                                                    _property!.longitude,
                                                  ),
                                                  initialZoom: 14.0,
                                                  onMarkerTap: (_) {},
                                                  enableClustering: false,
                                                  showLocationButton: true,
                                                  showUserLocation: true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  );
                                },
                                backgroundColor: Colors.white,
                                child: const Icon(Icons.fullscreen),
                              ),
                            ),
                          ],
                        ),
                      )
                      : // Если координаты отсутствуют, показываем текстовую информацию
                      Container(
                        padding: const EdgeInsets.all(AppConstants.paddingM),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusM,
                          ),
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 66,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Адрес:', style: theme.textTheme.titleSmall),
                            const SizedBox(height: AppConstants.paddingXS),
                            Text(
                              '${_property!.address}, ${_property!.city}, ${_property!.country}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppConstants.paddingS),
                            Text(
                              'Точное местоположение на карте недоступно',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: AppConstants.paddingL),

                  // Дополнительный отступ снизу для предотвращения перекрытия нижней панелью
                  SizedBox(height: 80), // Отступ под панелью бронирования
                ]),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBookingBar(theme, isDesktop),
        ),
      ],
    );
  }

  /// Строит секцию с характеристиками жилья
  Widget _buildFeaturesSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 66),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildFeatureItem(
                theme,
                Icons.person_outline,
                'Гостей',
                (_property != null) ? _property!.maxGuests.toString() : '0',
              ),
              _buildFeatureItem(
                theme,
                Icons.meeting_room_outlined,
                'Комнат',
                (_property != null) ? _property!.rooms.toString() : '0',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingM),
          Row(
            children: [
              _buildFeatureItem(
                theme,
                Icons.king_bed_outlined,
                'Спален',
                // Используем количество комнат, если нет отдельного поля для спален
                (_property != null) ? _property!.rooms.toString() : '0',
              ),
              _buildFeatureItem(
                theme,
                Icons.bathtub_outlined,
                'Ванных',
                (_property != null) ? _property!.bathrooms.toString() : '0',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Строит элемент характеристики жилья
  Widget _buildFeatureItem(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingS),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppConstants.paddingS),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.propertyFeature(context)),
              Text(value, style: AppTextStyles.propertyTitle(context)),
            ],
          ),
        ],
      ),
    );
  }

  /// Строит нижнюю панель с ценой и кнопкой бронирования
  Widget _buildBookingBar(ThemeData theme, bool isDesktop) {
    // Получаем текущего пользователя
    final authService = AuthService();
    final currentUser = authService.currentUser;

    // Проверяем, является ли текущий пользователь владельцем этого объекта
    final isPropertyOwner =
        currentUser != null &&
        _property != null &&
        currentUser.id == _property!.ownerId;

    // Для владельца объекта показываем кнопки редактирования и архивации
    if (isPropertyOwner) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 51),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: Tooltip(
                message: 'Редактировать объявление',
                child: ElevatedButton.icon(
                  onPressed: () {
                    debugPrint(
                      'Нажата кнопка редактирования, ID объекта: ${_property!.id}',
                    );
                    context.pushNamed(
                      'edit_property',
                      pathParameters: {'id': _property!.id},
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Редактировать'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Tooltip(
                message: 'Архивировать объявление',
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Показываем диалог подтверждения
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Архивировать объявление?'),
                            content: const Text(
                              'Архивированные объявления не будут видны в поиске. '
                              'Вы сможете активировать их позже.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Отмена'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Архивируем и возвращаемся
                                  _archiveProperty();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Архивировать'),
                              ),
                            ],
                          ),
                    );
                  },
                  icon: const Icon(Icons.archive),
                  label: const Text('В архив'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Для всех остальных пользователей, включая владельца, просматривающего чужие объявления
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 51),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatPrice(_property!.pricePerNight)} ₸',
                style: AppTextStyles.priceText(context),
              ),
              Text(
                'за ночь',
                style: AppTextStyles.bodySmall(
                  context,
                ).copyWith(color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(width: AppConstants.paddingM),

          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Если пользователь не авторизован, перенаправляем на экран входа
                if (currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Войдите в аккаунт, чтобы забронировать'),
                    ),
                  );
                  context.push('/auth');
                  return;
                }

                // Перенаправляем на экран бронирования
                context.push('/booking/${_property!.id}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
              ),
              child: Text(
                'Забронировать',
                style: AppTextStyles.buttonText(
                  context,
                ).copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Архивирует объявление
  Future<void> _archiveProperty() async {
    if (_property == null) return;

    try {
      // Создаем обновленный объект с isActive = false
      final updatedProperty = _property!.copyWith(isActive: false);

      // Обновляем свойство в базе данных
      await _propertyService.updateProperty(updatedProperty);

      // Показываем сообщение
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление архивировано')),
        );

        // Возвращаемся к списку объявлений
        context.pop();
      }
    } catch (e) {
      // Показываем ошибку
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: ${e.toString()}')));
      }
    }
  }

  /// Строит блок с типом жилья
  Widget _buildPropertyType(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getPropertyTypeText(_property?.type),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Получает текстовое представление типа недвижимости
  String _getPropertyTypeText(dynamic type) {
    // Если тип уже является строкой - используем её напрямую
    if (type is String) {
      switch (type) {
        case 'PropertyType.apartment':
        case 'apartment':
          return 'Квартира';
        case 'PropertyType.house':
        case 'house':
          return 'Дом';
        case 'PropertyType.hostel':
        case 'hostel':
          return 'Хостел';
        case 'PropertyType.room':
        case 'room':
          return 'Комната';
        case 'hotel':
          return 'Отель';
        case 'villa':
          return 'Вилла';
        default:
          return 'Другое';
      }
    }
    // Если это перечисление PropertyType
    else if (type is PropertyType) {
      switch (type) {
        case PropertyType.apartment:
          return 'Квартира';
        case PropertyType.house:
          return 'Дом';
        case PropertyType.hostel:
          return 'Хостел';
        case PropertyType.room:
          return 'Комната';
      }
    }
    // Во всех остальных случаях возвращаем значение по умолчанию
    return 'Другое';
  }

  /// Форматирует цену в удобочитаемом виде
  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  /// Проверяет, есть ли у объекта валидные координаты для отображения на карте
  bool _hasValidCoordinates() {
    if (_property == null) return false;
    return _property!.latitude != 0 &&
        _property!.longitude != 0 &&
        _property!.latitude.isFinite &&
        _property!.longitude.isFinite;
  }
}
