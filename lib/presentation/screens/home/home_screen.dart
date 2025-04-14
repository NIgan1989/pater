import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/di/service_locator.dart';
import 'package:pater/presentation/screens/search/search_screen.dart';

/// Главный экран приложения
/// Теперь использует SearchContent для отображения контента поиска
class HomeScreen extends StatefulWidget {
  /// Создает экземпляр [HomeScreen]
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = getIt<AuthService>();
    _checkAuth();
  }

  /// Проверяет авторизацию пользователя
  Future<void> _checkAuth() async {
    if (!_authService.isAuthenticated) {
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SearchContent());
  }
}
