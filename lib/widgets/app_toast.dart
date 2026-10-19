// lib/widgets/app_toast.dart
//
// Toast ya app nzima. Muundo umetokana na picha za sample:
//   - kidonge cheupe, kona 16, mpaka mwembamba wa kijivu, kivuli laini
//   - ikoni 18 upande wa kushoto, maandishi 13 (w500), mstari wa muda 2px chini
//   - upana unafuata maneno (haujai skrini)
//   - inakaa katikati, juu ya bottom nav (kwa sababu ToastHost iko ndani ya body)

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../services/network_service.dart';

enum ToastType { success, error, warning, info, offline, online }

class _ToastData {
  final String text;
  final ToastType type;
  final Duration duration;
  _ToastData(this.text, this.type, this.duration);
}

class AppToast {
  AppToast._();

  static final ValueNotifier<_ToastData?> current = ValueNotifier(null);
  static Timer? _timer;

  static void show(
    String text, {
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Ujumbe ULE ULE unaoonekana tayari: usiubadilishe (toast isionekane
    // kama inaruka/rangi isibadilike — mfano wakati wa offline, banner na
    // ombi lililoshindwa zote zinasema "Hakuna mtandao"). Ongeza muda tu.
    final cur = current.value;
    if (cur != null && cur.text == text) {
      _timer?.cancel();
      _timer = Timer(duration, () => current.value = null);
      return;
    }
    _timer?.cancel();
    current.value = _ToastData(text, type, duration);
    _timer = Timer(duration, () => current.value = null);
  }

  // Njia fupi
  static void success(String text) => show(text, type: ToastType.success);
  static void error(String text) => show(text, type: ToastType.error);
  static void warning(String text) => show(text, type: ToastType.warning);
  static void info(String text) => show(text, type: ToastType.info);
  static void offline() => show('Hakuna mtandao',
      type: ToastType.offline, duration: const Duration(seconds: 4));
  static void online() => show('Mtandao umerudi',
      type: ToastType.online, duration: const Duration(seconds: 2));
}

/// Funga body ya Scaffold na hii: body: ToastHost(child: ...)
class ToastHost extends StatelessWidget {
  final Widget child;
  const ToastHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 16, // umbali juu ya bottom nav. Badilisha hapa tu.
          child: IgnorePointer(
            child: ValueListenableBuilder<_ToastData?>(
              valueListenable: AppToast.current,
              builder: (_, d, __) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0, .3), end: Offset.zero)
                            .animate(a),
                    child: c,
                  ),
                ),
                child: d == null
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : Align(
                        key: ValueKey(d),
                        alignment: Alignment.bottomCenter,
                        child: _ToastPill(d),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastPill extends StatelessWidget {
  final _ToastData d;
  const _ToastPill(this.d);

  /// Icons za Tabler (kama zile za drawer/nav) — si Icons za Material.
  /// Kila aina ina icon yake HALISI ya mfumo (mfano watu anajiunga,
  /// malipo, maoni) — ndizo visually fiz and standard za app yote.
  static (IconData, Color, Color) _look(ToastType type) => switch (type) {
        ToastType.success => (
            TablerIcons.circle_check,
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7)
          ),
        ToastType.error => (
            TablerIcons.alert_circle,
            const Color(0xFFDC2626),
            const Color(0xFFFEE2E2)
          ),
        ToastType.warning => (
            TablerIcons.alert_triangle,
            const Color(0xFFB45309),
            const Color(0xFFFDE68A)
          ),
        ToastType.info => (
            TablerIcons.info_circle,
            const Color(0xFF2563EB),
            const Color(0xFFDBEAFE)
          ),
        ToastType.offline => (
            TablerIcons.wifi_off,
            const Color(0xFF92400E),
            const Color(0xFFFDE68A)
          ),
        ToastType.online => (
            TablerIcons.wifi,
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7)
          ),
      };

  @override
  Widget build(BuildContext context) {
    // ── zodat ya dark mode ──
    final dark = Theme.of(context).brightness == Brightness.dark;
    final card = dark ? const Color(0xFF1E293B) : Colors.white;
    final border = dark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final ink = dark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);

    final (icon, color, track) = _look(d.type);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 48,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x40000000) : const Color(0x1F000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // Row(mainAxisSize: min) inafanya upana ufuatane maneno bila
      // IntrinsicWidth — intrinsics na ConstrainedBox ndizo haki hapa.
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 18, 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── ICON DUARA (style za drawer) — duara la rangi (bg soft)
                  //  + icon za Tabler NYEUSI/RANGI, size 22 — toast iko KISASA
                  //  na zenye mfumo moja na drawer/nav zote. ──
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: track,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 22, color: color),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 116,
                    ),
                    child: Text(
                      d.text,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: ink,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: d.duration,
              builder: (_, v, __) => Container(
                height: 2.5,
                color: track,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  child: Container(color: color),
                ),
              ),
            ),
          ],
      ),
    );
  }
}

/// Weka MARA MOJA tu, kwenye shell kuu (juu ya ToastHost au ndani ya body).
/// Inaonyesha "Hakuna mtandao" na "Mtandao umerudi" kwa skrini zote.
///
/// Inatumia NetworkService (ILIYOTHIBITISHWA kwa GET /health) — SI
/// connectivity ghafi. Sababu: WiFi yenye signal bila internet ilikuwa
/// inaonyesha "Mtandao umerudi" ya UONGO, kisha maombi yanashindwa na
/// banner inasema "Hakuna mtandao" — toast za kupingana kila sekunde.
/// Sasa: toast MOJA kwa kila mzunguko halisi wa kukatika/kurejea, na
/// starti ya app (haijawahi online) haina toast — banner inatosha.
class NetworkToastListener extends StatefulWidget {
  final Widget child;
  const NetworkToastListener({super.key, required this.child});

  @override
  State<NetworkToastListener> createState() => _NetworkToastListenerState();
}

class _NetworkToastListenerState extends State<NetworkToastListener> {
  bool _seenOffline = false; // tumeingia offline kwenye mzunguko huu
  bool _everOnline = false;  // tumewahi kuwa online tangu widget ipandishwe

  @override
  void initState() {
    super.initState();
    final s = NetworkService().status;
    _everOnline = s == NetStatus.online;
    _seenOffline = s == NetStatus.offline;
    NetworkService().addListener(_onStatusChange);
  }

  @override
  void dispose() {
    NetworkService().removeListener(_onStatusChange);
    super.dispose();
  }

  void _onStatusChange() {
    final s = NetworkService().status;
    if (s == NetStatus.online) {
      _everOnline = true;
      if (_seenOffline) {
        // Umerudi KWELI (imethibitishwa kwa /health).
        _seenOffline = false;
        AppToast.online();
      }
    } else if (s == NetStatus.offline && !_seenOffline) {
      _seenOffline = true;
      // Mara MOJA kwa mzunguko huu — retry za NetworkService
      // (checking→offline kila mara) zisirudie toast.
      if (_everOnline) AppToast.offline();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Geuza kosa la kiufundi kuwa ujumbe mfupi wa Kiswahili.
/// USIONYESHE kamwe DioException wala stack trace kwa mtumiaji.
String friendlyError(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Mtandao ni polepole. Jaribu tena';
      case DioExceptionType.connectionError:
        return 'Hakuna mtandao';
      case DioExceptionType.badResponse:
        return 'Kuna tatizo kwenye seva. Jaribu baadaye';
      default:
        return 'Kuna kitu hakijaenda sawa';
    }
  }
  return 'Kuna kitu hakijaenda sawa';
}
