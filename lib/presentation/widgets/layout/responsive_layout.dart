import 'package:flutter/material.dart';

/// Виджет адаптивного макета для разных размеров экрана
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  // Максимальная ширина для мобильных устройств
  static const int mobileMaxWidth = 600;
  
  // Максимальная ширина для планшетов
  static const int tabletMaxWidth = 1200;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletMaxWidth) {
          // Для десктопа
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= mobileMaxWidth) {
          // Для планшета
          return tablet ?? mobile;
        } else {
          // Для мобильного
          return mobile;
        }
      },
    );
  }
} 