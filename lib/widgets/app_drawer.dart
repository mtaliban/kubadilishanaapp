// app_drawer.dart
// DRAWER — DESIGN MPYA (safu mbili ya kubadilishana:
//  ink #243049 + kAc #1F5FD6 + radius 24 + ripple kPress/kRedSoft + badge pill)
// + BadgeController (namba halisi za backend) + MenuButtonWithDot (hamburger).
// Bottom nav (footer) iko kwenye admin_shell.dart — inafuata mockup ileile.
//
// KUHUSU DESIGN MPYA (code ya kubadilishana):
//   radius ya kona ya kulia 24, group labels (Kuu/Mawasiliano/Mfumo) kijivu,
//   rows: bluu #1F5FD6 ikiwa hai, kSoft background, kubonyeza ripple kPress;
//   Toka: kRed + kRedSoft ripple; badge: pill nyekundu 22px.
//   Dark mode: inabaki (panel #1E293B).
//
// Needs:  flutter_tabler_icons   (pubspec: flutter_tabler_icons: ^1.43.0)
// Flutter 3.10+ (ListenableBuilder).
// If a TablerIcons name does not exist in your version, change it ONLY in the
// NavItem enum below (icons live in one place).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

const Color kBrand = Color(0xFF1565C0);

// ── RANGI ZA DESIGN MPYA (kInk / kAc / kLine / kSoft / kPress / kRed) ─────────
// Dark mode zinabadilishwa kupitia helpers kwenye chini; kama unataka proje
//  ya kubadilishwa (zote ni app-wide) tuna-kubali hapa (dark hakuna kubadilika).
const Color kBlue = Color(0xFF1F5FD6); // active icon/label (= kAc ya design mpya)
const Color kBlueTint = Color(0xFFE8EFFC); // active row/tile bg (= kSoft)
const Color kBlueBorder = Color(0xFFBFDBFE); // border ya logo/avatar
const Color kText = Color(0xFF243049); // row icon/label (inactive = kInk)
const Color kTextStrong = Color(0xFF243049); // active label / titles (= kInk)
const Color kMuted = Color(0xFF7A8496); // chevron / group labels (= kMut)
const Color kTextSecondary = Color(0xFF7A8496); // subtitle / footer inactive
const Color kBorder = Color(0xFFE3E7EE); // dividers / footer top border (= kLine)
const Color kTileGray = Color(0xFFF3F4F6); // inactive footer tile / group band
const Color kRed = Color(0xFFD92D20); // Toka + badge (kRed ya design)
const Color kBadgeRed = Color(0xFFD92D20); // badge za namba
const Color kFieldBorder = Color(0xFFE3E7EE); // close button border
// Ripple colors (design mpya):
const Color kPress = Color(0xFFD6E3FB); // active ripple
const Color kRedSoft = Color(0xFFFEF3F2); // danger ripple (Toka)

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
  wenzao('Waliopata wenzao', 'Wenzao', TablerIcons.link, Color(0xFF7E57C2), BadgeRule.clearOnOpen, false),
  matchZaKweli('Match za kweli', 'Match', TablerIcons.bolt, Color(0xFFE64A19), BadgeRule.clearOnOpen, false),
  matangazo('Matangazo', 'Matangazo', TablerIcons.speakerphone, Color(0xFFD81B60), BadgeRule.none, false),
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

  // Vikundi vya design mpya: Kuu / Mawasiliano / Mfumo (title-case).
  static const _groups = {
    NavItem.takwimu: 'Kuu',
    NavItem.matangazo: 'Mawasiliano',
    NavItem.malipo: 'Mfumo',
  };


  List<Widget> _drawerRows(BuildContext context) {
    final rows = <Widget>[];
    for (final item in _order) {
      final group = _groups[item];
      if (group != null) rows.add(_GroupLabel(group));
      rows.add(_DrawerRow(
        item: item,
        active: item == current,
        count: BadgeController.instance.count(item),
        onTap: () {
          Navigator.of(context).pop();
          onSelect(item);
        },
      ));
    }
    return rows;
  }

  // Urefu wa body ya footer (bottom nav): padding (4,10,4,8) + tile 44 +
  // gap 4 + label ≈ 80. SystemInset ya chini inajumlishwa runtime.
  static const double kFooterBody = 80;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).padding;
    return Drawer(
      // Drawer IFUNIKE hamburger: juu ya panel = KILELE CHA hamburger,
      // halafu inashuka HADI JUU YA FOOTER (gap ndogo tu — design mpya).
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.only(
          // Namba hasi inaruhusiwa kuwa 0 (simu isiyo na status inset) —
          // shifted_box assertion ya Flutter inakataza isNonNegative.
          top: math.max(0.0, insets.top - 4),
          // PANEL ISHE MOJA KWA MOJA JUU YA FOOTER (mizio ya geometry halisi:
          // footer = SafeArea-chini + Padding(4,10,4,8) + tile 44 + gap 4 +
          // label ≈ 80 + insets.bottom). Kuipunguza kunafunika footer — Toka
          // haionyeshwi vizuri chini ya panel. (Imepimwa kwenye 390×844/inset 40.)
          bottom: kFooterBody + insets.bottom,
        ),
        // Column moja halisi (height inasimamiwa): Spacer inaingia nafasi
        // ya pungufu bila kusinyoosha rows — rows zina ukubwa ule ulikuwa nao,
        // Wasifu + Toka zibandikwe chini ofu (kabla ya footer).
        child: Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white, // dark: giza, light: nyeupe (kama awali)
          // DESIGN MPYA: radius ya kona za kulia 24 (kama design yako)
          borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _drawerChildren(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _drawerChildren(BuildContext context) {
    return [
      _DrawerHeader(
        logo: logo,
        title: title,
        subtitle: subtitle,
        onClose: () => Navigator.of(context).pop(),
      ),
      const Divider(height: 1, thickness: 0.5, color: kBorder),
      ListenableBuilder(
        listenable: BadgeController.instance,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: _drawerRows(context),
        ),
      ),
      const Divider(height: 1, thickness: 0.5, color: kBorder),
      // Nafasi iliyoongezwa (Spacer): rows za menu hazinyooshwi — Wasifu
      // wangu + Toka zibandikwe CHINI ya drawer, panel ifikishe footer.
      const Spacer(),
      _ProfileRow(
        name: userName,
        onTap: () {
          Navigator.of(context).pop();
          onSelect(NavItem.wasifu);
        },
      ),
      _LogoutRow(onTap: onLogout),
    ];
  }
}

