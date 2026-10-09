import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_badge_service.dart';
import '../../widgets/app_shell.dart' show LanguageProvider;
import '../../services/app_navigator.dart' show adminPageNotifier;
import '../../widgets/admin_top_bar.dart';
import '../../widgets/app_drawer.dart' show AppDrawer, CountBadge, NavItem;
import '../../widgets/app_toast.dart';
import '../../widgets/network_banner.dart';
import '../../widgets/queue_banner.dart';
import 'admin_dashboard_page.dart';
import 'admin_users_v2_page.dart';
import 'admin_matches_page.dart';
import 'admin_real_matches_page.dart';
import 'admin_data_page.dart';
import 'matangazo_screen.dart';
import 'malipo_screen.dart';
import 'waliopigiana_page.dart';
import 'admin_feedback_page.dart';
import 'statistics_page.dart';
import 'admin_monitoring_page.dart';
import 'admin_password_resets_page.dart';
import 'profile_screen.dart';

// ─── Footer (bottom nav) — mockup ya admin_panel.dart ──────────────────────

// (index ya shell, jina fupi la footer, NavItem ya icon). Final (siyo const):
// NavItem.xxx.icon ni instance field ya enum — haiwezi kwenye const expression.
final _footerSpecs = <(int, String, NavItem)>[
  (9, 'Takwimu',   NavItem.takwimu),
  (1, 'Watumiaji', NavItem.watumiaji),
  (2, 'Wenzao',    NavItem.wenzao),
  (6, 'Malipo',    NavItem.malipo),
  (8, 'Maoni',     NavItem.maoni),
];

// ── DARK FOOTER (ThemeProvider.toggle) — inafuata ThemeMode ya Material app
const _kFooterBlue = Color(0xFF1E40AF); // active icon/label (light)
const _kFooterBlueTint = Color(0xFFEFF6FF); // active tile bg (light)
const _kFooterTileGray = Color(0xFFF3F4F6); // inactive tile bg (light)
const _kFooterMuted = Color(0xFF6B7280); // inactive icon/label (light)
const _kFooterBorder = Color(0xFFE5E7EB); // footer top border (light)
// ── DARK (ThemeProvider.toggle — inafuata ThemeMode ya MaterialApp) ──
const _kFooterBlueDark = Color(0xFF7AA7FF); // active icon/label
const _kFooterBlueTintDark = Color(0xFF1E293B); // active tile bg
const _kFooterTileGrayDark = Color(0xFF212833); // inactive tile bg
const _kFooterMutedDark = Color(0xFFA8B1C1); // inactive icon/label
const _kFooterBorderDark = Color(0xFF2A3240); // footer top border

class _FooterTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final int badgeCount;
  final VoidCallback onTap;
  const _FooterTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dark/Light: inafuata ThemeMode ya app — rangi za dark zinatumika wakati
    // brightness ni dark (ThemeProvider.toggle() inabadili MaterialApp).
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fgActive = dark ? _kFooterBlueDark : _kFooterBlue;
    final Color fgMuted = dark ? _kFooterMutedDark : _kFooterMuted;
    final Color tintActive = dark ? _kFooterBlueTintDark : _kFooterBlueTint;
    final Color tintMuted = dark ? _kFooterTileGrayDark : _kFooterTileGray;
    final Color fg = active ? fgActive : fgMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: active ? tintActive : tintMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: fg),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: CountBadge(count: badgeCount),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav index ↔ NavItem (AppDrawer) mapping ───────────────────────────────

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
      case 5:  return const AdminMatangazoPage();
      case 6:  return const AdminMalipoScreenPage();
      case 7:  return const WaliopigianaPage();
      case 8:  return const AdminFeedbackPage();
      case 9:  return const AdminStatisticsPage();
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const AdminProfileScreenPage(),
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
      // Dark/Light: inafuata ThemeMode ya app (ThemeProvider.toggle()).
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
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
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const Center(
              child: Text('ES',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B84A8))),
            ),
          ),
        ),
        userName: name,
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

  // ── Footer (bottom nav) — mockup ya admin_panel.dart ─────────────────────
  Widget _buildBottomNav() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF181D26) : Colors.white,
        border: Border(top: BorderSide(
            color: dark ? _kFooterBorderDark : _kFooterBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Row(
            children: [
              for (final (index, label, nav) in _footerSpecs)
                Expanded(
                  child: ListenableBuilder(
                    listenable: _badges,
                    builder: (context, _) => _FooterTile(
                      label: label,
                      icon: nav.icon,
                      active: _idx == index,
                      badgeCount: _badgeForIndex(index),
                      onTap: () => _go(index),
                    ),
                  ),
                ),
            ],
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

