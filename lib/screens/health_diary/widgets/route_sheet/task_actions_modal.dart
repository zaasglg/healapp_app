/// Модальное окно действий с задачей
///
/// Отображает детали задачи и действия: выполнить, отложить, пропустить.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'task_slot.dart';

/// Результат действия с задачей
enum TaskActionResult { complete, postpone, skip, cancel }

/// Показать модальное окно действий с задачей
Future<TaskActionResult?> showTaskActionsModal({
  required BuildContext context,
  required RouteTaskData task,
}) async {
  return showModalBottomSheet<TaskActionResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ручка
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Заголовок
              Text(
                task.title,
                style: GoogleFonts.firaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),

              // Время
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    task.timeRange,
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              if (task.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  task.description!,
                  style: GoogleFonts.firaSans(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Действия
              _ActionButton(
                icon: Icons.check_circle,
                label: 'Выполнено',
                color: Colors.green,
                onTap: () => Navigator.pop(ctx, TaskActionResult.complete),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.schedule,
                label: 'Отложить',
                color: Colors.orange,
                onTap: () => Navigator.pop(ctx, TaskActionResult.postpone),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.cancel_outlined,
                label: 'Пропустить',
                color: Colors.red,
                onTap: () => Navigator.pop(ctx, TaskActionResult.skip),
              ),
              const SizedBox(height: 16),

              // Кнопка отмены
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, TaskActionResult.cancel),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Отмена',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withOpacity(0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
