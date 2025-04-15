import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/presentation/screens/auth/auth_screen.dart';
import 'package:pater/presentation/screens/auth/sms_code_screen.dart';
import 'package:pater/presentation/screens/auth/pin_auth_screen.dart';
import 'package:pater/presentation/screens/auth/create_pin_screen.dart';
import 'package:pater/presentation/screens/property/property_details_screen.dart';
import 'package:pater/presentation/screens/profile/profile_screen.dart';
import 'package:pater/presentation/screens/profile/booking_calendar_screen.dart';
import 'package:pater/presentation/screens/profile/analytics_screen.dart';
import 'package:pater/presentation/screens/cleaning/cleaner_workboard_screen.dart';
import 'package:pater/presentation/screens/bookings/client_bookings_screen.dart';
import 'package:pater/presentation/screens/bookings/support_tickets_screen.dart';
import 'package:pater/presentation/screens/favorites/favorites_screen.dart';
import 'package:pater/presentation/screens/messages/messages_screen.dart';
import 'package:pater/presentation/screens/chat/chat_screen.dart';
import 'package:pater/presentation/screens/payment/payment_screen.dart';
import 'package:pater/presentation/screens/profile/finances_screen.dart';
import 'package:pater/presentation/screens/bookings/booking_details_screen.dart';
import 'package:pater/presentation/screens/property/add_property_screen.dart';
import 'package:pater/presentation/screens/search/search_screen.dart';
import 'package:pater/presentation/screens/navigation/shell_screen.dart';
import 'package:pater/presentation/screens/property/owner_properties_screen.dart';
import 'package:pater/presentation/screens/property/edit_property_screen.dart';
import 'package:pater/presentation/screens/bookings/owner_bookings_screen.dart';
import 'package:pater/core/di/service_locator.dart';

/// Экран для отображения ошибок
class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ошибка')),
      body: Center(child: Text(error)),
    );
  }
}

/// Наблюдатель для логирования навигации
class _NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint(
      'Навигация: ${previousRoute?.settings.name} -> ${route.settings.name}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint(
      'Навигация (возврат): ${route.settings.name} -> ${previousRoute?.settings.name}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Навигация (удаление): ${route.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint(
      'Навигация (замена): ${oldRoute?.settings.name} -> ${newRoute?.settings.name}',
    );
  }
}

/// Вспомогательная функция для создания наблюдателя навигации
NavigatorObserver _createNavigationObserver() {
  return _NavigationObserver();
}

/// Класс, управляющий маршрутизацией в приложении
class AppRouter {
  static final AuthService _authService = getIt<AuthService>();

