import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Виджет для отображения ошибок
class AppErrorWidget extends StatelessWidget {
  /// Текст ошибки
  final String error;
  
  /// Действие при нажатии на кнопку повтора
  final VoidCallback? onRetry;
  
  /// Иконка (опционально)
  final IconData? icon;
  
  /// Заголовок (опционально)
  final String? title;
  
  /// Текст кнопки (опционально)
  final String? buttonText;
  
  /// Конструктор
  const AppErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.icon,
    this.title,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Иконка ошибки
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            
            const SizedBox(height: AppConstants.paddingL),
            
            // Заголовок ошибки
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingM),
            ],
            
            // Текст ошибки
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 204),
              ),
              textAlign: TextAlign.center,
            ),
            
            if (onRetry != null) ...[
              const SizedBox(height: AppConstants.paddingL),
              
              // Кнопка повтора
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(buttonText ?? 'Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingL,
                    vertical: AppConstants.paddingM,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 