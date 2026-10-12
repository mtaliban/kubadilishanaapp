// ============================================================================
//  admin_profile_page.dart
//  Ukurasa wa Wasifu wa admin (kutazama + kuhariri) — DESIGN MPYA iliyo
//  kupitiwa kutoka mockup (admin_profile_page.dart ya designer), UI kama
//  ilivyo: picha, jina, cheo, kadi ya info 4, fomu (4 zinaharirika zote),
//  Ghairi/Hifadhi chini-kulia. Hifadhi halisi: onSave(callback) inaitwa.
//
//  [onSave] irudishe true ikifanikiwa (ukurasa utarudi kwenye hali ya
//  kutazama na values mpya zitarudiwa kwenye kadi ya info).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

// Rangi za app (bluu ya app, si bluu angavu)
const Color _blue = Color(0xFF1E40AF);
const Color _bluePale = Color(0xFFEEF2FF);
const Color _text = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _hint = Color(0xFF9CA3AF);
const Color _line = Color(0xFFE5E7EB);
const Color _fieldBorder = Color(0xFFDDDCF3);
const Color _red = Color(0xFFDC2626);

// ── DARK tokens (hali ya giza — zinatumika wakati ThemeProvider.dark) ────
const Color _textD = Color(0xFFE7ECF8);
const Color _mutedD = Color(0xFF9AA8C7);
const Color _hintD = Color(0xFF7B8DA5);
const Color _lineD = Color(0xFF2A3240);
const Color _fieldBorderD = Color(0xFF334155);
const Color _bluePaleD = Color(0xFF1C2A44);
const Color _blueD = Color(0xFF7AA7FF);

Color _textT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _textD : _text;
Color _mutedT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _mutedD : _muted;
Color _hintT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _hintD : _hint;
Color _lineT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _lineD : _line;
Color _fieldBorderT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _fieldBorderD : _fieldBorder;
Color _bluePaleT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _bluePaleD : _bluePale;
Color _blueT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _blueD : _blue;

