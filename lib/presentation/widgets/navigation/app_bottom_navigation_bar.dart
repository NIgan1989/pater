import 'package:flutter/material.dart';
import 'package:pater/domain/entities/user_role.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Улучшенная нижняя навигационная панель приложения с анимациями
class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final UserRole userRole;
  final bool showLabels;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.userRole,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.navBarHeight,
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withAlpha(153), // ~60% opacity
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: showLabels,
        showUnselectedLabels: showLabels,
        items: _getNavigationItems(),
      ),
    );
  }

  /// Возвращает элементы навигационной панели в зависимости от активной роли
  List<BottomNavigationBarItem> _getNavigationItems() {
    // Базовые элементы, которые всегда присутствуют
    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.search_outlined),
        activeIcon: Icon(Icons.search),
        label: 'Поиск',
      ),
    ];

    // Элемент зависит от роли
    switch (userRole) {
      case UserRole.client:
        items.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Поездки',
          ),
        );
        break;
      case UserRole.owner:
        items.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Объекты',
          ),
        );
        break;
      case UserRole.cleaner:
        items.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.cleaning_services_outlined),
            activeIcon: Icon(Icons.cleaning_services),
            label: 'Уборки',
          ),
        );
        break;
      case UserRole.support:
        items.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.support_agent_outlined),
            activeIcon: Icon(Icons.support_agent),
            label: 'Поддержка',
          ),
        );
        break;
      case UserRole.admin:
        items.add(
          const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Управление',
          ),
        );
        break;
    }

    // Третий элемент зависит от роли (Избранное или Бронирования)
    if (userRole == UserRole.owner) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_border_outlined),
          activeIcon: Icon(Icons.bookmark),
          label: 'Брони',
        ),
      );
    } else {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.favorite_border_outlined),
          activeIcon: Icon(Icons.favorite),
          label: 'Избранное',
        ),
      );
    }

    // Общие элементы для всех ролей
    items.addAll([
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat_outlined),
        activeIcon: Icon(Icons.chat),
        label: 'Чаты',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Профиль',
      ),
    ]);

    return items;
  }
}
