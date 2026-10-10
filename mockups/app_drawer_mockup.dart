// NOTE (Buffy): Mockup ya AppDrawer ya admin panel ya "Kubadilishana"
// iliyopeswa kama ilivyo (sio sehemu ya app halisi — hiyo ni lib/widgets/app_drawer.dart).
// Demo standalone yenye main() yake; haipaswi kwa app halisi.

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

const kInk = Color(0xFF243049);
const kMut = Color(0xFF7A8496);
const kLine = Color(0xFFE3E7EE);
const kAc = Color(0xFF1F5FD6);
const kSoft = Color(0xFFE8EFFC);
const kPress = Color(0xFFD6E3FB);
const kRed = Color(0xFFD92D20);
const kRedSoft = Color(0xFFFEF3F2);

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kubadilishana',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: kAc),
      ),
      home: const HomePage(),
    );
  }
}

/// Ukurasa wa mfano tu, unaonyesha kipengele ulichochagua.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selected = 'Watumiaji';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kInk),
        title: Text(selected,
            style: const TextStyle(
                color: kInk, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      drawer: AppDrawer(
        selected: selected,
        onSelect: (name) => setState(() => selected = name),
        onLogout: () {
          // hapa weka kutoka (logout) ya app yako
          Navigator.pop(context);
        },
      ),
      body: Center(
        child: Text(selected,
            style: const TextStyle(fontSize: 20, color: kInk)),
      ),
    );
  }
}

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

  const AppDrawer({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
  });

  // Badilisha namba za badge (4 na 1) na data halisi kutoka server yako.
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
    Navigator.pop(context); // funga menyu
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width * 0.84).clamp(260.0, 340.0);
    return Drawer(
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
            // Orodha ya menyu: inateleza ikiwa skrini ni fupi.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in sections) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
                        child: Text(s.title,
                            style: const TextStyle(fontSize: 12, color: kMut)),
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
            // Wasifu na Toka: vimefungwa chini kabisa.
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
      child: Row(
        children: [
          // Weka logo yako hapa, mfano:
          // ClipRRect(borderRadius: BorderRadius.circular(12),
          //   child: Image.asset('assets/logo.png', width: 44, height: 44)),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('ES',
                style: TextStyle(
                    color: kAc, fontSize: 16, fontWeight: FontWeight.w600)),
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
                        fontSize: 17,
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
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavRow(
            height: 60,
            leading: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: kSoft, shape: BoxShape.circle),
              child: const Text('H',
                  style: TextStyle(
                      color: kAc, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            label: 'Wasifu wangu',
            subtitle: 'Hamisi Selemani Hamisi',
            trailing: const Icon(Icons.chevron_right, size: 20, color: kMut),
            active: selected == 'Wasifu wangu',
            onTap: () => _pick(context, 'Wasifu wangu'),
          ),
          _NavRow(
            height: 44,
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
    this.height = 48,
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
            padding: const EdgeInsets.only(left: 18, right: 18),
            child: Row(
              children: [
                leading ?? Icon(icon, size: 22, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: subtitle == null
                      ? Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
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
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kRed,
                      borderRadius: BorderRadius.circular(11),
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
