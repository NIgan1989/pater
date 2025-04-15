import 'package:pater/domain/entities/user.dart';
import 'package:pater/domain/repositories/user_repository.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:pater/domain/entities/user_role.dart';

class UserRepositoryImpl implements UserRepository {
  final UserService _userService;

  UserRepositoryImpl(this._userService);

  @override
  Future<User?> getUserById(String id) async {
    return _userService.getUserById(id);
  }

  @override
  Future<User> updateUser(User user) async {
    return _userService.updateUser(user);
  }

  @override
  Future<User> createUser(User user) async {
    return _userService.createUser(user);
  }

  @override
  Future<bool> userExists(String id) async {
    return _userService.userExists(id);
  }

  @override
  Future<double> getUserBalance(String userId) async {
    return _userService.getUserBalance(userId);
  }

  @override
  Future<void> updateUserBalance(String userId, double newBalance) async {
    await _userService.updateUserBalance(userId, newBalance);
  }

  @override
  Future<List<User>> getUsersByRole(UserRole role) async {
    return _userService.getUsersByRole(role);
  }

  @override
  Future<List<User>> getCleaners() async {
    return _userService.getCleaners();
  }

  @override
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

  @override
  Future<List<Map<String, dynamic>>> getReviewsByCleanerId(
    String cleanerId,
  ) async {
    return _userService.getReviewsByCleanerId(cleanerId);
  }

  @override
  Future<User?> getUserProfile(String userId) async {
    return _userService.getUserProfile(userId);
  }

  @override
  Future<bool> updateUserProfile(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    return _userService.updateUserProfile(userId, userData);
  }

  @override
  Future<String?> uploadUserAvatar(String userId, String imagePath) async {
    return _userService.uploadUserAvatar(userId, imagePath);
  }

  @override
  Future<List<User>> getTopCleaners({int limit = 10}) async {
    return _userService.getTopCleaners(limit: limit);
  }
}
