/// CachedRepository — huduma MOYA ya offline-first kwa kurusa zote.
///
/// KANUNI:
///  • Data iliyohifadhiwa kwenye diski (SharedPreferences kupitia AppCache)
///    inasomwa PAPO HAPO ukurasa unapoanza — hata app ikiwa imefungwa
///    na kufunguliwa bila mtandao.
///  • API inaitwa NYUMA YA PAZIA (background). Ikifaulu: andika kwenye
///    diski + arifu (notifyListeners) → ukurasa unajisasisha.
///  • Ikishindwa (offline): HAKIBADILISHI chochote kwenye skrini —
///    data ya zamani inabaki kama ilivyo.
///  • updatedAt kwa kila funguo — inatumika kwenye bango la juu
///    ("data ya HH:mm") na kupatikana kupitia [updatedAt] / [latestUpdatedAt].
///
/// Kurusa zote (Takwimu, Watumiaji, Wenzao, Malipo, Maoni, Data, Matangazo,
/// Waliopigiana) zinatumia CachedRepository hii hii.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_cache.dart';

/// Imetupwa na [CachedRepository.read] kama hakuna data iliyohifadhiwa
/// kabisa kwenye diski kwa funguo hiyo. Ukurasa unapaswa kuonyesha
/// NoCachedDataWidget ("Data haijapakuliwa bado").
class NoCachedData implements Exception {
  final String key;
  NoCachedData(this.key);
  @override
  String toString() => 'NoCachedData($key)';
}

class CachedRepository extends ChangeNotifier {
  static final CachedRepository _i = CachedRepository._();
  factory CachedRepository() => _i;
  CachedRepository._();

  /// Prefix ya funguo za muda (timestamps) kwenye SharedPreferences.
  static const String _kAtPfx = 'repo_at_';

  /// TTL ndefu — hifadhi ya kudumu ya diski. Background refresh ndiyo
  /// inayosasisha data; TTL haifuti data kwenye diski kamwe.
  static const Duration _diskTtl = Duration(days: 365 * 10);

  final Map<String, DateTime> _updatedAt = {};
  final Map<String, Future<dynamic>> _inflight = {};

  int _revision = 0;
  int get revision => _revision;

  // ── Muda wa data (updatedAt) ──────────────────────────────────────────────

  DateTime? updatedAt(String key) {
    final own = _updatedAt[key];
    if (own != null) return own;
    // Fallback: data iliyoandikwa tangu kwanza (AppCache) — bango siwi "--:--"
    // kama kuna data iliyohifadhiwa, hata ila ya MUDA-TIME haipo.
    return AppCache().getSetAt(key);
  }

  /// Muda wa mwisho wa kusasisha (wa karibu zaidi) kati ya funguo zote —
  /// bango la juu linaonyesha hii kama "data ya HH:mm".
  DateTime? get latestUpdatedAt {
    final keys = <String>{..._updatedAt.keys, ...AppCache().keys};
    DateTime? max;
    for (final k in keys) {
      final t = updatedAt(k);
      if (t != null && (max == null || t.isAfter(max))) max = t;
    }
    return max;
  }

  /// Kama kuna data yoyote iliyohifadhiwa kwenye diski.
  bool get hasAnyData => AppCache().hasAny || _updatedAt.isNotEmpty;

  // ── KUANDIKA (kwa screens zinazo-paginate wenyewe) ─────────────────────────────

  /// Funguo ya cache ya ukurasa maalum wa orodha: "<base>@p<n>" + fingerprint
  /// ya vichujio (search/kategoria n.k.). Kurusa zinazo-paginate (users v2
  /// n.k.) zinatumia hii — kila ukurasa uliowahi kutembelewa unahifadhiwa
  /// kwenye diski, hivyo Next/Ifuatayo inafunguka KUTOKA DISKI hata offline.
  static String pagedKey(String base, int page, {String? filterHint}) {
    final f = (filterHint ?? '').trim();
    return f.isEmpty ? '$base@p$page' : '$base@p$page@${Uri.encodeComponent(f)}';
  }

  /// Andika data kwenye diski PAPO HAPO (bila kupiga API) na arifa
  /// (notifyListeners) — screens zote zinazotumia funguo hii zitasasishwa
  /// (revision). Inaitwa na kurusa zinazo-paginate wenyewe:
  /// SCREEN >>> CACHE >>> BASI (API inaitwa tu kupakua data; kila kitu
  /// kinachoonyeshwa kwenye skrini kimetoka kwenye cache).
  void write(String key, dynamic data) {
    if (data == null) return;
    AppCache().set(key, data, ttl: _diskTtl);
    final now = DateTime.now();
    _updatedAt[key] = now;
    _persistUpdatedAt(key, now);
    _revision++;
    notifyListeners();
  }

  // ── KUSOMA (diski pekee — haipigi API) ───────────────────────────────────

  /// Soma data iliyohifadhiwa kwenye diski — PAPO HAPO (synchronous).
  /// Inatupa [NoCachedData] kama HAKUNA data kabisa.
  T read<T>(String key) {
    final raw = AppCache().getStale(key);
    if (raw == null) throw NoCachedData(key);
    return raw as T;
  }

