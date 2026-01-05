import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';

final _defaultApiClient = apiClient;

/// Модель сотрудника
class Employee {
  final int id;
  final int? userId;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? phone;
  final String role;
  final String? accountType;
  final String? avatarUrl;
  final DateTime? createdAt;

  Employee({
    required this.id,
    this.userId,
    this.name,
    this.firstName,
    this.lastName,
    this.middleName,
    this.phone,
    required this.role,
    this.accountType,
    this.avatarUrl,
    this.createdAt,
  });

  /// Полное имя сотрудника или название организации
  String get fullName {
    // Для организаций (owner или account_type != specialist) показываем название
    if (isOrganization) {
      if (name != null && name!.isNotEmpty) {
        return name!;
      }
    }
    
    // Для сотрудников/сиделок показываем имя и фамилию
    final parts = <String>[];
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (middleName != null && middleName!.isNotEmpty) parts.add(middleName!);
    
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    
    // Fallback на name если нет first_name/last_name
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    
    return 'Без имени';
  }
  
  /// Проверка является ли это организацией
  bool get isOrganization {
    // Если есть account_type, проверяем его
    if (accountType != null) {
      // specialist и client - это не организации
      return accountType != 'specialist' && accountType != 'client';
    }
    // Иначе проверяем по роли
    return role == 'owner';
  }

  /// Отображаемое название роли на русском
  String get roleDisplayName {
    switch (role) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'doctor':
        return 'Врач';
      case 'caregiver':
        return 'Сиделка';
      default:
        return role;
    }
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Логируем данные для отладки
    log.d('Employee.fromJson: $json');
    
    // Пробуем разные варианты полей для аватара
    String? avatarUrl;
    if (json['avatar_url'] != null) {
      avatarUrl = json['avatar_url'] as String?;
    } else if (json['avatar'] != null) {
      avatarUrl = json['avatar'] as String?;
    } else if (json['photo'] != null) {
      avatarUrl = json['photo'] as String?;
    } else if (json['image'] != null) {
      avatarUrl = json['image'] as String?;
    }
    
    return Employee(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      name: json['name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      middleName: json['middle_name'] as String?,
      phone: json['phone']?.toString(),
      role: json['role'] as String? ?? 'caregiver',
      accountType: json['account_type'] as String?,
      avatarUrl: avatarUrl,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'phone': phone,
      'role': role,
      'account_type': accountType,
      'avatar_url': avatarUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Employee(id: $id, name: $fullName, role: $role, avatar: $avatarUrl)';
  }
}

/// Модель приглашения
class Invitation {
  final int id;
  final int organizationId;
  final int inviterId;
  final String token;
  final String type;
  final String? role;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? inviteUrl;

  Invitation({
    required this.id,
    required this.organizationId,
    required this.inviterId,
    required this.token,
    required this.type,
    this.role,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.inviteUrl,
  });

  /// Отображаемое название роли на русском
  String get roleDisplayName {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'doctor':
        return 'Врач';
      case 'caregiver':
        return 'Сиделка';
      default:
        return role ?? 'Неизвестно';
    }
  }

  /// Проверка истек ли срок приглашения
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] as int,
      organizationId: json['organization_id'] as int,
      inviterId: json['inviter_id'] as int,
      token: json['token'] as String,
      type: json['type'] as String,
      role: json['role'] as String?,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'].toString()),
      createdAt: DateTime.parse(json['created_at'].toString()),
      inviteUrl: json['invite_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'inviter_id': inviterId,
      'token': token,
      'type': type,
      'role': role,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'invite_url': inviteUrl,
    };
  }

  @override
  String toString() {
    return 'Invitation(id: $id, role: $role, status: $status)';
  }
}

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
