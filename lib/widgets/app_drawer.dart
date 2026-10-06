// app_drawer.dart
// DRAWER (mockup ya admin_panel.dart — rows + left-border active + badge nyekundu)
// + BadgeController (namba halisi za backend) + MenuButtonWithDot (hamburger).
// Bottom nav (footer) iko kwenye admin_shell.dart — inafuata mockup ileile.
//
// Needs:  flutter_tabler_icons   (pubspec: flutter_tabler_icons: ^1.43.0)
// Flutter 3.10+ (ListenableBuilder).
// If a TablerIcons name does not exist in your version, change it ONLY in the
// NavItem enum below (icons live in one place).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

const Color kBrand = Color(0xFF1565C0);

// Rangi za mockup (admin_panel.dart — AppColors)
const Color kBlue = Color(0xFF2F6FBF); // active icon/label
const Color kBlueTint = Color(0xFFEAF1FA); // active row/tile bg
const Color kText = Color(0xFF3A3F4B); // row icon/label (inactive)
const Color kTextStrong = Color(0xFF111111); // active label / titles
const Color kMuted = Color(0xFF6B7280); // subtitle / chevron
const Color kBorder = Color(0xFFE5E7EB); // dividers / footer top border
const Color kTileGray = Color(0xFFF3F4F6); // inactive footer tile
const Color kRed = Color(0xFFB3261E); // Toka
const Color kBadgeRed = Color(0xFFE53935); // badge za namba
const Color kFieldBorder = Color(0xFFD1D5DB); // close button border
const Color kLogoBorder = Color(0xFFA9BAD6); // logo box border

// ───────────────────────── 1. Menu items ─────────────────────────

/// none          -> never shows a badge (Takwimu, Matangazo, Data, Wasifu)
/// clearOnOpen   -> badge = "new/unseen". Disappears as soon as the page opens.
/// clearOnAction -> badge = "pending work". Disappears ONLY after the user does
///                  the action (Malipo: confirm/reject, Maoni: reply).
///                  Opening the page does NOT clear it.
enum BadgeRule { none, clearOnOpen, clearOnAction }

enum NavItem {
  takwimu('Takwimu', 'Takwimu', TablerIcons.chart_pie, Color(0xFF1565C0), BadgeRule.none, true),
  watumiaji('Watumiaji', 'Watumiaji', TablerIcons.users_group, Color(0xFF00897B), BadgeRule.clearOnOpen, true),
  wenzao('Waliopata wenzao', 'Wenzao', TablerIcons.hearts, Color(0xFF7E57C2), BadgeRule.clearOnOpen, false),
  matchZaKweli('Match za kweli', 'Match', TablerIcons.flame, Color(0xFFE64A19), BadgeRule.clearOnOpen, false),
  matangazo('Matangazo', 'Matangazo', TablerIcons.bell_ringing, Color(0xFFD81B60), BadgeRule.none, false),
  waliopigiana('Waliopigiana', 'Waliopigiana', TablerIcons.phone, Color(0xFFF9A825), BadgeRule.clearOnOpen, false),
  maoni('Maoni na malalamiko', 'Maoni', TablerIcons.message_2, Color(0xFF558B2F), BadgeRule.clearOnAction, true),
  malipo('Malipo', 'Malipo', TablerIcons.coin, Color(0xFF1565C0), BadgeRule.clearOnAction, true),
  data('Data', 'Data', TablerIcons.server, Color(0xFF00897B), BadgeRule.none, false),
  wasifu('Wasifu wangu', 'Wasifu', TablerIcons.id_badge_2, Color(0xFF757575), BadgeRule.none, false);

  const NavItem(this.label, this.shortLabel, this.icon, this.accent, this.badgeRule, this.inBottomNav);
  final String label; // used in drawer
  final String shortLabel; // used in bottom nav / app bar
  final IconData icon;
  final Color accent;
  final BadgeRule badgeRule;
  final bool inBottomNav;
}

