/// Константы для дневника здоровья
///
/// Содержит статические списки ключей показателей, разделённых по категориям,
/// а также типы параметров для API.

/// Ключи показателей ухода
const List<String> careIndicatorKeys = [
  'walk',
  'cognitive_games',
  'diaper_change',
  'hygiene',
  'skin_moisturizing',
  'meal',
  'medication',
  'vitamins',
  'sleep',
];

/// Ключи физических показателей
const List<String> physicalIndicatorKeys = [
  'temperature',
  'blood_pressure',
  'respiratory_rate',
  'pain_level',
  'oxygen_saturation',
  'blood_sugar',
];

/// Ключи показателей выделения
const List<String> excretionIndicatorKeys = ['urine', 'defecation'];

/// Булевые параметры (было/не было)
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
  'walk',
  'diaper_change',
];

/// Параметры с измерениями
const List<String> measurementParams = [
  'blood_pressure',
  'temperature',
  'pulse',
  'saturation',
  'oxygen_saturation',
  'respiratory_rate',
  'pain_level',
  'sugar_level',
  'blood_sugar',
  'fluid_intake',
  'urine_output',
];

/// Текстовые параметры
const List<String> textParams = [
  'feeding',
  'cognitive_games',
  'meal',
  'medication',
  'vitamins',
];

/// Параметры с диапазоном времени
const List<String> timeRangeParams = ['sleep'];

/// Параметры с выбором времени
const List<String> timeParams = ['diaper_change'];

/// Физические ключи для определения типа параметра
const List<String> physicalTypeKeys = [
  'blood_pressure',
  'temperature',
  'pulse',
  'blood_sugar',
  'weight',
  'oxygen_saturation',
  'urine_output',
  'fluid_intake',
];

/// Карта соответствия названия задачи → ключ показателя
const Map<String, String> titleToKeyMap = {
  'Прогулка': 'walk',
  'Давление': 'blood_pressure',
  'Температура': 'temperature',
  'Пульс': 'pulse',
  'Сатурация': 'saturation',
  'Частота дыхания': 'respiratory_rate',
  'Смена подгузников': 'diaper_change',
  'Увлажнение кожи': 'skin_moisturizing',
  'Приём лекарств': 'medication',
  'Кормление': 'feeding',
  'Прием пищи': 'meal',
  'Выпито жидкости': 'fluid_intake',
  'Выделено мочи': 'urine_output',
  'Выделение мочи': 'urine',
  'Дефекация': 'defecation',
  'Гигиена': 'hygiene',
  'Когнитивные игры': 'cognitive_games',
  'Приём витаминов': 'vitamins',
  'Сон': 'sleep',
  'Уровень боли': 'pain_level',
  'Уровень сахара': 'blood_sugar',
  'Тошнота': 'nausea',
  'Одышка': 'dyspnea',
  'Кашель': 'cough',
  'Икота': 'hiccup',
  'Рвота': 'vomiting',
  'Зуд': 'itching',
  'Сухость во рту': 'dry_mouth',
  'Нарушение вкуса': 'taste_disorder',
};

/// Метки дней недели для UI
const List<String> dayLabels = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

/// Соответствие индексов дней → API значения (0 = Воскресенье, 1 = Понедельник...)
const List<int> dayApiValues = [1, 2, 3, 4, 5, 6, 0];

/// Цвета мочи для выбора
const List<String> urineColors = [
  'Светло-жёлтый',
  'Жёлтый',
  'Тёмно-жёлтый',
  'Оранжевый',
  'Красноватый',
  'Коричневый',
];
