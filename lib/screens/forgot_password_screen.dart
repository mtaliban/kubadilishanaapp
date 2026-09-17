/// Forgot password screen — request OTP via SMS, enter code, set new password.
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
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
              child: const Icon(Icons.lock_reset_rounded, size: 20, color: _kBlue)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sahau Nenosiri',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900)),
              Text('Weka nenosiri jipya kupitia SMS',
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
            child: _step == 0
                ? _buildStep0()
                : _step == 1
                    ? _buildStep1()
                    : _buildSuccess(),
          ),
        )),
      ]),
    );
  }

  Widget _buildStep0() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: _kBlue50, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.phone_android_rounded, size: 30, color: _kBlue)),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text('Uthibitisho wa Namba',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900)),
      ),
      const SizedBox(height: 6),
      const Center(
        child: Text('Tutakutumia msimbo wa OTP kupitia SMS',
            style: TextStyle(fontSize: 13, color: _kGrey500), textAlign: TextAlign.center),
      ),
      const SizedBox(height: 24),
      const Text('Namba ya simu',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 6),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: '07XXXXXXXX',
          hintStyle: const TextStyle(color: _kGrey400, fontSize: 12),
          prefixIcon: const Icon(Icons.phone_outlined, size: 16, color: _kGrey500),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _requestOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue, foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Tuma Msimbo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: _kBlue50, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.pin_outlined, size: 30, color: _kBlue)),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text('Msimbo na Nenosiri Jipya',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900)),
      ),
      const SizedBox(height: 6),
      const Center(
        child: Text('Weka msimbo uliopokea na nenosiri jipya',
            style: TextStyle(fontSize: 13, color: _kGrey500), textAlign: TextAlign.center),
      ),
      const SizedBox(height: 24),
      const Text('Msimbo wa OTP',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 6),
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: '123456',
          hintStyle: const TextStyle(color: _kGrey400, fontSize: 12),
          prefixIcon: const Icon(Icons.pin_outlined, size: 16, color: _kGrey500),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
      const SizedBox(height: 10),
      const Text('Nenosiri jipya',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 6),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscure,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: const TextStyle(color: _kGrey400, fontSize: 12),
          prefixIcon: const Icon(Icons.lock_outline, size: 16, color: _kGrey500),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 16, color: _kGrey400)),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue, foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Weka Nenosiri Jipya',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kBlue, foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: const Text('Ingia Sasa',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Future<void> _requestOtp() async {
    setState(() => _loading = true);
    try {
      await ApiService().forgotPassword(_phoneCtrl.text.trim());
      setState(() { _step = 1; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hitilafu: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _loading = true);
    try {
      await ApiService().resetPassword(
        _phoneCtrl.text.trim(),
        _passwordCtrl.text,
      );
      setState(() { _step = 2; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hitilafu: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
