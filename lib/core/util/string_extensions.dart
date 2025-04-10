/// Расширения для строк
extension StringExtensions on String {
  /// Проверяет, является ли строка электронной почтой
  bool get isEmail {
    final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(this);
  }
  
  /// Проверяет, является ли строка телефонным номером
  bool get isPhoneNumber {
    final phoneRegExp = RegExp(r'^\+?[0-9]{10,15}$');
    return phoneRegExp.hasMatch(this);
  }
  
  /// Возвращает только цифры из строки
  String get digitsOnly {
    return replaceAll(RegExp(r'\D'), '');
  }
  
  /// Капитализирует первую букву строки
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
  
  /// Возвращает инициалы из полного имени (максимум 2 буквы)
  String get initials {
    final parts = trim().split(' ');
    if (parts.length >= 2) {
      final first = parts.first;
      final last = parts.last;
      return '${first.isNotEmpty ? first[0].toUpperCase() : ''}${last.isNotEmpty ? last[0].toUpperCase() : ''}';
    } else if (parts.length == 1 && parts.first.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    return '';
  }
  
  /// Обрезает строку до указанной длины с добавлением многоточия
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }
  
  /// Форматирует телефонный номер в международном формате
  String formatPhoneNumber() {
    final cleaned = digitsOnly;
    if (cleaned.length < 10) return this;
    
    // Если номер начинается с 7, 8 или 9, считаем его российским/казахстанским
    if (cleaned.length == 10) {
      return '+7 (${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6, 8)}-${cleaned.substring(8)}';
    } 
    // Если 11 цифр с кодом страны
    else if (cleaned.length == 11) {
      final withoutCountry = cleaned.substring(1);
      return '+${cleaned[0]} (${withoutCountry.substring(0, 3)}) ${withoutCountry.substring(3, 6)}-${withoutCountry.substring(6, 8)}-${withoutCountry.substring(8)}';
    }
    // Если длинный международный номер
    else {
      return '+${cleaned.substring(0, cleaned.length - 10)} (${cleaned.substring(cleaned.length - 10, cleaned.length - 7)}) ${cleaned.substring(cleaned.length - 7, cleaned.length - 4)}-${cleaned.substring(cleaned.length - 4, cleaned.length - 2)}-${cleaned.substring(cleaned.length - 2)}';
    }
  }
  
  /// Маскирует номер телефона, оставляя видимыми только последние 4 цифры
  String maskPhoneNumber() {
    final cleaned = digitsOnly;
    if (cleaned.length < 8) return this;
    
    final lastFour = cleaned.substring(cleaned.length - 4);
    return '**** *** **$lastFour';
  }
  
  /// Маскирует email, оставляя видимыми первые и последние символы
  String maskEmail() {
    if (!isEmail) return this;
    
    final parts = split('@');
    if (parts.length != 2) return this;
    
    final name = parts[0];
    final domain = parts[1];
    
    if (name.length <= 2) return this;
    
    final maskedName = '${name[0]}${name.substring(1, name.length - 1).replaceAll(RegExp(r'.'), '*')}${name[name.length - 1]}';
    return '$maskedName@$domain';
  }
  
  /// Преобразует строку в snake_case
  String get toSnakeCase {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceAll(' ', '_').toLowerCase();
  }
  
  /// Преобразует строку в camelCase
  String get toCamelCase {
    return replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    ).replaceAllMapped(
      RegExp(r'[ -]([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
  }
} 