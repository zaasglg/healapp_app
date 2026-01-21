import 'package:equatable/equatable.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';

final _defaultApiClient = apiClient;

/// Статус задачи
enum TaskStatus {
  pending,
  completed,
  missed,
  cancelled;

  String get value {
    switch (this) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.missed:
        return 'missed';
      case TaskStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Ожидает';
      case TaskStatus.completed:
        return 'Выполнена';
      case TaskStatus.missed:
        return 'Не выполнена';
      case TaskStatus.cancelled:
        return 'Отменена';
    }
  }

  static TaskStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return TaskStatus.pending;
      case 'completed':
        return TaskStatus.completed;
      case 'missed':
        return TaskStatus.missed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.pending;
    }
  }
}

/// Модель задачи маршрутного листа
class RouteSheetTask extends Equatable {
  final int id;
  final int patientId;
  final int? templateId;
  final int? assignedTo;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime? originalStartAt;
  final DateTime? originalEndAt;
  final TaskStatus status;
  final int priority;
  final DateTime? completedAt;
  final int? completedBy;
  final String? comment;
  final List<String>? photos;
  final String? rescheduleReason;
  final int? rescheduledBy;
  final DateTime? rescheduledAt;
  final String? relatedDiaryKey;
  final bool isRescheduled;
  final bool isOverdue;

  const RouteSheetTask({
    required this.id,
    required this.patientId,
    this.templateId,
    this.assignedTo,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.originalStartAt,
    this.originalEndAt,
    required this.status,
    required this.priority,
    this.completedAt,
    this.completedBy,
    this.comment,
    this.photos,
    this.rescheduleReason,
    this.rescheduledBy,
    this.rescheduledAt,
    this.relatedDiaryKey,
    required this.isRescheduled,
    required this.isOverdue,
  });

