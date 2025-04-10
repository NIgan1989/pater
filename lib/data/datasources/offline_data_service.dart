import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pater/data/datasources/firebase_connection_service.dart';

/// Сервис для работы с данными в офлайн-режиме
class OfflineDataService {
  static final OfflineDataService _instance = OfflineDataService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseConnectionService _connectionService = FirebaseConnectionService();
  
  factory OfflineDataService() {
    return _instance;
  }
  
  OfflineDataService._internal();
  
  /// Получает документ с поддержкой офлайн-режима
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String collection,
    String documentId, {
    GetOptions? options,
  }) async {
    try {
      // Пробуем получить документ с сервера
      final doc = await _firestore
          .collection(collection)
          .doc(documentId)
          .get(options ?? const GetOptions(source: Source.serverAndCache));
      
      return doc;
    } catch (e) {
      // Если произошла ошибка, пробуем получить из кэша
      try {
        return await _firestore
            .collection(collection)
            .doc(documentId)
            .get(const GetOptions(source: Source.cache));
      } catch (e) {
        rethrow;
      }
    }
  }
  
  /// Получает коллекцию с поддержкой офлайн-режима
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(
    String collection, {
    Query Function(Query)? queryBuilder,
    GetOptions? options,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      
      // Пробуем получить данные с сервера
      final result = await query.get(options ?? const GetOptions(source: Source.serverAndCache));
      return result as QuerySnapshot<Map<String, dynamic>>;
    } catch (e) {
      // Если произошла ошибка, пробуем получить из кэша
      try {
        Query query = _firestore.collection(collection);
        
        if (queryBuilder != null) {
          query = queryBuilder(query);
        }
        
        final result = await query.get(const GetOptions(source: Source.cache));
        return result as QuerySnapshot<Map<String, dynamic>>;
      } catch (e) {
        rethrow;
      }
    }
  }
  
  /// Устанавливает данные с поддержкой офлайн-режима
  Future<void> setData(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      // Если произошла ошибка, пробуем сохранить локально
      try {
        await _firestore
            .collection(collection)
            .doc(documentId)
            .set(data, SetOptions(merge: true));
      } catch (e) {
        rethrow;
      }
    }
  }
  
  /// Принудительно переподключается к Firebase с защитой от частых вызовов
  Future<void> reconnect() async {
    await _connectionService.forceReconnect();
  }
} 