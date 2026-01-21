/// Утилиты для работы с показателями дневника здоровья
///
/// Содержит функции для получения меток, единиц измерения,
/// описаний и типов показателей.

import 'diary_constants.dart';

/// Получить человекочитаемое название показателя по ключу API
String getIndicatorLabel(String key) {
  const labels = {
    'blood_pressure': 'Давление',
    'temperature': 'Температура',
    'pulse': 'Пульс',
    'saturation': 'Сатурация',
    'oxygen_saturation': 'Сатурация',
    'respiratory_rate': 'Частота дыхания',
    'diaper_change': 'Смена подгузников',
    'walk': 'Прогулка',
    'skin_moisturizing': 'Увлажнение кожи',
    'medication': 'Приём лекарств',
    'feeding': 'Кормление',
    'meal': 'Прием пищи',
    'fluid_intake': 'Выпито жидкости',
    'urine_output': 'Выделено мочи',
    'urine_color': 'Цвет мочи',
    'urine': 'Выделение мочи',
    'defecation': 'Дефекация',
    'hygiene': 'Гигиена',
    'cognitive_games': 'Когнитивные игры',
    'vitamins': 'Приём витаминов',
    'sleep': 'Сон',
    'pain_level': 'Уровень боли',
    'sugar_level': 'Уровень сахара',
    'blood_sugar': 'Уровень сахара',
    'nausea': 'Тошнота',
    'vomiting': 'Рвота',
    'dyspnea': 'Одышка',
    'itching': 'Зуд',
    'cough': 'Кашель',
    'dry_mouth': 'Сухость во рту',
    'hiccup': 'Икота',
    'taste_disorder': 'Нарушение вкуса',
    'care_procedure': 'Процедура ухода',
  };
  final mappedLabel = labels[key];
  if (mappedLabel != null) {
    return mappedLabel;
  }

  final normalizedKey = key.replaceAll('_', ' ').trim();
  if (normalizedKey.isEmpty) {
    return key;
  }
  return '${normalizedKey[0].toUpperCase()}${normalizedKey.substring(1)}';
}

/// Получить единицу измерения для параметра
String getUnitForParameter(String key) {
  switch (key) {
    case 'temperature':
      return '°C';
    case 'weight':
      return 'кг';
    case 'saturation':
    case 'oxygen_saturation':
      return '%';
    case 'blood_sugar':
    case 'sugar_level':
      return 'ммоль/л';
    case 'pulse':
      return 'уд/мин';
    case 'respiratory_rate':
      return 'дв/мин';
    default:
      return '';
  }
}

/// Получить описание показателя для модального окна
String getIndicatorDescription(String key) {
  const descriptions = {
    'skin_moisturizing': 'Отметьте, было ли увлажнение кожи.',
    'hygiene': 'Отметьте, была ли проведена гигиена.',
    'defecation': 'Отметьте, была ли дефекация.',
    'nausea': 'Отметьте, была ли тошнота.',
    'vomiting': 'Отметьте, была ли рвота.',
    'dyspnea': 'Отметьте, была ли одышка.',
    'itching': 'Отметьте, был ли зуд.',
    'cough': 'Отметьте, был ли кашель.',
    'dry_mouth': 'Отметьте, была ли сухость во рту.',
    'hiccup': 'Отметьте, была ли икота.',
    'taste_disorder': 'Отметьте, было ли нарушение вкуса.',
    'feeding': 'Опишите, что ели и как прошёл приём пищи.',
    'cognitive_games': 'Опишите, какие игры проводились.',
    'walk': 'Укажите время начала и окончания прогулки.',
    'sleep': 'Укажите время отхода ко сну и пробуждения.',
    'diaper_change': 'Укажите время смены подгузника.',
    'blood_pressure': 'Введите показатель артериального давления.',
    'temperature': 'Введите температуру тела.',
    'pulse': 'Введите частоту пульса.',
    'saturation': 'Введите уровень сатурации.',
    'respiratory_rate': 'Введите частоту дыхания.',
    'pain_level': 'Оцените уровень боли от 0 до 10.',
    'sugar_level': 'Введите уровень сахара в крови.',
    'fluid_intake': 'Введите количество выпитой жидкости.',
    'urine_output': 'Введите количество выделенной мочи.',
    'medication': 'Выберите лекарства для приёма.',
    'vitamins': 'Выберите витамины для приёма.',
    'urine_color': 'Выберите цвет мочи.',
  };
  return descriptions[key] ?? '';
}

/// Получить подсказку для текстового ввода
String getIndicatorHint(String key) {
  const hints = {
    'feeding': 'Например: завтрак — овсянка, чай',
    'cognitive_games': 'Например: шахматы, чтение книги',
    'medication': 'Например: парацетамол',
    'vitamins': 'Например: витамин D',
  };
  return hints[key] ?? '';
}

