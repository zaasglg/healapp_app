import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';

/// Модель данных приглашения
class Invitation {
  final String organizationName;
  final String organizationType;
  final String type;
  final String role;
  final DateTime expiresAt;

  Invitation({
    required this.organizationName,
    required this.organizationType,
    required this.type,
    required this.role,
    required this.expiresAt,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      organizationName: json['organization_name'] ?? '',
      organizationType: json['organization_type'] ?? '',
      type: json['type'] ?? '',
      role: json['role'] ?? '',
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }

  /// Получить читаемое название роли
  String get roleDisplayName {
    switch (role) {
      case 'doctor':
        return 'Врач';
      case 'nurse':
        return 'Медсестра';
      case 'caregiver':
        return 'Сиделка';
      case 'admin':
        return 'Администратор';
      default:
        return role;
    }
  }

  /// Получить читаемое название типа организации
  String get organizationTypeDisplayName {
    switch (organizationType) {
      case 'clinic':
        return 'Клиника';
      case 'pansionat':
        return 'Пансионат';
      case 'agency':
        return 'Патронажное агентство';
      default:
        return organizationType;
    }
  }
}

/// Результат принятия приглашения
class InvitationAcceptResult {
  final String message;
  final String accessToken;
  final Map<String, dynamic> user;

  InvitationAcceptResult({
    required this.message,
    required this.accessToken,
    required this.user,
  });

  factory InvitationAcceptResult.fromJson(Map<String, dynamic> json) {
    return InvitationAcceptResult(
      message: json['message'] ?? '',
      accessToken: json['access_token'] ?? '',
      user: json['user'] ?? {},
    );
  }
}

/// Репозиторий для работы с приглашениями
class InvitationRepository {
  final ApiClient _apiClient;

  InvitationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? apiClient as ApiClient;

  /// Проверить токен приглашения
  /// GET /api/v1/invitations/{token}
  Future<Invitation> getInvitation(String token) async {
    try {
      log.d('Проверка приглашения: $token');

      final response = await _apiClient.get('/invitations/$token');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        log.i('Приглашение найдено: ${data['organization_name']}');
        return Invitation.fromJson(data);
      }

      throw ServerException('Неизвестная ошибка');
    } on NotFoundException {
      log.w('Приглашение не найдено');
      throw const NotFoundException('Приглашение не найдено');
    } on ApiException {
      rethrow;
    } catch (e) {
      log.e('Ошибка проверки приглашения: $e');
      throw ServerException('Ошибка проверки приглашения');
    }
  }

  /// Принять приглашение (регистрация/привязка)
  /// POST /api/v1/invitations/{token}/accept
  Future<InvitationAcceptResult> acceptInvitation({
    required String token,
    required String phone,
    required String password,
    String? passwordConfirmation,
    String? firstName,
    String? lastName,
  }) async {
    try {
      log.d('Принятие приглашения: $token');

      final body = <String, dynamic>{'phone': phone, 'password': password};

      // Если есть подтверждение пароля - это новый пользователь
      if (passwordConfirmation != null) {
        body['password_confirmation'] = passwordConfirmation;
      }

      if (firstName != null && firstName.isNotEmpty) {
        body['first_name'] = firstName;
      }

      if (lastName != null && lastName.isNotEmpty) {
        body['last_name'] = lastName;
      }

      final response = await _apiClient.post(
        '/invitations/$token/accept',
        data: body,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        log.i('Приглашение принято: ${data['message']}');
        return InvitationAcceptResult.fromJson(data);
      }

      throw ServerException('Неизвестная ошибка');
    } on ValidationException {
      rethrow;
    } on UnauthorizedException {
      throw const UnauthorizedException('Неверный пароль');
    } on NotFoundException {
      throw const NotFoundException('Приглашение не найдено');
    } on ApiException {
      rethrow;
    } catch (e) {
      log.e('Ошибка принятия приглашения: $e');
      throw ServerException('Ошибка регистрации');
    }
  }

  /// Создать приглашение для клиента (родственника)
  /// POST /api/v1/invitations/client
  /// 
  /// [patientId] - ID пациента, к которому привязываем клиента
  /// 
  /// Возвращает Map с invitation и invite_url
  /// Выбрасывает [ApiException] при ошибке
  Future<Map<String, dynamic>> createClientInvitation({
    required int patientId,
  }) async {
    try {
      log.d('Создание приглашения для клиента: patientId=$patientId');

      final response = await _apiClient.post(
        '/invitations/client',
        data: {'patient_id': patientId},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        log.i('Приглашение для клиента создано: ${data['invite_url']}');
        return data;
      }

      throw ServerException('Неизвестная ошибка');
    } on ValidationException {
      rethrow;
    } on UnauthorizedException {
      throw const UnauthorizedException('Недостаточно прав для создания приглашения');
    } on ApiException {
      rethrow;
    } catch (e) {
      log.e('Ошибка создания приглашения для клиента: $e');
      throw ServerException('Ошибка создания приглашения: ${e.toString()}');
    }
  }
}

/// Глобальный экземпляр репозитория
final invitationRepository = InvitationRepository(apiClient: apiClient);
