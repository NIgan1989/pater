import 'package:flutter/material.dart';

/// Вспомогательные методы для работы с цветами
class ColorUtils {
  /// Преобразует значение прозрачности из диапазона [0.0, 1.0] в целое число [0, 255]
  static int alphaFromOpacity(double opacity) {
    return (opacity * 255).round();
  }
  
  /// Преобразует проценты прозрачности в значение alpha
  static int alphaFromPercent(int percent) {
    return (percent * 255 ~/ 100);
  }
}

/// Расширение для класса Color
extension ColorExtension on Color {
  /// Создает цвет с указанной прозрачностью в диапазоне [0.0, 1.0]
  Color withOpacity2(double opacity) {
    final alpha = ColorUtils.alphaFromOpacity(opacity);
    return Color.fromARGB(
      alpha,
      r.toInt(),
      g.toInt(),
      b.toInt(),
    );
  }
  
  /// Создает цвет с указанной прозрачностью в процентах
  Color withOpacityPercent(int percent) {
    final alpha = ColorUtils.alphaFromPercent(percent);
    return Color.fromARGB(
      alpha,
      r.toInt(),
      g.toInt(),
      b.toInt(),
    );
  }
  
  /// Замена метода withValues для обратной совместимости
  Color withValues({double alpha = 1.0}) {
    return withOpacity2(alpha);
  }
} 