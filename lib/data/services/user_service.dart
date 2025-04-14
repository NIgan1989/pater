import 'package:pater/domain/entities/user.dart';
import 'package:pater/data/datasources/user_service.dart' as datasource;
import 'package:pater/domain/entities/user_role.dart';

/// Сервис для работы с пользователями (обертка над UserService из datasources)
class UserService {
  static final UserService _instance = UserService._internal();
  final datasource.UserService _userService = datasource.UserService();
  final bool _isInitialized = false;

  factory UserService() {
    return _instance;
  }

  UserService._internal();

  /// Проверяет, инициализирован ли сервис
  bool get isInitialized => _isInitialized;

  /// Получает ID текущего пользователя
  String getCurrentUserId() {
    // В реальном приложении нужно реализовать получение ID текущего пользователя
    // из SharedPreferences или Firebase Auth
    // Временная заглушка для тестирования
    return 'test_user_id';
  }

  /// Получает пользователя по ID
  Future<User?> getUserById(String id) async {
    return _userService.getUserById(id);
  }

  /// Обновляет данные пользователя
  Future<User> updateUser(User user) async {
    return _userService.updateUser(user);
  }

  /// Создает нового пользователя
  Future<User> createUser(User user) async {
    return _userService.createUser(user);
  }

  /// Проверяет существование пользователя
  Future<bool> userExists(String id) async {
    return _userService.userExists(id);
  }

  /// Получает текущий баланс пользователя
  Future<double> getUserBalance(String userId) async {
    return _userService.getUserBalance(userId);
  }

  /// Обновляет баланс пользователя
  Future<void> updateUserBalance(String userId, double newBalance) async {
    await _userService.updateUserBalance(userId, newBalance);
  }

  /// Получает список пользователей по ролям
  Future<List<User>> getUsersByRole(UserRole role) async {
    return _userService.getUsersByRole(role);
  }

  /// Получает список клинеров
  Future<List<User>> getCleaners() async {
    return _userService.getCleaners();
  }

  /// Добавляет отзыв о клинере
  Future<void> addReview({
    required String cleanerId,
    required String reviewerId,
    required String requestId,
    required double rating,
    String? text,
  }) async {
    await _userService.addReview(
      cleanerId: cleanerId,
      reviewerId: reviewerId,
      requestId: requestId,
      rating: rating,
      text: text,
    );
  }

  /// Получает отзывы о клинере
  Future<List<Map<String, dynamic>>> getReviewsByCleanerId(
    String cleanerId,
  ) async {
    return _userService.getReviewsByCleanerId(cleanerId);
  }

  /// Загружает профиль пользователя
  Future<User?> getUserProfile(String userId) async {
    return _userService.getUserProfile(userId);
  }

  /// Обновляет профиль пользователя
  Future<bool> updateUserProfile(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    return _userService.updateUserProfile(userId, userData);
  }

  /// Загружает аватар пользователя
  Future<String?> uploadUserAvatar(String userId, String imagePath) async {
    return _userService.uploadUserAvatar(userId, imagePath);
  }
}
