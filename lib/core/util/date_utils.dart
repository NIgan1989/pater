import 'package:intl/intl.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Расширение для класса DateTime с утилитами для работы с датами
extension DateTimeExtensions on DateTime {
  /// Форматирование даты в соответствии с установленным форматом
  String formatDate({String? pattern}) {
    return DateFormat(pattern ?? AppConstants.dateFormat).format(this);
  }
  
  /// Форматирование времени в соответствии с установленным форматом
  String formatTime({String? pattern}) {
    return DateFormat(pattern ?? AppConstants.timeFormat).format(this);
  }
  
  /// Форматирование даты и времени в соответствии с установленным форматом
  String formatDateTime({String? pattern}) {
    return DateFormat(pattern ?? AppConstants.dateTimeFormat).format(this);
  }
  
  /// Получение даты без времени
  DateTime get dateOnly {
    return DateTime(year, month, day);
  }
  
  /// Проверка, является ли дата текущей
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  /// Проверка, является ли дата завтрашней
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }
  
  /// Проверка, является ли дата вчерашней
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }
  
  /// Возвращает разницу между датами в днях
  int daysDifference(DateTime other) {
    final thisMidnight = dateOnly;
    final otherMidnight = other.dateOnly;
    final difference = thisMidnight.difference(otherMidnight).inDays;
    return difference;
  }
  
  /// Добавляет указанное количество дней к дате
  DateTime addDays(int days) {
    return add(Duration(days: days));
  }
  
  /// Добавляет указанное количество недель к дате
  DateTime addWeeks(int weeks) {
    return add(Duration(days: weeks * 7));
  }
  
  /// Добавляет указанное количество месяцев к дате
  DateTime addMonths(int months) {
    var newMonth = month + months;
    var newYear = year;
    
    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }
    
    while (newMonth < 1) {
      newMonth += 12;
      newYear -= 1;
    }
    
    var newDay = day;
    final daysInMonth = DateTime(newYear, newMonth + 1, 0).day;
    
    if (newDay > daysInMonth) {
      newDay = daysInMonth;
    }
    
    return DateTime(newYear, newMonth, newDay, hour, minute, second, millisecond, microsecond);
  }
  
  /// Получает первый день месяца
  DateTime get firstDayOfMonth {
    return DateTime(year, month, 1);
  }
  
  /// Получает последний день месяца
  DateTime get lastDayOfMonth {
    return DateTime(year, month + 1, 0);
  }
  
  /// Получает первый день недели (понедельник)
  DateTime get firstDayOfWeek {
    int difference = weekday - 1;
    return subtract(Duration(days: difference));
  }
  
  /// Получает последний день недели (воскресенье)
  DateTime get lastDayOfWeek {
    int difference = 7 - weekday;
    return add(Duration(days: difference));
  }
  
  /// Интеллектуальное форматирование даты (сегодня, вчера, завтра или обычная дата)
  String smartFormat({bool includeTime = false}) {
    if (isToday) {
      return includeTime ? 'Сегодня, ${formatTime()}' : 'Сегодня';
    } else if (isTomorrow) {
      return includeTime ? 'Завтра, ${formatTime()}' : 'Завтра';
    } else if (isYesterday) {
      return includeTime ? 'Вчера, ${formatTime()}' : 'Вчера';
    } else {
      return includeTime ? formatDateTime() : formatDate();
    }
  }
} 