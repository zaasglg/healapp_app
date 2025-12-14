# Примеры использования иконок

## Использование в коде

### 1. Простое изображение
```dart
import 'package:flutter/material.dart';
import '../utils/app_icons.dart';

Image.asset(AppIcons.logo)
```

### 2. Иконка с размером
```dart
Image.asset(
  AppIcons.profile,
  width: 24,
  height: 24,
)
```

### 3. Иконка в контейнере с настройками
```dart
Container(
  width: 48,
  height: 48,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Image.asset(
    AppIcons.add,
    fit: BoxFit.contain,
  ),
)
```

### 4. Использование в IconButton
```dart
IconButton(
  icon: Image.asset(AppIcons.settings),
  onPressed: () {},
)
```

### 5. Использование в кнопке
```dart
ElevatedButton.icon(
  icon: Image.asset(AppIcons.add, width: 20, height: 20),
  label: Text('Добавить'),
  onPressed: () {},
)
```

## Добавление новых иконок

1. Поместите файл иконки в соответствующую папку
2. Добавьте константу в `lib/utils/app_icons.dart`
3. Убедитесь, что путь указан правильно

## Форматы и размеры

### SVG (рекомендуется)
- Лучшее качество при любом масштабе
- Меньший размер файла
- Используйте пакет `flutter_svg` для отображения

### PNG
- `icon.png` - 24x24 px (1x)
- `icon@2x.png` - 48x48 px (2x)
- `icon@3x.png` - 72x72 px (3x)

Flutter автоматически выберет правильное разрешение для устройства.

