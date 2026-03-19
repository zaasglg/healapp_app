import 'patient.dart';

/// Константа: читаемые названия параметров дневника
const Map<String, String> kParameterLabels = {
  'blood_pressure': 'Давление',
  'temperature': 'Температура',
  'pulse': 'Пульс',
  'blood_sugar': 'Сахар крови',
  'weight': 'Вес',
  'oxygen_saturation': 'Сатурация',
  'walk': 'Прогулка',
  'cognitive_games': 'Когнитивные игры',
  'diaper_change': 'Смена подгузника',
  'hygiene': 'Гигиена',
  'skin_moisturizing': 'Увлажнение кожи',
  'meal': 'Прием пищи',
  'medication': 'Лекарства',
  'vitamins': 'Витамины',
  'sleep': 'Сон',
  'respiratory_rate': 'Частота дыхания',
  'pain_level': 'Уровень боли',
  'urine': 'Мочеиспускание',
  'defecation': 'Дефекация',
  'urine_output': 'Диурез',
  'fluid_intake': 'Потребление жидкости',
};

enum PinnedParameterStatus {
  pending,
  overdue,
}

/// Модель для закреплённого параметра
class PinnedParameter {
  final String key;
  final int intervalMinutes;
  final List<String> times;
  final Map<String, dynamic>? settings;
  final DateTime? lastRecordedAt;

  const PinnedParameter({
    required this.key,
    this.intervalMinutes = 60,
    this.times = const [],
    this.settings,
    this.lastRecordedAt,
  });

  factory PinnedParameter.fromJson(Map<String, dynamic> json) {
    final intervalMinutes = json['interval_minutes'] as int? ?? 60;
    return PinnedParameter(
      key: (json['key'] as String?) ?? '',
      intervalMinutes: intervalMinutes < 1 ? 60 : intervalMinutes,
      times: (json['times'] as List<dynamic>?)
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
  String get label => kParameterLabels[key] ?? key;

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

    return difference.isNegative
        ? PinnedParameterStatus.overdue
        : PinnedParameterStatus.pending;
  }

  /// Получить время до следующего измерения
  Duration? get timeUntilNext {
    if (lastRecordedAt == null) return null;

    final nextMeasurementTime = lastRecordedAt!.add(
      Duration(minutes: intervalMinutes),
    );
    final difference = nextMeasurementTime.difference(DateTime.now());

    return difference.isNegative ? null : difference;
  }

  /// Получить время просрочки
  Duration? get overdueTime {
    if (lastRecordedAt == null) return null;

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
    final relevantEntries = entries
        .where((entry) => entry.parameterKey == key)
        .toList();

    if (relevantEntries.isEmpty) return null;

    relevantEntries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return relevantEntries.first.displayValue;
  }

  /// Форматировать значение для отображения в кружке
  String formatValueForDisplay(String? value) {
    if (value == null) return '—';

    try {
      if (key == 'blood_pressure') {
        return value;
      }

      if (key == 'temperature') {
        final temp = double.tryParse(value);
        return temp != null ? temp.toStringAsFixed(1) : value;
      }

      if (key == 'pulse') {
        final pulse = int.tryParse(value);
        return pulse != null ? pulse.toString() : value;
      }

      if (key == 'blood_sugar') {
        final sugar = double.tryParse(value);
        return sugar != null ? sugar.toStringAsFixed(1) : value;
      }

      if (key == 'weight') {
        final weight = double.tryParse(value);
        return weight != null ? weight.toStringAsFixed(1) : value;
      }

      if (key == 'oxygen_saturation') {
        final saturation = int.tryParse(value);
        return saturation != null ? '$saturation%' : value;
      }

      return value;
    } catch (e) {
      return '—';
    }
  }

  @override
  String toString() =>
      'PinnedParameter(key: $key, interval: $intervalMinutes min, lastRecorded: $lastRecordedAt)';
}

/// Модель записи дневника
class DiaryEntry {
  final int id;
  final int diaryId;
  final String parameterKey;
  final Map<String, dynamic> value;
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

  /// Получить строковое представление значения для отображения
  String get displayValue {
    if (value.containsKey('value')) {
      return value['value']?.toString() ?? '—';
    }
    if (value.isNotEmpty) {
      return value.values.first?.toString() ?? '—';
    }
    return '—';
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final rawValue = json['value'];
    Map<String, dynamic> value;

    if (rawValue is Map<String, dynamic>) {
      value = rawValue;
    } else if (rawValue != null) {
      value = {'value': rawValue};
    } else {
      value = {};
    }

    return DiaryEntry(
      id: json['id'] as int,
      diaryId: json['diary_id'] as int,
      parameterKey: (json['parameter_key'] ?? json['key'] ?? '').toString(),
      value: value,
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
  String toString() =>
      'DiaryEntry(id: $id, key: $parameterKey, value: $value)';
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

  /// Получить имя пациента
  String get patientName => patient?.fullName ?? 'Пациент #$patientId';

  /// Получить возраст пациента
  int? get patientAge => patient?.age;

  factory Diary.fromJson(Map<String, dynamic> json) {
    Patient? patient;
    final patientJson = json['patient'];
    if (patientJson is Map<String, dynamic>) {
      patient = Patient.fromJson(patientJson);
    }

    return Diary(
      id: json['id'] as int,
      patientId: json['patient_id'] as int,
      patient: patient,
      pinnedParameters: (json['pinned_parameters'] as List<dynamic>?)
              ?.map((e) => PinnedParameter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      settings: json['settings'] as Map<String, dynamic>?,
      entries: (json['entries'] as List<dynamic>?)
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

/// Клиент-владелец дневника
class DiaryClient {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? type;
  final String? accountType;

  const DiaryClient({
    required this.id,
    this.firstName,
    this.lastName,
    this.phone,
    this.type,
    this.accountType,
  });

  String get fullName {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    return parts.isNotEmpty ? parts.join(' ') : 'Без имени';
  }

  factory DiaryClient.fromJson(Map<String, dynamic> json) {
    return DiaryClient(
      id: json['id'] as int,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      type: json['type'] as String?,
      accountType: json['account_type'] as String?,
    );
  }
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
