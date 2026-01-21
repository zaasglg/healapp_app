# Документация: Процесс регистрации и передача ролей

## Обзор

Процесс регистрации в HealApp позволяет пользователям создавать аккаунты разных типов (пансионат, агентство, частная сиделка). Регистрация проходит в два этапа: выбор роли и заполнение данных, после чего требуется подтверждение по SMS.

## Архитектура

### Основные компоненты

1. **`RegisterPage`** (`lib/screens/auth/register_page.dart`) - UI страница регистрации
2. **`AuthBloc`** (`lib/bloc/auth/auth_bloc.dart`) - бизнес-логика авторизации
3. **`AuthEvent`** (`lib/bloc/auth/auth_event.dart`) - события авторизации
4. **`AuthState`** (`lib/bloc/auth/auth_state.dart`) - состояния авторизации
5. **`AuthRepository`** (`lib/repositories/auth_repository.dart`) - работа с API

## Типы ролей (account_type)

### Enum Role в UI
```dart
enum Role { 
  nursingHome,        // Пансионат
  agency,             // Патронажное агентство
  privateCaregiver    // Частная сиделка
}
```

### Маппинг на account_type для API

| UI Role              | API account_type | Описание                                   |
|---------------------|------------------|---------------------------------------------|
| `nursingHome`       | `pansionat`      | Учреждение для ухода за подопечными        |
| `agency`            | `agency`         | Агентство по предоставлению услуг ухода    |
| `privateCaregiver`  | `specialist`     | Индивидуальный специалист по уходу         |

### Метод преобразования роли

```dart
String _getAccountType(Role role) {
  switch (role) {
    case Role.nursingHome:
      return 'pansionat';
    case Role.agency:
      return 'agency';
    case Role.privateCaregiver:
      return 'specialist';
  }
}
```

## Процесс регистрации (пошагово)

### Шаг 1: Выбор роли

Пользователь видит три карточки с типами организаций:
- **Пансионат** - Учреждение для ухода за подопечными
- **Патронажное агентство** - Агентство по предоставлению услуг ухода
- **Частная сиделка** - Индивидуальный специалист по уходу

```dart
// В состоянии хранятся:
int _step = 0;  // 0 = выбор роли, 1 = заполнение данных
Role? _selectedRole;  // Выбранная роль
```

При выборе карточки:
```dart
setState(() {
  _selectedRole = role;
  _step = 1;  // Переход к форме
});
```

### Шаг 2: Заполнение данных

Пользователь заполняет:
- **Телефон** - с маской `+7 (###) ###-##-##`
- **Пароль** - минимум 8 символов
- **Подтверждение пароля** - должно совпадать с паролем

```dart
final MaskTextInputFormatter _phoneMask = MaskTextInputFormatter(
  mask: '+7 (###) ###-##-##',
  filter: {"#": RegExp(r'\d')},
);
```

### Шаг 3: Отправка данных

При нажатии кнопки "Зарегистрироваться":

```dart
void _submit() {
  if (_formKey.currentState?.validate() ?? false) {
    if (_selectedRole == null) {
      // Показ ошибки
      return;
    }

    _formKey.currentState?.save();
    final phone = _phoneMask.getUnmaskedText();  // Получаем номер без маски
    final accountType = _getAccountType(_selectedRole!);  // Преобразуем роль

    // Отправляем событие в BLoC
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        phone: phone,
        password: _password,
        passwordConfirmation: _passwordConfirmation,
        firstName: '',  // Пустые значения для первого этапа
        lastName: '',
        accountType: accountType,  // ВАЖНО: Передаем тип аккаунта
        organizationName: null,
        referralCode: null,
      ),
    );
  }
}
```

## Структура события AuthRegisterRequested

```dart
class AuthRegisterRequested extends AuthEvent {
  final String phone;                    // Телефон (обязательно)
  final String password;                 // Пароль (обязательно)
  final String passwordConfirmation;     // Подтверждение пароля (обязательно)
  final String firstName;                // Имя (опционально)
  final String lastName;                 // Фамилия (опционально)
  final String accountType;              // ТИП АККАУНТА (обязательно!)
  final String? organizationName;        // Название организации (опционально)
  final String? referralCode;            // Реферальный код (опционально)
}
```

