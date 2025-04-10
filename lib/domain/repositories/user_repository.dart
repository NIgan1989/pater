import 'package:pater/domain/entities/user.dart';

/// Интерфейс репозитория для работы с пользователями
abstract class UserRepository {
  /// Получает пользователя по ID
  Future<User?> getUserById(String id);

  /// Обновляет данные пользователя
  Future<User> updateUser(User user);

  /// Создает нового пользователя
  Future<User> createUser(User user);

  /// Проверяет существование пользователя
  Future<bool> userExists(String id);

  /// Получает баланс пользователя
  Future<double> getUserBalance(String userId);

  /// Обновляет баланс пользователя
  Future<void> updateUserBalance(String userId, double newBalance);

  /// Получает список пользователей по роли
  Future<List<User>> getUsersByRole(UserRole role);

  /// Получает список уборщиков
  Future<List<User>> getCleaners();

  /// Добавляет отзыв о пользователе
  Future<void> addReview({
    required String cleanerId,
    required String reviewerId,
    required String requestId,
    required double rating,
    String? text,
  });

  /// Получает отзывы о пользователе
  Future<List<Map<String, dynamic>>> getReviewsByCleanerId(String cleanerId);

  /// Получает профиль пользователя
  Future<User?> getUserProfile(String userId);

  /// Обновляет профиль пользователя
  Future<bool> updateUserProfile(String userId, Map<String, dynamic> userData);

  /// Загружает аватар пользователя
  Future<String?> uploadUserAvatar(String userId, String imagePath);

  /// Получает топ уборщиков
  Future<List<User>> getTopCleaners({int limit = 10});
} 