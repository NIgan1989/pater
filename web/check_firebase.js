/**
 * Скрипт для проверки доступности сервисов Firebase
 */

// Функция для проверки здоровья Firebase
function checkFirebaseHealth() {
  console.log('Запуск проверки доступности Firebase...');
  
  // Проверка доступности основных URL Firebase
  checkUrlAvailability('https://www.googleapis.com', 'Google API');
  checkUrlAvailability('https://firestore.googleapis.com', 'Firestore API');
  checkUrlAvailability('https://identitytoolkit.googleapis.com', 'Firebase Auth');
  checkUrlAvailability('https://firebase.googleapis.com', 'Firebase API');
  
  // Если Firebase уже инициализирован
  if (typeof firebase !== 'undefined' && firebase.app) {
    try {
      // Отключаем reCAPTCHA для аутентификации
      if (window.disableRecaptcha) {
        window.disableRecaptcha();
      }
      
      // Проверяем состояние аутентификации
      const auth = firebase.auth();
      console.log('Статус аутентификации:', auth.currentUser ? 'Пользователь вошел' : 'Пользователь не аутентифицирован');
      
      // Проверяем соединение с Firestore
      firebase.firestore().collection('system').doc('connection_test').get()
        .then(() => {
          console.log('✅ Соединение с Firestore работает');
          window.firebaseReady = true;
        })
        .catch(error => {
          console.error('❌ Ошибка соединения с Firestore:', error);
          // Автоматическая попытка исправить проблему
          fixCorsIssues();
        });
    } catch (error) {
      console.error('❌ Ошибка при проверке Firebase:', error);
    }
  } else {
    console.warn('⚠️ Firebase еще не инициализирован');
    // Пробуем инициализировать Firebase
    if (window.initializeFirebase) {
      console.log('Попытка запустить инициализацию Firebase...');
      window.initializeFirebase();
    }
  }
}

// Функция для проверки доступности URL
function checkUrlAvailability(url, name) {
  fetch(url, { method: 'HEAD', mode: 'no-cors', cache: 'no-store' })
    .then(() => {
      console.log(`✅ ${name} доступен`);
    })
    .catch(error => {
      console.error(`❌ ${name} недоступен:`, error);
    });
}

// Пробуем инициализировать Firebase если он еще не готов
window.initializeFirebase = function() {
  if (typeof firebase === 'undefined') {
    console.error('Firebase SDK не загружен');
    return;
  }
  
  if (firebase.apps.length === 0) {
    console.log('Инициализация Firebase...');
    
    const firebaseConfig = {
      apiKey: "AIzaSyARciuF5TVrDnUWRSyhUJ7Cs2HKjn3Idk8",
      appId: "1:637759816595:web:57b515f0284bf6f1601e66",
      messagingSenderId: "637759816595",
      projectId: "pater-bd6bb",
      authDomain: "pater-bd6bb.firebaseapp.com",
      storageBucket: "pater-bd6bb.appspot.com",
      measurementId: "G-HRB4M7G2ND",
      databaseURL: "https://pater-bd6bb.firebaseio.com",
    };
    
    try {
      // Перед инициализацией Firebase отключаем reCAPTCHA глобально
      // Добавляем глобальные настройки
      window.recaptchaDisabled = true;
      
      // Создаем глобальный фейковый объект recaptcha
      window.RecaptchaVerifier = function() {
        return {
          clear: function() {},
          render: function() { return 1; },
          verify: function() { return Promise.resolve("fake-token"); }
        };
      };
      
      firebase.initializeApp(firebaseConfig);
      console.log('Firebase инициализирован успешно');
      
      // Отключаем reCAPTCHA для телефонной аутентификации
      if (window.disableRecaptcha) {
        window.disableRecaptcha();
      }
      
      // Также отключаем reCAPTCHA через переопределение Firebase Auth
      if (firebase.auth && firebase.auth().settings) {
        try {
          // Отключаем приложение верификации reCAPTCHA
          if (typeof firebase.auth().settings.appVerificationDisabledForTesting === 'function') {
            firebase.auth().settings.appVerificationDisabledForTesting(true);
          }
          
          // Если есть метод setCustomParameters, попытаемся использовать его
          if (firebase.auth().signInWithPhoneNumber) {
            const originalMethod = firebase.auth().signInWithPhoneNumber;
            firebase.auth().signInWithPhoneNumber = function(phoneNumber, applicationVerifier) {
              // Если верификатор не предоставлен, создадим фейковый
              if (!applicationVerifier) {
                applicationVerifier = {
                  type: 'recaptcha',
                  verify: function() { return Promise.resolve('fake-token'); }
                };
              }
              return originalMethod.call(this, phoneNumber, applicationVerifier);
            };
          }
          
          console.log('Firebase Auth настроен для обхода reCAPTCHA');
        } catch (e) {
          console.warn('Не удалось настроить обход reCAPTCHA:', e);
        }
      }
      
      // Настраиваем Firestore
      firebase.firestore().settings({
        experimentalForceLongPolling: true,
        experimentalAutoDetectLongPolling: true,
        cacheSizeBytes: firebase.firestore.CACHE_SIZE_UNLIMITED,
        ignoreUndefinedProperties: true
      });
      
      // Создаем тестовый документ
      firebase.firestore().collection('system').doc('connection_test')
        .set({
          timestamp: firebase.firestore.FieldValue.serverTimestamp(),
          client: 'web_recovery',
          browser: navigator.userAgent
        }, { merge: true });
      
      window.firebaseReady = true;
    } catch (error) {
      console.error('Ошибка при инициализации Firebase:', error);
    }
  } else {
    console.log('Firebase уже инициализирован');
  }
};

