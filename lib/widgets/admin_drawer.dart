// =====================================================================
//  MENYU YA PEMBENI YA ADMIN (Drawer) — Kubadilishana
//  Icon iliyochaguliwa inakuwa BLUU tu — hakuna mandhari/mstari nyuma.
//  Kichwa kinakaa JUU kila wakati; orodha inapita chini yake.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

// ---- Rangi -------------------------------------------------------
class _D {
  static const blue       = Color(0xFF2878D6);
  static const text       = Color(0xFF111111);
  static const item       = Color(0xFF3D4150);
  static const icon       = Color(0xFF5A6072);
  static const section    = Color(0xFF8A8A8A);
  static const line       = Color(0xFFEFEFEF);
  static const border     = Color(0xFFE6E6E6);
  static const danger     = Color(0xFFB91C1C);
  static const badge      = Color(0xFFDC2626);
}

const String kDrawerLogoAsset = 'assets/images/app_icon.png';
const double kDrawerLogoSize  = 48;

// ---- Enum ya kurasa -----------------------------------------------
enum AdminPage {
  takwimu,
  watumiaji,
  wenzao,
  match,
  matangazo,
  waliopigiana,
  maoni,
  malipo,
  data,
}

// ---- Muundo wa orodha --------------------------------------------
class _Item {
  final AdminPage page;
  final IconData  icon;
  final String    label;
  const _Item(this.page, this.icon, this.label);
}

class _Section {
  final String       title;
  final List<_Item>  items;
  const _Section(this.title, this.items);
}

const _sections = <_Section>[
  _Section('KUU', [
    _Item(AdminPage.takwimu,     TablerIcons.layoutDashboard, 'Takwimu'),
    _Item(AdminPage.watumiaji,   TablerIcons.usersGroup,      'Watumiaji'),
    _Item(AdminPage.wenzao,      TablerIcons.replace,         'Waliopata wenzao'),
    _Item(AdminPage.match,       TablerIcons.circleCheck,     'Match za kweli'),
  ]),
  _Section('MAWASILIANO', [
    _Item(AdminPage.matangazo,   TablerIcons.speakerphone,    'Matangazo'),
    _Item(AdminPage.waliopigiana,TablerIcons.phoneCall,       'Waliopigiana'),
    _Item(AdminPage.maoni,       TablerIcons.message2,        'Maoni na malalamiko'),
  ]),
  _Section('FEDHA NA DATA', [
    _Item(AdminPage.malipo,      TablerIcons.wallet,          'Malipo'),
    _Item(AdminPage.data,        TablerIcons.database,        'Data'),
  ]),
];

// =====================================================================
// AdminDrawer — widget kuu
// =====================================================================
class AdminDrawer extends StatelessWidget {
  final AdminPage selected;
  final void Function(AdminPage page) onSelect;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final String adminName;
  final Map<AdminPage, int> counts;

  const AdminDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onProfile,
    required this.onLogout,
    required this.adminName,
    this.counts = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      surfaceTintColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Kichwa — kinakaa juu, hakifunikwi
            _Header(onClose: () => Navigator.of(context).pop()),

            // Orodha — inasogea chini ya kichwa
            Expanded(
              child: ClipRect(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final s in _sections) ...[
                      _SectionTitle(s.title),
                      for (final it in s.items)
                        _Tile(
                          icon:     it.icon,
                          label:    it.label,
                          selected: it.page == selected,
                          count:    counts[it.page] ?? 0,
                          onTap: () {
                            Navigator.of(context).pop();
                            onSelect(it.page);
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // Chini — Wasifu + Toka
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _D.line)),
              ),
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Column(children: [
                _ProfileTile(
                  name: adminName,
                  onTap: () {
                    Navigator.of(context).pop();
                    onProfile();
                  },
                ),
                _Tile(
                  icon:     TablerIcons.logout,
                  label:    'Toka',
                  selected: false,
                  color:    _D.danger,
                  onTap:    onLogout,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Kichwa -------------------------------------------------------
class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : _D.line)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width:  kDrawerLogoSize,
            height: kDrawerLogoSize,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF0F172A)
                  : Colors.white,
              border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF334155)
                      : _D.border),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Image.asset(
              kDrawerLogoAsset,
              fit:           BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder:  (_, __, ___) => const Center(
                child: Text('Logo',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Color(0xFF6B8AB8))),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kubadilishana',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: _D.text)),
              SizedBox(height: 2),
              Text('Admin panel',
                  style: TextStyle(fontSize: 13, color: _D.section)),
            ],
          ),
        ),
        Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : _D.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onClose,
            child: const SizedBox(
              width: 36, height: 36,
              child: Icon(TablerIcons.x, size: 20,
                  color: Color(0xFF444444)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---- Vipande ------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 20, 6),
        child: Text(text,
            style: const TextStyle(
                fontSize:     11,
                fontWeight:   FontWeight.w800,
                letterSpacing: 1.4,
                color:        _D.blue)),
      );
}

class _Tile extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final bool       selected;
  final int        count;
  final Color?     color;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? (selected ? _D.blue  : _D.icon);
    final textColor = color ?? (selected ? _D.text  : _D.item);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize:   15,
                        color:      textColor,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ),
              if (count > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color:        _D.badge,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                        fontSize:   11.5,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _ProfileTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Icon(TablerIcons.userCircle, size: 22, color: _D.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wasifu wangu',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600,
                          color: _D.text)),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: _D.section)),
                ],
              ),
            ),
            const Icon(TablerIcons.chevronRight, size: 18, color: _D.icon),
          ]),
        ),
      ),
    );
  }
}
