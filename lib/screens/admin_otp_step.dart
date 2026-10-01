// =====================================================================
//  KUINGIA KWA ADMIN — HATUA YA CODE (OTP ya barua pepe)
//  LOGO HAIMO hapa: weka widget hii CHINI ya logo iliyopo tayari,
//  ndani ya kadi ile ile ya kuingia.
//
//  pubspec.yaml:
//    dependencies:
//      flutter_tabler_icons: 1.43.0
// =====================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

class _C {
  static const primary = Color(0xFF2878D6);
  static const primaryDark = Color(0xFF1B4F9C);
  static const tagBg = Color(0xFFE6EFFB);
  static const text = Color(0xFF111111);
  static const body = Color(0xFF555555);
  static const label = Color(0xFF8A8A8A);
  static const disabled = Color(0xFF9A9A9A);
  static const line = Color(0xFFE6E6E6);
  static const boxBorder = Color(0xFFD5DEEB);
  static const boxFilled = Color(0xFF8AB6EC);
  static const boxFilledBg = Color(0xFFF3F8FE);
  static const lockedBg = Color(0xFFF4F5F7);
  static const lockedText = Color(0xFF374151);
  static const lockedIcon = Color(0xFF6B7280);
  static const error = Color(0xFFB91C1C);
}

class AdminOtpStep extends StatefulWidget {
  final String email;

  /// Hakiki code. Rudisha null kama ni sahihi, au ujumbe wa kosa
  /// (mfano "Code si sahihi" au "Code imeisha muda").
  final Future<String?> Function(String code) onVerify;

  /// Tuma code mpya. Rudisha null kama imetumwa, au ujumbe wa kosa.
  final Future<String?> Function() onResend;

  final VoidCallback onChangeEmail; // "Badilisha"
  final VoidCallback onBack; // "Rudi"

  /// Muda wa kusubiri kabla ya kuruhusu "Tuma tena".
  final int resendSeconds;

  const AdminOtpStep({
    super.key,
    required this.email,
    required this.onVerify,
    required this.onResend,
    required this.onChangeEmail,
    required this.onBack,
    this.resendSeconds = 45,
  });

  @override
  State<AdminOtpStep> createState() => _AdminOtpStepState();
}

class _AdminOtpStepState extends State<AdminOtpStep> {
  static const _len = 6;
  final _ctrls = List.generate(_len, (_) => TextEditingController());
  final _nodes = List.generate(_len, (_) => FocusNode());

  Timer? _timer;
  late int _left = widget.resendSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes.first.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();
  bool get _complete => _code.length == _len;

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = widget.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  void _fillFrom(int from, String digits) {
    for (var i = 0; i < digits.length && from + i < _len; i++) {
      _ctrls[from + i].text = digits[i];
    }
    final next = (from + digits.length).clamp(0, _len - 1);
    _nodes[next].requestFocus();
  }

  void _onChanged(int i, String v) {
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _fillFrom(i, digits);
    } else {
      _ctrls[i].text = digits;
      _ctrls[i].selection = TextSelection.collapsed(offset: digits.length);
      if (digits.isNotEmpty && i < _len - 1) _nodes[i + 1].requestFocus();
    }
    setState(() => _error = null);
    if (_complete) _verify();
  }

  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[i].text.isEmpty &&
        i > 0) {
      _ctrls[i - 1].clear();
      _nodes[i - 1].requestFocus();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _verify() async {
    if (!_complete || _verifying) return;
    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);
    final err = await widget.onVerify(_code);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _error = err;
    });
    if (err != null) {
      for (final c in _ctrls) {
        c.clear();
      }
      _nodes.first.requestFocus();
    }
  }

  Future<void> _resend() async {
    if (_left > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    final err = await widget.onResend();
    if (!mounted) return;
    setState(() {
      _resending = false;
      _error = err;
    });
    if (err == null) {
      for (final c in _ctrls) {
        c.clear();
      }
      _nodes.first.requestFocus();
      _startTimer();
    }
  }

  String get _timerText => '0:${_left.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------- KICHWA ----------
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration:
                  BoxDecoration(color: _C.tagBg, borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(TablerIcons.shield_check, size: 13, color: _C.primaryDark),
                SizedBox(width: 4),
                Text('Admin',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.primaryDark)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Weka code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _C.text)),
          const SizedBox(height: 4),
          const Text('Tumetuma code ya tarakimu 6 kwenye barua pepe yako.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _C.body, height: 1.45)),
          const SizedBox(height: 20),

          // ---------- BARUA PEPE (imefungwa) ----------
          _label(TablerIcons.mail, 'Barua pepe'),
          Container(
            height: 44,
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration:
                BoxDecoration(color: _C.lockedBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(TablerIcons.at, size: 18, color: _C.lockedIcon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, color: _C.lockedText)),
              ),
              _link(null, 'Badilisha', widget.onChangeEmail, size: 13),
            ]),
          ),

          // ---------- CODE ----------
          const SizedBox(height: 16),
          _label(TablerIcons.key, 'Code'),
          const SizedBox(height: 1),
          Row(
            children: List.generate(_len, (i) {
              final filled = _ctrls[i].text.isNotEmpty;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == _len - 1 ? 0 : 8),
                  child: Focus(
                    onKeyEvent: (_, e) => _onKey(i, e),
                    child: TextField(
                      controller: _ctrls[i],
                      focusNode: _nodes[i],
                      enabled: !_verifying,
                      autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => _onChanged(i, v),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: _C.text),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: filled ? _C.boxFilledBg : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: _border(hasError
                            ? _C.error
                            : (filled ? _C.boxFilled : _C.boxBorder)),
                        disabledBorder: _border(filled ? _C.boxFilled : _C.boxBorder),
                        focusedBorder: _border(hasError ? _C.error : _C.primary),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          if (hasError) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(TablerIcons.alert_circle, size: 15, color: _C.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12.5, color: _C.error, height: 1.3)),
              ),
            ]),
          ],

          const SizedBox(height: 6),
          Row(children: [
            const Text('Angalia pia Spam',
                style: TextStyle(fontSize: 12.5, color: _C.label)),
            const Spacer(),
            _resending
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _C.primaryDark)),
                  )
                : _link(
                    TablerIcons.refresh,
                    _left > 0 ? 'Tuma tena $_timerText' : 'Tuma code mpya',
                    _left > 0 ? null : _resend,
                  ),
          ]),

          // ---------- CHINI ----------
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.line))),
            child: Row(children: [
              _link(TablerIcons.arrow_left, 'Rudi', _verifying ? null : widget.onBack),
              const Spacer(),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: (_complete && !_verifying) ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    // ignore: deprecated_member_use
                    disabledBackgroundColor: _C.primary.withOpacity(_verifying ? 0.75 : 0.45),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Ingia',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          SizedBox(width: 6),
                          Icon(TablerIcons.login, size: 16),
                        ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ---------------- VIPANDE ----------------
  Widget _label(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Icon(icon, size: 17, color: _C.primaryDark),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.text)),
        ]),
      );

  Widget _link(IconData? icon, String text, VoidCallback? onTap, {double size = 13.5}) {
    final c = onTap == null ? _C.disabled : _C.primaryDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}
