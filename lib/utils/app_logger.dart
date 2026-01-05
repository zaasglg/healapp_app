import 'package:logger/logger.dart';

/// Глобальный логгер приложения
/// Используй `log` для логирования вместо print()
///
/// Примеры:
/// ```dart
/// log.d('Debug message');      // Debug
/// log.i('Info message');       // Info
/// log.w('Warning message');    // Warning
/// log.e('Error message');      // Error
/// log.t('Trace message');      // Trace (verbose)
/// ```
final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Level.debug,
);

/// Логгер для продакшена (без цветов и стектрейсов)
final logProd = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 3,
    lineLength: 80,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTime,
  ),
  level: Level.warning,
);
