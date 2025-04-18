import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // Логика проверки аутентификации удалена, так как реализована в _redirectLogic роутера
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SearchContent());
  }
}
