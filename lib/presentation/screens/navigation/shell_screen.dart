import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/domain/entities/user.dart';
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
  final AuthService _authService = AuthService();
  late User? _user;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем пользователя при изменении зависимостей
    final currentUser = _authService.currentUser;
    if (_user?.id != currentUser?.id) {
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
          context.goNamed('all_bookings');
        } else if (role == UserRole.owner) {
          context.goNamed('properties_list');
        } else if (role == UserRole.cleaner) {
          context.goNamed('cleaner_workboard');
        }
        break;
      case 2: // Избранное (для клинера - расписание)
        if (role == UserRole.cleaner) {
          context.goNamed('booking_calendar');
        } else {
          context.goNamed('favorites');
        }
        break;
      case 3: // Сообщения
        context.goNamed('messages');
        break;
      case 4: // Профиль
        context.goNamed('profile');
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
