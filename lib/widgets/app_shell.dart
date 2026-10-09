// AppShell — translation kamili ya AppShell.tsx + MobileTopBar + MobileBottomNav
// Inashirikishwa na Dashboard, Donate, Feedback, Profile
// Ina: top bar (UserTopBar) + bottom nav (4 tabs) + global WS toast
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';
import 'app_toast.dart';
import 'network_banner.dart';
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

// ── Theme Provider (singleton) ──────────────────────────────────────────────
/// Inabadilisha DARK/LIGHT theme ya app nzima (admins + users).
/// MaterialApp ina ListenableBuilder juu yake (`themeLight()` na `darkMode()`).
class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _i = ThemeProvider._();
  factory ThemeProvider() => _i;
  ThemeProvider._();

  bool _dark = false;
  bool get dark => _dark;

  void toggle() {
    _dark = !_dark;
    notifyListeners();
  }

  void setDark(bool d) {
    if (_dark == d) return;
    _dark = d;
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
      case 'admin.reply':
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
        AppToast.success('Malipo yamethibitishwa');
      case 'payment.rejected':
        AppToast.error('Malipo yamekataliwa · piga $_kAdminPhone');
      case 'feedback.replied':
        AppToast.success('Admin amejibu maoni yako');
      case 'match.found':
        AppToast.success('Umepata mwenzako. Angalia dashibodi');
      case 'user.registered':
        AppToast.success('Mtu anayefaa amejiunga. Angalia dashibodi');
    }
  }

  void _onMatchFound(Map<String, dynamic> payload) {
    _badge.bump('match.found');
    AppToast.success('Umepata mwenzako. Angalia dashibodi');
  }

  void _onAnnouncement(Map<String, dynamic> payload) {
    _badge.bump('announcement');
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
                top: -6, right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
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

        return NetworkToastListener(
          child: Scaffold(
          backgroundColor: AppColors.bg,
          body: ToastHost(child: SafeArea(
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

              // ══ NETWORK BANNER — offline/connecting/online ══════════════════
              const NetworkBanner(),

              // ══ CONTENT ══════════════════════════════════════════════════════
              Expanded(child: widget.child),
              ])),

            ]),
          )),

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
        ));
      },
    );
  }
}
