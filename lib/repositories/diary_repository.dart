import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import 'package:healapp_mobile/core/logging/app_logger.dart';
import '../models/diary.dart';

export '../models/diary.dart';

final _defaultApiClient = apiClient;

/// Репозиторий для работы с дневниками
class DiaryRepository {
  final ApiClient _apiClient;

  DiaryRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? _defaultApiClient;

  /// Создать новый дневник для пациента
  ///
  /// Возвращает [DiaryCreated] при успешном создании (201)
  /// или [DiaryAlreadyExists] если дневник уже существует (409)
  Future<CreateDiaryResult> createDiary({
    required int patientId,
    List<PinnedParameter>? pinnedParameters,
    Map<String, dynamic>? settings,
  }) async {
    try {
      log.d('📤 Отправка запроса на создание дневника');
      log.d('   patientId: $patientId');
      log.d(
        '   pinnedParameters: ${pinnedParameters?.map((e) => e.toJson()).toList()}',
      );
      log.d('   settings: $settings');

      final response = await _apiClient.post(
        '/diary/create',
        data: {
          'patient_id': patientId,
          'pinned_parameters':
              pinnedParameters?.map((e) => e.toJson()).toList() ?? [],
          'settings': settings,
        },
      );

      log.d('📥 Ответ получен: ${response.statusCode}');
      final data = response.data as Map<String, dynamic>;
      log.d('   Данные: $data');

      return DiaryCreated(Diary.fromJson(data));
    } on ConflictException catch (e) {
      // Обработка 409 Conflict — дневник уже существует
      log.w('⚠️ Конфликт: дневник уже существует');
      final diaryId = e.getData<int>('diary_id') ?? 0;
      return DiaryAlreadyExists(
        e.message.isNotEmpty
            ? e.message
            : 'Дневник для этого пациента уже существует',
        diaryId,
      );
    } on ApiException catch (e) {
      log.e(
        '❌ API ошибка при создании дневника: ${e.message}, statusCode: ${e.statusCode}',
      );
      rethrow;
    } catch (e, stackTrace) {
      log.e('❌ Неизвестная ошибка при создании дневника: $e');
      log.e('StackTrace: $stackTrace');
      throw ServerException('Ошибка при создании дневника: ${e.toString()}');
    }
  }

  /// Получить список всех дневников
  Future<List<Diary>> getDiaries() async {
    try {
      log.d('DiaryRepository: Запрос GET /diary');
      log.d('DiaryRepository: BaseURL: ${ApiConfig.baseUrl}');
      log.d('DiaryRepository: Full URL: ${ApiConfig.baseUrl}/diary');
      final response = await _apiClient.get('/diary');
      log.d('DiaryRepository: Ответ получен, статус: ${response.statusCode}');
      final data = response.data;
      log.d('DiaryRepository: Тип данных: ${data.runtimeType}');
      if (data is List) {
        log.d('DiaryRepository: Количество дневников: ${data.length}');
        for (var i = 0; i < data.length; i++) {
          final raw = data[i] as Map<String, dynamic>;
          final rawPatient = raw['patient'];
          log.d('DiaryRepository: Дневник[${i + 1}] raw patient JSON: $rawPatient');
        }
        final diaries = data
            .map((e) => Diary.fromJson(e as Map<String, dynamic>))
            .toList();
        for (var i = 0; i < diaries.length; i++) {
          final d = diaries[i];
          log.d(
            'DiaryRepository: Дневник[${i + 1}]: id=${d.id}, patientId=${d.patientId}, '
            'patient=${d.patientName}, age=${d.patientAge}, '
            'pinnedParams=${d.pinnedParameters.length}, entries=${d.entries.length}, '
            'created=${d.createdAt}',
          );
        }
        return diaries;
      }
      log.w('DiaryRepository: Данные не являются списком: $data');
      return [];
    } on ApiException catch (e) {
      log.e(
        'DiaryRepository: ApiException - ${e.runtimeType}: ${e.message}, statusCode: ${e.statusCode}',
      );
      rethrow;
    } catch (e, stackTrace) {
      log.e('DiaryRepository: Неизвестная ошибка: $e');
      log.e('DiaryRepository: StackTrace: $stackTrace');
      throw ServerException('Ошибка при получении дневников: ${e.toString()}');
    }
  }

  /// Получить дневник по ID
  Future<Diary> getDiary(int diaryId) async {
    try {
      final response = await _apiClient.get('/diary/$diaryId');
      final data = response.data as Map<String, dynamic>;
      return Diary.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении дневника: ${e.toString()}');
    }
  }

