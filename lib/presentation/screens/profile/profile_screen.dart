import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/auth/role_manager.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/presentation/widgets/app_bar/custom_app_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Экран профиля пользователя
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Получаем зарегистрированные синглтоны через GetIt
  final _authService = GetIt.instance.get<AuthService>();
  final _roleManager = GetIt.instance.get<RoleManager>();

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
        // Пытаемся подгрузить данные пользователя из Firestore напрямую
        try {
          // Получаем дополнительную информацию из Firestore
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.id)
                  .get();

          if (userDoc.exists) {
            // Получаем данные
            final userData = userDoc.data() as Map<String, dynamic>;

            // Создаем обновленного пользователя с данными из Firestore
            final String firstName =
                userData['firstName'] ??
                userData['first_name'] ??
                user.firstName;
            final String lastName =
                userData['lastName'] ?? userData['last_name'] ?? user.lastName;

            // Обновляем пользователя
            final updatedUser = user.copyWith(
              firstName: firstName,
              lastName: lastName,
              email: userData['email'] ?? user.email,
              avatarUrl: userData['avatar_url'] ?? user.avatarUrl,
            );

            // Сохраняем обновленного пользователя
            _user = updatedUser;

            debugPrint('Данные пользователя успешно загружены из Firestore');
            debugPrint('Имя: $firstName, Фамилия: $lastName');
          } else {
            _user = user;
            debugPrint('Документ пользователя не найден в Firestore');
          }
        } catch (e) {
          // В случае ошибки используем то, что есть
          _user = user;
          debugPrint('Ошибка при загрузке данных из Firestore: $e');
        }

        // Получаем все роли пользователя и фильтруем admin и support
        List<UserRole> roles = await _roleManager.getUserRoles(user.id);
        roles =
            roles
                .where(
                  (role) => role != UserRole.admin && role != UserRole.support,
                )
                .toList();

        // Если ролей нет, добавляем роль клиента
        if (roles.isEmpty) {
          roles.add(UserRole.client);
        }

        // Получаем активную роль
        var activeRole = await _roleManager.getActiveRole();

        // Если активная роль - admin или support, меняем на client
        if (activeRole == UserRole.admin || activeRole == UserRole.support) {
          activeRole = UserRole.client;
          await _roleManager.setActiveRole(UserRole.client);
        }

        setState(() {
          // _user уже установлен выше
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
      // Устанавливаем активную роль и уведомляем AuthService
      await _roleManager.setActiveRole(role);
      await _authService.updateActiveRole(role);

      // После асинхронной операции проверяем, что виджет все еще в дереве
      if (!mounted) return;

      setState(() {
        _activeRole = role;
      });

      // Обновляем интерфейс по активной роли
      if (role != _user!.role) {
        // Передача обновленной роли в другой метод без использования контекста
        await _updateUserRole(role);
      }

      // Перенаправляем на соответствующий экран в зависимости от роли
      _navigateToHomeScreen(role);
    } catch (e) {
      debugPrint('Ошибка при установке активной роли: $e');
    }
  }

  /// Перенаправляет пользователя на главный экран в зависимости от роли
  void _navigateToHomeScreen(UserRole role) {
    if (!mounted) return;

    switch (role) {
      case UserRole.client:
        context.go('/bookings');
        break;
      case UserRole.owner:
        context.go('/properties');
        break;
      case UserRole.cleaner:
        context.go('/cleanings');
        break;
      case UserRole.support:
        context.go('/profile/support');
        break;
      case UserRole.admin:
        context.go('/bookings'); // Как для админа указано в shell_screen
        break;
    }
  }

  /// Обновляет роль пользователя в сервисе авторизации
  Future<void> _updateUserRole(UserRole role) async {
    if (_user == null) return;

    try {
      // Создаем обновленного пользователя с новой ролью
      final updatedUser = _user!.copyWith(role: role);

      // Обновляем пользователя в сервисе авторизации
      // Метод возвращает void, поэтому мы просто вызываем его без проверки результата
      await _authService.updateUserRole(_user!.id, role);

      // Проверяем, что виджет все еще в дереве после асинхронной операции
      if (!mounted) return;

      // Обновляем локальное состояние пользователя
      setState(() {
        _user = updatedUser;
      });
    } catch (e) {
      debugPrint('Ошибка при обновлении роли пользователя: $e');
    }
  }

  /// Добавляет новую роль пользователю
  Future<void> _addUserRole(UserRole role) async {
    if (_user == null) return;

    try {
      // Метод возвращает void
      await _roleManager.addUserRole(_user!.id, role);

      // Проверяем, что виджет все еще в дереве после асинхронной операции
      if (!mounted) return;

      // Обновляем список ролей
      final roles = await _roleManager.getUserRoles(_user!.id);

      // Еще раз проверяем mounted после второй асинхронной операции
      if (!mounted) return;

      setState(() {
        _userRoles = roles;
      });
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
      // Метод возвращает void
      await _roleManager.removeUserRole(_user!.id, role);

      // Проверяем, что виджет все еще в дереве после асинхронной операции
      if (!mounted) return;

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
    } catch (e) {
      debugPrint('Ошибка при удалении роли пользователя: $e');
    }
  }

  /// Преобразует UserRole в читаемую строку
  String roleToString(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'Клиент';
      case UserRole.owner:
        return 'Владелец';
      case UserRole.cleaner:
        return 'Клининг';
      case UserRole.admin:
        return 'Администратор';
      case UserRole.support:
        return 'Служба поддержки';
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
            onPressed: () {
              _handleSignOut();
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

  /// Обрабатывает выход из аккаунта
  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        GoRouter.of(context).go('/home');
      }
    } catch (e) {
      debugPrint('Ошибка при выходе из аккаунта: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при выходе: $e')));
      }
    }
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

  /// Строит выпадающее меню для выбора активной роли
  Widget _buildActiveRoleSelector() {
    // Фильтруем роли, исключая admin и support
    final availableRoles =
        _userRoles
            .where((role) => role != UserRole.admin && role != UserRole.support)
            .toList();

    // Если нет доступных ролей после фильтрации, добавляем роль клиента
    if (availableRoles.isEmpty) {
      return const Text('Нет доступных ролей');
    }

    // Проверяем, что активная роль входит в отфильтрованный список
    if (!availableRoles.contains(_activeRole)) {
      // Если активная роль - admin или support, заменяем на client
      if (_activeRole == UserRole.admin || _activeRole == UserRole.support) {
        _roleManager.setActiveRole(UserRole.client);
        _activeRole = UserRole.client;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Активная роль',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButton<UserRole>(
            value: _activeRole,
            isExpanded: true,
            underline: const SizedBox(),
            items:
                availableRoles.map((role) {
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(roleToString(role)),
                  );
                }).toList(),
            onChanged: (value) async {
              if (value != null) {
                await _roleManager.setActiveRole(value);
                setState(() {
                  _activeRole = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  /// Строит список ролей с возможностью активации/деактивации
  Widget _buildRolesList() {
    final theme = Theme.of(context);
    // Используем только роли клиент, владелец и клининг
    final availableRoles = [UserRole.client, UserRole.owner, UserRole.cleaner];

    return Column(
      children:
          availableRoles.map((role) {
            final hasRole = _userRoles.contains(role);

            // Получаем название роли с учетом переименования "уборщик" в "клининг"
            String roleName = '';
            if (role == UserRole.cleaner) {
              roleName = 'Клининг';
            } else {
              roleName = _roleManager.getRoleName(role);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                title: Row(children: [Text(roleName)]),
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
        // Общие разделы для всех ролей
        ListTile(
          leading: const Icon(Icons.account_balance_wallet),
          title: const Text('Финансы'),
          onTap: () {
            if (mounted) {
              context.go('/profile/finances');
            }
          },
        ),

        // Заявки/бронирования - для всех ролей, но с разными экранами
        if (_user != null)
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: Text(
              _user!.role == UserRole.owner
                  ? 'Бронирования объектов'
                  : _user!.role == UserRole.cleaner
                  ? 'Заявки на уборку'
                  : 'Мои бронирования',
            ),
            onTap: () {
              if (mounted) {
                if (_user!.role == UserRole.owner) {
                  context.go('/owner-bookings');
                } else if (_user!.role == UserRole.cleaner) {
                  context.go('/cleanings');
                } else {
                  context.go('/bookings');
                }
              }
            },
          ),

        // Разделы для владельцев
        if (_userRoles.contains(UserRole.owner))
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Мои объекты'),
            onTap: () {
              if (mounted) {
                context.go('/properties');
              }
            },
          ),

        // Избранное - для клиентов и владельцев
        if (_user?.role == UserRole.client || _user?.role == UserRole.owner)
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Избранное'),
            onTap: () {
              if (mounted) {
                context.go('/favorites');
              }
            },
          ),

        // Разделы для клининга
        if (_userRoles.contains(UserRole.cleaner))
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Календарь уборок'),
            onTap: () {
              if (mounted) {
                context.go('/calendar');
              }
            },
          ),

        // Сообщения - для всех
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('Сообщения'),
          onTap: () {
            if (mounted) {
              context.go('/messages');
            }
          },
        ),

        // Поддержка - для всех
        ListTile(
          leading: const Icon(Icons.support),
          title: const Text('Поддержка'),
          onTap: () {
            if (mounted) {
              context.go('/profile/support');
            }
          },
        ),

        // Настройки - для всех
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
