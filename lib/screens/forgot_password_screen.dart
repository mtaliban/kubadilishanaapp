/// Forgot password screen — request OTP via SMS, enter code, set new password.
/// Design ni ile ile ya "Sahau namba?": maneno machache, kitufe kidogo.
library;

import 'package:flutter/material.dart';
import '../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kGrey900 = Color(0xFF111827);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey300 = Color(0xFFD1D5DB);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0 = namba, 1 = msimbo + nenosiri, 2 = mafanikio
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _kosa;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _rudi() {
    if (_step == 1) {
      setState(() { _step = 0; _kosa = null; });
    } else {
      Navigator.maybePop(context);
    }
  }

  InputDecoration _mapambo({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      counterText: '',
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGrey300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kGrey300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
    );
  }

  FilledButton _kitufe(String label, VoidCallback onPressed) {
    return FilledButton(
      onPressed: _loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _kBlue.withValues(alpha: 0.55),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _step == 2 ? _mafanikio() : _fomu(),
        ),
      ),
    );
  }

  // ── Hatua 0 na 1 ──
  Widget _fomu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "< Rudi"
        InkWell(
          onTap: _rudi,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 20, color: _kGrey900),
                SizedBox(width: 8),
                Text('Rudi',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: _kGrey900)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Text(_step == 0 ? 'Sahau nenosiri?' : 'Nenosiri jipya',
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, color: _kGrey900)),
        const SizedBox(height: 4),
        Text(
          _step == 0
              ? 'Weka namba yako tutakutumia msimbo.'
              : 'Weka msimbo uliotumiwa na nenosiri jipya.',
          style: const TextStyle(fontSize: 13, color: _kGrey500),
        ),
        const SizedBox(height: 18),

        if (_step == 0) ...[
          const Text('Namba ya simu',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _kGrey500)),
          const SizedBox(height: 5),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _requestOtp(),
            enabled: !_loading,
            decoration: _mapambo(
              hint: '0712345678',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: _kGrey400),
            ),
          ),
          const SizedBox(height: 16),
          _kitufe('Tuma msimbo', _requestOtp),
        ] else ...[
          const Text('Msimbo wa OTP',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _kGrey500)),
          const SizedBox(height: 5),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_loading,
            onChanged: (_) => setState(() {}),
            decoration: _mapambo(
              hint: '123456',
              prefixIcon: const Icon(Icons.pin_outlined, size: 20, color: _kGrey400),
            ),
            style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          const Text('Nenosiri jipya',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: _kGrey500)),
          const SizedBox(height: 5),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            enabled: !_loading,
            decoration: _mapambo(
              hint: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, size: 20, color: _kGrey400),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: _kGrey400),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _kitufe('Weka nenosiri jipya', _resetPassword),
        ],

        if (_kosa != null) ...[
          const SizedBox(height: 12),
          Text(_kosa!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
        ],
      ],
    );
  }

  // ── Mafanikio ──
  Widget _mafanikio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.check_circle_rounded, size: 40, color: Color(0xFF16A34A)),
        ),
        const SizedBox(height: 20),
        const Text('Nenosiri limebadilishwa!',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: _kGrey900)),
        const SizedBox(height: 6),
        const Text('Unaweza kuingia sasa kwa nenosiri jipya.',
            style: TextStyle(fontSize: 13, color: _kGrey500)),
        const SizedBox(height: 24),
        _kitufe('Ingia sasa', () => Navigator.pushReplacementNamed(context, '/login')),
      ],
    );
  }

  // ── Hatua za API ──
  Future<void> _requestOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _kosa = 'Weka namba ya simu kwanza');
      return;
    }
    setState(() { _loading = true; _kosa = null; });
    try {
      await ApiService().forgotPassword(phone);
      if (!mounted) return;
      setState(() { _step = 1; _loading = false; _kosa = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _kosa = 'Imeshindwa kutuma msimbo. Angalia namba kisha ujaribu tena.';
      });
    }
  }

  Future<void> _resetPassword() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final pw = _passwordCtrl.text;
    if (code.replaceAll(RegExp(r'\D'), '').length < 4) {
      setState(() => _kosa = 'Weka msimbo uliotumiwa');
      return;
    }
    if (pw.length < 6) {
      setState(() => _kosa = 'Nenosiri lazima iwe na herufi 6 au zaidi');
      return;
    }
    setState(() { _loading = true; _kosa = null; });
    try {
      await ApiService().resetPassword(phone, pw, code: code);
      if (!mounted) return;
      setState(() { _step = 2; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      String msg = 'Imeshindwa kuhifadhi. Jaribu tena.';
      try {
        final d = (e as dynamic).response?.data?['detail'];
        if (d is String && d.isNotEmpty) msg = d;
      } catch (_) {}
      setState(() { _loading = false; _kosa = msg; });
    }
  }
}
