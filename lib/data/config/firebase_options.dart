// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  /// Возвращает конфигурацию Firebase для текущей платформы
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Конфигурация Firebase для Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDSvhX44cmec1z2MPFzJXAg_mtlNynten4',
    appId: '1:705593932334:web:c916413096c240241dbdbf',
    messagingSenderId: '705593932334',
    projectId: 'pater-74569',
    authDomain: 'pater-74569.firebaseapp.com',
    storageBucket: 'pater-74569.firebasestorage.app',
    measurementId: 'G-Y70YD5M7F2',
  );

  /// Конфигурация Firebase для Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDsMNhlMP8VdgrfLx7stE3sey_94ve6Rsc',
    appId: '1:705593932334:android:aba79e9491d4b5dd1dbdbf',
    messagingSenderId: '705593932334',
    projectId: 'pater-74569',
    storageBucket: 'pater-74569.firebasestorage.app',
  );

  /// Конфигурация Firebase для iOS
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBIQTANLaolYqXDY4LYLK8r4l1Wv96H-sw',
    appId: '1:705593932334:ios:e1d1a8b14d3a817e1dbdbf',
    messagingSenderId: '705593932334',
    projectId: 'pater-74569',
    storageBucket: 'pater-74569.firebasestorage.app',
    iosBundleId: 'com.example.pater',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBIQTANLaolYqXDY4LYLK8r4l1Wv96H-sw',
    appId: '1:705593932334:ios:e1d1a8b14d3a817e1dbdbf',
    messagingSenderId: '705593932334',
    projectId: 'pater-74569',
    storageBucket: 'pater-74569.firebasestorage.app',
    iosBundleId: 'com.example.pater',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDSvhX44cmec1z2MPFzJXAg_mtlNynten4',
    appId: '1:705593932334:web:fa0358933a410de51dbdbf',
    messagingSenderId: '705593932334',
    projectId: 'pater-74569',
    authDomain: 'pater-74569.firebaseapp.com',
    storageBucket: 'pater-74569.firebasestorage.app',
    measurementId: 'G-N7VM40BXFD',
  );
} 