import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_shell.dart' show LanguageProvider;
import '../../widgets/admin_top_bar.dart';
import '../../widgets/admin_drawer.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_v2_page.dart';
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
import 'admin_profile_screen.dart';
import '../../utils/safe_cast.dart';

const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);

// ─── Nav item descriptor ──────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final String label;
  final IconData Function() icon;
  final IconData Function() iconFill;
  /// Rangi za tile (drawer-style icon) — fg na bg
  final Color tileFg;
  final Color tileBg;
  _NavItem(this.index, this.label, this.icon, this.iconFill, {
    this.tileFg = const Color(0xFF2A78D6),
    this.tileBg = const Color(0xFFD3E5FA),
  });
}

// ─── Master list of all nav items ────────────────────────────────────────────

List<_NavItem> _allNavItems() => [
  _NavItem(9,  'Statistics',          () => PhosphorIcons.chartBar(),
                                      () => PhosphorIcons.chartBar(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF2A78D6), tileBg: const Color(0xFFD3E5FA)),
  _NavItem(1,  'Watumiaji',           () => PhosphorIcons.usersThree(),
                                      () => PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF2A78D6), tileBg: const Color(0xFFD3E5FA)),
  _NavItem(2,  'Waliopata Wenzao',    () => PhosphorIcons.handshake(),
                                      () => PhosphorIcons.handshake(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF1E6B1E), tileBg: const Color(0xFFCDEBCB)),
  _NavItem(3,  'Match za Kweli',      () => PhosphorIcons.heart(),
                                      () => PhosphorIcons.heart(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF8E2A2A), tileBg: const Color(0xFFF8D7D7)),
  _NavItem(4,  'Data',                () => PhosphorIcons.database(),
                                      () => PhosphorIcons.database(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF3C3C3A), tileBg: const Color(0xFFEFEFEC)),
  _NavItem(5,  'Matangazo',           () => PhosphorIcons.megaphone(),
                                      () => PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF7A4A00), tileBg: const Color(0xFFF9DDA4)),
  _NavItem(6,  'Malipo',              () => PhosphorIcons.wallet(),
                                      () => PhosphorIcons.wallet(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF1E6B1E), tileBg: const Color(0xFFCDEBCB)),
  _NavItem(7,  'Waliopigiana',        () => PhosphorIcons.phoneCall(),
                                      () => PhosphorIcons.phoneCall(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF1E6B1E), tileBg: const Color(0xFFCDEBCB)),
  _NavItem(8,  'Maoni na Malalamiko', () => PhosphorIcons.chatCenteredText(),
                                      () => PhosphorIcons.chatCenteredText(PhosphorIconsStyle.fill),
                                      tileFg: const Color(0xFF7A4A00), tileBg: const Color(0xFFF9DDA4)),
];

// Bottom nav shows 5 key items (subset of drawer)
const _bottomNavIndices = [9, 1, 2, 6, 8];

// Mapping kati ya string key (AdminDrawer) na int index (pages)
const _keyToIndex = {
  'takwimu': 9,
  'watumiaji': 1,
  'wenzao': 2,
  'match': 3,
  'matangazo': 5,
  'simu': 7,
  'maoni': 8,
  'malipo': 6,
  'data': 4,
};

const _indexToKey = {
  9: 'takwimu',
  1: 'watumiaji',
  2: 'wenzao',
  3: 'match',
  5: 'matangazo',
  7: 'simu',
  8: 'maoni',
  6: 'malipo',
  4: 'data',
};

// ─── AdminShell ───────────────────────────────────────────────────────────────

class AdminShell extends StatefulWidget {
  /// Hiari: badilisha body ya shell (inatumika kwenye tests za responsive).
  /// Kama hutajapewa, shell inaonyesha ukurasa wa nav uliochaguliwa.
  final Widget? child;
  const AdminShell({super.key, this.child});
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
    LanguageProvider().addListener(_onLangChange);
  }

  void _onLangChange() => setState(() {});

  @override
  void dispose() {
    LanguageProvider().removeListener(_onLangChange);
    super.dispose();
  }

  Future<void> _loadCount() async {
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      final d = asMap(r.data);
      final totals = asMap(d['totals']);
      setState(() => _userCount = (totals['users'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  Widget _pageFor(int i) {
    switch (i) {
      case 0:  return AdminDashboardPage(onNavigate: _go);
      case 1:  return const AdminUsersV2Page();
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

  void _openProfile() {
    if (Navigator.of(context).canPop()) Navigator.pop(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminProfileScreen(
        profile: AdminProfile(
          name: user?.fullName ?? 'Admin',
          email: user?.email ?? '',
          emailVerified: true,
          phone: user?.phone ?? '',
          whatsapp: (user?.phoneAlt ?? '').trim().isEmpty
              ? null
              : user!.phoneAlt,
        ),
        onSave: (updated) async {
          try {
            await ApiService().updateProfile({
              'full_name': updated.name,
              // phone_alt huhifadhiwa kama '255XXXXXXXXX' (au null kufuta).
              'phone_alt': updated.whatsapp,
            });
            return true;
          } catch (_) {
            return false;
          }
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth  = Provider.of<AuthProvider>(context, listen: false);
    final name  = auth.user?.fullName ?? 'Admin';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AdminTopBar(
        initials: initial,
        lang: LanguageProvider().lang,
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onLangChanged: (l) => LanguageProvider().setLang(l),
        onAvatarTap: null,
      ),
      drawer: AdminDrawer(
        activeKey: _indexToKey[_idx] ?? 'takwimu',
        usersCount: _userCount > 0 ? _userCount : null,
        adminName: name,
        initials: initial,
        onSelect: (key) => _go(_keyToIndex[key] ?? 9),
        onProfile: _openProfile,
        onLogout: _logout,
      ),
      body: widget.child ?? _pageFor(_idx),
      bottomNavigationBar: _buildBottomNav(),
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
          height: 68,
          child: Row(
            children: bottomItems.map((item) {
              final active = _idx == item.index;
              // Tile colors: colored when active, grey when inactive
              final fg = active ? item.tileFg : _kGrey500;
              final bg = active ? item.tileBg : _kGrey200;
              final labelColor = active ? item.tileFg : _kGrey500;

              final label = item.label == 'Maoni na Malalamiko'
                  ? 'Maoni'
                  : item.label == 'Waliopata Wenzao'
                      ? 'Wenzao'
                      : item.label;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _go(item.index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tile ya drawer-style
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        height: 36,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          active ? item.iconFill() : item.icon(),
                          size: 20,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.0,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: labelColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
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

