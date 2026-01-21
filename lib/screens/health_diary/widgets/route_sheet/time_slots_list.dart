/// Список временных слотов
///
/// Отображает список задач маршрутного листа,
/// сгруппированных по времени.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';
import 'task_slot.dart';

/// Группа задач по времени
class TimeSlotGroup {
  final String timeLabel;
  final List<RouteTaskData> tasks;

  TimeSlotGroup({required this.timeLabel, required this.tasks});
}

/// Список временных слотов
class TimeSlotslist extends StatelessWidget {
  /// Группы задач по времени
  final List<TimeSlotGroup> groups;

  /// Callback при нажатии на задачу
  final Function(RouteTaskData task)? onTaskTap;

  /// Callback при выполнении задачи
  final Function(RouteTaskData task)? onTaskComplete;

  /// Показывать ли кнопки выполнения
  final bool showCompleteButtons;

  const TimeSlotslist({
    super.key,
    required this.groups,
    this.onTaskTap,
    this.onTaskComplete,
    this.showCompleteButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildTimeGroup(group);
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Нет задач на сегодня',
            style: GoogleFonts.firaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Задачи появятся в маршрутном листе',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGroup(TimeSlotGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок группы
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                group.timeLabel,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${group.tasks.length}',
                  style: GoogleFonts.firaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Список задач
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: group.tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = group.tasks[index];
            return TaskSlot(
              task: task,
              onTap: () => onTaskTap?.call(task),
              onComplete: () => onTaskComplete?.call(task),
              showCompleteButton: showCompleteButtons,
            );
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