/// Определить тип параметра (physical или care)
String getParameterType(String key) {
  if (physicalTypeKeys.contains(key)) return 'physical';
  return 'care';
}

/// Получить ключ показателя из названия задачи
String getKeyFromTitle(String title) {
  return titleToKeyMap[title] ?? 'walk';
}

/// Получить категорию для параметра
String getCategoryForParameter(String key) {
  switch (key) {
    case 'bath':
    case 'diaper_change':
    case 'nail_care':
    case 'hair_care':
      return 'Гигиена';
    case 'temperature':
    case 'weight':
    case 'height':
    case 'pulse':
    case 'blood_pressure':
    case 'saturation':
    case 'oxygen_saturation':
    case 'respiratory_rate':
      return 'Физические показатели';
    case 'urine':
    case 'stool':
    case 'vomit':
      return 'Выделения';
    case 'sleep':
    case 'nap':
      return 'Сон';
    case 'feeding':
    case 'breastfeeding':
    case 'bottle':
    case 'solid_food':
      return 'Питание';
    case 'walk':
    case 'activity':
      return 'Активность';
    default:
      return 'Другое';
  }
}

/// Получить последнее значение показателя из дневника
String? getLastValue(dynamic diary, String key) {
  if (diary == null) return null;

  // Фильтруем записи по ключу
  final entries = diary.entries.where((e) => e.parameterKey == key).toList();
  if (entries.isEmpty) return null;

  // Сортируем по дате (свежие первые)
  entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  final value = entries.first.value;

  // Обработка Map значений (например, {value: "Парацетамол"})
  if (value is Map) {
    // Для давления
    if (key == 'blood_pressure') {
      dynamic bpValue = value;
      // Если значение вложено в {value: {...}}, извлекаем его
      if (bpValue.containsKey('value') && bpValue['value'] is Map) {
        bpValue = bpValue['value'];
      }
      final systolic = bpValue['systolic'] ?? bpValue['sys'] ?? 0;
      final diastolic = bpValue['diastolic'] ?? bpValue['dia'] ?? 0;
      return '$systolic/$diastolic';
    }

    // Для других Map - извлекаем вложенное значение
    if (value.containsKey('value')) {
      final innerValue = value['value'];
      if (innerValue is bool) {
        return innerValue ? 'Было' : 'Не было';
      }
      return innerValue?.toString() ?? '—';
    }

    // Если структура неизвестна, пытаемся вывести первое значение
    return value.values.firstOrNull?.toString() ?? '—';
  }

  // Обработка булевых значений
  if (value is bool) {
    return value ? 'Было' : 'Не было';
  }

  // Обработка числовых булевых представлений
  if (value is num) {
    if (value == 1) return 'Было';
    if (value == 0) return 'Не было';
  }

  return value?.toString();
}

/// Форматирует значение записи для отображения в истории
String formatEntryValue(dynamic entry) {
  final value = entry.value;
  final parameterKey = entry.parameterKey;

  // Обработка булевых значений
  if (value is bool) {
    return value ? 'Было' : 'Не было';
  }

  // Обработка числовых булевых представлений (1/0)
  if (value is num) {
    if (value == 1) return 'Было';
    if (value == 0) return 'Не было';
  }

  // Обработка Map (например {value: false} или blood_pressure)
  if (value is Map) {
    // Для blood_pressure
    if (parameterKey == 'blood_pressure') {
      dynamic bpValue = value;
      // Если значение вложено в {value: {...}}, извлекаем его
      if (bpValue.containsKey('value') && bpValue['value'] is Map) {
        bpValue = bpValue['value'];
      }
      final systolic = bpValue['systolic'] ?? bpValue['sys'] ?? 0;
      final diastolic = bpValue['diastolic'] ?? bpValue['dia'] ?? 0;
      return '$systolic/$diastolic мм рт.ст.';
    }

    // Для других Map значений - проверяем вложенное value
    if (value.containsKey('value')) {
      final innerValue = value['value'];
      if (innerValue is bool) {
        return innerValue ? 'Было' : 'Не было';
      }
      return innerValue?.toString() ?? '—';
    }

    // Попытка вывести все значения из Map
    return value.values.map((v) => v.toString()).join(', ');
  }

  // Обработка строк "true"/"false"
  if (value is String) {
    final lowerValue = value.toLowerCase();
    if (lowerValue == 'true') return 'Было';
    if (lowerValue == 'false') return 'Не было';
    if (value == '1') return 'Было';
    if (value == '0') return 'Не было';
  }

  // Стандартное отображение с единицами измерения
  String displayValue = value?.toString() ?? '—';
  final unit = getUnitForParameter(parameterKey);
  if (unit.isNotEmpty && displayValue != '—') {
    displayValue = '$displayValue $unit';
  }

  return displayValue;
}
