import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../services/api_service.dart';
import '../services/cached_repository.dart';
import '../services/websocket_service.dart';
import '../widgets/no_cached_data_widget.dart';
import '../widgets/skeletons.dart';
import '../widgets/time_ago.dart';

// OFFLINE-FIRST — funguo ya diski ya arifa za mtumiaji.
const _kNotifsKey = 'page:notifications';

const _kBrand    = Color(0xFF1E40AF);
const _kBrand50  = Color(0xFFEFF6FF);
const _kBrand100 = Color(0xFFDBEAFE);
const _kGrey100  = Color(0xFFF3F4F6);
const _kGrey200  = Color(0xFFE5E7EB);
const _kGrey400  = Color(0xFF9CA3AF);
const _kGrey500  = Color(0xFF6B7280);
const _kGrey700  = Color(0xFF374151);
const _kGrey900  = Color(0xFF111827);

// ── Theme-aware helpers (light values = original const) ─
bool _nd(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _kGrey100T(BuildContext c) => _nd(c) ? const Color(0xFF212833) : _kGrey100;
Color _kGrey200T(BuildContext c) => _nd(c) ? const Color(0xFF2A3240) : _kGrey200;
Color _kGrey400T(BuildContext c) => _nd(c) ? const Color(0xFF64748B) : _kGrey400;
Color _kGrey500T(BuildContext c) => _nd(c) ? const Color(0xFF9AA8C7) : _kGrey500;
Color _kGrey700T(BuildContext c) => _nd(c) ? const Color(0xFFCBD5E1) : _kGrey700;
Color _kGrey900T(BuildContext c) => _nd(c) ? const Color(0xFFE7ECF8) : _kGrey900;
Color _kBrand50T(BuildContext c) => _nd(c) ? const Color(0xFF1C2A44) : _kBrand50;
Color _kBrandT(BuildContext c) => _nd(c) ? const Color(0xFF7AA7FF) : _kBrand;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // DISKI PAPO HAPO — data ya diski KWA FRAME YA KWANZA, hakuna spring
    // hata milisekunde moja (kanuni ya WhatsApp). Refresh mtandaoni ni nyuma
    // ya pazia; data mpya ikija ukurasa unajisasisha kimya.
    CachedRepository().hydrate(_kNotifsKey, _applyNotifs);
    _load();
    WebSocketService().on('notification', _onWs);
    WebSocketService().on('notification.new', _onWs);
  }

  void _applyNotifs(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final List<dynamic> items = data is List
        ? data
        : (data['notifications'] ?? data['items'] ?? []) as List;
    setState(() { _notifications = items; _loading = false; });
  }

  void _onWs(Map<String, dynamic> _) {
    if (mounted) _load();
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    WebSocketService().off('notification.new', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: arifa za diski zibaki.
    if (_notifications.isEmpty) setState(() => _loading = true);
    await CachedRepository().loadPage(_kNotifsKey,
        () async => (await ApiService().getNotifications(limit: 100)).data,
        _applyNotifs);
    if (mounted && _loading) setState(() => _loading = false);
    // Soma (mark-all-read) NYUMA YA PAZIA — inapofanikiwa tu.
    try { await ApiService().markAllRead(); } catch (_) {}
  }

  Future<void> _onTap(dynamic n) async {
    final id   = n['notification_id'] ?? n['id'] ?? '';
    final type = (n['type'] as String?) ?? '';
    if (!(n['read'] ?? false) && id.toString().isNotEmpty) {
      setState(() => n['read'] = true);
      try { await ApiService().markNotificationRead(id.toString()); } catch (_) {}
    }
    if (!mounted) return;
    switch (type) {
      case 'payment.approved':
      case 'payment.rejected':
      case 'payment.submitted':
      case 'payment.message':
      case 'payment.reply':
        Navigator.pushNamed(context, '/donate');
      case 'admin.reply':
      case 'feedback.replied':
      case 'feedback.new':
        Navigator.pushNamed(context, '/feedback');
      case 'announcement':
      case 'announcement.new':
        Navigator.pushNamed(context, '/announcements');
      case 'match.found':
      case 'match.new':
        Navigator.pop(context);
    }
  }

  Future<void> _markAll() async {
    try { await ApiService().markAllRead(); } catch (_) {}
    if (mounted) {
      setState(() {
        for (final n in _notifications) {
          n['read'] = true;
        }
      });
    }
  }

  // ── Muonekano wa icon kwa kila aina ───────────────────────────────────────
  /// ── Icons za DRAWER (Tabler) — mtindo MMOJA na drawer/nav ya admin ──
  /// (mtumia alitaka icons za hapa zikae na zile za drawer; kila aina ina
  ///  icon yake halisi — mtu anajiunga, malipo, maoni, mechi n.k.)
  static (IconData, Color, Color) _look(String type) {
    return switch (type) {
      'payment.approved'                    => (TablerIcons.circle_check,   const Color(0xFFD1FAE5), const Color(0xFF047857)),
      'payment.rejected'                    => (TablerIcons.circle_x,       const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'payment.submitted' ||
      'payment.message'   ||
      'payment.reply'                       => (TablerIcons.coin,           const Color(0xFFECFDF5), const Color(0xFF059669)), // drawer: Malipo
      'match.found' || 'match.new'          => (TablerIcons.link,           const Color(0xFFFCE7F3), const Color(0xFFBE185D)), // drawer: Wenzao
      'user.registered'                     => (TablerIcons.user_plus,      const Color(0xFFEDE9FE), const Color(0xFF6D28D9)), // mtu anajiunga
      'announcement' || 'announcement.new'  => (TablerIcons.speakerphone,   const Color(0xFFFEF3C7), const Color(0xFFB45309)), // drawer: Matangazo
      'feedback.replied' || 'admin.reply'   => (TablerIcons.message_2,      const Color(0xFFDBEAFE), const Color(0xFF1E40AF)), // drawer: Maoni
      'feedback.new'                        => (TablerIcons.message_2,      const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
      'message.sent' || 'message.new' ||
      'message'                             => (TablerIcons.message_dots,   const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      'call.initiated'                      => (TablerIcons.phone,          const Color(0xFFD1FAE5), const Color(0xFF047857)), // drawer: Waliopigiana
      _                                     => (TablerIcons.bell,           _kBrand100,              _kBrand),
    };
  }

  // ARIFA: muda KAMA WHATSAPP — "Sasa hivi", "dak 7", "saa 2", "Jana",
  // siku "3 Ago". Hapo awali leo ilikuwa "d Mon · HH:MM" tu — mtumiaji
  // ambaye hajui muda uliopita ("7m ago") ilipaswa kusoma muda halisi.
  static String _shortTime(String iso) => timeAgoShort(iso);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !(n['read'] ?? false)).length;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(unread),
          _summaryStrip(),
          Divider(height: 1, color: _kGrey200T(context)),
          Expanded(
            child: _loading && _notifications.isEmpty
                // KANUNI: KAMWE spinner — kijivu (skeleton) tu.
                ? const WatumiajiSkeleton(count: 5)
                : _notifications.isEmpty &&
                        CachedRepository().readOrNull<dynamic>(_kNotifsKey) == null
                    // HAKUNA data diski + API imeshindwa — widget MOYA ya
                    // "haijapakuliwa" (pull-to-refresh pekee).
                    ? const NoCachedDataWidget(
                        hint: 'Vuta chini kupakia — arifa zitahifadhiwa kwenye simu.',
                        onLoad: null,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: _kBrandT(context),
                        child: _notifications.isEmpty ? _empty() : _list(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStrip() {
    final Map<String, int> groups = {};
    for (final n in _notifications) {
      if (n['read'] == true) continue;
      final type = (n['type'] as String?) ?? '';
      final g = _typeGroup(type);
      if (g != null) groups[g] = (groups[g] ?? 0) + 1;
    }
    if (groups.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: groups.entries.map((e) {
          final (icon, bg, fg) = _groupStyle(e.key);
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text('${e.value}', style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 5),
              Text(_groupName(e.key), style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  static String? _typeGroup(String type) => switch (type) {
    'user.registered' || 'match.found' || 'match.new' => 'wenzao',
    'payment.approved' || 'payment.rejected' ||
    'payment.submitted' || 'payment.message' || 'payment.reply' => 'malipo',
    'announcement' || 'announcement.new' => 'matangazo',
    'admin.reply' || 'feedback.replied' || 'feedback.new' => 'maoni',
    _ => null,
  };

  static (IconData, Color, Color) _groupStyle(String group) => switch (group) {
    'wenzao'    => (TablerIcons.link,          const Color(0xFFD1FAE5), const Color(0xFF047857)),
    'malipo'    => (TablerIcons.coin,          const Color(0xFFD1FAE5), const Color(0xFF047857)),
    'matangazo' => (TablerIcons.speakerphone,  const Color(0xFFFEF3C7), const Color(0xFFB45309)),
    'maoni'     => (TablerIcons.message_2,     _kBrand100, _kBrand),
    _           => (TablerIcons.bell,          _kGrey100, _kGrey500),
  };

  static String _groupName(String group) => switch (group) {
    'wenzao'    => 'Wenzao wapya',
    'malipo'    => 'Malipo',
    'matangazo' => 'Matangazo',
    'maoni'     => 'Maoni',
    _           => group,
  };

  Widget _header(int unread) {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _kGrey100T(context), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: _kGrey700T(context)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Arifa',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: _kGrey900T(context), height: 1.1)),
          Text(
            unread > 0 ? '$unread hazijasomwa' : 'Zote zimesomwa',
            style: TextStyle(
              fontSize: 12,
              color: unread > 0 ? _kBrand : _kGrey400,
              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ])),
        if (unread > 0)
          GestureDetector(
            onTap: _markAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _kBrand50T(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBrandT(context).withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.done_all_rounded, size: 14, color: _kBrandT(context)),
                const SizedBox(width: 4),
                Text('Soma Zote', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _kBrandT(context))),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _empty() {
    return ListView(children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.22),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: _kGrey100T(context), borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.notifications_none_rounded,
              size: 30, color: _kGrey400),
        ),
        const SizedBox(height: 16),
        const Text('Hakuna arifa bado',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: _kGrey700)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Ukipata match, ujumbe au mchango — itaonekana hapa.',
          style: TextStyle(fontSize: 12.5, color: _kGrey500T(context), height: 1.5),
          textAlign: TextAlign.center,
          ),
        ),
      ])),
    ]);
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 80),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 88, endIndent: 0, color: _kGrey200T(context)),
      itemBuilder: (_, i) => _tile(_notifications[i]),
    );
  }

  Widget _tile(dynamic n) {
    final read  = n['read'] ?? false;
    final type  = (n['type'] as String?) ?? '';
    final title = (n['title'] ?? '').toString();
    final body  = (n['body']  ?? '').toString();
    final time  = _shortTime(n['created_at'] ?? '');
    final (icon, iconBg, iconFg) = _look(type);

    return GestureDetector(
      onTap: () => _onTap(n),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: read ? null : iconBg.withValues(alpha: 0.08),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Icon ya duara + ES badge ──────────────────────────────────────
          Stack(clipBehavior: Clip.none, children: [
            // ── Icon ya Duara (interface ya AppToast) — duara la rangi ya
            //    aina + icon za Tabler KUBWA (26) — hakuna kijivu tupu kila aina.
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: read ? _kGrey100T(context) : iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon,
                    size: 26, color: read ? _kGrey500 : iconFg),
              ),
            ),
            // ES badge — chini-kulia (kama design ya picha)
            Positioned(
              right: -2, bottom: -2,
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
                  border: Border.all(color: _kGrey200T(context), width: 1.5),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/ess_badge.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: _kBrand,
                      child: Center(
                        child: Text('ES',
                            style: TextStyle(fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(width: 14),

          // ── Maudhui ──────────────────────────────────────────────────────
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                  color: read ? _kGrey700 : _kGrey900,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )),
              if (time.isNotEmpty) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(time, style: TextStyle(
                    fontSize: 12,
                    fontWeight: read ? FontWeight.normal : FontWeight.w600,
                    color: read ? _kGrey400T(context) : _kBrandT(context),
                  )),
                ),
              ],
            ]),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body,
                  style: TextStyle(
                      fontSize: 13, color: _kGrey500T(context), height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ])),

          // ── Dot ya bluu kwa zisizosomwa (kama WhatsApp) ──────────────────
          if (!read) ...[
            const SizedBox(width: 10),
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 9, height: 9,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: _kBrand),
            ),
          ],
        ]),
      ),
    );
  }
}