# Модальное окно для скачивания приложения

## Описание

Красивое модальное окно, которое показывается только веб-пользователям при открытии страницы дневника здоровья. Окно предлагает скачать мобильное приложение для лучшего опыта использования.

## Особенности

- ✅ **Только для веб-версии** - автоматически определяет платформу и показывается только в браузере
- ✅ **Запоминает выбор пользователя** - использует `FlutterSecureStorage` для сохранения состояния
- ✅ **Красивый дизайн** - градиентный фон, анимации, современный UI
- ✅ **Интеграция с магазинами** - кнопки для перехода в App Store и Google Play
- ✅ **Backdrop blur эффект** - размытие фона для лучшего визуального эффекта

## Как использовать

### 1. Интеграция в страницу

 окно уже Модальноеинтегрировано в `health_diary_page.dart`:

```dart
import '../widgets/download_app_modal.dart';

// В initState:
WidgetsBinding.instance.addPostFrameCallback((_) {
  DownloadAppModal.showIfWeb(context);
});
```

### 2. Настройка ссылок на магазины

Откройте файл `lib/widgets/download_app_modal.dart` и замените ссылки на реальные:

```dart
// TODO: Замените эти ссылки на реальные ссылки на ваше приложение
static const String _appStoreUrl = 'https://apps.apple.com/app/your-app-id';
static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=your.package.name';
```

**Пример для App Store:**
```dart
static const String _appStoreUrl = 'https://apps.apple.com/app/healapp/id1234567890';
```

**Пример для Google Play:**
```dart
static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.healapp.mobile';
```

### 3. Сброс состояния (для тестирования)

Если вы хотите снова увидеть модальное окно после того, как закрыли его, нужно очистить хранилище:

```dart
// Добавьте это в консоль разработчика или создайте отладочную кнопку:
const storage = FlutterSecureStorage();
await storage.delete(key: 'download_app_modal_dismissed');
```

## Дизайн

Модальное окно использует:
- **Градиент**: `#7DCAD6` → `#55ACBF` → `#4A9FB0`
- **Шрифт**: Fira Sans (через Google Fonts)
- **Иконки**: Material Icons
- **Эффекты**: Backdrop blur, тени, декоративные круги

## Поведение

1. **При первом открытии** - модалка показывается через 800ms после загрузки страницы
2. **При нажатии на кнопку магазина** - открывается ссылка и модалка больше не показывается
3. **При нажатии "Продолжить в браузере"** - модалка закрывается и больше не показывается
4. **При нажатии на X** - модалка закрывается и больше не показывается
5. **При клике вне модалки** - модалка закрывается, но может показаться снова при следующем посещении

## Кастомизация

### Изменить задержку показа

```dart
await Future.delayed(const Duration(milliseconds: 800)); // Измените значение
```

### Изменить цвета градиента

```dart
gradient: const LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF7DCAD6), // Ваш цвет 1
    Color(0xFF55ACBF), // Ваш цвет 2
    Color(0xFF4A9FB0), // Ваш цвет 3
  ],
),
```

### Изменить текст

Все тексты находятся в методе `build()` виджета `DownloadAppModal`:

```dart
Text('Скачайте мобильное приложение', ...) // Заголовок
Text('Для лучшего опыта работы...', ...) // Описание
_buildFeature(text: 'Push-уведомления...') // Преимущества
```

## Зависимости

Модальное окно использует следующие пакеты (уже установлены в проекте):

- `flutter_secure_storage` - для сохранения состояния
- `url_launcher` - для открытия ссылок на магазины
- `google_fonts` - для шрифта Fira Sans

## Скриншот

![Download App Modal](../../../.gemini/antigravity/brain/ab6f280b-9dc6-48cb-8c72-99193e6fd328/download_app_modal_1768849137661.png)
