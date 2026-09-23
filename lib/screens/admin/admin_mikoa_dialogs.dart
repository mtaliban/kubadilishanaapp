import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/* ============================================================
   MODEL
   ============================================================ */
class Mkoa {
  final String id;        // from int, mf. "5"
  final String name;
  final bool active;
  final int? wilayaCount;

  const Mkoa({
    required this.id,
    required this.name,
    this.active = true,
    this.wilayaCount,
  });

  Mkoa copyWith({String? name, bool? active}) => Mkoa(
        id: id,
        name: name ?? this.name,
        active: active ?? this.active,
        wilayaCount: wilayaCount,
      );
}

/* ============================================================
   1. ANGALIA
   ============================================================ */
Future<void> showMkoaViewDialog(
  BuildContext context,
  Mkoa mkoa, {
  VoidCallback? onEdit,
}) {
  return showDialog(
    context: context,
    builder: (ctx) {
      final c = _C.of(ctx);

      return _Shell(
        c: c,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              c: c,
              icon: TablerIcons.mountains,
              iconFg: c.blue,
              iconBg: c.blueBg,
              title: mkoa.name,
              onClose: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 14),
            _Table(c: c, children: [
              _ViewRow(
                c: c,
                label: 'ID',
                value: Text(mkoa.id,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 13,
                        fontFamily: 'monospace')),
              ),
              _ViewRow(c: c, label: 'JINA', value: _val(c, mkoa.name)),
              _ViewRow(
                c: c,
                label: 'HALI',
                value: mkoa.active
                    ? _Pill(label: '● Hai', fg: c.green, bg: c.greenBg)
                    : _Pill(label: '● Imezimwa', fg: c.muted, bg: c.soft),
              ),
              if (mkoa.wilayaCount != null)
                _ViewRow(
                  c: c,
                  label: 'WILAYA',
                  value: _val(c, _fmt(mkoa.wilayaCount!), bold: true),
                ),
            ]),
            _Footer(
              c: c,
              children: [
                const Spacer(),
                _SmallBtn(
                    label: 'Ghairi',
                    fg: c.muted,
                    bg: c.soft,
                    onTap: () => Navigator.pop(ctx)),
                const SizedBox(width: 6),
                _SmallBtn(
                  label: 'Hariri',
                  icon: TablerIcons.pencil,
                  fg: c.blue,
                  bg: c.blueBg,
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit?.call();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/* ============================================================
   2. HARIRI (au ONGEZA ukipitisha mkoa = null)
   ============================================================ */
Future<Mkoa?> showMkoaEditDialog(BuildContext context, {Mkoa? mkoa}) {
  return showDialog<Mkoa>(
    context: context,
    builder: (_) => _EditDialog(original: mkoa),
  );
}

class _EditDialog extends StatefulWidget {
  final Mkoa? original;
  const _EditDialog({this.original});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final Mkoa o =
      widget.original ?? const Mkoa(id: '', name: '');
  late final nameCtrl = TextEditingController(text: o.name);
  late bool active = o.active;

  bool get isNew => widget.original == null;

  int get changes =>
      (nameCtrl.text.trim() != o.name ? 1 : 0) +
      (active != o.active ? 1 : 0);

  bool get canSave => changes > 0 && nameCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      o.copyWith(
        name: nameCtrl.text.trim(),
        active: active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _C.of(context);
    final n = changes;

    return _Shell(
      c: c,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              c: c,
              icon: TablerIcons.mountains,
              iconFg: c.blue,
              iconBg: c.blueBg,
              overline: isNew ? 'Ongeza mkoa' : 'Hariri mkoa',
              title:
                  nameCtrl.text.trim().isEmpty ? '—' : nameCtrl.text.trim(),
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 14),
            _Table(c: c, children: [
              _EditRow(
                c: c,
                label: 'JINA',
                child: _Field(
                  c: c,
                  controller: nameCtrl,
                  icon: TablerIcons.tag,
                  hint: 'mf. Dar es Salaam',
                  capitalization: TextCapitalization.sentences,
                ),
              ),
              _EditRow(
                c: c,
                label: 'HALI',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _SegBtn(
                        c: c,
                        label: 'Hai',
                        icon: TablerIcons.circleCheck,
                        iconColor: c.green,
                        on: active,
                        onTap: () => setState(() => active = true),
                      ),
                      _SegBtn(
                        c: c,
                        label: 'Imezimwa',
                        icon: TablerIcons.circleOff,
                        iconColor: c.muted,
                        on: !active,
                        onTap: () => setState(() => active = false),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            _Footer(
              c: c,
              children: [
                Expanded(
                  child: Text(
                    n == 0 ? 'Hakuna mabadiliko' : 'Mabadiliko $n',
                    style: TextStyle(
                        color: n == 0 ? c.muted : c.blue, fontSize: 12),
                  ),
                ),
                _SmallBtn(
                    label: 'Ghairi',
                    fg: c.muted,
                    bg: c.soft,
                    onTap: () => Navigator.pop(context)),
                const SizedBox(width: 6),
                Opacity(
                  opacity: canSave ? 1 : .45,
                  child: _SmallBtn(
                    label: 'Hifadhi',
                    icon: TablerIcons.deviceFloppy,
                    fg: c.blue,
                    bg: c.blueBg,
                    onTap: canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   3. FUTA
   ============================================================ */
Future<bool> showMkoaDeleteDialog(BuildContext context, Mkoa mkoa) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = _C.of(ctx);

      Widget btn(String label, Color f, Color b, bool v) => Expanded(
            child: _SmallBtn(
              label: label,
              fg: f,
              bg: b,
              expand: true,
              onTap: () => Navigator.pop(ctx, v),
            ),
          );

      return Dialog(
        backgroundColor: c.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 250,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: c.blueBg,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(TablerIcons.mountains,
                            size: 22, color: c.blue),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: c.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.card, width: 2),
                          ),
                          child: const Icon(TablerIcons.trash,
                              size: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: TextStyle(color: c.text, fontSize: 15),
                    children: [
                      const TextSpan(text: 'Futa '),
                      TextSpan(
                          text: mkoa.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text('Haiwezi kutenduliwa',
                    style: TextStyle(color: c.muted, fontSize: 12)),
                const SizedBox(height: 14),
                Row(children: [
                  btn('Hapana', c.muted, c.soft, false),
                  const SizedBox(width: 6),
                  btn('Futa', c.red, c.redBg, true),
                ]),
              ],
            ),
          ),
        ),
      );
    },
  );
  return res ?? false;
}

/* ============================================================
   VIPANDE VINAVYOSHIRIKIWA
   ============================================================ */
String _fmt(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

Widget _val(_C c, String v, {bool bold = false}) => Text(v,
    textAlign: TextAlign.right,
    style: TextStyle(
        color: c.text,
        fontSize: 14,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400));

class _Shell extends StatelessWidget {
  final _C c;
  final Widget child;
  const _Shell({required this.c, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.card,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final _C c;
  final IconData icon;
  final Color iconFg;
  final Color iconBg;
  final String title;
  final String? overline;
  final VoidCallback onClose;

  const _Header({
    required this.c,
    required this.icon,
    required this.iconFg,
    required this.iconBg,
    required this.title,
    required this.onClose,
    this.overline,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 21, color: iconFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(overline!,
                    style: TextStyle(color: c.muted, fontSize: 12)),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.text,
                      fontSize: overline == null ? 18 : 17,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Material(
          color: c.soft,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(TablerIcons.x, size: 16, color: c.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  final _C c;
  final List<Widget> children;
  const _Table({required this.c, required this.children});

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
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

class _ViewRow extends StatelessWidget {
  final _C c;
  final String label;
  final Widget value;
  const _ViewRow(
      {required this.c, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: c.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3)),
          const SizedBox(width: 12),
          Expanded(
              child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final _C c;
  final String label;
  final Widget child;
  const _EditRow(
      {required this.c, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              style: TextStyle(
                  color: c.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final _C c;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool mono;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? formatters;

  const _Field({
    required this.c,
    required this.controller,
    required this.icon,
    required this.hint,
    this.mono = false,
    this.capitalization = TextCapitalization.none,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: controller,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      autocorrect: !mono,
      style: TextStyle(
          color: c.text,
          fontSize: mono ? 13 : 14,
          fontFamily: mono ? 'monospace' : null),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: c.muted.withValues(alpha: .7), fontSize: 14),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        prefixIcon: Icon(icon, size: 17, color: c.blue),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 0),
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final _C c;
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool on;
  final VoidCallback onTap;

  const _SegBtn({
    required this.c,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 30,
          decoration: BoxDecoration(
            color: on ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:
                on ? Border.all(color: c.borderStrong, width: .5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: on ? c.text : c.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final _C c;
  final List<Widget> children;
  const _Footer({required this.c, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 12),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: c.border))),
      child: Row(children: children),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;
  final bool expand;
  final VoidCallback? onTap;

  const _SmallBtn({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.expand = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: expand ? double.infinity : null,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14),
              const SizedBox(width: 5)
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg, bg;
  const _Pill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/* ============================================================
   RANGI
   ============================================================ */
class _C {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg, red, redBg;

  const _C({
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
    required this.red,
    required this.redBg,
  });

  static const light = _C(
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
    red: Color(0xFFC62828),
    redBg: Color(0xFFFDECEC),
  );

  static const dark = _C(
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
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
  );

  static _C of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
