import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Log levels for structured logging
enum LogLevel { trace, debug, info, warning, error, fatal }

/// Log context for feature/module identification
enum LogContext {
  auth,
  api,
  diary,
  routeSheet,
  ui,
  navigation,
  cache,
  repository,
  notification,
  bloc,
}

/// Professional production-ready logger facade for HealApp
///
/// This logger provides:
/// - Structured logging with clean output for development
/// - Automatic release mode filtering
/// - Convenient methods: trace, debug, info, warning, error, fatal
/// - Short aliases: t, d, i, w, e, f
/// - Proper error and stackTrace handling
/// - Firebase Crashlytics / Sentry integration ready
///
/// Usage:
/// ```dart
/// // Basic usage
/// log.info('User logged in');
///
/// // With context
/// log.debug('API request', context: LogContext.api);
///
/// // With error and stackTrace
/// log.error('Failed to load data', error: e, stackTrace: stackTrace);
///
/// // Short aliases
/// log.i('Info message');
/// log.e('Error message', error: e);
/// ```
class AppLogger {
  /// Singleton instance
  static final AppLogger _instance = AppLogger._internal();

  /// Factory constructor returns singleton
  factory AppLogger() => _instance;

  /// Internal constructor
  AppLogger._internal();

  /// Logger instance from logger package
  late final Logger _logger;

  /// Whether logger is initialized
  bool _isInitialized = false;

  /// Minimum log level for current environment
  Level _minLevel = Level.debug;

  /// Crashlytics error reporter callback
  void Function(Object error, StackTrace? stackTrace, String message)?
  _crashlyticsReporter;

  /// Sentry error reporter callback
  void Function(Object error, StackTrace? stackTrace, String message)?
  _sentryReporter;

  /// Initialize the logger with configuration
  ///
  /// Should be called once at app startup (e.g., in main.dart)
  /// Automatically detects release mode and adjusts settings
  void initialize({
    Level? minLevel,
    bool enableColors = false,
    bool enableEmojis = true,
    int methodCount = 0,
    int errorMethodCount = 8,
    int lineLength = 120,
    void Function(Object error, StackTrace? stackTrace, String message)?
    crashlyticsReporter,
    void Function(Object error, StackTrace? stackTrace, String message)?
    sentryReporter,
  }) {
    if (_isInitialized) {
      developer.log('Logger already initialized', name: 'AppLogger');
      return;
    }

    // Set minimum level based on environment
    _minLevel = minLevel ?? (kReleaseMode ? Level.warning : Level.debug);

    // Store error reporters
    _crashlyticsReporter = crashlyticsReporter;
    _sentryReporter = sentryReporter;

    // Use custom printer for clean output
    final printer = _CleanPrinter(
      errorMethodCount: errorMethodCount,
      enableEmojis: enableEmojis,
    );

    // Create logger instance
    _logger = Logger(
      filter: kReleaseMode ? ProductionFilter() : DevelopmentFilter(),
      printer: printer,
      output: ConsoleOutput(),
    );

    _isInitialized = true;

    // Log initialization
    _logInternal(
      Level.info,
      'AppLogger initialized',
      context: LogContext.ui,
      extra: {'minLevel': _minLevel.name, 'isRelease': kReleaseMode},
    );
  }

  /// Ensure logger is initialized (auto-initialize if needed)
  void _ensureInitialized() {
    if (!_isInitialized) {
      initialize();
    }
  }

