import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Виджет для загрузки изображений из сети с кэшированием
class AppCachedNetworkImage extends StatelessWidget {
  /// URL изображения
  final String? imageUrl;
  
  /// Заполнение (тип фита для изображения)
  final BoxFit? fit;
  
  /// Ширина изображения
  final double? width;
  
  /// Высота изображения
  final double? height;
  
  /// Плейсхолдер при загрузке (опционально)
  final Widget? placeholder;
  
  /// Виджет для отображения ошибки (опционально)
  final Widget? errorWidget;
  
  /// Виджет для отображения, если URL пустой (опционально)
  final Widget? emptyWidget;
  
  /// Конструктор
  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Проверяем наличие URL
    if (imageUrl == null || imageUrl!.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: emptyWidget ?? _buildDefaultEmptyWidget(context),
      );
    }

    // Используем CachedNetworkImage для кэширования
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => placeholder ?? _buildDefaultLoadingWidget(),
      errorWidget: (context, url, error) => errorWidget ?? _buildDefaultErrorWidget(context),
    );
  }
  
  /// Стандартный виджет загрузки
  Widget _buildDefaultLoadingWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
  
  /// Стандартный виджет ошибки
  Widget _buildDefaultErrorWidget(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
        ),
      ),
    );
  }
  
  /// Стандартный виджет для пустого URL
  Widget _buildDefaultEmptyWidget(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
        ),
      ),
    );
  }
} 