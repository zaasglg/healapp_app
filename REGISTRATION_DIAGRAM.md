# Диаграмма процесса регистрации

## Общая схема потока данных

```
┌─────────────────────────────────────────────────────────────────────┐
│                          RegisterPage (UI)                          │
│                                                                     │
│  Step 0: Выбор роли                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │  Пансионат   │  │  Агентство   │  │   Сиделка    │            │
│  │ nursingHome  │  │    agency    │  │privateCaregiver│          │
│  └──────────────┘  └──────────────┘  └──────────────┘            │
│         │                  │                  │                     │
│         └──────────────────┴──────────────────┘                     │
│                            │                                         │
│                      _selectedRole                                  │
│                            │                                         │
│  Step 1: Форма регистрации                                         │
│  ┌─────────────────────────────────────────┐                       │
│  │  Телефон: +7 (___) ___-__-__           │                       │
│  │  Пароль: ************                   │                       │
│  │  Подтверждение: ************            │                       │
│  │                                          │                       │
│  │  [Зарегистрироваться]                   │                       │
│  └─────────────────────────────────────────┘                       │
│                            │                                         │
│                       _submit()                                     │
│                            │                                         │
└────────────────────────────┼─────────────────────────────────────────┘
                             ▼
                    _getAccountType()
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
    nursingHome          agency          privateCaregiver
        │                    │                    │
        ▼                    ▼                    ▼
   "pansionat"           "agency"           "specialist"
        │                    │                    │
        └────────────────────┴────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   context.read<AuthBloc>().add()                    │
│                                                                     │
│  AuthRegisterRequested(                                            │
│    phone: "77001234567",                                           │
│    password: "password123",                                        │
│    passwordConfirmation: "password123",                            │
│    accountType: "pansionat",  ◄─── КЛЮЧЕВОЕ ПОЛЕ                  │
│    firstName: "",                                                  │
│    lastName: "",                                                   │
│  )                                                                 │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AuthBloc (BLoC Layer)                          │
│                                                                     │
│  _onRegisterRequested()                                            │
│         │                                                           │
│         ▼                                                           │
│  emit(AuthLoading)                                                 │
│         │                                                           │
│         ▼                                                           │
│  Формирование data:                                                │
│  {                                                                  │
│    "phone": "77001234567",                                         │
│    "password": "password123",                                      │
│    "password_confirmation": "password123",                         │
│    "account_type": "pansionat"  ◄─── Передача в API               │
│  }                                                                 │
│         │                                                           │
│         ▼                                                           │
│  await _authRepository.register(data)                              │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  AuthRepository (Data Layer)                        │
│                                                                     │
│  register(data)                                                    │
│         │                                                           │
│         ▼                                                           │
│  POST /auth/register                                               │
│  Body: {                                                            │
│    "phone": "77001234567",                                         │
│    "password": "password123",                                      │
│    "password_confirmation": "password123",                         │
│    "account_type": "pansionat"                                     │
│  }                                                                 │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Backend API                                 │
│                                                                     │
│  Создание пользователя с account_type = "pansionat"               │
│  Отправка SMS-кода на номер телефона                               │
│                                                                     │
│  Response: {                                                        │
│    "message": "SMS-код отправлен...",                              │
│    "phone": "77001234567"                                          │
│  }                                                                 │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AuthBloc (BLoC Layer)                          │
│                                                                     │
│  emit(AuthAwaitingSmsVerification(                                 │
│    phone: "77001234567",                                           │
│    message: "SMS-код отправлен..."                                 │
│  ))                                                                │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    RegisterPage (BlocListener)                      │
│                                                                     │
│  if (state is AuthAwaitingSmsVerification)                         │
│         │                                                           │
│         ▼                                                           │
│  context.push('/verify-code/77001234567')                          │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                    VerifyCodePage
                             │
                             ▼
              Подтверждение SMS-кода
                             │
                             ▼
                 AuthAuthenticated State
                             │
                             ▼
                   Навигация на /home
```

## Маппинг ролей (детально)

```
UI Layer (RegisterPage)          Backend API          User Model
═══════════════════════          ═══════════          ══════════

enum Role:

nursingHome ────────────────► "pansionat" ────────► accountType: "pansionat"
                                                     ├─ organization: {...}
                                                     └─ roles: ["owner"]

agency ─────────────────────► "agency" ───────────► accountType: "agency"
                                                     ├─ organization: {...}
                                                     └─ roles: ["owner"]

privateCaregiver ───────────► "specialist" ───────► accountType: "specialist"
                                                     ├─ firstName: "..."
                                                     ├─ lastName: "..."
                                                     └─ roles: ["specialist"]
```

## Обработка ошибок

