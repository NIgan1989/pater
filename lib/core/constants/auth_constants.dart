/// Константы для аутентификации
class AuthConstants {
  /// Максимальное количество попыток ввода PIN-кода
  static const int maxPinAttempts = 3;
  
  /// Время блокировки после превышения попыток (в минутах)
  static const int pinLockoutDuration = 30;
  
  /// Минимальная длина пароля
  static const int minPasswordLength = 6;
  
  /// Максимальная длина PIN-кода
  static const int maxPinLength = 6;
  
  /// Минимальная длина PIN-кода
  static const int minPinLength = 4;
  
  /// Ключи для SharedPreferences
  static const String currentUserKey = 'current_user';
  static const String lastUserIdKey = 'last_user_id';
  static const String pinAttemptsKey = 'pin_auth_attempts';
  static const String pinLockoutTimeKey = 'pin_lockout_time';
  static const String skipPinAuthKey = 'skip_pin_auth';
  static const String userDisplayNameKey = 'user_display_name';
  static const String userAvatarUrlKey = 'user_avatar_url';
  static const String userPhoneNumberKey = 'user_phone_number';
  
  /// Префиксы для ключей
  static const String pinCodePrefix = 'user_pin_';
  static const String phoneNumberPrefix = 'user_phone_number_';
  
  /// Сообщения об ошибках
  static const String invalidEmailError = 'Введите корректный email';
  static const String emptyEmailError = 'Введите email';
  static const String emptyPasswordError = 'Введите пароль';
  static const String shortPasswordError = 'Пароль должен содержать минимум $minPasswordLength символов';
  static const String emptyPhoneError = 'Введите номер телефона';
  static const String shortPhoneError = 'Номер телефона слишком короткий';
  static const String emptyPinError = 'Введите PIN-код';
  static const String invalidPinError = 'PIN-код должен содержать от $minPinLength до $maxPinLength цифр';
  static const String pinOnlyDigitsError = 'PIN-код должен состоять только из цифр';
  static const String passwordsNotMatchError = 'Пароли не совпадают';
  static const String userNotFoundError = 'Пользователь не найден';
  static const String wrongPasswordError = 'Неверный пароль';
  static const String tooManyAttemptsError = 'Слишком много попыток. Попробуйте позже';
  static const String networkError = 'Ошибка сети. Проверьте подключение';
  static const String unknownError = 'Произошла неизвестная ошибка';
  
  /// Сообщения об успехе
  static const String resetPasswordSuccess = 'Инструкции по сбросу пароля отправлены на ваш email';
  static const String passwordUpdateSuccess = 'Пароль успешно обновлен';
  static const String pinSetupSuccess = 'PIN-код успешно установлен';
  static const String signOutSuccess = 'Вы успешно вышли из системы';
  
  /// Заголовки
  static const String signInTitle = 'Вход';
  static const String signUpTitle = 'Регистрация';
  static const String resetPasswordTitle = 'Сброс пароля';
  static const String pinAuthTitle = 'Вход по PIN-коду';
  static const String setPinTitle = 'Установка PIN-кода';
  
  /// Кнопки
  static const String signInButton = 'Войти';
  static const String signUpButton = 'Зарегистрироваться';
  static const String resetPasswordButton = 'Сбросить пароль';
  static const String confirmButton = 'Подтвердить';
  static const String cancelButton = 'Отмена';
  static const String continueButton = 'Продолжить';
  static const String skipButton = 'Пропустить';
  
  /// Подсказки
  static const String emailHint = 'Введите ваш email';
  static const String passwordHint = 'Введите пароль';
  static const String confirmPasswordHint = 'Подтвердите пароль';
  static const String phoneHint = 'Введите номер телефона';
  static const String pinHint = 'Введите PIN-код';
  static const String firstNameHint = 'Введите имя';
  static const String lastNameHint = 'Введите фамилию';
} 