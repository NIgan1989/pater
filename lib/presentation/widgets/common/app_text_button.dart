import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Текстовая кнопка приложения
class AppTextButton extends StatelessWidget {
  /// Текст кнопки
  final String text;
  
  /// Обработчик нажатия
  final VoidCallback? onPressed;
  
  /// Флаг состояния загрузки
  final bool isLoading;
  
  /// Иконка (опционально)
  final IconData? icon;
  
  /// Пользовательский цвет (опционально)
  final Color? textColor;
  
  /// Размер текста (опционально)
  final double? fontSize;
  
  /// Конструктор
  const AppTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = textColor ?? theme.colorScheme.primary;
    
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingM,
          vertical: AppConstants.paddingS,
        ),
        textStyle: TextStyle(
          fontSize: fontSize ?? AppConstants.fontSizeBody,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: _buildContent(color),
    );
  }
  
  /// Строит содержимое кнопки
  Widget _buildContent(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 18, 
            color: color,
          ),
          const SizedBox(width: AppConstants.paddingXS),
          Text(text),
        ],
      );
    }
    
    return Text(text);
  }
} 