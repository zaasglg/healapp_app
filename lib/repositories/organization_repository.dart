import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';

final _defaultApiClient = apiClient;

class OrganizationRepository {
  final ApiClient _apiClient;

  OrganizationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

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
}
