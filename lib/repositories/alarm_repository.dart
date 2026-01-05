import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';

final _defaultApiClient = apiClient;

/// Тип будильника
enum AlarmType {
  medicine,
  vitamin;

  String get value {
    switch (this) {
      case AlarmType.medicine:
        return 'medicine';
      case AlarmType.vitamin:
        return 'vitamin';
    }
  }

  String get label {
    switch (this) {
      case AlarmType.medicine:
        return 'Лекарство';
      case AlarmType.vitamin:
        return 'Витамин';
    }
  }

  static AlarmType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'medicine':
        return AlarmType.medicine;
      case 'vitamin':
        return AlarmType.vitamin;
      default:
        return AlarmType.medicine;
    }
  }
}

/// Модель будильника
class Alarm {
  final int id;
  final int diaryId;
  final int creatorId;
  final String name;
  final AlarmType type;
  final List<int> daysOfWeek;
  final List<String> times;
  final String? dosage;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Alarm({
    required this.id,
    required this.diaryId,
    required this.creatorId,
    required this.name,
    required this.type,
    required this.daysOfWeek,
    required this.times,
    this.dosage,
    this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Создать экземпляр из JSON
  factory Alarm.fromJson(Map<String, dynamic> json) {
    return Alarm(
      id: json['id'] as int,
      diaryId: json['diary_id'] as int,
      creatorId: json['creator_id'] as int,
      name: json['name'] as String,
      type: AlarmType.fromString(json['type'] as String),
      daysOfWeek: (json['days_of_week'] as List<dynamic>)
          .map((e) => e as int)
          .toList(),
      times: (json['times'] as List<dynamic>).map((e) => e as String).toList(),
      dosage: json['dosage'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Преобразовать в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'diary_id': diaryId,
      'creator_id': creatorId,
      'name': name,
      'type': type.value,
      'days_of_week': daysOfWeek,
      'times': times,
      'dosage': dosage,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Создаёт копию будильника с изменёнными полями
  Alarm copyWith({
    int? id,
    int? diaryId,
    int? creatorId,
    String? name,
    AlarmType? type,
    List<int>? daysOfWeek,
    List<String>? times,
    String? dosage,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Alarm(
      id: id ?? this.id,
      diaryId: diaryId ?? this.diaryId,
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      type: type ?? this.type,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      times: times ?? this.times,
      dosage: dosage ?? this.dosage,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Получить строку с днями недели
  String get daysOfWeekLabel {
    const dayLabels = {
      1: 'ПН',
      2: 'ВТ',
      3: 'СР',
      4: 'ЧТ',
      5: 'ПТ',
      6: 'СБ',
      7: 'ВС',
    };

    if (daysOfWeek.length == 7) {
      return 'Каждый день';
    }

    final sortedDays = List<int>.from(daysOfWeek)..sort();
    return sortedDays.map((d) => dayLabels[d] ?? '').join(', ');
  }

  @override
  String toString() =>
      'Alarm(id: $id, name: $name, type: ${type.value}, isActive: $isActive)';
}

/// Репозиторий для работы с будильниками
class AlarmRepository {
  final ApiClient _apiClient;

  AlarmRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Получить все будильники дневника
  Future<List<Alarm>> getAlarms(int diaryId) async {
    try {
      log.d('Запрос списка будильников для дневника: $diaryId');

      final response = await _apiClient.get<List<dynamic>>(
        '/alarms',
        queryParameters: {'diary_id': diaryId},
      );

      final data = response.data;
      if (data == null) {
        return [];
      }

      final alarms = data
          .map((json) => Alarm.fromJson(json as Map<String, dynamic>))
          .toList();

      log.d('Получено ${alarms.length} будильников');
      return alarms;
    } catch (e) {
      log.e('Ошибка получения будильников: $e');
      rethrow;
    }
  }

  /// Получить один будильник по ID
  Future<Alarm> getAlarm(int alarmId) async {
    try {
      log.d('Запрос будильника: $alarmId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/alarms/$alarmId',
      );

      final data = response.data;
      if (data == null) {
        throw const NotFoundException('Будильник не найден');
      }

      return Alarm.fromJson(data);
    } catch (e) {
      log.e('Ошибка получения будильника: $e');
      rethrow;
    }
  }

  /// Создать новый будильник
  Future<Alarm> createAlarm({
    required int diaryId,
    required String name,
    required AlarmType type,
    required List<int> daysOfWeek,
    required List<String> times,
    String? dosage,
    String? notes,
    bool isActive = true,
  }) async {
    try {
      log.d('Создание будильника: $name');

      final requestData = {
        'diary_id': diaryId,
        'name': name,
        'type': type.value,
        'days_of_week': daysOfWeek,
        'times': times,
        'dosage': dosage,
        'notes': notes,
        'is_active': isActive,
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/alarms',
        data: requestData,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось создать будильник');
      }

      log.i('Будильник создан успешно');
      return Alarm.fromJson(data);
    } catch (e) {
      log.e('Ошибка создания будильника: $e');
      rethrow;
    }
  }

  /// Обновить будильник
  Future<Alarm> updateAlarm({
    required int alarmId,
    String? name,
    AlarmType? type,
    List<int>? daysOfWeek,
    List<String>? times,
    String? dosage,
    String? notes,
    bool? isActive,
  }) async {
    try {
      log.d('Обновление будильника: $alarmId');

      final requestData = <String, dynamic>{};
      if (name != null) requestData['name'] = name;
      if (type != null) requestData['type'] = type.value;
      if (daysOfWeek != null) requestData['days_of_week'] = daysOfWeek;
      if (times != null) requestData['times'] = times;
      if (dosage != null) requestData['dosage'] = dosage;
      if (notes != null) requestData['notes'] = notes;
      if (isActive != null) requestData['is_active'] = isActive;

      final response = await _apiClient.put<Map<String, dynamic>>(
        '/alarms/$alarmId',
        data: requestData,
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось обновить будильник');
      }

      log.i('Будильник обновлён успешно');
      return Alarm.fromJson(data);
    } catch (e) {
      log.e('Ошибка обновления будильника: $e');
      rethrow;
    }
  }

  /// Удалить будильник
  Future<void> deleteAlarm(int alarmId) async {
    try {
      log.d('Удаление будильника: $alarmId');

      await _apiClient.delete<Map<String, dynamic>>('/alarms/$alarmId');

      log.i('Будильник удалён успешно');
    } catch (e) {
      log.e('Ошибка удаления будильника: $e');
      rethrow;
    }
  }

  /// Переключить состояние будильника (включить/выключить)
  Future<Alarm> toggleAlarm(int alarmId) async {
    try {
      log.d('Переключение будильника: $alarmId');

      final response = await _apiClient.patch<Map<String, dynamic>>(
        '/alarms/$alarmId/toggle',
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Не удалось переключить будильник');
      }

      // API возвращает { id, is_active, message }
      // Нужно получить полные данные будильника
      final alarm = await getAlarm(alarmId);

      log.i(
        'Будильник переключён: ${data['is_active'] == true ? 'активен' : 'неактивен'}',
      );
      return alarm;
    } catch (e) {
      log.e('Ошибка переключения будильника: $e');
      rethrow;
    }
  }

  /// Отметить будильник как принятый
  Future<void> acceptAlarm(int alarmId) async {
    try {
      log.d('Принятие будильника: $alarmId');

      await _apiClient.post<Map<String, dynamic>>(
        '/alarms/$alarmId/accept',
        data: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      log.i('Будильник отмечен как принятый');
    } catch (e) {
      log.e('Ошибка принятия будильника: $e');
      rethrow;
    }
  }

  /// Отметить будильник как отклоненный
  Future<void> declineAlarm(int alarmId) async {
    try {
      log.d('Отклонение будильника: $alarmId');

      await _apiClient.post<Map<String, dynamic>>(
        '/alarms/$alarmId/decline',
        data: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      log.i('Будильник отмечен как отклоненный');
    } catch (e) {
      log.e('Ошибка отклонения будильника: $e');
      rethrow;
    }
  }
}
