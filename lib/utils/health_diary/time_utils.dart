/// Утилиты для работы со временем в дневнике здоровья
///
/// Содержит функции для расчёта времени до следующего заполнения,
/// форматирования времени и работы с датами.

/// Получить текст таймера до следующего заполнения
String getDisplayTime(List<String> times) {
  if (times.isEmpty) return 'Выберите время';

  final now = DateTime.now();
  final currentMinutes = now.hour * 60 + now.minute;
  final currentSeconds = now.second;

  final sortedTimes = List<String>.from(times)..sort();

  int? nextTimeMinutes;

  // Ищем ближайшее время сегодня
  for (final time in sortedTimes) {
    final parts = time.split(':');
    if (parts.length < 2) continue;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final tMinutes = hour * 60 + minute;

    // Включаем текущую минуту, если секунды меньше 50
    // Это даёт время пользователю увидеть "через 0:00" перед срабатыванием
    if (tMinutes > currentMinutes ||
        (tMinutes == currentMinutes && currentSeconds < 50)) {
      nextTimeMinutes = tMinutes;
      break;
    }
  }

  int diffMinutes;

  if (nextTimeMinutes != null) {
    // Время сегодня
    diffMinutes = nextTimeMinutes - currentMinutes;
  } else {
    // Берем первое время завтра
    final firstParts = sortedTimes.first.split(':');
    final firstMinutes =
        int.parse(firstParts[0]) * 60 + int.parse(firstParts[1]);
    diffMinutes = (24 * 60 - currentMinutes) + firstMinutes;
  }

  final hours = diffMinutes ~/ 60;
  final minutes = diffMinutes % 60;

  if (diffMinutes == 0) {
    return 'Заполнить сейчас!';
  } else {
    return 'Заполнить через: ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}

/// Нормализовать формат времени (7:00 -> 07:00)
String normalizeTime(String time) {
  final parts = time.trim().split(':');
  if (parts.length != 2) return time;

  final hour = parts[0].padLeft(2, '0');
  final minute = parts[1].padLeft(2, '0');
  return '$hour:$minute';
}

/// Форматировать TimeOfDay в строку HH:mm
String formatTimeOfDay(dynamic timeOfDay) {
  return '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
}

/// Получить количество секунд до следующей минуты
int getSecondsUntilNextMinute() {
  final now = DateTime.now();
  return 60 - now.second;
}