  /// Получить клиента-владельца дневника
  Future<List<DiaryClient>> getDiaryClients(int diaryId) async {
    try {
      final response = await _apiClient.get('/diary/$diaryId/clients');
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => DiaryClient.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при получении владельца дневника: ${e.toString()}',
      );
    }
  }

  /// Получить дневник пациента по ID пациента
  Future<Diary?> getDiaryByPatientId(int patientId) async {
    try {
      final response = await _apiClient.get('/diary/patient/$patientId');
      final data = response.data as Map<String, dynamic>;
      return Diary.fromJson(data);
    } on NotFoundException {
      return null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении дневника: ${e.toString()}');
    }
  }

  /// Обновить закреплённые параметры дневника
  Future<Diary> updatePinnedParameters(
    int diaryId,
    List<PinnedParameter> pinnedParameters,
  ) async {
    try {
      // Новый API: PATCH /diary/pinned expects patient_id and pinned_parameters.
      // Получаем дневник по diaryId, чтобы узнать patientId
      final diary = await getDiary(diaryId);

      await savePinnedParameters(
        patientId: diary.patientId,
        pinnedParameters: pinnedParameters,
      );

      // После сохранения получаем обновлённый дневник и возвращаем его
      final updatedDiary = await getDiary(diaryId);
      return updatedDiary;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при обновлении параметров: ${e.toString()}',
      );
    }
  }

  /// Добавить запись в дневник
  Future<DiaryEntry> addEntry({
    required int diaryId,
    required String parameterKey,
    required String value,
    String? notes,
    DateTime? recordedAt,
  }) async {
    try {
      final response = await _apiClient.post(
        '/diary/$diaryId/entries',
        data: {
          'parameter_key': parameterKey,
          'value': value,
          'notes': notes,
          'recorded_at': (recordedAt ?? DateTime.now())
              .toUtc()
              .toIso8601String(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      return DiaryEntry.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при добавлении записи: ${e.toString()}');
    }
  }

  /// Получить записи дневника
  Future<List<DiaryEntry>> getEntries(
    int diaryId, {
    String? parameterKey,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (parameterKey != null) queryParams['parameter_key'] = parameterKey;
      if (fromDate != null) queryParams['from'] = fromDate.toIso8601String();
      if (toDate != null) queryParams['to'] = toDate.toIso8601String();

      final response = await _apiClient.get(
        '/diary/$diaryId/entries',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final data = response.data;
      if (data is List) {
        return data
            .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при получении записей: ${e.toString()}');
    }
  }

  /// Обновить запись в дневнике
  Future<DiaryEntry> updateEntry({
    required int entryId,
    dynamic value,
    String? notes,
    DateTime? recordedAt,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (value != null) {
        data['value'] = value is Map ? value : {'value': value};
      }
      if (notes != null) {
        data['notes'] = notes;
      }
      if (recordedAt != null) {
        data['recorded_at'] = recordedAt.toUtc().toIso8601String();
      }

      final response = await _apiClient.put(
        '/diary/entries/$entryId',
        data: data,
      );
      final responseData = response.data as Map<String, dynamic>;
      return DiaryEntry.fromJson(responseData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при обновлении записи: ${e.toString()}');
    }
  }

  /// Удалить запись из дневника
  Future<void> deleteEntry(int diaryId, int entryId) async {
    try {
      await _apiClient.delete('/diary/$diaryId/entries/$entryId');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при удалении записи: ${e.toString()}');
    }
  }

  /// Удалить дневник
  Future<void> deleteDiary(int diaryId) async {
    try {
      await _apiClient.delete('/diary/$diaryId');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при удалении дневника: ${e.toString()}');
    }
  }

  /// Синхронизировать набор записей дневника через API v2
  /// PUT /diary/{id}/entries/sync
  /// Принимает массив объектов по правилам API: обновление, создание и удаление.
  /// Возвращает распарсенный JSON-ответ сервера (message, created, updated, deleted, entries)
  Future<Map<String, dynamic>> syncEntries({
    required int diaryId,
    required List<Map<String, dynamic>> entries,
    bool deleteMissing = false,
  }) async {
    try {
      final response = await _apiClient.put(
        '/diary/$diaryId/entries/sync',
        data: {'entries': entries, 'delete_missing': deleteMissing},
      );

      final data = response.data as Map<String, dynamic>;
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при синхронизации записей: ${e.toString()}',
      );
    }
  }

  /// Сохранить настройки закрепленных показателей (API v2)
  /// Опционально можно передать settings.all_indicators для "всех показателей"
  Future<void> savePinnedParameters({
    required int patientId,
    required List<PinnedParameter> pinnedParameters,
    List<String>? allIndicators,
  }) async {
    try {
      final requestData = <String, dynamic>{
        'patient_id': patientId,
        'pinned_parameters': pinnedParameters.map((p) {
          // Отправляем полный объект с times и label
          return {
            'key': p.key,
            'interval_minutes': p.intervalMinutes < 1 ? 60 : p.intervalMinutes,
            'times': p.times,
            'label': p.label,
          };
        }).toList(),
      };

      // Добавляем settings.all_indicators если передан
      if (allIndicators != null) {
        requestData['settings'] = {'all_indicators': allIndicators};
      }

      await _apiClient.patch('/diary/pinned', data: requestData);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при сохранении параметров: ${e.toString()}',
      );
    }
  }

  /// Сохранить только settings.all_indicators (для диалога "Все показатели")
  Future<void> saveAllIndicators({
    required int patientId,
    required List<String> allIndicators,
    List<PinnedParameter> currentPinnedParameters = const [],
  }) async {
    try {
      await _apiClient.patch(
        '/diary/pinned',
        data: {
          'patient_id': patientId,
          'pinned_parameters': currentPinnedParameters
              .map((p) => {'key': p.key, 'label': p.label})
              .toList(),
          'settings': {'all_indicators': allIndicators},
        },
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Ошибка при сохранении показателей: ${e.toString()}',
      );
    }
  }

  /// Создать запись в дневнике (API v2)
  /// Возвращает созданную запись для локального обновления UI без перезагрузки
  Future<DiaryEntry> createMeasurement({
    required int patientId,
    required String type,
    required String key,
    required Map<String, dynamic> value,
    String? notes,
    required DateTime recordedAt,
  }) async {
    try {
      final response = await _apiClient.post(
        '/diary',
        data: {
          'patient_id': patientId,
          'type': type,
          'key': key,
          'value': value,
          'notes': notes,
          'recorded_at': recordedAt.toUtc().toIso8601String(),
        },
      );

      // Если сервер возвращает созданную запись, парсим её
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return DiaryEntry.fromJson(data);
      }

      throw const ServerException('Сервер не вернул данные созданной записи');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException('Ошибка при создании записи: ${e.toString()}');
    }
  }
}
