import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/* ============================================================
   MODEL
   ============================================================ */
class UserDetails {
  final String name;
  final String idara; // mf. "health", "education", "Afya", "Elimu"
  final String kada; // mf. "Enrolled Nurse (EN)" au "TEACHER_SECONDARY"
  final String? employer; // mf. "TAMISEMI"
  final List<String> masomo; // mf. ["MATH", "PHYS"]
  final String phone;
  final String? whatsapp;
  final String? mkoa;
  final String? wilaya;
  final String? kituo;
  final List<(String wilaya, String mkoa)> destinations;
  final bool active;
  final bool paid;
  final bool verified;
  final bool hasPassword;
  final bool contactAllowed;
  final String role; // mf. "Mtumiaji"
  final DateTime createdAt;
  final int seenBy; // wanaomwona kwenye dashboard
  final bool online;

  const UserDetails({
    required this.name,
    required this.idara,
    required this.kada,
    this.employer,
    this.masomo = const [],
    required this.phone,
    this.whatsapp,
    this.mkoa,
    this.wilaya,
    this.kituo,
    this.destinations = const [],
    this.active = true,
    this.paid = false,
    this.verified = false,
    this.hasPassword = false,
    this.contactAllowed = false,
    this.role = 'Mtumiaji',
    required this.createdAt,
    this.seenBy = 0,
    this.online = false,
  });
}

/* ============================================================
   TAFSIRI (database -> Kiswahili)
   ============================================================ */
enum _Tone { blue, green, amber }

class _IdaraInfo {
  final String label;
  final IconData icon, kadaIcon;
  final _Tone tone;
  const _IdaraInfo(this.label, this.icon, this.kadaIcon, this.tone);
}

_IdaraInfo _idaraInfo(String raw) {
  final k = raw.trim().toLowerCase();
  if (k == 'health' || k == 'afya') {
    return const _IdaraInfo('Afya', TablerIcons.heartRateMonitor, TablerIcons.nurse, _Tone.green);
  }
  if (k == 'education' || k == 'elimu') {
    return const _IdaraInfo('Elimu', TablerIcons.school, TablerIcons.chalkboard, _Tone.blue);
  }
  if (k.contains('agri') || k.contains('kilimo')) {
    return const _IdaraInfo('Kilimo na ufugaji', TablerIcons.plant2, TablerIcons.plant, _Tone.green);
  }
  if (k.contains('public') || k.contains('umma')) {
    return const _IdaraInfo('Watumishi wa umma', TablerIcons.buildingBank, TablerIcons.briefcase, _Tone.amber);
  }
  return _IdaraInfo(raw, TablerIcons.briefcase, TablerIcons.idBadge2, _Tone.blue);
}

const _kadaNames = {
  'TEACHER_PRIMARY': 'Mwalimu wa Elimu ya Msingi',
  'TEACHER_SECONDARY': 'Mwalimu wa Elimu ya Sekondari',
  'EN': 'Enrolled Nurse (EN)',
  'ANO': 'Assistant Nursing Officer (ANO)',
  'CO': 'Clinical Officer',
};

const _somoNames = {
  'MATH': 'Hisabati', 'PHYS': 'Fizikia', 'CHEM': 'Kemia', 'BIO': 'Biolojia',
  'KISW': 'Kiswahili', 'KISWAHILI': 'Kiswahili', 'ENG': 'Kiingereza',
  'HIST': 'Historia', 'GEO': 'Jiografia', 'CIV': 'Uraia', 'COMM': 'Biashara',
  'BK': 'Uhasibu', 'ARABIC': 'Kiarabu', 'FRENCH': 'Kifaransa',
};

String _kada(String raw) => _kadaNames[raw.trim().toUpperCase()] ?? raw;

String _somo(String raw) => _somoNames[raw.trim().toUpperCase()] ?? raw;

