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
class AppLogger {
  void d(String message) => print('[DEBUG] $message');
  void i(String message) => print('[INFO] $message');
  void w(String message) => print('[WARNING] $message');
  void e(String message) => print('[ERROR] $message');
  void t(String message) => print('[TRACE] $message');
}

final log = AppLogger();

/// Логгер для продакшена (без цветов и стектрейсов)
final logProd = AppLogger();
