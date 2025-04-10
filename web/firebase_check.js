/**
 * Утилиты для проверки состояния Firebase в веб-приложении
 */

// Проверяет, доступен ли Firebase в текущей среде
window.isFirebaseAvailable = function() {
  if (typeof firebase === 'undefined') {
    console.warn('Firebase не найден в глобальном контексте');
    return false;
  }
  
  try {
    // Проверка, что Firebase инициализирован
    if (!firebase.app || typeof firebase.app !== 'function') {
      console.warn('Firebase не инициализирован корректно');
      return false;
    }
    
    const app = firebase.app();
    const options = app.options || {};
    
    console.log('Firebase инициализирован с опциями:', {
      projectId: options.projectId,
      appId: options.appId,
      apiKey: options.apiKey ? 'Установлен' : 'Не установлен'
    });
    
    return true;
  } catch (e) {
    console.error('Ошибка при проверке Firebase:', e);
    return false;
  }
};

// Исправляет проблемы с CORS и сетевым соединением
window.fixCorsIssues = function() {
  console.log('Запуск функции исправления CORS и сетевого соединения');
  
  if (typeof firebase === 'undefined') {
    console.error('Firebase не определен, невозможно исправить соединение');
    return false;
  }
  
  try {
    // Сбрасываем кэш сервис-воркера, если он есть
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(registrations => {
        for (const registration of registrations) {
          registration.update();
        }
      });
    }
    
    // Удаляем куки и данные локального хранилища, связанные с Firebase
    if (firebase.auth && firebase.auth().signOut) {
      firebase.auth().signOut().catch(e => console.warn('Ошибка при выходе из Firebase:', e));
    }
    
    // Очистка проблемных данных в localStorage
    const keysToRemove = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && (key.includes('firebase') || key.includes('firestore'))) {
        keysToRemove.push(key);
      }
    }
    
    keysToRemove.forEach(key => {
      console.log('Удаление ключа localStorage:', key);
      localStorage.removeItem(key);
    });
    
    // Перенастройка сети Firestore
    if (firebase.firestore) {
      try {
        firebase.firestore().disableNetwork()
          .then(() => {
            console.log('Сеть Firestore отключена');
            return firebase.firestore().enableNetwork();
          })
          .then(() => {
            console.log('Сеть Firestore переподключена');
          })
          .catch(error => {
            console.error('Ошибка при перенастройке сети Firestore:', error);
          });
      } catch (e) {
        console.warn('Не удалось управлять сетью Firestore:', e);
      }
      
      // НЕ пытаемся изменить настройки, если Firestore уже запущен
      // Это избегает ошибки "Firestore has already been started and its settings can no longer be changed"
    }
    
    // Перезапускаем все WebChannel соединения
    if (firebase.INTERNAL && firebase.INTERNAL.resetConnections) {
      firebase.INTERNAL.resetConnections();
      console.log('Соединения Firebase сброшены');
    }
    
    return true;
  } catch (e) {
    console.error('Ошибка при исправлении соединения:', e);
    return false;
  }
};

// Получает текущий статус Firebase
window.getFirebaseStatus = function() {
  if (typeof firebase === 'undefined') {
    return {
      available: false,
      initialized: false,
      message: 'Firebase не найден'
    };
  }
  
  try {
    const status = {
      available: true,
      initialized: false,
      firestore: {
        available: false,
        online: false
      },
      auth: {
        available: false,
        loggedIn: false
      },
      messaging: {
        available: false
      },
      storage: {
        available: false
      },
      message: ''
    };
    
    // Проверка инициализации
    if (firebase.app && typeof firebase.app === 'function') {
      try {
        const app = firebase.app();
        status.initialized = !!app;
        
        if (app && app.options) {
          status.projectId = app.options.projectId;
          status.appId = app.options.appId;
        }
      } catch (e) {
        status.message = 'Ошибка при получении app: ' + e.message;
      }
    }
    
    // Проверка Firestore
    if (firebase.firestore) {
      status.firestore.available = true;
      
      try {
        const firestoreSettings = firebase.firestore().settings || {};
        status.firestore.settings = firestoreSettings;
        
        // В Firebase Web SDK нет прямого способа проверить статус соединения Firestore
        // Можно сделать тестовый запрос, но это не всегда надежно
      } catch (e) {
        status.firestore.error = e.message;
      }
    }
    
    // Проверка Auth
    if (firebase.auth) {
      status.auth.available = true;
      status.auth.loggedIn = !!firebase.auth().currentUser;
      status.auth.currentUser = status.auth.loggedIn 
        ? { uid: firebase.auth().currentUser.uid } 
        : null;
    }
    
    // Проверка Storage
    if (firebase.storage) {
      status.storage.available = true;
    }
    
    // Проверка Messaging
    if (firebase.messaging) {
      status.messaging.available = true;
      
      try {
        status.messaging.permission = Notification.permission;
      } catch (e) {
        status.messaging.error = e.message;
      }
    }
    
    return status;
  } catch (e) {
    return {
      available: false,
      initialized: false,
      error: e.message,
      message: 'Ошибка при получении статуса: ' + e.message
    };
  }
};

