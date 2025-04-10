import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geocoding/geocoding.dart';

/// Элемент кластера для группировки объектов на карте
class ClusterItem {
  final Property property;
  final LatLng latLng;

  ClusterItem({required this.property, required this.latLng});
}

/// Современный компонент карты для отображения объектов недвижимости
class PropertyMap extends StatefulWidget {
  /// Список объектов недвижимости для отображения на карте
  final List<Property> properties;

  /// Функция, вызываемая при нажатии на маркер объекта
  final Function(Property) onMarkerTap;

  /// Начальное местоположение карты
  final LatLng? initialLocation;

  /// Начальный масштаб карты
  final double initialZoom;

  /// Флаг, указывающий, нужно ли показывать текущее местоположение пользователя
  final bool showUserLocation;

  /// Флаг, указывающий, нужно ли показывать кнопку для центрирования по местоположению пользователя
  final bool showLocationButton;

  /// Флаг, указывающий, нужно ли показывать кластеризацию маркеров
  final bool enableClustering;

  const PropertyMap({
    super.key,
    required this.properties,
    required this.onMarkerTap,
    this.initialLocation,
    this.initialZoom = 12.0,
    this.showUserLocation = true,
    this.showLocationButton = true,
    this.enableClustering = true,
  });

  @override
  State<PropertyMap> createState() => _PropertyMapState();
}

class _PropertyMapState extends State<PropertyMap> {
  /// Контроллер для управления картой
  MapController? _mapController;

  /// Список маркеров для отображения на карте
  final List<Marker> _markers = [];

  /// Текущее местоположение пользователя
  Position? _currentPosition;

  /// Маркер местоположения пользователя
  Marker? _userLocationMarker;

  /// Выбранное свойство для показа всплывающего окна
  Property? _selectedProperty;

  /// Позиция всплывающего окна
  LatLng? _popupLocation;

  /// Текущий масштаб карты
  double _currentZoom = 12.0;

  /// Координаты центра Казахстана
  final LatLng _kazakhstanCenter = const LatLng(48.0196, 66.9237);

  /// Масштаб для обзора всего Казахстана
  final double _kazakhstanZoom = 5.0;

  /// Флаг, указывающий, была ли инициализирована карта
  bool _isMapInitialized = false;

