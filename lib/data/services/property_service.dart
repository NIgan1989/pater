import 'dart:async';
import 'dart:io';

import 'package:pater/domain/entities/property.dart';
import 'package:pater/domain/entities/booking.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:pater/core/di/service_locator.dart';

/// Класс для представления географических координат
class Location {
  final double latitude;
  final double longitude;

  const Location({required this.latitude, required this.longitude});
}

/// Сервис для работы с объектами недвижимости
class PropertyService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final AuthService _authService;

  /// Конструктор с DI
  PropertyService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    AuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _authService = authService ?? getIt<AuthService>();

  /// Получает все объекты недвижимости
  Future<List<Property>> getAllProperties() async {
    try {
      final snapshot = await _firestore.collection('properties').get();

      // Если нет данных или соединения с Firebase, возвращаем пустой список вместо тестовых данных
      if (snapshot.docs.isEmpty) {
        debugPrint(
          'В коллекции properties нет документов. Возвращаем пустой список.',
        );
        return [];
      }

      return snapshot.docs.map((doc) {
        return _documentToProperty(doc);
      }).toList();
    } catch (e) {
      debugPrint('Ошибка при получении объектов недвижимости: $e');
      return [];
    }
  }

  /// Помощник для безопасного преобразования документа Firestore в объект Property
  Property _documentToProperty(DocumentSnapshot doc) {
    final data = doc.data();
    if (data != null) {
      // Явное преобразование к Map<String, dynamic> для избежания ошибок типизации
      final Map<String, dynamic> propertyData = Map<String, dynamic>.from(
        data as Map<dynamic, dynamic>,
      );
      propertyData['id'] = doc.id;
      return Property.fromJson(propertyData);
    }

    // Возвращаем объект по умолчанию, если данные отсутствуют
    return Property(
      id: doc.id,
      title: 'Неизвестный объект',
      description: '',
      ownerId: '',
      type: PropertyType.apartment,
      status: PropertyStatus.available,
      imageUrls: [],
      address: '',
      city: '',
      country: '',
      latitude: 0,
      longitude: 0,
      pricePerNight: 0,
      pricePerHour: 0,
      area: 0,
      rooms: 0,
      bathrooms: 0,
      maxGuests: 0,
      hasWifi: false,
      hasParking: false,
      hasAirConditioning: false,
      hasKitchen: false,
      hasTV: false,
      hasWashingMachine: false,
      petFriendly: false,
      checkInTime: '',
      checkOutTime: '',
      rating: 0,
      reviewsCount: 0,
      isFeatured: false,
      isOnModeration: false,
      isActive: false,
      views: 0,
    );
  }

  /// Получает объект по идентификатору
  Future<Property?> getPropertyById(String id) async {
    try {
      final doc = await _firestore.collection('properties').doc(id).get();
      if (!doc.exists) return null;

      final property = _documentToProperty(doc);

      // Автоматическая проверка и исправление статуса объекта
      if (property.status == PropertyStatus.booked) {
        await checkAndFixPropertyStatus(property);
      }

      // Получаем обновленные данные об объекте (если изменения были)
      final updatedDoc =
          await _firestore.collection('properties').doc(id).get();
      return _documentToProperty(updatedDoc);
    } catch (e) {
      debugPrint('Ошибка при получении свойства: $e');
      return null;
    }
  }

  /// Проверяет и исправляет статус объекта, если на нем нет активных бронирований
  Future<void> checkAndFixPropertyStatus(Property property) async {
    try {
      // Получаем списки возможных значений для статусов активных бронирований
      final activeStatuses = [
        BookingStatus.pendingApproval
            .toString()
            .split('.')
            .last, // Ожидает подтверждения
        BookingStatus.waitingPayment
            .toString()
            .split('.')
            .last, // Ожидает оплаты
        BookingStatus.paid.toString().split('.').last, // Оплачено
        BookingStatus.active
            .toString()
            .split('.')
            .last, // Активно (клиент заселился)
        BookingStatus.pending.toString().split('.').last, // Для совместимости
        BookingStatus.confirmed.toString().split('.').last, // Для совместимости
      ];

      debugPrint('Проверка активных бронирований для объекта: ${property.id}');
      debugPrint(
        'Текущий статус объекта: ${property.status}, подстатус: ${property.subStatus}',
      );
      debugPrint('Ищем бронирования со статусами: $activeStatuses');

      // Проверяем, есть ли активные бронирования для этого объекта
      final bookingsSnapshot =
          await _firestore
              .collection('bookings')
              .where('propertyId', isEqualTo: property.id)
              .where('status', whereIn: activeStatuses)
              .get();

      debugPrint(
        'Найдено активных бронирований: ${bookingsSnapshot.docs.length}',
      );

      // Если активных бронирований нет, но статус объекта "забронирован",
      // изменяем его на "доступен"
      if (bookingsSnapshot.docs.isEmpty &&
          property.status == PropertyStatus.booked) {
        debugPrint(
          'Автоматическое исправление статуса: объект ${property.id} не имеет активных бронирований, но статус = ${property.status}',
        );

        await _firestore.collection('properties').doc(property.id).update({
          'status': PropertyStatus.available.toString().split('.').last,
          'sub_status': PropertySubStatus.none,
          'updated_at': DateTime.now().toIso8601String(),
        });

        debugPrint(
          'Статус объекта ${property.id} успешно изменен на "доступен"',
        );
      } else if (bookingsSnapshot.docs.isNotEmpty) {
        // Проверяем, нужно ли установить статус booked, если он еще не установлен
        if (property.status != PropertyStatus.booked) {
          // Установим статус booked только если есть бронирования со статусом paid или active
          final paidBookings =
              bookingsSnapshot.docs.where((doc) {
                final status = doc.data()['status'] as String?;
                return status ==
                        BookingStatus.paid.toString().split('.').last ||
                    status == BookingStatus.active.toString().split('.').last;
              }).toList();

          if (paidBookings.isNotEmpty) {
            debugPrint(
              'Найдены оплаченные бронирования для объекта ${property.id}, обновляем статус на booked',
            );

            await _firestore.collection('properties').doc(property.id).update({
              'status': PropertyStatus.booked.toString().split('.').last,
              'sub_status': PropertySubStatus.none,
              'updated_at': DateTime.now().toIso8601String(),
            });

            debugPrint(
              'Статус объекта ${property.id} успешно изменен на "забронирован"',
            );
          }
        }

        // Выводим информацию об активных бронированиях
        for (var doc in bookingsSnapshot.docs) {
          final data = doc.data();
          debugPrint(
            'Активное бронирование: ID=${doc.id}, статус=${data['status']}',
          );
        }
      }
    } catch (e) {
      debugPrint('Ошибка при проверке и исправлении статуса объекта: $e');
    }
  }

  /// Получает объекты владельца
  Future<List<Property>> getPropertiesByOwnerId(String ownerId) async {
    try {
      debugPrint('Запрашиваем объекты для владельца с ID: $ownerId');
      final querySnapshot =
          await _firestore
              .collection('properties')
              .where('owner_id', isEqualTo: ownerId)
              .get();

      debugPrint('Найдено объектов: ${querySnapshot.docs.length}');

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении объектов владельца: $e');
      // В случае ошибки возвращаем пустой список, вместо выброса исключения
      return [];
    }
  }

  /// Возвращает список объектов недвижимости, принадлежащих текущему пользователю
  Future<List<Property>> getOwnerProperties() async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId.isEmpty) {
        debugPrint('getOwnerProperties: userId пустой');
        return [];
      }

      debugPrint('getOwnerProperties: userId = $userId');
      return getPropertiesByOwnerId(userId);
    } catch (e) {
      debugPrint('Ошибка при получении объектов владельца: $e');
      return [];
    }
  }

  /// Возвращает список объектов недвижимости, принадлежащих указанному пользователю
  Future<List<Property>> getUserProperties() async {
    try {
      // Получаем ID пользователя
      final userId = await _authService.getCurrentUserId();
      if (userId.isEmpty) {
        return [];
      }

      // Запрашиваем объекты недвижимости, принадлежащие пользователю
      final snapshot =
          await _firestore
              .collection('properties')
              .where('owner_id', isEqualTo: userId)
              .get();

      return snapshot.docs.map((doc) => _documentToProperty(doc)).toList();
    } catch (e) {
      debugPrint('Ошибка при получении объектов пользователя: $e');
      return [];
    }
  }

  /// Создает новый объект
  Future<Property> createProperty(Property property) async {
    return createPropertyForOwner(property);
  }

  /// Добавляет новый объект (альтернативное имя для createProperty)
  Future<Property> addProperty(Property property) async {
    return createPropertyForOwner(property);
  }

  /// Обновляет объект
  Future<void> updateProperty(Property property) async {
    try {
      await _firestore
          .collection('properties')
          .doc(property.id)
          .update(property.toJson());
    } catch (e) {
      throw Exception('Ошибка при обновлении объекта: $e');
    }
  }

  /// Удаляет объект
  Future<void> deleteProperty(String id) async {
    try {
      await _firestore.collection('properties').doc(id).delete();
    } catch (e) {
      throw Exception('Ошибка при удалении объекта: $e');
    }
  }

  /// Получает рекомендуемые объекты
  Future<List<Property>> getFeaturedProperties() async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .where('is_featured', isEqualTo: true)
              .where('is_active', isEqualTo: true)
              .get();

      return querySnapshot.docs.map((doc) {
        return _documentToProperty(doc);
      }).toList();
    } catch (e) {
      throw Exception('Ошибка при получении рекомендуемых объектов: $e');
    }
  }

  /// Поиск объектов по параметрам
  Future<List<Property>> searchProperties({
    String? query,
    double? minPrice,
    double? maxPrice,
    int? minGuests,
    PropertyType? type,
    String? city,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      Query propertiesQuery = _firestore
          .collection('properties')
          .where('is_active', isEqualTo: true);

      // Фильтр по типу жилья
      if (type != null) {
        propertiesQuery = propertiesQuery.where(
          'type',
          isEqualTo: type.toString().split('.').last,
        );
      }

      // Фильтр по городу
      if (city != null && city.isNotEmpty) {
        propertiesQuery = propertiesQuery.where('city', isEqualTo: city);
      }

      // Фильтр по количеству гостей
      if (minGuests != null) {
        propertiesQuery = propertiesQuery.where(
          'max_guests',
          isGreaterThanOrEqualTo: minGuests,
        );
      }

      // Получаем результаты
      QuerySnapshot querySnapshot;
      if (limit != null) {
        querySnapshot = await propertiesQuery.limit(limit).get();
      } else {
        querySnapshot = await propertiesQuery.get();
      }

      List<Property> properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      // Дополнительная фильтрация в памяти для условий, которые сложно выразить в запросе
      if (minPrice != null || maxPrice != null || query != null) {
        properties =
            properties.where((property) {
              // Фильтр по минимальной цене
              if (minPrice != null && property.pricePerNight < minPrice) {
                return false;
              }

              // Фильтр по максимальной цене
              if (maxPrice != null && property.pricePerNight > maxPrice) {
                return false;
              }

              // Поиск по тексту
              if (query != null && query.isNotEmpty) {
                final queryLower = query.toLowerCase();
                return property.title.toLowerCase().contains(queryLower) ||
                    property.description.toLowerCase().contains(queryLower) ||
                    property.address.toLowerCase().contains(queryLower);
              }

              return true;
            }).toList();
      }

      return properties;
    } catch (e) {
      throw Exception('Ошибка при поиске объектов: $e');
    }
  }

  /// Проверяет доступность объекта на указанные даты
  Future<bool> checkAvailability({
    required String propertyId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Получаем объект
      final property = await getPropertyById(propertyId);

      if (property == null) {
        throw Exception('Объект не найден');
      }

      // Получаем все бронирования для этого объекта
      final bookingsSnapshot =
          await _firestore
              .collection('bookings')
              .where('property_id', isEqualTo: propertyId)
              .where(
                'status',
                whereIn: [
                  'BookingStatus.confirmed',
                  'BookingStatus.active',
                  'BookingStatus.pending',
                ],
              )
              .get();

      // Проверяем пересечения с существующими бронированиями
      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final checkInDate = (data['check_in_date'] as Timestamp).toDate();
        final checkOutDate = (data['check_out_date'] as Timestamp).toDate();

        // Проверяем пересечение дат
        if ((startDate.isBefore(checkOutDate) ||
                startDate.isAtSameMomentAs(checkOutDate)) &&
            (endDate.isAfter(checkInDate) ||
                endDate.isAtSameMomentAs(checkInDate))) {
          return false; // Есть пересечение, объект не доступен
        }
      }

      return true; // Нет пересечений, объект доступен
    } catch (e) {
      debugPrint('Ошибка при проверке доступности: $e');
      throw Exception('Ошибка при проверке доступности: $e');
    }
  }

  /// Добавляет объект в избранное
  Future<void> addToFavorites(String userId, String propertyId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(propertyId)
          .set({'added_at': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Ошибка при добавлении в избранное: $e');
    }
  }

  /// Удаляет объект из избранного
  Future<void> removeFromFavorites(String userId, String propertyId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(propertyId)
          .delete();
    } catch (e) {
      throw Exception('Ошибка при удалении из избранного: $e');
    }
  }

  /// Проверяет, находится ли объект в избранном
  Future<bool> isPropertyInFavorites(String userId, String propertyId) async {
    try {
      final docSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .doc(propertyId)
              .get();

      return docSnapshot.exists;
    } catch (e) {
      throw Exception('Ошибка при проверке избранного: $e');
    }
  }

  /// Получает список избранных объектов пользователя
  Future<List<Property>> getFavoriteProperties(String userId) async {
    try {
      final favoritesSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .get();

      final propertyIds = favoritesSnapshot.docs.map((doc) => doc.id).toList();

      if (propertyIds.isEmpty) return [];

      final propertiesSnapshot =
          await _firestore
              .collection('properties')
              .where(FieldPath.documentId, whereIn: propertyIds)
              .get();

      return propertiesSnapshot.docs.map((doc) {
        return _documentToProperty(doc);
      }).toList();
    } catch (e) {
      throw Exception('Ошибка при получении избранных объектов: $e');
    }
  }

  /// Загружает изображения объекта недвижимости в Firebase Storage
  Future<List<String>> uploadPropertyImages(
    String propertyId,
    List<File> images,
  ) async {
    try {
      final List<String> imageUrls = [];

      for (var i = 0; i < images.length; i++) {
        final file = images[i];
        final extension = file.path.split('.').last;
        final ref = _storage
            .ref()
            .child('properties')
            .child(propertyId)
            .child('image_$i.$extension');

        final uploadTask = await ref.putFile(file);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        imageUrls.add(downloadUrl);
      }

      return imageUrls;
    } catch (e) {
      throw Exception('Ошибка при загрузке изображений: $e');
    }
  }

  /// Удаляет изображения объекта из Firebase Storage
  Future<void> deletePropertyImages(
    String propertyId,
    List<String> imageUrls,
  ) async {
    try {
      for (var url in imageUrls) {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      }
    } catch (e) {
      throw Exception('Ошибка при удалении изображений: $e');
    }
  }

  /// Получает координаты города по умолчанию (Алматы)
  Location getDefaultCityLocation() {
    return const Location(latitude: 43.238949, longitude: 76.889709);
  }

  /// Создает новый объект недвижимости для владельца
  Future<Property> createPropertyForOwner(Property property) async {
    try {
      // Получаем ID текущего пользователя
      final userId = await _authService.getCurrentUserId();
      if (userId.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }

      // Убедимся, что owner_id установлен правильно
      final propertyWithOwnerId = property.copyWith(ownerId: userId);

      // Создаем идентификатор документа заранее
      final docRef = _firestore.collection('properties').doc();
      final docId = docRef.id;

      // Преобразуем в формат для Firestore с уже установленным id
      final propertyData = {
        'id': docId, // Устанавливаем ID сразу
        'title': propertyWithOwnerId.title,
        'description': propertyWithOwnerId.description,
        'owner_id': propertyWithOwnerId.ownerId,
        'type': propertyWithOwnerId.type.toString().split('.').last,
        'status': propertyWithOwnerId.status.toString().split('.').last,
        'image_urls': propertyWithOwnerId.imageUrls,
        'address': propertyWithOwnerId.address,
        'city': propertyWithOwnerId.city,
        'country': propertyWithOwnerId.country,
        'latitude': propertyWithOwnerId.latitude,
        'longitude': propertyWithOwnerId.longitude,
        'price_per_night': propertyWithOwnerId.pricePerNight,
        'price_per_hour': propertyWithOwnerId.pricePerHour,
        'area': propertyWithOwnerId.area,
        'rooms': propertyWithOwnerId.rooms,
        'bathrooms': propertyWithOwnerId.bathrooms,
        'max_guests': propertyWithOwnerId.maxGuests,
        'has_wifi': propertyWithOwnerId.hasWifi,
        'has_air_conditioning': propertyWithOwnerId.hasAirConditioning,
        'has_kitchen': propertyWithOwnerId.hasKitchen,
        'has_tv': propertyWithOwnerId.hasTV,
        'has_washing_machine': propertyWithOwnerId.hasWashingMachine,
        'has_parking': propertyWithOwnerId.hasParking,
        'pet_friendly': propertyWithOwnerId.petFriendly,
        'check_in_time': propertyWithOwnerId.checkInTime,
        'check_out_time': propertyWithOwnerId.checkOutTime,
        'is_featured': propertyWithOwnerId.isFeatured,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      debugPrint('Создаем объект недвижимости для владельца $userId');

      // Сохраняем документ с заранее созданным ID
      await docRef.set(propertyData);

      // Создаем полный объект с id
      final newProperty = propertyWithOwnerId.copyWith(id: docId);

      debugPrint('Объект успешно создан с ID: $docId');
      return newProperty;
    } catch (e) {
      debugPrint('Ошибка при создании объекта: $e');
      throw Exception('Ошибка при создании объекта: $e');
    }
  }

  /// Получает объекты по статусу и подстатусу
  Future<List<Property>> getPropertiesByStatusAndSubStatus(
    String ownerId,
    PropertyStatus? status,
    String? subStatus,
  ) async {
    try {
      Query query = _firestore
          .collection('properties')
          .where('owner_id', isEqualTo: ownerId);

      if (status != null) {
        query = query.where(
          'status',
          isEqualTo: status.toString().split('.').last,
        );
      }

      if (subStatus != null) {
        query = query.where('sub_status', isEqualTo: subStatus);
      }

      final querySnapshot = await query.get();

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении объектов по статусу: $e');
      return [];
    }
  }

  /// Обновляет статус объекта
  Future<void> updatePropertyStatus(
    String propertyId,
    PropertyStatus status,
  ) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'status': status.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('Ошибка при обновлении статуса объекта: $e');
    }
  }

  /// Обновляет подстатус объекта
  Future<void> updatePropertySubStatus(
    String propertyId,
    String subStatus,
  ) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'sub_status': subStatus,
      });
    } catch (e) {
      throw Exception('Ошибка при обновлении подстатуса объекта: $e');
    }
  }

  /// Устанавливает время окончания бронирования
  Future<void> setBookingEndTime(String propertyId, DateTime endTime) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'booking_end_time': endTime.millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception(
        'Ошибка при установке времени окончания бронирования: $e',
      );
    }
  }

  /// Обновляет статус и подстатус объекта одним запросом
  Future<void> updatePropertyStatusAndSubStatus(
    String propertyId,
    PropertyStatus status,
    String subStatus,
  ) async {
    try {
      debugPrint(
        'Обновление статуса объекта $propertyId: статус=${status.toString().split('.').last}, подстатус=$subStatus',
      );

      // Получаем объект, чтобы проверить текущие статусы
      final property = await getPropertyById(propertyId);
      debugPrint(
        'Текущий статус объекта: ${property?.status}, подстатус: ${property?.subStatus}',
      );

      // Обновляем все возможные форматы полей для совместимости
      Map<String, dynamic> updates = {
        // Snake case (как используется в некоторых частях кода)
        'status': status.toString().split('.').last,
        'sub_status': subStatus,
        'updated_at': DateTime.now().toIso8601String(),

        // CamelCase (как используется в других частях кода)
        'subStatus': subStatus,
        'updatedAt': DateTime.now().toIso8601String(),

        // Дополнительно обновляем другие связанные поля
        'lastStatusUpdate': DateTime.now().millisecondsSinceEpoch,
      };

      // Если статус меняется на booked, также обновляем bookingId, если еще не задан
      if (status == PropertyStatus.booked &&
          (property?.bookingId == null || property!.bookingId!.isEmpty)) {
        // Ищем соответствующее бронирование
        final bookingsSnapshot =
            await _firestore
                .collection('bookings')
                .where('propertyId', isEqualTo: propertyId)
                .where('status', whereIn: ['paid', 'active'])
                .get();

        if (bookingsSnapshot.docs.isNotEmpty) {
          final bookingId = bookingsSnapshot.docs.first.id;
          updates['bookingId'] = bookingId;
          updates['booking_id'] = bookingId; // snake_case версия
          debugPrint(
            'Установка bookingId = $bookingId для объекта $propertyId',
          );
        }
      }

      await _firestore.collection('properties').doc(propertyId).update(updates);

      // Проверяем, успешно ли обновился статус
      final updatedProperty = await getPropertyById(propertyId);
      debugPrint(
        'Новый статус объекта после обновления: ${updatedProperty?.status}, подстатус: ${updatedProperty?.subStatus}',
      );

      debugPrint('Статус и подстатус объекта $propertyId успешно обновлены');
    } catch (e) {
      debugPrint('Ошибка при обновлении статуса и подстатуса объекта: $e');
      // Логируем дополнительную информацию для отладки
      debugPrint('propertyId: $propertyId');
      debugPrint('status: ${status.toString()}');
      debugPrint('subStatus: $subStatus');
    }
  }

  /// Получает активные объекты для владельца
  Future<List<Property>> getActivePropertiesForOwner(String ownerId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .where('owner_id', isEqualTo: ownerId)
              .where('status', isEqualTo: 'available')
              .get();

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении активных объектов владельца: $e');
      return [];
    }
  }

  /// Получает забронированные объекты для владельца
  Future<List<Property>> getBookedPropertiesForOwner(String ownerId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .where('owner_id', isEqualTo: ownerId)
              .where('status', isEqualTo: 'booked')
              .get();

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении забронированных объектов владельца: $e');
      return [];
    }
  }

  /// Получает объекты на уборке для владельца
  Future<List<Property>> getCleaningPropertiesForOwner(String ownerId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .where('owner_id', isEqualTo: ownerId)
              .where('status', isEqualTo: 'cleaning')
              .get();

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении объектов на уборке: $e');
      return [];
    }
  }

  /// Получает объекты по подстатусу для владельца
  Future<List<Property>> getPropertiesBySubStatusForOwner(
    String ownerId,
    String subStatus,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .where('owner_id', isEqualTo: ownerId)
              .where('sub_status', isEqualTo: subStatus)
              .get();

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении объектов по подстатусу: $e');
      return [];
    }
  }

  /// Получает объекты по статусу для уборщиков
  Future<List<Property>> getPropertiesForCleaner() async {
    try {
      final querySnapshot =
          await _firestore
              .collection('properties')
              .where('status', isEqualTo: 'cleaning')
              .where('sub_status', isEqualTo: 'waiting_cleaning')
              .get();

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении объектов для уборщика: $e');
      return [];
    }
  }

  /// Получает объекты по статусу
  Future<List<Property>> getPropertiesByStatus(
    String? ownerId,
    PropertyStatus status,
  ) async {
    try {
      Query query = _firestore.collection('properties');

      if (ownerId != null) {
        query = query.where('owner_id', isEqualTo: ownerId);
      }

      query = query.where(
        'status',
        isEqualTo: status.toString().split('.').last,
      );

      final querySnapshot = await query.get();

      final properties =
          querySnapshot.docs.map((doc) {
            return _documentToProperty(doc);
          }).toList();

      return properties;
    } catch (e) {
      debugPrint('Ошибка при получении объектов по статусу: $e');
      return [];
    }
  }

  /// Делает объект доступным для бронирования
  Future<bool> makePropertyAvailable(String propertyId) async {
    try {
      // Получаем текущий объект, чтобы проверить его статус
      final property = await getPropertyById(propertyId);

      if (property == null) {
        debugPrint('Объект с ID $propertyId не найден');
        return false;
      }

      // Обновляем статус объекта на "доступен"
      await _firestore.collection('properties').doc(propertyId).update({
        'status': PropertyStatus.available.toString().split('.').last,
        'sub_status': PropertySubStatus.none,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Объект с ID $propertyId теперь доступен для бронирования');
      return true;
    } catch (e) {
      debugPrint('Ошибка при изменении статуса объекта на "доступен": $e');
      return false;
    }
  }

  /// Проверяет и исправляет статусы всех объектов с оплаченными бронированиями
  Future<void> fixAllPropertyStatuses() async {
    try {
      debugPrint('Запуск массового исправления статусов объектов...');

      // Получаем все оплаченные или активные бронирования
      final paidBookingsSnapshot =
          await _firestore
              .collection('bookings')
              .where('status', whereIn: ['paid', 'active'])
              .get();

      debugPrint(
        'Найдено ${paidBookingsSnapshot.docs.length} оплаченных/активных бронирований',
      );

      // Обрабатываем каждое бронирование
      for (var bookingDoc in paidBookingsSnapshot.docs) {
        final bookingData = bookingDoc.data();
        final propertyId = bookingData['propertyId'] as String;

        // Проверяем текущий статус объекта
        final propertyDoc =
            await _firestore.collection('properties').doc(propertyId).get();
        if (!propertyDoc.exists) {
          debugPrint('Объект $propertyId не найден в базе данных');
          continue;
        }

        final propertyData = propertyDoc.data()!;
        final currentStatus = propertyData['status'] as String?;

        // Если статус не "booked", исправляем его
        if (currentStatus != PropertyStatus.booked.toString().split('.').last) {
          debugPrint(
            'Исправление статуса объекта $propertyId: текущий статус=$currentStatus, требуемый=booked',
          );

          // Обновляем все возможные поля для статуса
          Map<String, dynamic> updates = {
            // Snake case
            'status': PropertyStatus.booked.toString().split('.').last,
            'sub_status': PropertySubStatus.none,
            'updated_at': DateTime.now().toIso8601String(),
            'booking_id': bookingDoc.id,

            // CamelCase
            'subStatus': PropertySubStatus.none,
            'updatedAt': DateTime.now().toIso8601String(),
            'bookingId': bookingDoc.id,

            // Дополнительные поля
            'lastStatusUpdate': DateTime.now().millisecondsSinceEpoch,
          };

          await _firestore
              .collection('properties')
              .doc(propertyId)
              .update(updates);
          debugPrint(
            'Статус объекта $propertyId успешно исправлен на "booked"',
          );
        } else {
          debugPrint('Объект $propertyId уже имеет корректный статус "booked"');
        }
      }

      debugPrint('Массовое исправление статусов объектов завершено');
    } catch (e) {
      debugPrint('Ошибка при массовом исправлении статусов объектов: $e');
    }
  }
}
