import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/cache/data_cache.dart';
import '../models/patient.dart';

export '../models/patient.dart';

final _defaultApiClient = apiClient;

/// Репозиторий для работы с пациентами
class PatientRepository {
  final ApiClient _apiClient;

  PatientRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Получить список всех пациентов
  Future<List<Patient>> getPatients({bool useCache = true}) async {
    // Проверяем кэш
    if (useCache) {
      final cached = AppCache.patients.get('patients_list');
      if (cached != null) {
        return cached
            .map((json) => Patient.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      final response = await _apiClient.get('/patients');

      final data = response.data;

      if (data is List) {
        final patients = data
            .map((json) => Patient.fromJson(json as Map<String, dynamic>))
            .toList();

        // Сохраняем в кэш
        AppCache.patients.put(
          'patients_list',
          patients.map((p) => p.toJson()).toList(),
        );

        return patients;
      }

      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении пациентов: ${e.toString()}');
    }
  }

  /// Получить пациента по ID
  Future<Patient> getPatient(int id) async {
    try {
      final response = await _apiClient.get('/patients/$id');

      final data = response.data as Map<String, dynamic>;
      return Patient.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении пациента: ${e.toString()}');
    }
  }

  /// Создать нового пациента
  Future<Patient> createPatient(Map<String, dynamic> patientData) async {
    try {
      final response = await _apiClient.post('/patients', data: patientData);

      final data = response.data as Map<String, dynamic>;

      Patient patient;
      // Проверяем формат ответа
      if (data.containsKey('patient')) {
        patient = Patient.fromJson(data['patient'] as Map<String, dynamic>);
      } else {
        patient = Patient.fromJson(data);
      }

      // Очищаем кэш списка пациентов
      AppCache.patients.remove('patients_list');

      return patient;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при создании пациента: ${e.toString()}');
    }
  }

  /// Обновить пациента
  Future<Patient> updatePatient(
    int id,
    Map<String, dynamic> patientData,
  ) async {
    try {
      final response = await _apiClient.put('/patients/$id', data: patientData);

      final data = response.data as Map<String, dynamic>;

      Patient patient;
      if (data.containsKey('patient')) {
        patient = Patient.fromJson(data['patient'] as Map<String, dynamic>);
      } else {
        patient = Patient.fromJson(data);
      }

      // Очищаем кэш списка пациентов
      AppCache.patients.remove('patients_list');

      return patient;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при обновлении пациента: ${e.toString()}');
    }
  }

  /// Удалить пациента
  Future<void> deletePatient(int id) async {
    try {
      await _apiClient.delete('/patients/$id');

      // Очищаем кэш списка пациентов
      AppCache.patients.remove('patients_list');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при удалении пациента: ${e.toString()}');
    }
  }
}
