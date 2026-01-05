import 'package:equatable/equatable.dart';

/// Базовый класс для событий пациентов
abstract class PatientEvent extends Equatable {
  const PatientEvent();

  @override
  List<Object?> get props => [];
}

/// Событие загрузки списка пациентов
class LoadPatients extends PatientEvent {
  final bool forceRefresh;

  const LoadPatients({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

/// Событие обновления списка пациентов
class RefreshPatients extends PatientEvent {
  const RefreshPatients();
}

/// Событие создания нового пациента
class CreatePatient extends PatientEvent {
  final Map<String, dynamic> patientData;

  const CreatePatient(this.patientData);

  @override
  List<Object?> get props => [patientData];
}

/// Событие обновления пациента
class UpdatePatient extends PatientEvent {
  final int patientId;
  final Map<String, dynamic> patientData;

  const UpdatePatient(this.patientId, this.patientData);

  @override
  List<Object?> get props => [patientId, patientData];
}

/// Событие удаления пациента
class DeletePatient extends PatientEvent {
  final int patientId;

  const DeletePatient(this.patientId);

  @override
  List<Object?> get props => [patientId];
}
