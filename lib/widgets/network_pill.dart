// network_pill.dart
//
// Kidonge kimoja cha hali ya mtandao kwa app nzima (compact),
// kwenye mtindo ule ule wa toast za app: kidonge cheupe, kona 16,
// kivuli laini, maandishi 13 (w500), ikoni duara ya rangi —
// hizo toast zile za AppToast ndizo msingi wa mtindo.
//
// Hali 3: Mtandao umekatika (njano) — Mtandao unaunganika (bluu) —
//         Mtandao umeunganishwa (kijani, nukta inayopiga).
//
// KANUNI YA APP: tint ya toast (bg la kidonge) inafuata bei shama —
//  • offline:    background #FEF3C7 (njano) — ina busara moja na AppToast.offline
//  • connecting: background #DBEAFE (bluu)
//  • connected:  background #DCFCE7 (kijani)
//
// Matumizi (main.dart/main_user.dart):
//   final net = ConnectivityController()..start();
//   MaterialApp(
//     builder: (context, child) => NetworkPillOverlay(
//       controller: net,
//       appShell: AppShell.kAdminOrUser,
//       child: child ?? const SizedBox.shrink(),
//     ),
//   );
//
// Kama mtumiaji anatuma toast ya "Kitu kimeharibika" au "Umeunganishwa",
// mtindo wa AppToast huu pia unaleta muundo wa kisasa wa kidonge.

import 'dart:async';
import 'dart:io' show InternetAddress;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/* ───────────────────────── Controller ───────────────────────── */

enum NetStatus { online, offline, connecting, connected }

// Controller wa singleton — main.dart na main_user.dart wote wanaangalia hali
// ile ile. Inaanza kupima intaneti mara inaitwa kwa MARA YA KWANZA pekee
// (`..start()` hapa kwa hot reload/awaiter instantiation lazily). Tests
// haziiitati ndani ya hii (zinajenga MaterialApp zao bila netPill).
ConnectivityController? _netPillCtl;
ConnectivityController get netPill =>
    _netPillCtl ??= ConnectivityController()..start();

class ConnectivityController extends ChangeNotifier {
  ConnectivityController({
    this.probeHost = 'google.com',
    this.probeInterval = const Duration(seconds: 6),
  });

  /// Host inayotumika kuthibitisha kuwa intaneti inafikika kweli
  /// (Wi-Fi inaweza kuwepo bila intaneti).
  final String probeHost;
  final Duration probeInterval;

  NetStatus _status = NetStatus.online;
  NetStatus get status => _status;

  /// Mara ya mwisho intaneti ilipothibitishwa kufanya kazi
  /// (unaweza kuitumia kwa "Data ya mwisho: HH:mm" ndani ya kurasa).
  DateTime? lastOnlineAt;

  bool get isOffline =>
      _status == NetStatus.offline || _status == NetStatus.connecting;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _poll;
  Timer? _hideTimer;
  bool _busy = false;
  bool _recovering = false;
  bool _disposed = false;
  int _epoch = 0;

  Future<void> start() async {
    _sub = Connectivity().onConnectivityChanged.listen((_) => _check());
    _poll = Timer.periodic(probeInterval, (_) => _check());
    await _check();
  }

  /// Mtumiaji akibonyeza kidonge cha "umekatika".
  Future<void> retry() async {
    if (_status != NetStatus.offline || _recovering) return;
    _set(NetStatus.connecting);
    final ok = await _hasInternet();
    if (_disposed) return;
    if (ok) {
      await _onReachable(fromRetry: true);
    } else {
      await Future.delayed(const Duration(milliseconds: 700));
      if (_disposed) return;
      _onUnreachable();
    }
  }

  Timer? _peekTimer;

  Future<void> _check() async {
    if (_busy || _disposed) return;
    _busy = true;
    final ok = await _hasInternet();
    _busy = false;
    if (_disposed) return;
    if (ok) {
      await _onReachable();
    } else {
      _onUnreachable();
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none)) {
        return false;
      }
      if (kIsWeb) return true;
      final lookup = await InternetAddress.lookup(probeHost)
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _disposeTimers() {
    _peekTimer?.cancel();
    _peekTimer = null;
  }

  void _onUnreachable() {
    _epoch++; // ghairi urejeshaji wowote unaoendelea
    _recovering = false;
    _hideTimer?.cancel();
    if (_status != NetStatus.offline) _set(NetStatus.offline);
  }

  Future<void> _onReachable({bool fromRetry = false}) async {
    lastOnlineAt = DateTime.now();
    if (_recovering) return;
    if (_status != NetStatus.offline && !fromRetry) return;

    _recovering = true;
    final token = ++_epoch;
    _set(NetStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (_disposed || token != _epoch) {
      _recovering = false;
      return;
    }
    _set(NetStatus.connected);
    _recovering = false;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (!_disposed && _status == NetStatus.connected) {
        _set(NetStatus.online);
      }
    });
  }

  void _set(NetStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _poll?.cancel();
    _hideTimer?.cancel();
    _disposeTimers();
    super.dispose();
  }
}

