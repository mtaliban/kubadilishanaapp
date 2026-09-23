import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/* ============================================================
   KICHUJIO
   ============================================================ */
class UserFilter {
  final String? idara; // afya / elimu / kilimo / umma
  final String? mkoa;
  final String? wilaya;
  final String? kituo; // au somo, kama idara ni elimu

  const UserFilter({this.idara, this.mkoa, this.wilaya, this.kituo});

  bool get isEmpty => idara == null && mkoa == null && wilaya == null && kituo == null;
}

/// Inafungua dirisha la vichujio kutoka chini.
/// [onChanged] inaitwa kila unapobadilisha kitu (orodha ichujwe papo hapo).
/// Inarudisha kichujio cha mwisho dirisha likifungwa.
Future<UserFilter> showUserFilterSheet(
  BuildContext context, {
  UserFilter initial = const UserFilter(),
  ValueChanged<UserFilter>? onChanged,
  required List<String> mikoa,
  required Map<String, List<String>> wilaya, // mkoa -> wilaya
  Map<String, List<String>> vituo = const {}, // wilaya -> vituo
  List<String> masomo = const [],
}) async {
  var last = initial;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FilterSheet(
      initial: initial,
      mikoa: mikoa,
      wilaya: wilaya,
      vituo: vituo,
      masomo: masomo,
      onChanged: (f) {
        last = f;
        onChanged?.call(f);
      },
    ),
  );
  return last;
}

/* ============================================================
   DATA YA IDARA
   ============================================================ */
enum _Tone { blue, green, amber }

class _Opt {
  final String? value;
  final String label;
  final IconData icon;
  final _Tone tone;
  const _Opt(this.value, this.label, this.icon, [this.tone = _Tone.blue]);
}

const _idara = [
  _Opt(null, 'Idara zote', TablerIcons.layoutGrid),
  _Opt('afya', 'Afya', TablerIcons.heartRateMonitor, _Tone.green),
  _Opt('elimu', 'Elimu', TablerIcons.school),
  _Opt('kilimo', 'Kilimo na ufugaji', TablerIcons.plant2, _Tone.green),
  _Opt('umma', 'Watumishi wa umma', TablerIcons.buildingBank, _Tone.amber),
];

bool _isHealth(String s) =>
    RegExp(r'health|hospital|zahanati|kituo cha afya', caseSensitive: false).hasMatch(s);

/* ============================================================
   DIRISHA
   ============================================================ */
class _FilterSheet extends StatefulWidget {
  final UserFilter initial;
  final List<String> mikoa;
  final Map<String, List<String>> wilaya;
  final Map<String, List<String>> vituo;
  final List<String> masomo;
  final ValueChanged<UserFilter> onChanged;

