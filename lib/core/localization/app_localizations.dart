import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pater/core/util/logger.dart';

/// Класс для локализации приложения
class AppLocalizations {
  final Locale locale;
  static late AppLocalizations current;
  final AppLogger _logger = AppLogger();
  
  AppLocalizations(this.locale);
  
  // Поддерживаемые локали
  static const List<Locale> supportedLocales = [
    Locale('ru', 'RU'),
    Locale('en', 'US'),
    Locale('kk', 'KZ'),
  ];
  
  // Делегат для локализации
  static const AppLocalizationsDelegate delegate = AppLocalizationsDelegate();
  
  // Переводы
  Map<String, String> _localizedStrings = {};
  
  // Загрузка локализованных строк из JSON файла
  Future<bool> load() async {
    try {
      // Загружаем языковой файл из assets
      final jsonString = await rootBundle.loadString('assets/lang/${locale.languageCode}.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      
      // Устанавливаем текущий экземпляр для глобального доступа
      current = this;
      
      // Устанавливаем локаль для Intl
      Intl.defaultLocale = locale.toString();
      
      _logger.info('Локализация загружена: ${locale.languageCode}');
      return true;
    } catch (e) {
      _logger.error('Ошибка при загрузке локализации: $e');
      
      // В случае ошибки загружаем базовые строки
      _loadFallbackStrings();
      return false;
    }
  }
  
  /// Загружает резервные строки в случае ошибки
  void _loadFallbackStrings() {
    _localizedStrings = {
      'app_name': 'Pater',
      'error': 'Ошибка',
      'ok': 'OK',
      'cancel': 'Отмена',
      'loading': 'Загрузка...',
      'retry': 'Повторить',
      'no_connection': 'Нет подключения к интернету',
      'unknown_error': 'Произошла непредвиденная ошибка',
    };
  }
  
  // Простой метод для получения локализованной строки
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
  
  // Метод для перевода с параметрами
  String translateWithParams(String key, Map<String, String> params) {
    String translated = translate(key);
    
    params.forEach((paramKey, paramValue) {
      translated = translated.replaceAll('{$paramKey}', paramValue);
    });
    
    return translated;
  }
  
  // Форматирование даты в соответствии с текущей локалью
  String formatDate(DateTime date, {String? pattern}) {
    final format = pattern ?? 'dd.MM.yyyy';
    return DateFormat(format, locale.toString()).format(date);
  }
  
  // Форматирование времени в соответствии с текущей локалью
  String formatTime(DateTime time, {String? pattern}) {
    final format = pattern ?? 'HH:mm';
    return DateFormat(format, locale.toString()).format(time);
  }
  
  // Форматирование даты и времени в соответствии с текущей локалью
  String formatDateTime(DateTime dateTime, {String? pattern}) {
    final format = pattern ?? 'dd.MM.yyyy HH:mm';
    return DateFormat(format, locale.toString()).format(dateTime);
  }
  
  // Форматирование денежных сумм в соответствии с текущей локалью
  String formatCurrency(double amount, {String? currencySymbol}) {
    final symbol = currencySymbol ?? '₸';
    final formatted = NumberFormat.currency(
      locale: locale.toString(),
      symbol: '',
      decimalDigits: 0,
    ).format(amount);
    
    return '$formatted $symbol';
  }
  
  // Вспомогательный метод для получения экземпляра из контекста
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
}

/// Делегат для локализации приложения
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['ru', 'en', 'kk'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }
  
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
} 