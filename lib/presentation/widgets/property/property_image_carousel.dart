import 'package:flutter/material.dart';
import 'package:pater/core/constants/app_constants.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

/// Виджет для отображения карусели изображений объекта недвижимости
class PropertyImageCarousel extends StatefulWidget {
  /// Список URL изображений
  final List<String> imageUrls;
  
  /// Высота карусели
  final double height;
  
  /// Callback при нажатии на изображение
  final Function(int)? onImageTap;
  
  /// Показывать ли индикаторы текущего изображения
  final bool showIndicators;
  
  /// Показывать ли кнопки навигации
  final bool showNavigationButtons;
  
  /// Автоматическая прокрутка карусели
  final bool autoPlay;
  
  /// Интервал автоматической прокрутки в секундах
  final int autoPlayInterval;
  
  /// Бесконечная прокрутка
  final bool infiniteScroll;
  
  /// Начальный индекс изображения
  final int initialIndex;

  const PropertyImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 300,
    this.onImageTap,
    this.showIndicators = true,
    this.showNavigationButtons = true,
    this.autoPlay = false,
    this.autoPlayInterval = 5,
    this.infiniteScroll = true,
    this.initialIndex = 0,
  });

  @override
  State<PropertyImageCarousel> createState() => _PropertyImageCarouselState();
}

class _PropertyImageCarouselState extends State<PropertyImageCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentPage = widget.initialIndex;
    
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: widget.autoPlayInterval), (timer) {
      if (_currentPage < widget.imageUrls.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else if (widget.infiniteScroll) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return _buildPlaceholder();
    }
    
    return Stack(
      children: [
        // Карусель изображений
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: widget.onImageTap != null 
                    ? () => widget.onImageTap!(index)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: AppConstants.grey,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppConstants.blue
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppConstants.grey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_not_supported,
                              color: AppConstants.darkGrey,
                              size: 50,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Обновить'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Индикаторы текущей страницы
        if (widget.showIndicators && widget.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imageUrls.length,
                (index) => _buildIndicator(index),
              ),
            ),
          ),
        
        // Кнопки навигации
        if (widget.showNavigationButtons && widget.imageUrls.length > 1)
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Кнопка "Назад"
                _buildNavigationButton(
                  Icons.chevron_left_rounded,
                  () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                
                // Кнопка "Вперед"
                _buildNavigationButton(
                  Icons.chevron_right_rounded,
                  () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  /// Создает индикатор текущей страницы
  Widget _buildIndicator(int index) {
    final isActive = index == _currentPage;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 12 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppConstants.white : AppConstants.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppConstants.black.withValues(alpha: 0.2),
                  blurRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
  
  /// Создает кнопку навигации
  Widget _buildNavigationButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppConstants.white.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppConstants.black.withValues(alpha: 0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: AppConstants.darkBlue,
        iconSize: 32,
      ),
    );
  }
  
  /// Создает плейсхолдер при отсутствии изображений
  Widget _buildPlaceholder() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppConstants.grey,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: AppConstants.darkGrey,
              size: 50,
            ),
            SizedBox(height: 8),
            Text(
              'Нет изображений',
              style: TextStyle(
                color: AppConstants.darkGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 