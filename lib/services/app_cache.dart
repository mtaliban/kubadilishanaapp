/// In-memory TTL cache — works like Redis on web but lives in process memory.
/// Survives navigations (singleton), clears on app restart.
library;

class _Entry {
  final dynamic data;
  final DateTime expiresAt;
  _Entry(this.data, Duration ttl) : expiresAt = DateTime.now().add(ttl);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class AppCache {
  static final AppCache _i = AppCache._();
  factory AppCache() => _i;
  AppCache._();

  final Map<String, _Entry> _store = {};

  void set(String key, dynamic data, {Duration ttl = const Duration(minutes: 5)}) {
    _store[key] = _Entry(data, ttl);
  }

  /// Returns cached data or null if missing / expired.
  dynamic get(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (e.isExpired) {
      _store.remove(key);
      return null;
    }
    return e.data;
  }

  void invalidate(String key) => _store.remove(key);

  void invalidatePrefix(String prefix) =>
      _store.removeWhere((k, _) => k.startsWith(prefix));

  void clear() => _store.clear();
}
