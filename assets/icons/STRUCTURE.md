# Структура иконок приложения HealApp

```
assets/icons/
├── common/          # Общие иконки приложения
│   ├── logo.png
│   ├── profile.png
│   └── settings.png
│
├── auth/            # Иконки для экранов аутентификации
│   ├── login.png
│   ├── register.png
│   └── verify.png
│
├── navigation/      # Иконки навигации и табов
│   ├── home.png
│   ├── diary.png
│   ├── market.png
│   ├── visits.png
│   └── roles.png
│
├── categories/      # Иконки категорий и ролей
│   ├── nursing_home.png
│   ├── agency.png
│   └── private_caregiver.png
│
└── actions/         # Иконки действий
    ├── add.png
    ├── edit.png
    ├── delete.png
    ├── save.png
    └── cancel.png
```

## Организация файлов

Все иконки организованы по категориям для удобной навигации:

- **common/** - базовые иконки, используемые в разных частях приложения
- **auth/** - иконки для экранов входа, регистрации, верификации
- **navigation/** - иконки для навигационного меню и табов
- **categories/** - иконки категорий и типов организаций
- **actions/** - иконки действий (CRUD операции)

## Соглашения об именовании

- Используйте snake_case для имен файлов: `nursing_home.png`
- Для файлов с разными разрешениями: `icon.png`, `icon@2x.png`, `icon@3x.png`
- Имена должны быть описательными и понятными