### Ключевые поля для передачи роли

**`accountType`** - это основное поле для передачи роли. Оно должно содержать одно из значений:
- `'pansionat'` - для пансионатов
- `'agency'` - для агентств
- `'specialist'` - для частных сиделок

## Обработка в AuthBloc

```dart
Future<void> _onRegisterRequested(
  AuthRegisterRequested event,
  Emitter<AuthState> emit,
) async {
  emit(const AuthLoading());

  try {
    // Формирование данных для API
    final data = <String, dynamic>{
      'phone': event.phone,
      'password': event.password,
      'password_confirmation': event.passwordConfirmation,
      'account_type': event.accountType,  // Передача роли в API
    };

    // Опциональные поля добавляются только если заполнены
    if (event.firstName.isNotEmpty) {
      data['first_name'] = event.firstName;
    }
    if (event.lastName.isNotEmpty) {
      data['last_name'] = event.lastName;
    }
    if (event.organizationName != null && event.organizationName!.isNotEmpty) {
      data['organization_name'] = event.organizationName;
    }
    if (event.referralCode != null && event.referralCode!.isNotEmpty) {
      data['referral_code'] = event.referralCode;
    }

    // Отправка запроса
    final response = await _authRepository.register(data);

    // После успешной регистрации переходим к подтверждению SMS
    emit(
      AuthAwaitingSmsVerification(
        phone: response['phone'] as String,
        message: response['message'] as String,
      ),
    );
  } catch (e) {
    // Обработка ошибок
    emit(AuthFailure('Ошибка при регистрации'));
  }
}
```

## API запрос регистрации

### Endpoint
```
POST /auth/register
```

### Тело запроса (JSON)

```json
{
  "phone": "77001234567",
  "password": "password123",
  "password_confirmation": "password123",
  "account_type": "pansionat",
  "first_name": "Иван",
  "last_name": "Иванов",
  "organization_name": "Название организации",
  "referral_code": "REF123"
}
```

### Обязательные поля
- `phone` - номер телефона
- `password` - пароль
- `password_confirmation` - подтверждение пароля
- `account_type` - **тип аккаунта (роль)**

### Опциональные поля
- `first_name` - имя
- `last_name` - фамилия
- `organization_name` - название организации
- `referral_code` - реферальный код

### Успешный ответ (200)

```json
{
  "message": "SMS-код отправлен на номер +7 700 123-45-67",
  "phone": "77001234567"
}
```

## Состояния после регистрации

### 1. AuthAwaitingSmsVerification
После успешной отправки данных:
```dart
if (state is AuthAwaitingSmsVerification) {
  context.push('/verify-code/${state.phone}');
}
```
Пользователь перенаправляется на страницу подтверждения SMS-кода.

### 2. AuthAuthenticated
После успешного подтверждения кода:
```dart
if (state is AuthAuthenticated) {
  context.go('/home');
}
```

### 3. AuthFailure
При ошибках:
```dart
if (state is AuthFailure) {
  // Показ toast с ошибкой
  toastification.show(
    context: context,
    type: ToastificationType.error,
    title: const Text('Ошибка'),
    description: Text(state.message),
  );
}
```

## Обработка ошибок

### Типы ошибок

1. **ValidationException** - ошибки валидации полей
   ```dart
   catch (ValidationException e) {
     final errorMessage = e.getAllErrors().join(', ');
     emit(AuthFailure(errorMessage));
   }
   ```

2. **UnauthorizedException** - ошибки авторизации
3. **NetworkException** - проблемы с сетью
4. **ServerException** - ошибки сервера
5. **ApiException** - общие API ошибки

### Примеры ошибок валидации

- "Телефон уже зарегистрирован"
- "Пароль должен содержать минимум 8 символов"
- "Пароли не совпадают"
- "Некорректный формат телефона"