```
┌──────────────────┐
│   AuthBloc       │
│  _onRegister     │
└────────┬─────────┘
         │
         ▼
    try { ... }
         │
         ├─► ValidationException
         │   └─► AuthFailure("Телефон уже зарегистрирован")
         │
         ├─► NetworkException
         │   └─► AuthFailure("Ошибка сети: ...")
         │
         ├─► ServerException
         │   └─► AuthFailure("Ошибка сервера: ...")
         │
         └─► ApiException
             └─► AuthFailure("API ошибка: ...")
         │
         ▼
┌──────────────────┐
│  RegisterPage    │
│  BlocListener    │
└────────┬─────────┘
         │
         ▼
if (state is AuthFailure)
         │
         ▼
    Toast с ошибкой
```

## Состояния UI (Step-based)

```
RegisterPage
│
├─ Step 0: Выбор роли
│  │
│  ├─ _selectedRole = null
│  │
│  ├─ Показ карточек:
│  │  ├─ Пансионат
│  │  ├─ Агентство
│  │  └─ Частная сиделка
│  │
│  └─ При выборе:
│     └─► setState(() {
│           _selectedRole = role;
│           _step = 1;
│         })
│
└─ Step 1: Форма регистрации
   │
   ├─ Показ формы с полями
   │  ├─ Телефон (с маской)
   │  ├─ Пароль
   │  └─ Подтверждение пароля
   │
   ├─ Кнопка "Назад" → _step = 0
   │
   └─ Кнопка "Зарегистрироваться" → _submit()
```

## BLoC State Flow

```
RegisterPage создана
        │
        ▼
┌─────────────────┐
│  AuthInitial    │ ← Начальное состояние
└─────────────────┘
        │
        ▼ (пользователь заполнил форму)
    _submit()
        │
        ▼ (dispatch AuthRegisterRequested)
┌─────────────────┐
│  AuthLoading    │ ← Показ индикатора загрузки
└─────────────────┘
        │
        ├─► Успех
        │   │
        │   ▼
        │ ┌──────────────────────────────┐
        │ │ AuthAwaitingSmsVerification  │ ← SMS отправлен
        │ └──────────────────────────────┘
        │   │
        │   ▼
        │ Навигация на /verify-code
        │
        └─► Ошибка
            │
            ▼
          ┌─────────────────┐
          │  AuthFailure    │ ← Показ toast с ошибкой
          └─────────────────┘
```

## Ключевые точки передачи роли

```
1. UI: Выбор роли
   _selectedRole = Role.nursingHome

2. UI: Преобразование
   accountType = _getAccountType(Role.nursingHome)
   // accountType = "pansionat"

3. Event: Создание события
   AuthRegisterRequested(
     accountType: "pansionat"  ◄─── Роль передается здесь
   )

4. BLoC: Формирование запроса
   data['account_type'] = event.accountType  ◄─── Роль в data

5. Repository: API запрос
   POST /auth/register
   {
     "account_type": "pansionat"  ◄─── Роль отправляется на сервер
   }

6. Backend: Создание пользователя
   User.account_type = "pansionat"  ◄─── Роль сохраняется в БД

7. Response: Возврат данных
   User {
     accountType: "pansionat"  ◄─── Роль возвращается клиенту
   }
```

## Валидация на каждом этапе

```
UI Layer (RegisterPage)
├─ Выбрана ли роль? (_selectedRole != null)
├─ Валидация формы (формат телефона, длина пароля)
└─ Совпадение паролей

BLoC Layer (AuthBloc)
├─ Обработка исключений
└─ Проверка ответа сервера

API Layer (Backend)
├─ Валидация телефона (уникальность, формат)
├─ Валидация пароля (длина, сложность)
├─ Валидация account_type (допустимые значения)
└─ Проверка обязательных полей
```

## Пример успешного флоу с таймингами

```
T+0s   │ Пользователь открывает RegisterPage
       │ State: AuthInitial
       │
T+5s   │ Выбирает "Пансионат"
       │ _selectedRole = Role.nursingHome
       │ _step = 1
       │
T+15s  │ Заполняет форму
       │ phone: "+7 (700) 123-45-67"
       │ password: "password123"
       │
T+20s  │ Нажимает "Зарегистрироваться"
       │ Dispatch AuthRegisterRequested
       │ State: AuthLoading
       │
T+21s  │ POST /auth/register
       │ body.account_type = "pansionat"
       │
T+23s  │ Ответ от сервера (200 OK)
       │ State: AuthAwaitingSmsVerification
       │
T+23s  │ Навигация на /verify-code/77001234567
       │
T+30s  │ Пользователь вводит SMS-код
       │ Dispatch AuthVerifyPhoneRequested
       │
T+32s  │ Подтверждение успешно
       │ State: AuthAuthenticated
       │
T+32s  │ Навигация на /home
```
