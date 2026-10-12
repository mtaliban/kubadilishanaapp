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

// Rangi za app (bluu ya app, si bluu angavu)
const Color _blue = Color(0xFF1E40AF);
const Color _bluePale = Color(0xFFEEF2FF);
const Color _text = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _hint = Color(0xFF9CA3AF);
const Color _line = Color(0xFFE5E7EB);
const Color _fieldBorder = Color(0xFFDDDCF3);
const Color _red = Color(0xFFDC2626);

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            children: [
              _edit ? _editTopBar() : _viewTopBar(),
              _header(small: _edit),
              _edit ? _form() : _infoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Juu ----------
  Widget _viewTopBar() {
    return _TopBar(
      title: 'Wasifu',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _text),
        onPressed: () => Navigator.maybePop(context),
      ),
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
          child: const Icon(Icons.edit_outlined, size: 16, color: _blue),
        ),
      ),
    );
  }

  Widget _editTopBar() {
    return _TopBar(
      title: 'Hariri wasifu',
      leading: IconButton(
        icon: const Icon(Icons.close, color: _text),
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
              color: _bluePale,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                fontSize: small ? 17 : 22,
                fontWeight: FontWeight.w500,
                color: _blue,
              ),
            ),
          ),
          SizedBox(height: small ? 8 : 10),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _bluePale,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.role,
              style: const TextStyle(fontSize: 11, color: _blue),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Kutazama ----------
  Widget _infoCard() {
    final rows = <_Info>[
      _Info(Icons.person_outline, 'Jina kamili', _name),
      _Info(Icons.phone_outlined, 'Namba ya simu', _phone),
      _Info(Icons.chat_outlined, 'WhatsApp', _wa),
      _Info(Icons.mail_outline, 'Barua pepe', _mail),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
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
              icon: Icons.person_outline,
              controller: _nameC,
              keyboardType: TextInputType.name,
              capitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Weka jina kamili' : null,
            ),
            _EditField(
              label: 'Namba ya simu',
              hint: '0712345678',
              icon: Icons.phone_outlined,
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
              icon: Icons.chat_outlined,
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
              icon: Icons.mail_outline,
              controller: _mailC,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // si lazima
                return _mailRe.hasMatch(t) ? null : 'Barua pepe si sahihi';
              },
            ),
            const SizedBox(height: 2),
            // Vitufe vidogo, kulia, chini ya fomu moja kwa moja
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _cancel,
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('Ghairi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
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
                        // Ikoni ya kuhifadhi (si tiki)
                        : const Icon(Icons.save_outlined, size: 15),
                    label: const Text('Hifadhi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFC7D2FE),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _text,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _bluePale,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(info.icon, size: 17, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  style: const TextStyle(fontSize: 10.5, color: _muted),
                ),
                const SizedBox(height: 1),
                Text(
                  empty ? 'Haijawekwa' : info.value,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: empty ? _hint : _text,
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            validator: validator,
            style: const TextStyle(fontSize: 13, color: _text),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: _hint),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Icon(icon, size: 17, color: _blue),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 20),
              errorStyle: const TextStyle(fontSize: 11, color: _red),
              enabledBorder: _border(_fieldBorder),
              focusedBorder: _border(_blue, 1.2),
              errorBorder: _border(_red),
              focusedErrorBorder: _border(_red, 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
