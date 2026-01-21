import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/diary_repository.dart';
import '../../core/network/api_exceptions.dart';
import '../../utils/app_logger.dart';
import '../../services/pinned_notification_service.dart';
import 'diary_event.dart';
import 'diary_state.dart';

/// BLoC для управления дневником пациента
class DiaryBloc extends Bloc<DiaryEvent, DiaryState> {
  final DiaryRepository _diaryRepository;
  final PinnedNotificationService _pinnedNotificationService;

  DiaryBloc({
    DiaryRepository? diaryRepository,
    PinnedNotificationService? pinnedNotificationService,
  }) : _diaryRepository = diaryRepository ?? DiaryRepository(),
       _pinnedNotificationService =
           pinnedNotificationService ?? PinnedNotificationService(),
       super(const DiaryInitial()) {
    on<LoadDiaries>(_onLoadDiaries);
    on<CreateDiary>(_onCreateDiary);
    on<LoadDiary>(_onLoadDiary);
    on<LoadDiaryByPatient>(_onLoadDiaryByPatient);
    on<UpdatePinnedParameters>(_onUpdatePinnedParameters);
    on<AddDiaryEntry>(_onAddDiaryEntry);
    on<LoadDiaryEntries>(_onLoadDiaryEntries);
    on<DeleteDiaryEntry>(_onDeleteDiaryEntry);
    on<DeleteDiary>(_onDeleteDiary);
    on<SavePinnedParameters>(_onSavePinnedParameters);
    on<CreateMeasurement>(_onCreateMeasurement);
    on<UpdateDiaryEntry>(_onUpdateDiaryEntry);
  }