// ───────────────────────── 2. Badge state ─────────────────────────

class BadgeController extends ChangeNotifier {
  BadgeController._();
  static final BadgeController instance = BadgeController._();

  final Map<NavItem, int> _counts = {};

  /// Optional: tell your backend the page was seen (for clearOnOpen items).
  Future<void> Function(NavItem item)? onMarkSeen;

  int count(NavItem i) => i.badgeRule == BadgeRule.none ? 0 : (_counts[i] ?? 0);

  /// Dot on the hamburger: true if any item that is NOT in the bottom bar has a badge.
  bool get hasHiddenBadge =>
      NavItem.values.any((i) => !i.inBottomNav && count(i) > 0);

  /// Call with fresh numbers from your API / push / websocket / polling.
  void setCounts(Map<NavItem, int> counts) {
    _counts
      ..clear()
      ..addAll(counts);
    notifyListeners();
  }

  void setCount(NavItem i, int n) {
    _counts[i] = math.max(0, n);
    notifyListeners();
  }

  /// Call after the user finishes ONE action (confirm payment, reply to feedback...).
  void decrement(NavItem i, [int by = 1]) => setCount(i, (_counts[i] ?? 0) - by);

  /// Call when the page is opened. Only clears clearOnOpen items.
  void markSeen(NavItem i) {
    if (i.badgeRule != BadgeRule.clearOnOpen) return;
    if ((_counts[i] ?? 0) == 0) return;
    _counts[i] = 0;
    notifyListeners();
    onMarkSeen?.call(i);
  }
}

// ───────────────────────── 3. Badge widgets ─────────────────────────

/// Badge nyekundu ya mockup (admin_panel.dart — CountBadge):
///   footer  -> height 20, fontSize 11, borderWidth 2 (mpaka mweupe)
///   drawer  -> height 22, fontSize 12, borderWidth 0
class CountBadge extends StatelessWidget {
  final int count;
  final double height;
  final double fontSize;
  final double borderWidth; // mpaka mweupe (footer = 2, drawer = 0)

  const CountBadge({
    super.key,
    required this.count,
    this.height = 20,
    this.fontSize = 11,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: BoxConstraints(minWidth: height),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBadgeRed,
        borderRadius: BorderRadius.circular(height / 2),
        border: borderWidth > 0
            ? Border.all(color: Colors.white, width: borderWidth)
            : null,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}

class BadgeBubble extends StatelessWidget {
  const BadgeBubble({super.key, required this.count, this.ringColor});
  final int count;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final ring = ringColor ?? Theme.of(context).colorScheme.surface;
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kBadgeRed,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ring, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, height: 1),
      ),
    );
  }
}

