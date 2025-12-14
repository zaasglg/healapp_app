import 'package:flutter_bloc/flutter_bloc.dart';
import 'route_sheet_state.dart';

class RouteSheetCubit extends Cubit<RouteSheetState> {
  RouteSheetCubit() : super(RouteSheetState(selectedDate: DateTime.now()));

  void setSelectedDate(DateTime date) {
    emit(state.copyWith(selectedDate: date));
  }

  void addTask(RouteSheetTask task) {
    final updatedTasks = List<RouteSheetTask>.from(state.tasks)..add(task);
    emit(state.copyWith(tasks: updatedTasks));
  }

  void updateTaskStatus(String taskId, TaskStatus newStatus) {
    final updatedTasks = state.tasks.map((task) {
      if (task.id == taskId) {
        return RouteSheetTask(
          id: task.id,
          name: task.name,
          time: task.time,
          status: newStatus,
          daysOfWeek: task.daysOfWeek,
          order: task.order,
        );
      }
      return task;
    }).toList();
    emit(state.copyWith(tasks: updatedTasks));
  }

  void removeTask(String taskId) {
    final updatedTasks = state.tasks
        .where((task) => task.id != taskId)
        .toList();
    emit(state.copyWith(tasks: updatedTasks));
  }

  void clearTasks() {
    emit(state.copyWith(tasks: []));
  }
}
