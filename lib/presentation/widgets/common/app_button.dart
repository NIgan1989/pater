import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Кастомная кнопка приложения
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final ButtonType type;
  final IconData? icon;
  final Color? customColor;
  final double? customHeight;
  final double? customWidth;

  /// Основная кнопка приложения с заполненным фоном
  const AppButton.primary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.customColor,
    this.customHeight,
    this.customWidth,
  })  : type = ButtonType.primary;

  /// Второстепенная кнопка приложения с обводкой
  const AppButton.secondary({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.customColor,
    this.customHeight,
    this.customWidth,
  })  : type = ButtonType.secondary;

  /// Третичная кнопка приложения (текстовая)
  const AppButton.text({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.customColor,
    this.customHeight,
    this.customWidth,
  })  : type = ButtonType.text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Определяем размеры кнопки
    final double height = customHeight ?? AppConstants.buttonHeight;
    final double width = isFullWidth 
        ? double.infinity 
        : (customWidth ?? AppConstants.buttonWidthNormal);
    
    // Выбираем тип кнопки на основе параметра type
    switch (type) {
      case ButtonType.primary:
        return SizedBox(
          width: width,
          height: height,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: customColor ?? theme.colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
              elevation: 1,
            ),
            child: _buildButtonContent(context, theme.colorScheme.onPrimary),
          ),
        );
      
      case ButtonType.secondary:
        return SizedBox(
          width: width,
          height: height,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: customColor ?? theme.colorScheme.primary,
              side: BorderSide(
                color: customColor ?? theme.colorScheme.primary,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusS),
              ),
            ),
            child: _buildButtonContent(context, customColor ?? theme.colorScheme.primary),
          ),
        );
      
      case ButtonType.text:
        return SizedBox(
          height: height,
          child: TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: customColor ?? theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingM,
              ),
            ),
            child: _buildButtonContent(context, customColor ?? theme.colorScheme.primary),
          ),
        );
    }
  }

  /// Построение содержимого кнопки (текст или индикатор загрузки)
  Widget _buildButtonContent(BuildContext context, Color contentColor) {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(contentColor),
        ),
      );
    }

    // Если есть иконка, отображаем её вместе с текстом
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: contentColor, size: 20),
          const SizedBox(width: AppConstants.paddingS),
          Text(
            text,
            style: TextStyle(
              color: contentColor,
              fontSize: AppConstants.fontSizeBody,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Только текст
    return Text(
      text,
      style: TextStyle(
        color: contentColor,
        fontSize: AppConstants.fontSizeBody,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Типы кнопок
enum ButtonType {
  primary,
  secondary,
  text,
} 