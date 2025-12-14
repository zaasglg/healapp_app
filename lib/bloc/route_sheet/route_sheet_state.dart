import 'package:equatable/equatable.dart';

enum TaskStatus {
  completed, // Выполненная задача
  planned, // Поставленная задача
  postponed, // Перенесенная задача
  uncompleted, // Не выполненная задача
}

class RouteSheetTask extends Equatable {
  final String id;
  final String name;
  final String time;
  final TaskStatus status;
  final List<int> daysOfWeek; // Дни недели (1-7)
  final int? order; // Порядок выполнения

  const RouteSheetTask({
    required this.id,
    required this.name,
    required this.time,
    required this.status,
    required this.daysOfWeek,
    this.order,
  });

  @override
  List<Object?> get props => [id, name, time, status, daysOfWeek, order];
}

class RouteSheetState extends Equatable {
  final List<RouteSheetTask> tasks;
  final DateTime selectedDate;

  const RouteSheetState({this.tasks = const [], required this.selectedDate});

  RouteSheetState copyWith({
    List<RouteSheetTask>? tasks,
    DateTime? selectedDate,
  }) {
    return RouteSheetState(
      tasks: tasks ?? this.tasks,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  // Получить задачи для выбранной даты
  List<RouteSheetTask> getTasksForDate(DateTime date) {
    final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday
    return tasks.where((task) {
      return task.daysOfWeek.contains(dayOfWeek);
    }).toList();
  }

  @override
  List<Object?> get props => [tasks, selectedDate];
}




