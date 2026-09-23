import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/* ============================================================
   VIPENGELE VYA MENYU
   key -> tumia kwenye onSelect kujua ukurasa gani ufunguliwe
   ============================================================ */
enum _Tone { blue, green, red, amber, neutral }

class _MenuItem {
  final String key;
  final String label;
  final IconData icon;
  final _Tone tone;
  const _MenuItem(this.key, this.label, this.icon, this.tone);
}

class _MenuSection {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection(this.title, this.items);
}

final _sections = [
  _MenuSection('KUU', [
    _MenuItem('takwimu', 'Takwimu', PhosphorIcons.chartBar(), _Tone.blue),
    _MenuItem('watumiaji', 'Watumiaji', PhosphorIcons.usersThree(), _Tone.blue),
    _MenuItem('wenzao', 'Waliopata wenzao', PhosphorIcons.arrowsLeftRight(), _Tone.green),
    _MenuItem('match', 'Match za kweli', PhosphorIcons.handshake(), _Tone.red),
  ]),
  _MenuSection('MAWASILIANO', [
    _MenuItem('matangazo', 'Matangazo', PhosphorIcons.megaphone(), _Tone.amber),
    _MenuItem('simu', 'Waliopigiana', PhosphorIcons.phoneCall(), _Tone.green),
    _MenuItem('maoni', 'Maoni na malalamiko', PhosphorIcons.chatCenteredText(), _Tone.amber),
  ]),
  _MenuSection('FEDHA NA DATA', [
    _MenuItem('malipo', 'Malipo', PhosphorIcons.wallet(), _Tone.green),
    _MenuItem('data', 'Data', PhosphorIcons.database(), _Tone.neutral),
  ]),
];

/* ============================================================
   MENYU YA PEMBENI
   Tumia kama:  Scaffold(drawer: AdminDrawer(...), ...)
   ============================================================ */
class AdminDrawer extends StatelessWidget {
  /// Ukurasa ulio wazi sasa, mf. 'wenzao'
  final String activeKey;

  /// Idadi ya watumiaji (badge ya bluu). null = haionekani
  final int? usersCount;

  final String adminName;
  final String initials;

  final ValueChanged<String> onSelect;
  final VoidCallback? onProfile;
  final VoidCallback? onLogout;

  const AdminDrawer({
    super.key,
    required this.activeKey,
    required this.adminName,
    required this.initials,
    required this.onSelect,
    this.usersCount,
    this.onProfile,
    this.onLogout,
  });

  static String _num(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c = _DrawerColors.of(context);
    final width = (MediaQuery.of(context).size.width * 0.82).clamp(260.0, 340.0);

    return Drawer(
      width: width,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(context, c),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final s in _sections) ...[
                    _SectionTitle(s.title, c: c),
                    for (final it in s.items)
                      _Row(
                        c: c,
                        leading: _IconTile(icon: it.icon, tone: it.tone, c: c),
                        label: it.label,
                        active: it.key == activeKey,
                        badge: it.key == 'watumiaji' && usersCount != null
                            ? _num(usersCount!)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          onSelect(it.key);
                        },
                      ),
                  ],
                ],
              ),
            ),
            _footer(context, c),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, _DrawerColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.fill),
                size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kubadilishana',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                Text('Admin panel',
                    style: TextStyle(color: c.muted, fontSize: 13)),
              ],
            ),
          ),
          Material(
            color: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: c.border),
            ),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(PhosphorIcons.x(), size: 19, color: c.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, _DrawerColors c) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          // Wasifu wangu
          _Row(
            c: c,
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.blueBg,
                shape: BoxShape.circle,
              ),
              child: Text(initials,
                  style: TextStyle(
                      color: c.blue,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            label: 'Wasifu wangu',
            labelBold: true,
            subtitle: adminName,
            trailing: Icon(PhosphorIcons.caretRight(), size: 18, color: c.faint),
            onTap: () {
              Navigator.pop(context);
              onProfile?.call();
            },
          ),
          // Toka
          _Row(
            c: c,
            leading: _IconTile(
                icon: PhosphorIcons.signOut(), tone: _Tone.red, c: c),
            label: 'Toka',
            labelColor: c.red,
            onTap: () {
              Navigator.pop(context);
              onLogout?.call();
            },
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _SectionTitle extends StatelessWidget {
  final String text;
  final _DrawerColors c;
  const _SectionTitle(this.text, {required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
      child: Text(text,
          style: TextStyle(
              color: c.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1)),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final _Tone tone;
  final _DrawerColors c;

  const _IconTile({required this.icon, required this.tone, required this.c});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = c.tone(tone);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: fg),
    );
  }
}

class _Row extends StatelessWidget {
  final _DrawerColors c;
  final Widget leading;
  final String label;
  final String? subtitle;
  final String? badge;
  final Widget? trailing;
  final bool active;
  final bool labelBold;
  final Color? labelColor;
  final VoidCallback onTap;

  const _Row({
    required this.c,
    required this.leading,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.trailing,
    this.active = false,
    this.labelBold = false,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: active ? c.activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: labelColor ?? c.text,
                          fontSize: 15,
                          fontWeight: active || labelBold
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.blue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(badge!,
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

/* ============================================================
   RANGI (light + dark)
   ============================================================ */
class _DrawerColors {
  final Color card, border, text, muted, faint, activeBg;
  final Color blue, blueBg, green, greenBg, red, redBg, amber, amberBg;
  final Color neutral, neutralBg;

  const _DrawerColors({
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.activeBg,
    required this.blue,
    required this.blueBg,
    required this.green,
    required this.greenBg,
    required this.red,
    required this.redBg,
    required this.amber,
    required this.amberBg,
    required this.neutral,
    required this.neutralBg,
  });

  static const light = _DrawerColors(
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE6E6E3),
    text: Color(0xFF141414),
    muted: Color(0xFF6E6E6A),
    faint: Color(0xFF9A9A96),
    activeBg: Color(0xFFF6F6F4),
    blue: Color(0xFF2A78D6),
    blueBg: Color(0xFFD3E5FA),
    green: Color(0xFF1E6B1E),
    greenBg: Color(0xFFCDEBCB),
    red: Color(0xFF8E2A2A),
    redBg: Color(0xFFF8D7D7),
    amber: Color(0xFF7A4A00),
    amberBg: Color(0xFFF9DDA4),
    neutral: Color(0xFF3C3C3A),
    neutralBg: Color(0xFFEFEFEC),
  );

  static const dark = _DrawerColors(
    card: Color(0xFF1C1C1B),
    border: Color(0xFF2E2E2C),
    text: Color(0xFFF1F1EE),
    muted: Color(0xFFA3A39E),
    faint: Color(0xFF75756F),
    activeBg: Color(0xFF262625),
    blue: Color(0xFF7AB0F0),
    blueBg: Color(0xFF1D3350),
    green: Color(0xFF8ED48A),
    greenBg: Color(0xFF1E3A1F),
    red: Color(0xFFF2A0A0),
    redBg: Color(0xFF4A2222),
    amber: Color(0xFFF2C46B),
    amberBg: Color(0xFF4A3614),
    neutral: Color(0xFFD6D6D2),
    neutralBg: Color(0xFF2E2E2C),
  );

  static _DrawerColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) {
    switch (t) {
      case _Tone.blue:
        return (blue, blueBg);
      case _Tone.green:
        return (green, greenBg);
      case _Tone.red:
        return (red, redBg);
      case _Tone.amber:
        return (amber, amberBg);
      case _Tone.neutral:
        return (neutral, neutralBg);
    }
  }
}
