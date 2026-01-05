import 'package:equatable/equatable.dart';
import '../../repositories/diary_repository.dart';

/// Базовый класс для событий дневника
abstract class DiaryEvent extends Equatable {
  const DiaryEvent();

  @override
  List<Object?> get props => [];
}

/// Событие загрузки списка дневников
class LoadDiaries extends DiaryEvent {
  const LoadDiaries();
}

/// Событие создания дневника
class CreateDiary extends DiaryEvent {
  final int patientId;
  final List<PinnedParameter>? pinnedParameters;
  final Map<String, dynamic>? settings;

  const CreateDiary({
    required this.patientId,
    this.pinnedParameters,
    this.settings,
  });

  @override
  List<Object?> get props => [patientId, pinnedParameters, settings];
}

/// Событие загрузки дневника по ID
class LoadDiary extends DiaryEvent {
  final int diaryId;

  const LoadDiary(this.diaryId);

  @override
  List<Object?> get props => [diaryId];
}

/// Событие загрузки дневника пациента
class LoadDiaryByPatient extends DiaryEvent {
  final int patientId;

  const LoadDiaryByPatient(this.patientId);

  @override
  List<Object?> get props => [patientId];
}

/// Событие обновления закреплённых параметров
class UpdatePinnedParameters extends DiaryEvent {
  final int diaryId;
  final List<PinnedParameter> pinnedParameters;

  const UpdatePinnedParameters({
    required this.diaryId,
    required this.pinnedParameters,
  });

  @override
  List<Object?> get props => [diaryId, pinnedParameters];
}

/// Событие добавления записи в дневник
class AddDiaryEntry extends DiaryEvent {
  final int diaryId;
  final String parameterKey;
  final String value;
  final String? notes;
  final DateTime? recordedAt;

  const AddDiaryEntry({
    required this.diaryId,
    required this.parameterKey,
    required this.value,
    this.notes,
    this.recordedAt,
  });

  @override
  List<Object?> get props => [diaryId, parameterKey, value, notes, recordedAt];
}

/// Событие загрузки записей дневника
class LoadDiaryEntries extends DiaryEvent {
  final int diaryId;
  final String? parameterKey;
  final DateTime? fromDate;
  final DateTime? toDate;

  const LoadDiaryEntries({
    required this.diaryId,
    this.parameterKey,
    this.fromDate,
    this.toDate,
  });

  @override
  List<Object?> get props => [diaryId, parameterKey, fromDate, toDate];
}

/// Событие удаления записи из дневника
class DeleteDiaryEntry extends DiaryEvent {
  final int diaryId;
  final int entryId;

  const DeleteDiaryEntry({required this.diaryId, required this.entryId});

  @override
  List<Object?> get props => [diaryId, entryId];
}

/// Событие удаления дневника
class DeleteDiary extends DiaryEvent {
  final int diaryId;

  const DeleteDiary(this.diaryId);

  List<Object?> get props => [diaryId];
}

/// Сохранить настройки закрепленных показателей (V2)
class SavePinnedParameters extends DiaryEvent {
  final int patientId;
  final List<PinnedParameter> pinnedParameters;

  const SavePinnedParameters({
    required this.patientId,
    required this.pinnedParameters,
  });

  @override
  List<Object?> get props => [patientId, pinnedParameters];
}

/// Создать замер (V2)
class CreateMeasurement extends DiaryEvent {
  final int patientId;
  final String type;
  final String key;
  final dynamic value;
  final DateTime recordedAt;

  final String? notes;

  const CreateMeasurement({
    required this.patientId,
    required this.type,
    required this.key,
    required this.value,
    this.notes,
    required this.recordedAt,
  });

  @override
  List<Object?> get props => [patientId, type, key, value, notes, recordedAt];
}

/// Обновить запись в дневнике
class UpdateDiaryEntry extends DiaryEvent {
  final int entryId;
  final dynamic value;
  final String? notes;
  final DateTime? recordedAt;

  const UpdateDiaryEntry({
    required this.entryId,
    this.value,
    this.notes,
    this.recordedAt,
  });

  @override
  List<Object?> get props => [entryId, value, notes, recordedAt];
}