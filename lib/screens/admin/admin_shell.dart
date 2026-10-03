import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/admin_badge_service.dart';
import '../../widgets/app_shell.dart' show LanguageProvider;
import '../../services/app_navigator.dart' show adminPageNotifier;
import '../../widgets/admin_top_bar.dart';
import '../../widgets/app_drawer.dart' show AppDrawer, NavItem;
import '../../widgets/app_toast.dart';
import '../../widgets/network_banner.dart';
import '../../widgets/queue_banner.dart';
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
import 'profile_page.dart';

const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);

// ─── Nav item descriptor ──────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final String label;
  final IconData icon;
  final Color tileFg;
  final Color tileBg;
  const _NavItem(this.index, this.label, this.icon, {
    this.tileFg = const Color(0xFF2A78D6),
    this.tileBg = const Color(0xFFD3E5FA),
  });
}

// ─── Master list of all nav items ────────────────────────────────────────────

const _allNavItems = <_NavItem>[
  // Icons za bottom nav: NavItem.xxx.icon — icons moja na drawer mpya
  // (takwimu/watumiaji/wenzao/malipo/maoni). Bottom nav yenyewe haibadilishwi.
  _NavItem(9,  'Statistics',          NavItem.takwimu.icon,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(1,  'Watumiaji',           NavItem.watumiaji.icon,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(2,  'Waliopata Wenzao',    NavItem.wenzao.icon,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(3,  'Match za Kweli',      TablerIcons.circleCheck,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(4,  'Data',                TablerIcons.database,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(5,  'Matangazo',           TablerIcons.speakerphone,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(6,  'Malipo',              NavItem.malipo.icon,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(7,  'Waliopigiana',        TablerIcons.phoneCall,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
  _NavItem(8,  'Maoni na Malalamiko', NavItem.maoni.icon,
                                      tileFg: Color(0xFF2A78D6), tileBg: Color(0xFFD3E5FA)),
];

// Bottom nav shows 5 key items (subset of drawer)
const _bottomNavIndices = [9, 1, 2, 6, 8];

// Mapping kati ya NavItem (AppDrawer) na int index (pages)
const _navItemToIndex = {
  NavItem.takwimu:      9,
  NavItem.watumiaji:    1,
  NavItem.wenzao:       2,
  NavItem.matchZaKweli: 3,
  NavItem.matangazo:    5,
  NavItem.waliopigiana: 7,
  NavItem.maoni:        8,
  NavItem.malipo:       6,
  NavItem.data:         4,
};

const _indexToNavItem = {
  9: NavItem.takwimu,
  1: NavItem.watumiaji,
  2: NavItem.wenzao,
  3: NavItem.matchZaKweli,
  5: NavItem.matangazo,
  7: NavItem.waliopigiana,
  8: NavItem.maoni,
  6: NavItem.malipo,
  4: NavItem.data,
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
  int? _lastClearedIdx; // Kufuatilia ukurasa uliofutwa badge — sio kila rebuild
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AdminBadgeService _badges = AdminBadgeService();

  @override
  void initState() {
    super.initState();
    _badges.start();
    LanguageProvider().addListener(_onLangChange);
    adminPageNotifier.addListener(_onFcmTap);
    // SECURITY (defense-in-depth): server inazuiya admin APIs kwa user wa
    // kawaida, lakini UI pia inalinda — user asiye admin aliyeanguka hapa
    // (deep link/navigesheni ya mkono) anarudishwa /login mara moja.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isAdmin) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  void _onLangChange() => setState(() {});

  void _onFcmTap() {
    final page = adminPageNotifier.value;
    if (page == null) return;
    adminPageNotifier.value = null; // consume
    _go(page);
  }

  @override
  void dispose() {
    _badges.stop();
    LanguageProvider().removeListener(_onLangChange);
    adminPageNotifier.removeListener(_onFcmTap);
    super.dispose();
  }

  /// Hesabu upya badges baada ya admin kufanya kitendo (approve/reject/reply).
  void refreshBadges() => _badges.refresh();

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
  }

  Future<void> _logout() async {
    if (Navigator.of(context).canPop()) Navigator.pop(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _LogoutDialog(),
    );
    if (ok != true) return;
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _openProfile() {
    if (Navigator.of(context).canPop()) Navigator.pop(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfilePage(
        profile: AdminProfile(
          fullName: user?.fullName ?? 'Admin',
          role: 'Administrator',
          phone: user?.phone ?? '',
          email: user?.email,
          whatsapp: (user?.phoneAlt ?? '').trim().isEmpty
              ? null
              : user!.phoneAlt,
        ),
        onSave: (fullName, whatsapp) async {
          try {
            await ApiService().updateProfile({
              'full_name': fullName,
              'phone_alt': whatsapp,
            });
            return null;
          } catch (e) {
            return e.toString();
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

    return NetworkToastListener(
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AdminTopBar(
        initials: initial,
        lang: LanguageProvider().lang,
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onLangChanged: (l) => LanguageProvider().setLang(l),
        onAvatarTap: null,
      ),
      // Drawer mpya (AppDrawer) — inasikiliza BadgeController yenyewe; namba
      // zinamwagika live kupitia bridge ya AdminBadgeService.notifyListeners.
      drawer: AppDrawer(
        logo: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('ES',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B8AB8))),
            ),
          ),
        ),
        userName: name,
        userRole: 'Msimamizi',
        current: _indexToNavItem[_idx] ?? NavItem.takwimu,
        onSelect: (item) {
          if (item == NavItem.wasifu) {
            _openProfile(); // Wasifu wangu — page inapushwa, siyo tab ya shell
            return;
          }
          _go(_navItemToIndex[item] ?? 9);
        },
        onLogout: _logout,
      ),
      body: ToastHost(child: Builder(builder: (ctx) {
        // Futa badge MARA MOJA ukurasa ukibadilika — siyo kila rebuild.
        // Kutofanya hivi kungesababisha badge kufutwa tena na tena kila
        // WS event ikija, ambayo inasababisha race condition na periodic poll.
        if (_idx != _lastClearedIdx) {
          _lastClearedIdx = _idx;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await _clearBadgeForPage(_idx);
            // Hakuna refreshBadges() hapa — kuitumia sasa kunaweza kubadilisha
            // badge kurudi (markSeen POST bado njiani). Poll ya sekunde 45
            // itapata count sahihi kutoka server.
          });
        }
        return Column(children: [
          const NetworkBanner(),
          const QueueBanner(),
          Expanded(child: widget.child ?? _pageFor(_idx)),
        ]);
      })),
      bottomNavigationBar: _buildBottomNav(),
    ),
    );
  }

  // ── Bottom Nav ──────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final bottomItems = _allNavItems.where((i) => _bottomNavIndices.contains(i.index)).toList();

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
          child: ListenableBuilder(
            listenable: _badges,
            builder: (context, _) => Row(
            children: bottomItems.map((item) {
              final active = _idx == item.index;
              final badgeCount = _badgeForIndex(item.index);
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
                      // Icon tile na badge juu-kulia
                      Stack(clipBehavior: Clip.none, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 40,
                          height: 36,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            size: 20,
                            color: fg,
                          ),
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            top: -7, right: -9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 3, offset: const Offset(0, 1)),
                                ],
                              ),
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              child: Center(
                                child: Text(
                                  badgeCount > 99 ? '99+' : '$badgeCount',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ]),
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
      ),
    );
  }

  int _badgeForIndex(int index) {
    switch (index) {
      case 1: return _badges.users;         // Watumiaji wapya
      case 2: return _badges.matches;       // Waliopata wenzao wapya
      case 3: return _badges.matches;       // Match za Kweli (same pool)
      case 6: return _badges.payments;      // Malipo yanasubiri
      case 7: return _badges.contacts;      // Waliopigiana wapya
      case 8: return _badges.feedback;      // Maoni yasiyojibiwa
      case 9: return _badges.announcements; // Matangazo
      default: return 0;
    }
  }

  Future<void> _clearBadgeForPage(int index) async {
    switch (index) {
      case 1: await _badges.clearUsers();         // Watumiaji — angalia tu
      case 2:
      case 3: await _badges.clearMatches();       // Wenzao / Match za Kweli — angalia tu
      case 7: await _badges.clearContacts();      // Waliopigiana — angalia tu
      case 9: await _badges.clearAnnouncements(); // Matangazo — angalia tu
      // Malipo (6): HAIISHI ukiangalia — inaisha baada ya approve/reject
      // Maoni (8): HAIISHI ukiangalia — inaisha baada ya kujibu
    }
  }
}

// ── Dialog ya kuthibitisha kutoka ─────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    const red    = Color(0xFFDC2626);
    const redBg  = Color(0xFFFEF2F2);
    const text   = Color(0xFF111111);
    const muted  = Color(0xFF6B7280);
    const border = Color(0xFFD1D5DB);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: redBg, borderRadius: BorderRadius.circular(12)),
              child: const Icon(TablerIcons.logout, size: 22, color: red),
            ),
            const SizedBox(height: 10),
            const Text('Toka kwenye akaunti?',
                style: TextStyle(
                    color: text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            const Text('Utahitaji kuingia tena',
                style: TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: text,
                      side: const BorderSide(color: border),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Hapana'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Toka'),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

