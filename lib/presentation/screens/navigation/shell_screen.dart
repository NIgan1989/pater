import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/domain/entities/user.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/presentation/widgets/navigation/app_bottom_navigation_bar.dart';

/// Базовый shell-экран для унифицированной навигации по приложению
/// Обеспечивает единую нижнюю навигационную панель для всех внутренних экранов
class ShellScreen extends StatefulWidget {
  final Widget child;
  final int selectedIndex;

  const ShellScreen({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final _authService = GetIt.instance.get<AuthService>();
  late User? _user;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
    _authService.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    final currentUser = _authService.currentUser;
    if (_user?.id != currentUser?.id || _user?.role != currentUser?.role) {
      setState(() {
        _user = currentUser;
      });

      // Если изменилась роль пользователя, но не сам ID (т.е. тот же пользователь),
      // перенаправляем на главный экран для новой роли, чтобы обновить контент
      if (_user?.id == currentUser?.id && _user?.role != currentUser?.role) {
        debugPrint(
          'Роль пользователя изменилась. Обновляем интерфейс для роли: ${currentUser?.role}',
        );
        // Переходим на главный экран
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/home');
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем пользователя при изменении зависимостей
    final currentUser = _authService.currentUser;
    if (_user?.id != currentUser?.id || _user?.role != currentUser?.role) {
      setState(() {
        _user = currentUser;
      });
    }
  }

  /// Обработчик нажатия на элемент в нижней навигационной панели
  void _onNavigationItemTap(int index) {
    // Если уже на этом индексе, не выполняем навигацию
    if (widget.selectedIndex == index) {
      return;
    }

    // Проверка авторизации для доступа к профилю
    if (index == 4 && !_authService.isAuthenticated) {
      // Если пользователь не авторизован и пытается получить доступ к профилю
      context.go('/auth');
      return;
    }

    final role = _user?.role ?? UserRole.client;

    switch (index) {
      case 0: // Поиск
        context.go('/home');
        break;
      case 1: // Бронирования/Объекты/Уборки
        if (role == UserRole.client) {
          context.go('/bookings');
        } else if (role == UserRole.owner) {
          context.go('/properties');
        } else if (role == UserRole.cleaner) {
          context.go('/cleanings');
        } else if (role == UserRole.support) {
          // Для роли поддержки показываем тикеты поддержки
          context.go('/profile/support');
        } else if (role == UserRole.admin) {
          // Для роли админа показываем экран управления
          context.go('/bookings');
        }
        break;
      case 2: // Избранное или Бронирования объектов (зависит от роли)
        if (role == UserRole.cleaner) {
          context.go('/calendar');
        } else if (role == UserRole.owner) {
          context.go('/owner-bookings');
        } else {
          context.go('/favorites');
        }
        break;
      case 3: // Сообщения
        context.go('/messages');
        break;
      case 4: // Профиль
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _user?.role ?? UserRole.client;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom:
            false, // Отключаем отступ внизу, чтобы избежать двойного отступа с BottomNavigationBar
        child: widget.child,
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: widget.selectedIndex,
        onTap: _onNavigationItemTap,
        userRole: userRole,
        showLabels: true,
      ),
    );
  }
}
