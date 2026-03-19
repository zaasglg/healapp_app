import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import 'package:healapp_mobile/core/logging/app_logger.dart';
import '../models/employee.dart';

export '../models/employee.dart';

final _defaultApiClient = apiClient;

/// Репозиторий для работы с сотрудниками
class EmployeeRepository {
  final ApiClient _apiClient;

  EmployeeRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Получение списка сотрудников организации
  ///
  /// [role] - опциональный фильтр по роли: owner, admin, doctor, caregiver
  ///
  /// Возвращает список [Employee]
  /// Выбрасывает [ApiException] при ошибке
  Future<List<Employee>> getEmployees({String? role}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (role != null) {
        queryParams['role'] = role;
      }

      final response = await _apiClient.get(
        '/organization/employees',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      log.d('Ответ GET /organization/employees: $data');

      List<dynamic> employeesList;
      if (data is List) {
        employeesList = data;
      } else if (data is Map && data.containsKey('data')) {
        employeesList = data['data'] as List;
      } else if (data is Map && data.containsKey('employees')) {
        employeesList = data['employees'] as List;
      } else {
        employeesList = [];
      }

      return employeesList.map((e) => Employee.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при получении сотрудников: ${e.toString()}',
      );
    }
  }

  /// Изменение роли сотрудника
  ///
  /// [employeeId] - ID сотрудника
  /// [role] - новая роль: admin, doctor, caregiver
  ///
  /// Возвращает обновлённого [Employee]
  /// Выбрасывает [ApiException] при ошибке
  Future<Employee> updateEmployeeRole({
    required int employeeId,
    required String role,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/organization/employees/$employeeId/role',
        data: {'role': role},
      );

      final data = response.data as Map<String, dynamic>;
      log.d('Ответ PATCH /organization/employees/$employeeId/role: $data');

      if (data.containsKey('employee')) {
        return Employee.fromJson(data['employee']);
      }

      // Возвращаем базовый объект если сервер не вернул полные данные
      return Employee(id: employeeId, role: role);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при изменении роли: ${e.toString()}');
    }
  }

  /// Удаление сотрудника из организации
  ///
  /// [employeeId] - ID сотрудника
  ///
  /// Выбрасывает [ApiException] при ошибке
  Future<void> deleteEmployee(int employeeId) async {
    try {
      await _apiClient.delete('/organization/employees/$employeeId');
      log.d('Сотрудник $employeeId удалён');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при удалении сотрудника: ${e.toString()}');
    }
  }

  /// Получение списка приглашений
  ///
  /// [status] - опциональный фильтр по статусу: pending, accepted, expired
  ///
  /// Возвращает список [Invitation]
  /// Выбрасывает [ApiException] при ошибке
  Future<List<Invitation>> getInvitations({String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await _apiClient.get(
        '/invitations',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      log.d('Ответ GET /invitations: $data');

      List<dynamic> invitationsList;
      if (data is List) {
        invitationsList = data;
      } else if (data is Map && data.containsKey('data')) {
        invitationsList = data['data'] as List;
      } else if (data is Map && data.containsKey('invitations')) {
        invitationsList = data['invitations'] as List;
      } else {
        invitationsList = [];
      }

      return invitationsList.map((e) => Invitation.fromJson(e)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при получении приглашений: ${e.toString()}',
      );
    }
  }

  /// Создание приглашения для сотрудника
  ///
  /// [role] - роль для приглашаемого: admin, doctor, caregiver
  ///
  /// Возвращает Map с invitation и invite_url
  /// Выбрасывает [ApiException] при ошибке
  Future<Map<String, dynamic>> createEmployeeInvitation({
    required String role,
  }) async {
    try {
      final response = await _apiClient.post(
        '/invitations/employee',
        data: {'role': role},
      );

      final data = response.data as Map<String, dynamic>;
      log.d('Ответ POST /invitations/employee: $data');

      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при создании приглашения: ${e.toString()}');
    }
  }

  /// Отзыв (удаление) приглашения
  ///
  /// [invitationId] - ID приглашения
  ///
  /// Выбрасывает [ApiException] при ошибке
  Future<void> deleteInvitation(int invitationId) async {
    try {
      await _apiClient.delete('/invitations/$invitationId');
      log.d('Приглашение $invitationId удалено');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при удалении приглашения: ${e.toString()}');
    }
  }
}
