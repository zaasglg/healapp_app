/// Утилиты для работы с показателями здоровья
///
/// Содержит константы и методы для преобразования ключей API
/// в человекочитаемые названия, описания и единицы измерения.
library;

/// Получить человекочитаемое название показателя по ключу API
String getIndicatorLabel(String key) {
  const labels = {
    'blood_pressure': 'Давление',
    'temperature': 'Температура',
    'pulse': 'Пульс',
    'saturation': 'Сатурация',
    'respiratory_rate': 'Частота дыхания',
    'diaper_change': 'Смена подгузников',
    'walk': 'Прогулка',
    'skin_moisturizing': 'Увлажнение кожи',
    'medication': 'Приём лекарств',
    'feeding': 'Кормление',
    'fluid_intake': 'Выпито жидкости',
    'urine_output': 'Выделено мочи',
    'urine_color': 'Цвет мочи',
    'defecation': 'Дефекация',
    'hygiene': 'Гигиена',
    'cognitive_games': 'Когнитивные игры',
    'vitamins': 'Приём витаминов',
    'sleep': 'Сон',
    'pain_level': 'Уровень боли',
    'sugar_level': 'Уровень сахара',
    'nausea': 'Тошнота',
    'vomiting': 'Рвота',
    'dyspnea': 'Одышка',
    'itching': 'Зуд',
    'cough': 'Кашель',
    'dry_mouth': 'Сухость во рту',
    'hiccup': 'Икота',
    'taste_disorder': 'Нарушение вкуса',
  };
  return labels[key] ?? key;
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

/// Получить подсказку (hint) для текстового ввода
String getIndicatorHint(String key) {
  const hints = {
    'feeding': 'Например: завтрак — овсянка, чай',
    'cognitive_games': 'Например: шахматы, чтение книги',
  };
  return hints[key] ?? '';
}

/// Получить единицу измерения показателя
String getMeasurementUnit(String key) {
  const units = {
    'blood_pressure': 'мм рт. ст.',
    'temperature': '°C',
    'pulse': 'уд/мин',
    'saturation': '%',
    'respiratory_rate': 'в мин',
    'pain_level': 'от 0 до 10',
    'sugar_level': 'ммоль/л',
    'fluid_intake': 'мл',
    'urine_output': 'мл',
  };
  return units[key] ?? '';
}

/// Параметры с булевым значением (Было/Не было)
const List<String> booleanParams = [
  'skin_moisturizing',
  'hygiene',
  'defecation',
  'nausea',
  'vomiting',
  'dyspnea',
  'itching',
  'cough',
  'dry_mouth',
  'hiccup',
  'taste_disorder',
];

/// Параметры с текстовым вводом
const List<String> textParams = ['feeding', 'cognitive_games'];

/// Параметры с диапазоном времени
const List<String> timeRangeParams = ['walk', 'sleep'];

/// Параметры с выбором времени
const List<String> timeParams = ['diaper_change'];

/// Параметры с вводом измерения
const List<String> measurementParams = [
  'blood_pressure',
  'temperature',
  'pulse',
  'saturation',
  'respiratory_rate',
  'pain_level',
  'sugar_level',
  'fluid_intake',
  'urine_output',
];

/// Определить тип ввода для показателя
IndicatorInputType getIndicatorInputType(String key) {
  if (booleanParams.contains(key)) return IndicatorInputType.boolean;
  if (textParams.contains(key)) return IndicatorInputType.text;
  if (timeRangeParams.contains(key)) return IndicatorInputType.timeRange;
  if (timeParams.contains(key)) return IndicatorInputType.time;
  if (measurementParams.contains(key)) return IndicatorInputType.measurement;
  if (key == 'medication' || key == 'vitamins')
    return IndicatorInputType.medication;
  if (key == 'urine_color') return IndicatorInputType.urineColor;
  return IndicatorInputType.text;
}

/// Тип правила ввода для показателя
enum IndicatorInputType {
  boolean,
  text,
  time,
  timeRange,
  measurement,
  medication,
  urineColor,
}
