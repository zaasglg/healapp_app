import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/route_sheet_repository.dart';
import '../../utils/app_logger.dart';
import 'route_sheet_state.dart';

class RouteSheetCubit extends Cubit<RouteSheetState> {
  final RouteSheetRepository _repository;
  final int patientId;

  RouteSheetCubit({required this.patientId, RouteSheetRepository? repository})
    : _repository = repository ?? RouteSheetRepository(),
      super(RouteSheetState(selectedDate: DateTime.now())) {
    log.d('RouteSheetCubit: Инициализация для пациента $patientId');
  }

  /// Загрузить маршрутный лист на выбранную дату
  Future<void> loadRouteSheet({DateTime? date}) async {
    final targetDate = date ?? state.selectedDate;
    log.d(
      'RouteSheetCubit.loadRouteSheet: Загрузка на дату ${targetDate.toIso8601String()}',
    );
    log.d('RouteSheetCubit.loadRouteSheet: patientId = $patientId');

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      log.d(
        'RouteSheetCubit.loadRouteSheet: Отправка запроса в репозиторий...',
      );

      final response = await _repository.getRouteSheet(
        patientId: patientId,
        date: targetDate,
      );

      log.i(
        'RouteSheetCubit.loadRouteSheet: Получено ${response.tasks.length} задач',
      );
      log.d(
        'RouteSheetCubit.loadRouteSheet: Summary - total: ${response.summary.total}, pending: ${response.summary.pending}',
      );

      for (var task in response.tasks) {
        log.d(
          '  - Задача: ${task.title}, время: ${task.timeRange}, статус: ${task.status.value}',
        );
      }

      emit(
        state.copyWith(
          tasks: response.tasks,
          summary: response.summary,
          selectedDate: targetDate,
          isLoading: false,
        ),
      );

      log.i('RouteSheetCubit.loadRouteSheet: Состояние обновлено успешно');
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.loadRouteSheet: ОШИБКА: $e');
      log.e('RouteSheetCubit.loadRouteSheet: StackTrace: $stackTrace');

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Ошибка загрузки: ${e.toString()}',
        ),
      );
    }
  }

  /// Загрузить шаблоны задач
  Future<void> loadTemplates() async {
    log.d(
      'RouteSheetCubit.loadTemplates: Загрузка шаблонов для пациента $patientId',
    );

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final templates = await _repository.getTaskTemplates(patientId);

      log.i(
        'RouteSheetCubit.loadTemplates: Получено ${templates.length} шаблонов',
      );
      for (var template in templates) {
        log.d('  - Шаблон: ${template.title}, активен: ${template.isActive}');
      }

      emit(state.copyWith(templates: templates, isLoading: false));
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.loadTemplates: ОШИБКА: $e');
      log.e('RouteSheetCubit.loadTemplates: StackTrace: $stackTrace');

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Ошибка загрузки шаблонов: ${e.toString()}',
        ),
      );
    }
  }

  /// Установить выбранную дату
  void setSelectedDate(DateTime date) {
    log.d(
      'RouteSheetCubit.setSelectedDate: Смена даты на ${date.toIso8601String()}',
    );
    emit(state.copyWith(selectedDate: date));
    loadRouteSheet(date: date);
  }

  /// Создать одноразовую задачу через API
  Future<void> createTask({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    int? assignedTo,
    int? priority,
    String? relatedDiaryKey,
  }) async {
    log.d('RouteSheetCubit.createTask: Создание задачи "$title"');
    log.d('  - patientId: $patientId');
    log.d('  - startAt: ${startAt.toIso8601String()}');
    log.d('  - endAt: ${endAt.toIso8601String()}');
    log.d('  - assignedTo: $assignedTo');
    log.d('  - priority: $priority');
    log.d('  - relatedDiaryKey: $relatedDiaryKey');

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      await _repository.createTask(
        patientId: patientId,
        title: title,
        startAt: startAt,
        endAt: endAt,
        assignedTo: assignedTo,
        priority: priority,
        relatedDiaryKey: relatedDiaryKey,
      );

      log.i('RouteSheetCubit.createTask: Задача "$title" создана успешно');

      // Перезагрузить задачи
      await loadRouteSheet();
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.createTask: ОШИБКА создания задачи: $e');
      log.e('RouteSheetCubit.createTask: StackTrace: $stackTrace');

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Ошибка создания задачи: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  /// Создать шаблон задачи через API
  Future<void> createTemplate({
    required String title,
    int? assignedTo,
    List<int>? daysOfWeek,
    required List<TimeRange> timeRanges,
    required DateTime startDate,
    DateTime? endDate,
    String? relatedDiaryKey,
  }) async {
    log.d('=== RouteSheetCubit.createTemplate: НАЧАЛО ===');
    log.d('RouteSheetCubit.createTemplate: Создание шаблона "$title"');
    log.d('  - patientId: $patientId');
    log.d('  - assignedTo: $assignedTo');
    log.d('  - daysOfWeek: $daysOfWeek');
    log.d(
      '  - timeRanges: ${timeRanges.map((tr) => "${tr.start}-${tr.end}").join(", ")}',
    );
    log.d('  - startDate: ${startDate.toIso8601String()}');
    log.d('  - endDate: ${endDate?.toIso8601String()}');
    log.d('  - relatedDiaryKey: $relatedDiaryKey');

    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      log.d(
        'RouteSheetCubit.createTemplate: Отправка запроса в репозиторий...',
      );

      await _repository.createTaskTemplate(
        patientId: patientId,
        title: title,
        assignedTo: assignedTo,
        daysOfWeek: daysOfWeek,
        timeRanges: timeRanges,
        startDate: startDate,
        endDate: endDate,
        relatedDiaryKey: relatedDiaryKey,
      );

      log.i(
        'RouteSheetCubit.createTemplate: Шаблон "$title" создан успешно через API',
      );

      // Перезагрузить шаблоны и задачи
      log.d('RouteSheetCubit.createTemplate: Перезагрузка шаблонов и задач...');
      await Future.wait([loadTemplates(), loadRouteSheet()]);

      log.d('=== RouteSheetCubit.createTemplate: УСПЕШНО ЗАВЕРШЕНО ===');
    } catch (e, stackTrace) {
      log.e('=== RouteSheetCubit.createTemplate: ОШИБКА ===');
      log.e('RouteSheetCubit.createTemplate: Ошибка: $e');
      log.e('RouteSheetCubit.createTemplate: StackTrace: $stackTrace');

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Ошибка создания шаблона: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  /// Выполнить задачу через API
  Future<void> completeTask({
    required int taskId,
    String? comment,
    Map<String, dynamic>? value,
  }) async {
    log.d('RouteSheetCubit.completeTask: Выполнение задачи $taskId');
    log.d('  - comment: $comment');
    log.d('  - value: $value');

    try {
      final updatedTask = await _repository.completeTask(
        taskId: taskId,
        comment: comment,
        value: value,
      );

      // Обновить локальное состояние
      final updatedTasks = state.tasks.map((task) {
        if (task.id == taskId) {
          // Форсируем статус completed и сбрасываем флаги isRescheduled и isOverdue
          return updatedTask.copyWith(
            status: TaskStatus.completed,
            completedAt: updatedTask.completedAt ?? DateTime.now(),
            isRescheduled: false,
            isOverdue: false,
          );
        }
        return task;
      }).toList();

      emit(state.copyWith(tasks: updatedTasks));
      log.i('RouteSheetCubit.completeTask: Задача $taskId выполнена');
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.completeTask: ОШИБКА: $e');
      log.e('RouteSheetCubit.completeTask: StackTrace: $stackTrace');

      emit(
        state.copyWith(
          errorMessage: 'Ошибка выполнения задачи: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  /// Пометить задачу как невыполненную через API
  Future<void> missTask({required int taskId, required String reason}) async {
    log.d('RouteSheetCubit.missTask: Пометка задачи $taskId как невыполненной');
    log.d('  - reason: $reason');

    try {
      final updatedTask = await _repository.missTask(
        taskId: taskId,
        reason: reason,
      );

      // Обновить локальное состояние
      final updatedTasks = state.tasks.map((task) {
        if (task.id == taskId) {
          // Форсируем статус missed и сбрасываем флаги isRescheduled и isOverdue
          return updatedTask.copyWith(
            status: TaskStatus.missed,
            isRescheduled: false,
            isOverdue: false,
          );
        }
        return task;
      }).toList();

      emit(state.copyWith(tasks: updatedTasks));
      log.i(
        'RouteSheetCubit.missTask: Задача $taskId помечена как невыполненная',
      );
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.missTask: ОШИБКА: $e');
      log.e('RouteSheetCubit.missTask: StackTrace: $stackTrace');

      emit(
        state.copyWith(errorMessage: 'Ошибка пометки задачи: ${e.toString()}'),
      );
      rethrow;
    }
  }

  /// Перенести задачу через API
  Future<void> rescheduleTask({
    required int taskId,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
  }) async {
    log.d('RouteSheetCubit.rescheduleTask: Перенос задачи $taskId');
    log.d('  - startAt: ${startAt.toIso8601String()}');
    log.d('  - endAt: ${endAt.toIso8601String()}');
    log.d('  - reason: $reason');

    try {
      final newTask = await _repository.rescheduleTask(
        taskId: taskId,
        startAt: startAt,
        endAt: endAt,
        reason: reason,
      );

      // Обновить локальное состояние
      // Бэкенд создает новую задачу при переносе, поэтому:
      // 1. Удаляем старую задачу из списка
      // 2. Добавляем новую задачу
      final updatedTasks =
          state.tasks.where((task) => task.id != taskId).toList()..add(newTask);

      // Сортируем по времени начала
      updatedTasks.sort((a, b) => a.startAt.compareTo(b.startAt));

      emit(state.copyWith(tasks: updatedTasks));
      log.i(
        'RouteSheetCubit.rescheduleTask: Задача $taskId перенесена, создана новая задача ${newTask.id}',
      );
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.rescheduleTask: ОШИБКА: $e');
      log.e('RouteSheetCubit.rescheduleTask: StackTrace: $stackTrace');

      emit(
        state.copyWith(errorMessage: 'Ошибка переноса задачи: ${e.toString()}'),
      );
      rethrow;
    }
  }

  /// Удалить задачу через API
  Future<void> deleteTask(int taskId) async {
    log.d('RouteSheetCubit.deleteTask: Удаление задачи $taskId');

    try {
      await _repository.deleteTask(taskId);

      // Удалить из локального состояния
      final updatedTasks = state.tasks
          .where((task) => task.id != taskId)
          .toList();

      emit(state.copyWith(tasks: updatedTasks));
      log.i('RouteSheetCubit.deleteTask: Задача $taskId удалена');
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.deleteTask: ОШИБКА: $e');
      log.e('RouteSheetCubit.deleteTask: StackTrace: $stackTrace');

      emit(
        state.copyWith(errorMessage: 'Ошибка удаления задачи: ${e.toString()}'),
      );
      rethrow;
    }
  }

  /// Переключить шаблон через API
  Future<void> toggleTemplate(int templateId) async {
    log.d('RouteSheetCubit.toggleTemplate: Переключение шаблона $templateId');

    try {
      final updatedTemplate = await _repository.toggleTaskTemplate(templateId);

      // Обновить локальное состояние
      final updatedTemplates = state.templates.map((template) {
        if (template.id == templateId) {
          return updatedTemplate;
        }
        return template;
      }).toList();

      emit(state.copyWith(templates: updatedTemplates));

      // Перезагрузить задачи
      await loadRouteSheet();
      log.i('RouteSheetCubit.toggleTemplate: Шаблон $templateId переключен');
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.toggleTemplate: ОШИБКА: $e');
      log.e('RouteSheetCubit.toggleTemplate: StackTrace: $stackTrace');

      emit(
        state.copyWith(
          errorMessage: 'Ошибка переключения шаблона: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  /// Удалить шаблон через API
  Future<void> deleteTemplate(int templateId) async {
    log.d('RouteSheetCubit.deleteTemplate: Удаление шаблона $templateId');

    try {
      await _repository.deleteTaskTemplate(templateId);

      // Удалить из локального состояния
      final updatedTemplates = state.templates
          .where((template) => template.id != templateId)
          .toList();

      emit(state.copyWith(templates: updatedTemplates));

      // Перезагрузить задачи
      await loadRouteSheet();
      log.i('RouteSheetCubit.deleteTemplate: Шаблон $templateId удален');
    } catch (e, stackTrace) {
      log.e('RouteSheetCubit.deleteTemplate: ОШИБКА: $e');
      log.e('RouteSheetCubit.deleteTemplate: StackTrace: $stackTrace');

      emit(
        state.copyWith(
          errorMessage: 'Ошибка удаления шаблона: ${e.toString()}',
        ),
      );
      rethrow;
    }
  }

  /// Очистить ошибку
  void clearError() {
    log.d('RouteSheetCubit.clearError: Очистка ошибки');
    emit(state.copyWith(errorMessage: null));
  }
}