/// Hamburger button: shows ONLY a red dot (no number).
class MenuButtonWithDot extends StatelessWidget {
  const MenuButtonWithDot({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    return ListenableBuilder(
      listenable: BadgeController.instance,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          IconButton(icon: const Icon(TablerIcons.menu_2), onPressed: onPressed),
          if (BadgeController.instance.hasHiddenBadge)
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: kBadgeRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: bg, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── 4. Drawer (mockup) ─────────────────────────

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.logo, // YOUR existing logo widget, e.g. Image.asset('assets/logo.png')
    required this.userName,
    required this.current,
    required this.onSelect,
    required this.onLogout,
    this.title = 'Kubadilishana',
    this.subtitle = 'Admin panel',
  });

  final Widget logo;
  final String userName;
  final NavItem current;
  final ValueChanged<NavItem> onSelect;
  final VoidCallback onLogout;
  final String title;
  final String subtitle;

  // Mpangilio wa mockup: Takwimu, Watumiaji, Wenzao, Match, Matangazo,
  // Waliopigiana, Maoni, Malipo, Data. (Wasifu iko chini — profile row.)
  static const _order = [
    NavItem.takwimu, NavItem.watumiaji, NavItem.wenzao, NavItem.matchZaKweli,
    NavItem.matangazo, NavItem.waliopigiana, NavItem.maoni, NavItem.malipo,
    NavItem.data,
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _DrawerHeader(
                logo: logo,
                title: title,
                subtitle: subtitle,
                onClose: () => Navigator.of(context).pop(),
              ),
              const Divider(height: 1, thickness: 0.5, color: kBorder),
              const SizedBox(height: 10),
              // Rows — zina-scroll ikitosha screen (mockup: Spacer; screen
              // ndogo huwa na rows 9 + header, tunazunganisha scroll).
              Expanded(
                child: ListenableBuilder(
                  listenable: BadgeController.instance,
                  builder: (context, _) => SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final item in _order)
                          _DrawerRow(
                            item: item,
                            active: item == current,
                            count: BadgeController.instance.count(item),
                            onTap: () {
                              Navigator.of(context).pop();
                              onSelect(item);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 0.5, color: kBorder),
              _ProfileRow(
                name: userName,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(NavItem.wasifu);
                },
              ),
              _LogoutRow(onTap: onLogout),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final Widget logo;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DrawerHeader({
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: kLogoBorder, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: logo,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: kTextStrong,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: kMuted),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: kFieldBorder, width: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(TablerIcons.x, size: 18, color: kTextStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  final NavItem item;
  final bool active;
  final int count;
  final VoidCallback onTap;
  const _DrawerRow({
    required this.item,
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? kBlueTint : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: active ? kBlue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 22,
              color: active ? kBlue : kText,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  color: active ? kTextStrong : kText,
                ),
              ),
            ),
            if (count > 0)
              CountBadge(
                count: count,
                height: 22,
                fontSize: 12,
                borderWidth: 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _ProfileRow({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              const Icon(TablerIcons.user_circle, size: 22, color: kText),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wasifu wangu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: kTextStrong,
                      ),
                    ),
                    Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.3,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(TablerIcons.chevron_right, size: 18, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: const Row(
            children: [
              Icon(TablerIcons.logout, size: 22, color: kRed),
              SizedBox(width: 14),
              Text(
                'Toka',
                style: TextStyle(fontSize: 15, color: kRed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 5. Example wiring ─────────────────────────

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  NavItem _current = NavItem.takwimu;

  @override
  void initState() {
    super.initState();
    // Demo numbers. Replace with your API / push / websocket data.
    BadgeController.instance.setCounts({
      NavItem.watumiaji: 12,
      NavItem.wenzao: 3,
      NavItem.matchZaKweli: 2,
      NavItem.waliopigiana: 7,
      NavItem.malipo: 124, // shows 99+
      NavItem.maoni: 5,
    });
    // Optional: tell the server a page was seen
    // BadgeController.instance.onMarkSeen = (item) async { await api.markSeen(item.name); };
  }

  void _select(NavItem item) {
    setState(() => _current = item);
    // Page opened -> clears ONLY clearOnOpen items.
    // Malipo & Maoni are NOT cleared here.
    BadgeController.instance.markSeen(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) =>
              MenuButtonWithDot(onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        title: Text(_current.shortLabel),
      ),
      drawer: AppDrawer(
        logo: const Center(child: Text('ES')), // <- put YOUR existing logo widget here
        userName: 'Hamisi Selemani',
        current: _current,
        onSelect: _select,
        onLogout: () {/* your logout */},
      ),
      body: Center(child: Text(_current.label)), // <- your pages
      // bottomNavigationBar: keep YOUR existing bottom nav (see notes below).
    );
  }
}

// Inside the Malipo page, AFTER the admin confirms/rejects ONE payment:
//   BadgeController.instance.decrement(NavItem.malipo);
// Inside the Maoni page, AFTER the admin replies to ONE complaint:
//   BadgeController.instance.decrement(NavItem.maoni);
// Or simply refetch counts from the server and call setCounts(...).
