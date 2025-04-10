import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Модель данных с фильтрами для недвижимости
class PropertyFilterData {
  String? propertyType;
  RangeValues priceRange;
  int? roomsCount;
  List<String> amenities;

  PropertyFilterData({
    this.propertyType,
    this.priceRange = const RangeValues(0, 100000),
    this.roomsCount,
    this.amenities = const [],
  });

  /// Создает копию с обновленными значениями
  PropertyFilterData copyWith({
    String? propertyType,
    RangeValues? priceRange,
    int? roomsCount,
    List<String>? amenities,
    bool resetPropertyType = false,
    bool resetRoomsCount = false,
  }) {
    return PropertyFilterData(
      propertyType:
          resetPropertyType ? null : (propertyType ?? this.propertyType),
      priceRange: priceRange ?? this.priceRange,
      roomsCount: resetRoomsCount ? null : (roomsCount ?? this.roomsCount),
      amenities: amenities ?? List.from(this.amenities),
    );
  }
}

/// Расширенный виджет фильтров для объектов недвижимости
class PropertyFilters extends StatefulWidget {
  final bool isVisible;
  final PropertyFilterData filterData;
  final VoidCallback onClose;
  final VoidCallback onReset;
  final Function(PropertyFilterData) onApply;

  const PropertyFilters({
    super.key,
    required this.isVisible,
    required this.filterData,
    required this.onClose,
    required this.onReset,
    required this.onApply,
  });

  @override
  State<PropertyFilters> createState() => _PropertyFiltersState();
}

class _PropertyFiltersState extends State<PropertyFilters> {
  late PropertyFilterData _localFilterData;

  @override
  void initState() {
    super.initState();
    _localFilterData = widget.filterData;
  }

  @override
  void didUpdateWidget(PropertyFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterData != widget.filterData) {
      _localFilterData = widget.filterData;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingM,
        vertical: AppConstants.paddingS,
      ),
      padding: const EdgeInsets.all(AppConstants.paddingM),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок и кнопка закрытия (не скроллируется)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Фильтры',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(),

            // Скроллируемое содержимое фильтров
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Тип жилья
                    Text(
                      'Тип жилья',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPropertyTypeChip(
                          context,
                          'Квартира',
                          'apartment',
                        ),
                        _buildPropertyTypeChip(context, 'Дом', 'house'),
                        _buildPropertyTypeChip(context, 'Вилла', 'villa'),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingM),

                    // Цена за ночь
                    Text(
                      'Цена за ночь (₸)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values: _localFilterData.priceRange,
                      min: 0,
                      max: 100000,
                      divisions: 20,
                      labels: RangeLabels(
                        '${_localFilterData.priceRange.start.round()} ₸',
                        '${_localFilterData.priceRange.end.round()} ₸',
                      ),
                      onChanged: (values) {
                        setState(() {
                          _localFilterData = _localFilterData.copyWith(
                            priceRange: values,
                          );
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0 ₸',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 128,
                            ),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '100 000 ₸',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 128,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingM),

                    // Количество комнат
                    Text(
                      'Количество комнат',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRoomsChip(context, '1 комната', 1),
                        _buildRoomsChip(context, '2 комнаты', 2),
                        _buildRoomsChip(context, '3 комнаты', 3),
                        _buildRoomsChip(context, '4+ комнат', 4),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingM),

                    // Удобства
                    Text(
                      'Удобства',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Wi-Fi'),
                          selected: _localFilterData.amenities.contains('wifi'),
                          onSelected: (selected) {
                            setState(() {
                              final amenities = List<String>.from(
                                _localFilterData.amenities,
                              );
                              if (selected) {
                                amenities.add('wifi');
                              } else {
                                amenities.remove('wifi');
                              }
                              _localFilterData = _localFilterData.copyWith(
                                amenities: amenities,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Кондиционер'),
                          selected: _localFilterData.amenities.contains(
                            'air_conditioning',
                          ),
                          onSelected: (selected) {
                            setState(() {
                              final amenities = List<String>.from(
                                _localFilterData.amenities,
                              );
                              if (selected) {
                                amenities.add('air_conditioning');
                              } else {
                                amenities.remove('air_conditioning');
                              }
                              _localFilterData = _localFilterData.copyWith(
                                amenities: amenities,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Кухня'),
                          selected: _localFilterData.amenities.contains(
                            'kitchen',
                          ),
                          onSelected: (selected) {
                            setState(() {
                              final amenities = List<String>.from(
                                _localFilterData.amenities,
                              );
                              if (selected) {
                                amenities.add('kitchen');
                              } else {
                                amenities.remove('kitchen');
                              }
                              _localFilterData = _localFilterData.copyWith(
                                amenities: amenities,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Телевизор'),
                          selected: _localFilterData.amenities.contains('tv'),
                          onSelected: (selected) {
                            setState(() {
                              final amenities = List<String>.from(
                                _localFilterData.amenities,
                              );
                              if (selected) {
                                amenities.add('tv');
                              } else {
                                amenities.remove('tv');
                              }
                              _localFilterData = _localFilterData.copyWith(
                                amenities: amenities,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Стиральная машина'),
                          selected: _localFilterData.amenities.contains(
                            'washing_machine',
                          ),
                          onSelected: (selected) {
                            setState(() {
                              final amenities = List<String>.from(
                                _localFilterData.amenities,
                              );
                              if (selected) {
                                amenities.add('washing_machine');
                              } else {
                                amenities.remove('washing_machine');
                              }
                              _localFilterData = _localFilterData.copyWith(
                                amenities: amenities,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('Можно с животными'),
                          selected: _localFilterData.amenities.contains(
                            'pet_friendly',
                          ),
                          onSelected: (selected) {
                            setState(() {
                              final amenities = List<String>.from(
                                _localFilterData.amenities,
                              );
                              if (selected) {
                                amenities.add('pet_friendly');
                              } else {
                                amenities.remove('pet_friendly');
                              }
                              _localFilterData = _localFilterData.copyWith(
                                amenities: amenities,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Кнопки действий внизу панели с дополнительным отступом
            const SizedBox(height: 16),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onReset();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onApply(_localFilterData);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppConstants.darkBlue,
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyTypeChip(
    BuildContext context,
    String label,
    String type,
  ) {
    final theme = Theme.of(context);
    final isSelected = _localFilterData.propertyType == type;

    return Padding(
      padding: const EdgeInsets.only(right: AppConstants.paddingS),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (value) {
          setState(() {
            _localFilterData = _localFilterData.copyWith(
              propertyType: value ? type : null,
              resetPropertyType: !value,
            );
          });
        },
        selectedColor: theme.colorScheme.primary.withValues(alpha: 20),
        checkmarkColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color:
              isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRoomsChip(BuildContext context, String label, int rooms) {
    final theme = Theme.of(context);
    final isSelected = _localFilterData.roomsCount == rooms;

    return Padding(
      padding: const EdgeInsets.only(right: AppConstants.paddingS),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (value) {
          setState(() {
            _localFilterData = _localFilterData.copyWith(
              roomsCount: value ? rooms : null,
              resetRoomsCount: !value,
            );
          });
        },
        selectedColor: theme.colorScheme.primary.withValues(alpha: 20),
        checkmarkColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color:
              isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
