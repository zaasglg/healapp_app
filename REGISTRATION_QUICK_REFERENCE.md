# Быстрая справка: Регистрация и роли

## TL;DR

**Ключевое поле для передачи роли:** `accountType` в событии `AuthRegisterRequested`

## Маппинг ролей

| UI Enum | API Value | Описание |
|---------|-----------|----------|
| `Role.nursingHome` | `"pansionat"` | Пансионат |
| `Role.agency` | `"agency"` | Патронажное агентство |
| `Role.privateCaregiver` | `"specialist"` | Частная сиделка |

## Как передать роль

### 1. В UI (RegisterPage)

```dart
// Преобразование enum в строку для API
String _getAccountType(Role role) {
  switch (role) {
    case Role.nursingHome: return 'pansionat';
    case Role.agency: return 'agency';
    case Role.privateCaregiver: return 'specialist';
  }
}

// Отправка события
context.read<AuthBloc>().add(
  AuthRegisterRequested(
    phone: phone,
    password: password,
    passwordConfirmation: passwordConfirmation,
    accountType: _getAccountType(_selectedRole!), // ← ЗДЕСЬ
    firstName: '',
    lastName: '',
  ),
);
```

### 2. В Event (AuthRegisterRequested)

```dart
class AuthRegisterRequested extends AuthEvent {
  final String accountType; // ← ОБЯЗАТЕЛЬНОЕ ПОЛЕ
  
  const AuthRegisterRequested({
    required this.phone,
    required this.password,
    required this.passwordConfirmation,
    required this.accountType, // ← ОБЯЗАТЕЛЬНО
    required this.firstName,
    required this.lastName,
    this.organizationName,
    this.referralCode,
  });
}
```

### 3. В BLoC (AuthBloc)

```dart
Future<void> _onRegisterRequested(
  AuthRegisterRequested event,
  Emitter<AuthState> emit,
) async {
  final data = <String, dynamic>{
    'phone': event.phone,
    'password': event.password,
    'password_confirmation': event.passwordConfirmation,
    'account_type': event.accountType, // ← Передача в API
  };
  
  await _authRepository.register(data);
}
```

### 4. API Request

```json
POST /auth/register

{
  "phone": "77001234567",
  "password": "password123",
  "password_confirmation": "password123",
  "account_type": "pansionat"
}
```

## Процесс регистрации (кратко)

```
1. Выбор роли (Step 0)
   ↓
2. Заполнение формы (Step 1)
   ↓
3. Dispatch AuthRegisterRequested с accountType
   ↓
4. POST /auth/register
   ↓
5. Состояние AuthAwaitingSmsVerification
   ↓
6. Навигация на /verify-code/{phone}
   ↓
7. Подтверждение SMS
   ↓
8. Состояние AuthAuthenticated
   ↓
9. Навигация на /home
```

## Состояния BLoC

| Состояние | Когда | Действие в UI |
|-----------|-------|---------------|
| `AuthInitial` | Начальное | - |
| `AuthLoading` | Отправка запроса | Показать индикатор |
| `AuthAwaitingSmsVerification` | SMS отправлен | Перейти на /verify-code |
| `AuthAuthenticated` | Успешная авторизация | Перейти на /home |
| `AuthFailure` | Ошибка | Показать toast |

## Обязательные поля для регистрации

✅ **Обязательно:**
- `phone` - номер телефона (без маски)
- `password` - пароль
- `password_confirmation` - подтверждение пароля
- `account_type` - **ТИП АККАУНТА (РОЛЬ)**

❌ **Опционально:**
- `first_name` - имя
- `last_name` - фамилия
- `organization_name` - название организации
- `referral_code` - реферальный код

## Типичные ошибки

### ❌ НЕ ДЕЛАЙТЕ ТАК:

```dart
// Забыли передать accountType
AuthRegisterRequested(
  phone: phone,
  password: password,
  // accountType отсутствует! ← ОШИБКА
);

// Передали enum вместо строки
AuthRegisterRequested(
  accountType: Role.nursingHome.toString(), // ← НЕПРАВИЛЬНО
);
```

### ✅ ПРАВИЛЬНО:

```dart
AuthRegisterRequested(
  phone: phone,
  password: password,
  accountType: _getAccountType(_selectedRole!), // ← ПРАВИЛЬНО
);
```

## Валидация телефона

```dart
// Маска для ввода
final _phoneMask = MaskTextInputFormatter(
  mask: '+7 (###) ###-##-##',
  filter: {"#": RegExp(r'\d')},
);

// Получение номера без маски
final phone = _phoneMask.getUnmaskedText(); // "77001234567"
```

## Обработка ошибок

```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthFailure) {
      // Показать toast с ошибкой
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Ошибка'),
        description: Text(state.message),
      );
    }
    
    if (state is AuthAwaitingSmsVerification) {
      // Перейти на подтверждение SMS
      context.push('/verify-code/${state.phone}');
    }
    
    if (state is AuthAuthenticated) {
      // Перейти на главную
      context.go('/home');
    }
  },
  child: /* ... */,
)
```

## Проверка после регистрации

После успешной регистрации и авторизации:

```dart
// Получить пользователя
final user = context.read<AuthBloc>().state;

if (user is AuthAuthenticated) {
  print(user.user.accountType); // "pansionat", "agency" или "specialist"
  print(user.user.roles);       // ["owner"] или ["specialist"]
}
```

## Навигация

```dart
// После регистрации
'/register' 
  → '/verify-code/{phone}'  // Подтверждение SMS
  → '/home'                 // Главная страница

// Кнопка "Назад" на Step 1
setState(() {
  _step = 0;
  _selectedRole = null;
});
```

## Полезные ссылки

- **Полная документация:** `REGISTRATION_FLOW.md`
- **Диаграммы:** `REGISTRATION_DIAGRAM.md`
- **Код страницы:** `lib/screens/auth/register_page.dart`
- **BLoC:** `lib/bloc/auth/auth_bloc.dart`
- **Event:** `lib/bloc/auth/auth_event.dart`
- **Repository:** `lib/repositories/auth_repository.dart`

## Команды для тестирования

```bash
# Запуск приложения
flutter run

# Анализ кода
flutter analyze

# Форматирование
dart format .

# Тесты
flutter test
```

---

**Помните:** `accountType` - это критически важное поле, которое определяет тип аккаунта и доступный функционал!