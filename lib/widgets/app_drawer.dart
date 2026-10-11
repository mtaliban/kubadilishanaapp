// app_drawer.dart
// Menyu ya pembeni (Kubadilishana / Admin panel) - toleo lililorekebishwa.
// Inahitaji Flutter 3.16 au mpya zaidi. Haihitaji package yoyote ya nje.
//
// MUHIMU: itumie kama `Scaffold(drawer: AppDrawer(...))`.
// Usiiweke ndani ya body au Stack, kwa sababu hapo urefu wake unapunguzwa
// na sehemu ya chini (Wasifu wangu na Toka) inakatwa.

import 'package:flutter/material.dart';

const Color kInk = Color(0xFF243049);
const Color kMut = Color(0xFF7A8496);
const Color kLine = Color(0xFFE3E7EE);
const Color kAc = Color(0xFF1F5FD6);
const Color kSoft = Color(0xFFE8EFFC);
const Color kPress = Color(0xFFD6E3FB);
const Color kRed = Color(0xFFD92D20);
const Color kRedSoft = Color(0xFFFEF3F2);

class MenuEntry {
  final String label;
  final IconData icon;
  final int badge; // 0 = hakuna namba
  const MenuEntry(this.label, this.icon, {this.badge = 0});
}

class MenuSection {
  final String title;
  final List<MenuEntry> entries;
  const MenuSection(this.title, this.entries);
}

class AppDrawer extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;
  final String userName;

  /// Weka logo yako hapa, mfano:
  /// Image.asset('assets/logo.png', width: 40, height: 40)
  final Widget? logo;

  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
    this.userName = 'Hamisi Selemani Hamisi',
    this.logo,
  });

  // Badilisha badge (4 na 1) na namba halisi kutoka server yako.
  static const sections = <MenuSection>[
    MenuSection('Kuu', [
      MenuEntry('Takwimu', Icons.pie_chart_outline),
      MenuEntry('Watumiaji', Icons.groups_outlined),
      MenuEntry('Waliopata wenzao', Icons.link),
      MenuEntry('Match za kweli', Icons.flash_on_outlined),
    ]),
    MenuSection('Mawasiliano', [
      MenuEntry('Matangazo', Icons.campaign_outlined),
      MenuEntry('Waliopigiana', Icons.phone_outlined, badge: 4),
      MenuEntry('Maoni na malalamiko', Icons.chat_outlined),
    ]),
    MenuSection('Mfumo', [
      MenuEntry('Malipo', Icons.paid_outlined, badge: 1),
      MenuEntry('Data', Icons.storage_outlined),
    ]),
  ];

  void _pick(BuildContext context, String name) {
    onSelect(name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = (mq.size.width * 0.82).clamp(260.0, 320.0);

    // Font kubwa ya simu isiikuze menyu hii (inasababisha kukatika chini).
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.0)),
      child: Drawer(
        width: width,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              const Divider(height: 1, thickness: 1, color: kLine),
              // Orodha: inateleza ikiwa skrini ni fupi sana.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in sections) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 14, 22, 4),
                          child: Text(s.title,
                              style:
                                  const TextStyle(fontSize: 12, color: kMut)),
                        ),
                        for (final e in s.entries)
                          _NavRow(
                            icon: e.icon,
                            label: e.label,
                            badge: e.badge,
                            active: selected == e.label,
                            onTap: () => _pick(context, e.label),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              // Wasifu wangu na Toka: vimefungwa chini, havikatiki kamwe.
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
      child: Row(
        children: [
          logo ??
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ES',
                    style: TextStyle(
                        color: kAc, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kubadilishana',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kInk,
                        height: 1.2)),
                SizedBox(height: 1),
                Text('Admin panel',
                    style: TextStyle(fontSize: 12, color: kMut)),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                border: Border.all(color: kLine),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, size: 18, color: kInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: kLine))),
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavRow(
            height: 54,
            leading: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: kSoft, shape: BoxShape.circle),
              child: Text(
                userName.isEmpty ? '?' : userName[0].toUpperCase(),
                style: const TextStyle(
                    color: kAc, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            label: 'Wasifu wangu',
            subtitle: userName,
            trailing: const Icon(Icons.chevron_right, size: 20, color: kMut),
            active: selected == 'Wasifu wangu',
            onTap: () => _pick(context, 'Wasifu wangu'),
          ),
          _NavRow(
            height: 42,
            icon: Icons.logout,
            label: 'Toka',
            danger: true,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

/// Mstari mmoja wa menyu. Ukichaguliwa, rangi inajaa hadi mwisho wa kulia
/// na mstari wa bluu unaonekana upande wa kushoto.
class _NavRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final String? subtitle;
  final int badge;
  final bool active;
  final bool danger;
  final double height;
  final Widget? trailing;
  final VoidCallback onTap;

  const _NavRow({
    this.icon,
    this.leading,
    required this.label,
    this.subtitle,
    this.badge = 0,
    this.active = false,
    this.danger = false,
    this.height = 44,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = danger ? kRed : (active ? kAc : kInk);

    return Ink(
      decoration: BoxDecoration(
        color: active ? kSoft : Colors.transparent,
        border: Border(
          left: BorderSide(color: active ? kAc : Colors.transparent, width: 4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: danger ? kRedSoft : kPress,
        highlightColor: danger ? kRedSoft : kPress,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Row(
              children: [
                leading ?? Icon(icon, size: 21, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: subtitle == null
                      ? Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5,
                              color: fg,
                              fontWeight: (active || danger)
                                  ? FontWeight.w600
                                  : FontWeight.w400))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kInk,
                                    height: 1.2)),
                            const SizedBox(height: 2),
                            Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: kMut)),
                          ],
                        ),
                ),
                if (badge > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mfano wa matumizi (futa main() hii ukiunganisha kwenye app yako)
// ---------------------------------------------------------------------------
void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: kAc),
        home: const _DemoHome(),
      );
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();
  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  String selected = 'Takwimu';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(selected)),
      // Drawer ya Scaffold: inafunika skrini nzima, pamoja na bottom nav.
      drawer: AppDrawer(
        selected: selected,
        onSelect: (name) => setState(() => selected = name),
        onLogout: () => Navigator.pop(context),
      ),
      body: Center(child: Text(selected)),
    );
  }
}
