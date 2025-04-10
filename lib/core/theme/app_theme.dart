import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:pater/core/util/color_utils.dart';

/// Класс для управления темами приложения
class AppTheme {
  // Новая цветовая схема, использующая константы из Real Estate App
  static const Color _primaryColorLight =
      AppConstants.darkBlue; // Темно-синий как основной цвет
  static const Color _accentColorLight =
      AppConstants.orange; // Оранжевый как акцентный цвет
  static const Color _surfaceColorLight = AppConstants.white;
  static const Color _errorColorLight = Color(
    0xFFEA5455,
  ); // Красный для ошибок и статуса "забронировано"
  static const Color _onPrimaryColorLight = AppConstants.white;
  static const Color _onSurfaceColorLight = AppConstants.darkBlue;

  // Статусные цвета
  static const Color statusAvailableLight =
      AppConstants.green; // Зеленый для статуса "доступно"
  static const Color statusBookedLight = Color(
    0xFFEA5455,
  ); // Красный для статуса "забронировано"
  static const Color statusCleaningLight = Color(
    0xFFFFCB33,
  ); // Желтый для статуса "уборка"

  static const Color _surfaceColorDark = Color(0xFF1E1E1E);
  static const Color _errorColorDark = Color(0xFFEA5455);
  static const Color _onPrimaryColorDark = AppConstants.darkBlue;
  static const Color _onSurfaceColorDark = AppConstants.white;

  // Статусные цвета для темной темы
  static const Color statusAvailableDark = AppConstants.green;
  static const Color statusBookedDark = Color(0xFFEA5455);
  static const Color statusCleaningDark = Color(0xFFFFCB33);

  // Статусные цвета для публичного API
  static const Color statusAvailable = AppConstants.green;
  static const Color statusBooked = Color(0xFFEA5455);
  static const Color statusCleaning = Color(0xFFFFCB33);

  // Цвета текста для лучшей читаемости
  static const Color _primaryTextColor = AppConstants.darkBlue;
  static const Color _secondaryTextColor = Color(
    0xFF2A374D,
  ); // Более темный, чем полупрозрачный darkBlue