  const _FilterSheet({
    required this.initial,
    required this.mikoa,
    required this.wilaya,
    required this.vituo,
    required this.masomo,
    required this.onChanged,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? idara = widget.initial.idara;
  late String? mkoa = widget.initial.mkoa;
  late String? wilaya = widget.initial.wilaya;
  late String? kituo = widget.initial.kituo;
  String? open;

  void _emit() => widget.onChanged(
      UserFilter(idara: idara, mkoa: mkoa, wilaya: wilaya, kituo: kituo));

  void _clear() => setState(() {
        idara = mkoa = wilaya = kituo = null;
        open = null;
        _emit();
      });

  @override
  Widget build(BuildContext context) {
    final c = _FColors.of(context);
    final any = idara != null || mkoa != null || wilaya != null || kituo != null;
    final elimu = idara == 'elimu';

    final mkoaOpts = [
      const _Opt(null, 'Mikoa yote', TablerIcons.mapPin),
      ...widget.mikoa.map((m) => _Opt(m, m, TablerIcons.mapPin)),
    ];
    final wilayaOpts = [
      const _Opt(null, 'Wilaya zote', TablerIcons.buildingCommunity),
      ...(widget.wilaya[mkoa] ?? const <String>[])
          .map((w) => _Opt(w, w, TablerIcons.buildingCommunity)),
    ];
    final lastOpts = elimu
        ? [
            const _Opt(null, 'Masomo yote', TablerIcons.books),
            ...widget.masomo.map((m) => _Opt(m, m, TablerIcons.book2)),
          ]
        : [
            const _Opt(null, 'Vituo vyote', TablerIcons.building),
            ...(widget.vituo[wilaya] ?? const <String>[]).map((k) => _Opt(
                  k,
                  k,
                  _isHealth(k) ? TablerIcons.buildingHospital : TablerIcons.school,
                  _isHealth(k) ? _Tone.green : _Tone.blue,
                )),
          ];

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kishikio
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: c.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Kichwa
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Icon(TablerIcons.filter, size: 20, color: c.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Vichujio',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ),
                  Opacity(
                    opacity: any ? 1 : .5,
                    child: _SmallButton(
                      icon: TablerIcons.refresh,
                      label: 'Futa vyote',
                      fg: c.blue,
                      bg: any ? c.blueBg : Colors.transparent,
                      onTap: any ? _clear : null,
                    ),
                  ),
                ],
              ),
            ),

            // Dropdown
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Label('IDARA', c: c),
                    _Dropdown(
                      c: c,
                      options: _idara,
                      value: idara,
                      open: open == 'idara',
                      onToggle: () => setState(
                          () => open = open == 'idara' ? null : 'idara'),
                      onPick: (v) => setState(() {
                        if (v != idara) kituo = null;
                        idara = v;
                        open = null;
                        _emit();
                      }),
                    ),
                    _Label('MKOA', c: c),
                    _Dropdown(
                      c: c,
                      options: mkoaOpts,
                      value: mkoa,
                      open: open == 'mkoa',
                      onToggle: () =>
                          setState(() => open = open == 'mkoa' ? null : 'mkoa'),
                      onPick: (v) => setState(() {
                        if (v != mkoa) {
                          wilaya = null;
                          if (!elimu) kituo = null;
                        }
                        mkoa = v;
                        open = null;
                        _emit();
                      }),
                    ),
                    _Label('WILAYA', c: c),
                    _Dropdown(
                      c: c,
                      options: wilayaOpts,
                      value: wilaya,
                      enabled: mkoa != null,
                      disabledHint: 'Chagua mkoa kwanza',
                      open: open == 'wilaya',
                      onToggle: () => setState(
                          () => open = open == 'wilaya' ? null : 'wilaya'),
                      onPick: (v) => setState(() {
                        if (v != wilaya && !elimu) kituo = null;
                        wilaya = v;
                        open = null;
                        _emit();
                      }),
                    ),
                    _Label(elimu ? 'MASOMO' : 'KITUO', c: c),
                    _Dropdown(
                      c: c,
                      options: lastOpts,
                      value: kituo,
                      enabled: elimu || wilaya != null,
                      disabledHint: 'Chagua wilaya kwanza',
                      open: open == 'kituo',
                      onToggle: () => setState(
                          () => open = open == 'kituo' ? null : 'kituo'),
                      onPick: (v) => setState(() {
                        kituo = v;
                        open = null;
                        _emit();
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // Funga (chembamba, kulia)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _SmallButton(
                    icon: TablerIcons.x,
                    label: 'Funga',
                    fg: c.muted,
                    bg: c.soft,
                    onTap: () => Navigator.pop(context),
                  ),
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
   VIPANDE VIDOGO
   ============================================================ */
class _Label extends StatelessWidget {
  final String text;
  final _FColors c;
  const _Label(this.text, {required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text,
          style: TextStyle(
              color: c.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: .3)),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg, bg;
  final VoidCallback? onTap;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 30),
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

class _IconTile extends StatelessWidget {
  final IconData icon;
  final _Tone tone;
  final _FColors c;
  const _IconTile({required this.icon, required this.tone, required this.c});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = c.tone(tone);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: fg),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final _FColors c;
  final List<_Opt> options;
  final String? value;
  final bool open;
  final bool enabled;
  final String? disabledHint;
  final VoidCallback onToggle;
  final ValueChanged<String?> onPick;

  const _Dropdown({
    required this.c,
    required this.options,
    required this.value,
    required this.open,
    required this.onToggle,
    required this.onPick,
    this.enabled = true,
    this.disabledHint,
  });

  @override
  Widget build(BuildContext context) {
    final sel = options.firstWhere((o) => o.value == value,
        orElse: () => options.first);
    final isOpen = open && enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: enabled ? c.card : c.soft,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onToggle : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isOpen ? c.blue : c.borderStrong,
                    width: isOpen ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  _IconTile(icon: sel.icon, tone: sel.tone, c: c),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      enabled ? sel.label : (disabledHint ?? sel.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: enabled ? c.text : c.muted, fontSize: 15),
                    ),
                  ),
                  Icon(isOpen ? TablerIcons.chevronUp : TablerIcons.chevronDown,
                      size: 18, color: c.muted),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          child: !isOpen
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderStrong),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
                    itemBuilder: (_, i) {
                      final o = options[i];
                      final picked = o.value == value;
                      return Material(
                        color: picked ? c.blueBg : c.card,
                        child: InkWell(
                          onTap: () => onPick(o.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                _IconTile(icon: o.icon, tone: o.tone, c: c),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(o.label,
                                      style: TextStyle(
                                          color: c.text, fontSize: 14)),
                                ),
                                if (picked)
                                  Icon(TablerIcons.check, size: 18, color: c.blue),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/* ============================================================
   RANGI
   ============================================================ */
class _FColors {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg;

  const _FColors({
    required this.card,
    required this.soft,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.blue,
    required this.blueBg,
    required this.green,
    required this.greenBg,
    required this.amber,
    required this.amberBg,
  });

  static const light = _FColors(
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFC3CAD6),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    green: Color(0xFF0F7A52),
    greenBg: Color(0xFFE3F5EC),
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFFFFF1D6),
  );

  static const dark = _FColors(
    card: Color(0xFF181D26),
    soft: Color(0xFF212833),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF465164),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    green: Color(0xFF5FD49A),
    greenBg: Color(0xFF15302A),
    amber: Color(0xFFF0B35A),
    amberBg: Color(0xFF3A2C14),
  );

  static _FColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}
