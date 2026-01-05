# API: Загрузить аватар

## Endpoint

```http
POST /api/v1/auth/avatar
```

## Описание

Загружает или обновляет аватар текущего аутентифицированного пользователя. Если у пользователя уже есть аватар, старый файл автоматически удаляется.

## Аутентификация

✅ **Требуется**: Bearer Token (Laravel Sanctum)

## Заголовки запроса

```
Authorization: Bearer {access_token}
Content-Type: multipart/form-data
Accept: application/json
```

## Тело запроса

### Параметры

| Параметр | Тип | Обязательный | Описание |
|----------|-----|--------------|----------|
| `avatar` | file | ✅ | Файл изображения (jpeg, png, jpg, gif, максимум 5MB) |

### Ограничения

- **Типы файлов**: `jpeg`, `png`, `jpg`, `gif`
- **Максимальный размер**: 5MB (5120 KB)

### Пример запроса

```
Content-Type: multipart/form-data

avatar: [файл изображения]
```

## Пример запроса

### cURL

```bash
curl -X POST https://api.sistemizdorovya.ru/api/v1/auth/avatar \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -F "avatar=@/path/to/image.jpg"
```

## Успешный ответ

### Статус: `200 OK`

### Структура ответа

```json
{
  "message": "Аватар загружен",
  "user": {
    "id": 1,
    "first_name": "Иван",
    "last_name": "Иванов",
    "middle_name": "Петрович",
    "avatar": "https://api.sistemizdorovya.ru/storage/avatars/1/abc123def456.jpg",
    "phone": "79001234567",
    "type": "organization",
    "account_type": "pansionat",
    "role": "owner",
    "phone_verified_at": "2024-12-20T10:30:00.000000Z",
    "created_at": "2024-12-20T10:00:00.000000Z",
    "updated_at": "2024-12-23T10:30:00.000000Z",
    "organization": {
      "id": 1,
      "name": "Пансионат 'Забота'",
      "type": "boarding_house"
    }
  }
}
```

### Описание полей

| Поле | Тип | Описание |
|------|-----|----------|
| `message` | string | Сообщение об успешной загрузке |
| `user` | object | Обновлённая информация о пользователе |
| `user.avatar` | string | URL загруженного аватара |

## Ошибки

### 401 Unauthorized

Токен отсутствует, недействителен или истёк.

```json
{
  "message": "Unauthenticated."
}
```

### 422 Unprocessable Entity

Ошибка валидации файла.

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "avatar": [
      "Поле avatar обязательно для заполнения."
    ]
  }
}
```

Или:

```json
{
  "message": "The given data was invalid.",
  "errors": {
    "avatar": [
      "Файл avatar должен быть изображением.",
      "Файл avatar должен быть одним из следующих типов: jpeg, png, jpg, gif.",
      "Файл avatar не должен быть больше 5120 килобайт."
    ]
  }
}
```

## Процесс загрузки

```
┌─────────────────────────────────┐
│  POST /api/v1/auth/avatar       │
│  multipart/form-data            │
│  avatar: [файл]                 │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│   Валидация файла               │
│   - required                    │
│   - image                       │
│   - mimes: jpeg,png,jpg,gif     │
│   - max: 5120 KB                │
└────────────────┬────────────────┘
                 │
            Валиден?
         ┌───────┴───────┐
         ▼               ▼
       ┌─────┐        ┌──────┐
       │ Нет │        │  Да  │
       └──┬──┘        └───┬──┘
          │               │
          ▼               ▼
┌────────────────┐ ┌─────────────────────────┐
│ Ошибка 422:    │ │ Проверка старого аватара│
│ Валидация      │ │ Если есть - удалить     │
│ не пройдена    │ └───────────┬─────────────┘
└────────────────┘             │
                               ▼
                   ┌─────────────────────────┐
                   │ Сохранение файла        │
                   │ storage/app/public/     │
                   │   avatars/{user_id}/    │
                   └───────────┬─────────────┘
                               │
                               ▼
                   ┌─────────────────────────┐
                   │ Обновление user.avatar  │
                   │ = Storage::url($path)   │
                   └───────────┬─────────────┘
                               │
                               ▼
                   ┌─────────────────────────┐
                   │ Response:               │
                   │ {                      │
                   │   "message": "...",    │
                   │   "user": {...}        │
                   │ }                      │
                   └─────────────────────────┘
```

### cURL

```bash
curl -X GET https://api.healapp.kz/api/v1/auth/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/json"
```

## Успешный ответ

### Статус: `200 OK`

### Структура ответа

```json
{
  "id": 1,
  "first_name": "Иван",
  "last_name": "Иванов",
  "middle_name": "Петрович",
  "avatar": "http://api.healapp.kz/storage/avatars/1/abc123.jpg",
  "phone": "79001234567",
  "type": "organization",
  "account_type": "pansionat",
  "role": "owner",
  "phone_verified_at": "2024-12-20T10:30:00.000000Z",
  "created_at": "2024-12-20T10:00:00.000000Z",
  "updated_at": "2024-12-23T08:30:00.000000Z",
  "organization": {
    "id": 1,
    "name": "Пансионат 'Забота'",
    "type": "boarding_house"
  }
}
```


## Примечания

- Старый аватар автоматически удаляется при загрузке нового
- Файлы сохраняются в `storage/app/public/avatars/{user_id}/`
- URL аватара формируется как `https://api.sistemizdorovya.ru/storage/avatars/{user_id}/{filename}`
- Максимальный размер файла: 5MB
- Поддерживаемые форматы: JPEG, PNG, JPG, GIF
- После успешной загрузки поле `avatar` в ответе содержит полный URL к изображению
- Убедитесь, что симлинк `storage` создан: `php artisan storage:link`

