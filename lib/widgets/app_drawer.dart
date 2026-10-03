// app_drawer.dart
// DRAWER ONLY (tile design) + red badges + hamburger dot.
// The bottom nav is NOT replaced: keep your existing bottom nav and only swap its
// icons with NavItem.xxx.icon (see example at the bottom of this file).
//
// Needs:  flutter_tabler_icons   (pubspec: flutter_tabler_icons: ^1.43.0)
// Flutter 3.10+ (ListenableBuilder).
// If a TablerIcons name does not exist in your version, change it ONLY in the
// NavItem enum below (icons live in one place).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

const Color kBrand = Color(0xFF1565C0);
const Color kBadgeRed = Color(0xFFE24B4A);

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

// ───────────────────────── 4. Drawer ─────────────────────────

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.logo, // YOUR existing logo widget, e.g. Image.asset('assets/logo.png')
    required this.userName,
    required this.userRole,
    required this.current,
    required this.onSelect,
    required this.onLogout,
    this.title = 'Kubadilishana',
    this.subtitle = 'Admin panel',
  });

  final Widget logo;
  final String userName;
  final String userRole;
  final NavItem current;
  final ValueChanged<NavItem> onSelect;
  final VoidCallback onLogout;
  final String title;
  final String subtitle;

  static const _order = [
    NavItem.takwimu, NavItem.watumiaji, NavItem.wenzao, NavItem.matchZaKweli,
    NavItem.matangazo, NavItem.waliopigiana, NavItem.maoni, NavItem.malipo,
    NavItem.data, NavItem.wasifu,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = math.min(MediaQuery.of(context).size.width * 0.84, 340.0);
    return Drawer(
      width: w,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header (logo + names + close) — same as the existing one
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: logo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(subtitle,
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: const Icon(TablerIcons.x, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile card
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: kBrand,
                            child: Text(
                              userName.isEmpty ? '?' : userName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(userRole,
                                    style: TextStyle(
                                        fontSize: 12, color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tiles (2 columns, short height)
                    ListenableBuilder(
                      listenable: BadgeController.instance,
                      builder: (context, _) => GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        itemCount: _order.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          mainAxisExtent: 72,
                        ),
                        itemBuilder: (context, i) {
                          final item = _order[i];
                          return _DrawerTile(
                            item: item,
                            selected: item == current,
                            count: BadgeController.instance.count(item),
                            onTap: () {
                              Navigator.of(context).pop();
                              onSelect(item);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(TablerIcons.power, size: 18),
                  label: const Text('Toka'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withOpacity(.5), width: .5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile(
      {required this.item, required this.selected, required this.count, required this.onTap});
  final NavItem item;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kBrand : cs.outlineVariant,
            width: selected ? 1.5 : .5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: item.accent.withOpacity(.13),
                  child: Icon(item.icon, size: 17, color: item.accent),
                ),
                Positioned(top: -7, right: -9, child: BadgeBubble(count: count)),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
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
        userRole: 'Msimamizi',
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

// Bottom nav (yours stays): only use these icons, same ones as the drawer:
//   Takwimu   -> NavItem.takwimu.icon
//   Watumiaji -> NavItem.watumiaji.icon
//   Malipo    -> NavItem.malipo.icon
//   Maoni     -> NavItem.maoni.icon
// Optional badge on top of an icon (wrap your icon in a Stack with clipBehavior: Clip.none):
//   Positioned(top: -5, right: -6,
//     child: ListenableBuilder(
//       listenable: BadgeController.instance,
//       builder: (_, __) => BadgeBubble(count: BadgeController.instance.count(NavItem.malipo)),
//     ))
