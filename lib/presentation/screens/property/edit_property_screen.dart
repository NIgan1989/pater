import 'package:flutter/material.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/domain/entities/property.dart';
import 'package:pater/presentation/screens/property/add_property_screen.dart';

/// Экран редактирования объявления
class EditPropertyScreen extends StatefulWidget {
  final String propertyId;

  const EditPropertyScreen({super.key, required this.propertyId});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final PropertyService _propertyService = PropertyService();
  bool _isLoading = true;
  Property? _property;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProperty();
  }

  /// Загружает данные объекта для редактирования
  Future<void> _loadProperty() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Проверяем, что ID не пустой
      if (widget.propertyId.isEmpty) {
        throw Exception('ID объекта не указан');
      }

      debugPrint('Загружаем данные объекта с ID: ${widget.propertyId}');
      final property = await _propertyService.getPropertyById(
        widget.propertyId,
      );

      if (property == null) {
        throw Exception('Объект с ID ${widget.propertyId} не найден');
      }

      if (mounted) {
        setState(() {
          _property = property;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке объекта: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Не удалось загрузить данные объекта: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || _property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Не удалось загрузить объект',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Вернуться назад'),
              ),
            ],
          ),
        ),
      );
    }

    // Если объект загружен успешно, отображаем экран добавления объекта
    // с передачей свойства для редактирования
    return AddPropertyScreen(propertyId: widget.propertyId);
  }
}
