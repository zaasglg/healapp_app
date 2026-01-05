import 'package:equatable/equatable.dart';
import '../../repositories/alarm_repository.dart';

/// Базовый класс для состояний будильника
abstract class AlarmState extends Equatable {
  const AlarmState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class AlarmInitial extends AlarmState {
  const AlarmInitial();
}

/// Состояние загрузки
class AlarmLoading extends AlarmState {
  const AlarmLoading();
}

/// Состояние успешной загрузки списка будильников
class AlarmsLoaded extends AlarmState {
  final List<Alarm> alarms;

  const AlarmsLoaded(this.alarms);

  @override
  List<Object?> get props => [alarms];
}

/// Состояние успешной загрузки одного будильника
class AlarmLoaded extends AlarmState {
  final Alarm alarm;

  const AlarmLoaded(this.alarm);

  @override
  List<Object?> get props => [alarm];
}

/// Состояние успешного создания будильника
class AlarmCreated extends AlarmState {
  final Alarm alarm;

  const AlarmCreated(this.alarm);

  @override
  List<Object?> get props => [alarm];
}

/// Состояние успешного обновления будильника
class AlarmUpdated extends AlarmState {
  final Alarm alarm;

  const AlarmUpdated(this.alarm);

  @override
  List<Object?> get props => [alarm];
}

/// Состояние успешного удаления будильника
class AlarmDeleted extends AlarmState {
  final int alarmId;

  const AlarmDeleted(this.alarmId);

  @override
  List<Object?> get props => [alarmId];
}

/// Состояние успешного переключения будильника
class AlarmToggled extends AlarmState {
  final Alarm alarm;

  const AlarmToggled(this.alarm);

  @override
  List<Object?> get props => [alarm];
}

/// Состояние ошибки
class AlarmError extends AlarmState {
  final String message;

  const AlarmError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Состояние операции в процессе (для индикатора на конкретном элементе)
class AlarmOperationInProgress extends AlarmState {
  final int? alarmId;
  final List<Alarm> alarms;

  const AlarmOperationInProgress({this.alarmId, this.alarms = const []});

  @override
  List<Object?> get props => [alarmId, alarms];
}