// Устанавливает настройки Firestore при инициализации
window.initializeFirestoreSettings = function() {
  if (typeof firebase === 'undefined' || !firebase.firestore) {
    console.warn('Firestore не доступен для инициализации настроек');
    return false;
  }
  
  try {
    // Применяем настройки только при инициализации, до любого использования Firestore
    firebase.firestore().settings({
      experimentalForceLongPolling: true,
      cacheSizeBytes: firebase.firestore.CACHE_SIZE_UNLIMITED,
      ignoreUndefinedProperties: true,
      // Используем merge: true, чтобы не перезаписывать существующие настройки
      merge: true
    });
    console.log('Настройки Firestore инициализированы успешно');
    return true;
  } catch (e) {
    console.error('Ошибка при инициализации настроек Firestore:', e);
    return false;
  }
};

// Добавляем обработчик исключений для Firebase
window.handleFirebaseException = function(exception) {
  try {
    // Безопасная обработка строкового представления исключения
    let errorMessage = exception;
    
    // Проверяем тип входных данных
    if (typeof exception !== 'string') {
      try {
        errorMessage = JSON.stringify(exception);
      } catch (e) {
        errorMessage = String(exception);
      }
    }
    
    console.error('Firebase ошибка:', errorMessage);
    
    // Возвращаем объект с ошибкой для дальнейшей обработки
    return {
      error: true,
      message: errorMessage
    };
  } catch (e) {
    console.error('Ошибка при обработке исключения Firebase:', e);
    return {
      error: true,
      message: 'Ошибка при обработке исключения'
    };
  }
};

// Скрипт для проверки доступности Firebase и исправления проблем
(function() {
  console.log('Firebase диагностика запущена');
  
  // Проверка и настройка Firebase
  function checkFirebaseHealth() {
    try {
      // Проверяем доступность Firebase и устанавливаем настройки, если он доступен
      if (isFirebaseAvailable()) {
        // Инициализируем настройки Firestore перед использованием
        initializeFirestoreSettings();
        console.log('Firebase настроен');
        return true;
      } else {
        console.warn('Firebase недоступен, попытка исправления...');
        return false;
      }
    } catch (e) {
      console.error('Ошибка при проверке Firebase:', e);
      return false;
    }
  }
  
  // Функция для проверки доступности Firebase
  function checkFirebase() {
    try {
      if (typeof firebase === 'undefined' || !firebase.app) {
        console.error('Firebase не доступен');
        return false;
      }
      
      // Проверяем основные сервисы
      const services = [
        { name: 'firestore', obj: firebase.firestore },
        { name: 'auth', obj: firebase.auth },
        { name: 'storage', obj: firebase.storage },
        { name: 'messaging', obj: firebase.messaging },
        { name: 'analytics', obj: firebase.analytics }
      ];
      
      let available = true;
      services.forEach(service => {
        if (typeof service.obj === 'undefined') {
          console.warn(`Firebase ${service.name} не доступен`);
          available = false;
        }
      });
      
      if (available) {
        console.log('Все сервисы Firebase доступны');
      }
      
      return available;
    } catch (e) {
      console.error('Ошибка при проверке Firebase:', e);
      return false;
    }
  }
  
  // Функция для перехвата и обработки ошибок Firebase
  function setupFirebaseErrorHandling() {
    try {
      // Общий обработчик ошибок
      window.onerror = function(message, source, lineno, colno, error) {
        if (message && (
          message.toString().includes('Firebase') || 
          message.toString().includes('firestore') ||
          message.toString().includes('WebChannel')
        )) {
          console.warn('Перехвачена ошибка Firebase:', message);
          
          // В случае ошибки "Firestore has already been started" НЕ вызываем fixCorsIssues
          if (message.toString().includes('Firestore has already been started')) {
            console.warn('Невозможно изменить настройки после запуска Firestore');
            return true;
          }
          
          // Вызываем корректор соединения только для других ошибок
          if (window.fixCorsIssues) {
            window.fixCorsIssues();
          }
          
          // Предотвращаем показ ошибки в консоли браузера
          return true;
        }
        
        // Для других ошибок продолжаем стандартную обработку
        return false;
      };
      
      // Обработчик исключений FirebaseException
      window.handleFirebaseException = function(exception) {
        // Проверяем, что exception - это строка или объект
        let errMessage = '';
        let errCode = 'unknown';
        
        if (typeof exception === 'string') {
          errMessage = exception;
        } else if (exception && typeof exception === 'object' && exception.message) {
          errMessage = exception.message;
          errCode = exception.code || 'unknown';
        } else {
          errMessage = String(exception);
        }
        
        console.error('Firebase ошибка:', errCode, errMessage);
        
        // Не вызываем fixCorsIssues для ошибок настроек Firestore
        if (!errMessage.includes('Firestore has already been started')) {
          // Отключаем автоматический вызов fixCorsIssues, чтобы избежать цикла
          // При необходимости пользователь может вызвать эту функцию вручную
        }
        
        // Возвращаем простой объект JavaScript вместо исключения
        return {
          error: true,
          code: errCode,
          message: errMessage
        };
      };
      
      console.log('Обработка ошибок Firebase настроена');
    } catch (e) {
      console.error('Ошибка при настройке обработки ошибок Firebase:', e);
    }
  }
  
  // Запускаем настройку после полной загрузки страницы
  window.addEventListener('load', function() {
    setTimeout(function() {
      checkFirebaseHealth();
      setupFirebaseErrorHandling();
    }, 1000); // Даем Firebase время на инициализацию
  });
})(); 