import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/app_cache.dart';
import '../../services/app_navigator.dart';
import '../../services/websocket_service.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_page.dart';
import 'admin_data_page.dart';
import 'admin_payments_page.dart';
import 'admin_contacts_page.dart';
import 'admin_feedback_page.dart';
import 'admin_announcements_page.dart';
import 'admin_password_resets_page.dart';
import 'admin_reports_page.dart';
import 'admin_events_page.dart';
import 'admin_matches_page.dart';
import 'admin_real_matches_page.dart';
import 'admin_monitoring_page.dart';
import 'admin_csv_page.dart';

const _kBlue   = Color(0xFF1E40AF);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey100 = Color(0xFFF3F4F6);
const _kRed    = Color(0xFFDC2626);

// Bottom nav: 5 tab indices → page list index
const _tabPageIndex = [0, 1, 11, 3, 5];

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _pageIndex = 0; // index into _pages list
  int _tabIndex  = 0; // active bottom tab (0-4)

  final _pages = const [
    AdminDashboardPage(),   // 0
    AdminUsersPage(),       // 1
    AdminDataPage(),        // 2
    AdminPaymentsPage(),    // 3
    AdminContactsPage(),    // 4
    AdminFeedbackPage(),    // 5
    AdminAnnouncementsPage(), // 6
    AdminPasswordResetsPage(), // 7
    AdminReportsPage(),     // 8
    AdminEventsPage(),      // 9
    AdminMatchesPage(),     // 10
    AdminRealMatchesPage(), // 11
    AdminMonitoringPage(),  // 12
    AdminCsvPage(),         // 13
  ];

  // WS callback references for proper cleanup in dispose()
  late final WsEventCallback _wsOnNotification;
  late final WsEventCallback _wsOnUserReg;
  late final WsEventCallback _wsOnPayment;
  late final WsEventCallback _wsOnFeedback;
  late final WsEventCallback _wsOnMatch;
  late final WsEventCallback _wsOnReset;
  late final WsEventCallback _wsOnDataChanged;

  // Badges per route (kama web unreadStore) — map route → count
  final Map<String, int> _routeCounts = {};
  final Map<String, List<String>> _routeNotifIds = {};
  Timer? _badgeTimer;

  // In-app toast (kama web showToast)
  String? _toastMsg;
  bool _toastIsSuccess = true;
  Timer? _toastTimer;

  final _hamburgerKey = GlobalKey();
  final _avatarKey    = GlobalKey();
  OverlayEntry? _menuOverlay;

  @override
  void initState() {
    super.initState();
    _refreshBadges();
    _setupRealtime();
    _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshBadges());
    adminPageNotifier.addListener(_onAdminPageNotified);
  }

  @override
  void dispose() {
    _closeMenu();
    _badgeTimer?.cancel();
    _toastTimer?.cancel();
    adminPageNotifier.removeListener(_onAdminPageNotified);
    final ws = WebSocketService();
    ws.off('notification',      _wsOnNotification);
    ws.off('user.registered',   _wsOnUserReg);
    ws.off('payment.submitted', _wsOnPayment);
    ws.off('feedback.new',      _wsOnFeedback);
    ws.off('match.found',       _wsOnMatch);
    ws.off('password_reset.new', _wsOnReset);
    ws.off('data.changed',      _wsOnDataChanged);
    super.dispose();
  }

  void _onAdminPageNotified() {
    final idx = adminPageNotifier.value;
    if (idx != null && mounted) {
      adminPageNotifier.value = null;
      _selectPage(idx, null);
    }
  }

  void _showToast(String msg, {bool success = true}) {
    if (!mounted) return;
    setState(() { _toastMsg = msg; _toastIsSuccess = success; });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _toastMsg = null);
    });
  }

  void _closeMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  void _setupRealtime() {
    final ws = WebSocketService();

    _wsOnNotification = (payload) {
      final type = (payload['type'] as String?) ?? '';
      final id   = '${payload['notification_id'] ?? payload['id'] ?? ''}';
      _bumpRoute(type, id);
      _toastForNotifType(type, payload);
    };
    _wsOnUserReg = (p) {
      final name = (p['full_name'] as String?)?.split(' ').first ?? 'Mtumiaji';
      _showToast('👤 $name amesajiliwa!');
      _refreshBadges();
    };
    _wsOnPayment = (p) {
      _showToast('💳 Malipo mapya yamefika!');
      _refreshBadges();
    };
    _wsOnFeedback = (p) {
      _showToast('📋 Maoni mapya yamefika!');
      _refreshBadges();
    };
    _wsOnMatch = (p) {
      _showToast('🤝 Match mpya imepatikana!');
      _bumpRoute('match.found', '');
    };
    _wsOnReset = (p) {
      _showToast('🔑 Ombi jipya la reset password!');
      _bumpRoute('password_reset.new', '');
    };
    _wsOnDataChanged = (_) {
      AppCache().invalidatePrefix('/locations');
      AppCache().invalidatePrefix('/cadres');
      AppCache().invalidatePrefix('/admin/data');
      AppCache().invalidatePrefix('/admin/departments');
    };

    ws.on('notification',      _wsOnNotification);
    ws.on('user.registered',   _wsOnUserReg);
    ws.on('payment.submitted', _wsOnPayment);
    ws.on('feedback.new',      _wsOnFeedback);
    ws.on('match.found',       _wsOnMatch);
    ws.on('password_reset.new', _wsOnReset);
    ws.on('data.changed',      _wsOnDataChanged);
  }

  void _toastForNotifType(String type, Map<String, dynamic> p) {
    switch (type) {
      case 'payment.submitted':
        _showToast('💳 Malipo mapya yamefika!');
      case 'feedback.new':
        _showToast('📋 Maoni mapya yamefika!');
      case 'user.registered':
        final name = (p['full_name'] as String?)?.split(' ').first ?? 'Mtumiaji';
        _showToast('👤 $name amesajiliwa!');
      case 'match.found':
        _showToast('🤝 Match mpya imepatikana!');
      case 'password_reset.new':
        _showToast('🔑 Ombi jipya la reset password!');
      case 'payment.approved':
        _showToast('✅ Malipo yamethibitishwa!');
      case 'payment.rejected':
        _showToast('❌ Malipo yamekataliwa.', success: false);
    }
  }

  String _routeForType(String type) {
    switch (type) {
      case 'payment.submitted':
      case 'payment.approved':
      case 'payment.rejected':
      case 'payment.message':
      case 'payment.reply': return '/admin/payments';
      case 'feedback.new':
      case 'feedback.replied': return '/admin/feedback';
      case 'user.registered':
      case 'user.profile_updated':
      case 'match.found': return '/admin/real-matches';
      case 'call.initiated': return '/admin/users';
      case 'password_reset.new': return '/admin/events';
      default: return '/notifications';
    }
  }

  Future<void> _refreshBadges() async {
    try {
      final res = await ApiService().getNotifications(limit: 100);
      final data = res.data;
      final List<dynamic> items = data is List ? data : (data['notifications'] ?? data['items'] ?? []);
      final counts = <String, int>{};
      final ids    = <String, List<String>>{};
      for (final n in items) {
        final read = n['read'] ?? n['is_read'] ?? false;
        if (read == true) continue;
        final type  = (n['type'] as String?) ?? '';
        final nid   = '${n['notification_id'] ?? n['id'] ?? ''}';
        final route = _routeForType(type);
        if (route == '/notifications') continue;
        counts[route] = (counts[route] ?? 0) + 1;
        if (nid.isNotEmpty) ids[route] = [...(ids[route] ?? []), nid];
      }
      if (mounted) setState(() {
        _routeCounts..clear()..addAll(counts);
        _routeNotifIds..clear()..addAll(ids);
      });
    } catch (_) {}
  }

  void _bumpRoute(String type, String notifId) {
    final route = _routeForType(type);
    if (route == '/notifications' || !mounted) return;
    setState(() {
      _routeCounts[route] = (_routeCounts[route] ?? 0) + 1;
      if (notifId.isNotEmpty) {
        _routeNotifIds[route] = [...(_routeNotifIds[route] ?? []), notifId];
      }
    });
  }

  Future<void> _clearRouteBadge(String route) async {
    final ids = List<String>.from(_routeNotifIds[route] ?? []);
    if (mounted) setState(() {
      _routeCounts.remove(route);
      _routeNotifIds.remove(route);
    });
    for (final id in ids) {
      try { await ApiService().markNotificationRead(id); } catch (_) {}
    }
  }

  void _selectPage(int pageIdx, String? badgeRoute) {
    // Which bottom tab corresponds?
    final tabIdx = _tabPageIndex.indexOf(pageIdx);
    setState(() {
      _pageIndex = pageIdx;
      _tabIndex  = tabIdx >= 0 ? tabIdx : _tabIndex;
    });
    if (badgeRoute != null) _clearRouteBadge(badgeRoute);
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    // ignore: unused_local_variable
    final user    = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(children: [
          // ── MOBILE TOP BAR — h-14=56px kama web ──
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _kGrey100)),
              boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))],
            ),
            child: Row(children: [
              // Hamburger — w-10 h-10 rounded-xl bg-grey-100
              GestureDetector(
                onTap: _showHamburgerDropdown,
                child: Container(
                  key: _hamburgerKey,
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kGrey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.menu, size: 22, color: _kGrey700)),
                ),
              ),
              const Spacer(),
              // Avatar + LangToggle
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: _showProfileDropdown,
                  child: SizedBox(
                    key: _avatarKey,
                    width: 36, height: 36,
                    child: Center(
                      child: Icon(Icons.person_rounded, size: 22, color: _kBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const _LangToggle(),
              ]),
            ]),
          ),

          // ── TOAST (WS events — kama web showToast) ──
          if (_toastMsg != null)
            GestureDetector(
              onTap: () => setState(() => _toastMsg = null),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _toastIsSuccess ? const Color(0xFF065F46) : _kRed,
                ),
                child: Row(children: [
                  Icon(
                    _toastIsSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    size: 14, color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_toastMsg!,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500))),
                  const Icon(Icons.close, size: 14, color: Colors.white70),
                ]),
              ),
            ),

          // ── PAGE CONTENT ──
          Expanded(child: _pages[_pageIndex]),
        ]),
      ),

      // ── MOBILE BOTTOM NAV — h-52px kama web MobileBottomNav ──
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _kGrey100)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            child: Row(children: [
              _navItem(0, 'assets/icons/crown.svg',          'Admin',    '/admin',              0),
              _navItem(1, 'assets/icons/users.svg',          'Watu',     '/admin/users',        1),
              _navItem(2, null,                              'Waliofanana', '/admin/real-matches', 11, matIcon: Icons.sync_alt),
              _navItem(3, 'assets/icons/wallet.svg',         'Malipo',   '/admin/payments',     3),
              _navItem(4, 'assets/icons/clipboard-list.svg', 'Maoni',    '/admin/feedback',     5),
            ]),
          ),
        ),
      ),
    );
  }

  // ── NAV ITEM — kama web MobileBottomNav (SVG icon, badge, underline indicator) ──
  Widget _navItem(int tabIdx, String? svgAsset, String label, String route, int pageIdx, {IconData? matIcon}) {
    final active = _tabIndex == tabIdx;
    final badge  = _routeCounts[route] ?? 0;
    final color  = active ? _kBlue : _kGrey500;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _selectPage(pageIdx, route);
        },
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            svgAsset != null
              ? SvgPicture.asset(svgAsset, width: 20, height: 20,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn))
              : Icon(matIcon ?? Icons.circle, size: 20, color: color),
            if (badge > 0)
              Positioned(
                top: -4, right: -6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _kRed),
                  child: Center(child: Text(badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
              ),
          ]),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 9, fontWeight: active ? FontWeight.w700 : FontWeight.w600, color: color)),
          if (active) ...[
            const SizedBox(height: 2),
            Container(width: 12, height: 2,
              decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(999))),
          ],
        ]),
      ),
    );
  }

  // ── HAMBURGER DROPDOWN — all 10 admin links (kama web) ──
  void _showHamburgerDropdown() {
    _closeMenu();
    final rb  = _hamburgerKey.currentContext!.findRenderObject() as RenderBox;
    final pos = rb.localToGlobal(Offset.zero);
    final sz  = rb.size;
    final counts = Map<String, int>.from(_routeCounts);

    _menuOverlay = OverlayEntry(builder: (_) => Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: _closeMenu, behavior: HitTestBehavior.opaque)),
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
              border: Border.all(color: _kGrey100),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dropLink('Admin',            null,                  0,  counts, active: _pageIndex == 0,  svg: 'assets/icons/crown.svg'),
              _dropLink('Watumiaji',        '/admin/users',        1,  counts, active: _pageIndex == 1,  svg: 'assets/icons/users.svg'),
              _dropLink('Waliopata Wenzao', null,                  10, counts, active: _pageIndex == 10, svg: 'assets/icons/git-merge.svg'),
              _dropLink('Match za Kweli',   '/admin/real-matches', 11, counts, active: _pageIndex == 11, icon: Icons.sync_alt),
              _dropLink('Data',             null,                  2,  counts, active: _pageIndex == 2,  icon: Icons.analytics_rounded),
              _dropLink('Matangazo',        null,                  6,  counts, active: _pageIndex == 6,  icon: Icons.notifications_active_rounded),
              _dropLink('Malipo',           '/admin/payments',     3,  counts, active: _pageIndex == 3,  svg: 'assets/icons/wallet.svg'),
              _dropLink('Waliopigiana',     null,                  4,  counts, active: _pageIndex == 4,  icon: Icons.phone_outlined),
              _dropLink('Maoni',            '/admin/feedback',     5,  counts, active: _pageIndex == 5,  svg: 'assets/icons/clipboard-list.svg'),
              _dropLink('Wasifu',           '/profile',            -1, counts, svg: 'assets/icons/user.svg'),
            ]),
          ),
        ),
      ),
    ]));
    Overlay.of(context).insert(_menuOverlay!);
  }

  Widget _dropLink(String label, String? badgeRoute, int targetPageIdx,
      Map<String, int> counts, {bool active = false, IconData? icon, String? svg}) {
    final badge = badgeRoute != null ? (counts[badgeRoute] ?? 0) : 0;
    final color = active ? _kBlue : _kGrey700;
    return GestureDetector(
      onTap: () {
        _closeMenu();
        if (targetPageIdx == -1) {
          Navigator.pushNamed(context, '/profile');
        } else {
          _selectPage(targetPageIdx, badgeRoute);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        color: active ? _kBlue.withValues(alpha: 0.06) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 20, height: 20,
            child: svg != null
                ? SvgPicture.asset(svg, width: 18, height: 18,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn))
                : Icon(icon ?? Icons.circle_outlined, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: color),
            overflow: TextOverflow.ellipsis)),
          if (badge > 0) Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _kRed),
            child: Center(child: Text(badge > 9 ? '9+' : '$badge',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
        ]),
      ),
    );
  }

  // ── PROFILE DROPDOWN — Avatar bofya → Profile / Logout ──
  void _showProfileDropdown() {
    _closeMenu();
    final rb      = _avatarKey.currentContext!.findRenderObject() as RenderBox;
    final pos     = rb.localToGlobal(Offset.zero);
    final sz      = rb.size;
    final screenW = MediaQuery.of(context).size.width;

    _menuOverlay = OverlayEntry(builder: (_) => Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: _closeMenu, behavior: HitTestBehavior.opaque)),
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
              border: Border.all(color: _kGrey100),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () { _closeMenu(); Navigator.pushNamed(context, '/profile'); },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(children: [
                    Icon(Icons.person_outline, size: 18, color: _kGrey700),
                    SizedBox(width: 12),
                    Text('Wasifu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kGrey700)),
                  ]),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _closeMenu();
                  context.read<AuthProvider>().logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(children: [
                    Icon(Icons.logout, size: 18, color: _kRed),
                    SizedBox(width: 12),
                    Text('Toka', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kRed)),
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
}

// ── LangToggle — SW/EN kama web LangToggle() ──
class _LangToggle extends StatefulWidget {
  const _LangToggle();
  @override
  State<_LangToggle> createState() => _LangToggleState();
}
class _LangToggleState extends State<_LangToggle> {
  String _lang = 'sw';
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn('SW', 'sw'),
        _btn('EN', 'en'),
      ]),
    );
  }

  Widget _btn(String text, String code) {
    final active = _lang == code;
    final isFirst = code == 'sw';
    return GestureDetector(
      onTap: () => setState(() => _lang = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(7) : Radius.zero,
            right: !isFirst ? const Radius.circular(7) : Radius.zero,
          ),
        ),
        child: Text(text, style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: active ? Colors.white : _kBlue,
        )),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