  // Создаем текстовые стили на основе современных шрифтов
  static TextTheme _createTextTheme(Color textColor, Color secondaryTextColor) {
    // Используем локальный шрифт Inter вместо Google Fonts
    const fontFamily = 'Inter';

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28.0, // Уменьшаем с 32.0
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24.0, // Уменьшаем с 28.0
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20.0, // Уменьшаем с 22.0
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -0.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18.0, // Уменьшаем с 20.0
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -0.25,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16.0, // Уменьшаем с 18.0
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.25,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16.0, // Уменьшаем с 18.0
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.25,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15.0, // Уменьшаем с 16.0
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.25,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: -0.25,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15.0, // Уменьшаем с 16.0
        color: textColor,
        letterSpacing: 0,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.0,
        color: secondaryTextColor,
        letterSpacing: 0,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.0,
        color: secondaryTextColor,
        letterSpacing: 0,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14.0, // Уменьшаем с 16.0
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.0, // Уменьшаем с 14.0
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11.0, // Уменьшаем с 12.0
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
        letterSpacing: 0,
      ),
    );
  }

  /// Получение светлой темы
  static ThemeData get lightTheme {
    // Создаем полупрозрачные варианты цветов
    final primaryLight70 = _primaryColorLight.withValues(alpha: 0.7);
    final primaryLight50 = _primaryColorLight.withValues(alpha: 0.5);
    final primaryLight30 = _primaryColorLight.withValues(alpha: 0.3);
    final primaryLight10 = _primaryColorLight.withValues(alpha: 0.1);

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'Inter', // Устанавливаем шрифт по умолчанию
      colorScheme: ColorScheme.light(
        primary: _primaryColorLight,
        primaryContainer: primaryLight30,
        secondary: _accentColorLight,
        secondaryContainer: primaryLight10,
        tertiary: primaryLight70,
        tertiaryContainer: primaryLight50,
        surface: _surfaceColorLight,
        error: _errorColorLight,
        onPrimary: _onPrimaryColorLight,
        onSurface: _onSurfaceColorLight,
      ),
      scaffoldBackgroundColor: AppConstants.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.white,
        foregroundColor: AppConstants.darkBlue,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18.0, // Уменьшаем размер заголовка AppBar
          fontWeight: FontWeight.bold,
          color: AppConstants.darkBlue,
          letterSpacing: -0.25,
        ),
        iconTheme: IconThemeData(
          color: AppConstants.darkBlue,
          size: AppConstants.iconSizeM,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: AppConstants.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColorLight,
          foregroundColor: _onPrimaryColorLight,
          elevation: 0,
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingL,
            vertical: AppConstants.paddingM,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15.0, // Уменьшаем с 16.0
            fontWeight: FontWeight.bold,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: _primaryColorLight,
          elevation: 0,
          side: const BorderSide(color: _primaryColorLight, width: 1.5),
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingL,
            vertical: AppConstants.paddingM,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: AppConstants.fontSizeBody,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColorLight,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: AppConstants.fontSizeBody,
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingM,
            vertical: AppConstants.paddingS,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.grey.withValues(alpha: 0.2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingL,
          vertical: AppConstants.paddingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: const BorderSide(
            color: AppConstants.darkBlue,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: _errorColorLight, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          borderSide: BorderSide(color: _errorColorLight, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: AppConstants.fontSizeBody,
          fontWeight: FontWeight.w500,
          color: AppConstants.darkGrey,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: AppConstants.fontSizeBody,
          fontWeight: FontWeight.w400,
          color: Color(0xFF767676), // Более темный серый цвет без прозрачности
        ),
      ),
      textTheme: _createTextTheme(_primaryTextColor, _secondaryTextColor),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceColorLight,
        selectedItemColor: _primaryColorLight,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  /// Получение темной темы
  static ThemeData get darkTheme {
    // Создаем полупрозрачные варианты цветов для темной темы
    final primaryDark70 = _primaryColorLight.withValues(alpha: 0.7);
    final primaryDark50 = _primaryColorLight.withValues(alpha: 0.5);
    final primaryDark30 = _primaryColorLight.withValues(alpha: 0.3);
    final primaryDark10 = _primaryColorLight.withValues(alpha: 0.1);

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Inter', // Устанавливаем шрифт по умолчанию
      colorScheme: ColorScheme.dark(
        primary:
            _primaryColorLight, // Используем тот же основной цвет для консистентности
        primaryContainer: primaryDark30,
        secondary: _accentColorLight, // Используем тот же акцентный цвет
        secondaryContainer: primaryDark10,
        tertiary: primaryDark70,
        tertiaryContainer: primaryDark50,
        surface: _surfaceColorDark,
        error: _errorColorDark,
        onPrimary: _onPrimaryColorDark,
        onSurface: _onSurfaceColorDark,
      ),
      scaffoldBackgroundColor: _surfaceColorDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceColorDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: _onSurfaceColorDark,
          letterSpacing: -0.25,
        ),
        iconTheme: IconThemeData(
          color: _onSurfaceColorDark,
          size: AppConstants.iconSizeM,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.2),
      ),
      textTheme: _createTextTheme(_onSurfaceColorDark, Colors.grey[300]!),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColorLight,
          foregroundColor: _onPrimaryColorDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingL,
            vertical: AppConstants.paddingM,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15.0,
            fontWeight: FontWeight.bold,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryColorLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryColorLight,
          side: const BorderSide(color: _primaryColorLight, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(
            0,
            48,
          ), // Высота кнопок 48px согласно требованиям
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primaryColorLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _errorColorDark, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        // Обновлённая высота поля ввода (52px согласно требованиям)
        isDense: false,
        constraints: const BoxConstraints(minHeight: 52, maxHeight: 52),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: AppConstants.fontSizeBody,
          fontWeight: FontWeight.w400,
          color: Color(0xFF767676), // Более темный серый цвет без прозрачности
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surfaceColorDark,
        selectedItemColor: _primaryColorLight,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  /// Получение статусного цвета доступности в зависимости от темы
  static Color getStatusColor(BuildContext context, String status) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    switch (status.toLowerCase()) {
      case 'available':
        return isDarkTheme ? statusAvailableDark : statusAvailableLight;
      case 'booked':
        return isDarkTheme ? statusBookedDark : statusBookedLight;
      case 'cleaning':
        return isDarkTheme ? statusCleaningDark : statusCleaningLight;
      default:
        return isDarkTheme
            ? Colors.grey.withValues(alpha: 0.7)
            : Colors.grey.withValues(alpha: 0.7);
    }
  }

  /// Создает полупрозрачный вариант цвета
  static Color withOpacity(Color color, double opacity) {
    return color.withAlpha(ColorUtils.alphaFromOpacity(opacity));
  }

  /// Создает полупрозрачный вариант цвета на основе процентов
  static Color withOpacityPercent(Color color, int percent) {
    return color.withAlpha(ColorUtils.alphaFromPercent(percent));
  }
}
