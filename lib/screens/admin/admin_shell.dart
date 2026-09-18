import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_shell.dart' show LanguageProvider;
import 'admin_dashboard_page.dart';
import 'admin_users_page.dart';
import 'admin_matches_page.dart';
import 'admin_real_matches_page.dart';
import 'admin_data_page.dart';
import 'admin_announcements_page.dart';
import 'admin_payments_page.dart';
import 'admin_contacts_page.dart';
import 'admin_feedback_page.dart';
import 'admin_reports_page.dart';
import 'admin_monitoring_page.dart';
import 'admin_password_resets_page.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

// ─── Nav item descriptor ──────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final String label;
  final IconData Function() icon;
  final IconData Function() iconFill;
  final Color? iconColor; // pink kwa Match za Kweli
  _NavItem(this.index, this.label, this.icon, this.iconFill, {this.iconColor});
}

// ─── Master list of all nav items ────────────────────────────────────────────

List<_NavItem> _allNavItems() => [
  _NavItem(9,  'Statistics',          () => PhosphorIcons.chartBar(),
                                      () => PhosphorIcons.chartBar(PhosphorIconsStyle.fill)),
  _NavItem(1,  'Watumiaji',           () => PhosphorIcons.usersThree(),
                                      () => PhosphorIcons.usersThree(PhosphorIconsStyle.fill)),
  _NavItem(2,  'Waliopata Wenzao',    () => PhosphorIcons.handshake(),
                                      () => PhosphorIcons.handshake(PhosphorIconsStyle.fill)),
  _NavItem(3,  'Match za Kweli',      () => PhosphorIcons.heart(),
                                      () => PhosphorIcons.heart(PhosphorIconsStyle.fill),
                                      iconColor: const Color(0xFFEC4899)),
  _NavItem(4,  'Data',                () => PhosphorIcons.database(),
                                      () => PhosphorIcons.database(PhosphorIconsStyle.fill)),
  _NavItem(5,  'Matangazo',           () => PhosphorIcons.megaphone(),
                                      () => PhosphorIcons.megaphone(PhosphorIconsStyle.fill)),
  _NavItem(6,  'Malipo',              () => PhosphorIcons.wallet(),
                                      () => PhosphorIcons.wallet(PhosphorIconsStyle.fill)),
  _NavItem(7,  'Waliopigiana',        () => PhosphorIcons.phoneCall(),
                                      () => PhosphorIcons.phoneCall(PhosphorIconsStyle.fill)),
  _NavItem(8,  'Maoni na Malalamiko', () => PhosphorIcons.chatCenteredText(),
                                      () => PhosphorIcons.chatCenteredText(PhosphorIconsStyle.fill)),
];

// Bottom nav shows 5 key items (subset of drawer)
const _bottomNavIndices = [9, 1, 2, 6, 8];

