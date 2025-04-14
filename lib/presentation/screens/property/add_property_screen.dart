import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pater/data/services/cloudinary_service.dart';
import 'package:pater/data/services/geocoding_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:pater/presentation/widgets/map/property_map.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';
import 'package:pater/core/di/service_locator.dart';

/// Экран создания/редактирования объявления о недвижимости
class AddPropertyScreen extends StatefulWidget {
  /// Идентификатор объекта для редактирования (null для создания нового)
  final String? propertyId;

  const AddPropertyScreen({super.key, this.propertyId});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final PropertyService _propertyService = PropertyService();
  late AuthService _authService;

  // Контроллеры формы
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _priceController = TextEditingController();
  final _pricePerHourController = TextEditingController();
  final _maxGuestsController = TextEditingController();
  final _areaController = TextEditingController();
  final _roomsController = TextEditingController();

  // Выбранные значения
  PropertyType _selectedType = PropertyType.apartment;
  bool _hasWifi = false;
  bool _hasAirConditioning = false;
  bool _hasKitchen = false;
  bool _hasTV = false;
  bool _hasWashingMachine = false;
  bool _petFriendly = false;
  String _checkInTime = '14:00';
  String _checkOutTime = '12:00';

  // Статус загрузки
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isUploading = false;

  // Изображения объекта
  List<String> _imageUrls = [];

  // Координаты объекта
  LatLng? _coordinates;

  // Статус геокодирования
  String? _geocodingStatus;