  /// Обработка события загрузки списка дневников
  Future<void> _onLoadDiaries(
    LoadDiaries event,
    Emitter<DiaryState> emit,
  ) async {
    emit(const DiaryLoading());

    try {
      final diaries = await _diaryRepository.getDiaries();
      // Фильтруем дневники - показываем только те, у которых есть пациент
      final diariesWithPatients = diaries
          .where((diary) => diary.patient != null)
          .toList();
      log.i(
        'Загружено ${diaries.length} дневников, показываем ${diariesWithPatients.length} (с пациентами)',
      );
      emit(DiariesLoaded(diariesWithPatients));
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(DiaryError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка загрузки дневников: $e');
      emit(const DiaryError('Неизвестная ошибка'));
    }
  }

  /// Обработка события создания дневника
  Future<void> _onCreateDiary(
    CreateDiary event,
    Emitter<DiaryState> emit,
  ) async {
    emit(const DiaryLoading());

    try {
      log.d('Создание дневника для пациента: ${event.patientId}');
      log.d(
        'Закрепленные параметры: ${event.pinnedParameters?.map((p) => p.key).toList() ?? []}',
      );
      log.d('Settings: ${event.settings}');

      final result = await _diaryRepository.createDiary(
        patientId: event.patientId,
        pinnedParameters: event.pinnedParameters,
        settings: event.settings,
      );

      switch (result) {
        case DiaryCreated(:final diary):
          log.i(
            '✅ Дневник создан успешно: ID=${diary.id}, patientId=${diary.patientId}',
          );

          // СНАЧАЛА отправляем состояние успеха
          emit(DiaryCreatedState(diary));

          // ПОТОМ планируем уведомления асинхронно (без await в основном потоке)
          if (diary.pinnedParameters.isNotEmpty) {
            log.d(
              '🔔 Запуск фоновой задачи планирования уведомлений для ${diary.pinnedParameters.length} параметров',
            );
            // Запускаем в фоне, не блокируя UI
            _pinnedNotificationService
                .schedulePinnedParameterNotifications(
                  patientId: diary.patientId,
                  pinnedParameters: diary.pinnedParameters,
                )
                .then((_) {
                  log.d('✅ Уведомления успешно запланированы');
                })
                .catchError((notificationError) {
                  // Логируем ошибку планирования уведомлений
                  log.w(
                    '⚠️ Ошибка планирования уведомлений: $notificationError',
                  );
                });
          }
        case DiaryAlreadyExists(:final message, :final existingDiaryId):
          log.w('⚠️ Дневник уже существует: $existingDiaryId');
          emit(DiaryConflict(message, existingDiaryId));
      }
    } on ValidationException catch (e) {
      log.w('❌ Ошибка валидации: ${e.getAllErrors()}');
      emit(DiaryError(e.getAllErrors().join(', ')));
    } on UnauthorizedException {
      log.w('❌ Требуется авторизация');
      emit(const DiaryError('Требуется авторизация'));
    } on NetworkException catch (e) {
      log.e('❌ Ошибка сети: ${e.message}');
      emit(DiaryError('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('❌ Ошибка сервера: ${e.message}');
      emit(DiaryError('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('❌ API ошибка: ${e.message}');
      emit(DiaryError(e.message));
    } catch (e, stackTrace) {
      log.e('❌ Неизвестная ошибка создания дневника: $e');
      log.e('StackTrace: $stackTrace');
      emit(DiaryError('Неизвестная ошибка: ${e.toString()}'));
    }
  }

  /// Обработка события загрузки дневника по ID
  Future<void> _onLoadDiary(LoadDiary event, Emitter<DiaryState> emit) async {
    emit(const DiaryLoading());

    try {
      final diary = await _diaryRepository.getDiary(event.diaryId);
      log.i('Дневник загружен: ${diary.id}');
      emit(DiaryLoaded(diary));
    } on NotFoundException {
      emit(const DiaryError('Дневник не найден'));
    } on ForbiddenException {
      emit(const DiaryError('У вас нет доступа к этому дневнику'));
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(DiaryError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка загрузки дневника: $e');
      emit(const DiaryError('Неизвестная ошибка'));
    }
  }

  /// Обработка события загрузки дневника по ID пациента
  Future<void> _onLoadDiaryByPatient(
    LoadDiaryByPatient event,
    Emitter<DiaryState> emit,
  ) async {
    emit(const DiaryLoading());

    try {
      final diary = await _diaryRepository.getDiaryByPatientId(event.patientId);

      if (diary != null) {
        log.i('Дневник пациента ${event.patientId} загружен: ${diary.id}');
        emit(DiaryLoaded(diary));
      } else {
        log.d('Дневник для пациента ${event.patientId} не найден');
        emit(DiaryNotFound(event.patientId));
      }
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(DiaryError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка загрузки дневника пациента: $e');
      emit(const DiaryError('Неизвестная ошибка'));
    }
  }

  /// Обработка события обновления закреплённых параметров
  Future<void> _onUpdatePinnedParameters(
    UpdatePinnedParameters event,
    Emitter<DiaryState> emit,
  ) async {
    emit(const DiaryLoading());

    try {
      log.d('Обновление параметров дневника ${event.diaryId}');

      final diary = await _diaryRepository.updatePinnedParameters(
        event.diaryId,
        event.pinnedParameters,
      );

      // Обновляем уведомления для закрепленных параметров
      await _pinnedNotificationService.updatePinnedParameterNotifications(
        patientId: diary.patientId,
        pinnedParameters: diary.pinnedParameters,
      );

      log.i('Параметры дневника обновлены');
      emit(DiaryParametersUpdated(diary));
    } on ValidationException catch (e) {
      emit(DiaryError(e.getAllErrors().join(', ')));
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(DiaryError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка обновления параметров: $e');
      emit(const DiaryError('Неизвестная ошибка'));
    }
  }

  /// Обработка события добавления записи
  Future<void> _onAddDiaryEntry(
    AddDiaryEntry event,
    Emitter<DiaryState> emit,
  ) async {
    emit(const DiaryLoading());

    try {
      log.d('Добавление записи в дневник ${event.diaryId}');

      final entry = await _diaryRepository.addEntry(
        diaryId: event.diaryId,
        parameterKey: event.parameterKey,
        value: event.value,
        notes: event.notes,
        recordedAt: event.recordedAt,
      );

      log.i('Запись добавлена: ${entry.id}');
      emit(DiaryEntryAdded(entry));
    } on ValidationException catch (e) {
      emit(DiaryError(e.getAllErrors().join(', ')));
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(DiaryError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка добавления записи: $e');
      emit(const DiaryError('Неизвестная ошибка'));
    }
  }

  /// Обработка события загрузки записей
  Future<void> _onLoadDiaryEntries(
    LoadDiaryEntries event,
    Emitter<DiaryState> emit,
  ) async {
    emit(const DiaryLoading());

    try {
      final entries = await _diaryRepository.getEntries(
        event.diaryId,
        parameterKey: event.parameterKey,
        fromDate: event.fromDate,
        toDate: event.toDate,
      );

      log.i('Загружено ${entries.length} записей');
      emit(DiaryEntriesLoaded(entries));
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(DiaryError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка загрузки записей: $e');
      emit(const DiaryError('Неизвестная ошибка'));
    }
  }

  /// Обработка события удаления записи
  Future<void> _onDeleteDiaryEntry(
    DeleteDiaryEntry event,
    Emitter<DiaryState> emit,
  ) async {
    try {
      await _diaryRepository.deleteEntry(event.diaryId, event.entryId);
      log.i('Запись ${event.entryId} удалена');
      emit(DiaryEntryDeleted(event.entryId));
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка удаления записи: $e');
      emit(const DiaryError('Ошибка при удалении'));
    }
  }

  /// Обработка события удаления дневника
  Future<void> _onDeleteDiary(
    DeleteDiary event,
    Emitter<DiaryState> emit,
  ) async {
    try {
      await _diaryRepository.deleteDiary(event.diaryId);
      log.i('Дневник ${event.diaryId} удалён');
      emit(DiaryDeleted(event.diaryId));
    } on UnauthorizedException {
      emit(const DiaryError('Требуется авторизация'));
    } on ApiException catch (e) {
      emit(DiaryError(e.message));
    } catch (e) {
      log.e('Ошибка удаления дневника: $e');
      emit(const DiaryError('Ошибка при удалении'));
    }
  }

  /// Обработка сохранения настроек (V2)
  Future<void> _onSavePinnedParameters(
    SavePinnedParameters event,
    Emitter<DiaryState> emit,
  ) async {
    try {
      await _diaryRepository.savePinnedParameters(
        patientId: event.patientId,
        pinnedParameters: event.pinnedParameters,
      );

      // Обновляем уведомления для закрепленных параметров
      await _pinnedNotificationService.updatePinnedParameterNotifications(
        patientId: event.patientId,
        pinnedParameters: event.pinnedParameters,
      );

      if (state is DiaryLoaded) {
        final currentDiary = (state as DiaryLoaded).diary;
        final updatedDiary = currentDiary.copyWith(
          pinnedParameters: event.pinnedParameters,
        );
        emit(DiaryParametersUpdated(updatedDiary));
      } else {
        // Загружаем дневник и эмитим DiaryParametersUpdated
        final diary = await _diaryRepository.getDiaryByPatientId(
          event.patientId,
        );
        if (diary != null) {
          emit(DiaryParametersUpdated(diary));
        } else {
          emit(const DiaryInitial());
        }
      }
    } catch (e) {
      log.e('Ошибка сохранения параметров: $e');
      emit(DiaryError('Не удалось сохранить настройки: $e'));
    }
  }

  /// Обработка создания замера (V2)
  /// Локально обновляет состояние без полной перезагрузки дневника
  Future<void> _onCreateMeasurement(
    CreateMeasurement event,
    Emitter<DiaryState> emit,
  ) async {
    // Сохраняем текущее состояние для восстановления при ошибке
    final currentState = state;

    try {
      // Создаём замер на сервере и получаем созданную запись
      final newEntry = await _diaryRepository.createMeasurement(
        patientId: event.patientId,
        type: event.type,
        key: event.key,
        value: event.value,
        notes: event.notes,
        recordedAt: event.recordedAt,
      );

      // Если текущее состояние - загруженный дневник, обновляем его локально
      if (currentState is DiaryLoaded) {
        final currentDiary = currentState.diary;

        // Создаём обновлённый список записей с новой записью в начале
        final updatedEntries = [newEntry, ...currentDiary.entries];

        // Обновляем lastRecordedAt для закрепленного параметра, если это он
        final updatedPinnedParameters = currentDiary.pinnedParameters.map((
          param,
        ) {
          if (param.key == event.key) {
            return PinnedParameter(
              key: param.key,
              intervalMinutes: param.intervalMinutes,
              times: param.times,
              settings: param.settings,
              lastRecordedAt: event.recordedAt,
            );
          }
          return param;
        }).toList();

        // Создаём копию дневника с обновлёнными записями и параметрами
        final updatedDiary = currentDiary.copyWith(
          entries: updatedEntries,
          pinnedParameters: updatedPinnedParameters,
          updatedAt: DateTime.now(),
        );

        // Эмитим обновлённое состояние без перезагрузки
        emit(DiaryLoaded(updatedDiary));
        log.i('Замер добавлен локально: ${event.key} = ${event.value}');
      } else {
        // Если дневник не загружен, загружаем его
        add(LoadDiaryByPatient(event.patientId));
      }
    } catch (e) {
      log.e('Ошибка создания замера: $e');
      emit(DiaryError('Не удалось добавить запись: $e'));

      // Восстанавливаем предыдущее состояние через небольшую задержку
      // чтобы пользователь увидел сообщение об ошибке
      await Future.delayed(const Duration(seconds: 2));
      if (currentState is DiaryLoaded) {
        emit(currentState);
      }
    }
  }

  /// Обработка обновления записи в дневнике
  Future<void> _onUpdateDiaryEntry(
    UpdateDiaryEntry event,
    Emitter<DiaryState> emit,
  ) async {
    // Сохраняем текущее состояние для восстановления при ошибке
    final currentState = state;

    try {
      log.d('Обновление записи дневника ${event.entryId}');

      // Обновляем запись на сервере
      final updatedEntry = await _diaryRepository.updateEntry(
        entryId: event.entryId,
        value: event.value,
        notes: event.notes,
        recordedAt: event.recordedAt,
      );

      // Если текущее состояние - загруженный дневник, обновляем его локально
      if (currentState is DiaryLoaded) {
        final currentDiary = currentState.diary;

        // Обновляем запись в списке
        final updatedEntries = currentDiary.entries.map((entry) {
          return entry.id == event.entryId ? updatedEntry : entry;
        }).toList();

        // Создаём копию дневника с обновлёнными записями
        final updatedDiary = currentDiary.copyWith(
          entries: updatedEntries,
          updatedAt: DateTime.now(),
        );

        // Эмитим обновлённое состояние без перезагрузки
        emit(DiaryLoaded(updatedDiary));
        log.i('Запись обновлена локально: ${event.entryId}');
      } else {
        // Если дневник не загружен, просто показываем успех
        emit(const DiaryInitial());
      }
    } catch (e) {
      log.e('Ошибка обновления записи: $e');
      emit(DiaryError('Не удалось обновить запись: $e'));

      // Восстанавливаем предыдущее состояние через небольшую задержку
      await Future.delayed(const Duration(seconds: 2));
      if (currentState is DiaryLoaded) {
        emit(currentState);
      }
    }
  }
}
