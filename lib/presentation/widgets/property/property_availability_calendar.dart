import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'package:intl/intl.dart';

/// Виджет мини-календаря, показывающий доступность объекта по датам
class PropertyAvailabilityCalendar extends StatefulWidget {
  /// ID объекта недвижимости
  final String propertyId;
  
  /// Ширина виджета
  final double? width;
  
  /// Высота виджета
  final double? height;
  
  /// Колбэк при выборе даты
  final Function(DateTime)? onDateSelected;
  
  /// Список дат, в которые объект забронирован
  final List<DateTime> bookedDates;
  
  /// Список дат, в которые объект на уборке
  final List<DateTime> cleaningDates;
  
  const PropertyAvailabilityCalendar({
    super.key,
    required this.propertyId,
    this.width,
    this.height,
    this.onDateSelected,
    this.bookedDates = const [],
    this.cleaningDates = const [],
  });

  @override
  State<PropertyAvailabilityCalendar> createState() => _PropertyAvailabilityCalendarState();
}

class _PropertyAvailabilityCalendarState extends State<PropertyAvailabilityCalendar> {
  /// Текущий отображаемый месяц
  late DateTime _currentMonth;
  
  /// Форматтер для месяца и года
  final DateFormat _monthFormatter = DateFormat('MMMM yyyy');
  
  /// Форматтер для дня недели
  final DateFormat _weekdayFormatter = DateFormat('E');
  
  /// Выбранная дата
  DateTime? _selectedDate;
  
  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          _buildDaysOfWeek(theme),
          Expanded(
            child: _buildCalendarGrid(theme),
          ),
          _buildLegend(theme),
        ],
      ),
    );
  }
  
  /// Заголовок с месяцем и кнопками навигации
  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
            splashRadius: 24,
          ),
          Text(
            _monthFormatter.format(_currentMonth),
            style: TextStyle(
              fontSize: AppConstants.fontSizeHeadingSecondary,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
            splashRadius: 24,
          ),
        ],
      ),
    );
  }
  
  /// Строка с названиями дней недели
  Widget _buildDaysOfWeek(ThemeData theme) {
    final List<String> weekdays = List.generate(
      7,
      (index) => _weekdayFormatter.format(DateTime(2023, 1, index + 2)),
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          return Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Text(
              day.substring(0, 1),
              style: TextStyle(
                fontSize: AppConstants.fontSizeSecondary,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  /// Сетка с числами месяца
  Widget _buildCalendarGrid(ThemeData theme) {
    final daysInMonth = _getDaysInMonth();
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingS),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: daysInMonth.length,
      itemBuilder: (context, index) {
        final date = daysInMonth[index];
        final isBooked = _isDateBooked(date);
        final isCleaning = _isDateCleaning(date);
        final isCurrentMonth = date.month == _currentMonth.month;
        
        return GestureDetector(
          onTap: isCurrentMonth && !isBooked && !isCleaning 
              ? () => _selectDate(date) 
              : null,
          child: _buildDayCell(theme, date, isCurrentMonth, isBooked, isCleaning),
        );
      },
    );
  }
  
  /// Ячейка с числом
  Widget _buildDayCell(
    ThemeData theme, 
    DateTime date, 
    bool isCurrentMonth, 
    bool isBooked, 
    bool isCleaning,
  ) {
    final isSelected = _selectedDate != null && 
        _selectedDate!.year == date.year && 
        _selectedDate!.month == date.month && 
        _selectedDate!.day == date.day;
    
    final isToday = date.year == DateTime.now().year && 
        date.month == DateTime.now().month && 
        date.day == DateTime.now().day;
    
    Color backgroundColor;
    Color textColor;
    
    if (!isCurrentMonth) {
      backgroundColor = Colors.transparent;
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isSelected) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (isToday) {
      backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.1);
      textColor = theme.colorScheme.primary;
    } else if (isBooked) {
      backgroundColor = Colors.red.withValues(alpha: 0.1);
      textColor = Colors.red;
    } else if (isCleaning) {
      backgroundColor = Colors.orange.withValues(alpha: 0.1);
      textColor = Colors.orange;
    } else {
      backgroundColor = Colors.transparent;
      textColor = theme.colorScheme.onSurface;
    }
    
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusS),
      ),
      alignment: Alignment.center,
      child: Text(
        date.day.toString(),
        style: TextStyle(
          fontSize: AppConstants.fontSizeBody,
          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }
  
  /// Легенда с объяснением статусов
  Widget _buildLegend(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(
            theme,
            'Доступно',
            Colors.transparent,
            theme.colorScheme.onSurface,
          ),
          _buildLegendItem(
            theme,
            'Занято',
            Colors.red.withValues(alpha: 0.1),
            Colors.red,
          ),
          _buildLegendItem(
            theme,
            'Уборка',
            Colors.orange.withValues(alpha: 0.1),
            Colors.orange,
          ),
        ],
      ),
    );
  }
  
  /// Элемент легенды
  Widget _buildLegendItem(
    ThemeData theme,
    String label,
    Color backgroundColor,
    Color textColor,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: textColor,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppConstants.fontSizeSmall,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
  
  /// Проверяет, забронирована ли дата
  bool _isDateBooked(DateTime date) {
    return widget.bookedDates.any((bookedDate) => 
      bookedDate.year == date.year && 
      bookedDate.month == date.month && 
      bookedDate.day == date.day
    );
  }
  
  /// Проверяет, назначена ли на дату уборка
  bool _isDateCleaning(DateTime date) {
    return widget.cleaningDates.any((cleaningDate) => 
      cleaningDate.year == date.year && 
      cleaningDate.month == date.month && 
      cleaningDate.day == date.day
    );
  }
  
  /// Возвращает список дней для отображения в календаре
  List<DateTime> _getDaysInMonth() {
    // Первый день месяца
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    
    // Определяем день недели первого числа (0 - пн, 6 - вс)
    final firstWeekday = firstDayOfMonth.weekday;
    
    // Последний день предыдущего месяца
    final lastDayOfPrevMonth = DateTime(_currentMonth.year, _currentMonth.month, 0);
    
    // Количество дней в текущем месяце
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    // Список всех дат для отображения
    final List<DateTime> result = [];
    
    // Добавляем дни из предыдущего месяца
    for (int i = 0; i < firstWeekday; i++) {
      result.add(lastDayOfPrevMonth.subtract(Duration(days: firstWeekday - i - 1)));
    }
    
    // Добавляем дни текущего месяца
    for (int i = 1; i <= daysInMonth; i++) {
      result.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }
    
    // Добавляем дни следующего месяца (до заполнения сетки)
    final remainingDays = 42 - result.length; // 6 недель по 7 дней = 42 ячейки
    for (int i = 1; i <= remainingDays; i++) {
      result.add(DateTime(_currentMonth.year, _currentMonth.month + 1, i));
    }
    
    return result;
  }
  
  /// Переход к предыдущему месяцу
  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }
  
  /// Переход к следующему месяцу
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }
  
  /// Обработка выбора даты
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    if (widget.onDateSelected != null) {
      widget.onDateSelected!(date);
    }
  }
} 