/// "NYAKAGOYAGOYE" -> "Nyakagoyagoye", "Karagwe Dc" -> "Karagwe DC"
String _place(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  return raw.trim().split(RegExp(r'\s+')).map((w) {
    final up = w.toUpperCase();
    if (const {'DC', 'TC', 'MC', 'CC'}.contains(up)) return up;
    if (w.length <= 1) return up;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

String _initials(String n) => n
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// "+255757502446" / "0757502446" -> "+255 757 502 446"
String _prettyPhone(String p) {
  var d = _digits(p);
  if (d.startsWith('255')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length != 9) return p;
  return '+255 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
}

String _intl(String p) {
  var d = _digits(p);
  if (d.startsWith('0')) d = '255${d.substring(1)}';
  if (!d.startsWith('255')) d = '255$d';
  return d;
}

const _months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];

String _date(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year} · '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/* ============================================================
   UKURASA
   ============================================================ */
class UserDetailsPage extends StatelessWidget {
  final UserDetails user;
  final VoidCallback? onEdit;
  final Future<void> Function()? onDelete;
  final VoidCallback? onToggleLock; // Funga / Fungua akaunti
  final VoidCallback? onSetPassword;

  /// Maelezo yanayoonekana kama hakuna anayemwona kwenye dashboard
  final String emptySeenText;

  const UserDetailsPage({
    super.key,
    required this.user,
    this.onEdit,
    this.onDelete,
    this.onToggleLock,
    this.onSetPassword,
    this.emptySeenText = 'Ataonekana na wengine akithibitishwa na kulipa.',
  });

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa mtumiaji'),
        content: Text('Una uhakika unataka kumfuta ${user.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hapana')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Futa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await onDelete?.call();
      if (context.mounted) Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _DColors.of(context);
    final id = _idaraInfo(user.idara);
    final (toneFg, toneBg) = c.tone(id.tone);
    final kada = _kada(user.kada);
    final wa = (user.whatsapp ?? '').trim();
    final sameWa = wa.isEmpty || _digits(_intl(wa)) == _digits(_intl(user.phone));

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Upau wa juu ----------
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  _SquareIcon(
                    c: c,
                    icon: TablerIcons.arrowLeft,
                    tooltip: 'Rudi',
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  _TonalButton(
                    c: c,
                    icon: TablerIcons.edit,
                    label: 'Hariri',
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _SquareIcon(
                    c: c,
                    icon: TablerIcons.trash,
                    tooltip: 'Futa',
                    fg: c.red,
                    bg: c.redBg,
                    onTap: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- Kichwa ----------
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: toneBg, shape: BoxShape.circle),
                            child: Text(_initials(user.name),
                                style: TextStyle(
                                    color: toneFg,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (user.online)
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: c.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.page, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(user.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w600)),
                    Text(kada,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _Pill(label: id.label, icon: id.icon, fg: toneFg, bg: toneBg),
                        if ((user.employer ?? '').isNotEmpty)
                          _Pill(
                              label: user.employer!,
                              icon: TablerIcons.buildingBank,
                              fg: c.blue,
                              bg: c.blueBg),
                        user.active
                            ? _Pill(
                                label: 'Hai',
                                icon: TablerIcons.pointFilled,
                                fg: c.green,
                                bg: c.greenBg)
                            : _Pill(
                                label: 'Amefungwa',
                                icon: TablerIcons.lock,
                                fg: c.amber,
                                bg: c.amberBg),
                        user.paid
                            ? _Pill(
                                label: 'Amelipa',
                                icon: TablerIcons.receipt,
                                fg: c.green,
                                bg: c.greenBg)
                            : _Pill(
                                label: 'Hajalipa',
                                icon: TablerIcons.receiptOff,
                                fg: c.red,
                                bg: c.redBg),
                      ],
                    ),

                    // ---------- Vitendo vya haraka ----------
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _QuickAction(
                          c: c,
                          icon: TablerIcons.phoneCall,
                          label: 'Piga',
                          fg: c.blue,
                          bg: c.blueBg,
                          onTap: () => launchUrl(
                              Uri(scheme: 'tel', path: '+${_intl(user.phone)}')),
                        ),
                        _QuickAction(
                          c: c,
                          icon: TablerIcons.brandWhatsapp,
                          label: 'WhatsApp',
                          fg: c.green,
                          bg: c.greenBg,
                          onTap: () => launchUrl(
                            Uri.parse(
                                'https://wa.me/${_intl(sameWa ? user.phone : wa)}'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        _QuickAction(
                          c: c,
                          icon: TablerIcons.copy,
                          label: 'Nakili',
                          fg: c.text,
                          bg: c.soft,
                          onTap: () async {
                            await Clipboard.setData(
                                ClipboardData(text: _prettyPhone(user.phone)));
                            if (context.mounted) {
                              _toast(context, 'Namba imenakiliwa');
                            }
                          },
                        ),
                        _QuickAction(
                          c: c,
                          icon: user.active ? TablerIcons.lock : TablerIcons.lockOpen,
                          label: user.active ? 'Funga' : 'Fungua',
                          fg: c.amber,
                          bg: c.amberBg,
                          onTap: onToggleLock,
                        ),
                      ],
                    ),

                    // ---------- Onyo la nywila ----------
                    if (!user.hasPassword) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: c.amberBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(TablerIcons.keyOff, size: 18, color: c.amber),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  'Hana nywila, kwa hivyo hawezi kuingia kwenye app.',
                                  style: TextStyle(color: c.amber, fontSize: 12)),
                            ),
                            _TonalButton(
                              c: c,
                              icon: TablerIcons.key,
                              label: 'Weka',
                              fg: c.amber,
                              bg: c.page,
                              height: 28,
                              onTap: onSetPassword,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ---------- Mawasiliano ----------
                    _GroupTitle(c: c, icon: TablerIcons.addressBook, text: 'MAWASILIANO'),
                    _Group(c: c, children: [
                      _Row(
                        c: c,
                        icon: TablerIcons.phone,
                        label: 'Namba ya simu',
                        value: _prettyPhone(user.phone),
                      ),
                      _Row(
                        c: c,
                        icon: TablerIcons.brandWhatsapp,
                        iconFg: c.green,
                        iconBg: c.greenBg,
                        label: 'WhatsApp',
                        value: sameWa ? 'Sawa na namba ya simu' : _prettyPhone(wa),
                        muted: sameWa,
                      ),
                    ]),

                    // ---------- Kazi ----------
                    _GroupTitle(c: c, icon: TablerIcons.briefcase2, text: 'KAZI'),
                    _Group(c: c, children: [
                      _Row(
                        c: c,
                        icon: id.icon,
                        iconFg: toneFg,
                        iconBg: toneBg,
                        label: 'Idara',
                        value: id.label,
                      ),
                      _Row(
                        c: c,
                        icon: id.kadaIcon,
                        iconFg: toneFg,
                        iconBg: toneBg,
                        label: 'Kada',
                        value: kada,
                      ),
                      if (user.masomo.isNotEmpty)
                        _Row(
                          c: c,
                          icon: TablerIcons.books,
                          label: 'Masomo',
                          value: user.masomo.map(_somo).join(', '),
                        ),
                      if ((user.employer ?? '').isNotEmpty)
                        _Row(
                          c: c,
                          icon: TablerIcons.buildingBank,
                          label: 'Mwajiri',
                          value: user.employer!,
                        ),
                    ]),

                    // ---------- Uhamisho ----------
                    _GroupTitle(c: c, icon: TablerIcons.route, text: 'UHAMISHO'),
                    _RouteCard(
                      c: c,
                      kituo: _place(user.kituo),
                      wilaya: _place(user.wilaya),
                      mkoa: _place(user.mkoa),
                      destinations: user.destinations
                          .map((d) => (_place(d.$1), _place(d.$2)))
                          .toList(),
                    ),

                    // ---------- Akaunti ----------
                    _GroupTitle(c: c, icon: TablerIcons.shieldCog, text: 'AKAUNTI'),
                    _Group(c: c, children: [
                      _StatusRow(
                        c: c,
                        icon: TablerIcons.userCheck,
                        label: 'Hali',
                        value: user.active ? 'Hai' : 'Amefungwa',
                        fg: user.active ? c.green : c.amber,
                        bg: user.active ? c.greenBg : c.amberBg,
                      ),
                      _StatusRow(
                        c: c,
                        icon: TablerIcons.receipt,
                        label: 'Malipo',
                        value: user.paid ? 'Amelipa' : 'Hajalipa',
                        fg: user.paid ? c.green : c.red,
                        bg: user.paid ? c.greenBg : c.redBg,
                      ),
                      _StatusRow(
                        c: c,
                        icon: TablerIcons.rosetteDiscountCheck,
                        label: 'Uthibitisho',
                        value: user.verified ? 'Imethibitishwa' : 'Haijathibitishwa',
                        fg: user.verified ? c.green : c.amber,
                        bg: user.verified ? c.greenBg : c.amberBg,
                      ),
                      _StatusRow(
                        c: c,
                        icon: TablerIcons.key,
                        label: 'Nywila',
                        value: user.hasPassword ? 'Imewekwa' : 'Haijawekwa',
                        fg: user.hasPassword ? c.green : c.amber,
                        bg: user.hasPassword ? c.greenBg : c.amberBg,
                      ),
                      _StatusRow(
                        c: c,
                        icon: TablerIcons.addressBook,
                        label: 'Kuona mawasiliano',
                        value: user.contactAllowed ? 'Ameruhusiwa' : 'Hajaruhusiwa',
                        fg: user.contactAllowed ? c.green : c.amber,
                        bg: user.contactAllowed ? c.greenBg : c.amberBg,
                      ),
                      _Row(c: c, icon: TablerIcons.user, label: 'Wajibu', value: user.role),
                      _Row(
                        c: c,
                        icon: TablerIcons.calendarEvent,
                        label: 'Imeundwa',
                        value: _date(user.createdAt),
                      ),
                    ]),

                    // ---------- Wanaomwona ----------
                    _GroupTitle(
                      c: c,
                      icon: TablerIcons.users,
                      text: 'WANAOMWONA KWENYE DASHBOARD',
                      trailing: '${user.seenBy}',
                    ),
                    _Group(c: c, children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                        child: Column(
                          children: [
                            Icon(
                              user.seenBy == 0 ? TablerIcons.usersMinus : TablerIcons.users,
                              size: 26,
                              color: c.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.seenBy == 0
                                  ? 'Bado hakuna anayemwona'
                                  : 'Watu ${user.seenBy} wanamwona',
                              style: TextStyle(
                                  color: c.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (user.seenBy == 0)
                              Text(emptySeenText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: c.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  ],
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
   VIPANDE VIDOGO
   ============================================================ */
class _SquareIcon extends StatelessWidget {
  final _DColors c;
  final IconData icon;
  final String tooltip;
  final Color? fg, bg;
  final VoidCallback? onTap;

  const _SquareIcon({
    required this.c,
    required this.icon,
    required this.tooltip,
    this.fg,
    this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg ?? c.soft,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: fg ?? c.text),
          ),
        ),
      ),
    );
  }
}

class _TonalButton extends StatelessWidget {
  final _DColors c;
  final IconData icon;
  final String label;
  final Color? fg, bg;
  final double height;
  final VoidCallback? onTap;

  const _TonalButton({
    required this.c,
    required this.icon,
    required this.label,
    this.fg,
    this.bg,
    this.height = 30,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg ?? c.blueBg,
          foregroundColor: fg ?? c.blue,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size(0, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 5),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;

  const _Pill({required this.label, this.icon, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final _DColors c;
  final IconData icon;
  final String label;
  final Color fg, bg;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.c,
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final _DColors c;
  final IconData icon;
  final String text;
  final String? trailing;

  const _GroupTitle(
      {required this.c, required this.icon, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c.blue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .3)),
          ),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(
                    color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final _DColors c;
  final List<Widget> children;
  const _Group({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, color: c.border));
      items.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color fg, bg;
  const _IconBox({required this.icon, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 17, color: fg),
    );
  }
}

class _Row extends StatelessWidget {
  final _DColors c;
  final IconData icon;
  final Color? iconFg, iconBg;
  final String label, value;
  final bool muted;

  const _Row({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    this.iconFg,
    this.iconBg,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _IconBox(icon: icon, fg: iconFg ?? c.blue, bg: iconBg ?? c.blueBg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
                Text(value,
                    style: TextStyle(
                      color: muted ? c.muted : c.text,
                      fontSize: 14,
                      fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final _DColors c;
  final IconData icon;
  final String label, value;
  final Color fg, bg;

  const _StatusRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _IconBox(icon: icon, fg: c.muted, bg: c.soft),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: c.text, fontSize: 14))),
          _Pill(label: value, fg: fg, bg: bg),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final _DColors c;
  final String kituo, wilaya, mkoa;
  final List<(String, String)> destinations;

  const _RouteCard({
    required this.c,
    required this.kituo,
    required this.wilaya,
    required this.mkoa,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle k() => TextStyle(color: c.muted, fontSize: 12);
    TextStyle v() =>
        TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderStrong),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.blue, width: 2.5),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: c.blueRing,
                    ),
                  ),
                  Icon(TablerIcons.mapPinFilled, size: 16, color: c.green),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ANAFANYA KAZI', style: k()),
                  Text(kituo, style: v()),
                  Text('$wilaya · $mkoa', style: k()),
                  const SizedBox(height: 14),
                  Text('ANAKWENDA', style: k()),
                  if (destinations.isEmpty)
                    Text('Hajachagua', style: k())
                  else
                    for (final d in destinations) ...[
                      Text(d.$1, style: v()),
                      Text(d.$2, style: k()),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   RANGI
   ============================================================ */
class _DColors {
  final Color page, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, blueRing, green, greenBg, amber, amberBg, red, redBg;

  const _DColors({
    required this.page,
    required this.soft,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.blue,
    required this.blueBg,
    required this.blueRing,
    required this.green,
    required this.greenBg,
    required this.amber,
    required this.amberBg,
    required this.red,
    required this.redBg,
  });

  static const light = _DColors(
    page: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFC3CAD6),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    blueRing: Color(0xFFBBD2F8),
    green: Color(0xFF0F7A52),
    greenBg: Color(0xFFE3F5EC),
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFFFFF1D6),
    red: Color(0xFFC62828),
    redBg: Color(0xFFFDECEC),
  );

  static const dark = _DColors(
    page: Color(0xFF12161D),
    soft: Color(0xFF1C222C),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF465164),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    blueRing: Color(0xFF2B4270),
    green: Color(0xFF5FD49A),
    greenBg: Color(0xFF15302A),
    amber: Color(0xFFF0B35A),
    amberBg: Color(0xFF3A2C14),
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
  );

  static _DColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}
