# Auth BLoC Documentation

## Обзор

BLoC для управления авторизацией пользователей в приложении HealApp.

## Структура

- `auth_event.dart` - События авторизации
- `auth_state.dart` - Состояния авторизации
- `auth_bloc.dart` - Логика обработки событий

## События (Events)

### AuthLoginRequested
Запрос на вход в систему.

```dart
AuthBloc().add(AuthLoginRequested(
  phone: '+79991234567',
  password: 'password123',
));
```

### AuthLogoutRequested
Запрос на выход из системы.

```dart
AuthBloc().add(const AuthLogoutRequested());
```

### AuthCheckStatus
Проверка статуса авторизации (проверяет наличие токена).

```dart
AuthBloc().add(const AuthCheckStatus());
```

## Состояния (States)

### AuthInitial
Начальное состояние (при первом запуске).

### AuthLoading
Состояние загрузки (выполняется запрос к API).

### AuthAuthenticated
Успешная авторизация. Содержит данные пользователя.

```dart
if (state is AuthAuthenticated) {
  final user = state.user;
  // Использовать данные пользователя
}
```

### AuthUnauthenticated
Пользователь не авторизован (нет токена или токен недействителен).

### AuthFailure
Ошибка авторизации. Содержит сообщение об ошибке.

```dart
if (state is AuthFailure) {
  final errorMessage = state.message;
  // Показать ошибку пользователю
}
```

## Использование

### В виджете

```dart
BlocProvider(
  create: (context) => AuthBloc(),
  child: YourWidget(),
)
```

### Прослушивание состояний

```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthAuthenticated) {
      // Навигация на главную страницу
      context.go('/home');
    }
    if (state is AuthFailure) {
      // Показать ошибку
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  },
  child: YourWidget(),
)
```

### Отображение состояния загрузки

```dart
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthLoading) {
      return CircularProgressIndicator();
    }
    return YourContent();
  },
)
```

### Отправка событий

```dart
context.read<AuthBloc>().add(
  AuthLoginRequested(
    phone: phone,
    password: password,
  ),
);
```

## Интеграция с API

BLoC использует `AuthRepository` для взаимодействия с API:

- **Endpoint:** `POST /api/v1/auth/login`
- **Body:** `{ "phone": "...", "password": "..." }`
- **Response:** `{ "token": "...", "user": { ... } }`

Токен автоматически сохраняется в `FlutterSecureStorage` при успешной авторизации.

## Обработка ошибок

BLoC обрабатывает следующие типы ошибок:

- `ValidationException` - Ошибки валидации (422)
- `UnauthorizedException` - Неверные учетные данные (401)
- `NetworkException` - Ошибки сети
- `ServerException` - Ошибки сервера (500+)
- `ApiException` - Другие ошибки API

Все ошибки преобразуются в `AuthFailure` с понятным сообщением для пользователя.

