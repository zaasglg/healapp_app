import 'app_logger.dart';
import 'log_mixin.dart';
import 'log_extensions.dart';
import 'log_analytics.dart';

/// Examples of using the structured logging system in HealApp
///
/// This file demonstrates various logging patterns and best practices.
/// Copy these patterns into your code as needed.

// ============================================================================
// 1. BASIC USAGE
// ============================================================================

void basicLoggingExamples() {
  // Basic logging at different levels
  log.trace('Very detailed trace message');
  log.debug('Debug information for development');
  log.info('General information about app operation');
  log.warning('Warning about potential issues');
  log.error('Error occurred during operation');
  log.fatal('Critical error that may crash the app');

  // Short aliases for convenience
  log.t('Trace alias');
  log.d('Debug alias');
  log.i('Info alias');
  log.w('Warning alias');
  log.e('Error alias');
  log.f('Fatal alias');
}

// ============================================================================
// 2. LOGGING WITH CONTEXT
// ============================================================================

void contextLoggingExamples() {
  // Log with specific context for better filtering
  log.debug('API request started', context: LogContext.api);
  log.info('User logged in', context: LogContext.auth);
  log.debug('Diary entry saved', context: LogContext.diary);
  log.info('Route sheet updated', context: LogContext.routeSheet);
  log.debug('Widget rebuilt', context: LogContext.ui);
  log.debug('Navigation to home', context: LogContext.navigation);
  log.debug('Cache hit', context: LogContext.cache);
  log.error('Repository error', context: LogContext.repository);
  log.info('Notification received', context: LogContext.notification);
  log.debug('BLoC state changed', context: LogContext.bloc);
}

// ============================================================================
// 3. LOGGING ERRORS WITH STACK TRACES
// ============================================================================

void errorLoggingExamples() {
  try {
    // Some operation that might fail
    throw Exception('Something went wrong');
  } catch (e, stackTrace) {
    // Always pass error and stackTrace as separate parameters
    log.error(
      'Operation failed',
      context: LogContext.api,
      error: e,
      stackTrace: stackTrace,
    );

    // For critical errors, use fatal
    log.fatal(
      'Critical failure',
      context: LogContext.ui,
      error: e,
      stackTrace: stackTrace,
    );
  }
}

// ============================================================================
// 4. LOGGING WITH EXTRA DATA
// ============================================================================

void extraDataLoggingExamples() {
  // Log with structured extra data
  log.info(
    'User action performed',
    context: LogContext.ui,
    extra: {'action': 'button_click', 'screen': 'home', 'user_id': '12345'},
  );

  // API logging with request details
  log.debug(
    'API Request',
    context: LogContext.api,
    extra: {
      'method': 'POST',
      'endpoint': '/api/v1/diary',
      'payload_size': 1024,
    },
  );

  // Performance logging
  log.info(
    'Operation completed',
    context: LogContext.ui,
    extra: {'duration_ms': 150, 'items_processed': 42, 'success_rate': 0.95},
  );
}

// ============================================================================
// 5. SPECIALIZED LOGGING METHODS
// ============================================================================

void specializedLoggingExamples() {
  // API logging
  log.apiRequest('GET', '/api/v1/users');
  log.apiResponse('GET', '/api/v1/users', 200);
  log.apiResponse('POST', '/api/v1/users', 400); // Will log as warning

  // Authentication events
  log.authEvent('login', userData: {'user_id': '12345'});
  log.authEvent('logout');

  // Navigation
  log.navigation('/login', '/home', reason: 'User authenticated');

  // Diary actions
  log.diaryAction('create_entry', 'patient_123', data: {'type': 'measurement'});

  // Performance
  final stopwatch = Stopwatch()..start();
  // ... some operation
  stopwatch.stop();
  log.performance('fetchUserData', stopwatch.elapsed);

  // BLoC logging
  log.blocEvent('AuthBloc', 'LoginButtonPressed');
  log.blocState('AuthBloc', 'AuthAuthenticated');
  log.blocError('AuthBloc', 'login', Exception('Invalid credentials'), null);

  // Notifications
  log.notification('push', 'New message received', data: {'sender': 'John'});
}

