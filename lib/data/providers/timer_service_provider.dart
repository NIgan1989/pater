import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pater/data/services/timer_service.dart';

/// Провайдер для сервиса таймера
final timerServiceProvider = Provider<TimerService>((ref) {
  final service = TimerService(ref);
  service.initialize();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
