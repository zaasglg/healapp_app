import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/app_logger.dart';
import '../repositories/diary_repository.dart';
import 'notification_service.dart';

/// Сервис для управления уведомлениями закрепленных параметров
class PinnedNotificationService {
  static final PinnedNotificationService _instance =
      PinnedNotificationService._internal();
  factory PinnedNotificationService() => _instance;
  PinnedNotificationService._internal();

  final NotificationService _notificationService = NotificationService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Планирование уведомлений для всех закрепленных параметров
  Future<void> schedulePinnedParameterNotifications({
    required int patientId,
    required List<PinnedParameter> pinnedParameters,
  }) async {
    try {
      // Инициализируем сервис уведомлений если нужно
      await _notificationService.initialize();

      // Отменяем все старые уведомления для этого пациента
      await cancelPinnedParameterNotifications(patientId);

      // Планируем уведомления для каждого закрепленного параметра
      for (final parameter in pinnedParameters) {
        await _scheduleSingleParameterNotifications(
          patientId: patientId,
          parameter: parameter,
        );
      }

      log.i(
        'Уведомления запланированы для ${pinnedParameters.length} закрепленных параметров пациента $patientId',
      );
    } catch (e) {
      log.e('Ошибка планирования уведомлений для закрепленных параметров: $e');
    }
  }

  /// Планирование уведомлений для одного закрепленного параметра
  Future<void> _scheduleSingleParameterNotifications({
    required int patientId,
    required PinnedParameter parameter,
  }) async {
    try {
      // Если у параметра есть конкретные времена, используем их
      if (parameter.times.isNotEmpty) {
        await _scheduleTimeBasedNotifications(
          patientId: patientId,
          parameter: parameter,
        );
      }
      // Если есть только интервал, планируем по интервалу
      else if (parameter.intervalMinutes > 0) {
        await _scheduleIntervalBasedNotifications(
          patientId: patientId,
          parameter: parameter,
        );
      }
    } catch (e) {
      log.e(
        'Ошибка планирования уведомлений для параметра ${parameter.key}: $e',
      );
    }
  }