  /// Log at trace level (most verbose)
  void trace(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _logInternal(
      Level.trace,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log at debug level
  void debug(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _logInternal(
      Level.debug,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log at info level
  void info(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _logInternal(
      Level.info,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log at warning level
  void warning(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _logInternal(
      Level.warning,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Log at error level
  void error(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _logInternal(
      Level.error,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );

    // Report to Crashlytics/Sentry if configured
    if (error != null) {
      _reportToExternalServices(error, stackTrace, message);
    }
  }

  /// Log at fatal level (highest severity)
  void fatal(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _logInternal(
      Level.fatal,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );

    // Always report fatal errors to external services
    if (error != null) {
      _reportToExternalServices(error, stackTrace, message);
    } else {
      _reportToExternalServices(Exception(message), stackTrace, message);
    }
  }

  // ========== Short aliases for convenience ==========

  /// Alias for trace()
  void t(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) => trace(
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
    extra: extra,
  );

  /// Alias for debug()
  void d(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) => debug(
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
    extra: extra,
  );

  /// Alias for info()
  void i(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) => info(
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
    extra: extra,
  );

  /// Alias for warning()
  void w(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) => warning(
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
    extra: extra,
  );

  /// Alias for error()
  void e(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) => this.error(
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
    extra: extra,
  );

  /// Alias for fatal()
  void f(
    String message, {
    LogContext context = LogContext.ui,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) => fatal(
    message,
    context: context,
    error: error,
    stackTrace: stackTrace,
    extra: extra,
  );

  // ========== Specialized logging methods ==========

  /// Log API request
  void apiRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? data,
  }) {
    debug(
      'API Request: $method $endpoint',
      context: LogContext.api,
      extra: {
        'method': method,
        'endpoint': endpoint,
        if (data != null) 'data': data,
      },
    );
  }

  /// Log API response
  void apiResponse(
    String method,
    String endpoint,
    int statusCode, {
    dynamic data,
  }) {
    final level = statusCode >= 400 ? Level.warning : Level.info;
    _logInternal(
      level,
      'API Response: $method $endpoint -> $statusCode',
      context: LogContext.api,
      extra: {
        'method': method,
        'endpoint': endpoint,
        'status': statusCode,
        if (data != null) 'data': data,
      },
    );
  }

  /// Log authentication event
  void authEvent(String event, {Map<String, dynamic>? userData}) {
    info(
      'Auth Event: $event',
      context: LogContext.auth,
      extra: {'event': event, if (userData != null) 'user': userData},
    );
  }

  /// Log navigation event
  void navigation(String from, String to, {String? reason}) {
    debug(
      'Navigation: $from -> $to',
      context: LogContext.navigation,
      extra: {'from': from, 'to': to, if (reason != null) 'reason': reason},
    );
  }

  /// Log diary action
  void diaryAction(
    String action,
    String patientId, {
    Map<String, dynamic>? data,
  }) {
    info(
      'Diary: $action for patient $patientId',
      context: LogContext.diary,
      extra: {
        'action': action,
        'patientId': patientId,
        if (data != null) 'data': data,
      },
    );
  }

  /// Log performance metric
  void performance(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metrics,
  }) {
    info(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      context: LogContext.ui,
      extra: {
        'operation': operation,
        'duration_ms': duration.inMilliseconds,
        ...?metrics,
      },
    );
  }

  /// Log BLoC event
  void blocEvent(String blocName, String event, {Map<String, dynamic>? extra}) {
    debug(
      'BLoC Event [$blocName]: $event',
      context: LogContext.bloc,
      extra: {'bloc': blocName, 'event': event, ...?extra},
    );
  }

  /// Log BLoC state
  void blocState(String blocName, String state, {Map<String, dynamic>? extra}) {
    debug(
      'BLoC State [$blocName]: $state',
      context: LogContext.bloc,
      extra: {'bloc': blocName, 'state': state, ...?extra},
    );
  }

  /// Log BLoC error
  void blocError(
    String blocName,
    String operation,
    Object error,
    StackTrace? stackTrace,
  ) {
    this.error(
      'BLoC Error [$blocName]: $operation failed',
      context: LogContext.bloc,
      error: error,
      stackTrace: stackTrace,
      extra: {'bloc': blocName, 'operation': operation},
    );
  }

  /// Log notification event
  void notification(String type, String message, {Map<String, dynamic>? data}) {
    info(
      'Notification [$type]: $message',
      context: LogContext.notification,
      extra: {'type': type, 'message': message, ...?data},
    );
  }

  // ========== Internal methods ==========

  /// Internal logging method
  void _logInternal(
    Level level,
    String message, {
    required LogContext context,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    _ensureInitialized();

    // Skip if below minimum level
    if (level.index < _minLevel.index) {
      return;
    }

    // Format message with context
    final contextStr = context.name.toUpperCase();
    final formattedMessage = '[$contextStr] $message';

    // Add extra data if present
    final extraStr = extra != null && extra.isNotEmpty ? ' | $extra' : '';
    final fullMessage = '$formattedMessage$extraStr';

    // Log using logger package
    _logger.log(level, fullMessage, error: error, stackTrace: stackTrace);
  }

  /// Report error to external services (Crashlytics, Sentry)
  void _reportToExternalServices(
    Object error,
    StackTrace? stackTrace,
    String message,
  ) {
    // Report to Crashlytics if configured
    _crashlyticsReporter?.call(error, stackTrace, message);

    // Report to Sentry if configured
    _sentryReporter?.call(error, stackTrace, message);
  }

  /// Close the logger (call when app terminates)
  void close() {
    _logger.close();
  }
}

/// Global logger instance for easy access throughout the app
///
/// Usage:
/// ```dart
/// import 'package:healapp_mobile/core/logging/logging.dart';
///
/// log.info('Hello from anywhere in the app');
/// ```
final log = AppLogger();

/// Custom printer for clean, minimal log output
class _CleanPrinter extends LogPrinter {
  final int errorMethodCount;
  final bool enableEmojis;

  _CleanPrinter({this.errorMethodCount = 8, this.enableEmojis = true});

  static final Map<Level, String> _levelEmojis = {
    Level.trace: '📝',
    Level.debug: '🐛',
    Level.info: '💡',
    Level.warning: '⚠️',
    Level.error: '❌',
    Level.fatal: '💀',
  };

  @override
  List<String> log(LogEvent event) {
    final buffer = <String>[];

    // Time
    final time = DateTime.now();
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';

    // Level emoji
    final emoji = enableEmojis ? '${_levelEmojis[event.level]} ' : '';

    // Main message
    buffer.add('$timeStr $emoji${event.message}');

    // Error and stack trace for errors
    if (event.error != null) {
      buffer.add('  Error: ${event.error}');
      if (event.stackTrace != null && errorMethodCount > 0) {
        final lines = event.stackTrace.toString().split('\n');
        for (var i = 0; i < lines.length && i < errorMethodCount; i++) {
          buffer.add('  ${lines[i]}');
        }
      }
    }

    return buffer;
  }
}
