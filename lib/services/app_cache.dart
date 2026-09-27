/// In-memory TTL cache — works like Redis on web but lives in process memory.
/// Survives navigations (singleton), clears on app restart.
library;

import 'package:flutter/foundation.dart';

class _Entry {
  final dynamic data;
  final DateTime expiresAt;
  _Entry(this.data, Duration ttl) : expiresAt = DateTime.now().add(ttl);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class AppCache extends ChangeNotifier {
  static final AppCache _i = AppCache._();
  factory AppCache() => _i;
  AppCache._();

  final Map<String, _Entry> _store = {};

  /// Idadi ya "toleo" la reference data — inaongezeka kila invalidation.
  /// Screens (register/profile/settings) zinaweza kusikiliza hii na kupakia
  /// dropdowns upya PAPO HAPO data ya admin ikiwa mpya (bila reload ya page).
  int get revision => _revision;
  int _revision = 0;

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

  void invalidate(String key) {
    final had = _store.remove(key) != null;
    if (had) {
      _revision++;
      notifyListeners();
    }
  }

  void invalidatePrefix(String prefix) {
    final before = _store.length;
    _store.removeWhere((k, _) => k.startsWith(prefix));
    if (_store.length != before) {
      _revision++;
      notifyListeners();
    }
  }

  void clear() {
    if (_store.isEmpty) return;
    _store.clear();
    _revision++;
    notifyListeners();
  }
}
