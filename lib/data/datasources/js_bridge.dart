import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:js/js.dart' as js;
import 'package:js/js_util.dart' as js_util;

/// Утилита для безопасного взаимодействия с JavaScript в веб-среде
class JsBridge {
  /// Проверяет доступность JavaScript
  static bool get isJsAvailable => kIsWeb;
  
  /// Вызывает JavaScript функцию по имени с заданными аргументами
  static Future<dynamic> callMethod(String methodName, [List<dynamic>? args]) async {
    if (!isJsAvailable) {
      throw Exception('JavaScript недоступен в текущей среде');
    }
    
    try {
      final completer = Completer<dynamic>();
      final timeout = Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.completeError('Таймаут вызова JavaScript метода: $methodName');
        }
      });
      
      // Получаем глобальный объект и нашу функцию
      final context = js_util.globalThis;
      final dartInterop = js_util.getProperty(context, 'dartInterop');
      
      if (dartInterop == null) {
        throw Exception('dartInterop модуль не найден');
      }
      
      // Получаем метод и вызываем его
      // Проверяем наличие метода (но не сохраняем в переменную, чтобы избежать предупреждения)
      if (!js_util.hasProperty(dartInterop, methodName)) {
        throw Exception('Метод $methodName не найден в dartInterop');
      }
      
      final result = js_util.callMethod(dartInterop, methodName, args ?? []);
      
      timeout.cancel();
      
      if (js_util.hasProperty(result, 'then')) {
        // Это Promise, нужно обработать асинхронно
        final completer = Completer<dynamic>();
        
        js_util.callMethod(result, 'then', [
          js.allowInterop((value) {
            completer.complete(value);
          }),
          js.allowInterop((error) {
            completer.completeError(error.toString());
          })
        ]);
        
        return completer.future;
      } else {
        // Синхронный результат
        return result;
      }
    } catch (e) {
      throw Exception('Ошибка при вызове JavaScript метода $methodName: $e');
    }
  }
  
  /// Выполняет произвольный JavaScript код
  static Future<dynamic> eval(String code) async {
    if (!isJsAvailable) {
      throw Exception('JavaScript недоступен в текущей среде');
    }
    
    try {
      final completer = Completer<dynamic>();
      final timeout = Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.completeError('Таймаут выполнения JavaScript кода');
        }
      });
      
      final context = js_util.globalThis;
      final result = js_util.callMethod(context, 'eval', [code]);
      
      timeout.cancel();
      
      if (js_util.hasProperty(result, 'then')) {
        // Это Promise, нужно обработать асинхронно
        final completer = Completer<dynamic>();
        
        js_util.callMethod(result, 'then', [
          js.allowInterop((value) {
            completer.complete(value);
          }),
          js.allowInterop((error) {
            completer.completeError(error.toString());
          })
        ]);
        
        return completer.future;
      } else {
        // Синхронный результат
        return result;
      }
    } catch (e) {
      throw Exception('Ошибка при выполнении JavaScript кода: $e');
    }
  }
  
  /// Выполняет JavaScript код и возвращает результат как bool
  static Future<bool> evalBool(String code) async {
    final result = await eval(code);
    return result == true;
  }
  
  /// Выполняет JavaScript код и возвращает результат как String
  static Future<String> evalString(String code) async {
    final result = await eval(code);
    return result?.toString() ?? '';
  }
  
  /// Проверяет существование JavaScript объекта по пути
  static bool objectExists(String objectPath) {
    if (!isJsAvailable) return false;
    
    try {
      final code = 'typeof $objectPath !== "undefined" && $objectPath !== null';
      final context = js_util.globalThis;
      final result = js_util.callMethod(context, 'eval', [code]);
      return result == true;
    } catch (e) {
      return false;
    }
  }
  
  /// Проверяет доступность Firebase в текущей среде
  static Future<bool> isFirebaseAvailable() async {
    if (!isJsAvailable) return false;
    
    try {
      return await evalBool('typeof firebase !== "undefined" && firebase.apps.length > 0');
    } catch (e) {
      return false;
    }
  }
} 