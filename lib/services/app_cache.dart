/// In-memory TTL cache with SharedPreferences backing.
///
/// Survives app restarts — warmUp() loads persisted entries into memory at
/// startup so the first page view shows stale data instantly while fresh data
/// is fetched in the background.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Entry {
  final dynamic data;
  final DateTime expiresAt;

  _Entry(this.data, Duration ttl) : expiresAt = DateTime.now().add(ttl);
  _Entry._raw(this.data, this.expiresAt);

  factory _Entry.fromJson(Map<String, dynamic> j) =>
      _Entry._raw(j['d'], DateTime.parse(j['exp'] as String));

  Map<String, dynamic> toJson() => {'d': data, 'exp': expiresAt.toIso8601String()};

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class AppCache extends ChangeNotifier {
  static final AppCache _i = AppCache._();
  factory AppCache() => _i;
  AppCache._();

  final Map<String, _Entry> _store = {};
  SharedPreferences? _prefs;
  static const _kPfx = 'kv_c_';

  int get revision => _revision;
  int _revision = 0;

  /// Call once at app start — loads persisted (non-expired) entries into memory.
  Future<void> warmUp() async {
    _prefs ??= await SharedPreferences.getInstance();
    for (final k in _prefs!.getKeys().toList()) {
      if (!k.startsWith(_kPfx)) continue;
      try {
        final raw = _prefs!.getString(k);
        if (raw == null) continue;
        final entry = _Entry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (!entry.isExpired) {
          _store[k.substring(_kPfx.length)] = entry;
        } else {
          _prefs!.remove(k);
        }
      } catch (_) {
        _prefs!.remove(k);
      }
    }
  }

  void set(String key, dynamic data, {Duration ttl = const Duration(minutes: 5)}) {
    final entry = _Entry(data, ttl);
    _store[key] = entry;
    _persist(key, entry);
  }

  void _persist(String key, _Entry entry) {
    () async {
      try {
        _prefs ??= await SharedPreferences.getInstance();
        await _prefs!.setString('$_kPfx$key', jsonEncode(entry.toJson()));
      } catch (_) {}
    }();
  }

  dynamic get(String key) {
    final e = _store[key];
    if (e == null) return null;
    if (e.isExpired) {
      // USIFUTE hapa — kipengele kimebaki kwa getStale() (sera ya offline:
      // "Cached + banner"). Inaondolewa na set() mpya, invalidate() au clear().
      return null;
    }
    return e.data;
  }

  /// Soma hata kipenye kilichoisha muda (stale) — SERA YA OFFLINE:
  /// "Cached + banner". Kwenye mtandao mbaya, GET inarudisha data hii
  /// badala ya kosa; mtumiaji anaona data za mwisho + banner juu.
  dynamic getStale(String key) => _store[key]?.data;

  void invalidate(String key) {
    final had = _store.remove(key) != null;
    _prefs?.remove('$_kPfx$key');
    if (had) { _revision++; notifyListeners(); }
  }

  void invalidatePrefix(String prefix) {
    final before = _store.length;
    _store.removeWhere((k, _) => k.startsWith(prefix));
    _prefs?.getKeys()
        .where((k) => k.startsWith('$_kPfx$prefix'))
        .toList()
        .forEach((k) => _prefs!.remove(k));
    if (_store.length != before) { _revision++; notifyListeners(); }
  }

  void clear() {
    if (_store.isEmpty) return;
    _store.clear();
    _prefs?.getKeys()
        .where((k) => k.startsWith(_kPfx))
        .toList()
        .forEach((k) => _prefs!.remove(k));
    _revision++;
    notifyListeners();
  }
}
