// =============================================================================
// user_top_bar.dart
// Upau wa juu wa app ya MTUMIAJI (si admin).
//
// ------------------------------ TABIA (SPEC) --------------------------------
// Mpangilio:  [≡]  ..............nafasi tupu..............  (B)  [SW|EN]
//
// 1. Kitufe cha ≡ (kushoto)
//    - UKIGUSA: menyu ndogo inafunguka chini yake ikiwa na, kwa mpangilio huu:
//        Dashibodi            (TablerIcons.layoutDashboard)
//        Changia              (TablerIcons.heartHandshake)
//        Maoni na malalamiko  (TablerIcons.clipboardList)
//        Wasifu               (TablerIcons.user)
//        ───────── mstari ─────────
//        Toka                 (TablerIcons.logout, rangi NYEKUNDU)
//    - Ukurasa uliopo sasa (currentPage) unaonyeshwa kwa rangi ya bluu hafifu
//      na alama ya ✓ upande wa kulia.
//    - Ukigusa ukurasa: menyu inafunga, kisha onNavigate(page) inaitwa.
//      Ukigusa ukurasa ulioko tayari: menyu inafunga tu, hakuna kinachoitwa.
//    - Ukigusa "Toka": menyu inafunga, dirisha dogo linauliza
//      "Toka kwenye akaunti?" [Hapana] [Toka].
//        * Hapana  -> dirisha linafunga, hakuna kinachotokea.
//        * Toka    -> onLogout() inaitwa.
//      (Weka confirmLogout: false kama hutaki swali hili.)
//    - Menyu ikiwa wazi, kitufe cha ≡ kinakuwa na rangi ya bluu hafifu.
//    - Ukigusa nje ya menyu: menyu inafunga.
//
// 2. Duara la herufi (B)
//    - NI LA KUONYESHA TU. UKILIGUSA HAKUNA KINACHOTOKEA.
//    - Hakuna menyu, hakuna kwenda Wasifu, hakuna ripple.
//    - Linaonyesha herufi za kwanza za jina na kitone cha kijani.
//
// 3. SW | EN (kulia kabisa)
//    - Ukigusa lugha ambayo haijachaguliwa: onLangChanged('sw' au 'en').
//    - Ukigusa lugha iliyochaguliwa tayari: hakuna kinachotokea.
//
// Matumizi:
//   Scaffold(
//     appBar: UserTopBar(
//       name: user.name,
//       currentPage: UserPage.wasifu,
//       lang: 'sw',
//       onLangChanged: (l) => ...,
//       onNavigate: (page) => ...,   // badilisha tab / Navigator
//       onLogout: () async => ...,   // futa token, rudi kwenye login
//     ),
//     body: ...,
//     bottomNavigationBar: menyuYakoYaChini, // haiguswi
//   )
// =============================================================================

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Kurasa nne za app ya mtumiaji
enum UserPage { dashibodi, changia, maoni, wasifu }

class UserTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final UserPage currentPage;
  final String lang; // 'sw' au 'en'
  final ValueChanged<String> onLangChanged;
  final ValueChanged<UserPage> onNavigate;
  final Future<void> Function() onLogout;
  final bool confirmLogout;

  const UserTopBar({
    super.key,
    required this.name,
    required this.currentPage,
    required this.lang,
    required this.onLangChanged,
    required this.onNavigate,
    required this.onLogout,
    this.confirmLogout = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final c = _TC.of(context);
    return Material(
      color: c.card,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
          child: Row(
            children: [
              // 1. Menyu ya ≡ (inafungua kurasa + Toka)
              _PageMenu(
                c: c,
                current: currentPage,
                onNavigate: onNavigate,
                onLogout: () => _logout(context),
              ),
              const Spacer(),
              // 2. Duara la jina: la kuonyesha tu, halibonyezeki
              _Avatar(c: c, name: name),
              const SizedBox(width: 10),
              // 3. Lugha
              _LangSwitch(c: c, lang: lang, onChanged: onLangChanged),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    if (!confirmLogout) return onLogout();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _LogoutDialog(c: _TC.of(context)),
    );
    if (ok == true) await onLogout();
  }
}

/* ============================================================
   1. MENYU YA ≡
   ============================================================ */
enum _Action { page, logout }

class _PageMenu extends StatefulWidget {
  final _TC c;
  final UserPage current;
  final ValueChanged<UserPage> onNavigate;
  final VoidCallback onLogout;

  const _PageMenu({
    required this.c,
    required this.current,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<_PageMenu> createState() => _PageMenuState();
}

class _PageMenuState extends State<_PageMenu> {
  bool open = false;

  static const _pages = <(UserPage, String, IconData)>[
    (UserPage.dashibodi, 'Dashibodi', TablerIcons.layoutDashboard),
    (UserPage.changia, 'Changia', TablerIcons.heartHandshake),
    (UserPage.maoni, 'Maoni na malalamiko', TablerIcons.clipboardList),
    (UserPage.wasifu, 'Wasifu', TablerIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return PopupMenuButton<(_Action, UserPage?)>(
      tooltip: 'Menyu',
      offset: const Offset(0, 46),
      color: c.card,
      elevation: 6,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 260),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.borderStrong, width: .5),
      ),
      onOpened: () => setState(() => open = true),
      onCanceled: () => setState(() => open = false),
      onSelected: (v) {
        setState(() => open = false);
        final (action, page) = v;
        if (action == _Action.logout) {
          widget.onLogout();
        } else if (page != null && page != widget.current) {
          widget.onNavigate(page);
        }
      },
      itemBuilder: (_) => [
        for (final (page, label, icon) in _pages)
          PopupMenuItem(
            value: (_Action.page, page),
            height: 44,
            padding: EdgeInsets.zero,
            child: _MenuRow(
              c: c,
              icon: icon,
              label: label,
              selected: page == widget.current,
            ),
          ),
        const PopupMenuDivider(height: 10),
        PopupMenuItem(
          value: (_Action.logout, null),
          height: 44,
          padding: EdgeInsets.zero,
          child: _MenuRow(c: c, icon: TablerIcons.logout, label: 'Toka', danger: true),
        ),
      ],
      // Kitufe cha ≡ chenyewe
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: open ? c.blueBg : c.soft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(TablerIcons.menu2, size: 20, color: open ? c.blue : c.text),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _TC c;
  final IconData icon;
  final String label;
  final bool selected;
  final bool danger;

  const _MenuRow({
    required this.c,
    required this.icon,
    required this.label,
    this.selected = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? c.red : (selected ? c.blue : c.text);
    final iconBg = danger ? c.redBg : (selected ? c.card : c.soft);
    final iconFg = danger ? c.red : (selected ? c.blue : c.muted);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? c.blueBg : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: iconFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ),
        if (selected) Icon(TablerIcons.check, size: 16, color: c.blue),
      ]),
    );
  }
}

/* ============================================================
   2. DUARA LA JINA — la kuonyesha tu (HALINA onTap)
   ============================================================ */
class _Avatar extends StatelessWidget {
  final _TC c;
  final String name;
  const _Avatar({required this.c, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    // Makusudi: hakuna GestureDetector / InkWell hapa.
    return ExcludeSemantics(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.blueBg,
              shape: BoxShape.circle,
              border: Border.all(color: c.blue.withValues(alpha: .35), width: 1.5),
            ),
            child: Text(initial,
                style: TextStyle(color: c.blue, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: c.green,
                shape: BoxShape.circle,
                border: Border.all(color: c.card, width: 2),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/* ============================================================
   3. SW | EN
   ============================================================ */
class _LangSwitch extends StatelessWidget {
  final _TC c;
  final String lang;
  final ValueChanged<String> onChanged;
  const _LangSwitch({required this.c, required this.lang, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String code, String label) {
      final on = lang == code;
      return GestureDetector(
        onTap: on ? null : () => onChanged(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: on ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: on ? Border.all(color: c.borderStrong, width: .5) : null,
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? c.blue : c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.border, width: .5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('sw', 'SW'),
        seg('en', 'EN'),
      ]),
    );
  }
}

/* ============================================================
   DIRISHA LA KUTHIBITISHA KUTOKA
   ============================================================ */
class _LogoutDialog extends StatelessWidget {
  final _TC c;
  const _LogoutDialog({required this.c});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.redBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(TablerIcons.logout, size: 22, color: c.red),
            ),
            const SizedBox(height: 10),
            Text('Toka kwenye akaunti?',
                style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Utahitaji kuingia tena', style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      side: BorderSide(color: c.borderStrong),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
                      backgroundColor: c.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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

/* ============================================================
   RANGI
   ============================================================ */
class _TC {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, red, redBg;

  const _TC({
    required this.card,
    required this.soft,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.blue,
    required this.blueBg,
    required this.green,
    required this.red,
    required this.redBg,
  });

  static const light = _TC(
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFC3CAD6),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    green: Color(0xFF16A34A),
    red: Color(0xFFC62828),
    redBg: Color(0xFFFDECEC),
  );

  static const dark = _TC(
    card: Color(0xFF181D26),
    soft: Color(0xFF212833),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF465164),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    green: Color(0xFF5FD49A),
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
  );

  static _TC of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
