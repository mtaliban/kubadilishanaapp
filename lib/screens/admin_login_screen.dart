/// Admin login — email + password → OTP 2FA.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _obscure = true;
  bool _showOtp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _step1() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.adminLoginStep1(
        _emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok && auth.pendingAdminEmail != null) {
      setState(() => _showOtp = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('OTP imetumwa — angalia email yako'),
            backgroundColor: AppColors.info));
    } else if (ok) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(auth.error!),
            backgroundColor: AppColors.error));
    }
  }

  Future<void> _step2() async {
    final auth = context.read<AuthProvider>();
    final email = auth.pendingAdminEmail ?? _emailCtrl.text.trim();
    final ok = await auth.adminLoginOtp(email, _otpCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(auth.error!),
            backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.admin_panel_settings,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                _showOtp ? 'Weka Nambari ya OTP' : 'Ingia kama Admin',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              if (!_showOtp) ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Nenosiri',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _step1,
                    child: auth.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Ingia'),
                  ),
                ),
              ] else ...[
                Text(
                  'OTP imetumwa kwa: ${auth.pendingAdminEmail ?? _emailCtrl.text}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Nambari ya OTP (6 digits)',
                    prefixIcon: Icon(Icons.pin),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _step2,
                    child: auth.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Thibitisha OTP'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _showOtp = false;
                    _otpCtrl.clear();
                  }),
                  child: const Text('Rudi nyuma'),
                ),
              ],

              const SizedBox(height: 12),
              if (!_showOtp)
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/login'),
                  child: const Text('Mtumiaji wa kawaida? Ingia hapa'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
