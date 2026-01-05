import 'package:equatable/equatable.dart';
import '../../repositories/alarm_repository.dart';

/// Базовый класс для событий будильника
abstract class AlarmEvent extends Equatable {
  const AlarmEvent();

  @override
  List<Object?> get props => [];
}

/// Событие загрузки списка будильников
class LoadAlarms extends AlarmEvent {
  final int diaryId;

  const LoadAlarms(this.diaryId);

  @override
  List<Object?> get props => [diaryId];
}

/// Событие загрузки одного будильника
class LoadAlarm extends AlarmEvent {
  final int alarmId;

  const LoadAlarm(this.alarmId);

  @override
  List<Object?> get props => [alarmId];
}

/// Событие создания будильника
class CreateAlarm extends AlarmEvent {
  final int diaryId;
  final String name;
  final AlarmType type;
  final List<int> daysOfWeek;
  final List<String> times;
  final String? dosage;
  final String? notes;

  const CreateAlarm({
    required this.diaryId,
    required this.name,
    required this.type,
    required this.daysOfWeek,
    required this.times,
    this.dosage,
    this.notes,
  });

  @override
  List<Object?> get props => [
    diaryId,
    name,
    type,
    daysOfWeek,
    times,
    dosage,
    notes,
  ];
}

/// Событие обновления будильника
class UpdateAlarm extends AlarmEvent {
  final int alarmId;
  final String? name;
  final AlarmType? type;
  final List<int>? daysOfWeek;
  final List<String>? times;
  final String? dosage;
  final String? notes;

  const UpdateAlarm({
    required this.alarmId,
    this.name,
    this.type,
    this.daysOfWeek,
    this.times,
    this.dosage,
    this.notes,
  });

  @override
  List<Object?> get props => [
    alarmId,
    name,
    type,
    daysOfWeek,
    times,
    dosage,
    notes,
  ];
}

/// Событие удаления будильника
class DeleteAlarm extends AlarmEvent {
  final int alarmId;

  const DeleteAlarm(this.alarmId);

  @override
  List<Object?> get props => [alarmId];
}

/// Событие переключения состояния будильника
class ToggleAlarm extends AlarmEvent {
  final int alarmId;

  const ToggleAlarm(this.alarmId);

  @override
  List<Object?> get props => [alarmId];
}
