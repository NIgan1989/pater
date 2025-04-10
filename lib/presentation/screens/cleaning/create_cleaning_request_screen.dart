import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/cleaning_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/cleaning_request.dart';
import 'package:pater/presentation/widgets/common/app_button.dart';
import 'package:pater/presentation/widgets/common/app_text_field.dart';

/// Экран создания заявки на уборку для владельцев
class CreateCleaningRequestScreen extends StatefulWidget {
  /// Идентификатор объекта недвижимости (опционально)
  final String? propertyId;

  const CreateCleaningRequestScreen({
    super.key,
    this.propertyId,
  });

  @override
  State<CreateCleaningRequestScreen> createState() => _CreateCleaningRequestScreenState();
}

class _CreateCleaningRequestScreenState extends State<CreateCleaningRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _propertyService = PropertyService();
  final _authService = AuthService();
  final _cleaningService = CleaningService();

  // Контроллеры для форм
  final _descriptionController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Property> _ownerProperties = [];
  Property? _selectedProperty;
  CleaningType _cleaningType = CleaningType.basic;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  double _price = 0;
  CleaningUrgency _urgency = CleaningUrgency.low;
  
  // Дополнительные услуги
  bool _windowCleaning = false;
  bool _balconyCleaning = false;
  bool _ironing = false;
  
  // Контроллеры для адреса
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadOwnerProperties();
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }
  
  /// Загружает список объектов недвижимости текущего владельца
  Future<void> _loadOwnerProperties() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final properties = await _propertyService.getOwnerProperties();
      
      setState(() {
        _ownerProperties = properties;
        
        // Если есть ID объекта из аргументов - выбираем его
        if (widget.propertyId != null) {
          _selectedProperty = properties.firstWhere(
            (property) => property.id == widget.propertyId,
            orElse: () => properties.isNotEmpty ? properties.first : Property(
              id: 'placeholder',
              title: 'Не выбрано',
              description: '',
              ownerId: '',
              type: PropertyType.apartment,
              status: PropertyStatus.available,
              imageUrls: [],
              address: '',
              city: '',
              country: '',
              latitude: 0,
              longitude: 0,
              pricePerNight: 0,
              pricePerHour: 0,
              area: 0,
              rooms: 0,
              maxGuests: 1,
              checkInTime: '14:00',
              checkOutTime: '12:00',
            ),
          );
        } else if (properties.isNotEmpty) {
          _selectedProperty = properties.first;
        }
        
        // Рассчитываем начальную цену
        if (_selectedProperty != null) {
          _calculatePrice();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке данных: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// Возвращает строковое представление типа уборки для отображения в UI
  String _getCleaningTypeText(CleaningType type) {
    switch (type) {
      case CleaningType.basic:
        return 'Базовая уборка';
      case CleaningType.deep:
        return 'Генеральная уборка';
      case CleaningType.postConstruction:
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
      case CleaningType.afterGuests:
        return 'Уборка после гостей';
    }
  }
  
  /// Возвращает строковое представление срочности
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
  
  /// Возвращает текст для отображения выбранной даты и времени
  String _getFormattedDateTime() {
    final dateFormatter = DateFormat('dd MMMM yyyy', 'ru');
    return '${dateFormatter.format(_selectedDate)}, ${_selectedTime.format(context)}';
  }
  
  /// Возвращает базовую стоимость в зависимости от типа уборки
  double _getBasePrice(CleaningType type) {
    switch (type) {
      case CleaningType.basic:
        return 100.0;
      case CleaningType.deep:
        return 200.0;
      case CleaningType.postConstruction:
      case CleaningType.postConstruction2:
        return 300.0;
      case CleaningType.window:
        return 150.0;
      case CleaningType.carpet:
        return 180.0;
      case CleaningType.regular:
        return 120.0;
      case CleaningType.general:
        return 220.0;
      case CleaningType.afterGuests:
        return 160.0;
    }
  }
  
  /// Рассчитывает ориентировочную стоимость уборки
  void _calculatePrice() {
    double basePrice = 0;
    
    // Базовая цена в зависимости от площади объекта
    if (_selectedProperty != null) {
      basePrice = _selectedProperty!.area * _getBasePrice(_cleaningType);
    }
    
    // Надбавка за тип уборки
    switch (_cleaningType) {
      case CleaningType.basic:
        // Базовая цена без изменений
        break;
      case CleaningType.deep:
        basePrice *= 1.5;
        break;
      case CleaningType.postConstruction:
      case CleaningType.postConstruction2:
        basePrice *= 2;
        break;
      case CleaningType.window:
        basePrice *= 1.2;
        break;
      case CleaningType.carpet:
        basePrice *= 1.3;
        break;
      case CleaningType.regular:
        basePrice *= 1.1;
        break;
      case CleaningType.general:
        basePrice *= 1.6;
        break;
      case CleaningType.afterGuests:
        basePrice *= 1.4;
        break;
    }
    
    // Надбавка за срочность
    switch (_urgency) {
      case CleaningUrgency.low:
        // Без надбавки
        break;
      case CleaningUrgency.medium:
        basePrice *= 1.1;
        break;
      case CleaningUrgency.high:
        basePrice *= 1.3;
        break;
      case CleaningUrgency.urgent:
        basePrice *= 1.5;
        break;
    }
    
    // Дополнительные услуги
    if (_windowCleaning) basePrice += 1000;
    if (_balconyCleaning) basePrice += 500;
    if (_ironing) basePrice += 800;
    
    setState(() {
      _price = basePrice.roundToDouble();
    });
  }
  
  /// Создает заявку на уборку
  Future<void> _createCleaningRequest() async {
    if (_formKey.currentState?.validate() != true) return;
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final user = _authService.currentUser;
      
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      // Формируем список дополнительных услуг
      List<String> additionalServices = [];
      if (_windowCleaning) additionalServices.add('Мытье окон');
      if (_balconyCleaning) additionalServices.add('Уборка балкона');
      if (_ironing) additionalServices.add('Глажка белья');
      
      // Формируем дату и время уборки
      final cleaningDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      final price = _price;
      
      // Сохраняем заявку
      final requestId = await _cleaningService.createCleaningRequest(
        propertyId: _selectedProperty?.id ?? '',
        ownerId: user.id,
        cleaningType: _cleaningType,
        scheduledDate: cleaningDateTime,
        estimatedPrice: price,
        description: _descriptionController.text,
        additionalServices: additionalServices,
        urgency: _urgency,
        address: _addressController.text,
        city: _cityController.text,
      );
      
      setState(() {
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заявка успешно создана'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Переход к странице заявки
        context.pushNamed('cleaning_request_details', pathParameters: {'id': requestId.toString()});
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании заявки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Выбор типа уборки
  void _selectCleaningType(CleaningType type) {
    setState(() {
      _cleaningType = type;
      _calculatePrice();
    });
  }
  
  /// Выбор срочности
  void _selectUrgency(CleaningUrgency urgency) {
    setState(() {
      _urgency = urgency;
      _calculatePrice();
    });
  }
  
  /// Открывает диалог выбора даты
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = now.add(const Duration(days: 90));
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ru', 'RU'),
    );
    
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }
  
  /// Открывает диалог выбора времени
  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }
  
  /// Строит выбор объекта недвижимости
  Widget _buildPropertySelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Выберите объект для уборки',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingM),
        if (_ownerProperties.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppConstants.paddingM),
                  Text(
                    'У вас нет объектов недвижимости',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.paddingS),
                  Text(
                    'Добавьте объект, чтобы создать заявку на уборку',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.paddingM),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.pushNamed('create_property');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить объект'),
                  ),
                ],
              ),
            ),
          )
        else
          DropdownButtonFormField<Property>(
            value: _selectedProperty,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusM),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingM,
                vertical: AppConstants.paddingS,
              ),
              hintText: 'Выберите объект',
            ),
            items: _ownerProperties.map((property) {
              return DropdownMenuItem<Property>(
                value: property,
                child: Text(
                  property.title,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (property) {
              setState(() {
                _selectedProperty = property;
              });
              _calculatePrice();
            },
          ),
      ],
    );
  }
  
  /// Строит опцию типа уборки
  Widget _buildCleaningTypeOption(CleaningType type, IconData icon, ThemeData theme) {
    final isSelected = _cleaningType == type;
    
    return Card(
      elevation: 0,
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectCleaningType(type),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingM),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppConstants.paddingM),
              Text(
                _getCleaningTypeText(type),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Строит опции типов уборки
  Widget _buildCleaningTypes(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.paddingL),
        Text(
          'Выберите тип уборки',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingM),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          childAspectRatio: 0.9,
          crossAxisSpacing: AppConstants.paddingS,
          mainAxisSpacing: AppConstants.paddingS,
          children: [
            _buildCleaningTypeOption(
              CleaningType.basic,
              Icons.cleaning_services,
              theme,
            ),
            _buildCleaningTypeOption(
              CleaningType.deep,
              Icons.auto_awesome,
              theme,
            ),
            _buildCleaningTypeOption(
              CleaningType.postConstruction,
              Icons.construction,
              theme,
            ),
            _buildCleaningTypeOption(
              CleaningType.window,
              Icons.window,
              theme,
            ),
            _buildCleaningTypeOption(
              CleaningType.carpet,
              Icons.home_work,
              theme,
            ),
          ],
        ),
      ],
    );
  }
  
  /// Строит опцию срочности
  Widget _buildUrgencyOption(CleaningUrgency urgency, String priceChange, ThemeData theme) {
    final isSelected = _urgency == urgency;
    
    return Card(
      elevation: 0,
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectUrgency(urgency),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getUrgencyText(urgency),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingS),
              Text(
                priceChange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание заявки на уборку'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.paddingM),
                children: [
                  // Выбор объекта недвижимости
                  _buildPropertySelector(theme),
                  
                  // Адрес, если нет выбранного объекта или для ручного ввода
                  if (_selectedProperty == null || _urgency != CleaningUrgency.low) ...[
                    const SizedBox(height: AppConstants.paddingL),
                    Text(
                      'Укажите адрес',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingM),
                    AppTextField(
                      controller: _addressController,
                      label: 'Адрес',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите адрес';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.paddingM),
                    AppTextField(
                      controller: _cityController,
                      label: 'Город',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите город';
                        }
                        return null;
                      },
                    ),
                  ],
                  
                  // Выбор типа уборки
                  _buildCleaningTypes(theme),
                  
                  // Выбор срочности
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppConstants.paddingL),
                      Text(
                        'Выберите срочность',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingM),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.0,
                        crossAxisSpacing: AppConstants.paddingS,
                        mainAxisSpacing: AppConstants.paddingS,
                        children: [
                          _buildUrgencyOption(
                            CleaningUrgency.low,
                            'Обычная цена',
                            theme,
                          ),
                          _buildUrgencyOption(
                            CleaningUrgency.medium,
                            '+20% к стоимости',
                            theme,
                          ),
                          _buildUrgencyOption(
                            CleaningUrgency.high,
                            '+50% к стоимости',
                            theme,
                          ),
                          _buildUrgencyOption(
                            CleaningUrgency.urgent,
                            '+100% к стоимости',
                            theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Выбор даты и времени
                  const SizedBox(height: AppConstants.paddingL),
                  Text(
                    'Выберите дату и время',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingM),
                  InkWell(
                    onTap: () async {
                      await _selectDate();
                      if (!mounted) return;
                      await _selectTime();
                    },
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.paddingM),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: AppConstants.paddingM),
                          Text(
                            _getFormattedDateTime(),
                            style: theme.textTheme.bodyLarge,
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  
                  // Дополнительные услуги
                  const SizedBox(height: AppConstants.paddingL),
                  Text(
                    'Дополнительные услуги',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingM),
                  CheckboxListTile(
                    value: _windowCleaning,
                    onChanged: (value) {
                      setState(() {
                        _windowCleaning = value ?? false;
                        _calculatePrice();
                      });
                    },
                    title: const Text('Мытье окон'),
                    subtitle: const Text('+1000 ₽'),
                    secondary: const Icon(Icons.window),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingM,
                      vertical: AppConstants.paddingS,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingS),
                  CheckboxListTile(
                    value: _balconyCleaning,
                    onChanged: (value) {
                      setState(() {
                        _balconyCleaning = value ?? false;
                        _calculatePrice();
                      });
                    },
                    title: const Text('Уборка балкона'),
                    subtitle: const Text('+800 ₽'),
                    secondary: const Icon(Icons.balcony),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingM,
                      vertical: AppConstants.paddingS,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingS),
                  CheckboxListTile(
                    value: _ironing,
                    onChanged: (value) {
                      setState(() {
                        _ironing = value ?? false;
                        _calculatePrice();
                      });
                    },
                    title: const Text('Глажка белья'),
                    subtitle: const Text('+1200 ₽'),
                    secondary: const Icon(Icons.iron),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingM,
                      vertical: AppConstants.paddingS,
                    ),
                  ),
                  
                  // Комментарий
                  const SizedBox(height: AppConstants.paddingL),
                  Text(
                    'Комментарий',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingM),
                  AppTextField(
                    controller: _descriptionController,
                    label: 'Комментарий к заявке',
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите описание';
                      }
                      return null;
                    },
                  ),
                  
                  // Стоимость и кнопка создания
                  const SizedBox(height: AppConstants.paddingL),
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingM),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Примерная стоимость:',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_price.toInt()} ₽',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.paddingS),
                        const Text(
                          'Окончательная стоимость может отличаться в зависимости от предложений клинеров',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.paddingL),
                  AppButton.primary(
                    text: 'Создать заявку',
                    onPressed: _isSubmitting ? null : _createCleaningRequest,
                    isLoading: _isSubmitting,
                    icon: Icons.add,
                  ),
                  const SizedBox(height: AppConstants.paddingL),
                ],
              ),
            ),
    );
  }
} 