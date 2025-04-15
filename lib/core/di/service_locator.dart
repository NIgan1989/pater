import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pater/core/auth/role_manager.dart';
import 'package:pater/core/auth/auth_service.dart';
import 'package:pater/core/auth/account_manager.dart';
import 'package:pater/data/services/user_service.dart';
import 'package:pater/data/repositories/user_repository_impl.dart';
import 'package:pater/domain/repositories/user_repository.dart';
import 'package:pater/data/services/booking_service.dart';
import 'package:pater/data/services/cleaning_service.dart';
import 'package:pater/data/services/property_service.dart';
import 'package:pater/data/services/payment_service.dart';
import 'package:pater/data/services/notification_service.dart';
import 'package:pater/data/services/geocoding_service.dart';
import 'package:pater/data/services/cloudinary_service.dart';
import 'package:pater/data/services/messaging_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External services
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Firebase
  getIt.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  getIt.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);

  // Core
  getIt.registerSingleton<RoleManager>(
    RoleManager(
      firestore: getIt<FirebaseFirestore>(),
      prefs: getIt<SharedPreferences>(),
    ),
  );

  // Account manager
  getIt.registerSingleton<AccountManager>(AccountManager());

  // Auth service
  getIt.registerSingleton<AuthService>(
    AuthService(
      auth: getIt<FirebaseAuth>(),
      firestore: getIt<FirebaseFirestore>(),
      roleManager: getIt<RoleManager>(),
      prefs: getIt<SharedPreferences>(),
      accountManager: getIt<AccountManager>(),
    ),
  );

  // Services
  getIt.registerSingleton<UserService>(UserService());
  getIt.registerSingleton<BookingService>(BookingService());
  getIt.registerSingleton<CleaningService>(CleaningService());
  getIt.registerSingleton<PropertyService>(
    PropertyService(
      firestore: getIt<FirebaseFirestore>(),
      authService: getIt<AuthService>(),
    ),
  );
  getIt.registerSingleton<PaymentService>(PaymentService());

  // Notification service
  getIt.registerSingleton<NotificationService>(
    NotificationService(
      firestore: getIt<FirebaseFirestore>(),
      prefs: getIt<SharedPreferences>(),
      roleManager: getIt<RoleManager>(),
    ),
  );

  getIt.registerSingleton<GeocodingService>(GeocodingService());
  getIt.registerSingleton<CloudinaryService>(CloudinaryService());
  getIt.registerSingleton<MessagingService>(MessagingService());

  // Timer service requires a Ref parameter, which we can't provide directly
  // We'll need to create this differently or use a different approach
  // For now, we'll leave it out

  // Repositories
  getIt.registerSingleton<UserRepository>(
    UserRepositoryImpl(getIt<UserService>()),
  );
}
