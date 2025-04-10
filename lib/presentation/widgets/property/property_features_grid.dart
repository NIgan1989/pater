import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';

/// Виджет для отображения характеристик объекта недвижимости в виде сетки
class PropertyFeaturesGrid extends StatelessWidget {
  /// Объект недвижимости
  final Property property;

  /// Количество колонок
  final int crossAxisCount;

  /// Добавлять ли свойства, специфичные для текущего объекта
  final bool includeCustomFeatures;

  /// Стиль отображения характеристик
  final PropertyFeaturesStyle style;

  const PropertyFeaturesGrid({
    super.key,
    required this.property,
    this.crossAxisCount = 2,
    this.includeCustomFeatures = true,
    this.style = PropertyFeaturesStyle.card,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = _getFeaturesList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: style == PropertyFeaturesStyle.card ? 2.5 : 3.5,
        crossAxisSpacing: AppConstants.paddingS,
        mainAxisSpacing: AppConstants.paddingS,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];

        if (style == PropertyFeaturesStyle.card) {
          return _buildFeatureCard(feature, theme);
        } else {
          return _buildFeatureItem(feature, theme);
        }
      },
    );
  }

  /// Строит карточку характеристики
  Widget _buildFeatureCard(PropertyFeature feature, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingS),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
        boxShadow: [
          BoxShadow(
            color: AppConstants.darkBlue.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingXS),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Icon(feature.icon, color: theme.primaryColor, size: 20),
          ),
          const SizedBox(width: AppConstants.paddingS),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: AppConstants.fontSizeSmall,
                    color: AppConstants.darkGrey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  feature.value,
                  style: const TextStyle(
                    fontSize: AppConstants.fontSizeSecondary,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.darkBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Строит элемент характеристики
  Widget _buildFeatureItem(PropertyFeature feature, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(feature.icon, color: theme.colorScheme.secondary, size: 16),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                feature.title,
                style: TextStyle(
                  fontSize: 10,
                  color: AppConstants.darkGrey.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                feature.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.darkBlue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Получает список характеристик для отображения
  List<PropertyFeature> _getFeaturesList() {
    final List<PropertyFeature> features = [
      PropertyFeature(
        icon: Icons.group_outlined,
        title: 'Гости',
        value: '${property.maxGuests} ${_getGuestsWord(property.maxGuests)}',
      ),
      PropertyFeature(
        icon: Icons.meeting_room_outlined,
        title: 'Комнаты',
        value: '${property.rooms} ${_getRoomsWord(property.rooms)}',
      ),
      PropertyFeature(
        icon: Icons.square_foot_outlined,
        title: 'Площадь',
        value: '${property.area.toInt()} м²',
      ),
      PropertyFeature(
        icon: Icons.house_outlined,
        title: 'Тип',
        value: _getPropertyTypeName(property.type),
      ),
    ];

    // Добавляем дополнительные свойства, если они есть у объекта
    if (includeCustomFeatures) {
      if (property.hasWifi) {
        features.add(
          const PropertyFeature(
            icon: Icons.wifi,
            title: 'Wi-Fi',
            value: 'Есть',
          ),
        );
      }

      if (property.hasParking) {
        features.add(
          const PropertyFeature(
            icon: Icons.local_parking_outlined,
            title: 'Парковка',
            value: 'Есть',
          ),
        );
      }

      if (property.hasAirConditioning) {
        features.add(
          const PropertyFeature(
            icon: Icons.ac_unit_outlined,
            title: 'Кондиционер',
            value: 'Есть',
          ),
        );
      }

      if (property.hasKitchen) {
        features.add(
          const PropertyFeature(
            icon: Icons.kitchen_outlined,
            title: 'Кухня',
            value: 'Есть',
          ),
        );
      }

      if (property.hasTV) {
        features.add(
          const PropertyFeature(
            icon: Icons.tv_outlined,
            title: 'Телевизор',
            value: 'Есть',
          ),
        );
      }

      if (property.hasWashingMachine) {
        features.add(
          const PropertyFeature(
            icon: Icons.local_laundry_service_outlined,
            title: 'Стиральная машина',
            value: 'Есть',
          ),
        );
      }
    }

    return features;
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

  /// Возвращает название типа недвижимости
  String _getPropertyTypeName(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return 'Квартира';
      case PropertyType.house:
        return 'Дом';
      case PropertyType.room:
        return 'Комната';
      case PropertyType.hostel:
        return 'Хостел';
    }
  }
}

/// Класс для представления характеристики недвижимости
class PropertyFeature {
  final IconData icon;
  final String title;
  final String value;

  const PropertyFeature({
    required this.icon,
    required this.title,
    required this.value,
  });
}

/// Стили отображения характеристик
enum PropertyFeaturesStyle {
  /// Отображение в виде карточек с фоном
  card,

  /// Простое отображение без дополнительных элементов
  simple,
}