// ─── AdminShell ───────────────────────────────────────────────────────────────

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _idx = 9;
  int _userCount = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      final d = r.data as Map<String, dynamic>? ?? {};
      final totals = (d['totals'] as Map<String, dynamic>?) ?? {};
      setState(() => _userCount = (totals['users'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  Widget _pageFor(int i) {
    switch (i) {
      case 0:  return AdminDashboardPage(onNavigate: _go);
      case 1:  return const AdminUsersPage();
      case 2:  return const AdminMatchesPage();
      case 3:  return const AdminRealMatchesPage();
      case 4:  return const AdminDataPage();
      case 5:  return const AdminAnnouncementsPage();
      case 6:  return const AdminPaymentsPage();
      case 7:  return const AdminContactsPage();
      case 8:  return const AdminFeedbackPage();
      case 9:  return const AdminReportsPage();
      case 10: return const AdminMonitoringPage();
      case 11: return const AdminPasswordResetsPage();
      default: return const AdminDashboardPage();
    }
  }

  void _go(int i) {
    final nav = Navigator.of(context);
    final drawerOpen = _scaffoldKey.currentState?.isDrawerOpen ?? false;
    setState(() => _idx = i);
    if (drawerOpen && nav.canPop()) nav.pop();
    if (i == 1) _loadCount();
  }

  Future<void> _logout() async {
    if (Navigator.of(context).canPop()) Navigator.pop(context);
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth  = Provider.of<AuthProvider>(context, listen: false);
    final name  = auth.user?.fullName ?? 'Admin';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: _buildAppBar(initial),
      drawer: _buildDrawer(initial, name),
      body: _pageFor(_idx),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(String initial) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (ctx) => GestureDetector(
          onTap: () => Scaffold.of(ctx).openDrawer(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: _kGrey100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(PhosphorIcons.list(), color: _kGrey900, size: 20),
            ),
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => _showUserMenu(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(color: _kBlueBg, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.user(PhosphorIconsStyle.fill),
                  color: _kBlue, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: LanguageProvider(),
          builder: (context, _) {
            final sw = LanguageProvider().lang == 'sw';
            return GestureDetector(
              onTap: () => LanguageProvider().setLang(sw ? 'en' : 'sw'),
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _langChip('SW', sw),
                  _langChip('EN', !sw),
                ]),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _kGrey200, height: 1),
      ),
    );
  }

  Widget _langChip(String label, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700,
      color: active ? _kBlue : Colors.white,
    )),
  );

  // ── User popup menu ─────────────────────────────────────────────────────────

  void _showUserMenu(BuildContext context) {
    final RenderBox btn = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final nav = Navigator.of(context);
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        btn.localToGlobal(Offset.zero, ancestor: overlay),
        btn.localToGlobal(btn.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<String>(
      context: context,
      position: pos,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      items: [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(PhosphorIcons.user(), size: 18, color: _kGrey700),
            const SizedBox(width: 10),
            const Text('Wasifu', style: TextStyle(fontSize: 14, color: _kGrey900)),
          ]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(PhosphorIcons.signOut(), size: 18, color: _kRed),
            const SizedBox(width: 10),
            const Text('Toka',
                style: TextStyle(fontSize: 14, color: _kRed, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ).then((v) {
      if (!mounted) return;
      if (v == 'logout') _logout();
      if (v == 'profile') nav.pushNamed('/profile');
    });
  }

  // ── Drawer ──────────────────────────────────────────────────────────────────

  Widget _buildDrawer(String initial, String name) {
    final navItems = _allNavItems();
    return Drawer(
      backgroundColor: Colors.white,
      width: 285,
      child: SafeArea(
        child: Column(children: [
          // ── Header logo/title ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kBlueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.fill),
                    color: _kBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kubadilishana',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800, color: _kGrey900)),
                Text('Admin Panel',
                    style: GoogleFonts.inter(fontSize: 11, color: _kGrey500)),
              ]),
            ]),
          ),
          const Divider(height: 1, color: _kGrey200),
          const SizedBox(height: 6),

          // ── Nav items ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: navItems.map((item) {
                final badge = item.index == 1 && _userCount > 0
                    ? '$_userCount'
                    : null;
                return _DrawerRow(
                  item: item,
                  isActive: _idx == item.index,
                  badge: badge,
                  onTap: () => _go(item.index),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1, color: _kGrey200),

          // ── Profile footer ─────────────────────────────────────────────────
          _DrawerProfileTile(
            initial: initial,
            name: name,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile');
            },
          ),

          // ── Logout ─────────────────────────────────────────────────────────
          _DrawerLogoutTile(onTap: _logout),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  // ── Bottom Nav ──────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final all = _allNavItems();
    final bottomItems = all.where((i) => _bottomNavIndices.contains(i.index)).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kGrey200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: bottomItems.map((item) {
              final active = _idx == item.index;
              final color = active ? _kBlue : _kGrey500;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _go(item.index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.iconFill() : item.icon(),
                        size: 22,
                        color: item.iconColor != null && active
                            ? item.iconColor!
                            : color,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Shorten long labels for bottom nav
                        item.label == 'Maoni na Malalamiko'
                            ? 'Maoni'
                            : item.label == 'Waliopata Wenzao'
                                ? 'Wenzao'
                                : item.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (active) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 14, height: 2,
                          decoration: BoxDecoration(
                              color: _kBlue,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Drawer row widget ────────────────────────────────────────────────────────

class _DrawerRow extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;
  const _DrawerRow({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    // For "Match za Kweli" pink color regardless of active state
    final Color iColor = item.iconColor != null
        ? item.iconColor!
        : isActive
            ? _kBlue
            : _kGrey500;
    final Color iBg = isActive ? _kBlueBg : _kGrey100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive
            ? _kBlue.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Row(children: [
              // Active indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 26,
                decoration: BoxDecoration(
                  color: isActive ? _kBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),

              // Icon container
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive ? item.iconFill() : item.icon(),
                  size: 20, color: iColor,
                ),
              ),
              const SizedBox(width: 14),

              // Label
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? _kBlue : _kGrey900,
                  ),
                ),
              ),

              // Badge
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge!,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                const SizedBox(width: 4),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Drawer profile tile ──────────────────────────────────────────────────────

class _DrawerProfileTile extends StatelessWidget {
  final String initial;
  final String name;
  final VoidCallback onTap;
  const _DrawerProfileTile(
      {required this.initial, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _kBlue,
              child: Text(initial,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Wasifu wangu',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: _kGrey900)),
                Text(name,
                    style: GoogleFonts.inter(fontSize: 11, color: _kGrey500),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(PhosphorIcons.caretRight(), size: 16, color: _kGrey400),
          ]),
        ),
      ),
    );
  }
}

// ─── Drawer logout tile ───────────────────────────────────────────────────────

class _DrawerLogoutTile extends StatelessWidget {
  final VoidCallback onTap;
  const _DrawerLogoutTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Material(
        color: _kRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(PhosphorIcons.signOut(), size: 20, color: _kRed),
              const SizedBox(width: 12),
              Text('Toka',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: _kRed)),
            ]),
          ),
        ),
      ),
    );
  }
}
