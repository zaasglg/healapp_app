import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Утилиты для оптимизации производительности

/// Кэш для форматирования дат
class DateFormatterCache {
  static final Map<String, DateFormat> _formatters = {};
  static final DateFormat _defaultFormatter = DateFormat('dd.MM.yyyy');
  static final DateFormat _timeFormatter = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormatter = DateFormat('dd.MM.yyyy, HH:mm');

  /// Получить форматтер даты
  static DateFormat getFormatter(String pattern) {
    if (!_formatters.containsKey(pattern)) {
      _formatters[pattern] = DateFormat(pattern);
    }
    return _formatters[pattern]!;
  }

  /// Форматировать дату (кэшированный)
  static String formatDate(DateTime date, {String? pattern}) {
    if (pattern != null) {
      return getFormatter(pattern).format(date);
    }
    return _defaultFormatter.format(date);
  }

  /// Форматировать время
  static String formatTime(DateTime date) {
    return _timeFormatter.format(date);
  }

  /// Форматировать дату и время
  static String formatDateTime(DateTime date) {
    return _dateTimeFormatter.format(date);
  }

  /// Относительное время (сегодня, вчера, X дн. назад)
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Сегодня';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн. назад';
    } else {
      return formatDate(date);
    }
  }
}

/// Оптимизированный ListView.builder с настройками производительности
class OptimizedListView extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final double? itemExtent;
  final double cacheExtent;
  final bool shrinkWrap;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;

  const OptimizedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.physics,
    this.controller,
    this.itemExtent,
    this.cacheExtent = 250.0, // Кэшируем 250px вне видимой области
    this.shrinkWrap = false,
    this.addAutomaticKeepAlives =
        false, // Отключаем для списков без сохранения состояния
    this.addRepaintBoundaries = true, // Включаем границы перерисовки
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      padding: padding,
      physics: physics,
      controller: controller,
      itemExtent: itemExtent,
      cacheExtent: cacheExtent,
      shrinkWrap: shrinkWrap,
      addAutomaticKeepAlives: addAutomaticKeepAlives,
      addRepaintBoundaries: addRepaintBoundaries,
    );
  }
}

/// Мемоизация для дорогих вычислений
class Memoized<T> {
  T? _cachedValue;
  dynamic _cacheKey;

  /// Получить значение с мемоизацией
  T getValue(T Function() compute, [dynamic cacheKey]) {
    if (_cacheKey != cacheKey || _cachedValue == null) {
      _cachedValue = compute();
      _cacheKey = cacheKey;
    }
    return _cachedValue!;
  }

  /// Очистить кэш
  void clear() {
    _cachedValue = null;
    _cacheKey = null;
  }
}

/// Дебаунсер для поиска и других действий
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void call(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(delay, callback);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Оптимизированный виджет с RepaintBoundary
class OptimizedWidget extends StatelessWidget {
  final Widget child;
  final bool isComplex;

  const OptimizedWidget({
    super.key,
    required this.child,
    this.isComplex = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isComplex) {
      return RepaintBoundary(child: child);
    }
    return child;
  }
}

/// Утилита для форматирования телефона (мемоизированная)
class PhoneFormatter {
  static final Map<String, String> _cache = {};

  static String format(String phone) {
    if (_cache.containsKey(phone)) {
      return _cache[phone]!;
    }

    String formatted;
    if (phone.length >= 11) {
      formatted =
          '+${phone[0]} (${phone.substring(1, 4)}) ${phone.substring(4, 7)}-${phone.substring(7, 9)}-${phone.substring(9)}';
    } else {
      formatted = phone;
    }

    _cache[phone] = formatted;
    return formatted;
  }

  static void clearCache() {
    _cache.clear();
  }
}
