import 'package:flutter/material.dart';

/// Общий компонент для отображения сообщений об ошибках
class ErrorMessageWidget extends StatelessWidget {
  /// Текст сообщения об ошибке
  final String message;

  /// Можно ли закрыть сообщение
  final bool dismissible;

  /// Обратный вызов при закрытии сообщения
  final VoidCallback? onDismiss;

  /// Иконка для отображения
  final IconData icon;

  /// Цвет фона сообщения
  final Color? backgroundColor;

  /// Цвет текста и иконки
  final Color? textColor;

  /// Граница
  final BorderRadius? borderRadius;

  /// Отступы
  final EdgeInsetsGeometry padding;

  /// Конструктор компонента ErrorMessageWidget
  const ErrorMessageWidget({
    super.key,
    required this.message,
    this.dismissible = false,
    this.onDismiss,
    this.icon = Icons.error_outline,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = textColor ?? theme.colorScheme.error;
    final effectiveBackgroundColor =
        backgroundColor ?? effectiveTextColor.withAlpha(26);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(8);

    return AnimatedOpacity(
      opacity: message.isNotEmpty ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child:
          message.isNotEmpty
              ? Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: effectiveBackgroundColor,
                  borderRadius: effectiveBorderRadius,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: effectiveTextColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: effectiveTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (dismissible && onDismiss != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: effectiveTextColor,
                        onPressed: onDismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                  ],
                ),
              )
              : const SizedBox.shrink(),
    );
  }
}
