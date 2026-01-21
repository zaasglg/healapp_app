/// Вкладка маршрутного листа
///
/// Отображает задачи маршрутного листа на день.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/route_sheet/route_sheet_cubit.dart';
import '../../../bloc/route_sheet/route_sheet_state.dart' hide TaskStatus;
import '../widgets/route_sheet/route_sheet.dart';
import '../../../repositories/route_sheet_repository.dart' as repo;
import '../widgets/modals/measurement_modal.dart';
import '../widgets/modals/text_input_modal.dart';
import '../../../utils/app_logger.dart';

/// Вкладка маршрутного листа
class RouteSheetTab extends StatefulWidget {
  /// ID дневника
  final int diaryId;

  /// Может ли выполнять задачи
  final bool canComplete;

  const RouteSheetTab({
    super.key,
    required this.diaryId,
    this.canComplete = true,
  });

  @override
  State<RouteSheetTab> createState() => _RouteSheetTabState();
}

class _RouteSheetTabState extends State<RouteSheetTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RouteSheetCubit, RouteSheetState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.errorMessage != null) {
          return Center(child: Text(state.errorMessage!));
        }

        return _buildContent(state);
      },
    );
  }

  Widget _buildContent(RouteSheetState state) {
    final tasks = state.tasks;

    // Преобразуем задачи в формат для виджетов
    final taskData = tasks.map((task) {
      return RouteTaskData(
        id: task.id,
        title: task.title,
        description: task.comment,
        startTime: TimeOfDay(
          hour: task.startAt.hour,
          minute: task.startAt.minute,
        ),
        endTime: TimeOfDay(hour: task.endAt.hour, minute: task.endAt.minute),
        status: _mapStatus(task.status),
        completedBy: task.completedBy?.toString(),
        completedAt: task.completedAt,
      );
    }).toList();

    // Группируем по периодам дня
    final morningTasks = taskData.where(
      (t) => t.startTime.hour >= 6 && t.startTime.hour < 12,
    );
    final afternoonTasks = taskData.where(
      (t) => t.startTime.hour >= 12 && t.startTime.hour < 18,
    );
    final eveningTasks = taskData.where(
      (t) => t.startTime.hour >= 18 || t.startTime.hour < 6,
    );

    final groups = <TimeSlotGroup>[];
    if (morningTasks.isNotEmpty) {
      groups.add(
        TimeSlotGroup(
          timeLabel: 'Утро (6:00 — 12:00)',
          tasks: morningTasks.toList(),
        ),
      );
    }
    if (afternoonTasks.isNotEmpty) {
      groups.add(
        TimeSlotGroup(
          timeLabel: 'День (12:00 — 18:00)',
          tasks: afternoonTasks.toList(),
        ),
      );
    }
    if (eveningTasks.isNotEmpty) {
      groups.add(
        TimeSlotGroup(
          timeLabel: 'Вечер (18:00 — 6:00)',
          tasks: eveningTasks.toList(),
        ),
      );
    }

    // Статистика
    final stats = RouteSheetStats(
      total: taskData.length,
      completed: taskData.where((t) => t.status == TaskStatus.completed).length,
      pending: taskData.where((t) => t.status == TaskStatus.pending).length,
      missed: taskData.where((t) => t.status == TaskStatus.missed).length,
    );

    return RefreshIndicator(
      onRefresh: () async {
        context.read<RouteSheetCubit>().loadRouteSheet(date: _selectedDate);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Навигация по датам
            RouteSheetHeader(
              selectedDate: _selectedDate,
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
                context.read<RouteSheetCubit>().loadRouteSheet(date: date);
              },
              onCalendarTap: () => _selectDate(context),
            ),

            const SizedBox(height: 16),

            // Статистика
            RouteSheetSummary(stats: stats),

            const SizedBox(height: 24),

            // Список задач
            TimeSlotslist(
              groups: groups,
              showCompleteButtons: widget.canComplete,
              onTaskTap: (task) => _showTaskActions(task),
              onTaskComplete: (task) => _completeTask(task),
            ),
          ],
        ),
      ),
    );
  }

  TaskStatus _mapStatus(repo.TaskStatus status) {
    switch (status) {
      case repo.TaskStatus.completed:
        return TaskStatus.completed;
      case repo.TaskStatus.missed:
        return TaskStatus.missed;
      case repo.TaskStatus.cancelled:
        return TaskStatus.missed; // Map cancelled to missed for UI
      case repo.TaskStatus.pending:
        return TaskStatus.pending;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      context.read<RouteSheetCubit>().loadRouteSheet(date: picked);
    }
  }

  Future<void> _showTaskActions(RouteTaskData task) async {
    final result = await showTaskActionsModal(context: context, task: task);

    if (result == null || result == TaskActionResult.cancel) return;

    switch (result) {
      case TaskActionResult.complete:
        _completeTask(task);
        break;
      case TaskActionResult.postpone:
        // TODO: Реализовать отложить
        break;
      case TaskActionResult.skip:
        // TODO: Реализовать пропустить
        break;
      default:
        break;
    }
  }

  static const Map<String, String> _titleToKey = {
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
    'Сухость во рту': 'dry_mouth',
    'Икота': 'hiccup',
    'Рвота': 'vomiting',
    'Зуд': 'itching',
    'Нарушение вкуса': 'taste_disorder',
  };

  static const Set<String> _booleanKeys = {
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
    'urine',
  };

  Future<void> _completeTask(RouteTaskData task) async {
    final taskKey = _titleToKey[task.title] ?? 'walk';
    final cubit = context.read<RouteSheetCubit>();

    // Булевые параметры - просто отмечаем как выполненные
    if (_booleanKeys.contains(taskKey)) {
      await cubit.completeTask(taskId: task.id, value: {'value': true});
      return;
    }

    // Параметры с измерениями - показываем диалог ввода
    if (taskKey == 'blood_pressure') {
      final result = await showMeasurementModal(
        context: context,
        title: 'Давление',
        description: 'Введите значение измерения',
        unit: 'мм рт.ст.',
        key: 'blood_pressure',
      );
      if (result != null) {
        log.d('_completeTask: blood_pressure result.value = ${result.value}');
        // Для давления оборачиваем в {value: {systolic: X, diastolic: Y}}
        await cubit.completeTask(
          taskId: task.id,
          value: {'value': result.value},
        );
      }
    } else if (taskKey == 'temperature') {
      final result = await showMeasurementModal(
        context: context,
        title: 'Температура',
        description: 'Введите значение измерения',
        unit: '°C',
        key: 'temperature',
      );
      if (result != null) {
        await cubit.completeTask(
          taskId: task.id,
          value: {'value': result.value},
        );
      }
    } else if (taskKey == 'pulse') {
      final result = await showMeasurementModal(
        context: context,
        title: 'Пульс',
        description: 'Введите значение измерения',
        unit: 'уд/мин',
        key: 'pulse',
      );
      if (result != null) {
        await cubit.completeTask(
          taskId: task.id,
          value: {'value': result.value},
        );
      }
    } else if (taskKey == 'saturation' || taskKey == 'oxygen_saturation') {
      final result = await showMeasurementModal(
        context: context,
        title: 'Сатурация',
        description: 'Введите значение измерения',
        unit: '%',
        key: 'saturation',
      );
      if (result != null) {
        await cubit.completeTask(
          taskId: task.id,
          value: {'value': result.value},
        );
      }
    } else if (taskKey == 'respiratory_rate') {
      final result = await showMeasurementModal(
        context: context,
        title: 'Частота дыхания',
        description: 'Введите значение измерения',
        unit: 'вд/мин',
        key: 'respiratory_rate',
      );
      if (result != null) {
        await cubit.completeTask(
          taskId: task.id,
          value: {'value': result.value},
        );
      }
    } else if (taskKey == 'pain_level') {
      final result = await showMeasurementModal(
        context: context,
        title: 'Уровень боли',
        description: 'Введите значение от 0 до 10',
        unit: '',
        key: 'pain_level',
      );
      if (result != null) {
        await cubit.completeTask(
          taskId: task.id,
          value: {'value': result.value},
        );
      }
    } else if (taskKey == 'blood_sugar') {
      final result = await showTextInputModal(
        context: context,
        title: 'Уровень сахара',
        description: 'Введите значение измерения',
        hint: 'Например: 5.5 ммоль/л',
      );
      if (result != null) {
        await cubit.completeTask(taskId: task.id, value: {'value': result});
      }
    } else if (taskKey == 'fluid_intake') {
      final result = await showTextInputModal(
        context: context,
        title: 'Выпито жидкости',
        description: 'Введите количество выпитой жидкости',
        hint: 'Например: 200 мл или 1 стакан',
      );
      if (result != null) {
        await cubit.completeTask(taskId: task.id, value: {'value': result});
      }
    } else if (taskKey == 'urine_output') {
      final result = await showTextInputModal(
        context: context,
        title: 'Выделено мочи',
        description: 'Введите количество выделенной мочи',
        hint: 'Например: 150 мл или много',
      );
      if (result != null) {
        await cubit.completeTask(taskId: task.id, value: {'value': result});
      }
    } else if (taskKey == 'medication' || taskKey == 'vitamins') {
      // Текстовые параметры - показываем диалог ввода текста
      final result = await showTextInputModal(
        context: context,
        title: taskKey == 'medication' ? 'Приём лекарств' : 'Приём витаминов',
        description: 'Введите название препарата',
        hint: 'Название препарата',
      );
      if (result != null) {
        await cubit.completeTask(taskId: task.id, value: {'value': result});
      }
    } else if (taskKey == 'meal' || taskKey == 'feeding') {
      final result = await showTextInputModal(
        context: context,
        title: 'Приём пищи',
        description: 'Что было съедено',
        hint: 'Описание приёма пищи',
      );
      if (result != null) {
        await cubit.completeTask(taskId: task.id, value: {'value': result});
      }
    } else if (taskKey == 'cognitive_games') {
      final result = await showTextInputModal(
        context: context,
        title: 'Когнитивные игры',
        description: 'Описание активности',
        hint: 'Что делали',
      );
      if (result != null) {
        await cubit.completeTask(taskId: task.id, value: {'value': result});
      }
    } else if (taskKey == 'sleep') {
      final result = await showMeasurementModal(
        context: context,
        title: 'Сон',
        description: 'Сколько часов спал',
        unit: 'ч',
        key: 'sleep',
      );
      if (result != null) {
        await cubit.completeTask(
          taskId: task.id,
          value: {'value': result.value},
        );
      }
    } else {
      // Для остальных задач - просто отмечаем как выполненные
      await cubit.completeTask(taskId: task.id, value: {'value': true});
    }
  }
}
