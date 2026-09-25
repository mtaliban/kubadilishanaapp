import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/* ============================================================
   MODEL
   ============================================================ */
class AdminProfile {
  final String name;
  final String role;
  final String email;
  final bool emailVerified;
  final String phone;
  final String? whatsapp;

  const AdminProfile({
    required this.name,
    this.role = 'Administrator',
    required this.email,
    this.emailVerified = true,
    required this.phone,
    this.whatsapp,
  });

  AdminProfile copyWith({String? name, String? whatsapp, bool clearWhatsapp = false}) {
    return AdminProfile(
      name: name ?? this.name,
      role: role,
      email: email,
      emailVerified: emailVerified,
      phone: phone,
      whatsapp: clearWhatsapp ? null : (whatsapp ?? this.whatsapp),
    );
  }
}

// Backward-compat alias used by admin_shell.dart
typedef AdminProfileData = AdminProfile;

/* ============================================================
   RANGI (light + dark)
   ============================================================ */
class ProfileColors {
  final Color page, card, soft, border, borderStrong, text, muted, faint;
  final Color blue, blueBg, blueRing, green;

  const ProfileColors({
    required this.page,
    required this.card,
    required this.soft,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.faint,
    required this.blue,
    required this.blueBg,
    required this.blueRing,
    required this.green,
  });

  static const light = ProfileColors(
    page: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFCFD5DF),
    text: Color(0xFF141A24),
    muted: Color(0xFF667085),
    faint: Color(0xFF98A2B3),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    blueRing: Color(0xFFBBD2F8),
    green: Color(0xFF0F7A52),
  );

  static const dark = ProfileColors(
    page: Color(0xFF0F1319),
    card: Color(0xFF181D26),
    soft: Color(0xFF212833),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF3A4454),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFF9AA4B5),
    faint: Color(0xFF6B7587),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    blueRing: Color(0xFF2B4270),
    green: Color(0xFF5FD49A),
  );

  static ProfileColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/* ============================================================
   UKURASA WA WASIFU
   ============================================================ */
class AdminProfilePage extends StatefulWidget {
  final AdminProfile profile;

  /// Inaitwa ukibonyeza Hifadhi.
  final Future<void> Function(AdminProfile updated)? onSave;

  const AdminProfilePage({super.key, required this.profile, this.onSave});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

// Backward-compat alias used by admin_shell.dart
typedef AdminProfileScreen = AdminProfilePage;

class _AdminProfilePageState extends State<AdminProfilePage> {
  late AdminProfile p;
  bool editing = false;
  bool saving = false;

  final nameCtrl = TextEditingController();
  final waCtrl = TextEditingController();
  String _origName = '';
  String _origWa = '';

  @override
  void initState() {
    super.initState();
    p = widget.profile;
    nameCtrl.addListener(_onChange);
    waCtrl.addListener(_onChange);
  }

  void _onChange() {
    if (editing) setState(() {});
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    waCtrl.dispose();
    super.dispose();
  }

  /* ---------- Msaidizi ---------- */
  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String _local9(String phone) {
    var d = _digits(phone);
    if (d.startsWith('255')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 9) {
      return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
    }
    return d;
  }

  static String _pretty(String phone) => '+255 ${_local9(phone)}';
  static String _intl(String phone) => '255${_digits(_local9(phone))}';

