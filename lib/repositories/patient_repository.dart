import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/cache/data_cache.dart';

final _defaultApiClient = apiClient;

/// Модель пациента (подопечного)
class Patient {
  final int id;
  final int? creatorId;
  final int? organizationId;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? fullNameFromApi;
  final DateTime? birthDate;
  final String? gender;
  final double? weight;
  final double? height;
  final String? mobility;
  final String? address;
  final List<String>? diagnoses;
  final List<String>? neededServices;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Patient({
    required this.id,
    this.creatorId,
    this.organizationId,
    this.firstName,
    this.lastName,
    this.middleName,
    this.fullNameFromApi,
    this.birthDate,
    this.gender,
    this.weight,
    this.height,
    this.mobility,
    this.address,
    this.diagnoses,
    this.neededServices,
    this.createdAt,
    this.updatedAt,
  });

  /// Полное имя пациента
  String get fullName {
    // Приоритет: full_name из API, иначе собираем из частей
    if (fullNameFromApi != null && fullNameFromApi!.trim().isNotEmpty) {
      return fullNameFromApi!.trim();
    }
    final parts = <String>[];
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (middleName != null && middleName!.isNotEmpty) parts.add(middleName!);
    return parts.isNotEmpty ? parts.join(' ') : 'Без имени';
  }

  /// Возраст пациента
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  /// Пол на русском
  String get genderLabel {
    switch (gender) {
      case 'male':
        return 'Мужской';
      case 'female':
        return 'Женский';
      default:
        return 'Не указан';
    }
  }

  /// Мобильность на русском
  String get mobilityLabel {
    switch (mobility) {
      case 'walking':
        return 'Ходит';
      case 'sitting':
        return 'Сидит';
      case 'bedridden':
        return 'Лежит';
      default:
        return 'Не указана';
    }
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as int,
      creatorId: json['creator_id'] as int?,
      organizationId: json['organization_id'] as int?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      middleName: json['middle_name'] as String?,
      fullNameFromApi: json['full_name'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      gender: json['gender'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      mobility: json['mobility'] as String?,
      address: json['address'] as String?,
      diagnoses: (json['diagnoses'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      neededServices: (json['needed_services'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'organization_id': organizationId,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'full_name': fullNameFromApi,
      'birth_date': birthDate?.toIso8601String(),
      'gender': gender,
      'weight': weight,
      'height': height,
      'mobility': mobility,
      'address': address,
      'diagnoses': diagnoses,
      'needed_services': neededServices,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Patient(id: $id, name: $fullName, age: $age)';
  }
}

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
