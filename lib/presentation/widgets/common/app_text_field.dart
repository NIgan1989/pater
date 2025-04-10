import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Кастомное поле ввода текста для приложения
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final bool showClear;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final EdgeInsets? contentPadding;
  final TextAlign textAlign;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final AutovalidateMode? autovalidateMode;
  final bool readOnly;
  final VoidCallback? onTap;
  final double? customHeight;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.showClear = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.contentPadding,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.autofocus = false,
    this.autovalidateMode,
    this.readOnly = false,
    this.onTap,
    this.customHeight,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final double height = widget.customHeight ?? 
                          (widget.maxLines != null && widget.maxLines! > 1 
                              ? widget.maxLines! * 24.0 + 24.0 
                              : AppConstants.inputHeight);
    
    // Константа для радиуса границы поля
    final double radius = AppConstants.radiusM;
    
    // Создаем виджеты для суффикса
    Widget? suffixIcon;
    
    // Если поле для пароля, добавляем переключатель видимости
    if (widget.obscureText) {
      suffixIcon = GestureDetector(
        onTap: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
        child: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      );
    } 
    // Если включена опция очистки и поле не пустое, показываем кнопку очистки
    else if (widget.showClear && _controller.text.isNotEmpty) {
      suffixIcon = GestureDetector(
        onTap: () {
          _controller.clear();
          if (widget.onChanged != null) {
            widget.onChanged!('');
          }
          setState(() {});
        },
        child: Icon(
          Icons.clear,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          size: 20,
        ),
      );
    } 
    // Если есть кастомный суффикс, используем его
    else if (widget.suffix != null) {
      suffixIcon = widget.suffix;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Метка поля (если не пустая)
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              bottom: AppConstants.paddingXS,
              left: AppConstants.paddingXS,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: AppConstants.fontSizeSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
        // Виджет текстового поля
        SizedBox(
          height: height,
          child: TextFormField(
            controller: _controller,
            obscureText: _obscureText,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            onChanged: (value) {
              if (widget.onChanged != null) {
                widget.onChanged!(value);
              }
              if (widget.showClear) {
                setState(() {});
              }
            },
            onFieldSubmitted: widget.onSubmitted,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            focusNode: widget.focusNode,
            inputFormatters: widget.inputFormatters,
            textCapitalization: widget.textCapitalization,
            textAlign: widget.textAlign,
            textInputAction: widget.textInputAction,
            autofocus: widget.autofocus,
            autovalidateMode: widget.autovalidateMode,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: AppConstants.fontSizeBody,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: widget.prefix,
              suffixIcon: suffixIcon,
              contentPadding: widget.contentPadding ?? 
                          const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingM,
                            vertical: AppConstants.paddingM,
                          ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
} 