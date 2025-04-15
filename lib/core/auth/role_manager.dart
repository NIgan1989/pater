import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pater/domain/entities/user_role.dart';

class RoleManager {
  static const String _activeRoleKey = 'active_role';
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;

  RoleManager({
    required FirebaseFirestore firestore,
    required SharedPreferences prefs,
  }) : _firestore = firestore,
       _prefs = prefs;

  // Фабричный метод для создания экземпляра с параметрами по умолчанию
  static RoleManager? _instance;

  static Future<RoleManager> instance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = RoleManager(
        firestore: FirebaseFirestore.instance,
        prefs: prefs,
      );
    }
    return _instance!;
  }

  Future<UserRole> getUserRole(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return UserRole.client;

      final data = doc.data();
      if (data == null) return UserRole.client;

      final roleStr = data['role'] as String?;
      if (roleStr == null) return UserRole.client;

      return UserRole.values.firstWhere(
        (role) => role.toString() == 'UserRole.$roleStr',
        orElse: () => UserRole.client,
      );
    } catch (e) {
      return UserRole.client;
    }
  }

  Future<List<UserRole>> getUserRoles(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return [UserRole.client];

      final data = doc.data();
      if (data == null) return [UserRole.client];

      final rolesList = data['roles'] as List<dynamic>?;
      if (rolesList == null) return [UserRole.client];

      return rolesList.map((role) {
        return UserRole.values.firstWhere(
          (r) => r.toString() == 'UserRole.$role',
          orElse: () => UserRole.client,
        );
      }).toList();
    } catch (e) {
      return [UserRole.client];
    }
  }

  Future<void> changeUserRole(String userId, UserRole newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole.toString().split('.').last,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addUserRole(String userId, UserRole role) async {
    try {
      final roles = await getUserRoles(userId);
      if (!roles.contains(role)) {
        roles.add(role);
        await _firestore.collection('users').doc(userId).update({
          'roles': roles.map((r) => r.toString().split('.').last).toList(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeUserRole(String userId, UserRole role) async {
    try {
      final roles = await getUserRoles(userId);
      roles.remove(role);
      await _firestore.collection('users').doc(userId).update({
        'roles': roles.map((r) => r.toString().split('.').last).toList(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setActiveRole(UserRole role) async {
    try {
      await _prefs.setString(_activeRoleKey, role.toString().split('.').last);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserRole> getActiveRole() async {
    try {
      final roleStr = _prefs.getString(_activeRoleKey);
      if (roleStr == null) return UserRole.client;

      return UserRole.values.firstWhere(
        (role) => role.toString() == 'UserRole.$roleStr',
        orElse: () => UserRole.client,
      );
    } catch (e) {
      return UserRole.client;
    }
  }

  String getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'assets/icons/client.png';
      case UserRole.cleaner:
        return 'assets/icons/cleaner.png';
      case UserRole.owner:
        return 'assets/icons/owner.png';
      case UserRole.admin:
        return 'assets/icons/admin.png';
      case UserRole.support:
        return 'assets/icons/support.png';
    }
  }

  String getRoleName(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'Клиент';
      case UserRole.cleaner:
        return 'Клининг';
      case UserRole.owner:
        return 'Владелец';
      case UserRole.admin:
        return 'Администратор';
      case UserRole.support:
        return 'Служба поддержки';
    }
  }

  String getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'Бронирование жилья и доступ к каталогу объектов';
      case UserRole.cleaner:
        return 'Управление заявками на уборку и календарь работ';
      case UserRole.owner:
        return 'Управление объектами недвижимости и бронированиями';
      case UserRole.admin:
        return 'Администратор системы';
      case UserRole.support:
        return 'Служба поддержки пользователей';
    }
  }
}
