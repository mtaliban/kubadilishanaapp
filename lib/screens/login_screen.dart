import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  // twoFA != null means OTP step is shown
  String? _twoFAEmail;
  bool _otpLoading = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final val = _identifierCtrl.text.trim();
    if (val.isEmpty) return;
    final auth = context.read<AuthProvider>();

    // Same endpoint for both phone and admin email — backend detects admin and sends OTP
    final ok = await auth.login(val);
    if (!mounted) return;

    if (auth.pendingAdminEmail != null) {
      // Admin 2FA — show OTP input
      setState(() => _twoFAEmail = auth.pendingAdminEmail);
    } else if (ok) {
      Navigator.pushReplacementNamed(context, auth.isAdmin ? '/admin' : '/dashboard');
    } else if (auth.error != null) {
      _showError(auth.error!);
    }
  }

  Future<void> _submitOtp(String code) async {
    if (code.length != 6 || _otpLoading) return;
    setState(() => _otpLoading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.adminLoginOtp(_twoFAEmail!, code);
    if (mounted) {
      setState(() => _otpLoading = false);
      if (ok) {
        Navigator.pushReplacementNamed(context, '/admin');
      } else if (auth.error != null) {
        _showError(auth.error!);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _cancelOtp() {
    setState(() {
      _twoFAEmail = null;
      _otpCtrl.clear();
    });
    context.read<AuthProvider>().pendingAdminEmail = null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loading = auth.loading || _otpLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // Back arrow
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 14, color: AppColors.textSecondary),
                        Text('Rudi', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo.jpeg',
                            height: 88,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text('Karibu Tena',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      const Center(
                        child: Text('Tafuta mtu wa kubadilishana naye',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ),
                      const SizedBox(height: 24),

                      // Phone / email input (always visible, disabled during OTP)
                      Text(
                        _identifierCtrl.text.contains('@') ? 'Email ya Admin' : 'Namba ya Simu',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _identifierCtrl,
                        keyboardType: TextInputType.phone,
                        enabled: _twoFAEmail == null,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '0712345678',
                          prefixIcon: const Icon(Icons.phone, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                      ),

                      if (_twoFAEmail != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'Code ya tarakimu 6 imetumwa kwa $_twoFAEmail — angalia email yako',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // OTP input OR login button
                      if (_twoFAEmail == null)
                        ElevatedButton(
                          onPressed: loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Ingia', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                autofocus: true,
                                enabled: !_otpLoading,
                                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: '000000',
                                  counterText: '',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onChanged: (v) {
                                  final code = v.replaceAll(RegExp(r'\D'), '');
                                  if (code.length == 6) _submitOtp(code);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _cancelOtp,
                              tooltip: 'Rudi',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                  child: const Text('Sahau namba yako?',
                      style: TextStyle(color: AppColors.primary)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Jisajili sasa', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
