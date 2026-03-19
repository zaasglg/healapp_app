// Centralized logging system for HealApp
//
// This module provides a professional, production-ready logging system
// based on the `logger` package with the following features:
//
// - Structured logging with PrettyPrinter for development
// - Automatic release mode filtering
// - Convenient methods: trace, debug, info, warning, error, fatal
// - Short aliases: t, d, i, w, e, f
// - Extension methods for logging any object
// - Mixins for BLoC, Repository, and Service logging
// - Firebase Crashlytics / Sentry integration ready
//
// Usage:
// ```dart
// import 'package:healapp_mobile/core/logging/logging.dart';
//
// // Basic usage
// log.info('User logged in');
//
// // With context
// log.debug('API request', context: LogContext.api);
//
// // With error and stackTrace
// log.error('Failed to load data', error: e, stackTrace: stackTrace);
//
// // Short aliases
// log.i('Info message');
// log.e('Error message', error: e);
//
// // Extension methods
// 'Debug message'.logD();
// myObject.logInfo();
// ```

export 'app_logger.dart';
export 'log_config.dart';
export 'log_mixin.dart';
export 'log_analytics.dart';
export 'log_extensions.dart';
export 'examples.dart';