// ============================================================================
// 6. USING MIXINS IN BLOC
// ============================================================================

/// Example BLoC with logging mixin
class ExampleBloc with BlocLogMixin {
  ExampleBloc() {
    setLogContext(LogContext.diary);
    logEvent('ExampleBloc initialized');
  }

  void processData() {
    try {
      logEvent('Processing data started');
      // ... processing logic
      logState('Data processed successfully');
    } catch (e, stackTrace) {
      logError('processData', e, stackTrace);
    }
  }
}

// ============================================================================
// 7. USING MIXINS IN REPOSITORY
// ============================================================================

/// Example Repository with logging mixin
class ExampleRepository with RepositoryLogMixin {
  ExampleRepository() {
    setLogContext(LogContext.api);
  }

  Future<void> fetchData() async {
    final stopwatch = Stopwatch()..start();

    try {
      logApiCall('GET', '/data');

      // ... HTTP request simulation
      await Future.delayed(const Duration(milliseconds: 100));

      logApiResponse('GET', '/data', 200);
      log.performance('fetchData', stopwatch.elapsed);
    } catch (e, stackTrace) {
      logApiResponse('GET', '/data', 500);
      logError('fetchData', e, stackTrace);
    } finally {
      stopwatch.stop();
    }
  }

  void cacheExample() {
    logCacheOperation('get', 'user_123', hit: true);
    logCacheOperation('set', 'user_456');
  }
}

// ============================================================================
// 8. USING EXTENSION METHODS
// ============================================================================

void extensionMethodsExamples() {
  // Log any object directly
  'User logged in'.logInfo();
  'Debug message'.logDebug();
  'Warning message'.logWarning();

  // Log with context
  'API error'.logError(context: LogContext.api);

  // Short aliases on String
  'Trace'.logT();
  'Debug'.logD();
  'Info'.logI();
  'Warning'.logW();
  'Error'.logE();

  // Log exceptions
  try {
    throw Exception('Test error');
  } catch (e, stackTrace) {
    e.logException(stackTrace, 'Operation failed');
  }

  // Log maps and lists
  final userData = {'user': 'John', 'age': 30};
  userData.logAsData('User data');
  final numbers = [1, 2, 3, 4, 5];
  numbers.logAsList('Numbers');

  // Log duration
  const Duration(milliseconds: 150).logPerformance('API call');
}

// ============================================================================
// 9. INTEGRATION WITH CRASHLYTICS/SENTRY
// ============================================================================

/// Example of initializing logger with Crashlytics integration
void initializeLoggerWithCrashlytics() {
  log.initialize(
    crashlyticsReporter: (error, stackTrace, message) {
      // Firebase Crashlytics integration
      // FirebaseCrashlytics.instance.recordError(error, stackTrace);
      // This is just an example - implement based on your setup
    },
    sentryReporter: (error, stackTrace, message) {
      // Sentry integration
      // Sentry.captureException(error, stackTrace: stackTrace);
      // This is just an example - implement based on your setup
    },
  );
}

// ============================================================================
// 10. LOG ANALYTICS
// ============================================================================

void logAnalyticsExample() {
  // Get statistics
  final stats = LogAnalytics.getStatistics();
  log.info('Log statistics: $stats');

  // Get recent errors
  final errors = LogAnalytics.getRecentErrors(limit: 10);
  for (final error in errors) {
    log.debug('${error.timestamp}: ${error.message}');
  }

  // Get logs by context
  final apiLogs = LogAnalytics.getLogsByContext(LogContext.api);
  log.debug('API logs count: ${apiLogs.length}');

  // Search logs
  final searchResults = LogAnalytics.searchLogs('error');
  log.debug('Found ${searchResults.length} logs matching "error"');

  // Export logs as JSON
  final jsonExport = LogAnalytics.exportAsJson();
  log.debug('Exported logs: ${jsonExport.length} characters');
}
