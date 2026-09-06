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
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _editing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMyProfile();
      if (mounted) setState(() => _profile = res.data as Map<String, dynamic>?);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return Scaffold(appBar: AppBar(title: const Text('Wasifu')),
        body: const Center(child: Text('Imeshindikana kupakia')));

    final isAdmin = _profile!['is_admin'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(isAdmin ? 'Wasifu wa Admin' : 'Wasifu Wangu'),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
              child: const Text('Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary))),
          ],
        ]),
        actions: [
          if (!_editing)
            TextButton(onPressed: () => setState(() => _editing = true), child: const Text('Hariri'))
          else
            TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Ghairi')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_message != null)
            Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
              child: Text(_message!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),

          if (_editing)
            isAdmin
                ? _EditAdminProfile(profile: _profile!, onSaved: (p) {
                    setState(() { _profile = p; _editing = false; _message = 'Imehifadhiwa!'; });
                    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _message = null); });
                  })
                : _EditProfile(profile: _profile!, onSaved: (p) {
                    setState(() { _profile = p; _editing = false; _message = 'Imehifadhiwa!'; });
                    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _message = null); });
                  })
          else
            isAdmin ? _ViewAdmin(profile: _profile!) : _ViewUser(profile: _profile!),
        ]),
      ),
    );
  }
}

// ── View Mode — Admin ─────────────────────────────────────────────────────────
class _ViewAdmin extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ViewAdmin({required this.profile});
  @override
  Widget build(BuildContext context) {
    return _Card(title: 'Taarifa za Admin', rows: [
      _Row('Jina', profile['full_name']),
      _Row('Email', profile['email']),
      _Row('Simu', profile['phone_primary']),
      _Row('Hali ya Email', profile['email_verified'] == true ? 'Imethibitishwa ✓' : 'Haijathibitishwa'),
      _Row('Jukumu', 'Administrator'),
    ]);
  }
}

// ── View Mode — Regular User ──────────────────────────────────────────────────
class _ViewUser extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ViewUser({required this.profile});
  @override
  Widget build(BuildContext context) {
    final cs = profile['current_station'] as Map? ?? {};
    final dests = profile['desired_destinations'] as List? ?? [];
    final subjects = profile['subjects'] as List? ?? [];
    final cat = profile['category'] ?? '';
    final sector = profile['employment_sector'] ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(title: 'Taarifa Binafsi', rows: [
        _Row('Jina', profile['full_name']),
        _Row('Simu', profile['phone_primary']),
        if ((profile['phone_alt'] ?? '').toString().isNotEmpty) _Row('WhatsApp', profile['phone_alt']),
        _Row('Idara', cat == 'health' ? 'Afya' : cat == 'education' ? 'Elimu' : cat),
        if (cat == 'health' && sector.isNotEmpty)
          _Row('Wizara', sector == 'wizara_afya' ? 'Wizara ya Afya' : 'TAMISEMI'),
        _Row('Kada', profile['cadre_display'] ?? profile['cadre_code'] ?? ''),
        if (subjects.isNotEmpty) _Row('Masomo', subjects.join(', ')),
      ]),
      const SizedBox(height: 12),
      _Card(title: 'Eneo la Sasa', rows: [
        _Row('Mkoa', cs['region_name']),
        _Row('Wilaya', cs['district_name']),
        _Row('Kituo', cs['facility_name'] ?? '(Hakuna)'),
      ]),
      const SizedBox(height: 12),
      if (dests.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Maeneo ya Lengo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...dests.map((d) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d['region_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${d['district_name'] ?? 'Wilaya yoyote'}${d['facility_name'] != null ? ' • ${d['facility_name']}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

// ── Edit Mode — Admin ─────────────────────────────────────────────────────────
class _EditAdminProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final void Function(Map<String, dynamic>) onSaved;
  const _EditAdminProfile({required this.profile, required this.onSaved});
  @override
  State<_EditAdminProfile> createState() => _EditAdminProfileState();
}

class _EditAdminProfileState extends State<_EditAdminProfile> {
  late TextEditingController _nameCtrl, _altCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile['full_name'] ?? '');
    _altCtrl = TextEditingController(text: widget.profile['phone_alt'] ?? '');
  }

  @override
  void dispose() { _nameCtrl.dispose(); _altCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService().updateProfile({'full_name': _nameCtrl.text.trim(), 'phone_alt': _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim()});
      final res = await ApiService().getMyProfile();
      widget.onSaved(res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() { _saving = false; _error = _parseError(e); });
    }
  }

  String _parseError(dynamic e) {
    try { final d = (e as dynamic).response?.data?['detail']; if (d is String) return d; } catch (_) {}
    return 'Imeshindikana kuhifadhi';
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null)
        Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
      _Card(title: 'Taarifa za Admin', children: [
        _field('Jina', _nameCtrl),
        const SizedBox(height: 10),
        _field('Simu ya Pili (hiari)', _altCtrl),
        const SizedBox(height: 10),
        _disabledField('Email', widget.profile['email'] ?? ''),
      ]),
      const SizedBox(height: 14),
      ElevatedButton(onPressed: _saving ? null : _save,
        child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Hifadhi')),
    ]);
  }
}

