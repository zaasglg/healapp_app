import 'package:equatable/equatable.dart';
import '../../repositories/employee_repository.dart';

abstract class EmployeeState extends Equatable {
  const EmployeeState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class EmployeeInitial extends EmployeeState {
  const EmployeeInitial();
}

/// Состояние загрузки
class EmployeeLoading extends EmployeeState {
  const EmployeeLoading();
}

/// Состояние успешной загрузки сотрудников и приглашений
class EmployeeLoaded extends EmployeeState {
  final List<Employee> employees;
  final List<Invitation> invitations;

  const EmployeeLoaded({required this.employees, required this.invitations});

  @override
  List<Object?> get props => [employees, invitations];

  /// Копирование с изменениями
  EmployeeLoaded copyWith({
    List<Employee>? employees,
    List<Invitation>? invitations,
  }) {
    return EmployeeLoaded(
      employees: employees ?? this.employees,
      invitations: invitations ?? this.invitations,
    );
  }
}

/// Состояние успешного создания приглашения
class InvitationCreated extends EmployeeState {
  final String inviteUrl;
  final Invitation invitation;

  const InvitationCreated({required this.inviteUrl, required this.invitation});

  @override
  List<Object?> get props => [inviteUrl, invitation];
}

/// Состояние успешного обновления роли
class EmployeeRoleUpdated extends EmployeeState {
  final Employee employee;

  const EmployeeRoleUpdated({required this.employee});

  @override
  List<Object?> get props => [employee];
}

/// Состояние успешного удаления сотрудника
class EmployeeDeleted extends EmployeeState {
  final int employeeId;

  const EmployeeDeleted({required this.employeeId});

  @override
  List<Object?> get props => [employeeId];
}

/// Состояние успешного удаления приглашения
class InvitationDeleted extends EmployeeState {
  final int invitationId;

  const InvitationDeleted({required this.invitationId});

  @override
  List<Object?> get props => [invitationId];
}

/// Состояние ошибки
class EmployeeFailure extends EmployeeState {
  final String message;

  const EmployeeFailure(this.message);

  @override
  List<Object?> get props => [message];
}
