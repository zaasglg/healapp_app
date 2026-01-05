import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/alarm_repository.dart';
import '../../core/network/api_exceptions.dart';
import '../../utils/app_logger.dart';
import '../../services/notification_service.dart';
import 'alarm_event.dart';
import 'alarm_state.dart';

/// BLoC для управления будильниками
class AlarmBloc extends Bloc<AlarmEvent, AlarmState> {
  final AlarmRepository _alarmRepository;
  final NotificationService _notificationService = NotificationService();
  List<Alarm> _cachedAlarms = [];

  AlarmBloc({AlarmRepository? alarmRepository})
    : _alarmRepository = alarmRepository ?? AlarmRepository(),
      super(const AlarmInitial()) {
    on<LoadAlarms>(_onLoadAlarms);
    on<LoadAlarm>(_onLoadAlarm);
    on<CreateAlarm>(_onCreateAlarm);
    on<UpdateAlarm>(_onUpdateAlarm);
    on<DeleteAlarm>(_onDeleteAlarm);
    on<ToggleAlarm>(_onToggleAlarm);
  }

  /// Обработка события загрузки списка будильников
  Future<void> _onLoadAlarms(LoadAlarms event, Emitter<AlarmState> emit) async {
    emit(const AlarmLoading());

    try {
      final alarms = await _alarmRepository.getAlarms(event.diaryId);
      _cachedAlarms = alarms;
      log.i('Загружено ${alarms.length} будильников');
      emit(AlarmsLoaded(alarms));
    } on UnauthorizedException {
      emit(const AlarmError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(AlarmError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(AlarmError(e.message));
    } catch (e) {
      log.e('Ошибка загрузки будильников: $e');
      emit(const AlarmError('Неизвестная ошибка'));
    }
  }

  /// Обработка события загрузки одного будильника
  Future<void> _onLoadAlarm(LoadAlarm event, Emitter<AlarmState> emit) async {
    emit(const AlarmLoading());

    try {
      final alarm = await _alarmRepository.getAlarm(event.alarmId);
      log.i('Будильник загружен: ${alarm.id}');
      emit(AlarmLoaded(alarm));
    } on NotFoundException {
      emit(const AlarmError('Будильник не найден'));
    } on UnauthorizedException {
      emit(const AlarmError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(AlarmError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(AlarmError(e.message));
    } catch (e) {
      log.e('Ошибка загрузки будильника: $e');
      emit(const AlarmError('Неизвестная ошибка'));
    }
  }

  /// Обработка события создания будильника
  Future<void> _onCreateAlarm(
    CreateAlarm event,
    Emitter<AlarmState> emit,
  ) async {
    emit(AlarmOperationInProgress(alarms: _cachedAlarms));

    try {
      log.d('Создание будильника: ${event.name}');

      final alarm = await _alarmRepository.createAlarm(
        diaryId: event.diaryId,
        name: event.name,
        type: event.type,
        daysOfWeek: event.daysOfWeek,
        times: event.times,
        dosage: event.dosage,
        notes: event.notes,
      );

      _cachedAlarms = [..._cachedAlarms, alarm];
      log.i('Будильник создан: ${alarm.id}');

      // Планируем уведомления для будильника
      if (alarm.isActive) {
        await _scheduleAlarmNotifications(alarm);
      }

      emit(AlarmCreated(alarm));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.getAllErrors()}');
      emit(AlarmError(e.getAllErrors().join(', ')));
    } on UnauthorizedException {
      emit(const AlarmError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(AlarmError('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      emit(AlarmError('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      emit(AlarmError(e.message));
    } catch (e) {
      log.e('Ошибка создания будильника: $e');
      emit(const AlarmError('Неизвестная ошибка'));
    }
  }

  /// Обработка события обновления будильника
  Future<void> _onUpdateAlarm(
    UpdateAlarm event,
    Emitter<AlarmState> emit,
  ) async {
    emit(
      AlarmOperationInProgress(alarmId: event.alarmId, alarms: _cachedAlarms),
    );

    try {
      log.d('Обновление будильника: ${event.alarmId}');

      final alarm = await _alarmRepository.updateAlarm(
        alarmId: event.alarmId,
        name: event.name,
        type: event.type,
        daysOfWeek: event.daysOfWeek,
        times: event.times,
        dosage: event.dosage,
        notes: event.notes,
      );

      _cachedAlarms = _cachedAlarms.map((a) {
        if (a.id == alarm.id) return alarm;
        return a;
      }).toList();

      log.i('Будильник обновлён: ${alarm.id}');

      // Обновляем уведомления
      await _cancelAlarmNotifications(alarm.id);
      if (alarm.isActive) {
        await _scheduleAlarmNotifications(alarm);
      }

      emit(AlarmUpdated(alarm));
    } on ValidationException catch (e) {
      emit(AlarmError(e.getAllErrors().join(', ')));
    } on NotFoundException {
      emit(const AlarmError('Будильник не найден'));
    } on UnauthorizedException {
      emit(const AlarmError('Требуется авторизация'));
    } on NetworkException catch (e) {
      emit(AlarmError('Ошибка сети: ${e.message}'));
    } on ApiException catch (e) {
      emit(AlarmError(e.message));
    } catch (e) {
      log.e('Ошибка обновления будильника: $e');
      emit(const AlarmError('Неизвестная ошибка'));
    }
  }

  /// Обработка события удаления будильника
  Future<void> _onDeleteAlarm(
    DeleteAlarm event,
    Emitter<AlarmState> emit,
  ) async {
    emit(
      AlarmOperationInProgress(alarmId: event.alarmId, alarms: _cachedAlarms),
    );

    try {
      await _alarmRepository.deleteAlarm(event.alarmId);
      _cachedAlarms = _cachedAlarms
          .where((a) => a.id != event.alarmId)
          .toList();
      log.i('Будильник ${event.alarmId} удалён');

      // Отменяем уведомления
      await _cancelAlarmNotifications(event.alarmId);

      emit(AlarmDeleted(event.alarmId));
    } on NotFoundException {
      emit(const AlarmError('Будильник не найден'));
    } on UnauthorizedException {
      emit(const AlarmError('Требуется авторизация'));
    } on ApiException catch (e) {
      emit(AlarmError(e.message));
    } catch (e) {
      log.e('Ошибка удаления будильника: $e');
      emit(const AlarmError('Ошибка при удалении'));
    }
  }

  /// Обработка события переключения будильника
  Future<void> _onToggleAlarm(
    ToggleAlarm event,
    Emitter<AlarmState> emit,
  ) async {
    // Оптимистичное обновление - сразу меняем состояние в UI
    final alarmIndex = _cachedAlarms.indexWhere((a) => a.id == event.alarmId);
    if (alarmIndex != -1) {
      final oldAlarm = _cachedAlarms[alarmIndex];
      final optimisticAlarm = oldAlarm.copyWith(isActive: !oldAlarm.isActive);
      _cachedAlarms[alarmIndex] = optimisticAlarm;
      emit(AlarmsLoaded(List.from(_cachedAlarms)));
    }

    try {
      final alarm = await _alarmRepository.toggleAlarm(event.alarmId);

      // Обновляем с реальными данными от сервера
      _cachedAlarms = _cachedAlarms.map((a) {
        if (a.id == alarm.id) return alarm;
        return a;
      }).toList();

      log.i(
        'Будильник ${event.alarmId} переключён: ${alarm.isActive ? 'вкл' : 'выкл'}',
      );

      // Управляем уведомлениями в зависимости от состояния
      if (alarm.isActive) {
        await _scheduleAlarmNotifications(alarm);
      } else {
        await _cancelAlarmNotifications(alarm.id);
      }

      // Эмитим AlarmsLoaded вместо AlarmToggled чтобы не было полной перезагрузки
      emit(AlarmsLoaded(List.from(_cachedAlarms)));
    } on NotFoundException {
      // Откатываем оптимистичное обновление
      emit(AlarmsLoaded(List.from(_cachedAlarms)));
      emit(const AlarmError('Будильник не найден'));
    } on UnauthorizedException {
      emit(AlarmsLoaded(List.from(_cachedAlarms)));
      emit(const AlarmError('Требуется авторизация'));
    } on ApiException catch (e) {
      emit(AlarmsLoaded(List.from(_cachedAlarms)));
      emit(AlarmError(e.message));
    } catch (e) {
      log.e('Ошибка переключения будильника: $e');
      emit(AlarmsLoaded(List.from(_cachedAlarms)));
      emit(const AlarmError('Ошибка при переключении'));
    }
  }

  /// Планирование уведомлений для будильника
  Future<void> _scheduleAlarmNotifications(Alarm alarm) async {
    try {
      for (final timeStr in alarm.times) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;

          await _notificationService.scheduleAlarmNotification(
            alarmId: alarm.id,
            title: 'Время принять лекарство: ${alarm.name}',
            body: alarm.dosage != null && alarm.dosage!.isNotEmpty
                ? 'Дозировка: ${alarm.dosage}'
                : 'Примите лекарство согласно назначению',
            hour: hour,
            minute: minute,
            daysOfWeek: alarm.daysOfWeek,
          );
        }
      }
      log.i('Уведомления запланированы для будильника: ${alarm.id}');
    } catch (e) {
      log.e('Ошибка планирования уведомлений: $e');
    }
  }

  /// Отмена уведомлений для будильника
  Future<void> _cancelAlarmNotifications(int alarmId) async {
    try {
      await _notificationService.cancelAlarmNotifications(alarmId);
      log.i('Уведомления отменены для будильника: $alarmId');
    } catch (e) {
      log.e('Ошибка отмены уведомлений: $e');
    }
  }
}
