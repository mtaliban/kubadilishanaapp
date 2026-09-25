// AppShell — translation kamili ya AppShell.tsx + MobileTopBar + MobileBottomNav
// Inashirikishwa na Dashboard, Donate, Feedback, Profile
// Ina: top bar (hamburger + avatar + lang toggle) + bottom nav (4 tabs) + global WS toast
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';
import 'user_top_bar.dart';

const _kAdminPhone = '0763795801';

// ── Language Provider (singleton) ─────────────────────────────────────────────
/// Kama web LangToggle — SW (Kiswahili) au EN (English)
class LanguageProvider extends ChangeNotifier {
  static final LanguageProvider _i = LanguageProvider._();
  factory LanguageProvider() => _i;
  LanguageProvider._();

  String _lang = 'sw';
  String get lang => _lang;

  void setLang(String code) {
    if (_lang == code) return;
    _lang = code;
    notifyListeners();
  }
}

// ── Badge Service (singleton) ─────────────────────────────────────────────────
/// Kama web unreadStore — counts za unread notifications kwa kila route
class BadgeService extends ChangeNotifier {
  static final BadgeService _i = BadgeService._();
  factory BadgeService() => _i;
  BadgeService._();

  Map<String, int> counts = {};
  final Map<String, List<String>> _ids = {};
  Timer? _pollTimer;

  void start() {
    refresh();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  void stop() => _pollTimer?.cancel();

  Future<void> refresh() async {
    try {
      final res = await ApiService().getNotifications(limit: 100);
      final data = res.data;
      final List<dynamic> items =
          data is List ? data : (data['notifications'] ?? data['items'] ?? []);

      final newCounts = <String, int>{};
      final newIds = <String, List<String>>{};

      for (final n in items) {
        final read = n['read'] ?? n['is_read'] ?? false;
        if (read == true) continue;
        final type = (n['type'] as String?) ?? '';
        final id = '${n['notification_id'] ?? n['id'] ?? ''}';
        final route = routeFor(type);
        if (route == '/notifications') continue;
        newCounts[route] = (newCounts[route] ?? 0) + 1;
        if (id.isNotEmpty) newIds[route] = [...(newIds[route] ?? []), id];
      }

      counts = newCounts;
      _ids
        ..clear()
        ..addAll(newIds);
      notifyListeners();
    } catch (_) {}
  }

  void bump(String type) {
    final route = routeFor(type);
    if (route == '/notifications') return;
    counts = {...counts, route: (counts[route] ?? 0) + 1};
    notifyListeners();
  }

  Future<void> clear(String route) async {
    final ids = List<String>.from(_ids[route] ?? []);
    counts = {...counts}..remove(route);
    _ids.remove(route);
    notifyListeners();
    for (final id in ids) {
      try {
        await ApiService().markNotificationRead(id);
      } catch (_) {}
    }
  }

  static String routeFor(String type) {
    switch (type) {
      case 'payment.submitted':
      case 'payment.approved':
      case 'payment.rejected':
      case 'payment.message':
      case 'payment.reply':
        return '/donate';
      case 'feedback.replied':
        return '/feedback';
      case 'match.found':
      case 'user.registered':
        return '/dashboard';
      default:
        return '/notifications';
    }
  }
}

// ── AppShell ──────────────────────────────────────────────────────────────────
/// Inawrapper screens zote za main tabs (Dashboard=0, Donate=1, Feedback=2, Profile=3)
/// Inatoa: Scaffold + top bar + bottom nav + global WS toast + phone chip
class AppShell extends StatefulWidget {
  final int tabIndex;
  final Widget child;

  const AppShell({
    required this.tabIndex,
    required this.child,
    super.key,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _badge = BadgeService();

  // Global WS toast (payment events + namba ya simu)
  String? _toastMsg;
  bool _toastIsSuccess = true;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _badge.start();
    // HUDUMA: badge.clear() inaita notifyListeners() — isitoke wakati wa build
    // (ListenableBuilder hapo juu bado inajenga). Panga baada ya frame ya kwanza.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _clearCurrentBadge();
    });

    // Sikiliza WS events kwa global toast
    WebSocketService().on('notification', _onWsNotification);
    WebSocketService().on('match.found', _onMatchFound);
    WebSocketService().on('announcement', _onAnnouncement);
    WebSocketService().on('announcement.new', _onAnnouncement);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _badge.stop(); // simamisha timer ya polling (singelton — hakuna mwingine)
    WebSocketService().off('notification', _onWsNotification);
    WebSocketService().off('match.found', _onMatchFound);
    WebSocketService().off('announcement', _onAnnouncement);
    WebSocketService().off('announcement.new', _onAnnouncement);
    super.dispose();
  }

  void _onWsNotification(Map<String, dynamic> payload) {
    final type = (payload['type'] as String?) ?? '';
    _badge.bump(type);
    switch (type) {
      case 'payment.approved':
        _showGlobalToast('✓ Malipo yamethibitishwa!', success: true);
      case 'payment.rejected':
        _showGlobalToast('✗ Malipo yamekataliwa. Piga: $_kAdminPhone', success: false);
      case 'feedback.replied':
        _showGlobalToast('📋 Admin amejibu maoni yako!', success: true);
      case 'match.found':
        _showGlobalToast('🤝 Umepata mwenzako! Angalia dashibodi.', success: true);
    }
  }