  static String _titleCase(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  bool get _hasWa => (p.whatsapp ?? '').trim().isNotEmpty;
  bool get _hasEmail => p.email.trim().isNotEmpty;

  int get _changes =>
      (nameCtrl.text.trim() != _origName ? 1 : 0) +
      (_digits(waCtrl.text) != _digits(_origWa) ? 1 : 0);

  bool get _canSave =>
      !saving && _changes > 0 && nameCtrl.text.trim().isNotEmpty;

  /// Namba ya WhatsApp kama tarakimu 9 (mf. 712345678), au null kama acha tupu.
  String? get _waNine {
    var d = _digits(waCtrl.text);
    if (d.startsWith('255')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d.length == 9 ? d : null;
  }

  /* ---------- Vitendo ---------- */
  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _startEdit() {
    _origName = _titleCase(p.name);
    _origWa = _hasWa ? _local9(p.whatsapp!) : '';
    nameCtrl.text = _origName;
    waCtrl.text = _origWa;
    setState(() => editing = true);
  }

  void _cancel() => setState(() => editing = false);

  Future<void> _save() async {
    final name = _titleCase(nameCtrl.text.trim());
    final wa = _digits(waCtrl.text);
    final nine = _waNine;
    if (wa.isNotEmpty && nine == null) {
      return _toast('Namba ya WhatsApp iwe tarakimu 9 baada ya +255');
    }
    // phone_alt huhifadhiwa kama '255XXXXXXXXX'. Kufuta WhatsApp
    // lazima pitie null kwenye payload (ui: 'phone_alt': null).
    final updated = nine == null
        ? p.copyWith(name: name, clearWhatsapp: true)
        : p.copyWith(name: name, whatsapp: '255$nine');

    setState(() => saving = true);
    try {
      await widget.onSave?.call(updated);
      if (!mounted) return;
      setState(() {
        p = updated;
        editing = false;
      });
      _toast('Mabadiliko yamehifadhiwa');
    } catch (e) {
      if (mounted) _toast('Imeshindikana kuhifadhi: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(ClipboardData(text: p.email));
    _toast('Barua pepe imenakiliwa');
  }

  Future<void> _call() async {
    if (!await launchUrl(Uri(scheme: 'tel', path: '0${_digits(_local9(p.phone))}'))) {
      _toast('Imeshindikana kufungua dialer');
    }
  }

  Future<void> _whatsapp() async {
    if (!_hasWa) return;
    if (!await launchUrl(
      Uri.parse('https://wa.me/${_intl(p.whatsapp!)}'),
      mode: LaunchMode.externalApplication,
    )) {
      _toast('Imeshindikana kufungua WhatsApp');
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = ProfileColors.of(context);
    return PopScope(
      canPop: !editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && editing) _cancel();
      },
      child: Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: editing ? _editTopBar(c) : _viewTopBar(c),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (box.maxHeight - 16).clamp(0, double.infinity),
                      ),
                      child: Center(
                        child: editing ? _editBody(c) : _viewBody(c),
                      ),
                    ),
                  ),
                ),
              ),
              if (editing) _footer(c),
            ],
          ),
        ),
      ),
    );
  }

  /* ================= KUANGALIA ================= */
  Widget _viewTopBar(ProfileColors c) {
    return Row(
      children: [
        _SquareButton(
          icon: PhosphorIcons.caretLeft(),
          c: c,
          tooltip: 'Rudi',
          onTap: () => Navigator.maybePop(context),
        ),
        const Spacer(),
        SizedBox(
          height: 36,
          child: FilledButton.icon(
            onPressed: _startEdit,
            icon: Icon(PhosphorIcons.pencilSimple(), size: 16),
            label: const Text('Hariri'),
            style: FilledButton.styleFrom(
              backgroundColor: c.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _viewBody(ProfileColors c) {
    final name = _titleCase(p.name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
          child: Column(
            children: [
              Text(name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      height: 1.3)),
              const SizedBox(height: 8),
              _RolePill(role: p.role, c: c),
            ],
          ),
        ),

        _GroupTitle('TAARIFA BINAFSI', c: c),
        _Group(c: c, children: [
          _ViewRow(
            c: c,
            icon: PhosphorIcons.user(),
            label: 'Jina kamili',
            value: name,
          ),
        ]),

        _GroupTitle('MAWASILIANO', c: c),
        _Group(c: c, children: [
          _ViewRow(
            c: c,
            icon: PhosphorIcons.envelope(),
            label: 'Barua pepe',
            labelExtra: p.emailVerified && _hasEmail
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                          size: 13, color: c.green),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text('Imethibitishwa',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )
                : null,
            value: _hasEmail ? p.email : 'Haijawekwa',
            empty: !_hasEmail,
            action: _CircleAction(
              icon: PhosphorIcons.copy(),
              c: c,
              tooltip: 'Nakili',
              onTap: _hasEmail ? _copyEmail : null,
            ),
          ),
          _ViewRow(
            c: c,
            icon: PhosphorIcons.phone(),
            label: 'Namba ya simu',
            value: _pretty(p.phone),
            action: _CircleAction(
              icon: PhosphorIcons.phoneCall(),
              c: c,
              tooltip: 'Piga',
              onTap: _call,
            ),
          ),
          _ViewRow(
            c: c,
            icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
            label: 'WhatsApp / simu ya pili',
            value: _hasWa ? _pretty(p.whatsapp!) : 'Haijawekwa',
            empty: !_hasWa,
            action: _CircleAction(
              icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
              c: c,
              tooltip: 'WhatsApp',
              onTap: _hasWa ? _whatsapp : null,
            ),
          ),
        ]),
      ],
    );
  }

  /* ================= KUHARIRI ================= */
  Widget _editTopBar(ProfileColors c) {
    return Row(
      children: [
        _SquareButton(
          icon: PhosphorIcons.x(),
          c: c,
          tooltip: 'Funga',
          onTap: _cancel,
        ),
        Expanded(
          child: Text('Hariri wasifu',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _editBody(ProfileColors c) {
    final liveName =
        nameCtrl.text.trim().isEmpty ? '—' : nameCtrl.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 2),
          child: Column(
            children: [
              Text(liveName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(p.role, style: TextStyle(color: c.blue, fontSize: 12)),
            ],
          ),
        ),

        _GroupTitle('UNAWEZA KUBADILISHA', c: c,
            icon: PhosphorIcons.pencil()),
        _Group(
          c: c,
          padding: const EdgeInsets.all(14),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FieldLabel('Jina kamili', c: c),
                _EditField(
                  c: c,
                  controller: nameCtrl,
                  icon: PhosphorIcons.user(),
                  capitalization: TextCapitalization.words,
                  clearable: true,
                ),
                const SizedBox(height: 14),
                _FieldLabel('WhatsApp / simu ya pili', c: c,
                    trailing: 'hiari'),
                _EditField(
                  c: c,
                  controller: waCtrl,
                  icon: PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
                  prefix255: true,
                  keyboard: TextInputType.phone,
                  hint: '712 345 678',
                ),
                const SizedBox(height: 6),
                Text('Acha tupu kama huna namba ya pili.',
                    style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ],
        ),

        _GroupTitle('HAZIWEZI KUBADILISHWA', c: c,
            icon: PhosphorIcons.lockSimple()),
        _Group(c: c, children: [
          _LockedRow(
            c: c,
            icon: PhosphorIcons.envelope(),
            text: _hasEmail ? p.email : 'Haijawekwa',
          ),
          _LockedRow(
              c: c,
              icon: PhosphorIcons.phone(),
              text: _pretty(p.phone)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text('Kubadilisha hizi, wasiliana na admin mwenzako.',
              style: TextStyle(color: c.muted, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _footer(ProfileColors c) {
    final n = _changes;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              n == 0 ? 'Hakuna mabadiliko' : 'Mabadiliko $n',
              style: TextStyle(
                  color: n == 0 ? c.muted : c.blue,
                  fontSize: 12,
                  fontWeight:
                      n == 0 ? FontWeight.w400 : FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: saving ? null : _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: c.blue,
                side: BorderSide(color: c.blueRing),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: const Text('Ghairi'),
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: _canSave || saving ? 1 : .45,
            child: SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: c.blue,
                  disabledBackgroundColor: c.blue,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIcons.floppyDisk(), size: 16),
                          const SizedBox(width: 6),
                          const Text('Hifadhi'),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _SquareButton extends StatelessWidget {
  final IconData icon;
  final ProfileColors c;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareButton({
    required this.icon,
    required this.c,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.blueBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: c.blue),
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  final ProfileColors c;
  const _RolePill({required this.role, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.blueBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.shieldCheck(), size: 14, color: c.blue),
          const SizedBox(width: 5),
          Text(role,
              style: TextStyle(
                  color: c.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String text;
  final ProfileColors c;
  final IconData? icon;
  const _GroupTitle(this.text, {required this.c, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c.blue),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: TextStyle(
                  color: c.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .3)),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final ProfileColors c;
  final List<Widget> children;
  final EdgeInsets? padding;

  const _Group({required this.c, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, color: c.border));
      items.add(children[i]);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    );
  }
}

class _ViewRow extends StatelessWidget {
  final ProfileColors c;
  final IconData icon;
  final String label;
  final Widget? labelExtra;
  final String value;
  final bool empty;
  final Widget? action;

  const _ViewRow({
    required this.c,
    required this.icon,
    required this.label,
    this.labelExtra,
    required this.value,
    this.empty = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 62),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text.rich na WidgetSpan: lebo na beji (mf.
                  // "Imethibitishwa") zinafunga/kupishana mstari kwenye
                  // skrini ndogo — hakuna RenderFlex inayoweza kumwaga.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: label,
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                        if (labelExtra != null)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            baseline: TextBaseline.alphabetic,
                            child: labelExtra!,
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: empty
                              ? c.blue.withValues(alpha: .55)
                              : c.blue,
                          fontSize: 14,
                          fontWeight: empty
                              ? FontWeight.w400
                              : FontWeight.w600)),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final ProfileColors c;
  final String tooltip;
  final VoidCallback? onTap;

  const _CircleAction({
    required this.icon,
    required this.c,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: c.blueBg,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(icon, size: 17, color: c.blue),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final ProfileColors c;
  final String? trailing;
  const _FieldLabel(this.text, {required this.c, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final ProfileColors c;
  final TextEditingController controller;
  final IconData icon;
  final bool prefix255;
  final bool clearable;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final String? hint;

  const _EditField({
    required this.c,
    required this.controller,
    required this.icon,
    this.prefix255 = false,
    this.clearable = false,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: col, width: w),
        );
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      style: TextStyle(color: c.blue, fontSize: 15),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.faint, fontSize: 15),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c.blue),
              if (prefix255) ...[
                const SizedBox(width: 10),
                Text('+255',
                    style: TextStyle(color: c.blue, fontSize: 15)),
                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: c.border),
              ],
            ],
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: clearable && controller.text.isNotEmpty
            ? IconButton(
                onPressed: controller.clear,
                icon: Icon(PhosphorIcons.x(), size: 16, color: c.blue),
              )
            : null,
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  final ProfileColors c;
  final IconData icon;
  final String text;

  const _LockedRow({required this.c, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: .7,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: c.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.blue, fontSize: 13)),
            ),
            Icon(PhosphorIcons.lockSimple(), size: 15, color: c.blue),
          ],
        ),
      ),
    );
  }
}
