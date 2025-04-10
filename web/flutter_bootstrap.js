/**
 * Скрипт-загрузчик для Flutter Web
 */
(function() {
  // Проверяем, что Flutter уже доступен
  if (typeof window._flutter === 'undefined') {
    console.error('Flutter не инициализирован. Загрузка отменена.');
    return;
  }
  
  // Настраиваем параметры и продолжаем загрузку
  try {
    console.log('Инициализация Flutter bootstrap');
    
    // Настраиваем опции Flutter
    window._flutter = window._flutter || {};
    
    // Настраиваем serviceWorker если он не был настроен
    var serviceWorkerVersion = window.serviceWorkerVersion;
    var serviceWorkerOptions = {serviceWorkerVersion: serviceWorkerVersion};
    
    // Гарантируем, что Flutter может загрузиться
    if (typeof window._flutter.loader === 'undefined') {
      console.warn('Flutter loader не найден, попытка инициализации через Flutter.js');
      
      // Попытка найти глобальный Flutter объект
      if (typeof Flutter !== 'undefined') {
        window._flutter.loader = Flutter.loader;
      } else {
        console.error('Flutter не доступен. Приложение не может быть загружено.');
        return;
      }
    }
    
    console.log('Flutter bootstrap загружен успешно');
  } catch (e) {
    console.error('Ошибка в bootstrap скрипте:', e);
  }
})(); 