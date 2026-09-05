/// Reset password screen — set new password with OTP code.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

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
      appBar: AppBar(title: const Text('Weka Nenosiri Jipya')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _success
              ? Column(
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: AppColors.success),
                    const SizedBox(height: 16),
                    const Text('Nenosiri limebadilishwa!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Ingia sana kwa nenosiri jipya.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('Ingia'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const Icon(Icons.key, size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text('Weka nenosiri jipya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nenosiri jipya',
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password2Ctrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Thibitisha nenosiri',
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Weka Nenosiri'),
                    ),
                  ],
                ),
        ),
      ),
    );
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
