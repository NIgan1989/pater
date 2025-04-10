import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/presentation/screens/property/property_details_screen.dart';

/// Карточка объекта недвижимости для отображения в списке
class PropertyCard extends StatefulWidget {
  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isFavorite;
  final Function(bool)? onFavoriteToggle;

  /// Виджет с дополнительной информацией (статус, подстатус и т.д.)
  final Widget? additionalInfo;

  /// Определяет, можно ли нажимать на карточку для перехода на детальный просмотр
  final bool isClickable;

  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.onLongPress,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.additionalInfo,
    this.isClickable = true,
  });

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  late bool _isFavorite;
  final PropertyService _propertyService = PropertyService();

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
  }

  @override
  void didUpdateWidget(PropertyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем состояние если изменилось свойство isFavorite
    if (oldWidget.isFavorite != widget.isFavorite) {
      setState(() {
        _isFavorite = widget.isFavorite;
      });
    }
  }

  /// Обрабатывает нажатие на иконку избранного
  Future<void> _handleFavoriteToggle() async {
    // Проверяем, что виджет всё ещё монтирован перед началом операции
    if (!mounted) return;

    final authService = AuthService();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Если пользователь не авторизован, перенаправляем на экран входа
    if (authService.currentUser == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Войдите в аккаунт, чтобы добавить в избранное'),
          duration: Duration(seconds: 2),
        ),
      );

      // Перенаправляем на экран входа
      context.push('/auth');
      return;
    }

    try {
      // Обновляем локальное состояние перед запросом
      setState(() {
        _isFavorite = !_isFavorite;
      });

      // Сохраняем окончательное состояние для использования в асинхронных операциях
      final newFavoriteState = _isFavorite;

      // Показываем индикатор загрузки
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  newFavoriteState
                      ? 'Добавляем в избранное...'
                      : 'Удаляем из избранного...',
                ),
              ],
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // Выполняем операцию с избранным
      if (newFavoriteState) {
        await _propertyService.addToFavorites(
          authService.currentUser!.id,
          widget.property.id,
        );

        // Показываем уведомление об успешном добавлении
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Объект добавлен в избранное'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _propertyService.removeFromFavorites(
          authService.currentUser!.id,
          widget.property.id,
        );

        // Показываем уведомление об успешном удалении
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Объект удален из избранного'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Уведомляем родительский виджет об изменении (если есть callback)
      if (mounted && widget.onFavoriteToggle != null) {
        widget.onFavoriteToggle!(newFavoriteState);
      }
    } catch (e) {
      // В случае ошибки возвращаем предыдущее состояние
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
        });

        // Показываем ошибку
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Обрабатывает нажатие на карточку объекта
  void _handleCardTap() {
    if (!mounted) return;

    if (widget.onTap != null) {
      widget.onTap!();
    } else if (widget.isClickable) {
      try {
        // Подробное логирование для отслеживания проблемы
        debugPrint(
          'PropertyCard: Попытка перехода к объекту с ID: ${widget.property.id}',
        );
        debugPrint(
          'PropertyCard: Данные объекта: title=${widget.property.title}, ownerId=${widget.property.ownerId}',
        );

        // Используем более надежный метод навигации
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => PropertyDetailsScreen(
                  propertyId: widget.property.id,
                  property: widget.property, // Всегда передаем сам объект
                ),
          ),
        );
      } catch (e) {
        if (mounted) {
          debugPrint('PropertyCard: Ошибка при переходе к деталям объекта: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть детали объекта: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    // Если карточка не кликабельна (isClickable == false) и нет onTap, ничего не делаем
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingL),
      decoration: BoxDecoration(
        color: AppConstants.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        child: InkWell(
          onTap:
              widget.isClickable || widget.onTap != null
                  ? _handleCardTap
                  : null,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Изображение с индикатором статуса и кнопкой "Избранное"
              _buildImageSection(theme),

              // Информация о жилье
              Padding(
                padding: const EdgeInsets.all(AppConstants.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок
                    Text(
                      widget.property.title,
                      style: const TextStyle(
                        fontSize: AppConstants.fontSizeL,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.darkBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppConstants.paddingXS),

                    // Адрес
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppConstants.darkGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.property.address,
                            style: const TextStyle(
                              fontSize: AppConstants.fontSizeSecondary,
                              color: AppConstants.darkGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingM),

                    // Рейтинг и цена
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Рейтинг
                        _buildRating(theme),

                        // Цена
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_formatPrice(widget.property.pricePerNight)} ₸/сутки',
                              style: const TextStyle(
                                fontSize: AppConstants.fontSizeBody,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.darkBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatPrice(widget.property.pricePerHour)} ₸/час',
                              style: TextStyle(
                                fontSize: AppConstants.fontSizeSecondary,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Дополнительная информация о статусе, если она предоставлена
                    if (widget.additionalInfo != null) ...[
                      const SizedBox(height: AppConstants.paddingM),
                      widget.additionalInfo!,
                    ],

                    const SizedBox(height: AppConstants.paddingM),

                    // Характеристики жилья
                    _buildFeatures(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строит секцию с изображением, статусом и кнопкой избранного
  Widget _buildImageSection(ThemeData theme) {
    return Stack(
      children: [
        // Изображение
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppConstants.radiusL),
            topRight: Radius.circular(AppConstants.radiusL),
          ),
          child: CachedNetworkImage(
            imageUrl:
                widget.property.imageUrl.isNotEmpty
                    ? widget.property.imageUrl
                    : widget.property.imageUrls.isNotEmpty
                    ? widget.property.imageUrls.first
                    : 'https://via.placeholder.com/400x250',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => Container(
                  height: 180,
                  color: AppConstants.lightGrey,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            errorWidget:
                (context, url, error) => Container(
                  height: 180,
                  color: AppConstants.lightGrey,
                  child: const Icon(Icons.error),
                ),
          ),
        ),

        // Кнопка "Избранное"
        Positioned(
          top: AppConstants.paddingS,
          right: AppConstants.paddingS,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppConstants.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 26),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color:
                    _isFavorite
                        ? AppConstants.accentColor
                        : AppConstants.darkGrey,
                size: 20,
              ),
              onPressed: _handleFavoriteToggle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }

  /// Создает виджет для отображения рейтинга
  Widget _buildRating(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.star, color: Colors.amber, size: 18),
        const SizedBox(width: 4),
        Text(
          widget.property.rating.toString(),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: AppConstants.fontSizeSecondary,
          ),
        ),
        if (widget.property.reviewsCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '(${widget.property.reviewsCount})',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: AppConstants.fontSizeSecondary,
            ),
          ),
        ],
      ],
    );
  }

  /// Создает раздел с характеристиками жилья
  Widget _buildFeatures(ThemeData theme) {
    return Row(
      children: [
        // Количество гостей
        _buildFeatureItem(
          Icons.person_outline,
          '${widget.property.maxGuests} ${_getGuestsWord(widget.property.maxGuests)}',
          theme,
        ),

        const SizedBox(width: AppConstants.paddingM),

        // Количество комнат
        _buildFeatureItem(
          Icons.meeting_room_outlined,
          '${widget.property.rooms} ${_getRoomsWord(widget.property.rooms)}',
          theme,
        ),

        const SizedBox(width: AppConstants.paddingM),

        // Площадь
        _buildFeatureItem(
          Icons.square_foot_outlined,
          '${widget.property.area.toInt()} м²',
          theme,
        ),
      ],
    );
  }

  /// Создает элемент характеристики
  Widget _buildFeatureItem(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Форматирует цену, добавляя пробелы между разрядами
  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  /// Возвращает правильное склонение для слова "комната"
  String _getRoomsWord(int count) {
    if (count == 1) {
      return 'комната';
    } else if (count >= 2 && count <= 4) {
      return 'комнаты';
    } else {
      return 'комнат';
    }
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
}
