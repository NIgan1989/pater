import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';

/// Виджет для отображения фильтров категорий на экране поиска
class CategoriesFilter extends StatefulWidget {
  final List<String> categories;
  final String? selectedType;
  final Function(String?) onTypeChanged;

  const CategoriesFilter({
    super.key,
    required this.categories,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  State<CategoriesFilter> createState() => _CategoriesFilterState();
}

class _CategoriesFilterState extends State<CategoriesFilter> {
  late String? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widget.categories.map((category) {
          final isSelected = _selectedType == category;
          return Padding(
            padding: const EdgeInsets.only(right: AppConstants.paddingS),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedType = selected ? category : null;
                });
                widget.onTypeChanged(selected ? category : null);
              },
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 20),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Предустановленные категории для фильтрации недвижимости
class PropertyCategories {
  static List<String> getCategories(BuildContext context) {
    return [
      'Все',
      'Квартиры',
      'Дома',
      'Комнаты',
      'Хостелы',
      'С бассейном',
      'С парковкой',
    ];
  }
  
  /// Получает название категории по типу недвижимости
  static String getCategoryNameByType(PropertyType type) {
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