# Network Layer Documentation

## Обзор

Сетевой слой для подключения Flutter приложения к Laravel Backend.

## Использование

### Базовое использование

```dart
import 'package:healapp_mobile/core/network/api_client.dart';

// Использование глобального экземпляра
final response = await apiClient.get('/users');

// Или создание нового экземпляра
final client = ApiClient();
final response = await client.get('/users');
```

### Работа с токенами

```dart
// Сохранение токена после авторизации
await apiClient.saveToken('your-auth-token');

// Получение токена
final token = await apiClient.getToken();

// Удаление токена при выходе
await apiClient.deleteToken();
```

### Обработка ошибок

```dart
import 'package:healapp_mobile/core/network/api_exceptions.dart';

try {
  final response = await apiClient.post('/login', data: {
    'email': 'user@example.com',
    'password': 'password',
  });
} on ValidationException catch (e) {
  // Ошибки валидации Laravel
  final emailError = e.getFirstError('email');
  final allErrors = e.getAllErrors();
} on UnauthorizedException catch (e) {
  // 401 - неавторизован
  print('Unauthorized: ${e.message}');
} on NetworkException catch (e) {
  // Ошибки сети
  print('Network error: ${e.message}');
} on ServerException catch (e) {
  // Ошибки сервера (500+)
  print('Server error: ${e.message}');
} on ApiException catch (e) {
  // Любая другая ошибка API
  print('API error: ${e.message}');
}
```

### Настройка callback для 401 ошибок

```dart
// В main.dart или в месте инициализации приложения
apiClient.setOnUnauthorizedCallback(() {
  // Выполнить выход из системы
  // Например, очистить данные и перейти на экран входа
  apiClient.deleteToken();
  // context.go('/login');
});
```

### Примеры запросов

#### GET запрос
```dart
final response = await apiClient.get('/users', queryParameters: {
  'page': 1,
  'per_page': 10,
});
```

#### POST запрос
```dart
final response = await apiClient.post('/login', data: {
  'email': 'user@example.com',
  'password': 'password',
});
```

#### PUT запрос
```dart
final response = await apiClient.put('/users/1', data: {
  'name': 'John Doe',
  'email': 'john@example.com',
});
```

#### PATCH запрос
```dart
final response = await apiClient.patch('/users/1', data: {
  'name': 'Jane Doe',
});
```

#### DELETE запрос
```dart
final response = await apiClient.delete('/users/1');
```

## Конфигурация

Настройки API находятся в `ApiConfig`. Базовый URL автоматически определяется в зависимости от платформы:

- **Android Emulator**: `http://10.0.2.2:8000/api/v1`
- **iOS Simulator**: `http://127.0.0.1:8000/api/v1`
- **Web**: `http://localhost:8000/api/v1`
- **Windows/Linux/macOS**: `http://127.0.0.1:8000/api/v1`

### Настройка для реального устройства

Если вы тестируете на **реальном устройстве** (не эмулятор/симулятор), нужно указать IP адрес вашего компьютера:

1. Узнайте IP адрес вашего компьютера:
   - **Windows**: Откройте командную строку и выполните `ipconfig`. Найдите `IPv4 Address` (например, `192.168.1.100`)
   - **Linux/Mac**: Выполните `ifconfig` или `ip addr` и найдите IP адрес (обычно начинается с `192.168.`)

2. Откройте `lib/core/network/api_client.dart` и установите `customIp`:
   ```dart
   static const String? customIp = '192.168.1.100'; // Ваш IP адрес
   ```

3. Убедитесь, что ваш сервер Laravel принимает подключения с этого IP:
   ```bash
   php artisan serve --host=0.0.0.0 --port=8000
   ```

4. Убедитесь, что устройство и компьютер находятся в одной Wi-Fi сети.

### Проверка подключения

Если возникают проблемы с подключением:
1. Проверьте, что сервер запущен и доступен
2. Проверьте, что устройство/эмулятор и компьютер в одной сети
3. Проверьте файрвол - он может блокировать подключения
4. Для Android реального устройства убедитесь, что указан правильный IP адрес

## Особенности

1. **Автоматическое добавление токена**: Interceptor автоматически добавляет токен из `FlutterSecureStorage` в заголовок `Authorization: Bearer <token>`.

2. **Обработка 401**: При получении 401 ошибки автоматически вызывается callback для выхода из системы.

3. **Обработка ошибок валидации Laravel**: Специальный класс `ValidationException` для удобной работы с ошибками валидации Laravel (422).

4. **Безопасное хранение токенов**: Используется `FlutterSecureStorage` для безопасного хранения токенов авторизации.