  // Навигационные shell ключи для основных вкладок
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'home');
  static final GlobalKey<NavigatorState> _bookingsNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'bookings');
  static final GlobalKey<NavigatorState> _favoritesNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'favorites');
  static final GlobalKey<NavigatorState> _messagesNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'messages');
  static final GlobalKey<NavigatorState> _profileNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'profile');

  /// Создает экземпляр маршрутизатора Go Router
  static GoRouter get router => GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/home',
    observers: [
      // Наблюдатель для отслеживания навигации
      _createNavigationObserver(),
    ],
    navigatorKey: _rootNavigatorKey,
    routes: [
      // Корневой маршрут (стартовый экран выбора аккаунта)
      GoRoute(path: '/', redirect: (_, __) => '/home'),

      // Маршрут для авторизации
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
        routes: [
          GoRoute(
            path: 'sms',
            name: 'sms_verification',
            builder: (context, state) {
              final Map<String, dynamic> extra =
                  state.extra as Map<String, dynamic>? ?? {};
              final String phoneNumber = extra['phoneNumber'] as String? ?? '';
              final String verificationId =
                  extra['verificationId'] as String? ?? '';

              return SmsCodeScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
              );
            },
          ),
          GoRoute(
            path: 'pin',
            name: 'pin_auth',
            builder: (context, state) {
              final Map<String, dynamic> pinData =
                  state.extra as Map<String, dynamic>? ?? {};
              return PinAuthScreen(pinData: pinData);
            },
          ),
          GoRoute(
            path: 'create-pin',
            name: 'create_pin',
            builder: (context, state) => const CreatePinScreen(),
          ),
        ],
      ),

      // Вкладка "Поиск" / "Главная"
      ShellRoute(
        navigatorKey: _homeNavigatorKey,
        builder:
            (context, state, child) =>
                ShellScreen(selectedIndex: 0, child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const SearchScreen(),
          ),
        ],
      ),

      // Вкладка "Бронирования/Объекты/Уборки" (в зависимости от роли)
      ShellRoute(
        navigatorKey: _bookingsNavigatorKey,
        builder:
            (context, state, child) =>
                ShellScreen(selectedIndex: 1, child: child),
        routes: [
          // Роли клиента: Бронирования
          GoRoute(
            path: '/bookings',
            name: 'all_bookings',
            builder: (context, state) => const ClientBookingsScreen(),
            routes: [
              GoRoute(
                path: ':bookingId',
                name: 'booking_details',
                builder: (context, state) {
                  final bookingId = state.pathParameters['bookingId'] ?? '';
                  return BookingDetailsScreen(bookingId: bookingId);
                },
              ),
            ],
          ),

          // Роли владельца: Объекты
          GoRoute(
            path: '/properties',
            name: 'properties_list',
            builder: (context, state) => const OwnerPropertiesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: 'add_property',
                builder: (context, state) => const AddPropertyScreen(),
              ),
              GoRoute(
                path: ':propertyId',
                name: 'property_details',
                builder: (context, state) {
                  final propertyId = state.pathParameters['propertyId'] ?? '';
                  return PropertyDetailsScreen(
                    propertyId: propertyId,
                    property: null,
                  );
                },
              ),
              GoRoute(
                path: ':propertyId/edit',
                name: 'edit_property',
                builder: (context, state) {
                  final propertyId = state.pathParameters['propertyId'] ?? '';
                  return EditPropertyScreen(propertyId: propertyId);
                },
              ),
              GoRoute(
                path: ':propertyId/bookings',
                name: 'owner_property_bookings',
                builder: (context, state) {
                  return const OwnerBookingsScreen();
                },
              ),
            ],
          ),

          // Роли клинера: Уборки
          GoRoute(
            path: '/cleanings',
            name: 'cleaner_workboard',
            builder: (context, state) => const CleanerWorkboardScreen(),
          ),
        ],
      ),

      // Вкладка "Избранное" (для клинера - "Расписание")
      ShellRoute(
        navigatorKey: _favoritesNavigatorKey,
        builder:
            (context, state, child) =>
                ShellScreen(selectedIndex: 2, child: child),
        routes: [
          GoRoute(
            path: '/favorites',
            name: 'favorites',
            builder: (context, state) => const FavoritesScreen(),
          ),
          GoRoute(
            path: '/calendar',
            name: 'booking_calendar',
            builder: (context, state) => const BookingCalendarScreen(),
          ),
        ],
      ),

      // Вкладка "Сообщения"
      ShellRoute(
        navigatorKey: _messagesNavigatorKey,
        builder:
            (context, state, child) =>
                ShellScreen(selectedIndex: 3, child: child),
        routes: [
          GoRoute(
            path: '/messages',
            name: 'messages',
            builder: (context, state) => const MessagesScreen(),
            routes: [
              GoRoute(
                path: ':chatId',
                name: 'chat',
                builder: (context, state) {
                  final chatId = state.pathParameters['chatId'] ?? '';
                  return ChatScreen(chatId: chatId);
                },
              ),
            ],
          ),
        ],
      ),

      // Вкладка "Профиль"
      ShellRoute(
        navigatorKey: _profileNavigatorKey,
        builder:
            (context, state, child) =>
                ShellScreen(selectedIndex: 4, child: child),
        routes: [
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'finances',
                name: 'finances',
                builder: (context, state) => const FinancesScreen(),
              ),
              GoRoute(
                path: 'analytics',
                name: 'analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
              GoRoute(
                path: 'support',
                name: 'support_tickets',
                builder: (context, state) => const SupportTicketsScreen(),
              ),
              GoRoute(
                path: 'add-property',
                name: 'add_property_profile',
                builder: (context, state) => const AddPropertyScreen(),
              ),
              GoRoute(
                path: 'owner-properties',
                name: 'owner_properties',
                builder: (context, state) => const OwnerPropertiesScreen(),
              ),
              GoRoute(
                path: 'payment/:bookingId',
                name: 'payment',
                builder: (context, state) {
                  final bookingId = state.pathParameters['bookingId'] ?? '';
                  return PaymentScreen(bookingId: bookingId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => ErrorScreen(error: state.error.toString()),
    redirect: _redirectLogic,
  );

  /// Обработка перенаправлений и защита маршрутов
  static Future<String?> _redirectLogic(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isAuthenticated = _authService.isAuthenticated;
    final location = state.uri.path;

    debugPrint(
      '_redirectLogic: проверка маршрута $location, аутентификация: $isAuthenticated',
    );

    // Публичные маршруты, доступные без авторизации
    final publicRoutes = ['/home', '/auth', '/auth/sms'];
    final isPublicRoute =
        publicRoutes.contains(location) ||
        location.startsWith('/auth/') ||
        location.startsWith('/property/');

    // Если это публичный маршрут, не делаем редирект
    if (isPublicRoute) {
      debugPrint(
        '_redirectLogic: публичный маршрут $location, редирект не требуется',
      );
      return null;
    }

    // Проверяем авторизацию для защищенных маршрутов
    if (!isAuthenticated) {
      debugPrint(
        '_redirectLogic: пользователь не авторизован, редирект на /auth',
      );
      return '/auth';
    }

    debugPrint('_redirectLogic: авторизованный доступ к $location разрешен');
    return null; // Нет перенаправления, продолжаем навигацию
  }
}
