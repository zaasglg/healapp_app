import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';
import 'patient_repository.dart';

final _defaultApiClient = apiClient;

/// Модель для закреплённого параметра
class PinnedParameter {
  final String key;
  final int intervalMinutes;
  final List<String> times;
  final Map<String, dynamic>? settings;
  final DateTime? lastRecordedAt;

  const PinnedParameter({
    required this.key,
    this.intervalMinutes = 60, // По умолчанию каждый час (минимум 1)
    this.times = const [],
    this.settings,
    this.lastRecordedAt,
  });

  factory PinnedParameter.fromJson(Map<String, dynamic> json) {
    final intervalMinutes = json['interval_minutes'] as int? ?? 60;
    return PinnedParameter(
      key: (json['key'] as String?) ?? '',
      intervalMinutes: intervalMinutes < 1
          ? 60
          : intervalMinutes, // Минимум 1 минута
      times:
          (json['times'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      settings: json['settings'] as Map<String, dynamic>?,
      lastRecordedAt: json['last_recorded_at'] != null
          ? DateTime.parse(json['last_recorded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'interval_minutes': intervalMinutes,
      'times': times,
      if (settings != null) 'settings': settings,
      if (lastRecordedAt != null)
        'last_recorded_at': lastRecordedAt!.toIso8601String(),
    };
  }

  /// Получить читаемое название параметра
  String get label {
    switch (key) {
      case 'blood_pressure':
        return 'Давление';
      case 'temperature':
        return 'Температура';
      case 'pulse':
        return 'Пульс';
      case 'blood_sugar':
        return 'Сахар крови';
      case 'weight':
        return 'Вес';
      case 'oxygen_saturation':
        return 'Сатурация';
      case 'walk':
        return 'Прогулка';
      case 'cognitive_games':
        return 'Когнитивные игры';
      case 'diaper_change':
        return 'Смена подгузника';
      case 'hygiene':
        return 'Гигиена';
      case 'skin_moisturizing':
        return 'Увлажнение кожи';
      case 'meal':
        return 'Прием пищи';
      case 'medication':
        return 'Лекарства';
      case 'vitamins':
        return 'Витамины';
      case 'sleep':
        return 'Сон';
      case 'respiratory_rate':
        return 'Частота дыхания';
      case 'pain_level':
        return 'Уровень боли';
      case 'urine':
        return 'Мочеиспускание';
      case 'defecation':
        return 'Дефекация';
      case 'urine_output':
        return 'Диурез';
      case 'fluid_intake':
        return 'Потребление жидкости';
      default:
        return key;
    }
  }

  /// Получить интервал в читаемом формате
  String get intervalLabel {
    if (intervalMinutes <= 0) {
      return 'не установлен';
    } else if (intervalMinutes < 60) {
      return 'каждые $intervalMinutes мин';
    } else if (intervalMinutes == 60) {
      return 'каждый час';
    } else if (intervalMinutes < 1440) {
      final hours = intervalMinutes ~/ 60;
      return 'каждые $hours ч';
    } else {
      final days = intervalMinutes ~/ 1440;
      return 'каждые $days дн';
    }
  }

  /// Получить статус показателя (ожидает/просрочено)
  PinnedParameterStatus get status {
    if (lastRecordedAt == null) {
      return PinnedParameterStatus.overdue;
    }

    final nextMeasurementTime = lastRecordedAt!.add(
      Duration(minutes: intervalMinutes),
    );
    final difference = nextMeasurementTime.difference(DateTime.now());

    if (difference.isNegative) {
      return PinnedParameterStatus.overdue;
    } else {
      return PinnedParameterStatus.pending;
    }
  }

  /// Получить время до следующего измерения
  Duration? get timeUntilNext {
    if (lastRecordedAt == null) {
      return null;
    }

    final nextMeasurementTime = lastRecordedAt!.add(
      Duration(minutes: intervalMinutes),
    );
    final difference = nextMeasurementTime.difference(DateTime.now());

    return difference.isNegative ? null : difference;
  }

  /// Получить время просрочки
  Duration? get overdueTime {
    if (lastRecordedAt == null) {
      return null;
    }

    final nextMeasurementTime = lastRecordedAt!.add(
      Duration(minutes: intervalMinutes),
    );
    final difference = DateTime.now().difference(nextMeasurementTime);

    return difference.isNegative ? null : difference;
  }

  /// Получить текст для отображения таймера
  String get timerText {
    if (lastRecordedAt == null) {
      return 'Требуется замер';
    }

    final time = timeUntilNext;
    if (time == null) {
      final overdue = overdueTime;
      if (overdue == null) return 'Просрочено';

      final hours = overdue.inHours;
      final minutes = overdue.inMinutes % 60;

      if (hours > 0) {
        return 'Просрочено на $hours ч $minutes мин';
      } else {
        return 'Просрочено на $minutes мин';
      }
    }

    final hours = time.inHours;
    final minutes = time.inMinutes % 60;

    if (hours > 0) {
      return 'Через $hours ч $minutes мин';
    } else {
      return 'Через $minutes мин';
    }
  }

  /// Получить последнее значение показателя из записей дневника
  String? getLastValue(List<DiaryEntry> entries) {
    // Фильтруем записи по ключу параметра
    final relevantEntries = entries
        .where((entry) => entry.parameterKey == key)
        .toList();

    if (relevantEntries.isEmpty) {
      return null;
    }

    // Сортируем по времени записи (последняя запись первой)
    relevantEntries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return relevantEntries.first.value;
  }

  /// Форматировать значение для отображения в кружке
  String formatValueForDisplay(String? value) {
    if (value == null) return '—';

    try {
      // Для давления (blood_pressure)
      if (key == 'blood_pressure') {
        // Значение может быть в формате "120/80"
        if (value.contains('/')) {
          return value; // Уже в нужном формате
        }
        // Иначе возвращаем как есть
        return value;
      }

      // Для температуры (temperature)
      if (key == 'temperature') {
        try {
          final temp = double.parse(value);
          return temp.toStringAsFixed(1);
        } catch (e) {
          return value;
        }
      }

      // Для пульса (pulse)
      if (key == 'pulse') {
        try {
          final pulse = int.parse(value);
          return pulse.toString();
        } catch (e) {
          return value;
        }
      }

      // Для сахара крови (blood_sugar)
      if (key == 'blood_sugar') {
        try {
          final sugar = double.parse(value);
          return sugar.toStringAsFixed(1);
        } catch (e) {
          return value;
        }
      }

      // Для веса (weight)
      if (key == 'weight') {
        try {
          final weight = double.parse(value);
          return weight.toStringAsFixed(1);
        } catch (e) {
          return value;
        }
      }

      // Для сатурации (oxygen_saturation)
      if (key == 'oxygen_saturation') {
        try {
          final saturation = int.parse(value);
          return '$saturation%';
        } catch (e) {
          return value;
        }
      }

      // По умолчанию возвращаем как есть
      return value;
    } catch (e) {
      return '—';
    }
  }

  @override
  String toString() =>
      'PinnedParameter(key: $key, interval: $intervalMinutes min, lastRecorded: $lastRecordedAt)';
}

enum PinnedParameterStatus {
  pending, // Ожидает (время еще не пришло)
  overdue, // Просрочено (время вышло)
}

/// Модель записи дневника
class DiaryEntry {
  final int id;
  final int diaryId;
  final String parameterKey;
  final dynamic value; // Changed from String to dynamic
  final String? notes;
  final DateTime recordedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiaryEntry({
    required this.id,
    required this.diaryId,
    required this.parameterKey,
    required this.value,
    this.notes,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as int,
      diaryId: json['diary_id'] as int,
      parameterKey: (json['parameter_key'] ?? json['key'] ?? '').toString(),
      value: json['value'], // Keep original type
      notes: json['notes'] as String?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'diary_id': diaryId,
      'parameter_key': parameterKey,
      'value': value,
      'notes': notes,
      'recorded_at': recordedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'DiaryEntry(id: $id, key: $parameterKey, value: $value)';
}

/// Модель дневника пациента
class Diary {
  final int id;
  final int patientId;
  final Patient? patient;
  final List<PinnedParameter> pinnedParameters;
  final Map<String, dynamic>? settings;
  final List<DiaryEntry> entries;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Diary({
    required this.id,
    required this.patientId,
    this.patient,
    required this.pinnedParameters,
    this.settings,
    required this.entries,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Получить имя пациента (удобное свойство)
  String get patientName => patient?.fullName ?? 'Пациент #$patientId';

  /// Получить возраст пациента (удобное свойство)
  int? get patientAge => patient?.age;

  factory Diary.fromJson(Map<String, dynamic> json) {
    // Парсим вложенный объект patient
    Patient? patient;
    final patientJson = json['patient'];
    if (patientJson is Map<String, dynamic>) {
      patient = Patient.fromJson(patientJson);
    }

    return Diary(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      patient: patient,
      pinnedParameters:
          (json['pinned_parameters'] as List<dynamic>?)
              ?.map((e) => PinnedParameter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      settings: json['settings'] as Map<String, dynamic>?,
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'patient': patient?.toJson(),
      'pinned_parameters': pinnedParameters.map((e) => e.toJson()).toList(),
      'settings': settings,
      'entries': entries.map((e) => e.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Создаёт копию дневника с изменёнными полями
  Diary copyWith({
    int? id,
    int? patientId,
    Patient? patient,
    List<PinnedParameter>? pinnedParameters,
    Map<String, dynamic>? settings,
    List<DiaryEntry>? entries,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Diary(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patient: patient ?? this.patient,
      pinnedParameters: pinnedParameters ?? this.pinnedParameters,
      settings: settings ?? this.settings,
      entries: entries ?? this.entries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'Diary(id: $id, patientId: $patientId, entries: ${entries.length})';
}

/// Результат создания дневника (может вернуть конфликт)
sealed class CreateDiaryResult {}

/// Дневник успешно создан
class DiaryCreated extends CreateDiaryResult {
  final Diary diary;
  DiaryCreated(this.diary);
}

/// Дневник уже существует (409 Conflict)
class DiaryAlreadyExists extends CreateDiaryResult {
  final String message;
  final int existingDiaryId;
  DiaryAlreadyExists(this.message, this.existingDiaryId);
}

/// Репозиторий для работы с дневниками
class DiaryRepository {
  final ApiClient _apiClient;

  DiaryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Создать новый дневник для пациента
  ///
  /// Возвращает [DiaryCreated] при успешном создании (201)
  /// или [DiaryAlreadyExists] если дневник уже существует (409)
  Future<CreateDiaryResult> createDiary({
    required int patientId,
    List<PinnedParameter>? pinnedParameters,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final response = await _apiClient.post(
        '/diary/create',
        data: {
          'patient_id': patientId,
          'pinned_parameters':
              pinnedParameters?.map((e) => e.toJson()).toList() ?? [],
          'settings': settings,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return DiaryCreated(Diary.fromJson(data));
    } on ConflictException catch (e) {
      // Обработка 409 Conflict — дневник уже существует
      final diaryId = e.getData<int>('diary_id') ?? 0;
      return DiaryAlreadyExists(
        e.message.isNotEmpty
            ? e.message
            : 'Дневник для этого пациента уже существует',
        diaryId,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при создании дневника: ${e.toString()}');
    }
  }

  /// Получить список всех дневников
  Future<List<Diary>> getDiaries() async {
    try {
      log.d('DiaryRepository: Запрос GET /diary');
      log.d('DiaryRepository: BaseURL: ${ApiConfig.baseUrl}');
      log.d('DiaryRepository: Full URL: ${ApiConfig.baseUrl}/diary');
      final response = await _apiClient.get('/diary');
      log.d('DiaryRepository: Ответ получен, статус: ${response.statusCode}');
      final data = response.data;
      log.d('DiaryRepository: Тип данных: ${data.runtimeType}');
      if (data is List) {
        log.d('DiaryRepository: Количество дневников: ${data.length}');
        return data
            .map((e) => Diary.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      log.w('DiaryRepository: Данные не являются списком: $data');
      return [];
    } on ApiException catch (e) {
      log.e(
        'DiaryRepository: ApiException - ${e.runtimeType}: ${e.message}, statusCode: ${e.statusCode}',
      );
      rethrow;
    } catch (e, stackTrace) {
      log.e('DiaryRepository: Неизвестная ошибка: $e');
      log.e('DiaryRepository: StackTrace: $stackTrace');
      throw ServerException('Ошибка при получении дневников: ${e.toString()}');
    }
  }

  /// Получить дневник по ID
  Future<Diary> getDiary(int diaryId) async {
    try {
      final response = await _apiClient.get('/diary/$diaryId');
      final data = response.data as Map<String, dynamic>;
      return Diary.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении дневника: ${e.toString()}');
    }
  }

  /// Получить дневник пациента по ID пациента
  Future<Diary?> getDiaryByPatientId(int patientId) async {
    try {
      final response = await _apiClient.get('/diary/patient/$patientId');
      final data = response.data as Map<String, dynamic>;
      return Diary.fromJson(data);
    } on NotFoundException {
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении дневника: ${e.toString()}');
    }
  }

  /// Обновить закреплённые параметры дневника
  Future<Diary> updatePinnedParameters(
    int diaryId,
    List<PinnedParameter> pinnedParameters,
  ) async {
    try {
      // Новый API: PATCH /diary/pinned expects patient_id and pinned_parameters.
      // Получаем дневник по diaryId, чтобы узнать patientId
      final diary = await getDiary(diaryId);

      await savePinnedParameters(
        patientId: diary.patientId,
        pinnedParameters: pinnedParameters,
      );

      // После сохранения получаем обновлённый дневник и возвращаем его
      final updatedDiary = await getDiary(diaryId);
      return updatedDiary;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при обновлении параметров: ${e.toString()}',
      );
    }
  }

  /// Добавить запись в дневник
  Future<DiaryEntry> addEntry({
    required int diaryId,
    required String parameterKey,
    required String value,
    String? notes,
    DateTime? recordedAt,
  }) async {
    try {
      final response = await _apiClient.post(
        '/diary/$diaryId/entries',
        data: {
          'parameter_key': parameterKey,
          'value': value,
          'notes': notes,
          'recorded_at': (recordedAt ?? DateTime.now()).toIso8601String(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      return DiaryEntry.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при добавлении записи: ${e.toString()}');
    }
  }

  /// Получить записи дневника
  Future<List<DiaryEntry>> getEntries(
    int diaryId, {
    String? parameterKey,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (parameterKey != null) queryParams['parameter_key'] = parameterKey;
      if (fromDate != null) queryParams['from'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to'] = toDate.toIso8601String();

      final response = await _apiClient.get(
        '/diary/$diaryId/entries',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении записей: ${e.toString()}');
    }
  }

  /// Обновить запись в дневнике
  Future<DiaryEntry> updateEntry({
    required int entryId,
    dynamic value,
    String? notes,
    DateTime? recordedAt,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (value != null) {
        data['value'] = value is Map ? value : {'value': value};
      }
      if (notes != null) {
        data['notes'] = notes;
      }
      if (recordedAt != null) {
        data['recorded_at'] = recordedAt.toIso8601String();
      }

      final response = await _apiClient.put(
        '/diary/entries/$entryId',
        data: data,
      );
      final responseData = response.data as Map<String, dynamic>;
      return DiaryEntry.fromJson(responseData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при обновлении записи: ${e.toString()}');
    }
  }

  /// Удалить запись из дневника
  Future<void> deleteEntry(int diaryId, int entryId) async {
    try {
      await _apiClient.delete('/diary/$diaryId/entries/$entryId');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при удалении записи: ${e.toString()}');
    }
  }

  /// Удалить дневник
  Future<void> deleteDiary(int diaryId) async {
    try {
      await _apiClient.delete('/diary/$diaryId');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при удалении дневника: ${e.toString()}');
    }
  }

  /// Синхронизировать набор записей дневника через API v2
  /// PUT /diary/{id}/entries/sync
  /// Принимает массив объектов по правилам API: обновление, создание и удаление.
  /// Возвращает распарсенный JSON-ответ сервера (message, created, updated, deleted, entries)
  Future<Map<String, dynamic>> syncEntries({
    required int diaryId,
    required List<Map<String, dynamic>> entries,
    bool deleteMissing = false,
  }) async {
    try {
      final response = await _apiClient.put(
        '/diary/$diaryId/entries/sync',
        data: {
          'entries': entries,
          'delete_missing': deleteMissing,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при синхронизации записей: ${e.toString()}');
    }
  }

  /// Сохранить настройки закрепленных показателей (API v2)
  Future<void> savePinnedParameters({
    required int patientId,
    required List<PinnedParameter> pinnedParameters,
  }) async {
    try {
      await _apiClient.patch(
        '/diary/pinned',
        data: {
          'patient_id': patientId,
          'pinned_parameters': pinnedParameters.map((p) {
            // Отправляем полный объект с times и label
            return {
              'key': p.key,
              'interval_minutes': p.intervalMinutes < 1
                  ? 60
                  : p.intervalMinutes,
              'times': p.times,
              'label': p.label,
            };
          }).toList(),
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при сохранении параметров: ${e.toString()}',
      );
    }
  }

  /// Создать запись в дневнике (API v2)
  /// Возвращает созданную запись для локального обновления UI без перезагрузки
  Future<DiaryEntry> createMeasurement({
    required int patientId,
    required String type,
    required String key,
    required dynamic value,
    String? notes,
    required DateTime recordedAt,
  }) async {
    try {
      final response = await _apiClient.post(
        '/diary',
        data: {
          'patient_id': patientId,
          'type': type,
          'key': key,
          'value': value,
          'notes': notes,
          'recorded_at': recordedAt.toIso8601String(),
        },
      );

      // Если сервер возвращает созданную запись, парсим её
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return DiaryEntry.fromJson(data);
      }

      // Если сервер не возвращает данные, создаём временную запись
      // с временным ID для локального обновления UI
      final now = DateTime.now();
      return DiaryEntry(
        id: now.millisecondsSinceEpoch, // временный ID
        diaryId: 0, // будет обновлён при следующей загрузке
        parameterKey: key,
        value: value,
        notes: notes,
        recordedAt: recordedAt,
        createdAt: now,
        updatedAt: now,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при создании записи: ${e.toString()}');
    }
  }
}
