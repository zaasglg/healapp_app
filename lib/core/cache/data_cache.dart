/// Простой кэш данных в памяти
class DataCache<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final Duration defaultTtl;

  DataCache({this.defaultTtl = const Duration(minutes: 5)});

  /// Получить значение из кэша
  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.value;
  }

  /// Сохранить значение в кэш
  void put(String key, T value, {Duration? ttl}) {
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Проверить наличие ключа
  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// Удалить значение из кэша
  void remove(String key) {
    _cache.remove(key);
  }

  /// Очистить весь кэш
  void clear() {
    _cache.clear();
  }

  /// Очистить истекшие записи
  void clearExpired() {
    _cache.removeWhere((key, entry) => entry.isExpired);
  }

  /// Получить размер кэша
  int get size => _cache.length;
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Глобальные экземпляры кэша для разных типов данных
class AppCache {
  static final DataCache<List<dynamic>> patients = DataCache<List<dynamic>>(
    defaultTtl: const Duration(minutes: 10),
  );

  static final DataCache<List<dynamic>> diaries = DataCache<List<dynamic>>(
    defaultTtl: const Duration(minutes: 5),
  );

  static final DataCache<List<dynamic>> employees = DataCache<List<dynamic>>(
    defaultTtl: const Duration(minutes: 10),
  );

  static final DataCache<Map<String, dynamic>> diaryDetails =
      DataCache<Map<String, dynamic>>(defaultTtl: const Duration(minutes: 3));

  /// Очистить все кэши
  static void clearAll() {
    patients.clear();
    diaries.clear();
    employees.clear();
    diaryDetails.clear();
  }

  /// Очистить истекшие записи во всех кэшах
  static void clearExpired() {
    patients.clearExpired();
    diaries.clearExpired();
    employees.clearExpired();
    diaryDetails.clearExpired();
  }
}
