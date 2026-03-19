import 'app_logger.dart';

/// Mixin for logging in BLoC/Cubit classes
///
/// Provides structured logging methods specifically designed for BLoC pattern.
///
/// Usage:
/// ```dart
/// class MyBloc extends Bloc<MyEvent, MyState> with BlocLogMixin {
///   MyBloc() : super(MyInitial()) {
///     setLogContext(LogContext.diary);
///     logEvent('MyBloc initialized');
///   }
///
///   void someMethod() {
///     try {
///       logEvent('Processing data started');
///       // ... logic
///       logState('Data processed successfully');
///     } catch (e, stackTrace) {
///       logError('Data processing failed', e, stackTrace);
///     }
///   }
/// }
/// ```
mixin BlocLogMixin {
  late final LogContext _logContext;

  /// Set the logging context for this BLoC
  void setLogContext(LogContext context) {
    _logContext = context;
  }

  /// Log a BLoC event
  void logEvent(String event, {Map<String, dynamic>? extra}) {
    log.debug('BLoC Event: $event', context: _logContext, extra: extra);
  }

  /// Log a BLoC state change
  void logState(String state, {Map<String, dynamic>? extra}) {
    log.debug('BLoC State: $state', context: _logContext, extra: extra);
  }

  /// Log a BLoC error
  void logError(String operation, Object error, [StackTrace? stackTrace]) {
    log.error(
      'BLoC Error in $operation: $error',
      context: _logContext,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Mixin for logging in Repository classes
///
/// Provides structured logging methods specifically designed for repository pattern.
///
/// Usage:
/// ```dart
/// class MyRepository with RepositoryLogMixin {
///   MyRepository() {
///     setLogContext(LogContext.api);
///   }
///
///   Future<void> fetchData() async {
///     final stopwatch = Stopwatch()..start();
///     try {
///       logApiCall('GET', '/data');
///       // ... HTTP request
///       logApiResponse('GET', '/data', 200);
///       log.performance('fetchData', stopwatch.elapsed);
///     } catch (e, stackTrace) {
///       logApiResponse('GET', '/data', 500);
///       logError('fetchData failed', e, stackTrace);
///     }
///   }
/// }
/// ```
mixin RepositoryLogMixin {
  late final LogContext _logContext;

  /// Set the logging context for this repository
  void setLogContext(LogContext context) {
    _logContext = context;
  }

  /// Log an API request
  void logApiCall(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
  }) {
    log.apiRequest(method, endpoint, data: data);
  }

  /// Log an API response
  void logApiResponse(
    String method,
    String endpoint,
    int statusCode, {
    dynamic data,
  }) {
    log.apiResponse(method, endpoint, statusCode, data: data);
  }

  /// Log a repository error
  void logError(String operation, Object error, [StackTrace? stackTrace]) {
    log.error(
      'Repository Error in $operation: $error',
      context: _logContext,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a cache operation
  void logCacheOperation(
    String operation,
    String key, {
    bool? hit,
    dynamic data,
  }) {
    log.debug(
      'Cache $operation: $key${hit != null ? (hit ? ' (HIT)' : ' (MISS)') : ''}',
      context: LogContext.cache,
      extra: {'operation': operation, 'key': key, 'hit': hit, 'data': data},
    );
  }
}

/// Mixin for logging in Service classes
///
/// Provides structured logging methods for service layer.
///
/// Usage:
/// ```dart
/// class NotificationService with ServiceLogMixin {
///   NotificationService() {
///     setLogContext(LogContext.notification);
///   }
///
///   void sendNotification(String title, String body) {
///     logInfo('Sending notification: $title');
///     try {
///       // ... send notification
///       logSuccess('Notification sent successfully');
///     } catch (e, stackTrace) {
///       logError('Failed to send notification', e, stackTrace);
///     }
///   }
/// }
/// ```
mixin ServiceLogMixin {
  late final LogContext _logContext;

  /// Set the logging context for this service
  void setLogContext(LogContext context) {
    _logContext = context;
  }

  /// Log an info message
  void logInfo(String message, {Map<String, dynamic>? extra}) {
    log.info(message, context: _logContext, extra: extra);
  }

  /// Log a debug message
  void logDebug(String message, {Map<String, dynamic>? extra}) {
    log.debug(message, context: _logContext, extra: extra);
  }

  /// Log a warning message
  void logWarning(String message, {Object? error, StackTrace? stackTrace}) {
    log.warning(
      message,
      context: _logContext,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  void logError(String message, Object error, [StackTrace? stackTrace]) {
    log.error(
      message,
      context: _logContext,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a success message
  void logSuccess(String message, {Map<String, dynamic>? extra}) {
    log.info('✓ $message', context: _logContext, extra: extra);
  }
}
