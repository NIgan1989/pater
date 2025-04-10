import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Централизованные текстовые стили приложения
/// Используется для унификации стилей текста во всем приложении
class AppTextStyles {
  AppTextStyles._();

  // Цвета получаются из темы приложения
  static TextStyle displayLarge(BuildContext context) =>
      Theme.of(context).textTheme.displayLarge!;
  static TextStyle displayMedium(BuildContext context) =>
      Theme.of(context).textTheme.displayMedium!;
  static TextStyle displaySmall(BuildContext context) =>
      Theme.of(context).textTheme.displaySmall!;

  static TextStyle headlineLarge(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge!;
  static TextStyle headlineMedium(BuildContext context) =>
      Theme.of(context).textTheme.headlineMedium!;
  static TextStyle headlineSmall(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!;

  static TextStyle titleLarge(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!;
  static TextStyle titleMedium(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;
  static TextStyle titleSmall(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!;

  static TextStyle bodyLarge(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!;
  static TextStyle bodyMedium(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;
  static TextStyle bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;

  static TextStyle labelLarge(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!;
  static TextStyle labelMedium(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!;
  static TextStyle labelSmall(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!;

  // Специализированные стили с цветами на основе темы

  // Стили для заголовков
  static TextStyle heading1(BuildContext context) =>
      displayLarge(context).copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      );

  static TextStyle heading2(BuildContext context) =>
      displayMedium(context).copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      );

  static TextStyle heading3(BuildContext context) =>
      displaySmall(context).copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      );

  // Стили для подзаголовков
  static TextStyle subtitle1(BuildContext context) => titleLarge(
    context,
  ).copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle subtitle2(BuildContext context) => titleMedium(
    context,
  ).copyWith(color: Theme.of(context).colorScheme.onSurface);

  // Стили для таймера
  static TextStyle timerValue(BuildContext context) => headlineMedium(
    context,
  ).copyWith(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22);

  static TextStyle timerLabel(BuildContext context) =>
      bodySmall(context).copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.primary.withValues(
          red: Theme.of(context).colorScheme.primary.r.toDouble(),
          green: Theme.of(context).colorScheme.primary.g.toDouble(),
          blue: Theme.of(context).colorScheme.primary.b.toDouble(),
          alpha: 0.9 * 255,
        ),
        fontSize: 12,
      );

  // Стили для информации о бронировании
  static TextStyle bookingStatus(BuildContext context) =>
      titleMedium(context).copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      );

  static TextStyle bookingStatusDescription(BuildContext context) =>
      bodySmall(context).copyWith(
        color: Theme.of(context).colorScheme.primary.withValues(
          red: Theme.of(context).colorScheme.primary.r.toDouble(),
          green: Theme.of(context).colorScheme.primary.g.toDouble(),
          blue: Theme.of(context).colorScheme.primary.b.toDouble(),
          alpha: 0.8 * 255,
        ),
      );

  // Стили для свойств объектов недвижимости
  static TextStyle propertyTitle(BuildContext context) =>
      titleMedium(context).copyWith(fontWeight: FontWeight.bold);

  static TextStyle propertyDescription(BuildContext context) =>
      bodyMedium(context);

  static TextStyle propertyFeature(BuildContext context) =>
      bodySmall(context).copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(
          red: Theme.of(context).colorScheme.onSurface.r.toDouble(),
          green: Theme.of(context).colorScheme.onSurface.g.toDouble(),
          blue: Theme.of(context).colorScheme.onSurface.b.toDouble(),
          alpha: 0.7 * 255,
        ),
      );

  // Стили для кнопок
  static TextStyle buttonText(BuildContext context) =>
      labelLarge(context).copyWith(fontWeight: FontWeight.bold);

  // Стили для цен и сумм
  static TextStyle priceText(BuildContext context) =>
      titleLarge(context).copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      );

  static TextStyle discountPrice(BuildContext context) => titleMedium(
    context,
  ).copyWith(fontWeight: FontWeight.w600, color: AppConstants.green);

  static TextStyle oldPrice(BuildContext context) =>
      bodyMedium(context).copyWith(
        decoration: TextDecoration.lineThrough,
        color: Theme.of(context).colorScheme.onSurface.withValues(
          red: Theme.of(context).colorScheme.onSurface.r.toDouble(),
          green: Theme.of(context).colorScheme.onSurface.g.toDouble(),
          blue: Theme.of(context).colorScheme.onSurface.b.toDouble(),
          alpha: 0.5 * 255,
        ),
      );

  // Стили для дат и времени
  static TextStyle dateText(BuildContext context) =>
      bodyMedium(context).copyWith(fontWeight: FontWeight.w500);

  // Стили для ошибок
  static TextStyle errorText(BuildContext context) =>
      bodySmall(context).copyWith(color: Theme.of(context).colorScheme.error);

  // Стили для сообщений
  static TextStyle messageText(BuildContext context) => bodyMedium(context);

  static TextStyle incomingMessageText(BuildContext context) => bodyMedium(
    context,
  ).copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle outgoingMessageText(BuildContext context) =>
      bodyMedium(context).copyWith(color: Colors.white);

  static TextStyle messageTime(BuildContext context) =>
      bodySmall(context).copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(
          red: Theme.of(context).colorScheme.onSurface.r.toDouble(),
          green: Theme.of(context).colorScheme.onSurface.g.toDouble(),
          blue: Theme.of(context).colorScheme.onSurface.b.toDouble(),
          alpha: 0.6 * 255,
        ),
        fontSize: 10,
      );

  // Адаптированные стили для компонентов
  static TextStyle iconLabel(BuildContext context) =>
      bodySmall(context).copyWith(fontWeight: FontWeight.w500);

  // Стили для экрана деталей бронирования
  static TextStyle bookingDetailsTitle(BuildContext context) =>
      titleMedium(context).copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      );

  static TextStyle bookingDetailsSubtitle(BuildContext context) =>
      bodyMedium(context).copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withValues(
          red: Theme.of(context).colorScheme.onSurface.r.toDouble(),
          green: Theme.of(context).colorScheme.onSurface.g.toDouble(),
          blue: Theme.of(context).colorScheme.onSurface.b.toDouble(),
          alpha: 0.7 * 255,
        ),
      );

  static TextStyle bookingDetailsPropertyName(BuildContext context) =>
      titleMedium(context).copyWith(fontWeight: FontWeight.bold);

  static TextStyle bookingStatusLabel(
    BuildContext context, {
    bool isPositive = false,
  }) => bodySmall(context).copyWith(
    fontWeight: FontWeight.bold,
    color:
        isPositive ? AppConstants.green : Theme.of(context).colorScheme.primary,
  );

  static TextStyle snackBarText(BuildContext context) => bodyMedium(
    context,
  ).copyWith(color: Colors.white, fontWeight: FontWeight.w500);

  static TextStyle snackBarError(BuildContext context) => bodyMedium(
    context,
  ).copyWith(color: Colors.white, fontWeight: FontWeight.w500);

  // Стили для списка диалогов (чатов)
  static TextStyle chatUserName(BuildContext context) =>
      titleSmall(context).copyWith(fontWeight: FontWeight.bold);

  static TextStyle chatLastMessage(BuildContext context) =>
      bodySmall(context).copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 153),
      );

  static TextStyle chatTime(BuildContext context) =>
      bodySmall(context).copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 128),
        fontSize: 11,
      );

  static TextStyle chatUnreadCount(BuildContext context) => bodySmall(
    context,
  ).copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10);
}
