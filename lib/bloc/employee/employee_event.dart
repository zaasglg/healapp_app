import 'package:equatable/equatable.dart';

abstract class EmployeeEvent extends Equatable {
  const EmployeeEvent();

  @override
  List<Object?> get props => [];
}

/// Событие загрузки списка сотрудников
class LoadEmployeesRequested extends EmployeeEvent {
  final String? roleFilter;

  const LoadEmployeesRequested({this.roleFilter});

  @override
  List<Object?> get props => [roleFilter];
}

/// Событие загрузки списка приглашений
class LoadInvitationsRequested extends EmployeeEvent {
  const LoadInvitationsRequested();
}

/// Событие создания приглашения
class CreateInvitationRequested extends EmployeeEvent {
  final String role;

  const CreateInvitationRequested({required this.role});

  @override
  List<Object?> get props => [role];
}

/// Событие удаления приглашения
class DeleteInvitationRequested extends EmployeeEvent {
  final int invitationId;

  const DeleteInvitationRequested({required this.invitationId});

  @override
  List<Object?> get props => [invitationId];
}

/// Событие изменения роли сотрудника
class UpdateEmployeeRoleRequested extends EmployeeEvent {
  final int employeeId;
  final String newRole;

  const UpdateEmployeeRoleRequested({
    required this.employeeId,
    required this.newRole,
  });

  @override
  List<Object?> get props => [employeeId, newRole];
}

/// Событие удаления сотрудника
class DeleteEmployeeRequested extends EmployeeEvent {
  final int employeeId;

  const DeleteEmployeeRequested({required this.employeeId});

  @override
  List<Object?> get props => [employeeId];
}