  /// Планирование уведомлений по конкретным временам
  Future<void> _scheduleTimeBasedNotifications({
    required int patientId,
    required PinnedParameter parameter,
  }) async {
    for (int timeIndex = 0; timeIndex < parameter.times.length; timeIndex++) {
      final timeStr = parameter.times[timeIndex];
      final timeParts = timeStr.split(':');

      if (timeParts.length != 2) continue;

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);

      if (hour == null || minute == null) continue;

      // Создаем уникальный ID для уведомления
      final notificationId = _generateNotificationId(
        patientId,
        parameter.key,
        timeIndex,
      );

      final title = 'Время измерить ${parameter.label}';
      final body = 'Не забудьте измерить ${parameter.label.toLowerCase()}';

      await _scheduleParameterNotification(
        notificationId: notificationId,
        title: title,
        body: body,
        hour: hour,
        minute: minute,
        parameter: parameter,
        patientId: patientId,
      );
    }
  }

  /// Планирование уведомлений по интервалу
  Future<void> _scheduleIntervalBasedNotifications({
    required int patientId,
    required PinnedParameter parameter,
  }) async {
    // Для интервальных уведомлений создаем напоминания каждые N часов
    // начиная с 8:00 утра
    final intervalHours = parameter.intervalMinutes ~/ 60;
    if (intervalHours <= 0) return;

    int currentHour = 8; // Начинаем с 8 утра
    int timeIndex = 0;

    while (currentHour < 22) {
      // До 22:00
      final notificationId = _generateNotificationId(
        patientId,
        parameter.key,
        timeIndex,
      );

      final title = 'Время измерить ${parameter.label}';
      final body =
          'Напоминание: измерьте ${parameter.label.toLowerCase()} (${parameter.intervalLabel})';

      await _scheduleParameterNotification(
        notificationId: notificationId,
        title: title,
        body: body,
        hour: currentHour,
        minute: 0,
        parameter: parameter,
        patientId: patientId,
      );

      currentHour += intervalHours;
      timeIndex++;
    }
  }

  /// Планирование одного уведомления для параметра
  Future<void> _scheduleParameterNotification({
    required int notificationId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required PinnedParameter parameter,
    required int patientId,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'pinned_parameters_channel',
        'Закрепленные показатели',
        channelDescription: 'Напоминания о измерении закрепленных показателей',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification_health',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: [
          AndroidNotificationAction(
            'measure_now',
            'Измерить сейчас',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_accept'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'remind_later',
            'Напомнить позже',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_decline'),
            showsUserInterface: false,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: 'pinned_parameter_category',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Планируем ежедневное уведомление
      final scheduledDate = _nextInstanceOfTime(hour, minute);

      await _notifications.zonedSchedule(
        notificationId,
        title,
        '$body\n\nВыберите действие или нажмите для открытия приложения',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'pinned_${patientId}_${parameter.key}',
      );

      log.d(
        'Уведомление запланировано для ${parameter.key} в $hour:${minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      log.e('Ошибка планирования уведомления для ${parameter.key}: $e');
    }
  }

  /// Отмена всех уведомлений для закрепленных параметров пациента
  Future<void> cancelPinnedParameterNotifications(int patientId) async {
    try {
      // Отменяем уведомления с ID от 100000 до 199999 для этого пациента
      final baseId = patientId * 100000;
      for (int i = 0; i < 10000; i++) {
        await _notifications.cancel(baseId + i);
      }
      log.i(
        'Уведомления отменены для закрепленных параметров пациента $patientId',
      );
    } catch (e) {
      log.e('Ошибка отмены уведомлений: $e');
    }
  }

  /// Отмена уведомлений для конкретного параметра
  Future<void> cancelParameterNotifications(
    int patientId,
    String parameterKey,
  ) async {
    try {
      // Отменяем все возможные уведомления для этого параметра
      for (int timeIndex = 0; timeIndex < 24; timeIndex++) {
        final notificationId = _generateNotificationId(
          patientId,
          parameterKey,
          timeIndex,
        );
        await _notifications.cancel(notificationId);
      }
      log.i(
        'Уведомления отменены для параметра $parameterKey пациента $patientId',
      );
    } catch (e) {
      log.e('Ошибка отмены уведомлений для параметра: $e');
    }
  }

  /// Генерация уникального ID для уведомления
  int _generateNotificationId(
    int patientId,
    String parameterKey,
    int timeIndex,
  ) {
    // Создаем уникальный ID на основе patientId, parameterKey и timeIndex
    final keyHash = parameterKey.hashCode.abs() % 1000;
    return patientId * 100000 + keyHash * 100 + timeIndex;
  }

  /// Получение следующего экземпляра времени
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Если время уже прошло сегодня, планируем на завтра
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Показать тестовое уведомление для закрепленного параметра
  Future<void> showTestPinnedParameterNotification({
    required int patientId,
    required PinnedParameter parameter,
  }) async {
    try {
      await _notificationService.initialize();

      final androidDetails = AndroidNotificationDetails(
        'pinned_parameters_channel',
        'Закрепленные показатели',
        channelDescription: 'Напоминания о измерении закрепленных показателей',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@drawable/ic_notification_health',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: [
          AndroidNotificationAction(
            'measure_now',
            'Измерить сейчас',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_accept'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'remind_later',
            'Напомнить позже',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_decline'),
            showsUserInterface: false,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: 'pinned_parameter_category',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = 'Время измерить ${parameter.label}';
      final body =
          'Тестовое напоминание: измерьте ${parameter.label.toLowerCase()}';

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        '$body\n\nТестовое уведомление с кнопками действий',
        notificationDetails,
        payload: 'pinned_${patientId}_${parameter.key}',
      );

      log.i('Тестовое уведомление показано для параметра ${parameter.key}');
    } catch (e) {
      log.e('Ошибка показа тестового уведомления: $e');
    }
  }

  /// Обновление уведомлений при изменении закрепленных параметров
  Future<void> updatePinnedParameterNotifications({
    required int patientId,
    required List<PinnedParameter> pinnedParameters,
  }) async {
    // Отменяем старые уведомления
    await cancelPinnedParameterNotifications(patientId);

    // Планируем новые уведомления
    await schedulePinnedParameterNotifications(
      patientId: patientId,
      pinnedParameters: pinnedParameters,
    );
  }
}
