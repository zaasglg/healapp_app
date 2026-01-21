/// Заголовок маршрутного листа
///
/// Отображает дату и навигацию по дням.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Заголовок маршрутного листа с навигацией по датам
class RouteSheetHeader extends StatelessWidget {
  /// Текущая выбранная дата
  final DateTime selectedDate;

  /// Callback при изменении даты
  final Function(DateTime date)? onDateChanged;

  /// Callback при открытии календаря
  final VoidCallback? onCalendarTap;

  const RouteSheetHeader({
    super.key,
    required this.selectedDate,
    this.onDateChanged,
    this.onCalendarTap,
  });

  String get _formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    if (selected == today) {
      return 'Сегодня';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      return 'Вчера';
    } else if (selected == today.add(const Duration(days: 1))) {
      return 'Завтра';
    }

    final months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${selectedDate.day} ${months[selectedDate.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Кнопка назад
          IconButton(
            onPressed: () {
              final newDate = selectedDate.subtract(const Duration(days: 1));
              onDateChanged?.call(newDate);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_left,
                color: Colors.grey.shade700,
                size: 24,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          // Дата
          GestureDetector(
            onTap: onCalendarTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppConfig.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppConfig.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formattedDate,
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppConfig.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Кнопка вперёд
          IconButton(
            onPressed: () {
              final newDate = selectedDate.add(const Duration(days: 1));
              onDateChanged?.call(newDate);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_right,
                color: Colors.grey.shade700,
                size: 24,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