  void _onMatchFound(Map<String, dynamic> payload) {
    _badge.bump('match.found');
    _showGlobalToast('🤝 Umepata mwenzako! Angalia dashibodi.', success: true);
  }

  void _onAnnouncement(Map<String, dynamic> payload) {
    _badge.bump('announcement');
  }

  void _showGlobalToast(String msg, {bool success = true}) {
    if (!mounted) return;
    setState(() {
      _toastMsg = msg;
      _toastIsSuccess = success;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _toastMsg = null);
    });
  }

  /// Toast ya KUELEA — kama toast ya web: card ndogo yenye rangi ya maana,
  /// inaonekana juu ya content (hai-sukumi layout), inabofyika kufunga.
  Widget _floatingToast() {
    final ok = _toastIsSuccess;
    final bg = ok ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final border = ok ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);
    final fg = ok ? const Color(0xFF047857) : const Color(0xFFB91C1C);
    return GestureDetector(
      onTap: () {
        if (!ok) Navigator.pushReplacementNamed(context, '/donate');
        setState(() => _toastMsg = null);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 17, color: fg),
          const SizedBox(width: 9),
          Expanded(child: Text(_toastMsg!,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: fg))),
          GestureDetector(
            onTap: () => setState(() => _toastMsg = null),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.close_rounded,
                  size: 16, color: fg.withValues(alpha: 0.65)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _clearCurrentBadge() async {
    const routes = ['/dashboard', '/donate', '/feedback', '/profile'];
    if (widget.tabIndex < routes.length) {
      await _badge.clear(routes[widget.tabIndex]);
    }
  }

  static const _tabRoutes = ['/dashboard', '/donate', '/feedback', '/profile'];

  void _navigateTab(int idx) {
    if (idx == widget.tabIndex) return;
    _badge.clear(_tabRoutes[idx]);
    Navigator.pushReplacementNamed(context, _tabRoutes[idx]);
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ── Bottom nav item ──
  Widget _navItem(int idx, String svgAsset, String label, String route, int badge) {
    final active = widget.tabIndex == idx;
    const brandBlue = Color(0xFF1E40AF);
    const grey500 = Color(0xFF6B7280);
    final color = active ? brandBlue : grey500;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (active) return;
          _badge.clear(route);
          Navigator.pushReplacementNamed(context, route);
        },
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            SvgPicture.asset(svgAsset, width: 22, height: 22,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
            if (badge > 0)
              Positioned(
                top: -4, right: -6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFFDC2626)),
                  child: Center(child: Text(badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold,
                          color: Colors.white))),
                ),
              ),
          ]),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
            fontSize: 9,
            fontWeight: active ? FontWeight.bold : FontWeight.w600,
            color: color,
          ), textAlign: TextAlign.center),
          if (active) ...[
            const SizedBox(height: 2),
            Container(width: 12, height: 2,
                decoration: BoxDecoration(
                    color: brandBlue, borderRadius: BorderRadius.circular(1))),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return ListenableBuilder(
      listenable: _badge,
      builder: (context, _) {
        final counts = _badge.counts;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Stack(children: [
              // Positioned.fill inahakikisha Column inapata constraints zenye
              // kikomo (Expanded inahitaji hilo ndani ya Stack).
              Positioned.fill(child: Column(children: [

              // ══ TOP BAR — UserTopBar mpya (menyu ya ≡ + duara la jina + SW|EN) ══
              UserTopBar(
                name: user?.fullName ?? '',
                currentPage: UserPage.values[widget.tabIndex.clamp(0, 3)],
                lang: LanguageProvider().lang,
                onLangChanged: (l) => setState(() => LanguageProvider().setLang(l)),
                onNavigate: (page) => _navigateTab(page.index),
                onLogout: _logout,
              ),

              // ══ CONTENT ══════════════════════════════════════════════════════
              Expanded(child: widget.child),
              ])),

              // ══ GLOBAL TOAST — inaelea juu ya content (kama web toast) ══════
              if (_toastMsg != null)
                Positioned(
                  left: 12, right: 12, bottom: 12,
                  child: _floatingToast(),
                ),
            ]),
          ),

          // ══ BOTTOM NAV (min-h-[56px]) ═══════════════════════════════════════
          // Kama web MobileBottomNav: bg-white border-t shadow-up.
          // withNoTextScaling: lebo za nav hazikali na font kubwa ya mfumo
          // (pattern ya iOS/Android) —azuia overflow kwenye simu ndogo.
          bottomNavigationBar: MediaQuery.withNoTextScaling(
            child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10, offset: const Offset(0, -2),
              )],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Row(children: [
                  _navItem(0, 'assets/icons/layout-dashboard.svg', 'Dashibodi',
                      '/dashboard', counts['/dashboard'] ?? 0),
                  _navItem(1, 'assets/icons/hand-coins.svg', 'Changia',
                      '/donate', counts['/donate'] ?? 0),
                  _navItem(2, 'assets/icons/clipboard-list.svg', 'Maoni',
                      '/feedback', counts['/feedback'] ?? 0),
                  _navItem(3, 'assets/icons/user.svg', 'Wasifu',
                      '/profile', counts['/profile'] ?? 0),
                ]),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
