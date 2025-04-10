import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/saved_search.dart';
import 'package:pater/presentation/widgets/common/loading_indicator.dart';
import 'package:pater/presentation/widgets/common/app_tab_bar.dart';
import 'package:intl/intl.dart';

/// Экран избранных объектов, доступный из нижней навигации
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final PropertyService _propertyService = PropertyService();
  final List<SavedSearch> _savedSearches = [];

  late TabController _tabController;
  bool _isLoading = false;

  List<Property> _favoriteProperties = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  /// Загружает данные для экрана (избранные объекты)
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Проверяем авторизацию
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _favoriteProperties = [];
          });
        }
        return;
      }

      // Получаем избранные объекты
      final properties = await _propertyService.getFavoriteProperties(
        currentUser.id,
      );

      if (mounted) {
        setState(() {
          _favoriteProperties = properties;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке избранных объектов: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _favoriteProperties = [];
        });
      }
    }
  }

  void _viewPropertyDetails(Property property) {
    if (mounted) {
      context.push(
        '/property_details/${property.id}',
        extra: {
          'propertyId': int.tryParse(property.id) ?? 0,
          'property': property,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        bottom: AppTabBar(
          controller: _tabController,
          tabs: const ['Объекты', 'Поиски'],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFavoritesTab(theme), _buildSavedSearchesTab(theme)],
      ),
    );
  }

  Widget _buildFavoritesTab(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (_favoriteProperties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 64,
                color: theme.colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                'У вас пока нет избранных объектов',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Добавляйте понравившиеся объекты в избранное, чтобы быстро находить их',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: () {
                    context.go('/search');
                  },
                  child: const Text('Найти жильё'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favoriteProperties.length,
        itemBuilder: (context, index) {
          final property = _favoriteProperties[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPropertyCard(property, theme),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(Property property, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => _viewPropertyDetails(property),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                      property.imageUrls.isNotEmpty
                          ? Image.network(
                            property.imageUrls.first,
                            fit: BoxFit.cover,
                          )
                          : Container(
                            color: theme.colorScheme.primary.withAlpha(25),
                            child: const Center(
                              child: Icon(Icons.image, size: 48),
                            ),
                          ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () async {
                      if (!mounted) return;

                      final currentUser = _authService.currentUser;
                      if (currentUser != null) {
                        await _propertyService.removeFromFavorites(
                          currentUser.id,
                          property.id,
                        );

                        if (!mounted) return;
                        _loadData();
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(230),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${property.city}, ${property.country}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        NumberFormat.currency(
                          locale: 'ru',
                          symbol: '₸',
                          decimalDigits: 0,
                        ).format(property.pricePerNight),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        ' / ночь',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedSearchesTab(ThemeData theme) {
    if (_savedSearches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                'У вас пока нет сохранённых поисков',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Сохраняйте результаты поиска, чтобы быстро находить жильё по вашим критериям',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: () {
                    context.go('/search');
                  },
                  child: const Text('Начать поиск'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedSearches.length,
      itemBuilder: (context, index) {
        final savedSearch = _savedSearches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSavedSearchCard(theme, savedSearch),
        );
      },
    );
  }

  Widget _buildSavedSearchCard(ThemeData theme, SavedSearch savedSearch) {
    final DateTime createdAt = savedSearch.createdAt;
    final String formattedDate = DateFormat('dd.MM.yyyy').format(createdAt);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    savedSearch.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!mounted) return;

                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Удаление поиска'),
                            content: const Text(
                              'Вы уверены, что хотите удалить этот сохранённый поиск?',
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                    );

                    if (confirmed == true && mounted) {
                      setState(() {
                        _savedSearches.remove(savedSearch);
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (savedSearch.city != null && savedSearch.city!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildSearchParam(theme, 'Город', savedSearch.city!),
              ),
            if (savedSearch.checkInDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildSearchParam(
                  theme,
                  'Заезд',
                  DateFormat('dd.MM.yyyy').format(savedSearch.checkInDate!),
                ),
              ),
            if (savedSearch.checkOutDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildSearchParam(
                  theme,
                  'Выезд',
                  DateFormat('dd.MM.yyyy').format(savedSearch.checkOutDate!),
                ),
              ),
            if (savedSearch.guestsCount != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildSearchParam(
                  theme,
                  'Гости',
                  '${savedSearch.guestsCount} чел.',
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Сохранено: $formattedDate',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.go('/search', extra: savedSearch);
                },
                child: const Text('Повторить поиск'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchParam(ThemeData theme, String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