/* ───────────────────────── Overlay ───────────────────────── */

/// Weka mara moja kwenye `MaterialApp.builder`. Inaelea juu ya kurasa zote.
class NetworkPillOverlay extends StatelessWidget {
  const NetworkPillOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.appBarHeight = 72,
  });

  final ConnectivityController controller;
  final Widget child;

  /// Urefu wa upau wa juu (hamburger/mwezi/avatar), ili kidonge kikae chini yake.
  final double appBarHeight;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + appBarHeight;
    return Stack(
      children: [
        child,
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final status = controller.status;
            return Stack(
              children: [
                // Mstari mwembamba wa bluu wakati wa "unaunganika"
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  height: 2,
                  child: status == NetStatus.connecting
                      ? const _ConnectingBar()
                      : const SizedBox.shrink(),
                ),
                // Kidonge
                Positioned(
                  top: top + 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: NetworkPill(
                      status: status,
                      onTap: status == NetStatus.offline ? controller.retry : null,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/* ───────────────────────── Pill ───────────────────────── */

class NetworkPillSpec {
  const NetworkPillSpec(this.label, this.bg, this.fg, this.accent);
  final String label;
  final Color bg;
  final Color fg;
  final Color accent;
}

class NetworkPill extends StatefulWidget {
  const NetworkPill({super.key, required this.status, this.onTap});

  final NetStatus status;
  final VoidCallback? onTap;

  @override
  State<NetworkPill> createState() => _NetworkPillState();
}

class _NetworkPillState extends State<NetworkPill> {
  // Inakumbuka hali ya mwisho ili kidonge kiendelee kuonyesha maudhui yake
  // wakati kinafifia na kupotea.
  NetStatus _last = NetStatus.offline;

  NetworkPillSpec _spec(NetStatus s, bool dark) {
    switch (s) {
      case NetStatus.connecting:
        return NetworkPillSpec(
          'Mtandao unaunganika',
          dark ? const Color(0xFF14264F) : const Color(0xFFE3ECFD),
          dark ? const Color(0xFF9DBBFF) : const Color(0xFF1A3FB5),
          const Color(0xFF1A56DB),
        );
      case NetStatus.connected:
        return NetworkPillSpec(
          'Mtandao umeunganishwa',
          dark ? const Color(0xFF0F3320) : const Color(0xFFDDF7E6),
          dark ? const Color(0xFF86E5A9) : const Color(0xFF146C35),
          const Color(0xFF16A34A),
        );
      case NetStatus.offline:
      case NetStatus.online:
        return NetworkPillSpec(
          'Mtandao umekatika',
          dark ? const Color(0xFF3A2C0E) : const Color(0xFFFFF4D6),
          dark ? const Color(0xFFFFD58A) : const Color(0xFF8A4B0B),
          const Color(0xFFF59E0B),
        );
    }
  }

  Widget _icon(NetStatus s) {
    switch (s) {
      case NetStatus.connecting:
        return SizedBox(
          key: const ValueKey('connecting'),
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case NetStatus.connected:
        return const _PulseDot();
      case NetStatus.offline:
      case NetStatus.online:
        return const Icon(Icons.cloud_off_rounded, size: 12, color: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.status != NetStatus.online;
    if (visible) _last = widget.status;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final spec = _spec(_last, dark);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, -0.8),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: visible ? 1 : 0,
          child: Material(
            type: MaterialType.transparency,
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 28,
                padding: const EdgeInsets.fromLTRB(4, 0, 11, 0),
                decoration: BoxDecoration(
                  color: spec.bg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F141E46),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: spec.accent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey(_last),
                          child: _icon(_last),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: spec.fg,
                        height: 1,
                        decoration: TextDecoration.none,
                      ),
                      child: Text(
                        spec.label,
                        maxLines: 1,
                        textWidthBasis: TextWidthBasis.parent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Nukta inayopiga ───────────────────────── */

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white
                    .withValues(alpha: 0.75 * (1 - t)),
                spreadRadius: 6 * t,
                blurRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ───────────────────────── Mstari wa "unaunganika" ───────────────────────── */

class _ConnectingBar extends StatefulWidget {
  const _ConnectingBar();

  @override
  State<_ConnectingBar> createState() => _ConnectingBarState();
}

class _ConnectingBarState extends State<_ConnectingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: Curves.easeInOut.transform(_c.value),
          child: const SizedBox(
            height: 2,
            child: ColoredBox(color: Color(0xFF1A56DB)),
          ),
        ),
      ),
    );
  }
}
