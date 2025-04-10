import 'package:flutter/material.dart';

/// Класс с константами приложения
class AppConstants {
  /// Задержка для анимаций
  static const Duration animationDuration = Duration(milliseconds: 300);

  /// Размеры отступов
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  /// Стандартный отступ для приложения (из Real Estate App)
  static const double appPadding = 30.0;

  /// Размеры радиусов
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;

  /// Размеры элементов
  static const double buttonHeight =
      54.0; // Увеличено для соответствия дизайну Real Estate
  static const double inputHeight =
      56.0; // Увеличено для соответствия дизайну Real Estate
  static const double cardHeight = 180.0; // Увеличено для карточек недвижимости
  static const double listItemHeight =
      80.0; // Увеличено для соответствия дизайну Real Estate
  static const double bottomNavBarHeight =
      70.0; // Увеличено для более крупных кнопок
  static const double appBarHeight =
      60.0; // Увеличено для более современного вида

  /// Размеры иконок
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;

  /// Размеры аватаров
  static const double avatarSizeSmall = 32.0;
  static const double avatarSizeMedium = 48.0;
  static const double avatarSizeLarge = 64.0;
  static const double avatarSizeXLarge = 96.0;

  /// Значения размеров шрифта
  static const double fontSizeHeading =
      28.0; // Увеличено для соответствия дизайну Real Estate
  static const double fontSizeHeadingSecondary = 22.0; // Увеличено
  static const double fontSizeSubheading = 20.0; // Увеличено
  static const double fontSizeL = 18.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeSecondary = 14.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeXSmall = 10.0; // Добавлено для мелких меток

  /// API URL
  static const String apiBaseUrl = 'https://api.pater.app/v1';

  /// Ключи хранилища
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String roleKey = 'user_role';
  static const String themeKey = 'app_theme';
  static const String localeKey = 'app_locale';

  /// Роли пользователей
  static const String roleClient = 'client';
  static const String roleOwner = 'owner';
  static const String roleCleaner = 'cleaner';

  /// Статусы жилья
  static const String propertyStatusAvailable = 'available';
  static const String propertyStatusBooked = 'booked';
  static const String propertyStatusCleaning = 'cleaning';

  /// Статусы запросов на уборку (для владельцев)
  static const String cleaningRequestDraft = 'draft';
  static const String cleaningRequestPending = 'pending';
  static const String cleaningRequestActive = 'active';
  static const String cleaningRequestCompleted = 'completed';
  static const String cleaningRequestCancelled = 'cancelled';

  /// Статусы заявок на уборку (для уборщиков)
  static const String cleaningJobWaiting = 'waiting';
  static const String cleaningJobInProgress = 'in_progress';
  static const String cleaningJobCompleted = 'completed';

  /// Лимиты
  static const int maxPhotosPerProperty = 10;
  static const int maxGuestsDefault = 10;
  static const int maxRooms = 20;
  static const int messageMaxLength = 1000;

  /// Ключи сервисов
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// Константы для файловой системы
  static const String imagesFolderName = 'images';
  static const String userAvatarsPath = 'users/avatars';
  static const String propertyImagesPath = 'properties/images';
  static const String cleaningImagesPath = 'cleaning/images';

  /// Формат даты и времени
  static const String dateFormat = 'dd.MM.yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd.MM.yyyy HH:mm';

  /// Тени
  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(20),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(26),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];

  /// Анимации
  static const Duration animationDurationShort = Duration(milliseconds: 150);
  static const Duration animationDurationMedium = Duration(milliseconds: 300);
  static const Duration animationDurationLong = Duration(milliseconds: 500);

  /// Ширина кнопок
  static const double buttonWidthNormal = 200.0;
  static const double buttonWidthWide = 280.0;

  /// Текстовые константы
  static const String appName = 'Pater';
  static const String appDescription =
      'Аренда жилья с профессиональной уборкой';

  /// Переходы между экранами
  static PageRouteBuilder<dynamic> fadeTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: animationDurationMedium,
    );
  }

  static PageRouteBuilder<dynamic> slideTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = const Offset(1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.easeInOut;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: animationDurationMedium,
    );
  }

  /// Константы для авторизации
  static const int pinCodeLength = 4;
  static const int smsCodeLength = 6;
  static const int phoneNumberMaxLength = 18; // +X (XXX) XXX-XX-XX
  static const String phoneNumberMask = '+7 (###) ###-##-##';
  static const String phoneNumberHint = '+7 (XXX) XXX-XX-XX';

  /// Время задержки для повторной отправки SMS кода (в секундах)
  static const int smsResendDelaySeconds = 60;

  /// Максимальное количество попыток ввода PIN-кода
  static const int maxPinAttempts = 3;

  /// Ключи для SharedPreferences (авторизация)
  static const String lastUserIdKey = 'last_user_id';
  static const String userDisplayNameKey = 'user_display_name';
  static const String userAvatarUrlKey = 'user_avatar_url';
  static const String skipPinAuthKey = 'skip_pin_auth';

  /// Основные цвета Real Estate дизайна
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color darkBlue = Color.fromRGBO(19, 26, 44, 1.0);
  static const Color blue = Color.fromRGBO(31, 160, 255, 1.0);
  static const Color green = Color.fromRGBO(22, 160, 133, 1.0);
  static const Color orange = Color.fromRGBO(255, 140, 0, 1.0);
  static const Color grey = Color.fromRGBO(225, 225, 225, 1.0);
  static const Color darkGrey = Color.fromRGBO(125, 125, 125, 1.0);
  static const Color lightGrey = Color.fromRGBO(245, 245, 245, 1.0);
  static const Color accentColor = Color.fromRGBO(255, 0, 0, 1.0);

  /// Радиусы для элементов
  static const double radiusCircular = 20.0;

  /// Цвета активных/неактивных элементов
  static const Color activeColor = darkBlue;
  static const Color inactiveColor = darkGrey;

  /// Тени для элементов
  static List<BoxShadow> containerShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(26),
      spreadRadius: 0,
      blurRadius: 10,
      offset: const Offset(0, 5),
    ),
  ];

  /// Тени для карточек
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(13),
      spreadRadius: 0,
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ];

  /// Градиенты для кнопок
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [blue, darkBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Градиент для фона карточек с изображениями
  static const LinearGradient darkOverlayGradient = LinearGradient(
    colors: [Colors.transparent, Colors.black54],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Добавляем константы для DraggableScrollableSheet
  static const double bottomSheetMinSize = 0.08; // Уменьшено с 0.12
  static const double bottomSheetInitialSize = 0.35; // Увеличено с 0.3
  static const double bottomSheetMaxSize = 0.9; // Максимальный размер

  // Унифицированные размеры для BottomNavigationBar
  static const double navBarHeight =
      60.0; // Стандартная высота для BottomNavigationBar
}
