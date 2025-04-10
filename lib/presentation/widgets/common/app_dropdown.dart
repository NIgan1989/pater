import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Виджет выпадающего списка с кастомным стилем
class AppDropdown<T> extends StatelessWidget {
  /// Текущее значение
  final T? value;
  
  /// Список всех доступных элементов
  final List<DropdownMenuItem<T>> items;
  
  /// Обработчик изменения значения
  final ValueChanged<T?>? onChanged;
  
  /// Подсказка (placeholder)
  final String? hint;
  
  /// Метка (label)
  final String? label;
  
  /// Сообщение об ошибке
  final String? errorText;
  
  /// Префикс (иконка слева)
  final Widget? prefix;
  
  /// Суффикс (иконка справа)
  final Widget? suffix;
  
  /// Отключён ли выпадающий список
  final bool isDisabled;
  
  /// Конструктор
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.label,
    this.errorText,
    this.prefix,
    this.suffix,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Метка
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 204),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
        ],
        
        // Выпадающий список
        Container(
          decoration: BoxDecoration(
            color: isDisabled 
                ? theme.disabledColor.withValues(alpha: 26) 
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusS),
            border: Border.all(
              color: errorText != null 
                  ? theme.colorScheme.error 
                  : theme.colorScheme.outline.withValues(alpha: 128),
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingS,
            ),
            child: Row(
              children: [
                // Префикс
                if (prefix != null) ...[
                  prefix!,
                  const SizedBox(width: AppConstants.paddingS),
                ],
                
                // Выпадающий список
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<T>(
                      value: value,
                      hint: hint != null 
                          ? Text(
                              hint!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 128),
                              ),
                            ) 
                          : null,
                      items: items,
                      onChanged: isDisabled ? null : onChanged,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      icon: suffix ?? const Icon(Icons.arrow_drop_down),
                      isExpanded: true,
                      dropdownColor: theme.colorScheme.surface,
                      menuMaxHeight: 300,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Сообщение об ошибке
        if (errorText != null) ...[
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
} 