// ─── Kichwa cha kikundi (KUU / MAWASILIANO / MFUMO) ──────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    // Design mpya: group label ni maandishi tupu kijivu 12 (bila band ya
    // kijivu nyuma) — "Kuu", "Mawasiliano", "Mfumo" kama design yako.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: kMuted)),
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
    // Design mpya: logo duara 44 (radius 12, kSoft, hakuna border),
    // title 17 w600, subtitle 12 kijivu, X button 34x34.
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kBlueTint,
              borderRadius: BorderRadius.circular(12),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: kTextStrong,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kMuted),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                border: Border.all(color: kFieldBorder),
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

  // ─── Row padding ndogo (urefu wa row uwe ~nusu ya ulivyo) ─────────
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Design mpya: active row = kSoft (#E8EFFC) + left-border bluu 4;
    // ripple kPress (kRedSoft kwa Toka); label 15 w600 active; badge pill 22.
    final Color fg = active ? kBlue : kText;
    return Ink(
      decoration: BoxDecoration(
        color: active
            ? kBlueTint
            : (dark ? const Color(0xFF1E293B) : Colors.transparent),
        border: Border(
          left: BorderSide(
            color: active ? kBlue : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: kPress,
        highlightColor: kPress,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Icon(item.icon, size: 22, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: fg,
                  ),
                ),
              ),
              if (count > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: CountBadge(count: count, height: 22, fontSize: 12, borderWidth: 0),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 18),
                  child: Icon(TablerIcons.chevron_right,
                      size: 16, color: kMuted),
                ),
            ],
          ),
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
    final initial =
        name.trim().isEmpty ? 'A' : name.trim()[0].toUpperCase();
    // Design mpya: footer ya Wasifu wangu — duara 38 'H' + label 14 w600
    // + subtitle 11 kijivu + chevron; height 60, border-top.
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kBorder))),
      child: InkWell(
        onTap: onTap,
        splashColor: kPress,
        highlightColor: kPress,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: kBlueTint,
                    shape: BoxShape.circle,
                  ),
                  child: Text(initial,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600, color: kBlue)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wasifu wangu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextStrong,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(TablerIcons.chevron_right,
                    size: 20, color: kMuted),
              ],
            ),
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
    // Design mpya: Toka — nyekundu + ripple kRedSoft, height 44, icon 20.
    return Ink(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.transparent))),
      child: InkWell(
        onTap: onTap,
        splashColor: kRedSoft,
        highlightColor: kRedSoft,
        child: const SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(TablerIcons.logout, size: 20, color: kRed),
                SizedBox(width: 14),
                Text(
                  'Toka',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kRed),
                ),
              ],
            ),
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
