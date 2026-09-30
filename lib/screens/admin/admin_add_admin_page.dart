// =====================================================================
//  FOMU YA "ONGEZA ADMIN" — Kubadilishana
//  Kadi moja: Jina kamili, Barua pepe, Namba ya simu (si lazima), Nywila.
//  Chini: "Ghairi" (kushoto) na kitufe KIDOGO "Hifadhi" (kulia, bila icon).
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class _C {
  static const pageBg      = Colors.white;
  static const cardBorder  = Color(0xFFEDEDED);
  static const primary     = Color(0xFF2878D6);
  static const primaryDark = Color(0xFF1B4F9C);
  static const text        = Color(0xFF111111);
  static const hint        = Color(0xFF9A9A9A);
  static const note        = Color(0xFF8A8A8A);
  static const line        = Color(0xFFE6E6E6);
  static const inputBorder = Color(0xFFD5DEEB);
  static const eye         = Color(0xFF6B7280);
  static const error       = Color(0xFFB91C1C);
}

class NewAdmin {
  final String  fullName;
  final String  email;
  final String? phone;    // "+2557XXXXXXXX" au null
  final String  password;
  const NewAdmin({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
  });
}

/// Ukurasa mzima (AppBar + fomu).
class AddAdminPage extends StatelessWidget {
  /// Rudisha null kama imefanikiwa, au ujumbe wa kosa (mf. "Barua pepe hii ipo tayari").
  /// Si lazima — tests zinaweza kutumia const AddAdminPage() bila onSave.
  final Future<String?> Function(NewAdmin admin)? onSave;
  const AddAdminPage({super.key, this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      appBar: AppBar(
        backgroundColor:  _C.pageBg,
        surfaceTintColor: _C.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(TablerIcons.arrowLeft, color: _C.text, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: const Text('Ongeza admin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.text)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: AddAdminForm(
            onSave: onSave,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

class AddAdminForm extends StatefulWidget {
  final Future<String?> Function(NewAdmin admin)? onSave;
  final VoidCallback onCancel;
  const AddAdminForm({super.key, required this.onCancel, this.onSave});

  @override
  State<AddAdminForm> createState() => _AddAdminFormState();
}

class _AddAdminFormState extends State<AddAdminForm> {
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _phone    = TextEditingController();
  final _password = TextEditingController();

  bool    _showPassword = false;
  bool    _saving       = false;
  String? _nameErr, _emailErr, _phoneErr, _passwordErr, _formErr;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    final name  = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.replaceAll(' ', '');
    final pass  = _password.text;

    setState(() {
      _formErr     = null;
      _nameErr     = name.split(RegExp(r'\s+')).length < 2
          ? 'Andika majina mawili au zaidi'
          : null;
      _emailErr    = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
          ? null
          : 'Barua pepe si sahihi';
      _phoneErr    = phone.isEmpty || RegExp(r'^[67]\d{8}$').hasMatch(phone)
          ? null
          : 'Andika tarakimu 9, mfano 712 345 678';
      _passwordErr = pass.length < 8 ? 'Nywila iwe na herufi 8 au zaidi' : null;
    });
    return _nameErr == null &&
        _emailErr == null &&
        _phoneErr == null &&
        _passwordErr == null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    setState(() => _saving = true);
    final phone = _phone.text.replaceAll(' ', '');
    final err   = await widget.onSave?.call(NewAdmin(
      fullName: _name.text.trim().toUpperCase(),
      email:    _email.text.trim().toLowerCase(),
      phone:    phone.isEmpty ? null : '+255$phone',
      password: _password.text,
    ));
    if (!mounted) return;
    setState(() {
      _saving  = false;
      _formErr = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: _C.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- JINA ----------
          _label(TablerIcons.userSquareRounded, 'Jina kamili'),
          _field(
            controller: _name,
            hint:       'Mfano: Amani Selemani',
            prefix:     _icon(TablerIcons.userCircle),
            error:      _nameErr,
            caps:       TextCapitalization.words,
            onChanged:  () => _nameErr = null,
          ),

          // ---------- BARUA PEPE ----------
          _gap(),
          _label(TablerIcons.mail, 'Barua pepe'),
          _field(
            controller: _email,
            hint:       'jina@mfano.go.tz',
            prefix:     _icon(TablerIcons.at),
            error:      _emailErr,
            keyboard:   TextInputType.emailAddress,
            onChanged:  () => _emailErr = null,
          ),

          // ---------- SIMU ----------
          _gap(),
          _label(TablerIcons.deviceMobile, 'Namba ya simu', trailing: 'Si lazima'),
          _field(
            controller: _phone,
            hint:       '7XX XXX XXX',
            prefix: Container(
              margin:  const EdgeInsets.only(left: 12, right: 10),
              padding: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: _C.line)),
              ),
              child: const Text('+255',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _C.text)),
            ),
            error:      _phoneErr,
            keyboard:   TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            onChanged: () => _phoneErr = null,
          ),

          // ---------- NYWILA ----------
          _gap(),
          _label(TablerIcons.lock, 'Nywila'),
          _field(
            controller: _password,
            hint:       'Angalau herufi 8',
            prefix:     _icon(TablerIcons.key),
            error:      _passwordErr,
            obscure:    !_showPassword,
            suffix: IconButton(
              tooltip:   _showPassword ? 'Ficha nywila' : 'Onyesha nywila',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword ? TablerIcons.eyeOff : TablerIcons.eye,
                size: 20, color: _C.eye,
              ),
            ),
            onChanged: () => _passwordErr = null,
          ),
          if (_passwordErr == null) ...[
            const SizedBox(height: 6),
            const Text(
                'Mpe admin nywila hii kwa njia salama. Ataweza kuibadilisha.',
                style: TextStyle(fontSize: 12, color: _C.note, height: 1.35)),
          ],

          // Kosa kutoka server
          if (_formErr != null) ...[
            const SizedBox(height: 12),
            _errorLine(_formErr!),
          ],

          // ---------- CHINI ----------
          Container(
            margin:  const EdgeInsets.only(top: 18),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.line)),
            ),
            child: Row(children: [
              Flexible(
                child: InkWell(
                  onTap:         _saving ? null : widget.onCancel,
                  borderRadius:  BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(TablerIcons.arrowLeft, size: 15, color: _C.primaryDark),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text('Ghairi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _C.primaryDark)),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:         _C.primary,
                    disabledBackgroundColor: _C.primary.withValues(alpha: 0.75),
                    foregroundColor:         Colors.white,
                    disabledForegroundColor: Colors.white,
                    elevation:  0,
                    padding:    const EdgeInsets.symmetric(horizontal: 20),
                    minimumSize:    Size.zero,
                    tapTargetSize:  MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Hifadhi',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ---------------- VIPANDE ----------------
  Widget _gap() => const SizedBox(height: 14);

  Widget _icon(IconData i) => Padding(
        padding: const EdgeInsets.only(left: 12, right: 10),
        child:   Icon(i, size: 20, color: _C.primaryDark),
      );

  Widget _label(IconData icon, String text, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Icon(icon, size: 17, color: _C.primaryDark),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.text)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(trailing,
                style: const TextStyle(fontSize: 12, color: _C.note)),
          ],
        ]),
      );

  Widget _errorLine(String msg) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(TablerIcons.alertCircle, size: 15, color: _C.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 12.5, color: _C.error, height: 1.3)),
          ),
        ],
      );

  Widget _field({
    required TextEditingController controller,
    required String                 hint,
    required Widget                 prefix,
    required String?                error,
    required VoidCallback           onChanged,
    Widget?                         suffix,
    bool                            obscure    = false,
    TextInputType?                  keyboard,
    TextCapitalization              caps       = TextCapitalization.none,
    List<TextInputFormatter>?       formatters,
  }) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller:           controller,
          obscureText:          obscure,
          keyboardType:         keyboard,
          textCapitalization:   caps,
          inputFormatters:      formatters,
          onChanged: (_) { if (hasError) setState(onChanged); },
          style: const TextStyle(fontSize: 15, color: _C.text, height: 1.2),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: const TextStyle(fontSize: 15, color: _C.hint, height: 1.2),
            prefixIcon:            prefix,
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 44),
            suffixIcon:            suffix,
            contentPadding:        const EdgeInsets.fromLTRB(0, 14, 12, 14),
            filled:      true,
            fillColor:   Colors.white,
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
        borderSide:   BorderSide(color: c, width: 1.5),
      );
}
