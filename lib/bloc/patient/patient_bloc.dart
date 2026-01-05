import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/patient_repository.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/cache/data_cache.dart';
import '../../utils/app_logger.dart';
import 'patient_event.dart';
import 'patient_state.dart';

/// BLoC для управления пациентами
class PatientBloc extends Bloc<PatientEvent, PatientState> {
  final PatientRepository _patientRepository;

  PatientBloc({PatientRepository? patientRepository})
    : _patientRepository = patientRepository ?? PatientRepository(),
      super(const PatientInitial()) {
    on<LoadPatients>(_onLoadPatients);
    on<RefreshPatients>(_onRefreshPatients);
    on<CreatePatient>(_onCreatePatient);
    on<UpdatePatient>(_onUpdatePatient);
    on<DeletePatient>(_onDeletePatient);
  }

  /// Обработка события загрузки пациентов
  Future<void> _onLoadPatients(
    LoadPatients event,
    Emitter<PatientState> emit,
  ) async {
    // Проверяем кэш перед загрузкой
    final cacheKey = 'patients_list';
    final cached = AppCache.patients.get(cacheKey);
    if (cached != null && !event.forceRefresh) {
      log.d('Используем кэшированные данные пациентов');
      final patients = cached.map((p) => Patient.fromJson(p as Map<String, dynamic>)).toList();
      emit(PatientLoaded(patients));
      // Загружаем в фоне для обновления
      _loadPatientsInBackground(emit);
      return;
    }

    emit(const PatientLoading());

    try {
      final patients = await _patientRepository.getPatients();
      log.i('Загружено ${patients.length} пациентов');
      
      // Сохраняем в кэш
      AppCache.patients.put(
        cacheKey,
        patients.map((p) => p.toJson()).toList(),
      );

      for (final p in patients) {
        log.d(
          '📋 Пациент: ${p.fullName}, ID: ${p.id}, organizationId: ${p.organizationId}',
        );
      }
      emit(PatientLoaded(patients));
    } on ValidationException catch (e) {
      emit(PatientError(e.getAllErrors().join(', ')));
    } on UnauthorizedException {
      emit(const PatientError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(PatientError('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      emit(PatientError('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      emit(PatientError(e.message));
    } catch (e) {
      log.e('Ошибка загрузки пациентов: $e');
      emit(const PatientError('Неизвестная ошибка'));
    }
  }

  /// Загрузка пациентов в фоне для обновления кэша
  Future<void> _loadPatientsInBackground(Emitter<PatientState> emit) async {
    try {
      final patients = await _patientRepository.getPatients();
      AppCache.patients.put(
        'patients_list',
        patients.map((p) => p.toJson()).toList(),
      );
      // Обновляем состояние только если текущее состояние - загруженное
      if (state is PatientLoaded) {
        emit(PatientLoaded(patients));
      }
    } catch (e) {
      log.w('Ошибка фоновой загрузки пациентов: $e');
    }
  }

  /// Обработка события обновления пациентов (без показа загрузки)
  Future<void> _onRefreshPatients(
    RefreshPatients event,
    Emitter<PatientState> emit,
  ) async {
    try {
      final patients = await _patientRepository.getPatients();
      log.d('Обновлено ${patients.length} пациентов');
      emit(PatientLoaded(patients));
    } catch (e) {
      log.w('Ошибка обновления пациентов: $e');
      // Не меняем состояние при ошибке обновления
    }
  }

  /// Обработка события создания пациента
  Future<void> _onCreatePatient(
    CreatePatient event,
    Emitter<PatientState> emit,
  ) async {
    emit(const PatientLoading());

    try {
      log.d('Создание пациента: ${event.patientData}');
      final patient = await _patientRepository.createPatient(event.patientData);
      log.i('Пациент создан: ${patient.fullName}');
      emit(PatientCreated(patient));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.getAllErrors()}');
      emit(PatientError(e.getAllErrors().join(', ')));
    } on UnauthorizedException {
      emit(const PatientError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(PatientError('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      emit(PatientError('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      emit(PatientError(e.message));
    } catch (e) {
      log.e('Ошибка создания пациента: $e');
      emit(const PatientError('Неизвестная ошибка'));
    }
  }

  /// Обработка события обновления пациента
  Future<void> _onUpdatePatient(
    UpdatePatient event,
    Emitter<PatientState> emit,
  ) async {
    emit(const PatientLoading());

    try {
      log.d('Обновление пациента ${event.patientId}: ${event.patientData}');
      final patient = await _patientRepository.updatePatient(
        event.patientId,
        event.patientData,
      );
      log.i('Пациент обновлён: ${patient.fullName}');
      emit(PatientUpdated(patient));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.getAllErrors()}');
      emit(PatientError(e.getAllErrors().join(', ')));
    } on UnauthorizedException {
      emit(const PatientError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(PatientError('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      emit(PatientError('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      emit(PatientError(e.message));
    } catch (e) {
      log.e('Ошибка обновления пациента: $e');
      emit(const PatientError('Неизвестная ошибка'));
    }
  }

  /// Обработка события удаления пациента
  Future<void> _onDeletePatient(
    DeletePatient event,
    Emitter<PatientState> emit,
  ) async {
    try {
      await _patientRepository.deletePatient(event.patientId);
      log.i('Пациент ${event.patientId} удалён');
      emit(PatientDeleted(event.patientId));

      // Перезагружаем список после удаления
      add(const RefreshPatients());
    } on ApiException catch (e) {
      emit(PatientError(e.message));
    } catch (e) {
      log.e('Ошибка удаления пациента: $e');
      emit(const PatientError('Ошибка при удалении'));
    }
  }
}
