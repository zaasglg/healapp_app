import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'app_logger.dart';

/// Environment configuration for logging
enum Environment { development, staging, production }

/// Log configuration for different environments
///
/// This class provides environment-specific logging configuration.
/// Use [LogConfig.initialize] at app startup to set the environment.
///
/// Example:
/// ```dart
/// void main() {
///   // Set environment before running app
///   LogConfig.initialize(
///     environment: Environment.development,
///     enableCrashlytics: false,
///   );
///
///   // Initialize logger
///   log.initialize();
///
///   runApp(MyApp());
/// }
/// ```
class LogConfig {
  LogConfig._();

  /// Current environment
  static Environment _environment = Environment.development;

  /// Whether Crashlytics is enabled
  static bool _enableCrashlytics = false;

  /// Whether Sentry is enabled
  static bool _enableSentry = false;

  /// Custom log file path for production logs
  static String? _logFilePath;

  /// Initialize logging configuration
  static void initialize({
    Environment environment = Environment.development,
    bool enableCrashlytics = false,
    bool enableSentry = false,
    String? logFilePath,
  }) {
    _environment = environment;
    _enableCrashlytics = enableCrashlytics && !kDebugMode;
    _enableSentry = enableSentry && !kDebugMode;
    _logFilePath = logFilePath;
  }

  /// Set the environment (convenience method for backward compatibility)
  static void setEnvironment(Environment environment) {
    _environment = environment;
  }

  /// Get current environment
  static Environment get environment => _environment;

  /// Check if Crashlytics is enabled
  static bool get isCrashlyticsEnabled => _enableCrashlytics;

  /// Check if Sentry is enabled
  static bool get isSentryEnabled => _enableSentry;

  /// Get log file path
  static String? get logFilePath => _logFilePath;

  /// Minimum log level for current environment
  static Level get minLevel {
    switch (_environment) {
      case Environment.development:
        return Level.trace;
      case Environment.staging:
        return Level.info;
      case Environment.production:
        return Level.warning;
    }
  }

  /// Allowed log contexts for current environment
  static Set<LogContext> get allowedContexts {
    switch (_environment) {
      case Environment.development:
        return LogContext.values.toSet();
      case Environment.staging:
        return {
          LogContext.auth,
          LogContext.api,
          LogContext.diary,
          LogContext.routeSheet,
          LogContext.bloc,
        };
      case Environment.production:
        return {LogContext.auth, LogContext.api};
    }
  }

  /// Whether to include extra data in logs
  static bool get includeExtra => _environment != Environment.production;

  /// Whether to include performance logs
  static bool get includePerformance => _environment != Environment.production;

  /// Whether to include BLoC logs
  static bool get includeBlocLogs => _environment == Environment.development;

  /// Whether to include navigation logs
  static bool get includeNavigationLogs =>
      _environment == Environment.development;

  /// Check if a context should be logged in current environment
  static bool shouldLogContext(LogContext context) {
    return allowedContexts.contains(context);
  }

  /// Get printer configuration for current environment
  static ({
    int methodCount,
    int errorMethodCount,
    int lineLength,
    bool colors,
    bool emojis,
  })
  get printerConfig {
    switch (_environment) {
      case Environment.development:
        return (
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          emojis: true,
        );
      case Environment.staging:
        return (
          methodCount: 1,
          errorMethodCount: 5,
          lineLength: 100,
          colors: true,
          emojis: false,
        );
      case Environment.production:
        return (
          methodCount: 0,
          errorMethodCount: 3,
          lineLength: 80,
          colors: false,
          emojis: false,
        );
    }
  }
}

/// Constants for logging configuration
class LogConstants {
  LogConstants._();

  /// Application tag for logs
  static const String appTag = 'HealApp';

  /// Maximum number of logs to keep in memory for analytics
  static const int maxLogCount = 1000;

  /// Maximum number of recent errors to track
  static const int maxRecentErrors = 50;

  /// Log file name for production
  static const String logFileName = 'healapp_logs.txt';

  /// Maximum log file size in bytes (5 MB)
  static const int maxLogFileSize = 5 * 1024 * 1024;

  /// Log rotation count (number of backup files)
  static const int logRotationCount = 3;
}
