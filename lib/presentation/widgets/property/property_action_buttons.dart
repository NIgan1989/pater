import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';

/// Кнопки действий на экране деталей недвижимости
class PropertyActionButtons extends StatelessWidget {
  /// Заголовок основной кнопки
  final String primaryButtonText;
  
  /// Иконка основной кнопки
  final IconData primaryButtonIcon;
  
  /// Действие при нажатии на основную кнопку
  final VoidCallback onPrimaryButtonTap;
  
  /// Заголовок дополнительной кнопки
  final String? secondaryButtonText;
  
  /// Иконка дополнительной кнопки
  final IconData? secondaryButtonIcon;
  
  /// Действие при нажатии на дополнительную кнопку
  final VoidCallback? onSecondaryButtonTap;
  
  /// Показывать одну или две кнопки
  final bool showTwoButtons;
  
  const PropertyActionButtons({
    super.key,
    required this.primaryButtonText,
    required this.primaryButtonIcon,
    required this.onPrimaryButtonTap,
    this.secondaryButtonText,
    this.secondaryButtonIcon,
    this.onSecondaryButtonTap,
    this.showTwoButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingM,
        vertical: AppConstants.paddingM,
      ),
      child: Row(
        mainAxisAlignment: showTwoButtons 
            ? MainAxisAlignment.spaceBetween 
            : MainAxisAlignment.center,
        children: [
          // Основная кнопка (всегда отображается)
          _buildActionButton(
            width: showTwoButtons ? size.width * 0.42 : size.width * 0.7,
            icon: primaryButtonIcon,
            text: primaryButtonText,
            onTap: onPrimaryButtonTap,
            theme: theme,
          ),
          
          // Дополнительная кнопка (опционально)
          if (showTwoButtons && secondaryButtonText != null && secondaryButtonIcon != null && onSecondaryButtonTap != null)
            _buildActionButton(
              width: size.width * 0.42,
              icon: secondaryButtonIcon!,
              text: secondaryButtonText!,
              onTap: onSecondaryButtonTap!,
              theme: theme,
            ),
        ],
      ),
    );
  }
  
  /// Строит отдельную кнопку действия
  Widget _buildActionButton({
    required double width,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Container(
      width: width,
      height: 58,
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.4),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: AppConstants.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: AppConstants.white,
                  fontSize: AppConstants.fontSizeBody,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Создает кнопки бронирования и звонка
  factory PropertyActionButtons.bookingAndCall({
    required VoidCallback onBookNow,
    required VoidCallback onCall,
    String bookButtonText = 'Забронировать',
    String callButtonText = 'Позвонить',
  }) {
    return PropertyActionButtons(
      primaryButtonText: bookButtonText,
      primaryButtonIcon: Icons.calendar_today_outlined,
      onPrimaryButtonTap: onBookNow,
      secondaryButtonText: callButtonText,
      secondaryButtonIcon: Icons.call_outlined,
      onSecondaryButtonTap: onCall,
    );
  }
  
  /// Создает кнопки сообщения и звонка
  factory PropertyActionButtons.messageAndCall({
    required VoidCallback onMessage,
    required VoidCallback onCall,
    String messageButtonText = 'Написать',
    String callButtonText = 'Позвонить',
  }) {
    return PropertyActionButtons(
      primaryButtonText: messageButtonText,
      primaryButtonIcon: Icons.message_outlined,
      onPrimaryButtonTap: onMessage,
      secondaryButtonText: callButtonText,
      secondaryButtonIcon: Icons.call_outlined,
      onSecondaryButtonTap: onCall,
    );
  }
  
  /// Создает одиночную кнопку "Забронировать"
  factory PropertyActionButtons.bookNow({
    required VoidCallback onBookNow,
    String bookButtonText = 'Забронировать',
  }) {
    return PropertyActionButtons(
      primaryButtonText: bookButtonText,
      primaryButtonIcon: Icons.calendar_today_outlined,
      onPrimaryButtonTap: onBookNow,
      showTwoButtons: false,
    );
  }
} 