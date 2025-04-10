import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Общий компонент для ввода PIN-кода
class PinCodeInput extends StatelessWidget {
  /// Контроллер для ввода PIN-кода
  final TextEditingController controller;

  /// Обратный вызов при заполнении всех полей
  final Function(String) onCompleted;

  /// Обратный вызов при изменении текста
  final Function(String)? onChanged;

  /// Количество цифр в PIN-коде
  final int length;

  /// Скрывать ли вводимые символы
  final bool obscureText;

  /// Активен ли ввод
  final bool enabled;

  /// Тип анимации
  final AnimationType animationType;

  /// Автофокус при отображении
  final bool autoFocus;

  /// Тема для PIN-кода
  final PinTheme? pinTheme;

  /// Оформление для активного состояния
  final Color? activeColor;

  /// Оформление для неактивного состояния
  final Color? inactiveColor;

  /// Оформление для выбранного состояния
  final Color? selectedColor;

  /// Цвет фона с заполнением
  final Color? fillColor;

  /// Форма полей ввода
  final PinCodeFieldShape shape;

  /// Радиус скругления для полей
  final double borderRadius;

  /// Высота полей ввода
  final double fieldHeight;

  /// Ширина полей ввода
  final double fieldWidth;

  /// Стиль текста ввода
  final TextStyle? textStyle;

  /// Конструктор компонента PinCodeInput
  const PinCodeInput({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.onChanged,
    this.length = 4,
    this.obscureText = true,
    this.enabled = true,
    this.animationType = AnimationType.fade,
    this.autoFocus = true,
    this.pinTheme,
    this.activeColor,
    this.inactiveColor,
    this.selectedColor,
    this.fillColor,
    this.shape = PinCodeFieldShape.box,
    this.borderRadius = 8,
    this.fieldHeight = 60,
    this.fieldWidth = 60,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Создаем тему PIN-кода на основе переданных параметров или используем значения по умолчанию
    final effectivePinTheme =
        pinTheme ??
        PinTheme(
          shape: shape,
          borderRadius: BorderRadius.circular(borderRadius),
          fieldHeight: fieldHeight,
          fieldWidth: fieldWidth,
          activeFillColor: fillColor ?? Colors.white,
          inactiveFillColor: fillColor ?? Colors.white,
          selectedFillColor:
              selectedColor?.withAlpha(30) ??
              theme.colorScheme.primary.withAlpha(30),
          activeColor: activeColor ?? theme.colorScheme.primary,
          inactiveColor: inactiveColor ?? Colors.grey.withAlpha(130),
          selectedColor: selectedColor ?? theme.colorScheme.primary,
        );

    return PinCodeTextField(
      appContext: context,
      length: length,
      controller: controller,
      autoFocus: autoFocus,
      enabled: enabled,
      obscureText: obscureText,
      onCompleted: onCompleted,
      animationType: animationType,
      pinTheme: effectivePinTheme,
      keyboardType: TextInputType.number,
      enableActiveFill: true,
      onChanged: onChanged ?? (_) {},
      textStyle:
          textStyle ??
          const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      animationDuration: const Duration(milliseconds: 150),
      useHapticFeedback: true,
      hapticFeedbackTypes: HapticFeedbackTypes.light,
      cursorColor: theme.colorScheme.primary,
      showCursor: true,
      cursorHeight: 20,
      cursorWidth: 2,
      boxShadows:
          effectivePinTheme.shape == PinCodeFieldShape.circle
              ? []
              : [
                BoxShadow(
                  offset: const Offset(0, 1),
                  color: Colors.black12,
                  blurRadius: 2,
                ),
              ],
      dialogConfig: DialogConfig(
        dialogTitle: "Ввод PIN-кода",
        dialogContent: "Используйте клавиатуру для ввода",
        affirmativeText: "OK",
        negativeText: "Отмена",
      ),
      beforeTextPaste: (text) {
        // Допускаем только цифры для вставки
        return text != null && RegExp(r'^[0-9]+$').hasMatch(text);
      },
    );
  }
}
