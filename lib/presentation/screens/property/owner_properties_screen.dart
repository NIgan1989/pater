import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/presentation/widgets/common/error_view.dart';
import 'package:pater/presentation/widgets/common/empty_state.dart';
import 'package:pater/presentation/widgets/property/property_card.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';

/// Экран управления объявлениями владельца недвижимости
class OwnerPropertiesScreen extends StatefulWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  State<OwnerPropertiesScreen> createState() => _OwnerPropertiesScreenState();
}

/// Тип фильтра для объектов владельца
enum PropertyFilterType { active, archived }

class _OwnerPropertiesScreenState extends State<OwnerPropertiesScreen>
    with TickerProviderStateMixin {
  final PropertyService _propertyService = PropertyService();
  final AuthService _authService = AuthService();

  /// Контроллер табов
  late TabController _tabController;

  bool _isLoading = true;
  List<Property> _properties = [];
  String? _errorMessage;

  // Текущий выбранный фильтр
  PropertyFilterType _currentFilter = PropertyFilterType.active;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProperties();

    // Обработчик изменения вкладки
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _currentFilter = PropertyFilterType.active;
              break;
            case 1:
              _currentFilter = PropertyFilterType.archived;
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Загружает данные объектов недвижимости
  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Проверяем и восстанавливаем авторизацию
      final isAuthorized = await _authService.checkAndRestoreAuth();
      debugPrint('Проверка авторизации: $isAuthorized');

      if (!isAuthorized) {
        throw Exception('Пользователь не авторизован');
      }

      final userId = _authService.currentUser?.id ?? '';
      debugPrint('Полученный userId: "$userId"');

      if (userId.isEmpty) {
        throw Exception('Пользователь не авторизован (пустой userId)');
      }

      // Загружаем объекты владельца
      debugPrint('Начинаем загрузку объектов для владельца ID: $userId');
      final properties = await _propertyService.getUserProperties(userId);

      // Проверяем, не пустой ли список объектов
      if (properties.isEmpty) {
        debugPrint('ВНИМАНИЕ: Список объектов владельца пуст!');
        debugPrint(
          'Проверяем напрямую через propertyService.getPropertiesByOwnerId()',
        );

        final directProperties = await _propertyService.getPropertiesByOwnerId(
          userId,
        );
        if (directProperties.isNotEmpty) {
          debugPrint('Найдены объекты напрямую: ${directProperties.length}');
          _properties = directProperties;
        } else {
          _properties = properties;
          debugPrint('Объекты не найдены даже при прямом запросе');
        }
      } else {
        _properties = properties;
      }

      debugPrint(
        'Загружено объектов для владельца ID $userId: ${_properties.length}',
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка при загрузке данных: $e');
      setState(() {
        _errorMessage = 'Ошибка при загрузке данных: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Показывает снэкбар с сообщением
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Обработчик нажатия на кнопку добавления объявления
  void _addProperty() {
    context.pushNamed('add_property_profile').then((_) => _loadProperties());
  }

  /// Редактирует существующее объявление
  void _editProperty(String propertyId) {
    // Используем именованный маршрут с параметром id
    context
        .pushNamed('edit_property', pathParameters: {'id': propertyId})
        .then((_) => _loadProperties());
  }

  /// Активирует объявление
  Future<void> _activateProperty(Property property) async {
    try {
      final updatedProperty = property.copyWith(
        isActive: true,
        status: PropertyStatus.available,
      );
      await _propertyService.updateProperty(updatedProperty);
      _showSnackBar('Объявление активировано');
      _loadProperties();
    } catch (e) {
      _showSnackBar('Ошибка при активации объявления: ${e.toString()}');
    }
  }

  /// Архивирует объявление
  Future<void> _archiveProperty(Property property) async {
    try {
      final updatedProperty = property.copyWith(isActive: false);
      await _propertyService.updateProperty(updatedProperty);
      _showSnackBar('Объявление архивировано');
      _loadProperties();
    } catch (e) {
      _showSnackBar('Ошибка при архивации объявления: ${e.toString()}');
    }
  }

  /// Показывает диалог подтверждения архивации объявления
  void _showArchiveConfirmationDialog(Property property) {
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
                  _archiveProperty(property);
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
  }

  /// Показывает диалог подтверждения активации объявления
  void _showActivateConfirmationDialog(Property property) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Активировать объявление?'),
            content: const Text(
              'Объявление будет опубликовано и станет видимым в поиске для клиентов.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _activateProperty(property);
                },
                child: const Text('Активировать'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Мои объявления',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Активные'), Tab(text: 'Архив')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProperties,
            tooltip: 'Обновить',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProperty,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorView(error: _errorMessage!, onRetry: _loadProperties);
    }

    if (_properties.isEmpty) {
      return EmptyState(
        title: 'Нет объявлений',
        message: 'У вас пока нет объектов недвижимости',
        icon: Icons.home,
        action: ElevatedButton.icon(
          onPressed: _addProperty,
          icon: const Icon(Icons.add),
          label: const Text('Добавить объявление'),
        ),
      );
    }

    // Фильтруем объекты по текущему фильтру
    final filteredProperties =
        _properties.where((property) {
          if (_currentFilter == PropertyFilterType.active) {
            return property.isActive;
          } else {
            return !property.isActive;
          }
        }).toList();

    return TabBarView(
      controller: _tabController,
      children: [
        // Вкладка "Активные"
        filteredProperties.isEmpty
            ? _buildEmptyTabView('У вас нет активных объявлений')
            : _buildPropertiesListView(filteredProperties),

        // Вкладка "Архив"
        filteredProperties.isEmpty
            ? _buildEmptyTabView('У вас нет архивированных объявлений')
            : _buildPropertiesListView(filteredProperties),
      ],
    );
  }

  /// Отображает пустое состояние вкладки
  Widget _buildEmptyTabView(String message) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadProperties();
      },
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 179),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_currentFilter == PropertyFilterType.active)
                    ElevatedButton.icon(
                      onPressed: _addProperty,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить объявление'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingL,
                          vertical: AppConstants.paddingM,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Отображает список объектов недвижимости
  Widget _buildPropertiesListView(List<Property> properties) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadProperties();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        itemCount: properties.length,
        itemBuilder: (context, index) {
          final property = properties[index];
          return PropertyCard(
            property: property,
            // Добавляем обработчик нажатия для перехода к деталям
            onTap: () {
              context.pushNamed(
                'property_details',
                pathParameters: {'id': property.id.toString()},
                extra: property,
              );
            },
            // Добавляем обработчик долгого нажатия для управления объявлением
            onLongPress: () {
              showModalBottomSheet(
                context: context,
                builder:
                    (context) => Container(
                      padding: const EdgeInsets.all(AppConstants.paddingM),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Редактировать'),
                            onTap: () {
                              Navigator.pop(context);
                              _editProperty(property.id);
                            },
                          ),
                          if (_currentFilter == PropertyFilterType.active)
                            ListTile(
                              leading: const Icon(
                                Icons.archive_outlined,
                                color: Colors.red,
                              ),
                              title: const Text(
                                'Архивировать',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showArchiveConfirmationDialog(property);
                              },
                            )
                          else
                            ListTile(
                              leading: const Icon(
                                Icons.public,
                                color: Colors.green,
                              ),
                              title: const Text(
                                'Активировать',
                                style: TextStyle(color: Colors.green),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showActivateConfirmationDialog(property);
                              },
                            ),
                        ],
                      ),
                    ),
              );
            },
          );
        },
      ),
    );
  }
}