// ── Edit Mode — Regular User ──────────────────────────────────────────────────
class _EditProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final void Function(Map<String, dynamic>) onSaved;
  const _EditProfile({required this.profile, required this.onSaved});
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late TextEditingController _nameCtrl, _phoneCtrl, _altCtrl, _curPwdCtrl, _newPwdCtrl;
  bool _saving = false, _changingPwd = false;
  String? _error, _pwdMsg;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile['full_name'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile['phone_primary'] ?? '');
    _altCtrl = TextEditingController(text: widget.profile['phone_alt'] ?? '');
    _curPwdCtrl = TextEditingController();
    _newPwdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _altCtrl.dispose();
    _curPwdCtrl.dispose(); _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim(),
        'phone_alt': _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      });
      final res = await ApiService().getMyProfile();
      widget.onSaved(res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() { _saving = false; _error = _parseError(e); });
    }
  }

  Future<void> _changePwd() async {
    if (_newPwdCtrl.text.length < 6) {
      setState(() => _pwdMsg = 'Nenosiri lazima liwe na herufi 6+');
      return;
    }
    setState(() { _changingPwd = true; _pwdMsg = null; });
    try {
      await ApiService().changePassword(_curPwdCtrl.text, _newPwdCtrl.text);
      if (mounted) {
        setState(() { _pwdMsg = '✓ Nenosiri limebadilishwa'; _curPwdCtrl.clear(); _newPwdCtrl.clear(); });
      }
    } catch (e) {
      setState(() => _pwdMsg = _parseError(e));
    }
    if (mounted) setState(() => _changingPwd = false);
  }

  String _parseError(dynamic e) {
    try { final d = (e as dynamic).response?.data?['detail']; if (d is String) return d; } catch (_) {}
    return 'Imeshindikana';
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null)
        Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),

      _Card(title: 'Taarifa Binafsi', children: [
        _field('Jina Kamili', _nameCtrl),
        const SizedBox(height: 10),
        _field('Namba ya Simu', _phoneCtrl, keyboard: TextInputType.phone),
        const SizedBox(height: 10),
        _field('Namba ya WhatsApp', _altCtrl, keyboard: TextInputType.phone),
      ]),
      const SizedBox(height: 14),
      ElevatedButton(onPressed: _saving ? null : _save,
        child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Hifadhi Mabadiliko')),

      const SizedBox(height: 20),

      // Password change section
      _Card(title: 'Badilisha Nenosiri', children: [
        _field('Nenosiri la sasa', _curPwdCtrl, obscure: true),
        const SizedBox(height: 10),
        _field('Nenosiri jipya (min. 6)', _newPwdCtrl, obscure: true),
        if (_pwdMsg != null) ...[
          const SizedBox(height: 8),
          Text(_pwdMsg!, style: TextStyle(fontSize: 12,
              color: _pwdMsg!.startsWith('✓') ? Colors.green : AppColors.error)),
        ],
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _changingPwd ? null : _changePwd,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
          child: _changingPwd ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Badilisha Nenosiri')),
      ]),
    ]);
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final List<Widget>? children;
  final List<_Row>? rows;
  const _Card({required this.title, this.children, this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        if (rows != null) ...rows!,
        if (children != null) ...children!,
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final dynamic value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final v = value?.toString() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ]));
  }
}

Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboard, bool obscure = false}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    TextField(controller: ctrl, keyboardType: keyboard, obscureText: obscure,
      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true)),
  ]);
}

Widget _disabledField(String label, String value) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    TextField(controller: TextEditingController(text: value), enabled: false,
      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true,
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)))),
  ]);
}