  // Флаг загрузки координат
  bool _isLoadingCoordinates = false;

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
    _authService = getIt<AuthService>();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _priceController.dispose();
    _pricePerHourController.dispose();
    _maxGuestsController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  /// Безопасно показывает SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  /// Безопасная навигация назад с результатом
  void _navigateBack({bool? result}) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  /// Загружает данные объекта для редактирования
  Future<void> _loadPropertyData() async {
    if (widget.propertyId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final property = await _propertyService.getPropertyById(
        widget.propertyId!,
      );

      if (property != null && mounted) {
        // Заполняем поля формы данными объекта
        _titleController.text = property.title;
        _descriptionController.text = property.description;
        _addressController.text = property.address;
        _cityController.text = property.city;
        _countryController.text = property.country;
        _priceController.text = property.pricePerNight.toString();
        _pricePerHourController.text = property.pricePerHour.toString();
        _maxGuestsController.text = property.maxGuests.toString();
        _areaController.text = property.area.toString();
        _roomsController.text = property.rooms.toString();

        // Устанавливаем выбранные значения
        setState(() {
          _selectedType = property.type;
          _hasWifi = property.hasWifi;
          _hasAirConditioning = property.hasAirConditioning;
          _hasKitchen = property.hasKitchen;
          _hasTV = property.hasTV;
          _hasWashingMachine = property.hasWashingMachine;
          _petFriendly = property.petFriendly;
          _checkInTime = property.checkInTime;
          _checkOutTime = property.checkOutTime;
          _imageUrls = List.from(property.imageUrls);
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки данных объекта: $e');
      if (mounted) {
        _showSnackBar('Ошибка загрузки данных: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Получает координаты по адресу
  Future<void> _getCoordinates() async {
    // Проверяем, что все адресные поля заполнены
    if (_addressController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _countryController.text.isEmpty) {
      setState(() {
        _geocodingStatus = 'Заполните все поля адреса';
        _coordinates = null;
      });
      return;
    }

    setState(() {
      _isLoadingCoordinates = true;
      _geocodingStatus = 'Получение координат...';
    });

    try {
      // Получаем координаты по адресу
      final geocodingService = GeocodingService();
      final fullAddress =
          '${_addressController.text}, ${_cityController.text}, ${_countryController.text}';
      final coordinates = await geocodingService.getCoordinatesFromAddress(
        fullAddress,
      );

      if (coordinates != null) {
        setState(() {
          _coordinates = LatLng(coordinates.latitude, coordinates.longitude);
          _geocodingStatus =
              'Координаты получены: ${coordinates.latitude}, ${coordinates.longitude}';
          _isLoadingCoordinates = false;
        });
      } else {
        setState(() {
          _geocodingStatus =
              'Не удалось определить координаты. Попробуйте уточнить адрес.';
          _coordinates = null;
          _isLoadingCoordinates = false;
        });
      }
    } catch (e) {
      setState(() {
        _geocodingStatus = 'Ошибка при получении координат: $e';
        _coordinates = null;
        _isLoadingCoordinates = false;
      });
    }
  }

  /// Валидатор для адресных полей
  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Поле обязательно для заполнения';
    }
    return null;
  }

  /// Сохраняет объект недвижимости
  Future<void> _saveProperty() async {
    if (_isSubmitting) return;

    // Проверяем валидность формы
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Если координаты еще не получены, пробуем получить их
    if (_coordinates == null) {
      await _getCoordinates();
      // Если координаты все еще не получены, показываем предупреждение
      if (_coordinates == null) {
        _showSnackBar(
          'Координаты объекта не определены. Объявление будет создано без координат, '
          'но объект не будет отображаться на карте. Рекомендуется уточнить адрес.',
          isError: true,
        );
        // Даем пользователю время прочитать сообщение перед продолжением
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    // Устанавливаем флаг отправки формы
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Получаем ID текущего пользователя
      final userId = await _authService.getCurrentUserId();

      // Создаем объект для сохранения
      final property = Property(
        id: widget.propertyId ?? '',
        ownerId: userId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        status: PropertyStatus.available, // Новые объекты всегда доступны
        imageUrls: _imageUrls,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
        latitude: _coordinates?.latitude ?? 0.0,
        longitude: _coordinates?.longitude ?? 0.0,
        pricePerNight: double.parse(_priceController.text),
        pricePerHour: double.parse(_pricePerHourController.text),
        area: double.parse(_areaController.text),
        rooms: int.parse(_roomsController.text),
        maxGuests: int.parse(_maxGuestsController.text),
        hasWifi: _hasWifi,
        hasAirConditioning: _hasAirConditioning,
        hasKitchen: _hasKitchen,
        hasTV: _hasTV,
        hasWashingMachine: _hasWashingMachine,
        petFriendly: _petFriendly,
        checkInTime: _checkInTime,
        checkOutTime: _checkOutTime,
        rating: 0.0, // Для новых объектов рейтинг 0
        reviewsCount: 0, // Для новых объектов нет отзывов
      );

      // Сохраняем или обновляем объект
      if (widget.propertyId == null) {
        await _propertyService.addProperty(property);
      } else {
        await _propertyService.updateProperty(property);
      }

      // Закрываем экран и возвращаем результат успешного сохранения
      if (!mounted) return;

      // Показываем уведомление об успехе
      _showSnackBar('Объект успешно сохранен');

      // Возвращаемся на предыдущий экран
      _navigateBack(result: true);
    } catch (e) {
      debugPrint('Ошибка сохранения объекта: $e');
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showSnackBar('Ошибка сохранения: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        widget.propertyId == null
            ? 'Добавление объекта'
            : 'Редактирование объекта';

    return Scaffold(
      appBar: CustomAppBar(title: title),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.paddingL),
                child: _buildForm(theme),
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: ElevatedButton(
          onPressed:
              _isSubmitting
                  ? null
                  : () {
                    // Проверяем, находится ли виджет в активном состоянии перед выполнением действия
                    if (mounted) {
                      _saveProperty();
                    }
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              vertical: AppConstants.paddingL,
            ),
            disabledBackgroundColor: theme.colorScheme.primary.withValues(
              alpha: 153,
            ), // ~60%
          ),
          child:
              _isSubmitting
                  ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Text(
                    widget.propertyId == null
                        ? 'Создать объявление'
                        : 'Сохранить изменения',
                  ),
        ),
      ),
    );
  }

  /// Строит форму для ввода данных объекта
  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок секции - Основная информация
          Text('Основная информация', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingM),

          // Название объекта
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Название объекта',
              hintText: 'Например: Уютная квартира в центре',
            ),
            key: const Key('property-title'),
            autocorrect: true,
            autofillHints: const [AutofillHints.name],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, введите название';
              }
              return null;
            },
          ),
          const SizedBox(height: AppConstants.paddingM),

          // Тип жилья
          DropdownButtonFormField<PropertyType>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: 'Тип жилья'),
            key: const Key('property-type'),
            items:
                PropertyType.values.map((type) {
                  String label;
                  switch (type) {
                    case PropertyType.apartment:
                      label = 'Квартира';
                      break;
                    case PropertyType.house:
                      label = 'Дом';
                      break;
                    case PropertyType.room:
                      label = 'Комната';
                      break;
                    case PropertyType.hostel:
                      label = 'Хостел';
                      break;
                  }

                  return DropdownMenuItem<PropertyType>(
                    value: type,
                    child: Text(label),
                  );
                }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                });
              }
            },
          ),
          const SizedBox(height: AppConstants.paddingM),

          // Описание
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Описание',
              hintText: 'Расскажите подробнее о вашем жилье',
            ),
            maxLines: 5,
            key: const Key('property-description'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, введите описание';
              }
              return null;
            },
          ),
          const SizedBox(height: AppConstants.paddingL),

          // Заголовок секции - Расположение
          Text('Расположение', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingM),

          // Адрес
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Адрес',
              hintText: 'Например: ул. Абая, 150',
              suffixIcon:
                  _isLoadingCoordinates
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : IconButton(
                        icon: Icon(
                          _coordinates == null
                              ? Icons.location_searching
                              : Icons.location_on,
                          color:
                              _coordinates == null ? Colors.grey : Colors.green,
                        ),
                        onPressed: _getCoordinates,
                      ),
            ),
            validator: _validateAddress,
            onChanged: (_) {
              // Сбрасываем координаты при изменении адреса
              setState(() {
                _coordinates = null;
                _geocodingStatus = null;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'Город',
              hintText: 'Например: Алматы',
            ),
            validator: _validateAddress,
            onChanged: (_) {
              setState(() {
                _coordinates = null;
                _geocodingStatus = null;
              });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _countryController,
            decoration: const InputDecoration(
              labelText: 'Страна',
              hintText: 'Например: Казахстан',
            ),
            validator: _validateAddress,
            onChanged: (_) {
              setState(() {
                _coordinates = null;
                _geocodingStatus = null;
              });
            },
          ),
          const SizedBox(height: 8),
          if (_geocodingStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _geocodingStatus!,
                style: TextStyle(
                  color: _coordinates != null ? Colors.green : Colors.orange,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _getCoordinates,
            icon: const Icon(Icons.location_on),
            label: const Text('Получить координаты'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_coordinates != null)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 76), // 0.3 * 255 = 76
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: PropertyMap(
                properties: [
                  Property(
                    id: 'preview',
                    title:
                        _titleController.text.isNotEmpty
                            ? _titleController.text
                            : 'Новый объект',
                    description: '',
                    ownerId: '',
                    type: _selectedType,
                    status: PropertyStatus.available,
                    imageUrls: const [],
                    address: _addressController.text,
                    city: _cityController.text,
                    country: _countryController.text,
                    latitude: _coordinates!.latitude,
                    longitude: _coordinates!.longitude,
                    pricePerNight:
                        _priceController.text.isNotEmpty
                            ? double.parse(_priceController.text)
                            : 0,
                    pricePerHour:
                        _pricePerHourController.text.isNotEmpty
                            ? double.parse(_pricePerHourController.text)
                            : 0,
                    area:
                        _areaController.text.isNotEmpty
                            ? double.parse(_areaController.text)
                            : 0,
                    rooms:
                        _roomsController.text.isNotEmpty
                            ? int.parse(_roomsController.text)
                            : 1,
                    maxGuests:
                        _maxGuestsController.text.isNotEmpty
                            ? int.parse(_maxGuestsController.text)
                            : 1,
                    checkInTime: _checkInTime,
                    checkOutTime: _checkOutTime,
                  ),
                ],
                initialLocation: _coordinates,
                initialZoom: 14.0,
                onMarkerTap: (_) {},
                enableClustering: false,
                showLocationButton: true,
                showUserLocation: true,
              ),
            ),

          // Заголовок секции - Детали
          Text('Детали жилья', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingM),

          // Цена за ночь
          TextFormField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Цена за сутки (₸)',
              hintText: 'Например: 15000',
            ),
            keyboardType: TextInputType.number,
            key: const Key('property-price'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, введите цену за сутки';
              }
              if (double.tryParse(value) == null) {
                return 'Пожалуйста, введите корректную цену';
              }
              return null;
            },
          ),
          const SizedBox(height: AppConstants.paddingM),

          // Цена за час
          TextFormField(
            controller: _pricePerHourController,
            decoration: const InputDecoration(
              labelText: 'Цена за час (₸)',
              hintText: 'Например: 1000',
            ),
            keyboardType: TextInputType.number,
            key: const Key('property-price-per-hour'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, введите цену за час';
              }
              if (double.tryParse(value) == null) {
                return 'Пожалуйста, введите корректную цену за час';
              }
              return null;
            },
          ),
          const SizedBox(height: AppConstants.paddingM),

          // Размер
          Row(
            children: [
              // Площадь
              Expanded(
                child: TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Площадь (м²)',
                    hintText: 'Например: 55',
                  ),
                  keyboardType: TextInputType.number,
                  key: const Key('property-area'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите площадь';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Некорректная площадь';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppConstants.paddingM),

              // Количество комнат
              Expanded(
                child: TextFormField(
                  controller: _roomsController,
                  decoration: const InputDecoration(
                    labelText: 'Комнат',
                    hintText: 'Например: 2',
                  ),
                  keyboardType: TextInputType.number,
                  key: const Key('property-rooms'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите кол-во комнат';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Некорректное число';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingM),

          // Максимальное количество гостей
          TextFormField(
            controller: _maxGuestsController,
            decoration: const InputDecoration(
              labelText: 'Максимальное количество гостей',
              hintText: 'Например: 4',
            ),
            keyboardType: TextInputType.number,
            key: const Key('property-max-guests'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Пожалуйста, введите количество гостей';
              }
              if (int.tryParse(value) == null) {
                return 'Пожалуйста, введите корректное число';
              }
              return null;
            },
          ),
          const SizedBox(height: AppConstants.paddingL),

          // Заголовок секции - Удобства
          Text('Удобства', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingM),

          // Удобства
          _buildAmenitiesSection(theme),
          const SizedBox(height: AppConstants.paddingL),

          // Заголовок секции - Фотографии
          Text('Фотографии объекта', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingM),

          // Виджет для загрузки фотографий
          _buildImagesSection(theme),
          const SizedBox(height: AppConstants.paddingL),

          // Заголовок секции - Время заезда и выезда
          Text('Время заселения и выезда', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.paddingM),

          // Время заезда и выезда
          Row(
            children: [
              Expanded(
                child: _buildTimePickerField(
                  theme,
                  label: 'Время заезда',
                  value: _checkInTime,
                  onChanged: (newTime) {
                    setState(() {
                      _checkInTime = newTime;
                    });
                  },
                ),
              ),
              const SizedBox(width: AppConstants.paddingM),
              Expanded(
                child: _buildTimePickerField(
                  theme,
                  label: 'Время выезда',
                  value: _checkOutTime,
                  onChanged: (newTime) {
                    setState(() {
                      _checkOutTime = newTime;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingXL),
        ],
      ),
    );
  }

  /// Строит секцию с удобствами
  Widget _buildAmenitiesSection(ThemeData theme) {
    return Column(
      children: [
        // Wi-Fi
        SwitchListTile(
          title: const Text('Wi-Fi'),
          value: _hasWifi,
          onChanged: (value) {
            setState(() {
              _hasWifi = value;
            });
          },
          activeColor: theme.colorScheme.primary,
        ),

        // Кондиционер
        SwitchListTile(
          title: const Text('Кондиционер'),
          value: _hasAirConditioning,
          onChanged: (value) {
            setState(() {
              _hasAirConditioning = value;
            });
          },
          activeColor: theme.colorScheme.primary,
        ),

        // Кухня
        SwitchListTile(
          title: const Text('Кухня'),
          value: _hasKitchen,
          onChanged: (value) {
            setState(() {
              _hasKitchen = value;
            });
          },
          activeColor: theme.colorScheme.primary,
        ),

        // Телевизор
        SwitchListTile(
          title: const Text('Телевизор'),
          value: _hasTV,
          onChanged: (value) {
            setState(() {
              _hasTV = value;
            });
          },
          activeColor: theme.colorScheme.primary,
        ),

        // Стиральная машина
        SwitchListTile(
          title: const Text('Стиральная машина'),
          value: _hasWashingMachine,
          onChanged: (value) {
            setState(() {
              _hasWashingMachine = value;
            });
          },
          activeColor: theme.colorScheme.primary,
        ),

        // Можно с животными
        SwitchListTile(
          title: const Text('Можно с животными'),
          value: _petFriendly,
          onChanged: (value) {
            setState(() {
              _petFriendly = value;
            });
          },
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }

  /// Строит секцию с фотографиями
  Widget _buildImagesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Загрузите фотографии вашего объекта (мин. 1, макс. 10)',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppConstants.paddingM),

        // Отображаем индикатор загрузки при загрузке изображения
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppConstants.paddingM),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Загрузка изображения...'),
                ],
              ),
            ),
          ),

        // Кнопка добавления изображений
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _pickImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Добавить изображение'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: AppConstants.paddingM),

        if (_imageUrls.isNotEmpty) ...[
          Text(
            'Добавленные изображения (${_imageUrls.length}):',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.paddingS),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _imageUrls.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: AppConstants.paddingS),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    child: CachedNetworkImage(
                      imageUrl: _imageUrls[index],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            width: 60,
                            height: 60,
                            color: theme.colorScheme.primary.withAlpha(
                              25,
                            ), // ~10%
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            color: theme.colorScheme.primary.withAlpha(
                              25,
                            ), // ~10%
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                  title: Text(
                    'Изображение ${index + 1}',
                    style: const TextStyle(
                      fontSize: AppConstants.fontSizeSecondary,
                    ),
                  ),
                  subtitle: Text(
                    _imageUrls[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppConstants.fontSizeSmall,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeImage(index),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  /// Строит поле для выбора времени
  Widget _buildTimePickerField(
    ThemeData theme, {
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        if (!mounted) return;

        // Показываем диалог выбора времени
        final TimeOfDay initialTime = _parseTimeString(value);
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: initialTime,
        );

        // Если пользователь выбрал время и виджет все еще активен
        if (pickedTime != null && mounted) {
          final String newTime =
              '${pickedTime.hour.toString().padLeft(2, '0')}:'
              '${pickedTime.minute.toString().padLeft(2, '0')}';
          onChanged(newTime);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
          ),
        ),
        child: Text(value),
      ),
    );
  }

  /// Парсит строку времени в объект TimeOfDay
  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// Выбор и загрузка изображения с устройства
  Future<void> _pickImage() async {
    if (!mounted) return;

    // Создаем экземпляр ImagePicker
    final ImagePicker picker = ImagePicker();

    try {
      // Открываем галерею для выбора изображения
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      // Проверяем, выбрано ли изображение и активен ли виджет
      if (pickedImage == null || !mounted) return;

      setState(() {
        _isUploading = true;
      });

      try {
        // Инициализируем Cloudinary если еще не инициализирован
        final cloudinaryService = CloudinaryService();
        await cloudinaryService.init();

        // Загружаем изображение в Cloudinary
        final String imageUrl = await cloudinaryService.uploadXFile(
          pickedImage,
        );

        // Проверяем, активен ли виджет
        if (!mounted) return;

        // Добавляем URL в список изображений
        setState(() {
          _imageUrls.add(imageUrl);
          _isUploading = false;
        });

        // Показываем уведомление об успешной загрузке
        _showSnackBar('Изображение успешно загружено');
      } catch (e) {
        debugPrint('Ошибка при загрузке изображения в Cloudinary: $e');

        if (!mounted) return;

        setState(() {
          _isUploading = false;
        });

        _showSnackBar('Ошибка загрузки изображения: $e', isError: true);
      }
    } catch (e) {
      debugPrint('Ошибка при выборе изображения: $e');

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showSnackBar('Ошибка при выборе изображения: $e', isError: true);
    }
  }

  /// Удаляет изображение из списка
  void _removeImage(int index) async {
    if (!mounted) return;

    // Сохраняем URL удаляемого изображения
    final String imageUrl = _imageUrls[index];

    try {
      // Сначала удаляем из UI для мгновенной обратной связи
      setState(() {
        _imageUrls.removeAt(index);
      });

      // Затем удаляем из облака
      final cloudinaryService = CloudinaryService();
      await cloudinaryService.init();
      await cloudinaryService.deleteImage(imageUrl);
    } catch (e) {
      debugPrint('Ошибка при удалении изображения: $e');

      if (!mounted) return;

      // В случае ошибки восстанавливаем изображение в списке
      if (!_imageUrls.contains(imageUrl)) {
        setState(() {
          _imageUrls.insert(index, imageUrl);
        });
      }

      _showSnackBar('Ошибка при удалении изображения: $e', isError: true);
    }
  }
}