## Модель User после успешной регистрации

```dart
class User {
  final String id;
  final String? firstName;
  final String? lastName;
  final String phone;
  final String? accountType;  // Сохраненный тип аккаунта
  final List<String>? roles;   // Список ролей пользователя
  final Map<String, dynamic>? organization;  // Данные организации
}
```

### Определение типа пользователя

```dart
// В User.displayName
if (accountType == 'specialist') {
  return '$firstName $lastName'.trim();
}

if (accountType == 'pansionat' || accountType == 'agency') {
  return organization?['name'] ?? 'Организация';
}
```

## Пример полного флоу

```
1. Пользователь открывает RegisterPage
   └─> _step = 0 (выбор роли)

2. Пользователь выбирает "Пансионат"
   └─> _selectedRole = Role.nursingHome
   └─> _step = 1 (форма)

3. Пользователь заполняет:
   - Телефон: +7 (700) 123-45-67
   - Пароль: password123
   - Подтверждение: password123

4. Нажатие "Зарегистрироваться"
   └─> phone = "77001234567"
   └─> accountType = "pansionat"
   └─> Dispatch AuthRegisterRequested

5. AuthBloc обрабатывает событие
   └─> POST /auth/register с account_type: "pansionat"
   └─> emit(AuthAwaitingSmsVerification)

6. Навигация на /verify-code/77001234567

7. Пользователь вводит SMS-код
   └─> Dispatch AuthVerifyPhoneRequested

8. После подтверждения
   └─> emit(AuthAuthenticated)
   └─> Навигация на /home
```

## Важные замечания

### 1. Передача роли - КРИТИЧЕСКИ ВАЖНО
Роль **обязательно** должна передаваться через поле `accountType` в событии `AuthRegisterRequested`. Без этого поля сервер не сможет определить тип создаваемого аккаунта.

### 2. Маппинг ролей
Всегда используйте метод `_getAccountType()` для преобразования enum `Role` в строковое значение для API:
- `Role.nursingHome` → `"pansionat"`
- `Role.agency` → `"agency"`
- `Role.privateCaregiver` → `"specialist"`

### 3. Валидация телефона
Телефон передается **без маски** - используйте `_phoneMask.getUnmaskedText()` для получения чистого номера.

### 4. Опциональные поля
Имя, фамилия и другие опциональные поля добавляются в запрос только если они заполнены (не пустые).

### 5. Двухэтапная регистрация
Текущая реализация использует двухэтапную регистрацию:
- Этап 1: Выбор роли + базовые данные (телефон, пароль)
- Этап 2: Подтверждение SMS-кодом

## Расширение функционала

### Добавление новой роли

1. Добавить в enum:
```dart
enum Role { 
  nursingHome, 
  agency, 
  privateCaregiver,
  newRole  // Новая роль
}
```

2. Добавить маппинг:
```dart
String _getAccountType(Role role) {
  switch (role) {
    // ... существующие
    case Role.newRole:
      return 'new_role_api_value';
  }
}
```

3. Добавить название:
```dart
String _getRoleName(Role role) {
  switch (role) {
    // ... существующие
    case Role.newRole:
      return 'Название новой роли';
  }
}
```

4. Добавить карточку в UI:
```dart
_buildRoleCard(
  title: 'Название новой роли',
  subtitle: 'Описание',
  role: Role.newRole,
),
```

### Добавление дополнительных полей

Если нужно собирать больше данных при регистрации:

1. Добавить поля в состояние `_RegisterPageState`
2. Добавить TextFormField в форму
3. Передать значения в `AuthRegisterRequested`
4. Обновить `AuthRegisterRequested` с новыми полями
5. Добавить поля в data в `_onRegisterRequested`

## Заключение

Система регистрации построена на BLoC паттерне и четко разделяет ответственность между UI, бизнес-логикой и работой с API. Ключевым аспектом является правильная передача `accountType`, которая определяет тип создаваемого аккаунта и влияет на доступный функционал в приложении.