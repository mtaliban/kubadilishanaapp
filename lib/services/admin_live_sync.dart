/// AdminLiveSync — huduma MOJA ya live-refresh kwa kurasa zote za admin.
///
/// KASORO ILIYOKUWA: ukurasa unaofungwa unapakia mara moja (initState), ila
/// WS event ikija UKO UPO (mf. mtumiaji mpya, malipo, maoni), ukurasa
/// HAUJITASASISHI mpaka utoke na urudi — data inaonyesha ya zamani.
///
/// SABABU ZA MFUMO:
///  1. Kurasa nyingi za admin (dashboard, matangazo, wenzao, waliopigiana,
///     contacts, reports, monitoring, mechi) HAZISIKILIZI WS KABISA —
///     zilikuwa zinapakia tu kwenye `initState()`.
///  2. Backend inatuma tukio kwa ADMIN kama `notification` (envelope yenye
///     `type: user.registered` n.k.) — si event raw `user.registered`.
///     Kurasa zilizosikiliza raw-pekee zilipuuza arifa za admin.
///  3. Baadhi ya APIs (stats/reports/data/monitoring n.k.) zilikuwa
///     cache-first (TTL dakika 2–15) — hata reload ikiitwa, data ya zamani
///     ilirudi kutoka cache ya AppCache (zimefanyiwa useCache:false).
///
/// KANUNI YA HUDUMA HII:
///  • Inasikiliza WS MARA MOJA (onAny) — si kila ukurasa kuunganisha neno.
///  • Ukurasa unaomba aina (Set<String>) na kupewa ticket — kuiita kwenye
///    dispose() inamwondoa. Washukaji WOTE wanaoreceive reload mara event
///    inayolingana (raw AU ndani ya 'notification' envelope).
///  • Wakati huo event MOJA reload MOJA — bila kuzidisha mtandao.
library;

import 'websocket_service.dart';

/// Ticket inayorudishwa na [AdminLiveSync.listen] — call it kwenye
/// dispose() ya ukurasa: `final _live = ... and later: _live();`
typedef AdminLiveTicket = void Function();

class AdminLiveSync {
  static final AdminLiveSync _i = AdminLiveSync._();
  factory AdminLiveSync() => _i;
  AdminLiveSync._();

  final List<_Sub> _subs = [];
  bool _hooked = false;

  /// Jiunge na kurasa zako kwa aina (events) fulani.
  ///
  /// Aina zinazofika kwenye WS:
  ///  • RAW: `user.registered`, `user.changed`, `user.removed`,
  ///    `user.updated_by_admin`, `match.found`, `data.changed`,
  ///    `contact.activity`, `announcement`, `announcement.new` n.k.
  ///  • `notification` envelope: payload ina `type:` ile ile — mf. admins
  ///    hupokea mtumiaji mpya kupitia `notification`-envelope yenye
  ///    `type: user.registered`. Kumpanganyika ko hii inafanywa KIMBARA hapa
  ///    — ukurasa hapaswi kujua farada za envelope za backend.
  /// KUSIKILIZA VYOTE (Broad-mode) — event YOYOTE ya WS (raw + envelope
  /// 'notification') inaita [onEvent], isipokuwa aina kwenye [skip]
  /// (kwa mf. 'pong'/'heartbeat'). HII NI YA PAGES ZINAZOTAKA DATA MPYA
  /// PAPO HAPO bila kujua orodha kamili ya aina — kila ukurasa unaweza
  /// ku-refresh mara data inabadilika, BILO LA KUSUBIRI mtumiaji atoke
  /// na arudi (kasoro ya "badge inaonyesha, data bado ya kale").
  ///
  /// REJESHO: ticket — iite kwenye dispose() ya ukurasa.
  AdminLiveTicket listenAll(void Function() onEvent,
      {Set<String> skip = const {'pong', 'heartbeat'}}) {
    _hook();
    final sub = _Sub(const <String>{}, onEvent)..skip = skip;
    _subs.add(sub);
    return () => _subs.remove(sub);
  }

  AdminLiveTicket listen(Set<String> events, void Function() onEvent) {
    _hook();
    final sub = _Sub(Set<String>.of(events), onEvent);
    _subs.add(sub);
    return () => _subs.remove(sub);
  }

  void _hook() {
    if (_hooked) return;
    _hooked = true;
    WebSocketService().onAny(_onAny);
  }

  void _onAny(Map<String, dynamic> event) {
    final raw = (event['event'] ?? event['type'])?.toString() ?? '';
    if (raw.isEmpty || raw == 'pong') return;
    final ntype = (event['type'] as String?)?.toString() ?? '';
    final keys = <String>{raw};
    if (ntype.isNotEmpty && ntype != raw) keys.add(ntype);
    // Snapshot — subscriber mpya anajisajili ndani ya callback hapajitokezi
    // kwenye duara hii (hakuna ConcurrentModificationError).
    for (final s in List<_Sub>.from(_subs)) {
      // listenAll (events tupu): kila aina ya event — BILA zilizo kwenye skip.
      final hit = s.events.isEmpty
          ? keys.any((k) => !s.skip.contains(k))
          : s.events.intersection(keys).isNotEmpty;
      if (hit) {
        try {
          s.onEvent();
        } catch (_) {}
      }
    }
  }
}

class _Sub {
  final Set<String> events;
  final void Function() onEvent;
  _Sub(this.events, this.onEvent);

  /// listenAll: aina hizi ZISIJITOE (pong/heartbeat n.k.).
  Set<String> skip = const <String>{};
}
