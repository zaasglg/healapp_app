# API Маршрутного листа (Route Sheet)

## Оглавление

- [Обзор](#обзор)
- [Аутентификация](#аутентификация)
- [Модели данных](#модели-данных)
- [Endpoints](#endpoints)
  - [Route Sheet](#route-sheet-маршрутный-лист)
  - [Task Templates](#task-templates-шаблоны-задач)
- [Примеры использования](#примеры-использования)
- [Права доступа](#права-доступа)
- [Коды ошибок](#коды-ошибок)

---

## Обзор

Маршрутный лист — это чёткий план с задачами на день/неделю, которые должна выполнять сиделка. API позволяет:

- Создавать и управлять шаблонами задач (повторяющиеся задачи)
- Создавать одноразовые задачи
- Просматривать задачи на определённую дату
- Переносить задачи на другое время
- Отмечать выполнение/невыполнение задач
- Назначать задачи конкретным сотрудникам
- Прикреплять фото к выполненным задачам
- Автоматически создавать записи в дневнике при выполнении задач с измерениями

---

## Аутентификация

Все запросы требуют Bearer Token (Sanctum):

```
Authorization: Bearer {token}
```

---

## Модели данных

### Task (Задача)

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | integer | Уникальный идентификатор |
| `patient_id` | integer | ID подопечного |
| `template_id` | integer, null | ID шаблона (если создана из шаблона) |
| `assigned_to` | integer, null | ID назначенного сотрудника |
| `title` | string | Название задачи |
| `start_at` | datetime | Время начала |
| `end_at` | datetime | Время окончания |
| `original_start_at` | datetime, null | Оригинальное время начала (если была перенесена) |
| `original_end_at` | datetime, null | Оригинальное время окончания |
| `status` | enum | `pending`, `completed`, `missed`, `cancelled` |
| `priority` | integer | Приоритет (0-10) |
| `completed_at` | datetime, null | Время выполнения |
| `completed_by` | integer, null | ID пользователя, выполнившего задачу |
| `comment` | string, null | Комментарий |
| `photos` | array, null | Массив URL фотографий |
| `reschedule_reason` | string, null | Причина переноса |
| `rescheduled_by` | integer, null | ID пользователя, перенёсшего задачу |
| `rescheduled_at` | datetime, null | Время переноса |
| `related_diary_key` | string, null | Ключ для записи в дневник |
| `is_rescheduled` | boolean | Была ли задача перенесена |
| `is_overdue` | boolean | Просрочена ли задача |

### TaskTemplate (Шаблон задачи)

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | integer | Уникальный идентификатор |
| `patient_id` | integer | ID подопечного |
| `creator_id` | integer | ID создателя |
| `assigned_to` | integer, null | ID сотрудника по умолчанию |
| `title` | string | Название задачи |
| `days_of_week` | array, null | Дни недели [0-6]. Null = каждый день |
| `time_ranges` | array | Массив временных диапазонов |
| `start_date` | date | Дата начала действия |
| `end_date` | date, null | Дата окончания (null = бессрочно) |
| `is_active` | boolean | Активен ли шаблон |
| `related_diary_key` | string, null | Ключ для записи в дневник |

#### Структура time_ranges

```json
[
    {
        "start": "08:00",
        "end": "08:30",
        "assigned_to": 5,      // optional
        "priority": 1          // optional
    }
]
```

### Дни недели

| Значение | День |
|----------|------|
| 0 | Воскресенье |
| 1 | Понедельник |
| 2 | Вторник |
| 3 | Среда |
| 4 | Четверг |
| 5 | Пятница |
| 6 | Суббота |

### Статусы задач

| Статус | Описание |
|--------|----------|
| `pending` | Ожидает выполнения |
| `completed` | Выполнена |
| `missed` | Не выполнена (пропущена) |
| `cancelled` | Отменена |

### Ключи дневника (related_diary_key)

| Ключ | Описание | Тип |
|------|----------|-----|
| `temperature` | Температура | physical |
| `blood_pressure` | Артериальное давление | physical |
| `pulse` | Пульс | physical |
| `blood_sugar` | Сахар в крови | physical |
| `saturation` | Сатурация | physical |
| `breathing_rate` | Частота дыхания | physical |
| `pain_level` | Уровень боли | physical |
| `weight` | Вес | physical |
| `height` | Рост | physical |
| `hygiene` | Гигиена | care |
| `diaper_change` | Смена подгузника | care |
| `meal` | Приём пищи | care |
| `medication` | Приём лекарств | care |
| `walk` | Прогулка | care |

---

## Endpoints

### Route Sheet (Маршрутный лист)

#### GET /api/v1/route-sheet

Получить маршрутный лист (задачи) на определённую дату.

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `patient_id` | integer | Нет | ID подопечного |
| `date` | date | Нет | Дата (YYYY-MM-DD). По умолчанию: сегодня |
| `from_date` | date | Нет | Начало диапазона |
| `to_date` | date | Нет | Конец диапазона |
| `status` | string | Нет | Фильтр по статусу |

**Пример запроса:**

```http
GET /api/v1/route-sheet?patient_id=1&date=2024-01-15
Authorization: Bearer {token}
```

**Пример ответа:**

```json
{
    "date": "2024-01-15",
    "from_date": "2024-01-15",
    "to_date": "2024-01-15",
    "tasks": [
        {
            "id": 1,
            "patient_id": 1,
            "template_id": 1,
            "assigned_to": 5,
            "title": "Смена подгузников",
            "start_at": "2024-01-15T08:00:00.000000Z",
            "end_at": "2024-01-15T08:30:00.000000Z",
            "status": "pending",
            "priority": 1,
            "is_rescheduled": false,
            "is_overdue": false,
            "patient": {
                "id": 1,
                "first_name": "Иван",
                "last_name": "Петров"
            },
            "assigned_to": {
                "id": 5,
                "name": "Мария Сидорова"
            }
        }
    ],
    "summary": {
        "total": 8,
        "pending": 5,
        "completed": 2,
        "missed": 1,
        "overdue": 0
    }
}
```

---

#### GET /api/v1/route-sheet/my-tasks

Получить задачи текущего пользователя (для сиделок).

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `date` | date | Нет | Дата (YYYY-MM-DD). По умолчанию: сегодня |

**Пример ответа:**

```json
{
    "date": "2024-01-15",
    "tasks": [...],
    "time_slots": {
        "08:00": [...],
        "09:00": [...],
        "14:00": [...]
    },
    "summary": {
        "total": 5,
        "pending": 3,
        "completed": 2,
        "overdue": 0
    }
}
```

---

#### GET /api/v1/route-sheet/available-employees

Получить доступных сотрудников для назначения задачи.

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `patient_id` | integer | Да | ID подопечного |
| `start_at` | datetime | Да | Время начала (Y-m-d H:i:s) |
| `end_at` | datetime | Да | Время окончания (Y-m-d H:i:s) |

**Пример ответа:**

```json
{
    "employees": [
        {
            "id": 5,
            "name": "Мария Сидорова",
            "role": "caregiver",
            "is_available": true,
            "conflicting_tasks_count": 0
        },
        {
            "id": 6,
            "name": "Анна Иванова",
            "role": "caregiver",
            "is_available": false,
            "conflicting_tasks_count": 2
        }
    ],
    "time_slot": {
        "start_at": "2024-01-15 08:00:00",
        "end_at": "2024-01-15 08:30:00"
    }
}
```

---

#### GET /api/v1/route-sheet/{id}

Получить одну задачу по ID.

**Пример ответа:**

```json
{
    "id": 1,
    "patient_id": 1,
    "template_id": 1,
    "assigned_to": 5,
    "title": "Смена подгузников",
    "start_at": "2024-01-15T08:00:00.000000Z",
    "end_at": "2024-01-15T08:30:00.000000Z",
    "original_start_at": null,
    "original_end_at": null,
    "status": "pending",
    "priority": 1,
    "completed_at": null,
    "completed_by": null,
    "comment": null,
    "photos": null,
    "reschedule_reason": null,
    "is_rescheduled": false,
    "is_overdue": false,
    "patient": {...},
    "assigned_to": {...},
    "template": {...}
}
```

---

#### POST /api/v1/route-sheet

Создать одноразовую задачу (без шаблона).

**Тело запроса:**

```json
{
    "patient_id": 1,
    "title": "Визит врача",
    "start_at": "2024-01-15 10:00:00",
    "end_at": "2024-01-15 11:00:00",
    "assigned_to": 5,
    "priority": 2,
    "related_diary_key": null
}
```

| Поле | Тип | Обязательный | Описание |
|------|-----|--------------|----------|
| `patient_id` | integer | Да | ID подопечного |
| `title` | string | Да | Название задачи |
| `start_at` | datetime | Да | Время начала |
| `end_at` | datetime | Да | Время окончания |
| `assigned_to` | integer | Нет | ID сотрудника |
| `priority` | integer | Нет | Приоритет (0-10) |
| `related_diary_key` | string | Нет | Ключ дневника |

**Ответ:** `201 Created`

---

#### PUT /api/v1/route-sheet/{id}

Обновить задачу.

**Тело запроса:**

```json
{
    "title": "Обновлённое название",
    "start_at": "2024-01-15 11:00:00",
    "end_at": "2024-01-15 11:30:00",
    "assigned_to": 6,
    "priority": 3
}
```

> **Важно:** Можно обновить только задачи со статусом `pending`.

---

#### POST /api/v1/route-sheet/{id}/reschedule

Перенести задачу на другое время.

**Тело запроса:**

```json
{
    "start_at": "2024-01-15 14:00:00",
    "end_at": "2024-01-15 14:30:00",
    "reason": "Подопечный спал"
}
```

| Поле | Тип | Обязательный | Описание |
|------|-----|--------------|----------|
| `start_at` | datetime | Да | Новое время начала |
| `end_at` | datetime | Да | Новое время окончания |
| `reason` | string | Да | Причина переноса |

**Пример ответа:**

```json
{
    "id": 1,
    "title": "Смена подгузников",
    "start_at": "2024-01-15T14:00:00.000000Z",
    "end_at": "2024-01-15T14:30:00.000000Z",
    "original_start_at": "2024-01-15T08:00:00.000000Z",
    "original_end_at": "2024-01-15T08:30:00.000000Z",
    "reschedule_reason": "Подопечный спал",
    "rescheduled_by": 5,
    "rescheduled_at": "2024-01-15T07:45:00.000000Z",
    "is_rescheduled": true,
    "message": "Task rescheduled successfully"
}
```

---

#### POST /api/v1/route-sheet/{id}/complete

Отметить задачу как выполненную.

**Тело запроса (form-data для загрузки фото):**

| Поле | Тип | Обязательный | Описание |
|------|-----|--------------|----------|
| `comment` | string | Нет | Комментарий |
| `photos[]` | file | Нет | Фотографии (до 5 шт, макс 5MB) |
| `value` | object | Нет* | Значение измерения (для задач с `related_diary_key`) |
| `completed_at` | datetime | Нет | Фактическое время выполнения |

**Пример запроса (JSON):**

```json
{
    "comment": "Подопечный чувствует себя хорошо",
    "value": {
        "systolic": 120,
        "diastolic": 80
    },
    "completed_at": "2024-01-15 09:15:00"
}
```

> **Важно:** Если у задачи есть `related_diary_key` и передан `value`, автоматически создаётся запись в дневнике подопечного.

**Формат value для разных типов измерений:**

```json
// Артериальное давление
{"systolic": 120, "diastolic": 80}

// Температура
{"value": 36.6}

// Уровень сахара
{"value": 5.5}

// Сатурация
{"value": 98}
```

---

#### POST /api/v1/route-sheet/{id}/miss

Отметить задачу как невыполненную.

**Тело запроса:**

```json
{
    "reason": "У подопечного была высокая температура"
}
```

| Поле | Тип | Обязательный | Описание |
|------|-----|--------------|----------|
| `reason` | string | Да | Причина невыполнения |

> **Важно:** При отметке задачи как невыполненной отправляется критическое уведомление менеджеру организации.

---

#### DELETE /api/v1/route-sheet/{id}

Удалить задачу.

> **Ограничения:** Можно удалить только задачи со статусом `pending` или `cancelled`.

---

### Task Templates (Шаблоны задач)

#### GET /api/v1/task-templates

Получить список шаблонов для подопечного.

**Query параметры:**

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `patient_id` | integer | Да | ID подопечного |

---

#### GET /api/v1/task-templates/{id}

Получить один шаблон.

---

#### POST /api/v1/task-templates

Создать новый шаблон задачи.

**Тело запроса:**

```json
{
    "patient_id": 1,
    "title": "Смена подгузников",
    "assigned_to": 5,
    "days_of_week": [1, 2, 3, 4, 5],
    "time_ranges": [
        {"start": "08:00", "end": "08:30", "priority": 1},
        {"start": "14:00", "end": "14:30"},
        {"start": "20:00", "end": "20:30"}
    ],
    "start_date": "2024-01-01",
    "end_date": null,
    "is_active": true,
    "related_diary_key": null
}
```

| Поле | Тип | Обязательный | Описание |
|------|-----|--------------|----------|
| `patient_id` | integer | Да | ID подопечного |
| `title` | string | Да | Название задачи |
| `assigned_to` | integer | Нет | ID сотрудника по умолчанию |
| `days_of_week` | array | Нет | Дни недели [0-6]. Null = каждый день |
| `time_ranges` | array | Да | Временные диапазоны |
| `time_ranges.*.start` | string | Да | Время начала (HH:MM) |
| `time_ranges.*.end` | string | Да | Время окончания (HH:MM) |
| `time_ranges.*.assigned_to` | integer | Нет | Сотрудник для этого времени |
| `time_ranges.*.priority` | integer | Нет | Приоритет |
| `start_date` | date | Да | Дата начала действия |
| `end_date` | date | Нет | Дата окончания (null = бессрочно) |
| `is_active` | boolean | Нет | Активен ли шаблон |
| `related_diary_key` | string | Нет | Ключ дневника |

> **Важно:** При создании шаблона автоматически генерируются задачи на ближайшие 7 дней.

---

#### PUT /api/v1/task-templates/{id}

Обновить шаблон.

> **Важно:** При изменении `time_ranges` или `days_of_week` автоматически удаляются будущие pending-задачи и генерируются новые.

---

#### PATCH /api/v1/task-templates/{id}/toggle

Включить/выключить шаблон.

**Пример ответа:**

```json
{
    "message": "Template deactivated",
    "is_active": false
}
```

> **Поведение:**
> - При деактивации — удаляются все будущие pending-задачи шаблона
> - При активации — генерируются новые задачи на 7 дней

---

#### DELETE /api/v1/task-templates/{id}

Удалить шаблон.

> При удалении также удаляются все будущие pending-задачи, созданные из этого шаблона.

---

## Примеры использования

### Сценарий 1: Создание расписания для сиделки

```bash
# 1. Создать шаблон "Смена подгузников" на Пн-Пт, 3 раза в день
POST /api/v1/task-templates
{
    "patient_id": 1,
    "title": "Смена подгузников",
    "assigned_to": 5,
    "days_of_week": [1, 2, 3, 4, 5],
    "time_ranges": [
        {"start": "08:00", "end": "08:30"},
        {"start": "14:00", "end": "14:30"},
        {"start": "20:00", "end": "20:30"}
    ],
    "start_date": "2024-01-01"
}

# 2. Создать шаблон "Измерение давления" каждый день утром
POST /api/v1/task-templates
{
    "patient_id": 1,
    "title": "Измерение давления",
    "assigned_to": 5,
    "days_of_week": null,  // каждый день
    "time_ranges": [
        {"start": "09:00", "end": "09:15"}
    ],
    "start_date": "2024-01-01",
    "related_diary_key": "blood_pressure"
}
```

### Сценарий 2: Выполнение задачи сиделкой

```bash
# 1. Получить мои задачи на сегодня
GET /api/v1/route-sheet/my-tasks

# 2. Выполнить задачу с измерением давления
POST /api/v1/route-sheet/123/complete
{
    "comment": "Давление в норме",
    "value": {"systolic": 120, "diastolic": 80}
}
# → Автоматически создаётся запись в дневнике!
```

### Сценарий 3: Перенос задачи

```bash
# Сиделка переносит задачу, т.к. подопечный спит
POST /api/v1/route-sheet/123/reschedule
{
    "start_at": "2024-01-15 10:00:00",
    "end_at": "2024-01-15 10:30:00",
    "reason": "Подопечный спал"
}
```

### Сценарий 4: Назначение задачи сотруднику (пансионат)

```bash
# 1. Получить доступных сотрудников
GET /api/v1/route-sheet/available-employees?patient_id=1&start_at=2024-01-15 08:00:00&end_at=2024-01-15 08:30:00

# 2. Назначить задачу свободному сотруднику
PUT /api/v1/route-sheet/123
{
    "assigned_to": 6
}
```

---

## Права доступа

### Кто может создавать маршрутный лист (шаблоны и задачи)

| Роль | Может создавать | Условие |
|------|-----------------|---------|
| `client` | ✅ Да | Для своих подопечных |
| `manager` | ✅ Да | Для подопечных организации |
| `doctor` | ✅ Да | Для назначенных подопечных |
| `admin` | ✅ Да | Для всех |
| `caregiver` | ❌ Нет | — |

### Кто может выполнять задачи

| Роль | Может выполнять | Условие |
|------|-----------------|---------|
| `caregiver` | ✅ Да | Назначенные ему или без назначения |
| `doctor` | ✅ Да | Назначенные ему или без назначения |
| `client` | ✅ Да | Для своих подопечных |
| `manager` | ✅ Да | Для подопечных организации |
| `admin` | ✅ Да | Для всех |

### Особенности для разных типов организаций

**Патронажное агентство:**
- Задачи не привязаны к конкретному сотруднику при создании
- Любой сотрудник с доступом к дневнику может выполнить задачу

**Пансионат:**
- Задачи назначаются конкретному сотруднику
- Каждый сотрудник видит только свои задачи через `/my-tasks`
- При назначении проверяется занятость сотрудника

---

## Коды ошибок

| Код | Описание |
|-----|----------|
| `400` | Неверные параметры запроса |
| `401` | Не авторизован |
| `403` | Нет доступа к ресурсу |
| `404` | Ресурс не найден |
| `422` | Ошибка валидации |

### Примеры ошибок

```json
// 403 Forbidden
{
    "message": "You do not have permission to access this patient."
}

// 422 Validation Error
{
    "message": "Validation failed",
    "errors": {
        "start_at": ["The start at field is required."],
        "reason": ["The reason field is required."]
    }
}

// 422 Business Logic Error
{
    "message": "Only pending tasks can be completed."
}
```

---

## Уведомления

При изменении статуса задачи отправляются уведомления:

| Событие | Получатели |
|---------|------------|
| Задача выполнена | Менеджер, Клиент |
| Задача не выполнена | Менеджер (критическое), Клиент |
| Задача перенесена | Менеджер, Клиент |

---

## Автоматические процессы

### Генерация задач

Задачи генерируются автоматически из активных шаблонов. Рекомендуется настроить команду в scheduler:

```php
// app/Console/Kernel.php
$schedule->call(function () {
    $taskService = new \App\Services\TaskService();
    $taskService->generateForAllPatients(7);
})->dailyAt('00:01');
```

### Пометка просроченных задач

```php
$schedule->call(function () {
    $taskService = new \App\Services\TaskService();
    $taskService->markOverdueTasks();
})->hourly();
```

---

## Swagger документация

Полная интерактивная документация доступна по адресу:

```
GET /api/documentation
```
