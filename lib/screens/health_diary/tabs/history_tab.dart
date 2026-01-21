/// Вкладка истории
///
/// Отображает историю заполнения показателей
/// за выбранный период.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../bloc/diary/diary_bloc.dart';
import '../../../bloc/diary/diary_state.dart';
import '../../../config/app_config.dart';
import '../../../utils/health_diary/health_diary_utils.dart';

/// Вкладка истории дневника
class HistoryTab extends StatefulWidget {
  /// ID дневника
  final int diaryId;

  const HistoryTab({super.key, required this.diaryId});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiaryBloc, DiaryState>(
      builder: (context, state) {
        if (state is DiaryLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DiaryLoaded) {
          return _buildContent(state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildContent(DiaryLoaded state) {
    return Column(
      children: [
        // Навигация по датам
        _buildDateNavigation(),

        // Список записей
        Expanded(child: _buildEntriesList(state)),
      ],
    );
  }

  Widget _buildDateNavigation() {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Назад
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_left, color: Colors.grey.shade700),
            ),
          ),

          // Дата
          GestureDetector(
            onTap: () => _selectDate(context),
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
                    isToday ? 'Сегодня' : _formatDate(_selectedDate),
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

          // Вперёд
          IconButton(
            onPressed: isToday
                ? null
                : () {
                    setState(() {
                      _selectedDate = _selectedDate.add(
                        const Duration(days: 1),
                      );
                    });
                  },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isToday ? Colors.grey.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_right,
                color: isToday ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(DiaryLoaded state) {
    final entries = state.diary.entries.where((e) {
      // Конвертируем UTC в локальное время для корректного сравнения дат
      final localRecordedAt = e.recordedAt.toLocal();
      return localRecordedAt.year == _selectedDate.year &&
          localRecordedAt.month == _selectedDate.month &&
          localRecordedAt.day == _selectedDate.day;
    }).toList();

    if (entries.isEmpty) {
      return _buildEmptyState();
    }

    // Группировка по времени (используем локальное время)
    final groupedEntries = <String, List<dynamic>>{};
    for (final entry in entries) {
      final localTime = entry.recordedAt.toLocal();
      final time = '${localTime.hour.toString().padLeft(2, '0')}:00';
      groupedEntries.putIfAbsent(time, () => []).add(entry);
    }

    final sortedTimes = groupedEntries.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedTimes.length,
      itemBuilder: (context, index) {
        final time = sortedTimes[index];
        final timeEntries = groupedEntries[time]!;
        return _buildTimeGroup(time, timeEntries);
      },
    );
  }

  Widget _buildTimeGroup(String time, List<dynamic> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок времени
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                time,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),

        // Записи
        ...entries.map((entry) => _buildEntryCard(entry)),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildEntryCard(dynamic entry) {
    final label = getIndicatorLabel(entry.parameterKey);
    final value = formatEntryValue(entry);
    final unit = getUnitForParameter(entry.parameterKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Иконка
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check, color: AppConfig.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value $unit',
                  style: GoogleFonts.firaSans(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Время
          Text(
            () {
              final localTime = entry.recordedAt.toLocal();
              return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
            }(),
            style: GoogleFonts.firaSans(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Нет записей',
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'За этот день нет данных',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]}';
  }
}
