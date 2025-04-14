import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/di/service_locator.dart';
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
enum PropertyFilterType {
  /// Активные объявления
  active,

  /// Неактивные объявления
  inactive,

  /// Архивированные объявления
  archived,
}

class _OwnerPropertiesScreenState extends State<OwnerPropertiesScreen>
    with SingleTickerProviderStateMixin {
  final PropertyService _propertyService = PropertyService();
  late final AuthService _authService;
  late TabController _tabController;

  List<Property> _activeProperties = [];
  List<Property> _inactiveProperties = [];
  List<Property> _archivedProperties = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Текущий выбранный фильтр
  PropertyFilterType _currentFilter = PropertyFilterType.active;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _authService = getIt<AuthService>();
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
              _currentFilter = PropertyFilterType.inactive;
              break;
            case 2:
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
      // Получаем ID текущего пользователя
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Пользователь не авторизован';
        });
        return;
      }

      // Загружаем объекты пользователя
      final properties = await _propertyService.getPropertiesByOwnerId(userId);

      // Фильтруем объекты по категориям
      final active =
          properties
              .where((p) => p.isActive && p.status == PropertyStatus.available)
              .toList();
      final inactive = properties.where((p) => !p.isActive).toList();
      final archived =
          properties
              .where((p) => p.isActive && p.status != PropertyStatus.available)
              .toList();

      if (mounted) {
        setState(() {
          _activeProperties = active;
          _inactiveProperties = inactive;
          _archivedProperties = archived;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
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

  /// Переводит объект в активное состояние
  Future<void> _makePropertyAvailable(Property property) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Вызываем метод с правильным числом параметров - он принимает только ID объекта
      final result = await _propertyService.makePropertyAvailable(property.id);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Объект успешно активирован'),
              backgroundColor: Colors.green,
            ),
          );

          _loadProperties();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка при активации объекта'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
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
                  _makePropertyAvailable(property);
                },
                child: const Text('Активировать'),
              ),
            ],
          ),
    );
  }

  /// Архивирует объект
  Future<void> _archiveProperty(Property property) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Вместо использования copyWith, просто изменим статус объекта
      // на нужный перед отправкой обновления
      await _propertyService.updatePropertyStatus(
        property.id,
        PropertyStatus.archived,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Объект успешно архивирован'),
            backgroundColor: Colors.green,
          ),
        );

        _loadProperties();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

    if (_activeProperties.isEmpty &&
        _inactiveProperties.isEmpty &&
        _archivedProperties.isEmpty) {
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
        _currentFilter == PropertyFilterType.active
            ? _activeProperties
            : _archivedProperties;

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
