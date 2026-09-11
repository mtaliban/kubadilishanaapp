// AppShell — translation kamili ya AppShell.tsx + MobileTopBar + MobileBottomNav
// Inashirikishwa na Dashboard, Donate, Feedback, Profile
// Ina: top bar (hamburger + avatar + lang toggle) + bottom nav (4 tabs) + global WS toast
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

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
  final _hamburgerKey = GlobalKey();
  final _avatarKey = GlobalKey();
  OverlayEntry? _menuOverlay;

  // Global WS toast (payment events + namba ya simu)
  String? _toastMsg;
  bool _toastIsSuccess = true;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _badge.start();
    _clearCurrentBadge();

    // Sikiliza WS events kwa global toast
    WebSocketService().on('notification', _onWsNotification);
  }

  @override
  void dispose() {
    _closeMenu();
    _toastTimer?.cancel();
    WebSocketService().off('notification', _onWsNotification);
    super.dispose();
  }

  void _onWsNotification(Map<String, dynamic> payload) {
    final type = (payload['type'] as String?) ?? '';
    _badge.bump(type);
    // Global toast kwa payment events
    if (type == 'payment.approved') {
      _showGlobalToast('✓ Malipo yamethibitishwa!', success: true);
    } else if (type == 'payment.rejected') {
      _showGlobalToast('✗ Malipo yamekataliwa. Piga: $_kAdminPhone', success: false);
    } else if (type == 'feedback.replied') {
      _showGlobalToast('📋 Admin amejibu maoni yako!', success: true);
    }
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

  Future<void> _clearCurrentBadge() async {
    const routes = ['/dashboard', '/donate', '/feedback', '/profile'];
    if (widget.tabIndex < routes.length) {
      await _badge.clear(routes[widget.tabIndex]);
    }
  }

  void _closeMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  // ── Hamburger dropdown ──
  void _showHamburgerMenu(AuthUser? user) {
    _closeMenu();
    final rb = _hamburgerKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos = rb.localToGlobal(Offset.zero);
    final sz = rb.size;
    final counts = Map<String, int>.from(_badge.counts);

    _menuOverlay = OverlayEntry(builder: (_) => Stack(children: [
      Positioned.fill(child: GestureDetector(
        onTap: _closeMenu,
        behavior: HitTestBehavior.opaque,
      )),
      Positioned(
        top: pos.dy + sz.height + 4,
        left: pos.dx,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 224,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F4F6)),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Nav links (kama web — hakuna WS pill kwenye mobile hamburger)
              _dropLink(context, Icons.dashboard_outlined, 'Nyumbani', '/dashboard',
                  counts, widget.tabIndex == 0),
              _dropLink(context, Icons.volunteer_activism_outlined, 'Changia', '/donate',
                  counts, widget.tabIndex == 1),
              _dropLink(context, Icons.assignment_outlined, 'Maoni', '/feedback',
                  counts, widget.tabIndex == 2),
              _dropLink(context, Icons.person_outline, 'Wasifu', '/profile',
                  counts, widget.tabIndex == 3),
            ]),
          ),
        ),
      ),
    ]));
    Overlay.of(context).insert(_menuOverlay!);
  }

  Widget _dropLink(BuildContext ctx, IconData icon, String label, String route,
      Map<String, int> counts, bool active) {
    final badge = counts[route] ?? 0;
    final color = active ? const Color(0xFF1E40AF) : const Color(0xFF374151);
    return GestureDetector(
      onTap: () {
        _closeMenu();
        if (!active) {
          _badge.clear(route);
          Navigator.pushReplacementNamed(ctx, route);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color))),
          if (badge > 0)
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFDC2626)),
              child: Center(child: Text(badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                      color: Colors.white))),
            ),
        ]),
      ),
    );
  }

  // ── Avatar/profile dropdown ──
  void _showProfileMenu(AuthUser? user) {
    _closeMenu();
    final rb = _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos = rb.localToGlobal(Offset.zero);
    final sz = rb.size;
    final screenW = MediaQuery.of(context).size.width;

    _menuOverlay = OverlayEntry(builder: (_) => Stack(children: [
      Positioned.fill(child: GestureDetector(
        onTap: _closeMenu,
        behavior: HitTestBehavior.opaque,
      )),
      Positioned(
        top: pos.dy + sz.height + 4,
        right: screenW - pos.dx - sz.width,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 208,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F4F6)),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // User info
              if (user != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.fullName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                            color: Color(0xFF111827)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(user.phone,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    if ((user.cadreDisplay ?? '').isNotEmpty)
                      Text(user.cadreDisplay!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
                  ]),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
              ],
              // Profile link
              GestureDetector(
                onTap: () {
                  _closeMenu();
                  if (widget.tabIndex != 3) {
                    _badge.clear('/profile');
                    Navigator.pushReplacementNamed(context, '/profile');
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(children: [
                    Icon(Icons.person_outline, size: 18, color: Color(0xFF374151)),
                    SizedBox(width: 12),
                    Text('Wasifu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: Color(0xFF374151))),
                  ]),
                ),
              ),
              // Logout — text-brand-red
              GestureDetector(
                onTap: () async {
                  _closeMenu();
                  await context.read<AuthProvider>().logout();
                  if (mounted) Navigator.pushReplacementNamed(context, '/login');
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(children: [
                    Icon(Icons.logout, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 12),
                    Text('Toka', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: Color(0xFFDC2626))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]));
    Overlay.of(context).insert(_menuOverlay!);
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
            SvgPicture.asset(svgAsset, width: 20, height: 20,
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
          Text(label, style: TextStyle(
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
    final initial = _initials(user?.fullName ?? 'M');

    return ListenableBuilder(
      listenable: _badge,
      builder: (context, _) {
        final counts = _badge.counts;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(children: [

              // ══ TOP BAR (h-14 = 56px) ══════════════════════════════════════
              // Kama web: fixed top-0 bg-white border-b shadow-sm
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                  boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
                ),
                child: Row(children: [
                  // ── LEFT: Hamburger ─────────────────────────────────────────
                  // w-10 h-10 rounded-xl bg-brand-grey-100
                  GestureDetector(
                    onTap: () => _showHamburgerMenu(user),
                    child: Container(
                      key: _hamburgerKey,
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.menu, size: 22, color: Color(0xFF374151)),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── RIGHT: Avatar + LangToggle (kama web) ──────────────────
                  // Avatar — w-8 h-8 rounded-full bg-brand-blue-50 border-blue-200 text-blue-700
                  GestureDetector(
                    onTap: () => _showProfileMenu(user),
                    child: Container(
                      key: _avatarKey,
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEFF6FF), // brand-blue-50
                        border: Border.all(color: const Color(0xFFBFDBFE)), // brand-blue-200
                      ),
                      child: Center(child: Text(initial,
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8), // brand-blue-700
                          ))),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _LangToggle(),
                ]),
              ),

              // ══ GLOBAL TOAST (WS payment events) ════════════════════════════
              // Inaonekana kila page pale WS event inafika
              if (_toastMsg != null)
                GestureDetector(
                  onTap: () {
                    if (!_toastIsSuccess) {
                      // Namba inapobonyezwa — wazi dialer
                      Navigator.pushReplacementNamed(context, '/donate');
                    }
                    setState(() => _toastMsg = null);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _toastIsSuccess
                          ? const Color(0xFF065F46) // emerald-800
                          : const Color(0xFF1E40AF), // brand-blue
                    ),
                    child: Row(children: [
                      Icon(
                        _toastIsSuccess ? Icons.check_circle_outline : Icons.info_outline,
                        size: 14, color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_toastMsg!,
                          style: const TextStyle(
                            fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500,
                          ))),
                      const Icon(Icons.close, size: 14, color: Colors.white70),
                    ]),
                  ),
                ),

              // ══ CONTENT ══════════════════════════════════════════════════════
              Expanded(child: widget.child),
            ]),
          ),

          // ══ BOTTOM NAV (min-h-[52px]) ═══════════════════════════════════════
          // Kama web MobileBottomNav: bg-white border-t shadow-up
          bottomNavigationBar: Container(
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
                height: 52,
                child: Row(children: [
                  _navItem(0, 'assets/icons/layout-dashboard.svg', 'Nyumbani',
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
        );
      },
    );
  }
}

// ── LangToggle — kama web: SW / EN buttons kando kando ───────────────────────
class _LangToggle extends StatelessWidget {
  const _LangToggle();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageProvider(),
      builder: (context, _) {
        final lang = LanguageProvider().lang;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _btn('SW', 'sw', lang, isLeft: true),
            _btn('EN', 'en', lang, isLeft: false),
          ]),
        );
      },
    );
  }

  Widget _btn(String label, String code, String current, {required bool isLeft}) {
    final active = current == code;
    return GestureDetector(
      onTap: () => LanguageProvider().setLang(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1E40AF) : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: isLeft ? const Radius.circular(7) : Radius.zero,
            bottomLeft: isLeft ? const Radius.circular(7) : Radius.zero,
            topRight: isLeft ? Radius.zero : const Radius.circular(7),
            bottomRight: isLeft ? Radius.zero : const Radius.circular(7),
          ),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold,
            color: active ? Colors.white : const Color(0xFF1E40AF),
          )),
      ),
    );
  }
}
