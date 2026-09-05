/// Profile screen — view and edit user profile.
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
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _editing = false;
  bool _loading = false;
  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  int? _regionId;
  int? _districtId;
  int? _facilityId;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      setState(() => _regions = res.data);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasifu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                user.fullName.split(' ').map((w) => w[0]).take(2).join().toUpperCase(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(user.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user.phone, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (user.isVerified)
              const Chip(label: Text('✓ Imethibitishwa', style: TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: AppColors.success)
            else
              const Chip(label: Text('✗ Haijathibitishwa', style: TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: AppColors.warning),
            const SizedBox(height: 16),

            // Info cards
            _infoCard('Idara', user.category == 'education' ? 'Elimu' : user.category == 'health' ? 'Afya' : '—', Icons.school),
            _infoCard('Kada', user.cadreCode ?? '—', Icons.badge),
            _infoCard('Eneo', user.currentStation?['region_name'] ?? '—', Icons.location_on),
            _infoCard('Wilaya', user.currentStation?['district_name'] ?? '—', Icons.map),
            _infoCard('Kituo', user.currentStation?['facility_name'] ?? '—', Icons.business),
            _infoCard('Mikoa Unayotaka', (user.currentStation?['destinations'] ?? []).isNotEmpty
                ? (user.currentStation!['destinations'] as List).map((d) => d['name'] ?? d).join(', ')
                : '—', Icons.flag),

            const SizedBox(height: 16),

            // Edit / Save button
            if (_editing)
              ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Hifadhi'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Hariri Wasifu'),
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
        title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'region_id': _regionId,
        'district_id': _districtId,
        'facility_id': _facilityId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wasifu umesasishwa!'), backgroundColor: AppColors.success));
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hitilafu — jaribu tena'), backgroundColor: AppColors.error));
      }
    } finally {
      setState(() => _loading = false);
    }
  }
}
