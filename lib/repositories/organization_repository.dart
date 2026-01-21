import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../utils/app_logger.dart';

final _defaultApiClient = apiClient;

class OrganizationRepository {
  final ApiClient _apiClient;

  OrganizationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Получение данных организации
  ///
  /// Возвращает Map с полными данными организации (включая phone и address)
  /// Выбрасывает [ApiException] при ошибке
  Future<Map<String, dynamic>> getOrganization() async {
    try {
      final response = await _apiClient.get('/organization');

      final data = response.data as Map<String, dynamic>;

      // API возвращает данные организации напрямую (с id, name, phone, address и т.д.)
      // Проверяем наличие обязательных полей
      if (!data.containsKey('id')) {
        throw const ServerException('Данные организации не получены');
      }

      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при получении организации: ${e.toString()}',
      );
    }
  }

  /// Обновление данных организации
  ///
  /// [name] - название организации
  /// [phone] - номер телефона
  /// [address] - адрес организации
  ///
  /// Возвращает Map с данными обновленной организации
  /// Выбрасывает [ApiException] при ошибке
  Future<Map<String, dynamic>> updateOrganization({
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final response = await _apiClient.patch(
        '/organization',
        data: {'name': name, 'phone': phone, 'address': address},
      );

      final data = response.data as Map<String, dynamic>;

      // Проверяем, что пришел ответ с организацией
      final organization = data['organization'] as Map<String, dynamic>?;
      if (organization == null) {
        throw const ServerException('Данные организации не получены');
      }

      return organization;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при обновлении организации: ${e.toString()}',
      );
    }
  }

  /// Назначение доступа к дневнику сотруднику
  ///
  /// [patientId] - ID пациента
  /// [userId] - ID пользователя (user_id сотрудника)
  /// [permission] - уровень доступа (по умолчанию 'edit')
  ///
  /// Выбрасывает [ApiException] при ошибке
  Future<void> assignDiaryAccess({
    required int patientId,
    required int userId,
    String permission = 'edit',
  }) async {
    try {
      log.d('=== assignDiaryAccess API call ===');
      log.d('Endpoint: POST /organization/assign-diary-access');
      log.d(
        'Request data: {patient_id: $patientId, user_id: $userId, permission: $permission}',
      );

      final response = await _apiClient.post(
        '/organization/assign-diary-access',
        data: {
          'patient_id': patientId,
          'user_id': userId,
          'permission': permission,
        },
      );

      log.d('Response status: ${response.statusCode}');
      log.d('Response data: ${response.data}');
      log.d('Доступ к дневнику назначен: patient=$patientId, user=$userId');
    } on ApiException catch (e) {
      log.e('=== API Exception in assignDiaryAccess ===');
      log.e('Type: ${e.runtimeType}');
      log.e('Message: ${e.message}');
      log.e('Status code: ${e.statusCode}');
      rethrow;
    } catch (e) {
      log.e('=== Unknown error in assignDiaryAccess ===');
      log.e('Type: ${e.runtimeType}');
      log.e('Error: $e');
      throw ServerException('Ошибка при назначении доступа: ${e.toString()}');
    }
  }

  /// Отзыв доступа к дневнику у сотрудника
  ///
  /// [patientId] - ID пациента
  /// [userId] - ID пользователя
  ///
  /// Выбрасывает [ApiException] при ошибке
  Future<void> revokeDiaryAccess({
    required int patientId,
    required int userId,
  }) async {
    try {
      await _apiClient.delete(
        '/organization/revoke-diary-access',
        data: {'patient_id': patientId, 'user_id': userId},
      );
      log.d('Доступ к дневнику отозван: patient=$patientId, user=$userId');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при отзыве доступа: ${e.toString()}');
    }
  }

  /// Получение списка сотрудников с доступом к дневнику пациента
  ///
  /// [diaryId] - ID дневника
  ///
  /// Возвращает список сотрудников с доступом
  /// Выбрасывает [ApiException] при ошибке
  Future<List<Map<String, dynamic>>> getDiaryAccessList({
    required int diaryId,
  }) async {
    try {
      log.d('=== getDiaryAccessList API call ===');
      log.d('Endpoint: GET /diary/$diaryId/access');

      final response = await _apiClient.get('/diary/$diaryId/access');

      log.d('Response status: ${response.statusCode}');
      final data = response.data;
      log.d('Response data type: ${data.runtimeType}');
      log.d('Response data: $data');

      List<dynamic> accessList;
      if (data is List) {
        accessList = data;
        log.d('Data is List, length: ${accessList.length}');
      } else if (data is Map && data.containsKey('data')) {
        accessList = data['data'] as List;
        log.d('Data is Map with "data" key, length: ${accessList.length}');
      } else if (data is Map && data.containsKey('accesses')) {
        accessList = data['accesses'] as List;
        log.d('Data is Map with "accesses" key, length: ${accessList.length}');
      } else {
        accessList = [];
        log.w('Unexpected data format, returning empty list');
      }

      final result = accessList.cast<Map<String, dynamic>>();
      log.d('Returning ${result.length} access records');
      return result;
    } on ApiException catch (e) {
      log.e('=== API Exception in getDiaryAccessList ===');
      log.e('Type: ${e.runtimeType}');
      log.e('Message: ${e.message}');
      log.e('Status code: ${e.statusCode}');
      rethrow;
    } catch (e) {
      log.e('=== Unknown error in getDiaryAccessList ===');
      log.e('Type: ${e.runtimeType}');
      log.e('Error: $e');
      throw ServerException(
        'Ошибка при получении списка доступов: ${e.toString()}',
      );
    }
  }
}
