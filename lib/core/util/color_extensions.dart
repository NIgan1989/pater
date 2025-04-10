// Экспортируем расширение, чтобы оно было доступно глобально
export 'color_extensions.dart';

import 'package:flutter/material.dart';

/// Расширение для класса Color, добавляющее метод withValues
/// Позволяет изменять компоненты цвета с сохранением остальных значений
extension ColorExtensions on Color {
  /// Создает новый цвет с указанными значениями прозрачности, красного, зеленого и синего компонентов.
  /// Если значение не указано, используется исходное значение.
  /// 
  /// Пример использования:
  /// ```dart
  /// final color = Colors.blue.withValues(alpha: 128); // Прозрачность 50%
  /// ```
  Color withValues({int? alpha, int? red, int? green, int? blue}) {
    return Color.fromARGB(
      alpha ?? a.toInt(),
      red ?? r.toInt(),
      green ?? g.toInt(),
      blue ?? b.toInt(),
    );
  }
} 