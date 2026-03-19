import 'app_logger.dart';

/// Extension methods for convenient logging on any object
///
/// These extensions allow you to log any object directly without
/// explicitly calling the logger methods.
///
/// Usage:
/// ```dart
/// 'User logged in'.logInfo();
/// myObject.logDebug();
/// exception.logError('Failed to process', stackTrace);
/// ```
extension LogObjectExtension on Object {
  /// Log this object at trace level
  void logTrace({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log.trace(
      toString(),
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log this object at debug level
  void logDebug({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log.debug(
      toString(),
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log this object at info level
  void logInfo({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log.info(
      toString(),
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log this object at warning level
  void logWarning({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log.warning(
      toString(),
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log this object at error level
  void logError({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log.error(
      toString(),
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log this object at fatal level
  void logFatal({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log.fatal(
      toString(),
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }
}

/// Extension for short aliases on String
///
/// Provides convenient short-hand methods for quick logging.
///
/// Usage:
/// ```dart
/// 'Debug message'.logD();
/// 'Info message'.logI();
/// 'Warning message'.logW();
/// 'Error message'.logE();
/// ```
extension LogStringExtension on String {
  /// Alias for logTrace()
  void logT({LogContext context = LogContext.ui}) =>
      log.t(this, context: context);

  /// Alias for logDebug()
  void logD({LogContext context = LogContext.ui}) =>
      log.d(this, context: context);

  /// Alias for logInfo()
  void logI({LogContext context = LogContext.ui}) =>
      log.i(this, context: context);

  /// Alias for logWarning()
  void logW({LogContext context = LogContext.ui}) =>
      log.w(this, context: context);

  /// Alias for logError()
  void logE({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
  }) => log.e(this, context: context, error: error, stackTrace: stackTrace);

  /// Alias for logFatal()
  void logF({
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
  }) => log.f(this, context: context, error: error, stackTrace: stackTrace);
}

/// Extension for logging exceptions with stack traces
///
/// Usage:
/// ```dart
/// try {
///   // ... code
/// } catch (e, stackTrace) {
///   e.logException(stackTrace, 'Operation failed');
/// }
/// ```
extension LogExceptionExtension on Object {
  /// Log this exception with stack trace and message
  void logException(StackTrace? stackTrace, [String? message]) {
    log.error(
      message ?? 'Exception occurred',
      context: LogContext.ui,
      error: this,
      stackTrace: stackTrace,
    );
  }
}

/// Extension for logging Map data
///
/// Usage:
/// ```dart
/// {'user': 'John', 'age': 30}.logAsData('User data');
/// ```
extension LogMapExtension on Map {
  /// Log this map as structured data
  void logAsData(String label, {LogContext context = LogContext.ui}) {
    log.info(
      '$label: $this',
      context: context,
      extra: {'label': label, 'data': this},
    );
  }
}

/// Extension for logging List data
///
/// Usage:
/// ```dart
/// [1, 2, 3].logAsList('Numbers');
/// ```
extension LogListExtension on List {
  /// Log this list with a label
  void logAsList(String label, {LogContext context = LogContext.ui}) {
    log.debug(
      '$label ($length items): $this',
      context: context,
      extra: {'label': label, 'count': length},
    );
  }
}

/// Extension for logging Duration
///
/// Usage:
/// ```dart
/// final duration = Duration(milliseconds: 150);
/// duration.logPerformance('API call');
/// ```
extension LogDurationExtension on Duration {
  /// Log this duration as a performance metric
  void logPerformance(String operation, {LogContext context = LogContext.ui}) {
    log.performance(operation, this);
  }
}

/// Extension for logging Future results
///
/// Usage:
/// ```dart
/// final result = await fetchData().logResult('Fetch operation');
/// ```
extension LogFutureExtension<T> on Future<T> {
  /// Log the result of this future
  Future<T> logResult(
    String operation, {
    LogContext context = LogContext.ui,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await this;
      stopwatch.stop();
      log.performance(operation, stopwatch.elapsed);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      log.error(
        '$operation failed after ${stopwatch.elapsed.inMilliseconds}ms',
        context: context,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
