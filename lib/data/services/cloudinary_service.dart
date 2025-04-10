import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

/// Сервис для работы с Cloudinary
class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  bool _isInitialized = false;
  late final String _cloudName;
  late final String _uploadPreset;
  late final String _apiKey;

  /// Инициализация сервиса
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _cloudName = 'dfilhecvd';
      _uploadPreset = 'paters';
      _apiKey = '593318396465835';  // API ключ из скриншота
      _isInitialized = true;
    } catch (e) {
      debugPrint('Ошибка инициализации Cloudinary: $e');
      rethrow;
    }
  }

  /// Загрузка изображения из XFile (работает как на веб, так и на мобильных платформах)
  Future<String> uploadXFile(XFile pickedImage) async {
    if (!_isInitialized) {
      throw Exception('Cloudinary не инициализирован');
    }

    try {
      // Получаем данные изображения в виде байтов
      final imageBytes = await pickedImage.readAsBytes();
      
      // Создаем URL для загрузки с указанием облака
      final uploadUrl = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
      
      // Создаем FormData для отправки
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      
      // Добавляем параметры для неподписанной загрузки с API ключом
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['api_key'] = _apiKey;  // Добавляем API ключ
      
      // Добавляем файл для загрузки
      var multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: pickedImage.name,
        contentType: MediaType('image', _getImageFormat(pickedImage.name)),
      );
      request.files.add(multipartFile);
      
      // Отладочный вывод
      debugPrint('Отправляем запрос на Cloudinary: ${request.url}');
      debugPrint('С пресетом: ${request.fields['upload_preset']} и API ключом: ${request.fields['api_key']}');
      
      // Отправляем запрос
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        debugPrint('Ошибка API Cloudinary: $responseData');
        throw Exception('Ошибка загрузки, код: ${response.statusCode}');
      }
      
      final jsonResponse = json.decode(responseData);
      return jsonResponse['secure_url'];
    } catch (e) {
      debugPrint('Ошибка загрузки изображения в Cloudinary: $e');
      rethrow;
    }
  }
  
  /// Загрузка изображения из File (только для мобильных платформ)
  Future<String> uploadImage(File imageFile) async {
    if (!_isInitialized) {
      throw Exception('Cloudinary не инициализирован');
    }

    if (kIsWeb) {
      throw Exception('Метод uploadImage не поддерживается в веб-версии. Используйте uploadXFile');
    }

    try {
      // Читаем файл как XFile
      final xFile = XFile(imageFile.path);
      return await uploadXFile(xFile);
    } catch (e) {
      debugPrint('Ошибка загрузки изображения в Cloudinary: $e');
      rethrow;
    }
  }
  
  /// Определяет формат изображения по имени файла
  String _getImageFormat(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'jpeg'; // По умолчанию предполагаем JPEG
    }
  }

  /// Загрузка нескольких изображений
  Future<List<String>> uploadImages(List<File> imageFiles) async {
    if (!_isInitialized) {
      throw Exception('Cloudinary не инициализирован');
    }

    try {
      final List<String> urls = [];
      
      for (var file in imageFiles) {
        final url = await uploadImage(file);
        urls.add(url);
      }

      return urls;
    } catch (e) {
      debugPrint('Ошибка загрузки изображений в Cloudinary: $e');
      rethrow;
    }
  }

  /// Удаление изображения по URL
  Future<void> deleteImage(String imageUrl) async {
    if (!_isInitialized) {
      throw Exception('Cloudinary не инициализирован');
    }

    try {
      // В бесплатном плане Cloudinary нет прямого API для удаления изображений
      // Поэтому мы просто логируем это действие
      debugPrint('Запрос на удаление изображения: $imageUrl');
      debugPrint('Примечание: В бесплатном плане Cloudinary удаление через API недоступно');
      
      // Для удаления изображений в бесплатном плане используйте 
      // панель управления Cloudinary (Media Library)
    } catch (e) {
      debugPrint('Ошибка при обработке запроса на удаление изображения: $e');
    }
  }

  /// Удаление нескольких изображений
  Future<void> deleteImages(List<String> imageUrls) async {
    if (!_isInitialized) {
      throw Exception('Cloudinary не инициализирован');
    }

    try {
      for (var url in imageUrls) {
        await deleteImage(url);
      }
    } catch (e) {
      debugPrint('Ошибка удаления изображений из Cloudinary: $e');
      rethrow;
    }
  }
} 