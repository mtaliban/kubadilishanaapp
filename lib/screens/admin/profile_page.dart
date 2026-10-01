// =====================================================================
//  UKURASA WA "WASIFU WANGU" — Kubadilishana
//  Kadi MOJA yenye hali 2:
//    1. Kuangalia: taarifa kwa mistari (lebo juu, thamani chini)
//    2. Kuhariri: kadi ile ile inageuka fomu (bofya "Hariri" au "Ongeza")
//  Hakuna vitufe vikubwa. "Hifadhi" ni kidogo na inawaka tu kukiwa na badiliko.
//
//  pubspec.yaml:
//    dependencies:
//      flutter_tabler_icons: 1.43.0
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class _C {
  static const pageBg = Color(0xFFF7F7F5);
  static const cardBorder = Color(0xFFEDEDED);
  static const primary = Color(0xFF2878D6);
  static const primaryDark = Color(0xFF1B4F9C);
  static const avatarBg = Color(0xFFE6EFFB);
  static const text = Color(0xFF111111);
  static const label = Color(0xFF8A8A8A);
  static const empty = Color(0xFF9A9A9A);
  static const line = Color(0xFFE6E6E6);
  static const inputBorder = Color(0xFFD5DEEB);
  static const lockedBg = Color(0xFFF4F5F7);
  static const lockedText = Color(0xFF6B7280);
  static const ok = Color(0xFF1B6B1B);
  static const error = Color(0xFFB91C1C);
}

class AdminProfile {
  final String fullName; // "Hamisi Selemani Hamisi"
  final String role; // "Administrator"
  final String phone; // "+255 763 795 801" (haibadilishwi hapa)
  final String? email; // null = haijawekwa (haibadilishwi hapa)
  final String? whatsapp; // "+255 712 345 678" au null
  const AdminProfile({
    required this.fullName,
    required this.role,
    required this.phone,
    this.email,
    this.whatsapp,
  });

