import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/employee_repository.dart';
import '../../core/network/api_exceptions.dart';
import '../../utils/app_logger.dart';
import 'employee_event.dart';
import 'employee_state.dart';

class EmployeeBloc extends Bloc<EmployeeEvent, EmployeeState> {
  final EmployeeRepository _employeeRepository;

  // Кэшируем данные для быстрого возврата к EmployeeLoaded
  List<Employee> _cachedEmployees = [];
  List<Invitation> _cachedInvitations = [];

  EmployeeBloc({EmployeeRepository? employeeRepository})
    : _employeeRepository = employeeRepository ?? EmployeeRepository(),
      super(const EmployeeInitial()) {
    on<LoadEmployeesRequested>(_onLoadEmployeesRequested);
    on<LoadInvitationsRequested>(_onLoadInvitationsRequested);
    on<CreateInvitationRequested>(_onCreateInvitationRequested);
    on<DeleteInvitationRequested>(_onDeleteInvitationRequested);
    on<UpdateEmployeeRoleRequested>(_onUpdateEmployeeRoleRequested);
    on<DeleteEmployeeRequested>(_onDeleteEmployeeRequested);
  }

  /// Загрузка списка сотрудников
  Future<void> _onLoadEmployeesRequested(
    LoadEmployeesRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(const EmployeeLoading());

    try {
      log.d('Загрузка сотрудников...');

      // Загружаем сотрудников и приглашения параллельно
      final results = await Future.wait([
        _employeeRepository.getEmployees(role: event.roleFilter),
        _employeeRepository.getInvitations(status: 'pending'),
      ]);

      _cachedEmployees = results[0] as List<Employee>;
      _cachedInvitations = results[1] as List<Invitation>;

      log.i(
        'Загружено ${_cachedEmployees.length} сотрудников и ${_cachedInvitations.length} приглашений',
      );

      emit(
        EmployeeLoaded(
          employees: _cachedEmployees,
          invitations: _cachedInvitations,
        ),
      );
    } on UnauthorizedException {
      log.e('Ошибка авторизации');
      emit(const EmployeeFailure('Требуется авторизация'));
    } on ForbiddenException catch (e) {
      log.e('Недостаточно прав: ${e.message}');
      emit(EmployeeFailure('Недостаточно прав: ${e.message}'));
    } on NetworkException catch (e) {
      log.e('Ошибка сети: ${e.message}');
      emit(EmployeeFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('Ошибка сервера: ${e.message}');
      emit(EmployeeFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(EmployeeFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const EmployeeFailure('Неизвестная ошибка'));
    }
  }

  /// Загрузка только приглашений
  Future<void> _onLoadInvitationsRequested(
    LoadInvitationsRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    try {
      log.d('Загрузка приглашений...');

      _cachedInvitations = await _employeeRepository.getInvitations();

      log.i('Загружено ${_cachedInvitations.length} приглашений');

      emit(
        EmployeeLoaded(
          employees: _cachedEmployees,
          invitations: _cachedInvitations,
        ),
      );
    } on ApiException catch (e) {
      log.e('Ошибка при загрузке приглашений: ${e.message}');
      emit(EmployeeFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const EmployeeFailure('Неизвестная ошибка'));
    }
  }

  /// Создание приглашения
  Future<void> _onCreateInvitationRequested(
    CreateInvitationRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(const EmployeeLoading());

    try {
      log.d('Создание приглашения для роли: ${event.role}');

      final response = await _employeeRepository.createEmployeeInvitation(
        role: event.role,
      );

      final invitationData = response['invitation'] as Map<String, dynamic>;
      final inviteUrl = response['invite_url'] as String;

      final invitation = Invitation.fromJson({
        ...invitationData,
        'invite_url': inviteUrl,
      });

      // Добавляем в кэш
      _cachedInvitations = [..._cachedInvitations, invitation];

      log.i('Приглашение создано: $inviteUrl');

      emit(InvitationCreated(inviteUrl: inviteUrl, invitation: invitation));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.message}');
      emit(
        EmployeeFailure(
          e.getAllErrors().isNotEmpty ? e.getAllErrors().join(', ') : e.message,
        ),
      );
    } on ForbiddenException catch (e) {
      log.e('Недостаточно прав: ${e.message}');
      emit(EmployeeFailure('Недостаточно прав для создания приглашения'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(EmployeeFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const EmployeeFailure('Неизвестная ошибка'));
    }
  }

  /// Удаление приглашения
  Future<void> _onDeleteInvitationRequested(
    DeleteInvitationRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(const EmployeeLoading());

    try {
      log.d('Удаление приглашения: ${event.invitationId}');

      await _employeeRepository.deleteInvitation(event.invitationId);

      // Удаляем из кэша
      _cachedInvitations = _cachedInvitations
          .where((i) => i.id != event.invitationId)
          .toList();

      log.i('Приглашение удалено');

      emit(InvitationDeleted(invitationId: event.invitationId));
    } on ForbiddenException catch (e) {
      log.e('Недостаточно прав: ${e.message}');
      emit(EmployeeFailure('Недостаточно прав для удаления приглашения'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(EmployeeFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const EmployeeFailure('Неизвестная ошибка'));
    }
  }

  /// Изменение роли сотрудника
  Future<void> _onUpdateEmployeeRoleRequested(
    UpdateEmployeeRoleRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(const EmployeeLoading());

    try {
      log.d(
        'Изменение роли сотрудника ${event.employeeId} на ${event.newRole}',
      );

      final updatedEmployee = await _employeeRepository.updateEmployeeRole(
        employeeId: event.employeeId,
        role: event.newRole,
      );

      // Обновляем в кэше
      _cachedEmployees = _cachedEmployees.map((e) {
        if (e.id == event.employeeId) {
          return Employee(
            id: e.id,
            firstName: e.firstName,
            lastName: e.lastName,
            middleName: e.middleName,
            phone: e.phone,
            role: event.newRole,
            createdAt: e.createdAt,
          );
        }
        return e;
      }).toList();

      log.i('Роль сотрудника изменена');

      emit(EmployeeRoleUpdated(employee: updatedEmployee));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.message}');
      emit(
        EmployeeFailure(
          e.getAllErrors().isNotEmpty ? e.getAllErrors().join(', ') : e.message,
        ),
      );
    } on ForbiddenException catch (e) {
      log.e('Недостаточно прав: ${e.message}');
      emit(EmployeeFailure('Только владелец может менять роли'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(EmployeeFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const EmployeeFailure('Неизвестная ошибка'));
    }
  }

  /// Удаление сотрудника
  Future<void> _onDeleteEmployeeRequested(
    DeleteEmployeeRequested event,
    Emitter<EmployeeState> emit,
  ) async {
    emit(const EmployeeLoading());

    try {
      log.d('Удаление сотрудника: ${event.employeeId}');

      await _employeeRepository.deleteEmployee(event.employeeId);

      // Удаляем из кэша
      _cachedEmployees = _cachedEmployees
          .where((e) => e.id != event.employeeId)
          .toList();

      log.i('Сотрудник удалён');

      emit(EmployeeDeleted(employeeId: event.employeeId));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.message}');
      emit(EmployeeFailure(e.message));
    } on ForbiddenException catch (e) {
      log.e('Недостаточно прав: ${e.message}');
      emit(EmployeeFailure('Недостаточно прав для удаления сотрудника'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(EmployeeFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const EmployeeFailure('Неизвестная ошибка'));
    }
  }

  /// Получение кэшированных данных
  EmployeeLoaded? getCachedData() {
    if (_cachedEmployees.isNotEmpty || _cachedInvitations.isNotEmpty) {
      return EmployeeLoaded(
        employees: _cachedEmployees,
        invitations: _cachedInvitations,
      );
    }
    return null;
  }
}