  @override
  void initState() {
    super.initState();

    // Инициализация контроллера карты
    _mapController = MapController();

    // Установка начального масштаба
    _currentZoom = widget.initialZoom;

    // Проверка разрешения на доступ к местоположению
    if (widget.showUserLocation) {
      _checkLocationPermission();
    }

    // Создание маркеров для объектов
    _createPropertyMarkers();

    // Планируем перемещение к центру Казахстана, если масштаб <= 6 и не задана начальная позиция
    if (widget.initialZoom <= 6.0 &&
        widget.initialLocation == null &&
        widget.properties.length > 10) {
      // Используем Future.delayed, чтобы подождать инициализацию карты
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _mapController!.move(_kazakhstanCenter, _kazakhstanZoom);
        }
      });
    }
  }

  @override
  void didUpdateWidget(PropertyMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если список объектов изменился, обновляем маркеры
    if (widget.properties != oldWidget.properties) {
      _createPropertyMarkers();
    }
  }

  @override
  void dispose() {
    // Очистка ресурсов перед удалением виджета
    try {
      _mapController?.dispose();
    } catch (e) {
      debugPrint('Ошибка при освобождении ресурсов карты: $e');
    }
    super.dispose();
  }

  /// Получить текущее местоположение пользователя
  Future<void> _getCurrentLocation() async {
    try {
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

        // Создаем маркер для текущего местоположения
        _createUserLocationMarker(position);

        // Перемещаем карту к местоположению пользователя, если карта инициализирована
        if (widget.showLocationButton) {
          _moveMapToLocation(
            LatLng(position.latitude, position.longitude),
            15.0,
          );
        }
      }
    } catch (e) {
      debugPrint('Ошибка при получении местоположения: $e');
    }
  }

  /// Проверка разрешения на доступ к местоположению
  Future<void> _checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await _getCurrentLocation();
      }
    } catch (e) {
      debugPrint('Ошибка при проверке разрешений: $e');
    }
  }

  /// Создает маркер для текущего местоположения пользователя
  void _createUserLocationMarker(Position position) {
    if (!mounted) return;

    setState(() {
      // Создание маркера пользователя
      _userLocationMarker = Marker(
        point: LatLng(position.latitude, position.longitude),
        child: GestureDetector(
          onTap: () {
            _showUserLocationInfo();
          },
          child: Container(
            width: 30.0,
            height: 30.0,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 179),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.0),
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 20.0,
            ),
          ),
        ),
      );

      // Обновляем маркеры на карте
      _updateMarkers();
    });
  }

  /// Показывает информацию о местоположении пользователя
  void _showUserLocationInfo() {
    if (_currentPosition != null) {
      // Получаем адрес по координатам и показываем в диалоге
      _getAddressFromLatLng(_currentPosition!).then((address) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Ваше местоположение'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Координаты: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
                    ),
                    const SizedBox(height: 8),
                    if (address != null) Text('Адрес: $address'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Закрыть'),
                  ),
                ],
              );
            },
          );
        }
      });
    }
  }

  /// Получает адрес по координатам
  Future<String?> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.country}';
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка при получении адреса: $e');
      return null;
    }
  }

  /// Создание маркеров для объектов недвижимости
  void _createPropertyMarkers() {
    if (!mounted) {
      return; // Проверяем, монтирован ли виджет
    }

    final markers = <Marker>[];
    int validCoordinatesCount = 0;

    for (final property in widget.properties) {
      // Проверяем валидность координат перед созданием маркера
      if (!_isValidCoordinate(property.latitude, property.longitude)) {
        debugPrint(
          'Пропущен объект с невалидными координатами: ID=${property.id}, '
          'lat=${property.latitude}, lng=${property.longitude}',
        );
        continue;
      }

      validCoordinatesCount++;
      final marker = Marker(
        point: LatLng(property.latitude, property.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            if (!mounted) {
              return; // Проверяем, монтирован ли виджет
            }

            // Обновляем состояние для отображения всплывающего окна
            setState(() {
              _selectedProperty = property;
              _popupLocation = LatLng(property.latitude, property.longitude);
            });
            widget.onMarkerTap(property);
          },
          child: _buildMarkerWidget(context, property),
        ),
      );

      markers.add(marker);
    }

    debugPrint(
      'Создано маркеров: $validCoordinatesCount из ${widget.properties.length}',
    );

    // Добавляем маркер местоположения пользователя, если он доступен
    if (_userLocationMarker != null) {
      markers.add(_userLocationMarker!);
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  /// Проверяет валидность координат
  bool _isValidCoordinate(double lat, double lng) {
    // Проверка на нулевые координаты (часто признак неинициализированных значений)
    if (lat == 0.0 && lng == 0.0) {
      return false;
    }

    // Проверка на бесконечность или NaN
    if (!lat.isFinite || !lng.isFinite) {
      return false;
    }

    // Проверка диапазона координат
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return false;
    }

    return true;
  }

  /// Обновление маркеров на карте
  void _updateMarkers() {
    if (!mounted) {
      return; // Проверяем, монтирован ли виджет перед обновлением состояния
    }
    setState(() {}); // Это заставит виджет перерисоваться с текущими маркерами
  }

  /// Создает маркер для объекта недвижимости
  Widget _buildMarkerWidget(BuildContext context, Property property) {
    // Определение цвета маркера в зависимости от доступности объекта
    final Color markerColor;

    if (property.status == PropertyStatus.available) {
      markerColor = AppConstants.darkBlue;
    } else if (property.status == PropertyStatus.booked) {
      markerColor = Colors.red;
    } else {
      markerColor = Colors.grey;
    }

    // Проверяем, является ли этот объект выбранным
    final bool isSelected = _selectedProperty?.id == property.id;
    final double size =
        isSelected ? 35.0 : 30.0; // Увеличиваем размер выбранного маркера

    // Делаем сжатый виджет маркера, чтобы избежать переполнения
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Минимальный размер по вертикали
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 1,
            ), // Минимальный паддинг
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3), // Уменьшенный радиус
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${_formatPrice(property.pricePerNight)} ₸',
                style: TextStyle(
                  fontSize:
                      isSelected
                          ? 7
                          : 6, // Увеличиваем шрифт для выбранного маркера
                  fontWeight: FontWeight.bold,
                  color: AppConstants.darkBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 1), // Минимальный отступ
          Icon(
            Icons.location_on,
            color: markerColor,
            size:
                isSelected
                    ? 20
                    : 16, // Увеличиваем размер иконки для выбранного маркера
          ),
        ],
      ),
    );
  }

  /// Форматирует стоимость в виде строки
  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  /// Строит маркер кластера
  Widget _buildClusterMarker(int markerCount) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppConstants.darkBlue.withValues(alpha: 179),
      ),
      child: Center(
        child: Text(
          markerCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Строит всплывающее окно для маркера
  Widget _buildPopupMarker(Marker marker) {
    // Находим объект недвижимости по точке маркера
    final propertyMarkers =
        _markers.where((m) => m.point == marker.point).toList();
    if (propertyMarkers.isEmpty) return const SizedBox.shrink();

    // Получаем объект недвижимости из маркера
    final property = widget.properties.firstWhere(
      (p) =>
          p.latitude == marker.point.latitude &&
          p.longitude == marker.point.longitude,
      orElse: () => widget.properties.first,
    );

    // Устанавливаем выбранное свойство и его локацию
    setState(() {
      _selectedProperty = property;
      _popupLocation = marker.point;
    });

    // Возвращаем всплывающее окно, передавая контекст
    return _buildPropertyPopup(context);
  }

  @override
  Widget build(BuildContext context) {
    // Проверяем доступность свойств для отображения
    final hasProperties = widget.properties.isNotEmpty;

    // Определяем центр карты
    final center =
        widget.initialLocation ??
        (hasProperties
            ? LatLng(
              widget.properties.first.latitude,
              widget.properties.first.longitude,
            )
            : const LatLng(43.238949, 76.889709)); // Алматы по умолчанию

    // Используем более надежный источник тайлов - OpenStreetMap
    const String tileUrlTemplate =
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    // Запасной источник тайлов (резервный)
    const String fallbackUrlTemplate =
        'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';

    return FlutterMap(
      mapController: _mapController!,
      options: MapOptions(
        initialCenter: center,
        initialZoom:
            5.0, // Сначала устанавливаем низкий зум для предотвращения проблем загрузки
        initialRotation: 0.0,
        maxZoom: 18.0,
        minZoom: 3.0,
        backgroundColor: Colors.white,
        // Предотвращаем повторные запросы при масштабировании
        interactionOptions: const InteractionOptions(
          enableScrollWheel: true,
          enableMultiFingerGestureRace: true,
        ),
        onMapReady: () {
          // После инициализации карты выставляем нужный зум
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _isMapInitialized = true;
              try {
                _mapController?.move(center, widget.initialZoom);
                debugPrint('Карта инициализирована, зум установлен');

                // Если у нас есть текущее местоположение пользователя и требуется его отображение,
                // перемещаемся к нему
                if (widget.showUserLocation && _currentPosition != null) {
                  _moveMapToLocation(
                    LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    15.0,
                  );
                }
              } catch (e) {
                debugPrint('Ошибка при инициализации карты: $e');
              }
            }
          });
        },
        onMapEvent: (MapEvent mapEvent) {
          // Отслеживаем изменение масштаба
          if (mapEvent is MapEventMoveEnd) {
            setState(() {
              _currentZoom = mapEvent.camera.zoom;
              debugPrint('Текущий масштаб карты: $_currentZoom');
            });
          }
        },
        onTap: (_, __) {
          _hidePopup(); // Явно используем метод для скрытия всплывающего окна
        },
      ),
      children: [
        // Слой тайлов карты с улучшенной обработкой ошибок
        TileLayer(
          urlTemplate: tileUrlTemplate,
          // Используем более качественный провайдер тайлов с кэшированием
          tileProvider: CancellableNetworkTileProvider(),
          userAgentPackageName: 'com.pater.app',
          // Минимизация сетевых запросов
          maxZoom: 18,
          minZoom: 3,
          keepBuffer: 5,
          // Обработка ошибок загрузки тайлов
          errorImage: const NetworkImage(
            'https://via.placeholder.com/256x256.png?text=Map+Unavailable',
          ),
          // Запасной источник тайлов
          fallbackUrl: fallbackUrlTemplate,
          errorTileCallback: (tile, error, stackTrace) {
            debugPrint('Ошибка загрузки тайла: $error');
          },
        ),

        // Слой с маркерами или с кластерами
        if (widget.enableClustering && widget.properties.length > 1)
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              markers: _markers,
              builder: (context, markers) {
                return _buildClusterMarker(
                  markers.length,
                ); // Явно используем метод для создания кластера
              },
              maxClusterRadius: 45,
              size: const Size(40, 40),
              disableClusteringAtZoom: 15,
              // Добавляем анимацию для кластеров
              animationsOptions: const AnimationsOptions(
                zoom: Duration(milliseconds: 300),
                fitBound: Duration(milliseconds: 300),
                centerMarker: Duration(milliseconds: 300),
                spiderfy: Duration(milliseconds: 300),
              ),
              popupOptions: PopupOptions(
                popupSnap: PopupSnap.markerTop,
                popupController: PopupController(),
                popupBuilder:
                    (context, marker) => _buildPopupMarker(
                      marker,
                    ), // Явно используем метод для создания всплывающего окна
              ),
            ),
          )
        else
          MarkerLayer(
            markers: [
              ..._markers,
              if (_userLocationMarker != null) _userLocationMarker!,
            ],
          ),

        // Всплывающее окно для выбранного объекта
        if (_selectedProperty != null && _popupLocation != null)
          _buildPropertyPopup(context),

        // Кнопки управления картой
        if (widget.showLocationButton)
          Stack(
            children: [
              Positioned(
                bottom:
                    80, // Увеличиваем отступ снизу, чтобы поднять кнопку выше
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.my_location, size: 20),
                      color: AppConstants.darkBlue,
                      onPressed: () {
                        if (_currentPosition != null) {
                          _moveMapToLocation(
                            LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            15.0,
                          );
                        } else {
                          _getCurrentLocation();
                        }
                      },
                      tooltip: 'Мое местоположение',
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Строит всплывающее окно с информацией об объекте
  Widget _buildPropertyPopup(BuildContext context) {
    final property = _selectedProperty!;

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                property.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                property.address,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${property.pricePerNight.toInt()} ₸ / ночь',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.darkBlue,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      widget.onMarkerTap(property);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.darkBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Подробнее',
                      style: TextStyle(fontSize: 12, color: Colors.white),
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

  /// Скрывает всплывающее окно
  void _hidePopup() {
    setState(() {
      _selectedProperty = null;
      _popupLocation = null;
    });
  }

  /// Перемещение карты к указанной локации
  void _moveMapToLocation(LatLng location, double zoom) {
    // Проверяем, инициализирован ли контроллер карты
    if (_mapController != null && _isMapInitialized) {
      try {
        _mapController!.move(location, zoom);
      } catch (e) {
        debugPrint('Ошибка при перемещении карты: $e');
      }
    } else {
      debugPrint('Карта еще не инициализирована, перемещение отложено');
      // Перемещение будет выполнено в onMapReady
    }
  }
}
