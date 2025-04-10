import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/auth/role_manager.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';

/// Экран профиля пользователя
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final RoleManager _roleManager = RoleManager();

  User? _user;
  List<UserRole> _userRoles = [];
  UserRole? _activeRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Загружает данные пользователя и его роли
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем текущего пользователя
      final user = _authService.currentUser;

      if (user != null) {
        // Получаем все роли пользователя
        final roles = await _roleManager.getUserRoles(user.id);
        // Получаем активную роль
        final activeRole = await _roleManager.getActiveRole(user.id);

        setState(() {
          _user = user;
          _userRoles = roles;
          _activeRole = activeRole;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке данных пользователя: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Переключает активную роль пользователя
  Future<void> _setActiveRole(UserRole role) async {
    if (_user == null) return;

    try {
      final success = await _roleManager.setActiveRole(_user!.id, role);

      // После асинхронной операции проверяем, что виджет все еще в дереве
      if (!mounted) return;

      if (success) {
        setState(() {
          _activeRole = role;
        });

        // Обновляем интерфейс по активной роли
        if (role != _user!.role) {
          // Передача обновленной роли в другой метод без использования контекста
          await _updateUserRole(role);
        }
      }
    } catch (e) {
      debugPrint('Ошибка при установке активной роли: $e');
    }
  }

  /// Обновляет роль пользователя в сервисе авторизации
  Future<void> _updateUserRole(UserRole role) async {
    if (_user == null) return;

    try {
      // Создаем обновленного пользователя с новой ролью
      final updatedUser = _user!.copyWith(role: role);

      // Обновляем пользователя в сервисе авторизации
      final success = await _authService.updateUserRole(updatedUser);

      // Проверяем, что виджет все еще в дереве после асинхронной операции
      if (!mounted) return;

      // Если обновление прошло успешно, обновляем локальное состояние
      if (success) {
        setState(() {
          _user = updatedUser;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при обновлении роли пользователя: $e');
    }
  }

  /// Добавляет новую роль пользователю
  Future<void> _addUserRole(UserRole role) async {
    if (_user == null) return;

    try {
      final success = await _roleManager.addUserRole(_user!.id, role);

      // Проверяем, что виджет все еще в дереве после асинхронной операции
      if (!mounted) return;

      if (success) {
        // Обновляем список ролей
        final roles = await _roleManager.getUserRoles(_user!.id);

        // Еще раз проверяем mounted после второй асинхронной операции
        if (!mounted) return;

        setState(() {
          _userRoles = roles;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при добавлении роли пользователю: $e');
    }
  }

  /// Удаляет роль у пользователя
  Future<void> _removeUserRole(UserRole role) async {
    if (_user == null) return;

    // Нельзя удалить роль клиента
    if (role == UserRole.client) {
      return;
    }

    try {
      final success = await _roleManager.removeUserRole(_user!.id, role);

      // Проверяем, что виджет все еще в дереве после асинхронной операции
      if (!mounted) return;

      if (success) {
        // Обновляем список ролей
        final roles = await _roleManager.getUserRoles(_user!.id);

        // Еще раз проверяем mounted после второй асинхронной операции
        if (!mounted) return;

        setState(() {
          _userRoles = roles;
        });

        // Сохраняем флаг для последующего переключения роли
        final needSwitchToClient = _activeRole == role;

        // Если нужно переключиться на клиента, делаем это в отдельном методе
        if (needSwitchToClient && mounted) {
          // Запускаем операцию переключения роли асинхронно, но не ждем ее завершения
          _setActiveRole(UserRole.client);
        }
      }
    } catch (e) {
      debugPrint('Ошибка при удалении роли пользователя: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Профиль',
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: theme.iconTheme.color),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                context.go('/home');
              }
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              )
              : _user == null
              ? _buildNotAuthorizedView()
              : _buildProfileContent(),
    );
  }

  /// Строит содержимое профиля для авторизованного пользователя
  Widget _buildProfileContent() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Верхняя секция с данными пользователя
          _buildUserInfoSection(),

          const Divider(),

          // Секция ролей
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Управление ролями', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),

                // Активная роль
                _buildActiveRoleSelector(),

                const SizedBox(height: 24),

                // Доступные роли
                Text('Доступные роли', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),

                // Список ролей с возможностью активации/деактивации
                _buildRolesList(),
              ],
            ),
          ),

          const Divider(),

          // Нижняя секция с основными действиями
          _buildActionsSection(),
        ],
      ),
    );
  }

  /// Строит секцию с информацией о пользователе
  Widget _buildUserInfoSection() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Аватар пользователя
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.primaryColor.withAlpha(26),
            backgroundImage:
                _user?.avatarUrl != null
                    ? NetworkImage(_user!.avatarUrl!)
                    : null,
            child:
                _user?.avatarUrl == null
                    ? Text(
                      _user?.initials ?? '',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          const SizedBox(height: 16),

          // Имя пользователя
          Text(
            _user?.fullName ?? 'Пользователь',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),

          // Телефон пользователя
          Text(_user?.phoneNumber ?? '', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  /// Строит селектор активной роли
  Widget _buildActiveRoleSelector() {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Текущая роль', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            if (_userRoles.isEmpty)
              const Text('У вас нет активных ролей')
            else
              DropdownButtonFormField<UserRole>(
                value: _activeRole ?? _userRoles.first,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items:
                    _userRoles.map((role) {
                      return DropdownMenuItem<UserRole>(
                        value: role,
                        child: Row(
                          children: [
                            Icon(_roleManager.getRoleIcon(role)),
                            const SizedBox(width: 8),
                            Text(_roleManager.getRoleName(role)),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (role) {
                  if (role != null) {
                    _setActiveRole(role);
                  }
                },
              ),

            const SizedBox(height: 8),

            Text(
              'Выберите роль, чтобы переключить функционал приложения.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Строит список ролей с возможностью активации/деактивации
  Widget _buildRolesList() {
    final theme = Theme.of(context);
    final availableRoles = UserRole.values;

    return Column(
      children:
          availableRoles.map((role) {
            final hasRole = _userRoles.contains(role);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                title: Row(
                  children: [
                    Icon(_roleManager.getRoleIcon(role)),
                    const SizedBox(width: 8),
                    Text(_roleManager.getRoleName(role)),
                  ],
                ),
                subtitle: Text(_roleManager.getRoleDescription(role)),
                value: hasRole,
                onChanged:
                    role == UserRole.client
                        ? null // Роль клиента нельзя отключить
                        : (value) {
                          if (value) {
                            _addUserRole(role);
                          } else {
                            _removeUserRole(role);
                          }
                        },
                activeColor: theme.primaryColor,
              ),
            );
          }).toList(),
    );
  }

  /// Строит секцию с основными действиями
  Widget _buildActionsSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text('Финансы'),
          onTap: () {
            if (mounted) {
              context.go('/profile/finances');
            }
          },
        ),
        if (_userRoles.contains(UserRole.owner))
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Мои объекты'),
            onTap: () {
              if (mounted) {
                context.go('/profile/owner-properties');
              }
            },
          ),
        if (_userRoles.contains(UserRole.support))
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Аналитика'),
            onTap: () {
              if (mounted) {
                context.go('/profile/analytics');
              }
            },
          ),
        ListTile(
          leading: const Icon(Icons.support),
          title: const Text('Поддержка'),
          onTap: () {
            if (mounted) {
              context.go('/profile/support');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Настройки'),
          onTap: () {},
        ),
      ],
    );
  }

  /// Строит экран для неавторизованного пользователя
  Widget _buildNotAuthorizedView() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 80,
            color: theme.primaryColor.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text('Вы не авторизованы', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Войдите в свой аккаунт, чтобы\nпользоваться всеми возможностями',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('Войти или зарегистрироваться'),
          ),
        ],
      ),
    );
  }
}
