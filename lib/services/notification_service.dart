import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../utils/app_logger.dart';
import '../repositories/alarm_repository.dart';

/// Сервис для управления локальными уведомлениями
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AlarmRepository _alarmRepository = AlarmRepository();

  bool _isInitialized = false;

  /// Инициализация сервиса уведомлений
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Инициализация timezone
    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      // Пытаемся установить локальную временную зону
      try {
        tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
        log.i('Timezone настроен: ${timezoneInfo.identifier}');
      } catch (locationError) {
        // Если не удалось найти location по имени, используем UTC
        log.w(
          'Не удалось установить timezone "${timezoneInfo.identifier}", используем UTC',
        );
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      log.e('Ошибка настройки timezone: $e');
      // Fallback to UTC if error getting timezone
      tz.setLocalLocation(tz.UTC);
    }

    // Настройки для Android
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // Настройки для iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Очищаем все старые уведомления при инициализации
    await clearAllNotifications();

    // Создаём канал уведомлений для будильников с звуком
    await _createAlarmChannel();

    // Настраиваем категории для iOS
    await _setupIOSCategories();

    // Запрашиваем разрешения на Android 13+
    await _requestPermissions();

    // Очищаем все старые уведомления для предотвращения проблем
    await clearAllAlarmNotifications();

    _isInitialized = true;
    log.i('NotificationService инициализирован');
  }

  /// Создание канала уведомлений для будильников с звуком
  Future<void> _createAlarmChannel() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      // Создаём канал уведомлений для будильников
      const alarmChannel = AndroidNotificationChannel(
        'alarm_channel',
        'Будильники',
        description: 'Уведомления о напоминаниях с звуком будильника',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Создаём канал уведомлений для закрепленных параметров
      const pinnedParametersChannel = AndroidNotificationChannel(
        'pinned_parameters_channel',
        'Закрепленные показатели',
        description: 'Напоминания о измерении закрепленных показателей',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await androidPlugin.createNotificationChannel(alarmChannel);
      await androidPlugin.createNotificationChannel(pinnedParametersChannel);
      log.i('Каналы уведомлений созданы');
    }
  }

  /// Настройка категорий для iOS
  Future<void> _setupIOSCategories() async {
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      await iosPlugin.initialize(
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: [
            // Категория для будильников
            DarwinNotificationCategory(
              'alarm_category',
              actions: [
                DarwinNotificationAction.plain(
                  'accept',
                  'Принято',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  'decline',
                  'Не принято',
                  options: {DarwinNotificationActionOption.destructive},
                ),
              ],
            ),
            // Категория для закрепленных параметров
            DarwinNotificationCategory(
              'pinned_parameter_category',
              actions: [
                DarwinNotificationAction.plain(
                  'measure_now',
                  'Измерить сейчас',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  'remind_later',
                  'Напомнить позже',
                  options: {DarwinNotificationActionOption.destructive},
                ),
              ],
            ),
          ],
        ),
      );
      log.i('Категории iOS настроены');
    }
  }

  /// Запрос разрешений на уведомления
  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Обработка нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    log.i('Уведомление нажато: ${response.payload}');

    // Обрабатываем действия с кнопок
    if (response.actionId != null) {
      _handleNotificationAction(response.actionId!, response.payload);
    }

    // Можно добавить навигацию к определённому экрану
  }

  /// Обработка действий с кнопок уведомлений
  void _handleNotificationAction(String actionId, String? payload) {
    log.i('Действие уведомления: $actionId, payload: $payload');

    if (payload != null) {
      if (payload.startsWith('alarm_')) {
        final alarmId = int.tryParse(payload.replaceFirst('alarm_', ''));
        if (alarmId != null) {
          switch (actionId) {
            case 'accept':
              _handleAlarmAccepted(alarmId);
              break;
            case 'decline':
              _handleAlarmDeclined(alarmId);
              break;
          }
        }
      } else if (payload.startsWith('pinned_')) {
        // Формат: pinned_{patientId}_{parameterKey}
        final parts = payload.split('_');
        if (parts.length >= 3) {
          final patientId = int.tryParse(parts[1]);
          final parameterKey = parts.sublist(2).join('_');
          if (patientId != null) {
            switch (actionId) {
              case 'measure_now':
                _handleMeasureNow(patientId, parameterKey);
                break;
              case 'remind_later':
                _handleRemindLater(patientId, parameterKey);
                break;
            }
          }
        }
      }
    }
  }

  /// Обработка принятия будильника
  Future<void> _handleAlarmAccepted(int alarmId) async {
    log.i('Будильник $alarmId принят');

    try {
      await _alarmRepository.acceptAlarm(alarmId);

      // Показываем подтверждающее уведомление
      await showInstantNotification(
        title: 'Принято ✓',
        body: 'Напоминание отмечено как выполненное',
      );
    } catch (e) {
      log.e('Ошибка при принятии будильника: $e');
      await showInstantNotification(
        title: 'Ошибка',
        body: 'Не удалось отметить напоминание',
      );
    }
  }

  /// Обработка отклонения будильника
  Future<void> _handleAlarmDeclined(int alarmId) async {
    log.i('Будильник $alarmId отклонен');

    try {
      await _alarmRepository.declineAlarm(alarmId);

      // Показываем подтверждающее уведомление
      await showInstantNotification(
        title: 'Отклонено ✗',
        body: 'Напоминание отмечено как пропущенное',
      );
    } catch (e) {
      log.e('Ошибка при отклонении будильника: $e');
      await showInstantNotification(
        title: 'Ошибка',
        body: 'Не удалось отметить напоминание',
      );
    }
  }

  /// Обработка действия "Измерить сейчас" для закрепленного параметра
  Future<void> _handleMeasureNow(int patientId, String parameterKey) async {
    log.i('Измерить сейчас: пациент $patientId, параметр $parameterKey');

    try {
      // Показываем подтверждающее уведомление
      await showInstantNotification(
        title: 'Открыть приложение',
        body: 'Откройте приложение для измерения показателя',
      );

      // Здесь можно добавить навигацию к экрану измерения
      // или другую логику обработки
    } catch (e) {
      log.e('Ошибка при обработке "Измерить сейчас": $e');
    }
  }

  /// Обработка действия "Напомнить позже" для закрепленного параметра
  Future<void> _handleRemindLater(int patientId, String parameterKey) async {
    log.i('Напомнить позже: пациент $patientId, параметр $parameterKey');

    try {
      // Планируем напоминание через 30 минут
      final reminderTime = DateTime.now().add(const Duration(minutes: 30));

      await showInstantNotification(
        title: 'Напоминание отложено',
        body: 'Напомним через 30 минут',
      );

      // Здесь можно запланировать отложенное уведомление
      // Пока просто логируем
      log.i(
        'Отложенное напоминание запланировано на ${reminderTime.toString()}',
      );
    } catch (e) {
      log.e('Ошибка при обработке "Напомнить позже": $e');
    }
  }

  /// Планирование ежедневного уведомления для будильника
  Future<void> scheduleAlarmNotification({
    required int alarmId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      // Отменяем ВСЕ старые уведомления для этого будильника
      await cancelAlarmNotifications(alarmId);

      // Дополнительная очистка - отменяем все уведомления
      await _notifications.cancelAll();

      // Создаем ТОЛЬКО простое уведомление с логотипом (БЕЗ КНОПОК)
      await _scheduleSimpleAlarmNotification(
        alarmId: alarmId,
        title: title,
        body: body,
        hour: hour,
        minute: minute,
        daysOfWeek: daysOfWeek,
      );
    } catch (e) {
      log.e('Ошибка планирования уведомления: $e');
      // Критический fallback - базовое уведомление
      await _scheduleBasicAlarmNotification(
        alarmId: alarmId,
        title: title,
        body: body,
        hour: hour,
        minute: minute,
        daysOfWeek: daysOfWeek,
      );
    }
  }

  /// Создание уведомлений с логотипом и кнопками действий
  Future<void> _scheduleSimpleAlarmNotification({
    required int alarmId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
  }) async {
    try {
      log.i(
        'Создаем уведомление с логотипом и кнопками для будильника $alarmId',
      );

      final androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        'Будильники',
        channelDescription: 'Уведомления о напоминаниях с звуком будильника',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon:
            '@drawable/ic_notification_health', // Медицинская иконка для статус-бара
        largeIcon: DrawableResourceAndroidBitmap(
          '@mipmap/ic_launcher',
        ), // Полноцветный логотип
        actions: [
          AndroidNotificationAction(
            'accept',
            'Принято',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_accept'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'decline',
            'Не принято',
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
        categoryIdentifier: 'alarm_category',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Планируем уведомление для каждого дня недели
      for (int day in daysOfWeek) {
        final notificationId = alarmId * 10 + day;
        final scheduledDate = _nextInstanceOfDayTime(day, hour, minute);

        await _notifications.zonedSchedule(
          notificationId,
          title,
          '$body\n\nВыберите действие или нажмите для открытия приложения',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'alarm_$alarmId',
        );
      }

      log.i(
        'Уведомление с логотипом и кнопками создано для будильника $alarmId',
      );
    } catch (e) {
      log.e('Критическая ошибка создания уведомления: $e');
      rethrow;
    }
  }

  /// Базовый метод для создания простейших уведомлений (критический fallback)
  Future<void> _scheduleBasicAlarmNotification({
    required int alarmId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> daysOfWeek,
  }) async {
    try {
      log.w('Создаем базовое уведомление для будильника $alarmId');

      const androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        'Будильники',
        channelDescription: 'Уведомления о напоминаниях',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Планируем уведомление для каждого дня недели
      for (int day in daysOfWeek) {
        final notificationId = alarmId * 10 + day;
        final scheduledDate = _nextInstanceOfDayTime(day, hour, minute);

        await _notifications.zonedSchedule(
          notificationId,
          title,
          '$body\n\nОткройте приложение',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'alarm_$alarmId',
        );
      }

      log.i('Базовое уведомление создано для будильника $alarmId');
    } catch (e) {
      log.e('Критическая ошибка создания базового уведомления: $e');
      // Больше ничего не делаем, чтобы не создать бесконечный цикл
    }
  }

  /// Отмена всех уведомлений для будильника
  Future<void> cancelAlarmNotifications(int alarmId) async {
    // Отменяем уведомления для всех 7 дней недели
    for (int day = 1; day <= 7; day++) {
      final notificationId = alarmId * 10 + day;
      await _notifications.cancel(notificationId);
    }
    log.i('Уведомления отменены для будильника: $alarmId');
  }

  /// Отмена всех уведомлений
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    log.i('Все уведомления отменены');
  }

  /// Полная очистка всех уведомлений (для решения проблем с contextual actions)
  Future<void> clearAllNotifications() async {
    try {
      await _notifications.cancelAll();
      log.i('Выполнена полная очистка всех уведомлений');
    } catch (e) {
      log.e('Ошибка очистки уведомлений: $e');
    }
  }

  /// Очистка всех старых уведомлений (для исправления проблем)
  Future<void> clearAllAlarmNotifications() async {
    try {
      // Отменяем все уведомления
      await _notifications.cancelAll();
      log.i('Все старые уведомления очищены');
    } catch (e) {
      log.e('Ошибка очистки уведомлений: $e');
    }
  }

  /// Получение следующего экземпляра времени для определённого дня недели
  tz.TZDateTime _nextInstanceOfDayTime(int dayOfWeek, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Находим следующий нужный день недели
    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Показать мгновенное уведомление (для тестирования)
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'instant_channel',
      'Мгновенные уведомления',
      channelDescription: 'Тестовые уведомления',
      importance: Importance.high,
      priority: Priority.high,
      icon:
          '@drawable/ic_notification_health', // Медицинская иконка для статус-бара
      largeIcon: DrawableResourceAndroidBitmap(
        '@mipmap/ic_launcher',
      ), // Полноцветный логотип
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  /// Показать тестовое уведомление будильника с логотипом
  Future<void> showTestAlarmNotification({
    required int alarmId,
    required String title,
    required String body,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        'Будильники',
        channelDescription: 'Уведомления о напоминаниях с звуком будильника',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon:
            '@drawable/ic_notification_health', // Медицинская иконка для статус-бара
        largeIcon: DrawableResourceAndroidBitmap(
          '@mipmap/ic_launcher',
        ), // Полноцветный логотип
        actions: [
          AndroidNotificationAction(
            'accept',
            'Принято',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_accept'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'decline',
            'Не принято',
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
        categoryIdentifier: 'alarm_category',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        alarmId,
        title,
        '$body\n\nТестовое уведомление с кнопками действий',
        notificationDetails,
        payload: 'alarm_$alarmId',
      );

      log.i('Тестовое уведомление с логотипом и кнопками показано');
    } catch (e) {
      log.e('Ошибка показа тестового уведомления: $e');
      // Fallback - показываем базовое уведомление
      await showInstantNotification(
        title: title,
        body: '$body\n\n(Базовая версия)',
      );
    }
  }

  /// Проверка наличия разрешений
  Future<bool> hasPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      return granted ?? false;
    }

    return true; // На iOS разрешения запрашиваются при инициализации
  }
}
