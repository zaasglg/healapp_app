import 'package:equatable/equatable.dart';

import '../../repositories/route_sheet_repository.dart';

// Re-export models for convenience
export '../../repositories/route_sheet_repository.dart'
    show RouteSheetTask, TaskTemplate, TimeRange, TaskStatus, TaskSummary;

/// Состояние маршрутного листа
class RouteSheetState extends Equatable {
  final List<RouteSheetTask> tasks;
  final List<TaskTemplate> templates;
  final DateTime selectedDate;
  final TaskSummary? summary;
  final bool isLoading;
  final String? errorMessage;

  const RouteSheetState({
    this.tasks = const [],
    this.templates = const [],
    required this.selectedDate,
    this.summary,
    this.isLoading = false,
    this.errorMessage,
  });

  RouteSheetState copyWith({
    List<RouteSheetTask>? tasks,
    List<TaskTemplate>? templates,
    DateTime? selectedDate,
    TaskSummary? summary,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RouteSheetState(
      tasks: tasks ?? this.tasks,
      templates: templates ?? this.templates,
      selectedDate: selectedDate ?? this.selectedDate,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Получить задачи для выбранной даты
  List<RouteSheetTask> getTasksForDate(DateTime date) {
    return tasks.where((task) {
      return task.startAt.year == date.year &&
          task.startAt.month == date.month &&
          task.startAt.day == date.day;
    }).toList();
  }

  /// Получить задачи по временным слотам
  Map<String, List<RouteSheetTask>> getTasksByTimeSlots(DateTime date) {
    final tasksForDate = getTasksForDate(date);
    final Map<String, List<RouteSheetTask>> tasksByTime = {};

    for (var task in tasksForDate) {
      final time = task.startTimeFormatted;
      if (!tasksByTime.containsKey(time)) {
        tasksByTime[time] = [];
      }
      tasksByTime[time]!.add(task);
    }

    return tasksByTime;
  }

  /// Проверить, есть ли задачи
  bool get hasTasks => tasks.isNotEmpty;

  /// Проверить, есть ли шаблоны
  bool get hasTemplates => templates.isNotEmpty;

  @override
  List<Object?> get props => [
    tasks,
    templates,
    selectedDate,
    summary,
    isLoading,
    errorMessage,
  ];
}