  /// Mbadala rahisi: null kama hakuna data (bila exception).
  T? readOrNull<T>(String key) {
    final raw = AppCache().getStale(key);
    if (raw == null) return null;
    return raw as T;
  }

  // ── REFRESH (nyuma ya pazia) ─────────────────────────────────────────────

  /// Piga API na, ikifaulu, uandike kwenye diski + arifu (notifyListeners).
  /// Ikishindwa: hakibadilishi chochote kwenye diski wala skrini.
  Future<void> refresh(String key, Future<dynamic> Function() fetch) async {
    // Request Moja kwa funguo — pull-to-refresh, WS, badge... zote
    // zinashirikisha ombi moja (isiweke kazi mbili kwenye mtandao).
    var f = _inflight[key];
    if (f == null) {
      f = () async {
        try {
          final data = await fetch();
          if (data == null) return null;
          AppCache().set(key, data, ttl: _diskTtl);
          final now = DateTime.now();
          _updatedAt[key] = now;
          _persistUpdatedAt(key, now);
          _revision++;
          notifyListeners();
          return data;
        } finally {
          _inflight.remove(key);
        }
      }();
      _inflight[key] = f;
    }
    try {
      await f;
    } catch (_) {
      // Kosa la API — hakibadilishi diski wala skrini (kanuni ya offline).
    }
  }

  /// Futa timestamp iliyohifadhiwa — inaitwa na AppCache.clear() (logout)
  /// kupitia [clearAll].
  void clearAll() {
    _updatedAt.clear();
    _revision++;
    notifyListeners();
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final keys =
            prefs.getKeys().where((k) => k.startsWith(_kAtPfx)).toList();
        for (final k in keys) {
          await prefs.remove(k);
        }
      } catch (_) {}
    }();
  }

  /// invalidatePrefix ya funguo — inaitwa na cleanup ya AppCache (logout).
  void invalidateKey(String key) {
    if (_updatedAt.remove(key) == null) return;
    _revision++;
    notifyListeners();
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_kAtPfx$key');
      } catch (_) {}
    }();
  }

  /// Msaada kwa kurusa: soma diski PAPO HAPO (synchronous) na GAZA data
  /// kwenye ukurasa mara moja. Itwa kwenye initState() ya ukurasa — kabla
  /// ya frame ya kwanza. Data ya diski inaonekana MARA MOJA, hakuna spinner
  /// hata milisekunde moja, hata mtandao ukiwa mbaya.
  ///
  /// Kama hakuna data diski: hautagawa (ukurasa unaonyesha NoCachedDataWidget
  /// na pull-to-refresh pekee).
  void hydrate(String key, void Function(dynamic data) apply) {
    final cached = readOrNull<dynamic>(key);
    if (cached == null) return;
    apply(cached);
  }

  /// Pakia ukurasa: 1) diski mara moja (synchronous — frame ya kwanza),
  /// 2) refresh NYUMA YA PAZIA (data mpya inagusa diski na ukurasa
  /// unajisasisha kimya — hakuna spinner inayoonekana kamwe).
  ///
  /// [apply] lazima iwe SYNC (void) — inaitwa hata kabla ya frame ya kwanza.
  Future<void> loadPage(
    String key,
    Future<dynamic> Function() fetch,
    void Function(dynamic data) apply,
  ) async {
    // 1) Diski — PAPO HAPO, kabla ya frame (data AMA NULL — ukurasa unaamua).
    final cached = readOrNull<dynamic>(key);
    apply(cached);
    // 2) Refresh nyuma ya pazia — ikifaulu apply() tena na data mpya.
    unawaited(() async {
      final rev0 = revision;
      await refresh(key, fetch);
      if (revision != rev0) {
        final fresh = readOrNull<dynamic>(key);
        if (fresh != null && fresh != cached) apply(fresh);
      }
    }());
  }

  // ── Boot ─────────────────────────────────────────────────────────────────

  /// Ita mara moja kwenye main(), KABLA ya skrini ya kwanza.
  /// Inasoma timestamps kutoka diski — data halisi inasomwa na
  /// AppCache().getStale() (synchronous) ukurasa unapoanza.
  Future<void> warmUp() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().toList()) {
      if (!k.startsWith(_kAtPfx)) continue;
      try {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        final t = DateTime.tryParse(raw);
        if (t == null) {
          prefs.remove(k);
          continue;
        }
        final key = k.substring(_kAtPfx.length);
        if (AppCache().getStale(key) == null) {
          // Data imefutwa (TTL ya AppCache ilishaisha au imefutwa)
          // — timestamp pia haifaa tena.
          prefs.remove(k);
          continue;
        }
        _updatedAt[key] = t;
      } catch (_) {}
    }
  }

  void _persistUpdatedAt(String key, DateTime t) {
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_kAtPfx$key', t.toIso8601String());
      } catch (_) {}
    }();
  }
}
