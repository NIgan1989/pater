import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Кастомный AppBar с дополнительными возможностями и правильной обработкой кнопки "назад"
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onBackPressed;
  final bool isAuthScreen;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.leading,
    this.bottom,
    this.height = kToolbarHeight,
    this.backgroundColor,
    this.foregroundColor,
    this.onBackPressed,
    this.isAuthScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      automaticallyImplyLeading: showBackButton,
      leading:
          leading ??
          (showBackButton
              ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed:
                    onBackPressed ??
                    () {
                      // Правильная обработка кнопки "назад"
                      if (isAuthScreen) {
                        // Для экранов авторизации
                        final currentRoute = GoRouterState.of(context).uri.path;
                        if (currentRoute == '/auth') {
                          // Если мы на главном экране авторизации, выходим из приложения
                          context.go('/');
                        } else {
                          // Если мы на подэкране авторизации (например, PIN), возвращаемся на auth
                          context.go('/auth');
                        }
                      } else {
                        // Для остальных экранов пробуем pop, если не получается - на home
                        try {
                          context.pop();
                        } catch (e) {
                          debugPrint('Ошибка при возврате: $e');
                          context.go('/home');
                        }
                      }
                    },
              )
              : null),
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }

  @override
  Size get preferredSize =>
      bottom != null
          ? Size.fromHeight(height + bottom!.preferredSize.height)
          : Size.fromHeight(height);
}
