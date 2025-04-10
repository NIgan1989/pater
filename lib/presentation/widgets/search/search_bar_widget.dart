import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Виджет строки поиска с современным дизайном
class SearchBarWidget extends StatefulWidget {
  /// Контроллер для текстового поля
  final TextEditingController controller;

  /// Callback для изменения текста
  final Function(String)? onChanged;

  /// Callback для отправки формы поиска
  final Function(String)? onSubmitted;

  /// Подсказка для поля ввода
  final String hintText;

  /// Иконка поиска
  final IconData searchIcon;

  /// Показывать ли кнопку фильтра
  final bool showFilterButton;

  /// Callback для нажатия на кнопку фильтра
  final VoidCallback? onFilterTap;

  /// Стиль отображения строки поиска
  final SearchBarStyle style;

  const SearchBarWidget({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Поиск...',
    this.searchIcon = Icons.search,
    this.showFilterButton = true,
    this.onFilterTap,
    this.style = SearchBarStyle.expanded,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Определяем стиль контейнера в зависимости от настроек
    final isCompact = widget.style == SearchBarStyle.compact;

    return Container(
      height: isCompact ? 48 : 60,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(
          isCompact ? AppConstants.radiusS : AppConstants.radiusM,
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.darkBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Иконка поиска
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  isCompact ? AppConstants.paddingS : AppConstants.paddingM,
            ),
            child: Icon(
              widget.searchIcon,
              color: _isFocused ? theme.primaryColor : AppConstants.darkGrey,
              size: isCompact ? 20 : 24,
            ),
          ),

          // Текстовое поле для поиска
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(
                fontSize:
                    isCompact
                        ? AppConstants.fontSizeSecondary
                        : AppConstants.fontSizeBody,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: AppConstants.darkGrey.withValues(alpha: 0.6),
                  fontSize:
                      isCompact
                          ? AppConstants.fontSizeSecondary
                          : AppConstants.fontSizeBody,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Кнопка очистки текста, если есть текст
          if (widget.controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              color: AppConstants.darkGrey,
              onPressed: () {
                widget.controller.clear();
                if (widget.onChanged != null) {
                  widget.onChanged!('');
                }
              },
            ),

          // Кнопка фильтра (опционально)
          if (widget.showFilterButton)
            Padding(
              padding: EdgeInsets.only(
                right:
                    isCompact ? AppConstants.paddingS : AppConstants.paddingM,
                left:
                    widget.controller.text.isEmpty ? 0 : AppConstants.paddingXS,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onFilterTap,
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(AppConstants.paddingXS),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: theme.colorScheme.secondary,
                      size: isCompact ? 20 : 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Стили отображения строки поиска
enum SearchBarStyle {
  /// Расширенный вид с большими отступами
  expanded,

  /// Компактный вид с меньшими элементами
  compact,
}
