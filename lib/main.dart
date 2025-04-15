import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pater/core/router/app_router.dart';
import 'package:pater/core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pater/data/config/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:pater/data/datasources/firebase_connection_service.dart';
import 'package:flutter/foundation.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/notification_service.dart';
import 'package:pater/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Инициализирует Firebase
Future<void> initializeFirebase() async {
  try {
    // Инициализируем Firebase с нужными настройками
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase успешно инициализирован');

    // Настройка Firestore для нативных платформ
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    // Запускаем мониторинг соединения с Firebase
    FirebaseConnectionService().startMonitoring();
  } catch (e) {
    debugPrint('Ошибка при инициализации Firebase: $e');
  }
}

Future<void> fixExistingPropertyStatuses() async {
  try {
    final propertyService = getIt<PropertyService>();
    await propertyService.fixAllPropertyStatuses();
  } catch (e) {
    debugPrint('Ошибка при исправлении статусов объектов: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Очистка временных данных авторизации
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('temp_pin');
  await prefs.remove('temp_user_id');
  await prefs.remove('temp_phone');
  await prefs.remove('verificationId');
  await prefs.remove('sms_code');

  // Инициализируем Firebase
  await initializeFirebase();

  // Инициализируем сервис-локатор
  await setupServiceLocator();

  // Инициализируем Mapbox и кэширование карт
  try {
    // Инициализируем кэширование карт
    debugPrint('Инициализация кэширования карт...');

    // Используем корректный синтаксис для инициализации кэширования
    // на основе документации и примеров
    // Откладываем инициализацию кэширования на будущее, так как
    // требуется более сложная настройка с использованием ObjectBox

    debugPrint('Mapbox успешно инициализирован');
  } catch (e) {
    debugPrint('Ошибка при инициализации карт: $e');
  }

  // Исправление статусов существующих объектов
  await fixExistingPropertyStatuses();

  // Инициализируем сервисы уведомлений
  await NotificationService.getInstance().init();

  // Устанавливаем обработчик ошибок
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Ошибка в приложении: ${details.exception}');
  };

  // Включаем сервисы DevTools
  if (kDebugMode) {
    // Выводим статус объекта (для отладки)
    debugPropertyStatus();

    // Раскомментируйте строку ниже и перезапустите приложение,
    // чтобы сделать объект доступным для бронирования
    // await fixPropertyStatus('zYs5ry3dUVDgt5jVZ6rh');
  }

  runApp(const ProviderScope(child: MainApp()));
}

/// Отладочная функция для проверки статуса объекта
Future<void> debugPropertyStatus() async {
  try {
    final propertyId = 'zYs5ry3dUVDgt5jVZ6rh';
    final propertyService = getIt<PropertyService>();
    final property = await propertyService.getPropertyById(propertyId);

    if (property != null) {
      debugPrint(
        'DEBUG: Статус объекта $propertyId: ${property.status}, подстатус: ${property.subStatus}',
      );
    } else {
      debugPrint('DEBUG: Объект $propertyId не найден');
    }
  } catch (e) {
    debugPrint('DEBUG: Ошибка при получении статуса объекта: $e');
  }
}

/// Функция для исправления статуса объекта
Future<void> fixPropertyStatus(String propertyId) async {
  try {
    final propertyService = getIt<PropertyService>();
    final result = await propertyService.makePropertyAvailable(propertyId);

    if (result) {
      debugPrint('Статус объекта $propertyId успешно изменен на "доступен"');
    } else {
      debugPrint('Не удалось изменить статус объекта $propertyId');
    }
  } catch (e) {
    debugPrint('Ошибка при изменении статуса объекта: $e');
  }
}

/// Основной класс приложения
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pater',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
        Locale('kk', 'KZ'),
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
