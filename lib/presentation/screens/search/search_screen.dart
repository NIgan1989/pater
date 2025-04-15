import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/presentation/widgets/map/property_map.dart';
import 'package:pater/presentation/widgets/property/property_card.dart';
import 'package:pater/presentation/widgets/common/app_button.dart';
import 'package:pater/presentation/widgets/search/property_filters.dart';
import 'package:pater/presentation/screens/property/property_details_screen.dart';
import 'dart:async';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/core/di/service_locator.dart';

/// Исключение, возникающее при отказе пользователя предоставить разрешение на геолокацию
class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException([
    this.message = 'Доступ к геолокации запрещен',
  ]);
  @override
  String toString() => message;
}

/// Исключение, возникающее при постоянном отказе пользователя предоставить разрешение на геолокацию
class LocationPermissionPermanentlyDeniedException implements Exception {
  final String message;
  LocationPermissionPermanentlyDeniedException([
    this.message = 'Доступ к геолокации запрещен навсегда',
  ]);
  @override
  String toString() => message;
}

/// Компонент содержимого экрана поиска, без Scaffold и BottomNavigationBar
/// Используется для встраивания в HomeScreen
class SearchContent extends StatefulWidget {
  const SearchContent({super.key});

  @override
  State<SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<SearchContent>
    with TickerProviderStateMixin {
  final PropertyService _propertyService = PropertyService();
  final AuthService _authService = getIt<AuthService>();
  final TextEditingController _searchController = TextEditingController();

  // Состояние экрана
  List<Property> _properties = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Контроллер для выдвижного списка
  late DraggableScrollableController _bottomSheetController;

  // Текущее местоположение пользователя
  Position? _currentPosition;

  // Вкладки для владельцев
  late TabController _tabController;

  // Информация о пользователе
  late User? _user;

  // Показывать ли фильтры
  bool _showFilters = false;

  // Фильтры
  String? _selectedPropertyType;
  RangeValues _priceRange = const RangeValues(10000, 100000);
  int? _selectedRoomsCount;
  List<String> _selectedAmenities = [];

  // Начальное положение карты
  final LatLng _defaultLocation = const LatLng(43.238949, 76.889709); // Алматы

  // Карта для отслеживания избранных объектов
  final Map<String, bool> _favorites = {};

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
    _bottomSheetController = DraggableScrollableController();
    _loadData();

    // Инициализация контроллера вкладок для владельцев
    _tabController = TabController(
      length: _user?.role == UserRole.owner ? 2 : 1,
      vsync: this,
    );

    // Загружаем статус избранных объектов
    if (_user != null) {
      _loadFavoritesStatus();
    }

    // Получаем местоположение пользователя
    _initializeLocation();

    // Исправление: Замена addListener со строковым аргументом на VoidCallback
    _searchController.addListener(() => _handleSearch(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _bottomSheetController.dispose();
    super.dispose();
  }

  /// Инициализация получения местоположения
  void _initializeLocation() {
    _getCurrentLocation()
        .then((_) {
          if (mounted) {
            setState(() {});
          }
        })
        .catchError((error) {
          debugPrint('Ошибка при получении местоположения: $error');
          if (error is! LocationPermissionDeniedException && mounted) {
            setState(() {});
          }
        });
  }

  /// Определяет текущее местоположение пользователя
  Future<void> _getCurrentLocation() async {
    try {
      // Проверяем разрешение на доступ к местоположению
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw LocationPermissionDeniedException();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationPermissionPermanentlyDeniedException();
      }

      // Получаем текущее местоположение пользователя
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при получении местоположения: $e');
      if (e is! LocationPermissionDeniedException) {
        // Показываем сообщение об ошибке, только если это не отказ от разрешения
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось получить местоположение: $e')),
          );
        }
      }
    }
  }

  /// Обработчик изменения текста в строке поиска и обновления карты
  void _handleSearch(String value) {
    setState(() {
      _searchQuery = value.trim();
    });

    // Если строка поиска содержит название города, пытаемся найти его на карте
    if (_searchQuery.isNotEmpty) {
      _searchLocationOnMap(_searchQuery);
    }
  }

  /// Функция поиска локации на карте по названию
  void _searchLocationOnMap(String query) {
    // Реализация поиска местоположения по строке
    // ...
  }

  /// Загрузка данных
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final properties = await _propertyService.getAllProperties();

      // Добавляем логирование для отладки координат
      debugPrint('Загружено объектов: ${properties.length}');
      int validCoordinatesCount = 0;
      for (var property in properties) {
        if (_hasValidCoordinates(property)) {
          validCoordinatesCount++;
        }
      }
      debugPrint('Объектов с валидными координатами: $validCoordinatesCount');

      if (mounted) {
        setState(() {
          _properties = properties;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Загружает статус избранного для текущего пользователя
  Future<void> _loadFavoritesStatus() async {
    try {
      // Получаем список избранных объектов
      final favorites = await _propertyService.getFavoriteProperties(_user!.id);

      // Сохраняем ID избранных объектов в Map для быстрого доступа
      for (final favorite in favorites) {
        _favorites[favorite.id] = true;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке избранного: $e');
    }
  }

  /// Проверяет, есть ли у объекта валидные координаты для отображения на карте
  bool _hasValidCoordinates(Property property) {
    return property.latitude != 0 &&
        property.longitude != 0 &&
        property.latitude.isFinite &&
        property.longitude.isFinite;
  }

  /// Отфильтрованные объекты недвижимости
  List<Property> get _filteredProperties {
    if (_properties.isEmpty) return [];

    return _properties.where((property) {
      // Фильтрация по поисковому запросу
      if (_searchQuery.isNotEmpty) {
        if (!property.title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) &&
            !property.address.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            )) {
          return false;
        }
      }

      // Фильтрация по типу недвижимости
      if (_selectedPropertyType != null) {
        String propertyTypeString = property.type.toString().split('.').last;
        if (propertyTypeString != _selectedPropertyType) {
          return false;
        }
      }

      // Фильтрация по цене
      if (property.pricePerNight < _priceRange.start ||
          property.pricePerNight > _priceRange.end) {
        return false;
      }

      // Фильтрация по количеству комнат
      if (_selectedRoomsCount != null &&
          property.rooms != _selectedRoomsCount) {
        return false;
      }

      // Фильтрация по удобствам
      if (_selectedAmenities.contains('wifi') && !property.hasWifi) {
        return false;
      }
      if (_selectedAmenities.contains('air_conditioning') &&
          !property.hasAirConditioning) {
        return false;
      }
      if (_selectedAmenities.contains('kitchen') && !property.hasKitchen) {
        return false;
      }
      if (_selectedAmenities.contains('tv') && !property.hasTV) {
        return false;
      }
      if (_selectedAmenities.contains('washing_machine') &&
          !property.hasWashingMachine) {
        return false;
      }
      if (_selectedAmenities.contains('pet_friendly') &&
          !property.petFriendly) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Сбрасывает все фильтры к начальным значениям
  void _resetFilters() {
    setState(() {
      _selectedPropertyType = null;
      _priceRange = const RangeValues(10000, 100000);
      _selectedRoomsCount = null;
      _selectedAmenities = [];
      _searchController.clear();
      _searchQuery = '';
      _showFilters = false;
    });
    _loadData(); // Использовать существующий метод _loadData вместо _loadProperties
  }

  /// Применяет выбранные фильтры
  void _applyFilters(PropertyFilterData filterData) {
    setState(() {
      _selectedPropertyType = filterData.propertyType;
      _priceRange = filterData.priceRange;
      _selectedRoomsCount = filterData.roomsCount;
      _selectedAmenities = filterData.amenities;
      _showFilters = false;
    });
    _loadData();
  }

  /// Полное раскрытие bottom sheet
  void _expandBottomSheet() {
    _bottomSheetController.animateTo(
      1.0, // Полный экран
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Частичное сворачивание bottom sheet
  void _collapseBottomSheet() {
    _bottomSheetController.animateTo(
      AppConstants.bottomSheetMinSize, // Минимальный размер
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Открывает диалог с фильтрами
  void _showFilterDialog(BuildContext context) {
    setState(() {
      _showFilters = !_showFilters;

      // Если фильтры открываются, сворачиваем нижний лист до минимального размера
      if (_showFilters) {
        _collapseBottomSheet();
      }
    });
  }

  /// Загружает недвижимость с применением фильтров
  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Исправление: Используем существующий метод getAllProperties вместо getProperties
      final properties = await _propertyService.getAllProperties();

      setState(() {
        _properties = properties;
        // Исправление: Используем геттер _filteredProperties вместо сеттера
        _isLoading = false;
      });

      // Обновляем маркеры на карте
      _updateMapMarkers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      }
    }
  }

  /// Переключает статус "избранное" для свойства
  void _toggleFavorite(String propertyId) {
    if (mounted && _user != null) {
      setState(() {
        _favorites[propertyId] = !(_favorites[propertyId] ?? false);
      });

      // Исправление: Используем существующие методы для добавления/удаления из избранного
      final isFavorite = _favorites[propertyId] ?? false;
      if (isFavorite) {
        _propertyService.addToFavorites(_user!.id, propertyId);
      } else {
        _propertyService.removeFromFavorites(_user!.id, propertyId);
      }
    }
  }

  /// Обработка нажатия на маркер карты или на карточку объекта
  void _showPropertyDetails(Property property) {
    context.pushNamed(
      'property_details',
      pathParameters: {'id': property.id.toString()},
      extra: property,
    );
  }

  /// Переходит на страницу деталей объекта недвижимости
  void _navigateToPropertyDetails(String propertyId) {
    debugPrint(
      'SearchScreen: Переход к детальному просмотру объявления с ID: $propertyId',
    );

    try {
      // Находим объект по ID из загруженных свойств с дополнительными проверками
      Property? property;

      try {
        property = _filteredProperties.firstWhere(
          (p) => p.id == propertyId,
          orElse:
              () => _properties.firstWhere(
                (p) => p.id == propertyId,
                orElse:
                    () => throw Exception('Объект с ID $propertyId не найден'),
              ),
        );

        debugPrint('SearchScreen: Объект найден: ${property.title}');
      } catch (e) {
        debugPrint('SearchScreen: Ошибка при поиске объекта: $e');
        rethrow;
      }

      // Используем прямую навигацию через MaterialPageRoute вместо именованного маршрута
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => PropertyDetailsScreen(
                propertyId: propertyId,
                property: property, // Передаем полный объект
              ),
        ),
      );
    } catch (e) {
      debugPrint('SearchScreen: Ошибка при переходе к деталям объекта: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось открыть объявление: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Обновляет маркеры на карте
  void _updateMapMarkers() {
    // Логика обновления маркеров на карте по необходимости
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    // Учитываем высоту нижней навигационной панели
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bottomNavBarHeight = AppConstants.navBarHeight + bottomPadding;

    // Создаем объект данных фильтров на основе текущих значений
    final filterData = PropertyFilterData(
      propertyType: _selectedPropertyType,
      priceRange: _priceRange,
      roomsCount: _selectedRoomsCount,
      amenities: _selectedAmenities,
    );

    return Stack(
      children: [
        // Карта на весь экран
        SizedBox(height: screenHeight, child: _buildMapView()),

        // Выдвижной список объектов (Bottom Sheet)
        DraggableScrollableSheet(
          initialChildSize: AppConstants.bottomSheetInitialSize,
          minChildSize: AppConstants.bottomSheetMinSize,
          maxChildSize: 1.0,
          controller: _bottomSheetController,
          snap: true,
          snapSizes: const [
            AppConstants.bottomSheetMinSize,
            AppConstants.bottomSheetInitialSize,
            0.7,
            1.0,
          ],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.radiusL),
                  topRight: Radius.circular(AppConstants.radiusL),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 26),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 3, bottom: 1),
                    width: 40,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Expand/Collapse buttons
                  SizedBox(
                    height: 30, // Фиксированная высота для кнопок
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Найдено: ${_filteredProperties.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.keyboard_arrow_down),
                                onPressed: _collapseBottomSheet,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Свернуть',
                                iconSize: 20, // Уменьшаем размер иконки
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.keyboard_arrow_up),
                                onPressed: _expandBottomSheet,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Развернуть',
                                iconSize: 20, // Уменьшаем размер иконки
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Список объектов
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _filteredProperties.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Объекты не найдены',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: 200,
                                      child: AppButton.secondary(
                                        text: 'Сбросить фильтры',
                                        onPressed: _resetFilters,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : ListView.builder(
                              // Добавляем physics для правильной прокрутки
                              physics: const ClampingScrollPhysics(),
                              controller: scrollController,
                              padding: EdgeInsets.only(
                                left: 16.0,
                                right: 16.0,
                                bottom:
                                    bottomNavBarHeight +
                                    24.0, // увеличиваем отступ снизу
                              ),
                              itemCount: _filteredProperties.length,
                              itemBuilder: (context, index) {
                                final property = _filteredProperties[index];
                                final isFavorite =
                                    _favorites[property.id] == true;

                                return PropertyCard(
                                  property: property,
                                  isFavorite: isFavorite,
                                  onFavoriteToggle:
                                      (value) => _toggleFavorite(property.id),
                                  onTap:
                                      () => _navigateToPropertyDetails(
                                        property.id,
                                      ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        ),

        // Search bar (всегда наверху)
        Positioned(
          top: MediaQuery.of(context).padding.top,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 26),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск жилья...',
                prefixIcon: const Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterDialog(context),
                ),
              ),
              onChanged: (value) {
                // Рекомендуется использовать debounce для сокращения количества запросов
                setState(() {
                  _searchQuery = value;
                });
                _loadProperties();
              },
            ),
          ),
        ),

        // Панель фильтров (поверх всего при открытии)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: MediaQuery.of(context).padding.top + 70, // Ниже поисковой строки
          left: 0,
          right: 0,
          height: _showFilters ? null : 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Container(
              // Добавляем дополнительный контейнер с отступами
              margin: const EdgeInsets.only(bottom: 8.0),
              child: PropertyFilters(
                isVisible: _showFilters,
                filterData: filterData,
                onClose: () => setState(() => _showFilters = false),
                onReset: _resetFilters,
                onApply: _applyFilters,
              ),
            ),
          ),
        ),

        // Добавляем SizedBox в нижней части экрана для предотвращения переполнения
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SizedBox(height: bottomNavBarHeight + 8),
        ),

        // Loading indicator
        if (_isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  /// Изменяем метод _buildMapView для фильтрации объектов без координат:
  Widget _buildMapView() {
    // Фильтруем список объектов, оставляя только те, у которых есть корректные координаты
    final propertiesWithCoordinates =
        _properties.where(_hasValidCoordinates).toList();

    // Определяем начальное положение карты
    LatLng? initialLocation;

    // Если есть текущее местоположение пользователя, используем его
    if (_currentPosition != null) {
      initialLocation = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }
    // Если есть объекты с координатами, используем координаты первого объекта
    else if (propertiesWithCoordinates.isNotEmpty) {
      initialLocation = LatLng(
        propertiesWithCoordinates.first.latitude,
        propertiesWithCoordinates.first.longitude,
      );
    }
    // В противном случае используем координаты по умолчанию (Алматы)
    else {
      initialLocation = _defaultLocation;
    }

    return PropertyMap(
      properties: propertiesWithCoordinates,
      initialLocation: initialLocation,
      initialZoom: 12.0,
      onMarkerTap: (property) {
        // Обрабатываем нажатие на маркер
        _showPropertyDetails(property);
      },
      showUserLocation: true,
      showLocationButton: true,
      enableClustering: true,
    );
  }
}

/// Экран поиска жилья и заявок на уборку
/// Этот класс оставлен для обратной совместимости
/// Но рекомендуется использовать SearchContent внутри HomeScreen
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SafeArea(child: SearchContent()));
  }
}
