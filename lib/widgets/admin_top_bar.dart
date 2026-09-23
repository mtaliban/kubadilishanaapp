import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/* ============================================================
   UPAU WA JUU
   Tumia kama:  Scaffold(appBar: AdminTopBar(...), ...)
   ============================================================ */
class AdminTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// Herufi za kwenye duara, mf. "H"
  final String initials;

  /// Lugha iliyochaguliwa: "sw" au "en"
  final String lang;

  /// Kitone cha kijani kwenye duara (yuko mtandaoni)
  final bool online;

  final VoidCallback? onMenu;
  final ValueChanged<String>? onLangChanged;
  final VoidCallback? onAvatarTap;

  const AdminTopBar({
    super.key,
    required this.initials,
    this.lang = 'sw',
    this.online = true,
    this.onMenu,
    this.onLangChanged,
    this.onAvatarTap,
  });

  static const double _height = 58;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final c = _BarColors.of(context);

    return Material(
      color: c.card,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              // Kitufe cha menyu
              IconButton(
                onPressed: onMenu ?? () => Scaffold.maybeOf(context)?.openDrawer(),
                tooltip: 'Menyu',
                icon: Icon(PhosphorIcons.list(), size: 24, color: c.text),
                style: IconButton.styleFrom(
                  fixedSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),

              // Kitufe cha lugha
              _LangButton(lang: lang, c: c, onChanged: onLangChanged),
              const SizedBox(width: 10),

              // Duara la admin
              _Avatar(
                initials: initials,
                online: online,
                c: c,
                onTap: onAvatarTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   KITUFE CHA LUGHA (🇹🇿 SW ⌄)
   ============================================================ */
class _LangButton extends StatelessWidget {
  final String lang;
  final _BarColors c;
  final ValueChanged<String>? onChanged;

  const _LangButton({required this.lang, required this.c, this.onChanged});

  static const _langs = {
    'sw': (flag: '🇹🇿', code: 'SW', name: 'Kiswahili'),
    'en': (flag: '🇬🇧', code: 'EN', name: 'English'),
  };

  @override
  Widget build(BuildContext context) {
    final cur = _langs[lang] ?? _langs['sw']!;

    return PopupMenuButton<String>(
      tooltip: 'Lugha',
      initialValue: lang,
      onSelected: onChanged,
      color: c.card,
      elevation: 6,
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borderStrong),
      ),
      itemBuilder: (_) => _langs.entries.map((e) {
        final selected = e.key == lang;
        return PopupMenuItem<String>(
          value: e.key,
          height: 44,
          child: Row(
            children: [
              Text(e.value.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(e.value.name,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400)),
              ),
              if (selected)
                Icon(PhosphorIcons.check(), size: 16, color: c.blue),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cur.flag, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(cur.code,
                style: TextStyle(
                    color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(PhosphorIcons.caretDown(), size: 14, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   DUARA LA ADMIN (lenye pete + kitone cha kijani)
   ============================================================ */
class _Avatar extends StatelessWidget {
  final String initials;
  final bool online;
  final _BarColors c;
  final VoidCallback? onTap;

  const _Avatar({
    required this.initials,
    required this.online,
    required this.c,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Pete ya nje
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.ring, width: 1.5),
              ),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.blueBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: c.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Kitone cha kijani
            if (online)
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
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   RANGI (light + dark)
   ============================================================ */
class _BarColors {
  final Color card, border, borderStrong, text, muted, blue, blueBg, ring, green;

  const _BarColors({
    required this.card,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.blue,
    required this.blueBg,
    required this.ring,
    required this.green,
  });

  static const light = _BarColors(
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFCFD5DF),
    text: Color(0xFF141A24),
    muted: Color(0xFF667085),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    ring: Color(0xFF9DBDF3),
    green: Color(0xFF1FAA59),
  );

  static const dark = _BarColors(
    card: Color(0xFF181D26),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF3A4454),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFF9AA4B5),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    ring: Color(0xFF3B5A94),
    green: Color(0xFF5FD49A),
  );

  static _BarColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
