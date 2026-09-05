/// Profile screen — view info, edit profile, change password, logout.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Password change
  final _curPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _obscureCur = true;
  bool _obscureNew = true;
  bool _changingPass = false;

  @override
  void dispose() {
    _curPassCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasifu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + Name
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                user.fullName
                    .split(' ')
                    .map((w) => w.isNotEmpty ? w[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase(),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(user.fullName,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user.phone,
                style:
                    const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (user.isVerified)
              const Chip(
                label: Text('✓ Imethibitishwa',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12)),
                backgroundColor: AppColors.success,
              )
            else
              const Chip(
                label: Text('✗ Haijathibitishwa',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12)),
                backgroundColor: AppColors.warning,
              ),
            const SizedBox(height: 16),

            // Info cards
            _infoCard(
              'Idara',
              user.category == 'education'
                  ? 'Elimu'
                  : user.category == 'health'
                      ? 'Afya'
                      : user.category ?? '—',
              Icons.school,
            ),
            _infoCard(
                'Kada',
                user.cadreDisplay ?? user.cadreCode ?? '—',
                Icons.badge),
            if (user.employmentSector != null)
              _infoCard('Sekta', user.employmentSector!, Icons.work),
            _infoCard(
                'Mkoa',
                user.currentStation?['region_name'] ?? '—',
                Icons.location_on),
            _infoCard(
                'Wilaya',
                user.currentStation?['district_name'] ?? '—',
                Icons.map),
            _infoCard(
                'Kituo',
                user.currentStation?['facility_name'] ?? '—',
                Icons.business),
            const SizedBox(height: 8),

            // Payment status / donate CTA
            if (!user.isVerified)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/donate'),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Lipia TZS 2,000 — Pata Ufikiaji'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning)),
                ),
              ),

            const Divider(height: 32),

            // Password change section
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Badilisha Nenosiri',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _curPassCtrl,
              obscureText: _obscureCur,
              decoration: InputDecoration(
                labelText: 'Nenosiri la Sasa',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCur
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureCur = !_obscureCur),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPassCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Nenosiri Jipya',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changingPass ? null : _changePassword,
                child: _changingPass
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Hifadhi Nenosiri'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _changePassword() async {
    final cur = _curPassCtrl.text;
    final nw = _newPassCtrl.text;
    if (cur.isEmpty || nw.isEmpty) return;
    if (nw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenosiri jipya lazima liwe na herufi 6+'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _changingPass = true);
    try {
      await ApiService().changePassword(cur, nw);
      _curPassCtrl.clear();
      _newPassCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nenosiri limebadilishwa!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      String msg = 'Hitilafu — jaribu tena';
      try {
        final detail = (e as dynamic).response?.data?['detail'];
        if (detail is String) msg = detail;
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }
}