  factory RouteSheetTask.fromJson(Map<String, dynamic> json) {
    final status = TaskStatus.fromString(json['status'] as String);
    final isRescheduledFromApi = json['is_rescheduled'] as bool? ?? false;
    final isOverdueFromApi = json['is_overdue'] as bool? ?? false;

    // Для завершенных задач (completed, missed, cancelled)
    // сбрасываем флаги isRescheduled и isOverdue для правильного отображения
    final shouldResetFlags =
        status == TaskStatus.completed ||
        status == TaskStatus.missed ||
        status == TaskStatus.cancelled;

    return RouteSheetTask(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      templateId: json['template_id'] as int?,
      assignedTo: json['assigned_to'] == null
          ? null
          : json['assigned_to'] is int
          ? json['assigned_to'] as int
          : (json['assigned_to'] as Map<String, dynamic>?)?['id'] as int?,
      title: json['title'] as String,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      originalStartAt: json['original_start_at'] != null
          ? DateTime.parse(json['original_start_at'] as String)
          : null,
      originalEndAt: json['original_end_at'] != null
          ? DateTime.parse(json['original_end_at'] as String)
          : null,
      status: status,
      priority: json['priority'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completedBy: json['completed_by'] == null
          ? null
          : json['completed_by'] is int
          ? json['completed_by'] as int
          : (json['completed_by'] as Map<String, dynamic>?)?['id'] as int?,
      comment: json['comment'] as String?,
      photos: json['photos'] != null
          ? (json['photos'] as List<dynamic>).cast<String>()
          : null,
      rescheduleReason: json['reschedule_reason'] as String?,
      rescheduledBy: json['rescheduled_by'] == null
          ? null
          : json['rescheduled_by'] is int
          ? json['rescheduled_by'] as int
          : (json['rescheduled_by'] as Map<String, dynamic>?)?['id'] as int?,
      rescheduledAt: json['rescheduled_at'] != null
          ? DateTime.parse(json['rescheduled_at'] as String)
          : null,
      relatedDiaryKey: json['related_diary_key'] as String?,
      // Для завершенных задач сбрасываем флаги
      isRescheduled: shouldResetFlags ? false : isRescheduledFromApi,
      isOverdue: shouldResetFlags ? false : isOverdueFromApi,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'template_id': templateId,
      'assigned_to': assignedTo,
      'title': title,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'original_start_at': originalStartAt?.toIso8601String(),
      'original_end_at': originalEndAt?.toIso8601String(),
      'status': status.value,
      'priority': priority,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      'comment': comment,
      'photos': photos,
      'reschedule_reason': rescheduleReason,
      'rescheduled_by': rescheduledBy,
      'rescheduled_at': rescheduledAt?.toIso8601String(),
      'related_diary_key': relatedDiaryKey,
      'is_rescheduled': isRescheduled,
      'is_overdue': isOverdue,
    };
  }

  /// Получить время начала в формате HH:MM
  String get startTimeFormatted {
    return '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}';
  }

  /// Получить время окончания в формате HH:MM
  String get endTimeFormatted {
    return '${endAt.hour.toString().padLeft(2, '0')}:${endAt.minute.toString().padLeft(2, '0')}';
  }

  /// Получить диапазон времени
  String get timeRange => '$startTimeFormatted - $endTimeFormatted';

  RouteSheetTask copyWith({
    int? id,
    int? patientId,
    int? templateId,
    int? assignedTo,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? originalStartAt,
    DateTime? originalEndAt,
    TaskStatus? status,
    int? priority,
    DateTime? completedAt,
    int? completedBy,
    String? comment,
    List<String>? photos,
    String? rescheduleReason,
    int? rescheduledBy,
    DateTime? rescheduledAt,
    String? relatedDiaryKey,
    bool? isRescheduled,
    bool? isOverdue,
  }) {
    return RouteSheetTask(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      templateId: templateId ?? this.templateId,
      assignedTo: assignedTo ?? this.assignedTo,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      originalStartAt: originalStartAt ?? this.originalStartAt,
      originalEndAt: originalEndAt ?? this.originalEndAt,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      comment: comment ?? this.comment,
      photos: photos ?? this.photos,
      rescheduleReason: rescheduleReason ?? this.rescheduleReason,
      rescheduledBy: rescheduledBy ?? this.rescheduledBy,
      rescheduledAt: rescheduledAt ?? this.rescheduledAt,
      relatedDiaryKey: relatedDiaryKey ?? this.relatedDiaryKey,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      isOverdue: isOverdue ?? this.isOverdue,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    templateId,
    assignedTo,
    title,
    startAt,
    endAt,
    originalStartAt,
    originalEndAt,
    status,
    priority,
    completedAt,
    completedBy,
    comment,
    photos,
    rescheduleReason,
    rescheduledBy,
    rescheduledAt,
    relatedDiaryKey,
    isRescheduled,
    isOverdue,
  ];

  @override
  String toString() =>
      'RouteSheetTask(id: $id, title: $title, status: ${status.value})';
}

/// Временной диапазон для шаблона
class TimeRange {
  final String start;
  final String end;
  final int? assignedTo;
  final int? priority;

  const TimeRange({
    required this.start,
    required this.end,
    this.assignedTo,
    this.priority,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      start: json['start'] as String,
      end: json['end'] as String,
      assignedTo: json['assigned_to'] as int?,
      priority: json['priority'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (priority != null) 'priority': priority,
    };
  }
}

/// Модель шаблона задачи
class TaskTemplate {
  final int id;
  final int patientId;
  final int creatorId;
  final int? assignedTo;
  final String title;
  final List<int>? daysOfWeek;
  final List<TimeRange> timeRanges;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? relatedDiaryKey;

  const TaskTemplate({
    required this.id,
    required this.patientId,
    required this.creatorId,
    this.assignedTo,
    required this.title,
    this.daysOfWeek,
    required this.timeRanges,
    required this.startDate,
    this.endDate,
    required this.isActive,
    this.relatedDiaryKey,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      creatorId: json['creator_id'] as int,
      assignedTo: json['assigned_to'] as int?,
      title: json['title'] as String,
      daysOfWeek: json['days_of_week'] != null
          ? (json['days_of_week'] as List<dynamic>).cast<int>()
          : null,
      timeRanges: (json['time_ranges'] as List<dynamic>)
          .map((e) => TimeRange.fromJson(e as Map<String, dynamic>))
          .toList(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      isActive: json['is_active'] as bool,
      relatedDiaryKey: json['related_diary_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'creator_id': creatorId,
      'assigned_to': assignedTo,
      'title': title,
      'days_of_week': daysOfWeek,
      'time_ranges': timeRanges.map((e) => e.toJson()).toList(),
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate?.toIso8601String().split('T')[0],
      'is_active': isActive,
      'related_diary_key': relatedDiaryKey,
    };
  }

  /// Получить строку с днями недели
  String get daysOfWeekLabel {
    if (daysOfWeek == null || daysOfWeek!.length == 7) {
      return 'Каждый день';
    }

    const dayLabels = {
      0: 'ВС',
      1: 'ПН',
      2: 'ВТ',
      3: 'СР',
      4: 'ЧТ',
      5: 'ПТ',
      6: 'СБ',
    };

    return daysOfWeek!.map((d) => dayLabels[d] ?? '').join(', ');
  }

  TaskTemplate copyWith({
    int? id,
    int? patientId,
    int? creatorId,
    int? assignedTo,
    String? title,
    List<int>? daysOfWeek,
    List<TimeRange>? timeRanges,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? relatedDiaryKey,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      creatorId: creatorId ?? this.creatorId,
      assignedTo: assignedTo ?? this.assignedTo,
      title: title ?? this.title,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      timeRanges: timeRanges ?? this.timeRanges,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      relatedDiaryKey: relatedDiaryKey ?? this.relatedDiaryKey,
    );
  }

  @override
  String toString() =>
      'TaskTemplate(id: $id, title: $title, isActive: $isActive)';
}

/// Сводка по задачам
class TaskSummary {
  final int total;
  final int pending;
  final int completed;
  final int missed;
  final int overdue;

  const TaskSummary({
    required this.total,
    required this.pending,
    required this.completed,
    required this.missed,
    required this.overdue,
  });

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      total: json['total'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      missed: json['missed'] as int? ?? 0,
      overdue: json['overdue'] as int? ?? 0,
    );
  }
}

/// Ответ со списком задач
class RouteSheetResponse {
  final DateTime date;
  final DateTime fromDate;
  final DateTime toDate;
  final List<RouteSheetTask> tasks;
  final TaskSummary summary;
  final Map<String, List<RouteSheetTask>>? timeSlots;

  const RouteSheetResponse({
    required this.date,
    required this.fromDate,
    required this.toDate,
    required this.tasks,
    required this.summary,
    this.timeSlots,
  });

  factory RouteSheetResponse.fromJson(Map<String, dynamic> json) {
    final tasksJson = json['tasks'] as List<dynamic>? ?? [];
    final tasks = tasksJson
        .map((e) => RouteSheetTask.fromJson(e as Map<String, dynamic>))
        .toList();

    // Parse time slots if available
    Map<String, List<RouteSheetTask>>? timeSlots;
    if (json['time_slots'] != null) {
      timeSlots = {};
      final timeSlotsJson = json['time_slots'] as Map<String, dynamic>;
      for (final entry in timeSlotsJson.entries) {
        final slotTasks = (entry.value as List<dynamic>)
            .map((e) => RouteSheetTask.fromJson(e as Map<String, dynamic>))
            .toList();
        timeSlots[entry.key] = slotTasks;
      }
    }

    return RouteSheetResponse(
      date: DateTime.parse(json['date'] as String),
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      tasks: tasks,
      summary: TaskSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      timeSlots: timeSlots,
    );
  }
}

/// Репозиторий для работы с маршрутным листом
class RouteSheetRepository {
  final ApiClient _apiClient;

  RouteSheetRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Получить маршрутный лист на дату
  Future<RouteSheetResponse> getRouteSheet({
    int? patientId,
    DateTime? date,
    DateTime? fromDate,
    DateTime? toDate,
    TaskStatus? status,
  }) async {
    try {
      log.d('=== RouteSheetRepository.getRouteSheet: НАЧАЛО ===');
      log.d('RouteSheetRepository: Запрос маршрутного листа');
      log.d('  - patientId: $patientId');
      log.d('  - date: ${date?.toIso8601String()}');
      log.d('  - fromDate: ${fromDate?.toIso8601String()}');
      log.d('  - toDate: ${toDate?.toIso8601String()}');
      log.d('  - status: ${status?.value}');

      final queryParams = <String, dynamic>{};
      if (patientId != null) queryParams['patient_id'] = patientId;
      if (date != null)
        queryParams['date'] = date.toIso8601String().split('T')[0];
      if (fromDate != null)
        queryParams['from_date'] = fromDate.toIso8601String().split('T')[0];
      if (toDate != null)
        queryParams['to_date'] = toDate.toIso8601String().split('T')[0];
      if (status != null) queryParams['status'] = status.value;

      log.d('RouteSheetRepository: Query params: $queryParams');
      log.d('RouteSheetRepository: Отправка GET запроса на /route-sheet...');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/route-sheet',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось получить маршрутный лист');
      }

      final result = RouteSheetResponse.fromJson(data);

      return result;
    } catch (e, stackTrace) {
      log.e('=== RouteSheetRepository.getRouteSheet: ОШИБКА ===');
      log.e('RouteSheetRepository: Ошибка получения маршрутного листа: $e');
      log.e('RouteSheetRepository: StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Получить мои задачи (для сиделок)
  Future<RouteSheetResponse> getMyTasks({DateTime? date}) async {
    try {
      log.d('RouteSheetRepository: Запрос моих задач');

      final queryParams = <String, dynamic>{};
      if (date != null)
        queryParams['date'] = date.toIso8601String().split('T')[0];

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/route-sheet/my-tasks',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось получить задачи');
      }

      return RouteSheetResponse.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка получения моих задач: $e');
      rethrow;
    }
  }

  /// Получить одну задачу
  Future<RouteSheetTask> getTask(int taskId) async {
    try {
      log.d('RouteSheetRepository: Запрос задачи $taskId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/route-sheet/$taskId',
      );

      final data = response.data;
      if (data == null) {
        throw const NotFoundException('Задача не найдена');
      }

      return RouteSheetTask.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка получения задачи: $e');
      rethrow;
    }
  }

  /// Создать одноразовую задачу
  Future<RouteSheetTask> createTask({
    required int patientId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    int? assignedTo,
    int? priority,
    String? relatedDiaryKey,
  }) async {
    try {
      log.d('RouteSheetRepository: Создание задачи $title');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/route-sheet',
        data: {
          'patient_id': patientId,
          'title': title,
          'start_at': _formatDateTime(startAt),
          'end_at': _formatDateTime(endAt),
          if (assignedTo != null) 'assigned_to': assignedTo,
          if (priority != null) 'priority': priority,
          if (relatedDiaryKey != null) 'related_diary_key': relatedDiaryKey,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось создать задачу');
      }

      log.i('RouteSheetRepository: Задача создана');
      return RouteSheetTask.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка создания задачи: $e');
      rethrow;
    }
  }

  /// Обновить задачу
  Future<RouteSheetTask> updateTask({
    required int taskId,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    int? assignedTo,
    int? priority,
  }) async {
    try {
      log.d('RouteSheetRepository: Обновление задачи $taskId');

      final requestData = <String, dynamic>{};
      if (title != null) requestData['title'] = title;
      if (startAt != null) requestData['start_at'] = _formatDateTime(startAt);
      if (endAt != null) requestData['end_at'] = _formatDateTime(endAt);
      if (assignedTo != null) requestData['assigned_to'] = assignedTo;
      if (priority != null) requestData['priority'] = priority;

      final response = await _apiClient.put<Map<String, dynamic>>(
        '/route-sheet/$taskId',
        data: requestData,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось обновить задачу');
      }

      log.i('RouteSheetRepository: Задача обновлена');
      return RouteSheetTask.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка обновления задачи: $e');
      rethrow;
    }
  }

  /// Перенести задачу
  Future<RouteSheetTask> rescheduleTask({
    required int taskId,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
  }) async {
    try {
      log.d('RouteSheetRepository: Перенос задачи $taskId');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/route-sheet/$taskId/reschedule',
        data: {
          'start_at': _formatDateTime(startAt),
          'end_at': _formatDateTime(endAt),
          'reason': reason,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось перенести задачу');
      }

      log.i('RouteSheetRepository: Задача перенесена');
      return RouteSheetTask.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка переноса задачи: $e');
      rethrow;
    }
  }

  /// Выполнить задачу
  Future<RouteSheetTask> completeTask({
    required int taskId,
    String? comment,
    Map<String, dynamic>? value,
    DateTime? completedAt,
  }) async {
    try {
      log.d('RouteSheetRepository.completeTask: taskId=$taskId');
      log.d('RouteSheetRepository.completeTask: value=$value');
      log.d('RouteSheetRepository.completeTask: comment=$comment');

      final requestData = {
        if (comment != null) 'comment': comment,
        if (value != null) 'value': value,
        if (completedAt != null) 'completed_at': _formatDateTime(completedAt),
      };

      log.d('RouteSheetRepository.completeTask: requestData=$requestData');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/route-sheet/$taskId/complete',
        data: requestData,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось выполнить задачу');
      }

      log.d('RouteSheetRepository.completeTask: response data=$data');
      return RouteSheetTask.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка выполнения задачи: $e');
      rethrow;
    }
  }

  /// Пометить задачу как невыполненную
  Future<RouteSheetTask> missTask({
    required int taskId,
    required String reason,
  }) async {
    try {
      log.d('RouteSheetRepository: Пометка задачи $taskId как невыполненной');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/route-sheet/$taskId/miss',
        data: {'reason': reason},
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось пометить задачу');
      }

      log.i('RouteSheetRepository: Задача помечена как невыполненная');
      return RouteSheetTask.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка пометки задачи: $e');
      rethrow;
    }
  }

  /// Удалить задачу
  Future<void> deleteTask(int taskId) async {
    try {
      log.d('RouteSheetRepository: Удаление задачи $taskId');

      await _apiClient.delete('/route-sheet/$taskId');

      log.i('RouteSheetRepository: Задача удалена');
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка удаления задачи: $e');
      rethrow;
    }
  }

  // =========== Task Templates ===========

  /// Получить список шаблонов
  Future<List<TaskTemplate>> getTaskTemplates(int patientId) async {
    try {
      log.d('RouteSheetRepository: Запрос шаблонов задач');

      final response = await _apiClient.get<List<dynamic>>(
        '/task-templates',
        queryParameters: {'patient_id': patientId},
      );

      final data = response.data;
      if (data == null) {
        return [];
      }

      return data
          .map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка получения шаблонов: $e');
      rethrow;
    }
  }

  /// Получить один шаблон
  Future<TaskTemplate> getTaskTemplate(int templateId) async {
    try {
      log.d('RouteSheetRepository: Запрос шаблона $templateId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/task-templates/$templateId',
      );

      final data = response.data;
      if (data == null) {
        throw const NotFoundException('Шаблон не найден');
      }

      return TaskTemplate.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка получения шаблона: $e');
      rethrow;
    }
  }

  /// Создать шаблон задачи
  Future<TaskTemplate> createTaskTemplate({
    required int patientId,
    required String title,
    int? assignedTo,
    List<int>? daysOfWeek,
    required List<TimeRange> timeRanges,
    required DateTime startDate,
    DateTime? endDate,
    bool isActive = true,
    String? relatedDiaryKey,
  }) async {
    try {
      log.d('=== RouteSheetRepository.createTaskTemplate: НАЧАЛО ===');
      log.d('RouteSheetRepository: Создание шаблона "$title"');
      log.d('  - patientId: $patientId');
      log.d('  - assignedTo: $assignedTo');
      log.d('  - daysOfWeek: $daysOfWeek');
      log.d(
        '  - timeRanges: ${timeRanges.map((tr) => "${tr.start}-${tr.end}").join(", ")}',
      );
      log.d('  - startDate: ${startDate.toIso8601String()}');
      log.d('  - isActive: $isActive');

      final requestData = {
        'patient_id': patientId,
        'title': title,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (daysOfWeek != null) 'days_of_week': daysOfWeek,
        'time_ranges': timeRanges.map((e) => e.toJson()).toList(),
        'start_date': startDate.toIso8601String().split('T')[0],
        if (endDate != null)
          'end_date': endDate.toIso8601String().split('T')[0],
        'is_active': isActive,
        if (relatedDiaryKey != null) 'related_diary_key': relatedDiaryKey,
      };

      log.d('RouteSheetRepository: Request data: $requestData');
      log.d(
        'RouteSheetRepository: Отправка POST запроса на /task-templates...',
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/task-templates',
        data: requestData,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось создать шаблон');
      }

      return TaskTemplate.fromJson(data);
    } catch (e, stackTrace) {
      log.e('=== RouteSheetRepository.createTaskTemplate: ОШИБКА ===');
      log.e('RouteSheetRepository: Ошибка создания шаблона: $e');
      log.e('RouteSheetRepository: StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Обновить шаблон
  Future<TaskTemplate> updateTaskTemplate({
    required int templateId,
    String? title,
    int? assignedTo,
    List<int>? daysOfWeek,
    List<TimeRange>? timeRanges,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? relatedDiaryKey,
  }) async {
    try {
      log.d('RouteSheetRepository: Обновление шаблона $templateId');

      final requestData = <String, dynamic>{};
      if (title != null) requestData['title'] = title;
      if (assignedTo != null) requestData['assigned_to'] = assignedTo;
      if (daysOfWeek != null) requestData['days_of_week'] = daysOfWeek;
      if (timeRanges != null) {
        requestData['time_ranges'] = timeRanges.map((e) => e.toJson()).toList();
      }
      if (startDate != null) {
        requestData['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        requestData['end_date'] = endDate.toIso8601String().split('T')[0];
      }
      if (isActive != null) requestData['is_active'] = isActive;
      if (relatedDiaryKey != null) {
        requestData['related_diary_key'] = relatedDiaryKey;
      }

      final response = await _apiClient.put<Map<String, dynamic>>(
        '/task-templates/$templateId',
        data: requestData,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось обновить шаблон');
      }

      log.i('RouteSheetRepository: Шаблон обновлён');
      return TaskTemplate.fromJson(data);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка обновления шаблона: $e');
      rethrow;
    }
  }

  /// Включить/выключить шаблон
  Future<TaskTemplate> toggleTaskTemplate(int templateId) async {
    try {
      log.d('RouteSheetRepository: Переключение шаблона $templateId');

      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/task-templates/$templateId/toggle',
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось переключить шаблон');
      }

      // Fetch full template since toggle might return partial data
      return getTaskTemplate(templateId);
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка переключения шаблона: $e');
      rethrow;
    }
  }

  /// Удалить шаблон
  Future<void> deleteTaskTemplate(int templateId) async {
    try {
      log.d('RouteSheetRepository: Удаление шаблона $templateId');

      await _apiClient.delete('/task-templates/$templateId');

      log.i('RouteSheetRepository: Шаблон удалён');
    } catch (e) {
      log.e('RouteSheetRepository: Ошибка удаления шаблона: $e');
      rethrow;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
