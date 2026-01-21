/// Слот задачи в маршрутном листе
///
/// Отображает отдельную задачу с временем и статусом выполнения.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../config/app_config.dart';

/// Статус задачи
enum TaskStatus { pending, inProgress, completed, missed }

/// Модель задачи маршрутного листа
class RouteTaskData {
  final int id;
  final String title;
  final String? description;
  final TimeOfDay startTime;
  final TimeOfDay? endTime;
  final TaskStatus status;
  final String? completedBy;
  final DateTime? completedAt;

  RouteTaskData({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.status = TaskStatus.pending,
    this.completedBy,
    this.completedAt,
  });

  String get timeRange {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    if (endTime != null) {
      final end =
          '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
      return '$start — $end';
    }
    return start;
  }
}

/// Виджет слота задачи
class TaskSlot extends StatelessWidget {
  /// Данные задачи
  final RouteTaskData task;

  /// Callback при нажатии
  final VoidCallback? onTap;

  /// Callback при выполнении
  final VoidCallback? onComplete;

  /// Показывать ли кнопку выполнения
  final bool showCompleteButton;

  const TaskSlot({
    super.key,
    required this.task,
    this.onTap,
    this.onComplete,
    this.showCompleteButton = true,
  });

  Color get _statusColor {
    switch (task.status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.missed:
        return Colors.red;
    }
  }

  IconData get _statusIcon {
    switch (task.status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.inProgress:
        return Icons.play_circle_outline;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.missed:
        return Icons.cancel_outlined;
    }
  }

  String get _statusText {
    switch (task.status) {
      case TaskStatus.pending:
        return 'Ожидает';
      case TaskStatus.inProgress:
        return 'В процессе';
      case TaskStatus.completed:
        return 'Выполнено';
      case TaskStatus.missed:
        return 'Пропущено';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.status == TaskStatus.completed
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Индикатор времени
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(_statusIcon, color: _statusColor, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    task.timeRange,
                    style: GoogleFonts.firaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Информация о задаче
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.firaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                      decoration: task.status == TaskStatus.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      style: GoogleFonts.firaSans(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusText,
                          style: GoogleFonts.firaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _statusColor,
                          ),
                        ),
                      ),
                      if (task.completedBy != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Выполнил: ${task.completedBy}',
                            style: GoogleFonts.firaSans(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Кнопка выполнения
            if (showCompleteButton && task.status == TaskStatus.pending)
              IconButton(
                onPressed: onComplete,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConfig.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.check,
                    color: AppConfig.primaryColor,
                    size: 20,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}
