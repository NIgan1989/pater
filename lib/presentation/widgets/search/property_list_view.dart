import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/presentation/widgets/property/property_card.dart';

/// Виджет для улучшенного отображения списка недвижимости
class PropertyListView extends StatelessWidget {
  final List<Property> properties;
  final Function(Property) onPropertyTap;
  final Function(Property, bool)? onFavoriteToggle;
  final Map<String, bool> favorites;
  
  /// Стиль отображения списка
  final PropertyListViewStyle style;
  
  /// Заголовок для секции
  final String? title;
  
  /// Отображать ли кнопку "См. все"
  final bool showSeeAll;
  
  /// Callback для нажатия на кнопку "См. все"
  final VoidCallback? onSeeAllTap;

  const PropertyListView({
    super.key,
    required this.properties,
    required this.onPropertyTap,
    this.onFavoriteToggle,
    this.favorites = const {},
    this.style = PropertyListViewStyle.list,
    this.title,
    this.showSeeAll = false,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Если есть заголовок, отображаем его с опциональной кнопкой "См. все"
    final hasHeader = title != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHeader)
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.paddingM,
              right: AppConstants.paddingM,
              bottom: AppConstants.paddingS,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showSeeAll)
                  TextButton(
                    onPressed: onSeeAllTap,
                    child: Text(
                      'Смотреть все',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
    
        // Выбираем тип отображения списка в зависимости от стиля
        if (style == PropertyListViewStyle.horizontalScroll)
          _buildHorizontalList(context)
        else if (style == PropertyListViewStyle.grid)
          _buildGridList(context)
        else
          _buildVerticalList(context),
      ],
    );
  }
  
  /// Создает горизонтальный скроллируемый список карточек недвижимости
  Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 320, // Фиксированная высота для горизонтального списка
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingS),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          return Container(
            width: 280,
            padding: const EdgeInsets.all(AppConstants.paddingS),
            child: PropertyCard(
              property: property,
              onTap: () => onPropertyTap(property),
              isFavorite: favorites[property.id] ?? false,
              onFavoriteToggle: onFavoriteToggle != null 
                  ? (newValue) => onFavoriteToggle!(property, newValue)
                  : null,
            ),
          );
        },
      ),
    );
  }
  
  /// Создает вертикальный список карточек недвижимости
  Widget _buildVerticalList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingM,
            vertical: AppConstants.paddingS,
          ),
          child: PropertyCard(
            property: property,
            onTap: () => onPropertyTap(property),
            isFavorite: favorites[property.id] ?? false,
            onFavoriteToggle: onFavoriteToggle != null 
                ? (newValue) => onFavoriteToggle!(property, newValue)
                : null,
          ),
        );
      },
    );
  }
  
  /// Создает сетку из карточек недвижимости
  Widget _buildGridList(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingS),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppConstants.paddingS,
        mainAxisSpacing: AppConstants.paddingS,
      ),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return PropertyCard(
          property: property,
          onTap: () => onPropertyTap(property),
          isFavorite: favorites[property.id] ?? false,
          onFavoriteToggle: onFavoriteToggle != null 
              ? (newValue) => onFavoriteToggle!(property, newValue)
              : null,
        );
      },
    );
  }
}

/// Стили отображения списка недвижимости
enum PropertyListViewStyle {
  /// Вертикальный список
  list,
  
  /// Горизонтальный скроллируемый список
  horizontalScroll,
  
  /// Сетка
  grid,
} 