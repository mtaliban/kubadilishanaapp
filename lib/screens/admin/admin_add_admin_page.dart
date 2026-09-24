import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/* ============================================================
   DATA INAYORUDISHWA
   ============================================================ */
class NewAdminData {
  final String name;
  final String email;
  final String phone; // mf. 0712345678
  final String password;

  const NewAdminData({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });
}

/* ============================================================
   UKURASA WA KUONGEZA ADMIN
   Tumia kama:
   Navigator.push(context, MaterialPageRoute(
     builder: (_) => AddAdminPage(onSave: (d) async { ... }),
   ));
   ============================================================ */
class AddAdminPage extends StatefulWidget {
  final Future<void> Function(NewAdminData data)? onSave;
  const AddAdminPage({super.key, this.onSave});

  @override
  State<AddAdminPage> createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  bool showPw = false;
  bool saving = false;
  bool showErr = false; // kitufe kinakuwa chekundu kwa muda mfupi

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    emailCtrl.addListener(() => setState(() {}));
    pwCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  bool get _emailOk => _emailRe.hasMatch(emailCtrl.text.trim());

  // 0 - 4
  int get _strength {
    final v = pwCtrl.text;
    var s = 0;
    if (v.length >= 6) s++;
    if (v.length >= 10) s++;
    if (RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[a-zA-Z]').hasMatch(v)) s++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(v)) s++;
    return s;
  }

  static const _strengthLabels = ['Dhaifu sana', 'Dhaifu', 'Wastani', 'Nzuri', 'Imara'];

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _validate() {
    if (nameCtrl.text.trim().isEmpty) return 'Andika jina kamili';
    if (!_emailOk) return 'Andika barua pepe sahihi';
    if (_digits(phoneCtrl.text).length != 9) {
      return 'Namba ya simu iwe tarakimu 9 baada ya +255';
    }
    if (pwCtrl.text.length < 6) return 'Nywila iwe angalau herufi 6';
    return null;
  }

  Future<void> _flashError(String msg) async {
    _toast(msg);
    setState(() => showErr = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => showErr = false);
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) return _flashError(err);

    final data = NewAdminData(
      name: nameCtrl.text.trim(),
      email: emailCtrl.text.trim().toLowerCase(),
      phone: '0${_digits(phoneCtrl.text)}',
      password: pwCtrl.text,
    );

    setState(() => saving = true);
    try {
      await widget.onSave?.call(data);
      if (!mounted) return;
      _toast('Admin ameongezwa');
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) _toast('Imeshindikana kuongeza admin: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _AColors.of(context);
    final emailText = emailCtrl.text.trim();
    final emailBad = emailText.isNotEmpty && !_emailOk;
    final s = _strength;
    final meterColor = switch (s) {
      1 => c.red,
      2 || 3 => c.amber,
      4 => c.green,
      _ => c.borderStrong,
    };

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: [
            // Kichwa
            Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
              decoration: BoxDecoration(
                color: c.page,
                border: Border(bottom: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(PhosphorIcons.arrowLeft(), size: 21, color: c.text),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ongeza admin',
                            style: TextStyle(
                                color: c.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                        Text('Msimamizi mpya wa mfumo',
                            style: TextStyle(color: c.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Maelezo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.blueBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(PhosphorIcons.shieldCheck(), size: 20, color: c.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(color: c.blue, fontSize: 13),
                                children: const [
                                  TextSpan(text: 'Admin anaingia kwa '),
                                  TextSpan(
                                      text: 'barua pepe na nywila',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  TextSpan(
                                      text: '. Hahitaji idara wala kada.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _Section(
                        icon: PhosphorIcons.userGear(),
                        title: 'Taarifa za admin',
                        c: c),

                    _Label('Jina kamili', c: c, required: true),
                    _Input(
                      c: c,
                      controller: nameCtrl,
                      icon: PhosphorIcons.user(),
                      hint: 'mf. Hamisi Selemani',
                      capitalization: TextCapitalization.words,
                    ),

                    _Label('Barua pepe', c: c, required: true),
                    _Input(
                      c: c,
                      controller: emailCtrl,
                      icon: PhosphorIcons.envelope(),
                      hint: 'jina@mfano.com',
                      keyboard: TextInputType.emailAddress,
                      error: emailBad,
                      suffix: _emailOk
                          ? Icon(PhosphorIcons.checkCircle(),
                              size: 19, color: c.green)
                          : null,
                    ),
                    _Hint(
                      c: c,
                      icon: emailBad
                          ? PhosphorIcons.warningCircle()
                          : PhosphorIcons.info(),
                      text: emailBad
                          ? 'Barua pepe si sahihi'
                          : 'Atatumia barua pepe hii kuingia',
                      color: emailBad ? c.red : null,
                    ),

                    _Label('Namba ya simu', c: c, required: true),
                    _Input(
                      c: c,
                      controller: phoneCtrl,
                      icon: PhosphorIcons.phone(),
                      hint: '712 345 678',
                      keyboard: TextInputType.phone,
                      prefix255: true,
                    ),

                    _Label('Nywila',
                        c: c,
                        required: true,
                        trailing: pwCtrl.text.isEmpty
                            ? null
                            : _strengthLabels[s]),
                    _Input(
                      c: c,
                      controller: pwCtrl,
                      icon: PhosphorIcons.lock(),
                      hint: 'Angalau herufi 6',
                      obscure: !showPw,
                      suffix: IconButton(
                        onPressed: () => setState(() => showPw = !showPw),
                        icon: Icon(
                            showPw ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye(),
                            size: 19,
                            color: c.muted),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(4, (i) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: i < s ? meterColor : c.borderStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),

                    _Section(
                        icon: PhosphorIcons.key(),
                        title: 'Atakachoweza kufanya',
                        c: c),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: c.borderStrong),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _Perm(
                              c: c,
                              icon: PhosphorIcons.usersThree(),
                              text: 'Kusimamia watumiaji'),
                          Divider(height: 1, color: c.border),
                          _Perm(
                              c: c,
                              icon: PhosphorIcons.megaphone(),
                              text: 'Kutuma matangazo'),
                          Divider(height: 1, color: c.border),
                          _Perm(
                              c: c,
                              icon: PhosphorIcons.creditCard(),
                              text: 'Kuthibitisha malipo'),
                        ],
                      ),
                    ),

                    // Vitufe (mtindo B: bluu hafifu, vyembamba)
                    Container(
                      margin: const EdgeInsets.only(top: 18),
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: c.border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 30,
                            child: TextButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.maybePop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: c.muted,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w400),
                              ),
                              child: const Text('Ghairi'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 30,
                            child: TextButton(
                              onPressed: saving || showErr ? null : _save,
                              style: TextButton.styleFrom(
                                backgroundColor: showErr ? c.redBg : c.blueBg,
                                foregroundColor: showErr ? c.red : c.blue,
                                disabledBackgroundColor:
                                    showErr ? c.redBg : c.blueBg,
                                disabledForegroundColor:
                                    showErr ? c.red : c.blue,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w400),
                              ),
                              child: saving
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: c.blue),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            showErr
                                                ? PhosphorIcons.warningCircle()
                                                : PhosphorIcons.userPlus(),
                                            size: 14),
                                        const SizedBox(width: 5),
                                        Text(showErr
                                            ? 'Jaza sehemu zote'
                                            : 'Ongeza admin'),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final _AColors c;
  const _Section({required this.icon, required this.title, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.blue),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool required;
  final String? trailing;
  final _AColors c;
  const _Label(this.text,
      {required this.c, this.required = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text,
                style: TextStyle(
                    color: c.text, fontSize: 13, fontWeight: FontWeight.w600),
                children: [
                  if (required)
                    TextSpan(text: ' *', style: TextStyle(color: c.red)),
                ],
              ),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final _AColors c;
  final IconData icon;
  final String text;
  final Color? color;
  const _Hint(
      {required this.c, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final col = color ?? c.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: col),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: col, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final _AColors c;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool prefix255;
  final bool obscure;
  final bool error;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final Widget? suffix;

  const _Input({
    required this.c,
    required this.controller,
    required this.icon,
    required this.hint,
    this.prefix255 = false,
    this.obscure = false,
    this.error = false,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: col, width: w),
        );
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      autocorrect: !obscure,
      style: TextStyle(color: c.text, fontSize: 15),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.faint, fontSize: 15),
        isDense: true,
        filled: true,
        fillColor: c.page,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: c.blue),
              if (prefix255) ...[
                const SizedBox(width: 10),
                Text('+255', style: TextStyle(color: c.text, fontSize: 15)),
                const SizedBox(width: 10),
                Container(width: 1, height: 20, color: c.borderStrong),
              ],
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        border: b(error ? c.red : c.borderStrong),
        enabledBorder: b(error ? c.red : c.borderStrong),
        focusedBorder: b(error ? c.red : c.blue, 1.5),
      ),
    );
  }
}

class _Perm extends StatelessWidget {
  final _AColors c;
  final IconData icon;
  final String text;
  const _Perm({required this.c, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.blueBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: c.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: c.text, fontSize: 14)),
          ),
          Icon(PhosphorIcons.check(), size: 18, color: c.green),
        ],
      ),
    );
  }
}

/* ============================================================
   RANGI (nyeupe, zisizopauka)
   ============================================================ */
class _AColors {
  final Color page, border, borderStrong, text, muted, faint;
  final Color blue, blueBg, blueRing, green, amber, red, redBg;

  const _AColors({
    required this.page,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.faint,
    required this.blue,
    required this.blueBg,
    required this.blueRing,
    required this.green,
    required this.amber,
    required this.red,
    required this.redBg,
  });

  static const light = _AColors(
    page: Color(0xFFFFFFFF),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFC3CAD6),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    faint: Color(0xFF8A93A3),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    blueRing: Color(0xFFBBD2F8),
    green: Color(0xFF0F7A52),
    amber: Color(0xFFD08A00),
    red: Color(0xFFC62828),
    redBg: Color(0xFFFDECEC),
  );

  static const dark = _AColors(
    page: Color(0xFF12161D),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF465164),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    faint: Color(0xFF7C8699),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    blueRing: Color(0xFF2B4270),
    green: Color(0xFF5FD49A),
    amber: Color(0xFFF0B35A),
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
  );

  static _AColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
