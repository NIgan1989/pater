import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:pater/domain/entities/user.dart' as domain;
import 'package:pater/domain/entities/user_role.dart' as domain_roles;

/// Адаптер для работы с пользователями из разных источников
/// Обеспечивает единый интерфейс для доступа к свойствам пользователя
class UserAdapter {
  final firebase.User? _firebaseUser;
  final domain.User? _domainUser;

  /// Создает адаптер на основе Firebase пользователя
  UserAdapter.fromFirebaseUser(this._firebaseUser) : _domainUser = null;

  /// Создает адаптер на основе доменного пользователя
  UserAdapter.fromDomainUser(this._domainUser) : _firebaseUser = null;

  /// Создает пустой адаптер (нет пользователя)
  UserAdapter.empty() : _firebaseUser = null, _domainUser = null;

  /// Проверяет, есть ли пользователь
  bool get hasUser => _firebaseUser != null || _domainUser != null;

  /// Возвращает идентификатор пользователя
  String? get id => _firebaseUser?.uid ?? _domainUser?.id;

  /// Возвращает email пользователя
  String? get email => _firebaseUser?.email ?? _domainUser?.email;

  /// Возвращает номер телефона пользователя
  String? get phoneNumber =>
      _firebaseUser?.phoneNumber ?? _domainUser?.phoneNumber;

  /// Возвращает имя пользователя
  String? get displayName {
    if (_firebaseUser != null) {
      return _firebaseUser.displayName;
    }
    if (_domainUser != null) {
      return '${_domainUser.firstName} ${_domainUser.lastName}'.trim();
    }
    return null;
  }

  /// Возвращает имя пользователя
  String? get firstName =>
      _domainUser?.firstName ?? _firebaseUser?.displayName?.split(' ').first;

  /// Возвращает фамилию пользователя
  String? get lastName =>
      _domainUser?.lastName ?? _firebaseUser?.displayName?.split(' ').last;

  /// Возвращает URL аватара пользователя
  String? get avatarUrl => _firebaseUser?.photoURL ?? _domainUser?.avatarUrl;

  /// Возвращает роль пользователя
  domain_roles.UserRole? get role =>
      _domainUser?.role != null
          ? domain_roles.UserRole.values.firstWhere(
            (r) =>
                r.toString().split('.').last ==
                _domainUser!.role.toString().split('.').last,
            orElse: () => domain_roles.UserRole.client,
          )
          : null;

  /// Преобразует Firebase пользователя в доменного пользователя
  domain.User toDomainUser(domain_roles.UserRole roleFromAuth) {
    if (_domainUser != null) {
      return _domainUser;
    }

    if (_firebaseUser != null) {
      final names =
          _firebaseUser.displayName?.split(' ') ?? ['Пользователь', ''];

      return domain.User(
        id: _firebaseUser.uid,
        email: _firebaseUser.email ?? '',
        firstName: names.first,
        lastName: names.length > 1 ? names.last : '',
        phoneNumber: _firebaseUser.phoneNumber ?? '',
        role: roleFromAuth,
        avatarUrl: _firebaseUser.photoURL,
        emailVerified: _firebaseUser.emailVerified,
        isAnonymous: _firebaseUser.isAnonymous,
        metadata: domain.UserMetadata(
          creationTime: _firebaseUser.metadata.creationTime,
          lastSignInTime: _firebaseUser.metadata.lastSignInTime,
        ),
        providerData:
            _firebaseUser.providerData
                .map(
                  (data) => domain.UserInfo(
                    uid: data.uid,
                    email: data.email,
                    displayName: data.displayName,
                    phoneNumber: data.phoneNumber,
                    photoURL: data.photoURL,
                    providerId: data.providerId,
                  ),
                )
                .toList(),
        roles: [roleFromAuth],
        activeRole: roleFromAuth,
      );
    }

    // Создаем пустого пользователя, если нет данных
    return domain.User(
      id: '',
      email: '',
      firstName: 'Гость',
      lastName: '',
      phoneNumber: '',
      role: domain_roles.UserRole.client,
      emailVerified: false,
      isAnonymous: true,
      metadata: domain.UserMetadata(),
      providerData: [],
      roles: [domain_roles.UserRole.client],
      activeRole: domain_roles.UserRole.client,
    );
  }

