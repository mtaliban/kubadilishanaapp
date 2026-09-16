/// Reset password screen — set new password with OTP code.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class ResetPasswordScreen extends StatefulWidget {
  final String phone;
  const ResetPasswordScreen({super.key, required this.phone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kGrey700)),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2))),
              child: const Icon(Icons.key_rounded, size: 20, color: _kBlue)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Weka Nenosiri Jipya',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900)),
              Text('Thibitisha na uhifadhi nenosiri jipya',
                  style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
          ]),
        ),
        Container(height: 1, color: _kGrey200),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGrey200),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
            ),
            child: _success ? _buildSuccess() : _buildForm(),
          ),
        )),
      ]),
    );
  }

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: _kBlue50, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.lock_outline_rounded, size: 30, color: _kBlue)),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text('Nenosiri Jipya',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900)),
      ),
      const SizedBox(height: 6),
      const Center(
        child: Text('Nenosiri lazima iwe na herufi 6 au zaidi',
            style: TextStyle(fontSize: 13, color: _kGrey500), textAlign: TextAlign.center),
      ),
      const SizedBox(height: 24),
      const Text('Nenosiri jipya',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 8),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscure1,
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: _kGrey500),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscure1 = !_obscure1),
            child: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18, color: _kGrey400)),
          filled: true,
          fillColor: _kGrey100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      const SizedBox(height: 14),
      const Text('Thibitisha nenosiri',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 8),
      TextField(
        controller: _password2Ctrl,
        obscureText: _obscure2,
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: _kGrey500),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscure2 = !_obscure2),
            child: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18, color: _kGrey400)),
          filled: true,
          fillColor: _kGrey100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.error_outline, size: 14, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue, foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Weka Nenosiri',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _buildSuccess() {
    return Column(children: [
      const SizedBox(height: 16),
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.check_circle_rounded, size: 40, color: Color(0xFF16A34A))),
      const SizedBox(height: 20),
      const Text('Nenosiri Limebadilishwa!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text('Unaweza kuingia sasa kwa nenosiri jipya.',
          style: TextStyle(fontSize: 13, color: _kGrey500), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue, foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Ingia Sasa',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Future<void> _submit() async {
    final pw = _passwordCtrl.text;
    final pw2 = _password2Ctrl.text;
    if (pw != pw2) {
      setState(() => _error = 'Nenosiri hazifanani');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'Nenosiri lazima iwe na herufi 6 au zaidi');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService().resetPassword(widget.phone, pw);
      setState(() { _success = true; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Hitilafu — jaribu tena'; _loading = false; });
    }
  }
}
