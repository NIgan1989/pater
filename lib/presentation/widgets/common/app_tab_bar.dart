import 'package:flutter/material.dart';

/// Кастомный виджет для отображения вкладок приложения
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<String> tabs;
  final Function(int)? onTap;

  const AppTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      onTap: onTap,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withAlpha(153),
      indicatorColor: Theme.of(context).colorScheme.primary,
      indicatorWeight: 3,
      tabs: tabs.map((tab) => Tab(text: tab)).toList(),
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);
} 