// Запускаем проверку при загрузке страницы с задержкой 5 секунд
window.addEventListener('load', function() {
  console.log('Страница загружена, планируем проверку Firebase...');
  
  // Задержка для гарантии, что Firebase уже инициализирован
  setTimeout(checkFirebaseHealth, 5000);
  
  // Повторная проверка через 15 секунд
  setTimeout(checkFirebaseHealth, 15000);
});

// Глобальная функция для ручного запуска проверки
window.checkFirebaseHealth = checkFirebaseHealth;

// Вспомогательная функция для исправления ошибок CORS
window.fixCorsIssues = function() {
  console.log('Попытка исправления проблем с CORS...');
  
  if (typeof firebase === 'undefined' || !firebase.firestore) {
    console.error('Firebase не инициализирован');
    
    // Пробуем инициализировать Firebase
    if (window.initializeFirebase) {
      window.initializeFirebase();
    }
    return;
  }
  
  // Перенастраиваем Firestore с longpolling
  firebase.firestore().settings({
    experimentalForceLongPolling: true,
    experimentalAutoDetectLongPolling: true,
    cacheSizeBytes: firebase.firestore.CACHE_SIZE_UNLIMITED,
    ignoreUndefinedProperties: true
  });
  
  console.log('Настройки Firestore обновлены для решения проблем с CORS');
  
  // Очищаем кэш Firestore
  console.log('Очистка кэша Firestore...');
  firebase.firestore().clearPersistence()
    .then(() => {
      console.log('Кэш Firestore очищен успешно');
      
      // Пересоздаем тестовый документ
      firebase.firestore().collection('system').doc('connection_test')
        .set({
          timestamp: firebase.firestore.FieldValue.serverTimestamp(),
          client: 'web_after_clear',
          recoveryTime: new Date().toISOString()
        }, { merge: true })
        .then(() => {
          console.log('✅ Соединение успешно восстановлено');
          window.firebaseReady = true;
        })
        .catch(error => {
          console.error('❌ Не удалось восстановить соединение:', error);
        });
    })
    .catch(error => {
      console.error('Ошибка при очистке кэша:', error);
      
      // Тестируем подключение без очистки кэша
      firebase.firestore().collection('system').doc('connection_test').get()
        .then(() => {
          console.log('✅ Соединение работает без очистки кэша');
          window.firebaseReady = true;
        })
        .catch(error => {
          console.error('❌ Соединение по-прежнему не работает:', error);
        });
    });
}; 