/// Ukurasa wa Wasifu wa admin (kutazama + kuhariri).
/// UI tu: weka logic yako ya kuhifadhi ndani ya [onSave].
/// [onSave] irudishe true ikifanikiwa (ukurasa utarudi kwenye hali ya kutazama).
class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({
    super.key,
    required this.fullName,
    required this.phone,
    required this.onSave,
    this.whatsapp,
    this.email,
    this.role = 'Administrator',
  });

  final String fullName;
  final String phone;
  final String? whatsapp;
  final String? email;
  final String role;
  final Future<bool> Function(
    String fullName,
    String phone,
    String whatsapp,
    String email,
  ) onSave;

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _phoneC;
  late final TextEditingController _waC;
  late final TextEditingController _mailC;

  late String _name;
  late String _phone;
  late String _wa;
  late String _mail;
  bool _edit = false;
  bool _saving = false;

  static final _phoneRe = RegExp(r'^(0|\+?255)\d{9}$');
  static final _mailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _name = widget.fullName;
    _phone = widget.phone;
    _wa = widget.whatsapp ?? '';
    _mail = widget.email ?? '';
    _nameC = TextEditingController();
    _phoneC = TextEditingController();
    _waC = TextEditingController();
    _mailC = TextEditingController();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _waC.dispose();
    _mailC.dispose();
    super.dispose();
  }

  String get _initials {
    final parts =
        _name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  void _startEdit() {
    _nameC.text = _name;
    _phoneC.text = _phone;
    _waC.text = _wa;
    _mailC.text = _mail;
    setState(() => _edit = true);
  }

  void _cancel() => setState(() => _edit = false);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(
      _nameC.text.trim(),
      _phoneC.text.trim(),
      _waC.text.trim(),
      _mailC.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _name = _nameC.text.trim();
        _phone = _phoneC.text.trim();
        _wa = _waC.text.trim();
        _mail = _mailC.text.trim();
        _edit = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 18),
              child:              Column(
                children: [
                  _edit ? _editTopBar() : _viewTopBar(),
                  _header(small: _edit),
                  _edit ? _form() : _infoCard(),
                ],
              ),
            ),
          ),
        ),
      ),
      // ⭐ VITUFE VYA KUDUMU (Ghairi / Hifadhi) — nje YA scroll view, chini
      // KAILE KAILE ya screen. Shida ya awali: vitufe vilikuwa vitu vya
      // mwisho ndani ya fomu — keyboard ikifunguka (baada ya 'Hariri')
      // vilifunikwa/kusukuma nje ya screen. Sasa ni bar ya footer:
      // inaonekana mara moja 'Hariri' ikibonyezwa, keyboard ikiwa wazi au la.
      bottomNavigationBar: _edit ? _actionBar() : null,
    );
  }

  // ---------- Juu ----------
  Widget _viewTopBar() {
    // Hakuna mshale wa rudi — Wasifu ni screen/tab ya AdminShell, haifunguliwi
    // kwa Navigator.push; kurudi kunafanyika kwa drawer/footer ya shell.
    return _TopBar(
      title: 'Wasifu',
      leading: const SizedBox(width: 40),
      trailing: InkWell(
        onTap: _startEdit,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _bluePale,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: const Icon(TablerIcons.pencil, size: 15, color: _blue),
        ),
      ),
    );
  }

  Widget _editTopBar() {
    return _TopBar(
      title: 'Hariri wasifu',
      leading: IconButton(
        icon: const Icon(TablerIcons.x, size: 22, color: _text),
        onPressed: _cancel,
      ),
    );
  }

  // ---------- Picha, jina, cheo ----------
  Widget _header({required bool small}) {
    final size = small ? 48.0 : 64.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _bluePaleT(context),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                fontSize: small ? 17 : 22,
                fontWeight: FontWeight.w500,
                color: _blueT(context),
              ),
            ),
          ),
          SizedBox(height: small ? 8 : 10),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _textT(context),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _bluePaleT(context),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.role,
              style: TextStyle(fontSize: 11, color: _blueT(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Kutazama ----------
  Widget _infoCard() {
    final rows = <_Info>[
      _Info(TablerIcons.user, 'Jina kamili', _name),
      _Info(TablerIcons.phone, 'Namba ya simu', _phone),
      _Info(TablerIcons.messageCircle, 'WhatsApp', _wa),
      _Info(TablerIcons.mail, 'Barua pepe', _mail),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lineT(context)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            _InfoRow(info: rows[i], showDivider: i != rows.length - 1),
        ],
      ),
    );
  }

  // ---------- Kuhariri (sehemu zote zinahaririwa) ----------
  Widget _form() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EditField(
              label: 'Jina kamili',
              hint: 'Jina la kwanza na la ukoo',
              icon: TablerIcons.user,
              controller: _nameC,
              keyboardType: TextInputType.name,
              capitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Weka jina kamili' : null,
            ),
            _EditField(
              label: 'Namba ya simu',
              hint: '0712345678',
              icon: TablerIcons.phone,
              controller: _phoneC,
              keyboardType: TextInputType.phone,
              validator: (v) {
                final t = (v ?? '').replaceAll(' ', '');
                return _phoneRe.hasMatch(t) ? null : 'Namba ya simu si sahihi';
              },
            ),
            _EditField(
              label: 'WhatsApp',
              hint: '0712345678',
              icon: TablerIcons.messageCircle,
              controller: _waC,
              keyboardType: TextInputType.phone,
              validator: (v) {
                final t = (v ?? '').replaceAll(' ', '');
                if (t.isEmpty) return null; // si lazima
                return _phoneRe.hasMatch(t) ? null : 'Namba ya WhatsApp si sahihi';
              },
            ),
            _EditField(
              label: 'Barua pepe',
              hint: 'jina@mfano.com',
              icon: TablerIcons.mail,
              controller: _mailC,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // si lazima
                return _mailRe.hasMatch(t) ? null : 'Barua pepe si sahihi';
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Bar ya kudumu ya chini: Ghairi + Hifadhi — KUSHOTO (kama mockup).
  /// Iko kwenye Scaffold.bottomNavigationBar: HAIFIKA kwenye scroll,
  /// HAIFUNIKWA na keyboard (Material inai-push juu ya keyboard).
  Widget _actionBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        // Dark: rangi SAWA na scaffold (0xFF0F172A) — hakuna 'div' tofauti
        // inayoonekana kama kanda nyuma ya buttons.
        color: dark ? const Color(0xFF0F172A) : Colors.white,
        // Border top imefutwa — bar iko safi (mockup hauna mstari).
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            // KUSHOTO: buttons zinaanza mwanzo wa Row (si kulia).
            // Zote wrap-content (upana wa text+icon tu) na haziwezi kutoka
            // screen — Ghairi KISHOTO, Hifadhi mbele yake.
            children: [
              // Ghairi — upana wa content tu (mfupi).
              TextButton.icon(
                onPressed: _saving ? null : _cancel,
                icon: Icon(TablerIcons.x, size: 15, color: _mutedT(context)),
                label: Text(
                  'Ghairi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textT(context),
                  ),
                ),
                style: TextButton.styleFrom(
                  // VITUFE VIDOGO: minimumSize ya DEFAULT ya Material (64×36)
                  // ndiyo chanzo cha 'div kubwa' — imepunguzwa 0×28 +
                  // tapTargetSize.shrinkWrap. Height halisi 28.
                  // BORDER DARK-AWARE: ilikuwa #D1D5DB (kijivu kipya, ilikuwa
                  // 'div' nyeupe kwenye dark) — kwenye dark utumia _lineD.
                  side: BorderSide(color: _lineT(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              // Hifadhi — KULIA bluu, upana wa content tu (mfupi).
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(TablerIcons.deviceFloppy, size: 15),
                label: const Text(
                  'Hifadhi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFC7D2FE),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // Hifadhi pia ndogo — height halisi 28 (minimumSize BAIASI).
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.leading, this.trailing});
  final String title;
  final Widget leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: leading),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _textT(context),
              ),
            ),
            if (trailing != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: trailing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Info {
  const _Info(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.info, required this.showDivider});
  final _Info info;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final empty = info.value.trim().isEmpty;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final divider = dark ? const Color(0xFF2A3240) : const Color(0xFFF3F4F6);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: divider))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _bluePaleT(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(info.icon, size: 17, color: _blueT(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  style: TextStyle(fontSize: 10.5, color: _mutedT(context)),
                ),
                const SizedBox(height: 1),
                Text(
                  empty ? 'Haijawekwa' : info.value,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: empty ? _hintT(context) : _textT(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.validator,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final String? Function(String?)? validator;

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _mutedT(context),
            ),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            validator: validator,
            style: TextStyle(fontSize: 13, color: _textT(context)),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13, color: _hintT(context)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Icon(icon, size: 17, color: _blueT(context)),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 20),
              errorStyle: const TextStyle(fontSize: 11, color: _red),
              enabledBorder: _border(_fieldBorderT(context)),
              focusedBorder: _border(_blueT(context), 1.2),
              errorBorder: _border(_red),
              focusedErrorBorder: _border(_red, 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
