# Система регистрации и авторизации HealApp

## Оглавление

1. [Обзор системы](#обзор-системы)
2. [Типы пользователей](#типы-пользователей)
3. [Роли в организации](#роли-в-организации)
4. [Permissions (Права доступа)](#permissions-права-доступа)
5. [Процесс регистрации](#процесс-регистрации)
6. [Процесс авторизации](#процесс-авторизации)
7. [Верификация телефона](#верификация-телефона)
8. [Смена номера телефона](#смена-номера-телефона)
9. [Система приглашений](#система-приглашений)
10. [Доступ к дневникам](#доступ-к-дневникам)
11. [API Endpoints](#api-endpoints)

---

## Обзор системы

HealApp использует **Laravel Sanctum** для аутентификации через API-токены и **Spatie Laravel Permission** для управления ролями и правами доступа.

### Ключевые компоненты:

| Компонент | Путь | Назначение |
|-----------|------|------------|
| `AuthController` | `app/Http/Controllers/Api/v1/AuthController.php` | Контроллер аутентификации |
| `User` модель | `app/Models/User.php` | Модель пользователя с методами проверки ролей |
| `UserType` enum | `app/Enums/UserType.php` | Типы аккаунтов |
| `OrganizationRole` enum | `app/Enums/OrganizationRole.php` | Роли внутри организации |
| `PermissionsSeeder` | `database/seeders/PermissionsSeeder.php` | Создание ролей и permissions |

---

## Типы пользователей

Система поддерживает три основных типа пользователей, определённых в `App\Enums\UserType`:

### 1. CLIENT (Клиент)
```
account_type: 'client'
```
- **Описание**: Родственник или законный представитель подопечного
- **Особенности**:
  - Владеет карточками пациентов (подопечных)
  - Имеет полный доступ к своим дневникам
  - Не принадлежит организации
  - Получает доступ через приглашения от организаций

### 2. PRIVATE_CAREGIVER (Частная сиделка)
```
account_type: 'specialist'
```
- **Описание**: Независимый специалист, работающий напрямую с клиентами
- **Особенности**:
  - Работает самостоятельно без организации
  - Может создавать карточки подопечных
  - Доступ к дневникам через явное назначение
  - Может выполнять задачи в маршрутных листах

### 3. ORGANIZATION (Организация)
```
account_type: 'pansionat' | 'agency'
```
- **Описание**: Владелец или сотрудник организации
- **Подтипы**:
  - **Пансионат (`pansionat`)**: Все сотрудники видят всех подопечных
  - **Патронажное агентство (`agency`)**: Сотрудники привязываются к конкретным подопечным

---

## Роли в организации

Определены в `App\Enums\OrganizationRole` и используются через Spatie Permission:

### 🔴 OWNER (Владелец)
```php
Role: 'owner'
```
- Полные права на организацию
- Создаётся автоматически при регистрации организации
- Может управлять всеми сотрудниками
- Имеет все permissions

### 🟠 ADMIN (Администратор)
```php
Role: 'admin'
```
- Почти полные права (кроме удаления организации)
- Может приглашать и управлять сотрудниками
- Может управлять доступом к дневникам
- Может создавать карточки подопечных

### 🟢 DOCTOR (Врач)
```php
Role: 'doctor'
```
- Может просматривать пациентов и дневники
- Может заполнять дневники
- Может создавать и редактировать маршрутные листы
- **Не может** управлять сотрудниками

### 🔵 CAREGIVER (Сиделка)
```php
Role: 'caregiver'
```
- Минимальные права
- Может просматривать назначенных пациентов
- Может заполнять дневники
- Может выполнять задачи (отмечать как выполненные)
- **Не может** создавать или редактировать задачи

---

## Permissions (Права доступа)

Permissions создаются в `PermissionsSeeder`:

### Пациенты
| Permission | Описание | Owner | Admin | Doctor | Caregiver |
|------------|----------|:-----:|:-----:|:------:|:---------:|
| `patients.create` | Создание карточек | ✅ | ✅ | ❌ | ❌ |
| `patients.view` | Просмотр пациентов | ✅ | ✅ | ✅ | ✅ |
| `patients.edit` | Редактирование | ✅ | ✅ | ❌ | ❌ |
| `patients.delete` | Удаление | ✅ | ✅ | ❌ | ❌ |

### Дневники
| Permission | Описание | Owner | Admin | Doctor | Caregiver |
|------------|----------|:-----:|:-----:|:------:|:---------:|
| `diaries.create` | Создание дневников | ✅ | ✅ | ❌ | ❌ |
| `diaries.view` | Просмотр | ✅ | ✅ | ✅ | ✅ |
| `diaries.edit` | Редактирование настроек | ✅ | ✅ | ❌ | ❌ |
| `diaries.fill` | Внесение записей | ✅ | ✅ | ✅ | ✅ |

### Маршрутные листы (Tasks)
| Permission | Описание | Owner | Admin | Doctor | Caregiver |
|------------|----------|:-----:|:-----:|:------:|:---------:|
| `tasks.create` | Создание задач | ✅ | ✅ | ✅ | ❌ |
| `tasks.view` | Просмотр | ✅ | ✅ | ✅ | ✅ |
| `tasks.edit` | Редактирование | ✅ | ✅ | ✅ | ❌ |
| `tasks.complete` | Выполнение | ✅ | ✅ | ❌ | ✅ |

### Управление
| Permission | Описание | Owner | Admin | Doctor | Caregiver |
|------------|----------|:-----:|:-----:|:------:|:---------:|
| `access.manage` | Управление доступом | ✅ | ✅ | ❌ | ❌ |
| `employees.invite` | Приглашение сотрудников | ✅ | ✅ | ❌ | ❌ |
| `employees.manage` | Управление сотрудниками | ✅ | ✅ | ❌ | ❌ |
| `clients.invite` | Приглашение клиентов | ✅ | ✅ | ❌ | ❌ |
| `organization.edit` | Редактирование организации | ✅ | ✅ | ❌ | ❌ |

---

## Процесс регистрации

### Endpoint
```http
POST /api/v1/auth/register
```

### Request Body
```json
{
    "first_name": "string|nullable",
    "last_name": "string|nullable",
    "middle_name": "string|nullable",
    "phone": "string|required|unique",
    "password": "string|required|min:6",
    "password_confirmation": "string|required",
    "account_type": "client|specialist|pansionat|agency",
    "organization_name": "string|nullable (для pansionat/agency)",
    "address": "string|nullable (для организаций)"
}
```

### Диаграмма процесса

```
┌─────────────────────────────────┐
│         Клиент шлёт             │
│      POST /auth/register        │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   Валидация RegisterRequest     │
│   - phone уникален              │
│   - password >= 6 символов      │
│   - account_type валиден        │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   Определение UserType          │
│   client → CLIENT               │
│   specialist → PRIVATE_CAREGIVER│
│   pansionat/agency → ORGANIZATION│
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   Создание User                 │
│   - Генерация verification_code │
│   - Хеширование пароля          │
└────────────────┬────────────────┘
                 │
         account_type?
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌───────┐  ┌──────────┐  ┌─────────────────┐
│client │  │specialist│  │pansionat/agency │
└───┬───┘  └────┬─────┘  └───────┬─────────┘
    │           │                │
    │           │                ▼
    │           │   ┌─────────────────────────┐
    │           │   │ Создание Organization   │
    │           │   │ - owner_id = user.id    │
    │           │   │ - type = boarding_house │
    │           │   │   или agency            │
    │           │   └───────────┬─────────────┘
    │           │               │
    │           │               ▼
    │           │   ┌─────────────────────────┐
    │           │   │ Привязка user к org     │
    │           │   │ Назначение роли 'owner' │
    │           │   └───────────┬─────────────┘
    │           │               │
    └───────────┴───────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   SMS с кодом верификации       │
│   (в тесте код = '1234')        │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   Response: {"message": "SMS    │
│   sent", "phone": "..."}        │
└─────────────────────────────────┘
```

### Код регистрации (упрощённо)
```php
public function register(RegisterRequest $request): JsonResponse
{
    // Генерация кода (в тесте '1234')
    $verificationCode = app()->environment('production')
        ? str_pad((string) rand(0, 9999), 4, '0', STR_PAD_LEFT)
        : '1234';

    // Определение типа
    $userType = match ($request->account_type) {
        'client' => UserType::CLIENT,
        'specialist' => UserType::PRIVATE_CAREGIVER,
        'pansionat', 'agency' => UserType::ORGANIZATION,
    };

    // Создание пользователя
    $user = User::create([
        'phone' => $request->phone,
        'password' => Hash::make($request->password),
        'verification_code' => $verificationCode,
        'type' => $userType->value,
        // ...
    ]);

    // Для организаций
    if (in_array($request->account_type, ['pansionat', 'agency'])) {
        $organization = Organization::create([
            'owner_id' => $user->id,
            'type' => $organizationType->value,
            // ...
        ]);
        $user->organization_id = $organization->id;
        $user->save();
        $user->assignRole('owner'); // Spatie Role
    }

    return response()->json(['message' => 'SMS sent', 'phone' => $user->phone]);
}
```

---

## Процесс авторизации

### Endpoint
```http
POST /api/v1/auth/login
```

### Request Body
```json
{
    "phone": "79001234567",
    "password": "secret123"
}
```

### Диаграмма процесса

```
┌─────────────────────────────────┐
│      POST /api/v1/auth/login    │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   Поиск пользователя по phone   │
└────────────────┬────────────────┘
                 │
            Найден?
         ┌───────┴───────┐
         ▼               ▼
       ┌─────┐        ┌──────┐
       │ Нет │        │  Да  │
       └──┬──┘        └───┬──┘
          │               │
          ▼               ▼
┌────────────────┐ ┌─────────────────────────┐
│ Ошибка 422:    │ │ Проверка пароля         │
│ "Неверные      │ │ Hash::check(...)        │
│ учётные данные"│ └───────────┬─────────────┘
└────────────────┘             │
                           Верный?
                     ┌─────────┴─────────┐
                     ▼                   ▼
                  ┌─────┐             ┌──────┐
                  │ Нет │             │  Да  │
                  └──┬──┘             └───┬──┘
                     │                    │
                     ▼                    ▼
          ┌────────────────┐   ┌──────────────────────┐
          │ Ошибка 422:    │   │ Проверка верификации │
          │ "Неверные      │   │ phone_verified_at    │
          │ учётные данные"│   └──────────┬───────────┘
          └────────────────┘              │
                                    Подтверждён?
                              ┌───────────┴───────────┐
                              ▼                       ▼
                           ┌─────┐                 ┌──────┐
                           │ Нет │                 │  Да  │
                           └──┬──┘                 └───┬──┘
                              │                        │
                              ▼                        ▼
                  ┌────────────────────┐   ┌─────────────────────┐
                  │ Ошибка 401:        │   │ Создание токена     │
                  │ "Телефон не        │   │ Sanctum             │
                  │ подтверждён"       │   │ createToken(...)    │
                  └────────────────────┘   └──────────┬──────────┘
                                                      │
                                                      ▼
                                           ┌──────────────────────┐
                                           │ Response:            │
                                           │ {                    │
                                           │   "access_token":    │
                                           │   "user": {...}      │
                                           │ }                    │
                                           └──────────────────────┘
```

### Response (успешный вход)
```json
{
    "access_token": "1|abc123...",
    "user": {
        "id": 1,
        "first_name": "Иван",
        "last_name": "Иванов",
        "phone": "79001234567",
        "type": "organization",
        "account_type": "pansionat",
        "role": "owner",
        "organization": {
            "id": 1,
            "name": "Пансионат 'Забота'",
            "type": "boarding_house"
        }
    }
}
```

---

## Верификация телефона

### Endpoint
```http
POST /api/v1/auth/verify-phone
```

### Request Body
```json
{
    "phone": "79001234567",
    "code": "1234"
}
```

### Процесс

```
┌─────────────────────────────────┐
│  POST /api/v1/auth/verify-phone │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   Поиск user по phone           │
│   Проверка verification_code    │
└────────────────┬────────────────┘
                 │
            Совпадает?
         ┌───────┴───────┐
         ▼               ▼
       ┌─────┐        ┌──────┐
       │ Нет │        │  Да  │
       └──┬──┘        └───┬──┘
          │               │
          ▼               ▼
┌────────────────┐ ┌─────────────────────────┐
│ Ошибка 401:    │ │ Обновление:             │
│ "Неверный код" │ │ - phone_verified_at=now │
└────────────────┘ │ - verification_code=null│
                   └───────────┬─────────────┘
                               │
                               ▼
                   ┌─────────────────────────┐
                   │ Создание токена Sanctum │
                   └───────────┬─────────────┘
                               │
                               ▼
                   ┌─────────────────────────┐
                   │ Response:               │
                   │ {"access_token": "...", │
                   │  "user": {...}}         │
                   └─────────────────────────┘
```

> **Примечание**: В тестовом окружении (`APP_ENV != production`) код верификации всегда `1234`.

---

## Смена номера телефона

### Шаг 1: Запрос на смену
```http
POST /api/v1/auth/change-phone/request
Authorization: Bearer {token}
```
```json
{
    "phone": "79009876543"
}
```

### Шаг 2: Подтверждение
```http
POST /api/v1/auth/change-phone/confirm
Authorization: Bearer {token}
```
```json
{
    "code": "1234"
}
```

### Диаграмма

```
┌─────────────────────────────────────────┐
│  POST /auth/change-phone/request        │
│  {"phone": "новый_номер"}               │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│  Сохранение в user:                     │
│  - unverified_phone = новый_номер       │
│  - verification_code = новый_код        │
└─────────────────────┬───────────────────┘
                      │
        SMS на новый номер
                      │
                      ▼
┌─────────────────────────────────────────┐
│  POST /auth/change-phone/confirm        │
│  {"code": "1234"}                       │
└─────────────────────┬───────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────┐
│  Если код верный:                       │
│  - phone = unverified_phone             │
│  - unverified_phone = null              │
│  - verification_code = null             │
│  - phone_verified_at = now()            │
└─────────────────────────────────────────┘
```

---

## Система приглашений

Система поддерживает два типа приглашений:

### 1. Приглашение сотрудника
```http
POST /api/v1/invitations/employee
Authorization: Bearer {token}
```
```json
{
    "role": "doctor", // admin, doctor, caregiver
    "phone": "79001234567" // опционально
}
```

**Результат**: Генерируется уникальная ссылка, при переходе по которой:
- Новый пользователь регистрируется и автоматически добавляется в организацию с указанной ролью
- Существующий пользователь привязывается к организации

### 2. Приглашение клиента
```http
POST /api/v1/invitations/client
Authorization: Bearer {token}
```
```json
{
    "patient_id": 1,
    "diary_id": 1 // опционально
}
```

**Результат**: Клиент получает:
- Связь с организацией
- Доступ к карточке пациента (становится owner)
- Доступ к дневнику

### Принятие приглашения
```http
POST /api/v1/invitations/{token}/accept
```
```json
{
    "phone": "79001234567",
    "password": "secret123",
    "password_confirmation": "secret123"
}
```

---

## Доступ к дневникам

### Логика доступа (метод `canAccessDiary`)

```php
public function canAccessDiary(Diary $diary): bool
{
    $patient = $diary->patient;

    // 1. Владелец карточки (клиент) - всегда имеет доступ
    if ($patient->owner_id === $this->id) {
        return true;
    }

    // 2. Частная сиделка - нужен явный доступ через diary_access
    if ($this->isPrivateCaregiver()) {
        return $diary->hasAccess($this);
    }

    // 3. Сотрудник организации
    if ($this->organization_id && $patient->organization_id === $this->organization_id) {
        $org = $this->organization;
        
        // Пансионат: ВСЕ сотрудники видят ВСЕ дневники
        if ($org->isBoardingHouse()) {
            return true;
        }
        
        // Агентство: нужен явный доступ
        if ($org->isAgency()) {
            return $diary->hasAccess($this);
        }
    }

    return false;
}
```

### Визуализация

```
                    ┌─────────────────────────────────┐
                    │         Запрос доступа          │
                    │       к дневнику (Diary)        │
                    └────────────────┬────────────────┘
                                     │
                                     ▼
                    ┌─────────────────────────────────┐
                    │   User == Patient.owner_id?     │
                    └────────────────┬────────────────┘
                              ┌──────┴──────┐
                              ▼             ▼
                           ┌─────┐       ┌─────┐
                           │ Да  │───────│ДОСТУП│
                           └─────┘       └─────┘
                              │  
                              ▼ Нет
                    ┌─────────────────────────────────┐
                    │  User.isPrivateCaregiver()?     │
                    └────────────────┬────────────────┘
                              ┌──────┴──────┐
                              ▼             ▼
                           ┌─────┐       ┌─────┐
                           │ Да  │       │ Нет │
                           └──┬──┘       └──┬──┘
                              │             │
                              ▼             │
                    ┌──────────────────┐    │
                    │ diary.hasAccess? │    │
                    └───────┬──────────┘    │
                            │               │
                       ┌────┴────┐          │
                       ▼         ▼          │
                    ┌─────┐   ┌─────┐       │
                    │ Да  │   │ Нет │       │
                    └──┬──┘   └──┬──┘       │
                       │         │          │
                       ▼         ▼          │
                   ┌─────┐   ┌──────┐       │
                   │ДОСТУП│  │ОТКАЗ │       │
                   └─────┘   └──────┘       │
                                            ▼
                    ┌─────────────────────────────────┐
                    │ User.organization == Patient.org│
                    └────────────────┬────────────────┘
                              ┌──────┴──────┐
                              ▼             ▼
                           ┌─────┐       ┌──────┐
                           │ Да  │       │ Нет  │──▶ ОТКАЗ
                           └──┬──┘       └──────┘
                              │
                              ▼
                    ┌─────────────────────────────────┐
                    │   Тип организации?              │
                    └────────────────┬────────────────┘
                         ┌───────────┴───────────┐
                         ▼                       ▼
                 ┌──────────────┐        ┌───────────────┐
                 │  Пансионат   │        │   Агентство   │
                 │ (boarding_   │        │   (agency)    │
                 │   house)     │        │               │
                 └──────┬───────┘        └───────┬───────┘
                        │                        │
                        ▼                        ▼
                    ┌─────┐            ┌──────────────────┐
                    │ДОСТУП│           │ diary.hasAccess? │
                    └─────┘            └────────┬─────────┘
                                          ┌─────┴─────┐
                                          ▼           ▼
                                      ┌─────┐     ┌──────┐
                                      │ Да  │     │ Нет  │
                                      └──┬──┘     └──┬───┘
                                         │           │
                                         ▼           ▼
                                     ┌─────┐     ┌──────┐
                                     │ДОСТУП│    │ОТКАЗ │
                                     └─────┘     └──────┘
```

---

## API Endpoints

### Аутентификация

| Метод | Endpoint | Описание | Auth |
|-------|----------|----------|:----:|
| POST | `/api/v1/auth/register` | Регистрация | ❌ |
| POST | `/api/v1/auth/verify-phone` | Верификация телефона | ❌ |
| POST | `/api/v1/auth/login` | Вход в систему | ❌ |
| POST | `/api/v1/auth/logout` | Выход из системы | ✅ |
| GET | `/api/v1/auth/me` | Текущий пользователь | ✅ |
| PATCH | `/api/v1/auth/profile` | Обновление профиля | ✅ |
| POST | `/api/v1/auth/change-phone/request` | Запрос смены телефона | ✅ |
| POST | `/api/v1/auth/change-phone/confirm` | Подтверждение смены | ✅ |

### Приглашения

| Метод | Endpoint | Описание | Auth |
|-------|----------|----------|:----:|
| GET | `/api/v1/invitations/{token}` | Просмотр приглашения | ❌ |
| POST | `/api/v1/invitations/{token}/accept` | Принятие приглашения | ❌ |
| GET | `/api/v1/invitations` | Список приглашений | ✅ |
| POST | `/api/v1/invitations/employee` | Пригласить сотрудника | ✅ |
| POST | `/api/v1/invitations/client` | Пригласить клиента | ✅ |
| DELETE | `/api/v1/invitations/{id}` | Отозвать приглашение | ✅ |

### Организация

| Метод | Endpoint | Описание | Auth |
|-------|----------|----------|:----:|
| GET | `/api/v1/organization` | Информация об организации | ✅ |
| PATCH | `/api/v1/organization` | Обновление организации | ✅ |
| GET | `/api/v1/organization/employees` | Список сотрудников | ✅ |
| PATCH | `/api/v1/organization/employees/{id}/role` | Изменить роль | ✅ |
| DELETE | `/api/v1/organization/employees/{id}` | Удалить сотрудника | ✅ |
| POST | `/api/v1/organization/assign-diary-access` | Назначить доступ | ✅ |
| DELETE | `/api/v1/organization/revoke-diary-access` | Отозвать доступ | ✅ |

---

## Примеры использования

### Регистрация клиента
```bash
curl -X POST https://api.healapp.kz/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Мария",
    "last_name": "Петрова",
    "phone": "79001234567",
    "password": "secret123",
    "password_confirmation": "secret123",
    "account_type": "client"
  }'
```

### Регистрация пансионата
```bash
curl -X POST https://api.healapp.kz/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Иван",
    "last_name": "Директоров",
    "phone": "79009876543",
    "password": "secret123",
    "password_confirmation": "secret123",
    "account_type": "pansionat",
    "organization_name": "Пансионат \"Забота\"",
    "address": "г. Алматы, ул. Примерная, 1"
  }'
```

### Авторизация
```bash
curl -X POST https://api.healapp.kz/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "79001234567",
    "password": "secret123"
  }'
```

### Проверка текущего пользователя
```bash
curl https://api.healapp.kz/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## Безопасность

### Хранение паролей
- Пароли хешируются с использованием `bcrypt` через Laravel `Hash::make()`
- Хеши хранятся в поле `password` с cast `'hashed'`

### Токены
- Используется **Laravel Sanctum** для API токенов
- Токены привязаны к конкретному устройству/сессии
- При выходе токен удаляется из БД

### Верификация
- Код верификации генерируется случайно (4 цифры)
- В production коды отправляются через SMS
- В development/testing используется фиксированный код `1234`

### Middleware
- Защищённые маршруты используют `auth:sanctum`
- Проверка ролей через Spatie `HasRoles` trait

---

*Документация актуальна на 22.12.2024*
