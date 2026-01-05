import 'package:equatable/equatable.dart';
import '../../repositories/patient_repository.dart';

/// Базовый класс для состояний пациентов
abstract class PatientState extends Equatable {
  const PatientState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class PatientInitial extends PatientState {
  const PatientInitial();
}

/// Состояние загрузки
class PatientLoading extends PatientState {
  const PatientLoading();
}

/// Состояние успешной загрузки списка пациентов
class PatientLoaded extends PatientState {
  final List<Patient> patients;

  const PatientLoaded(this.patients);

  @override
  List<Object?> get props => [patients];
}

/// Состояние ошибки
class PatientError extends PatientState {
  final String message;

  const PatientError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Состояние успешного создания пациента
class PatientCreated extends PatientState {
  final Patient patient;

  const PatientCreated(this.patient);

  @override
  List<Object?> get props => [patient];
}

/// Состояние успешного обновления пациента
class PatientUpdated extends PatientState {
  final Patient patient;

  const PatientUpdated(this.patient);

  @override
  List<Object?> get props => [patient];
}

/// Состояние успешного удаления
class PatientDeleted extends PatientState {
  final int patientId;

  const PatientDeleted(this.patientId);

  @override
  List<Object?> get props => [patientId];
}
