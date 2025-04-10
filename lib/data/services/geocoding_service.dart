import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Сервис для геокодирования адресов в координаты и обратно
class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();

  factory GeocodingService() {
    return _instance;
  }

  GeocodingService._internal();

  /// Получает координаты по адресу
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    if (address.isEmpty) {
      debugPrint('GeocodingService: Получен пустой адрес');
      return null;
    }

    try {
      debugPrint('GeocodingService: Запрос координат для адреса: $address');

      // Пытаемся получить местоположение по адресу
      final locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final result = LatLng(location.latitude, location.longitude);

        debugPrint(
          'GeocodingService: Координаты успешно получены: ${result.latitude}, ${result.longitude}',
        );
        return result;
      } else {
        debugPrint(
          'GeocodingService: Координаты не найдены для адреса: $address',
        );
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Ошибка при получении координат: $e');
      return null;
    }
  }

  /// Получает адрес по координатам
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    if (!_isValidCoordinate(latitude, longitude)) {
      debugPrint(
        'GeocodingService: Получены невалидные координаты: $latitude, $longitude',
      );
      return null;
    }

    try {
      debugPrint(
        'GeocodingService: Запрос адреса для координат: $latitude, $longitude',
      );

      // Пытаемся получить адрес по координатам
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Формируем полный адрес из компонентов
        final components = <String>[];

        if (place.country?.isNotEmpty == true) {
          components.add(place.country!);
        }
        if (place.administrativeArea?.isNotEmpty == true) {
          components.add(place.administrativeArea!);
        }
        if (place.locality?.isNotEmpty == true) {
          components.add(place.locality!);
        }
        if (place.subLocality?.isNotEmpty == true) {
          components.add(place.subLocality!);
        }
        if (place.thoroughfare?.isNotEmpty == true) {
          components.add(place.thoroughfare!);
        }
        if (place.subThoroughfare?.isNotEmpty == true) {
          components.add(place.subThoroughfare!);
        }

        final result = components.join(', ');
        debugPrint('GeocodingService: Адрес успешно получен: $result');
        return result;
      } else {
        debugPrint(
          'GeocodingService: Адрес не найден для координат: $latitude, $longitude',
        );
        return null;
      }
    } catch (e) {
      debugPrint('GeocodingService: Ошибка при получении адреса: $e');
      return null;
    }
  }

  /// Проверяет валидность координат
  bool _isValidCoordinate(double lat, double lng) {
    // Проверка на нулевые координаты (часто признак неинициализированных значений)
    if (lat == 0.0 && lng == 0.0) {
      return false;
    }

    // Проверка на бесконечность или NaN
    if (!lat.isFinite || !lng.isFinite) {
      return false;
    }

    // Проверка диапазона координат
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return false;
    }

    return true;
  }
}
