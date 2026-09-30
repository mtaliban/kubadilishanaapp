/// Huduma ya mtandao — inagundua hali ya muunganiko na kuarifu app nzima.
///
/// Hatua:
///  1. Sikiliza connectivity_plus kwa mabadiliko ya haraka (WiFi/data imewashwa).
///  2. Thibitisha kwa GET /health kwenye server ili kuhakikisha intaneti halisi
///     (simu inaweza kuwa na data bila kufika intaneti — WiFi ya hoteli n.k.).
///  3. Kama ombi limeshindwa: subiri kwa muda unaodoble (2 → 4 → 8 … → 60s).
///  4. Mtandao ukirejesha: piga simu zote zilizosajiliwa za onOnline.
library;

import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api.dart';
import 'admin_badge_service.dart';

enum NetStatus { unknown, checking, online, offline }

class NetworkService extends ChangeNotifier {
  static final NetworkService _i = NetworkService._();
  factory NetworkService() => _i;
  NetworkService._();

  NetStatus _status = NetStatus.unknown;
  DateTime?  _lastOnline;
  Timer?     _retryTimer;
  int        _retryDelay = 2; // seconds — doubles kila kushindwa, max 60
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool       _checking = false;

  final List<VoidCallback> _onlineCallbacks = [];

  NetStatus get status    => _status;
  DateTime? get lastOnline => _lastOnline;
  bool get isOnline  => _status == NetStatus.online;
  bool get isOffline => _status == NetStatus.offline;

  // ── Maisha ────────────────────────────────────────────────────────────────

  void start() {
    _sub?.cancel();
    _sub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
    _check();
  }

  void stop() {
    _sub?.cancel();
    _retryTimer?.cancel();
    _sub = null;
  }

  // ── Callback za "mtandao umerudi" ────────────────────────────────────────

  void addOnlineListener(VoidCallback cb)    => _onlineCallbacks.add(cb);
  void removeOnlineListener(VoidCallback cb) => _onlineCallbacks.remove(cb);

  // ── Jaribu tena mara moja (kitufe cha "Jaribu") ──────────────────────────

  Future<void> retry() async {
    _retryDelay = 2;
    _retryTimer?.cancel();
    await _check();
  }

  // ── Ndani ─────────────────────────────────────────────────────────────────

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_isNone(results)) {
      _retryTimer?.cancel();
      _setStatus(NetStatus.offline);
    } else {
      _check();
    }
  }

  static bool _isNone(List<ConnectivityResult> r) =>
      r.isEmpty || r.every((x) => x == ConnectivityResult.none);

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    _setStatus(NetStatus.checking);

    // Ukaguzi wa haraka wa connectivity kwanza
    final conn = await Connectivity().checkConnectivity();
    if (_isNone(conn)) {
      _checking = false;
      _setStatus(NetStatus.offline);
      _scheduleRetry();
      return;
    }

    // Thibitisha kwa ping halisi kwa server
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ));
      await dio.get('${ApiConfig.baseUrl}/health');

      final wasOffline = _status != NetStatus.online;
      _lastOnline = DateTime.now();
      _retryDelay = 2;
      _retryTimer?.cancel();
      _checking = false;
      _setStatus(NetStatus.online);

      if (wasOffline) _onCameOnline();
    } catch (_) {
      _checking = false;
      _setStatus(NetStatus.offline);
      _scheduleRetry();
    }
  }

  void _onCameOnline() {
    // Sasisha badges za admin bila mtu kubonyeza chochote
    AdminBadgeService().refresh();
    // Arifu waliangaliwa (screens zinaweza ku-reload)
    for (final cb in List.of(_onlineCallbacks)) {
      try { cb(); } catch (_) {}
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retryDelay), () {
      _retryDelay = min(60, _retryDelay * 2);
      _check();
    });
  }

  void _setStatus(NetStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }
}
