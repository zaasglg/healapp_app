import 'package:equatable/equatable.dart';
import '../../repositories/diary_repository.dart';

/// Базовый класс для состояний дневника
abstract class DiaryState extends Equatable {
  const DiaryState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class DiaryInitial extends DiaryState {
  const DiaryInitial();
}

/// Состояние загрузки
class DiaryLoading extends DiaryState {
  const DiaryLoading();
}

/// Состояние успешной загрузки списка дневников
class DiariesLoaded extends DiaryState {
  final List<Diary> diaries;

  const DiariesLoaded(this.diaries);

  @override
  List<Object?> get props => [diaries];
}

/// Состояние успешной загрузки дневника
class DiaryLoaded extends DiaryState {
  final Diary diary;

  const DiaryLoaded(this.diary);

  @override
  List<Object?> get props => [diary];
}

/// Состояние когда дневник не найден
class DiaryNotFound extends DiaryState {
  final int patientId;

  const DiaryNotFound(this.patientId);

  @override
  List<Object?> get props => [patientId];
}

/// Состояние успешного создания дневника
class DiaryCreatedState extends DiaryState {
  final Diary diary;

  const DiaryCreatedState(this.diary);

  @override
  List<Object?> get props => [diary];
}

/// Состояние когда дневник уже существует (409 Conflict)
class DiaryConflict extends DiaryState {
  final String message;
  final int existingDiaryId;

  const DiaryConflict(this.message, this.existingDiaryId);

  @override
  List<Object?> get props => [message, existingDiaryId];
}

/// Состояние успешного обновления параметров
class DiaryParametersUpdated extends DiaryState {
  final Diary diary;

  const DiaryParametersUpdated(this.diary);

  @override
  List<Object?> get props => [diary];
}

/// Состояние успешного добавления записи
class DiaryEntryAdded extends DiaryState {
  final DiaryEntry entry;

  const DiaryEntryAdded(this.entry);

  @override
  List<Object?> get props => [entry];
}

/// Состояние загруженных записей
class DiaryEntriesLoaded extends DiaryState {
  final List<DiaryEntry> entries;

  const DiaryEntriesLoaded(this.entries);

  @override
  List<Object?> get props => [entries];
}

/// Состояние успешного удаления записи
class DiaryEntryDeleted extends DiaryState {
  final int entryId;

  const DiaryEntryDeleted(this.entryId);

  @override
  List<Object?> get props => [entryId];
}

/// Состояние успешного удаления дневника
class DiaryDeleted extends DiaryState {
  final int diaryId;

  const DiaryDeleted(this.diaryId);

  @override
  List<Object?> get props => [diaryId];
}

/// Состояние ошибки
class DiaryError extends DiaryState {
  final String message;

  const DiaryError(this.message);

  @override
  List<Object?> get props => [message];
}