  /// Конвертировать роль из enum UserRole в домениый enum
  domain_roles.UserRole convertToDomainRole(domain_roles.UserRole role) {
    switch (role) {
      case domain_roles.UserRole.owner:
        return domain_roles.UserRole.owner;
      case domain_roles.UserRole.cleaner:
        return domain_roles.UserRole.cleaner;
      case domain_roles.UserRole.admin:
        return domain_roles.UserRole.support;
      case domain_roles.UserRole.support:
        return domain_roles.UserRole.support;
      case domain_roles.UserRole.client:
        return domain_roles.UserRole.client;
    }
  }

  /// Преобразует доменного пользователя в карту для Firestore
  Map<String, dynamic> toFirestoreMap() {
    if (_domainUser != null) {
      return _domainUser.toMap();
    }

    if (_firebaseUser != null) {
      final names =
          _firebaseUser.displayName?.split(' ') ?? ['Пользователь', ''];

      return {
        'id': _firebaseUser.uid,
        'email': _firebaseUser.email ?? '',
        'first_name': names.first,
        'last_name': names.length > 1 ? names.last : '',
        'phone_number': _firebaseUser.phoneNumber ?? '',
        'avatar_url': _firebaseUser.photoURL,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
    }

    return {};
  }

  static domain.User? fromFirebase(firebase.User? firebaseUser) {
    if (firebaseUser == null) return null;

    // Разделяем displayName на имя и фамилию
    final names = firebaseUser.displayName?.split(' ') ?? ['Пользователь', ''];
    final firstName = names.first;
    final lastName = names.length > 1 ? names.last : '';

    return domain.User(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      phoneNumber: firebaseUser.phoneNumber ?? '',
      firstName: firstName,
      lastName: lastName,
      avatarUrl: firebaseUser.photoURL,
      emailVerified: firebaseUser.emailVerified,
      isAnonymous: firebaseUser.isAnonymous,
      metadata: domain.UserMetadata(
        creationTime: firebaseUser.metadata.creationTime,
        lastSignInTime: firebaseUser.metadata.lastSignInTime,
      ),
      providerData:
          firebaseUser.providerData
              .map(
                (data) => domain.UserInfo(
                  uid: data.uid,
                  email: data.email,
                  displayName: data.displayName,
                  phoneNumber: data.phoneNumber,
                  photoURL: data.photoURL,
                  providerId: data.providerId,
                ),
              )
              .toList(),
      role: domain_roles.UserRole.client,
      roles: [domain_roles.UserRole.client],
      activeRole: domain_roles.UserRole.client,
    );
  }

  static Map<String, dynamic> toFirestoreData(domain.User user) {
    return {
      'id': user.id,
      'email': user.email,
      'phone_number': user.phoneNumber,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'avatar_url': user.avatarUrl,
      'email_verified': user.emailVerified,
      'is_anonymous': user.isAnonymous,
      'metadata': {
        'creation_time': user.metadata.creationTime?.toIso8601String(),
        'last_sign_in_time': user.metadata.lastSignInTime?.toIso8601String(),
      },
      'provider_data':
          user.providerData
              .map(
                (data) => {
                  'uid': data.uid,
                  'email': data.email,
                  'display_name': data.displayName,
                  'phone_number': data.phoneNumber,
                  'photo_url': data.photoURL,
                  'provider_id': data.providerId,
                },
              )
              .toList(),
      'role': user.role.toString().split('.').last,
      'roles':
          user.roles.map((role) => role.toString().split('.').last).toList(),
      'active_role': user.activeRole.toString().split('.').last,
    };
  }
}
