import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Виджет для отображения заголовка раздела
class SectionHeader extends StatelessWidget {
  /// Заголовок раздела
  final String title;
  
  /// Подзаголовок раздела (опционально)
  final String? subtitle;
  
  /// Кнопка действия справа (опционально)
  final Widget? action;
  
  /// Дополнительные отступы
  final EdgeInsetsGeometry? padding;
  
  /// Выравнивание заголовка
  final CrossAxisAlignment alignment;
  
  /// Стиль заголовка
  final TextStyle? titleStyle;
  
  /// Стиль подзаголовка
  final TextStyle? subtitleStyle;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding,
    this.alignment = CrossAxisAlignment.start,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingM,
        vertical: AppConstants.paddingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                Text(
                  title,
                  style: titleStyle ?? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.darkBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: subtitleStyle ?? theme.textTheme.bodyMedium?.copyWith(
                      color: AppConstants.darkGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
  
  /// Создает заголовок с кнопкой "См. все"
  factory SectionHeader.withSeeAll({
    required String title,
    String? subtitle,
    required VoidCallback onSeeAllTap,
    EdgeInsetsGeometry? padding,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    String actionText = 'Смотреть все',
  }) {
    return SectionHeader(
      title: title,
      subtitle: subtitle,
      padding: padding,
      alignment: alignment,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
      action: TextButton(
        onPressed: onSeeAllTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingS,
            vertical: AppConstants.paddingXS,
          ),
        ),
        child: Text(
          actionText,
          style: const TextStyle(
            color: AppConstants.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Создает заголовок с кнопкой-иконкой
  factory SectionHeader.withIconButton({
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
    EdgeInsetsGeometry? padding,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    Color? iconColor,
  }) {
    return SectionHeader(
      title: title,
      subtitle: subtitle,
      padding: padding,
      alignment: alignment,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
      action: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onTap,
      ),
    );
  }
} 