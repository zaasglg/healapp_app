import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../bloc/route_sheet/route_sheet_cubit.dart';
import '../../../bloc/route_sheet/route_sheet_state.dart';
import '../../../config/app_config.dart';
import '../widgets/inline_calendar.dart';

/// Таб "Маршрутный лист" для страницы дневника здоровья
class RouteSheetTab extends StatefulWidget {
  final VoidCallback onAddManipulations;

  const RouteSheetTab({super.key, required this.onAddManipulations});

  @override
  State<RouteSheetTab> createState() => _RouteSheetTabState();
}

class _RouteSheetTabState extends State<RouteSheetTab> {
  bool _isDatePickerExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RouteSheetCubit, RouteSheetState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.errorMessage != null) {
          return _buildErrorState(context, state.errorMessage!);
        }

        final tasksForDate = state.getTasksForDate(state.selectedDate);

        if (!state.hasTasks) {
          return _buildEmptyState(context);
        }

        return _buildTasksView(context, state, tasksForDate);
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.firaSans(
              fontSize: 16,
              color: Colors.red.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<RouteSheetCubit>().loadRouteSheet();
            },
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Маршрутный лист показывает, какие манипуляции нужно выполнять с подопечным, когда и с какой периодичностью (ежедневно, раз в неделю). Можно составить вручную или воспользоваться ИИ, который предложит готовый вариант на основе дневника динамики ухода. С маршрутным листом легко согласовать, изменить и отслеживать выполнение всех процедур.',
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Настроить маршрутный лист',
              style: GoogleFonts.firaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Добавьте манипуляции вручную или с помощью ИИ',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: widget.onAddManipulations,
                    child: Text(
                      'Добавить',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      // TODO: Implement AI add
                    },
                    child: Text(
                      'Добавить с ИИ',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksView(
    BuildContext context,
    RouteSheetState state,
    List<RouteSheetTask> tasksForDate,
  ) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'НАЖМИТЕ, ЧТОБЫ ВЫБРАТЬ ДАТУ',
                  style: GoogleFonts.firaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isDatePickerExpanded = !_isDatePickerExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppConfig.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE, d MMMM y',
                            'ru',
                          ).format(state.selectedDate),
                          style: GoogleFonts.firaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: AppConfig.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isDatePickerExpanded) ...[
                  const SizedBox(height: 16),
                  InlineCalendar(
                    initialDate: state.selectedDate,
                    onDateSelected: (date) {
                      context.read<RouteSheetCubit>().setSelectedDate(date);
                      setState(() {
                        _isDatePickerExpanded = false;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          // Summary
          if (state.summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSummary(state.summary!),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Задачи на ${DateFormat('d MMMM', 'ru').format(state.selectedDate)}',
                    style: GoogleFonts.firaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: tasksForDate.isEmpty
                        ? Center(
                            child: Text(
                              'Нет задач на эту дату',
                              style: GoogleFonts.firaSans(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : _buildTimeSlots(context, tasksForDate),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: widget.onAddManipulations,
                      child: Text(
                        'Добавить задачу',
                        style: GoogleFonts.firaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(TaskSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Всего', summary.total, Colors.grey.shade700),
          _buildSummaryItem('Ожидает', summary.pending, Colors.blue),
          _buildSummaryItem('Выполнено', summary.completed, Colors.green),
          _buildSummaryItem('Пропущено', summary.missed, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: GoogleFonts.firaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.firaSans(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlots(BuildContext context, List<RouteSheetTask> tasks) {
    // Sort tasks by start time
    final sortedTasks = List<RouteSheetTask>.from(tasks)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return ListView.builder(
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return _buildTaskCard(context, task);
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, RouteSheetTask task) {
    Color statusColor;
    IconData statusIcon;

    switch (task.status) {
      case TaskStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TaskStatus.missed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case TaskStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        break;
      case TaskStatus.pending:
        statusColor = task.isOverdue ? Colors.orange : AppConfig.primaryColor;
        statusIcon = task.isOverdue ? Icons.warning : Icons.circle_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key('task_${task.id}'),
        direction: task.status == TaskStatus.pending
            ? DismissDirection.horizontal
            : DismissDirection.none,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.check, color: Colors.white),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.close, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            // Complete task
            await context.read<RouteSheetCubit>().completeTask(taskId: task.id);
            return false; // Don't remove from list
          } else {
            // Show miss dialog
            final reason = await _showMissReasonDialog(context);
            if (reason != null) {
              await context.read<RouteSheetCubit>().missTask(
                taskId: task.id,
                reason: reason,
              );
            }
            return false;
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: GoogleFonts.firaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                        decoration: task.status == TaskStatus.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.timeRange,
                      style: GoogleFonts.firaSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (task.isRescheduled) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Перенесено',
                            style: GoogleFonts.firaSans(
                              fontSize: 11,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (task.status == TaskStatus.pending)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  onSelected: (value) async {
                    switch (value) {
                      case 'complete':
                        await context.read<RouteSheetCubit>().completeTask(
                          taskId: task.id,
                        );
                        break;
                      case 'reschedule':
                        _showRescheduleDialog(context, task);
                        break;
                      case 'miss':
                        final reason = await _showMissReasonDialog(context);
                        if (reason != null) {
                          await context.read<RouteSheetCubit>().missTask(
                            taskId: task.id,
                            reason: reason,
                          );
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Выполнено'),
                    ),
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: Text('Перенести'),
                    ),
                    const PopupMenuItem(
                      value: 'miss',
                      child: Text('Не выполнено'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showMissReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Причина невыполнения'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Укажите причину'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(BuildContext context, RouteSheetTask task) {
    // TODO: Implement reschedule dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Перенос задачи - в разработке')),
    );
  }
}