  AdminProfile copyWith({String? fullName, String? whatsapp, bool clearWhatsapp = false}) =>
      AdminProfile(
        fullName: fullName ?? this.fullName,
        role: role,
        phone: phone,
        email: email,
        whatsapp: clearWhatsapp ? null : (whatsapp ?? this.whatsapp),
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class ProfilePage extends StatefulWidget {
  final AdminProfile profile;

  /// Hifadhi mabadiliko. Rudisha null kama imefanikiwa, au ujumbe wa kosa.
  final Future<String?> Function(String fullName, String? whatsapp) onSave;

  const ProfilePage({super.key, required this.profile, required this.onSave});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late AdminProfile _p = widget.profile;
  bool _editing = false;
  bool _saving = false;
  bool _copied = false;
  String? _nameErr, _waErr, _formErr;

  final _name = TextEditingController();
  final _wa = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _wa.dispose();
    super.dispose();
  }

  // "+255 712 345 678" -> "712345678"
  String _waDigits(String? v) => (v ?? '').replaceAll('+255', '').replaceAll(RegExp(r'\D'), '');

  // "712345678" -> "+255 712 345 678"
  String _formatWa(String d) =>
      '+255 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';

  bool get _changed =>
      _name.text.trim() != _p.fullName || _wa.text.trim() != _waDigits(_p.whatsapp);

  void _startEdit() {
    _name.text = _p.fullName;
    _wa.text = _waDigits(_p.whatsapp);
    setState(() {
      _editing = true;
      _nameErr = _waErr = _formErr = null;
    });
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final wa = _wa.text.trim();
    setState(() {
      _formErr = null;
      _nameErr = name.split(RegExp(r'\s+')).length < 2 ? 'Andika majina mawili au zaidi' : null;
      _waErr = wa.isEmpty || RegExp(r'^[67]\d{8}$').hasMatch(wa)
          ? null
          : 'Andika tarakimu 9, mfano 712 345 678';
    });
    if (_nameErr != null || _waErr != null) return;

    setState(() => _saving = true);
    final waFull = wa.isEmpty ? null : _formatWa(wa);
    final err = await widget.onSave(name, waFull);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (err != null) {
        _formErr = err;
      } else {
        _p = waFull == null
            ? _p.copyWith(fullName: name, clearWhatsapp: true)
            : _p.copyWith(fullName: name, whatsapp: waFull);
        _editing = false;
      }
    });
  }

  // HAKUNA toast: kitufe chenyewe kinaonyesha "Imenakiliwa" kwa sekunde 2.
  Future<void> _copyPhone() async {
    await Clipboard.setData(ClipboardData(text: _p.phone.replaceAll(' ', '')));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      appBar: AppBar(
        backgroundColor: _C.pageBg,
        surfaceTintColor: _C.pageBg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(_editing ? TablerIcons.x : TablerIcons.arrow_left,
              size: 22, color: _C.text),
          onPressed: _editing ? _cancelEdit : () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? 'Hariri wasifu' : 'Wasifu wangu',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.text)),
        actions: [
          if (!_editing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _smallLink(TablerIcons.pencil, 'Hariri', _startEdit),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _editing ? _editView() : _readView(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- KICHWA (picha + jina + cheo) ----------------
  Widget _header() => Container(
        padding: const EdgeInsets.only(bottom: 16),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _C.line))),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _C.avatarBg, shape: BoxShape.circle),
            child: Text(_p.initials,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w900, color: _C.primaryDark)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_p.fullName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900, color: _C.text, height: 1.25)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: _C.avatarBg, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(TablerIcons.shield_check, size: 13, color: _C.primaryDark),
                    const SizedBox(width: 4),
                    Text(_p.role,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _C.primaryDark)),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      );

  // ---------------- HALI 1: KUANGALIA ----------------
  Widget _readView() {
    return Column(
      key: const ValueKey('read'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(TablerIcons.user, 'Jina kamili', Text(_p.fullName, style: _valueStyle)),
        _divider(),
        _infoRow(
          TablerIcons.device_mobile,
          'Namba ya simu',
          Row(children: [
            Expanded(child: Text(_p.phone, style: _valueStyle)),
            _copied
                ? _smallLink(TablerIcons.check, 'Imenakiliwa', null, color: _C.ok)
                : _smallLink(TablerIcons.copy, 'Nakili', _copyPhone),
          ]),
        ),
        _divider(),
        _infoRow(
          TablerIcons.brand_whatsapp,
          'WhatsApp / simu ya pili',
          _p.whatsapp != null
              ? Text(_p.whatsapp!, style: _valueStyle)
              : Row(children: [
                  const Expanded(child: Text('Haijawekwa', style: _emptyStyle)),
                  _smallLink(null, 'Ongeza', _startEdit),
                ]),
        ),
        _divider(),
        _infoRow(
          TablerIcons.mail,
          'Barua pepe',
          Text(_p.email ?? 'Haijawekwa', style: _p.email == null ? _emptyStyle : _valueStyle),
        ),
      ],
    );
  }

  // ---------------- HALI 2: KUHARIRI ----------------
  Widget _editView() {
    return Column(
      key: const ValueKey('edit'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _label(TablerIcons.user_square_rounded, 'Jina kamili'),
        _field(
          controller: _name,
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12, right: 10),
            child: Icon(TablerIcons.user_circle, size: 20, color: _C.primaryDark),
          ),
          hint: 'Mfano: Amani Selemani',
          error: _nameErr,
          caps: TextCapitalization.words,
          onChanged: () => _nameErr = null,
        ),
        const SizedBox(height: 14),
        _label(TablerIcons.brand_whatsapp, 'WhatsApp / simu ya pili', trailing: 'Si lazima'),
        _field(
          controller: _wa,
          prefix: Container(
            margin: const EdgeInsets.only(left: 12, right: 10),
            padding: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: _C.line))),
            child: const Text('+255',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.text)),
          ),
          hint: '7XX XXX XXX',
          error: _waErr,
          keyboard: TextInputType.phone,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          onChanged: () => _waErr = null,
        ),

        // Zilizofungwa
        const SizedBox(height: 18),
        _label(TablerIcons.lock, 'Haziwezi kubadilishwa hapa'),
        _lockedRow(TablerIcons.device_mobile, _p.phone),
        const SizedBox(height: 8),
        _lockedRow(TablerIcons.mail, _p.email ?? 'Barua pepe haijawekwa'),
        const SizedBox(height: 8),
        const Text('Kubadilisha hizi, wasiliana na admin mwenzako.',
            style: TextStyle(fontSize: 12, color: _C.label, height: 1.35)),

        if (_formErr != null) ...[
          const SizedBox(height: 12),
          _errorLine(_formErr!),
        ],

        // Chini
        Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.line))),
          child: Row(children: [
            _smallLink(TablerIcons.arrow_left, 'Ghairi', _saving ? null : _cancelEdit),
            const Spacer(),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: (_saving || !_changed) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  disabledBackgroundColor: _C.primary.withValues(alpha: _saving ? 0.75 : 0.45),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Hifadhi',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ---------------- VIPANDE ----------------
  static const _valueStyle =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.text, height: 1.35);
  static const _emptyStyle = TextStyle(fontSize: 15, color: _C.empty, height: 1.35);

  Widget _divider() => const Divider(height: 1, thickness: 1, color: _C.line);

  Widget _infoRow(IconData icon, String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: _C.primaryDark),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12.5, color: _C.label)),
            ]),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.only(left: 22), child: value),
          ],
        ),
      );

  Widget _smallLink(IconData? icon, String text, VoidCallback? onTap, {Color? color}) {
    final c = color ?? _C.primaryDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }

  Widget _label(IconData icon, String text, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Icon(icon, size: 17, color: _C.primaryDark),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.text)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(trailing, style: const TextStyle(fontSize: 12, color: _C.label)),
          ],
        ]),
      );

  Widget _lockedRow(IconData icon, String text) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration:
            BoxDecoration(color: _C.lockedBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 18, color: _C.lockedText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, color: _C.lockedText)),
          ),
          const Icon(TablerIcons.lock, size: 16, color: _C.empty),
        ]),
      );

  Widget _errorLine(String msg) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(TablerIcons.alert_circle, size: 15, color: _C.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontSize: 12.5, color: _C.error, height: 1.3)),
          ),
        ],
      );

  Widget _field({
    required TextEditingController controller,
    required Widget prefix,
    required String hint,
    required String? error,
    required VoidCallback onChanged,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
  }) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboard,
          textCapitalization: caps,
          inputFormatters: formatters,
          onChanged: (_) => setState(() {
            if (hasError) onChanged();
          }),
          style: const TextStyle(fontSize: 15, color: _C.text, height: 1.2),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 15, color: _C.empty, height: 1.2),
            prefixIcon: prefix,
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 44),
            contentPadding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: _border(hasError ? _C.error : _C.inputBorder),
            focusedBorder: _border(hasError ? _C.error : _C.primary),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          _errorLine(error),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}
