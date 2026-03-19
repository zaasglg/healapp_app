import 'dart:collection';
import 'package:logger/logger.dart';
import 'app_logger.dart';

/// Log entry for analytics tracking
class LogEntry {
  final DateTime timestamp;
  final Level level;
  final LogContext context;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? extra;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.context,
    required this.message,
    this.error,
    this.stackTrace,
    this.extra,
  });

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'context': context.name,
      'message': message,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      if (extra != null) 'extra': extra,
    };
  }

  /// Create from JSON
  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: Level.values.firstWhere((l) => l.name == json['level']),
      context: LogContext.values.firstWhere((c) => c.name == json['context']),
      message: json['message'] as String,
      error: json['error'],
      stackTrace: json['stackTrace'] != null
          ? StackTrace.fromString(json['stackTrace'] as String)
          : null,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }
}

/// Log analytics for monitoring performance and errors
///
/// This class provides in-memory log analytics for tracking
/// application behavior during runtime. Useful for debugging
/// and performance monitoring.
///
/// Usage:
/// ```dart
/// // Get statistics
/// final stats = LogAnalytics.getStatistics();
/// print('Total logs: ${stats['total_logs']}');
///
/// // Get recent errors
/// final errors = LogAnalytics.getRecentErrors(limit: 10);
/// for (final error in errors) {
///   print('${error.timestamp}: ${error.message}');
/// }
///
/// // Clear analytics
/// LogAnalytics.clear();
/// ```
class LogAnalytics {
  LogAnalytics._();

  static final Queue<LogEntry> _recentLogs = Queue<LogEntry>();
  static const int _maxLogCount = 1000;

  static final Map<LogContext, int> _contextCounts = {};
  static final Map<Level, int> _levelCounts = {};
  static final Map<String, int> _errorCounts = {};

  /// Add a log entry to analytics
  static void addLog(LogEntry entry) {
    // Add to recent logs queue
    _recentLogs.add(entry);
    if (_recentLogs.length > _maxLogCount) {
      _recentLogs.removeFirst();
    }

    // Update statistics
    _contextCounts[entry.context] = (_contextCounts[entry.context] ?? 0) + 1;
    _levelCounts[entry.level] = (_levelCounts[entry.level] ?? 0) + 1;

    // Track errors
    if (entry.level == Level.error || entry.level == Level.fatal) {
      final messageLength = entry.message.length > 50
          ? 50
          : entry.message.length;
      final errorKey =
          '${entry.context.name}:${entry.message.substring(0, messageLength)}';
      _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    }
  }

  /// Get log statistics
  static Map<String, dynamic> getStatistics() {
    return {
      'total_logs': _recentLogs.length,
      'by_context': Map<LogContext, int>.from(_contextCounts),
      'by_level': Map<Level, int>.from(_levelCounts),
      'top_errors': _errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    };
  }

  /// Get recent errors
  static List<LogEntry> getRecentErrors({int limit = 50}) {
    return _recentLogs
        .where((log) => log.level == Level.error || log.level == Level.fatal)
        .toList()
        .reversed
        .take(limit)
        .toList();
  }

  /// Get logs by context
  static List<LogEntry> getLogsByContext(
    LogContext context, {
    int limit = 100,
  }) {
    return _recentLogs
        .where((log) => log.context == context)
        .toList()
        .reversed
        .take(limit)
        .toList();
  }

  /// Get logs by level
  static List<LogEntry> getLogsByLevel(Level level, {int limit = 100}) {
    return _recentLogs
        .where((log) => log.level == level)
        .toList()
        .reversed
        .take(limit)
        .toList();
  }

  /// Get all recent logs
  static List<LogEntry> getRecentLogs({int limit = 100}) {
    return _recentLogs.toList().reversed.take(limit).toList();
  }

  /// Search logs by message content
  static List<LogEntry> searchLogs(String query, {int limit = 50}) {
    final lowerQuery = query.toLowerCase();
    return _recentLogs
        .where((log) => log.message.toLowerCase().contains(lowerQuery))
        .toList()
        .reversed
        .take(limit)
        .toList();
  }

  /// Get error count for a specific time period
  static int getErrorCountSince(DateTime since) {
    return _recentLogs
        .where(
          (log) =>
              (log.level == Level.error || log.level == Level.fatal) &&
              log.timestamp.isAfter(since),
        )
        .length;
  }

  /// Clear all analytics data
  static void clear() {
    _recentLogs.clear();
    _contextCounts.clear();
    _levelCounts.clear();
    _errorCounts.clear();
  }

  /// Export logs as JSON string
  static String exportAsJson() {
    final logs = _recentLogs.map((e) => e.toJson()).toList();
    return '{"logs": $logs, "statistics": ${getStatistics()}}';
  }
}

/// Custom log output that forwards logs to analytics
///
/// Use this with the Logger to automatically track logs in analytics.
///
/// ```dart
/// final logger = Logger(
///   output: AnalyticsOutput(),
/// );
/// ```
class AnalyticsOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Parse the log message to extract context
    // This is a simplified implementation
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: event.level,
      context: LogContext.ui, // Default context
      message: event.lines.join('\n'),
    );
    LogAnalytics.addLog(entry);
  }
}
