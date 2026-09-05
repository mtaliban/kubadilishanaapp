/// Profile screen — view, edit profile, change password, logout.
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
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getMyProfile();
      setState(() {
        _profile = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasifu'),
        actions: [
          if (!_editMode)
            TextButton(
              onPressed: () => setState(() => _editMode = true),
              child: const Text('Hariri',
                  style: TextStyle(color: Colors.white)),
            )
          else
            TextButton(
              onPressed: () => setState(() => _editMode = false),
              child: const Text('Ghairi',
                  style: TextStyle(color: Colors.white70)),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Mipangilio',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _editMode
            ? _EditProfile(
                profile: _profile!,
                onSaved: () {
                  _load();
                  setState(() => _editMode = false);
                },
              )
            : _ViewProfile(profile: _profile!, user: user),
      ),
    );
  }
}

// ─── VIEW MODE ───────────────────────────────────────────────────────────────
class _ViewProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final dynamic user;
  const _ViewProfile({required this.profile, required this.user});

  @override
  State<_ViewProfile> createState() => _ViewProfileState();
}

class _ViewProfileState extends State<_ViewProfile> {
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
    final p = widget.profile;
    final user = widget.user;
    final station = p['current_station'] as Map<String, dynamic>? ?? {};
    final dests = p['desired_destinations'] as List? ?? [];
    final subjects = p['subjects'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar + name
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  (p['full_name'] ?? 'U').split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(p['full_name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(p['phone_primary'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              if (user.isVerified)
                const Chip(label: Text('✓ Imethibitishwa', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: AppColors.success)
              else
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/donate'),
                  icon: const Icon(Icons.payment, size: 14),
                  label: const Text('Lipia TZS 2,000 — Pata Ufikiaji', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning, side: const BorderSide(color: AppColors.warning)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Identity
        _section('Utambulisho', [
          _row('Idara', p['category'] == 'health' ? 'Afya' : p['category'] == 'education' ? 'Elimu' : '—', Icons.school),
          if (p['employment_sector'] != null)
            _row('Sekta', p['employment_sector'] == 'wizara_afya' ? 'Wizara ya Afya' : 'TAMISEMI', Icons.work),
          _row('Kada', p['cadre_display'] ?? p['cadre_code'] ?? '—', Icons.badge),
          if (p['phone_alt'] != null) _row('Simu Mbadala', p['phone_alt'], Icons.phone),
          if (subjects.isNotEmpty) _row('Masomo', subjects.join(', '), Icons.book),
        ]),
        const SizedBox(height: 12),

        // Current station
        _section('Kituo cha Sasa', [
          _row('Mkoa', station['region_name'] ?? '—', Icons.location_on),
          _row('Wilaya', station['district_name'] ?? '—', Icons.map),
          _row('Kituo/Shule', station['facility_name'] ?? '—', Icons.business),
        ]),
        const SizedBox(height: 12),

        // Desired destinations
        _section('Maeneo Unayotaka', dests.isEmpty
            ? [_row('—', 'Hakuna eneo lililochaguliwa', Icons.flag)]
            : dests.map((d) => _row(
                d['region_name'] ?? '',
                [d['district_name'], d['facility_name']].where((x) => x != null && x.toString().isNotEmpty).join(' • '),
                Icons.flag_outlined,
              )).toList()),
        const SizedBox(height: 16),

        // Password change
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Badilisha Nenosiri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                TextField(
                  controller: _curPassCtrl,
                  obscureText: _obscureCur,
                  decoration: InputDecoration(
                    labelText: 'Nenosiri la Sasa',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCur ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureCur = !_obscureCur),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nenosiri Jipya (min 6)',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _changingPass ? null : _changePassword,
                    child: _changingPass
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Hifadhi Nenosiri'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary)),
            const Divider(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final cur = _curPassCtrl.text;
    final nw = _newPassCtrl.text;
    if (cur.isEmpty || nw.isEmpty) return;
    if (nw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenosiri jipya lazima liwe herufi 6+'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _changingPass = true);
    try {
      await ApiService().changePassword(cur, nw);
      _curPassCtrl.clear();
      _newPassCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenosiri limebadilishwa!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      String msg = 'Hitilafu — jaribu tena';
      try {
        final d = (e as dynamic).response?.data?['detail'];
        if (d is String) msg = d;
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }
}

// ─── EDIT MODE ────────────────────────────────────────────────────────────────
class _EditProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onSaved;
  const _EditProfile({required this.profile, required this.onSaved});

  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _phoneAltCtrl;
  bool _saving = false;

  // Cadre
  List<dynamic> _cadres = [];
  String _cadreCode = '';

  // Subjects
  List<dynamic> _subjects = [];
  List<String> _selectedSubjects = [];

  // Station
  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  int? _regionId;
  int? _districtId;
  String? _facilityId;

  // Destinations
  List<Map<String, dynamic>> _destinations = [];
  Map<int, List<dynamic>> _destDistricts = {};

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p['full_name'] ?? '');
    _phoneCtrl = TextEditingController(text: p['phone_primary'] ?? '');
    _phoneAltCtrl = TextEditingController(text: p['phone_alt'] ?? '');
    _cadreCode = p['cadre_code'] ?? '';
    _selectedSubjects = List<String>.from(p['subjects'] ?? []);
    final st = p['current_station'] as Map<String, dynamic>? ?? {};
    _regionId = st['region_id'] as int?;
    _districtId = st['district_id'] as int?;
    _facilityId = st['facility_id']?.toString();
    _destinations = (p['desired_destinations'] as List? ?? []).map((d) => Map<String, dynamic>.from(d as Map)).toList();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _loadRegions();
    if (_regionId != null) await _loadDistricts(_regionId!);
    if (_districtId != null) await _loadFacilities(_districtId!);
    await _loadCadres();
    await _loadSubjects();
    for (final d in _destinations) {
      if (d['region_id'] != null) {
        final rid = d['region_id'] as int;
        if (!_destDistricts.containsKey(rid)) {
          try {
            final r = await ApiService().getDistricts(rid);
            if (mounted) setState(() => _destDistricts[rid] = r.data as List);
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _loadRegions() async {
    try {
      final r = await ApiService().getRegions();
      if (mounted) setState(() => _regions = r.data as List);
    } catch (_) {}
  }

  Future<void> _loadDistricts(int regionId) async {
    try {
      final r = await ApiService().getDistricts(regionId);
      if (mounted) setState(() => _districts = r.data as List);
    } catch (_) {}
  }

  Future<void> _loadFacilities(int districtId) async {
    try {
      final cat = widget.profile['category'] ?? 'health';
      final r = await ApiService().getFacilities(districtId, category: cat);
      if (mounted) setState(() => _facilities = r.data as List);
    } catch (_) {}
  }

  Future<void> _loadCadres() async {
    try {
      final cat = widget.profile['category'] as String?;
      final r = await ApiService().getCadres(category: cat);
      if (mounted) setState(() => _cadres = r.data as List);
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    try {
      final r = await ApiService().getSubjects();
      if (mounted) setState(() => _subjects = r.data as List);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneAltCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.profile['category'] as String? ?? '';
    final isEdu = cat == 'education';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Identity
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Utambulisho', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Jina Kamili')),
                const SizedBox(height: 8),
                TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Simu ya Kwanza')),
                const SizedBox(height: 8),
                TextField(controller: _phoneAltCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '🟢 Simu ya WhatsApp')),
                if (_cadres.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _cadreCode.isNotEmpty && _cadres.any((c) => c['code'] == _cadreCode) ? _cadreCode : null,
                    decoration: const InputDecoration(labelText: 'Kada'),
                    items: _cadres.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['code'] as String, child: Text(c['display_name'] ?? c['code'], style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() { _cadreCode = v ?? ''; _selectedSubjects = []; }),
                  ),
                ],
                if (isEdu && _subjects.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Masomo:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _subjects.map((s) {
                      final code = s['code'] as String;
                      final sel = _selectedSubjects.contains(code);
                      return FilterChip(
                        label: Text(s['name'] ?? code, style: const TextStyle(fontSize: 11)),
                        selected: sel,
                        onSelected: (_) => setState(() { sel ? _selectedSubjects.remove(code) : _selectedSubjects.add(code); }),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: sel ? Colors.white : null),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Current station
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kituo cha Sasa', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _regionId,
                  decoration: const InputDecoration(labelText: 'Mkoa'),
                  items: _regions.map<DropdownMenuItem<int>>((r) => DropdownMenuItem(value: r['id'] as int, child: Text(r['name'] as String))).toList(),
                  onChanged: (v) {
                    setState(() { _regionId = v; _districtId = null; _facilityId = null; _facilities = []; });
                    if (v != null) _loadDistricts(v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _districtId,
                  decoration: const InputDecoration(labelText: 'Wilaya'),
                  items: _districts.map<DropdownMenuItem<int>>((d) => DropdownMenuItem(value: d['id'] as int, child: Text(d['name'] as String))).toList(),
                  onChanged: (v) {
                    setState(() { _districtId = v; _facilityId = null; });
                    if (v != null) _loadFacilities(v);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _facilities.any((f) => (f['id'] ?? f['code'])?.toString() == _facilityId) ? _facilityId : null,
                  decoration: InputDecoration(labelText: isEdu ? 'Shule (hiari)' : 'Kituo cha Afya (hiari)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— Chochote —')),
                    ..._facilities.map<DropdownMenuItem<String>>((f) {
                      final id = (f['id'] ?? f['code']).toString();
                      return DropdownMenuItem(value: id, child: Text(f['name'] as String, style: const TextStyle(fontSize: 13)));
                    }),
                  ],
                  onChanged: (v) => setState(() => _facilityId = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Desired destinations
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Maeneo Unayotaka', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => setState(() => _destinations.add({'region_id': null, 'region_name': '', 'district_id': null, 'district_name': null})),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ongeza', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                ..._destinations.asMap().entries.map((e) {
                  final i = e.key;
                  final d = e.value;
                  final rid = d['region_id'] as int?;
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: rid != null && _regions.any((r) => r['id'] == rid) ? rid : null,
                                decoration: const InputDecoration(labelText: 'Mkoa', isDense: true),
                                items: _regions.map<DropdownMenuItem<int>>((r) => DropdownMenuItem(value: r['id'] as int, child: Text(r['name'] as String, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) {
                                  setState(() {
                                    _destinations[i] = {..._destinations[i], 'region_id': v, 'region_name': _regions.firstWhere((r) => r['id'] == v, orElse: () => {'name': ''})['name'], 'district_id': null, 'district_name': null};
                                    _destDistricts.remove(rid);
                                  });
                                  if (v != null) {
                                    ApiService().getDistricts(v).then((r) {
                                      if (mounted) setState(() => _destDistricts[v] = r.data as List);
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => setState(() => _destinations.removeAt(i))),
                          ],
                        ),
                        if (rid != null && (_destDistricts[rid] ?? []).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: DropdownButtonFormField<int>(
                              value: d['district_id'] as int?,
                              decoration: const InputDecoration(labelText: 'Wilaya (hiari)', isDense: true),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('— Yoyote —', style: TextStyle(fontSize: 12))),
                                ...(_destDistricts[rid] ?? []).map<DropdownMenuItem<int>>((dd) => DropdownMenuItem(value: dd['id'] as int, child: Text(dd['name'] as String, style: const TextStyle(fontSize: 12)))),
                              ],
                              onChanged: (v) => setState(() => _destinations[i] = {..._destinations[i], 'district_id': v, 'district_name': v == null ? null : (_destDistricts[rid] ?? []).firstWhere((dd) => dd['id'] == v, orElse: () => {'name': ''})['name']}),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Hifadhi Mabadiliko'),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final st = widget.profile['current_station'] as Map<String, dynamic>? ?? {};
      final region = _regions.firstWhere((r) => r['id'] == _regionId, orElse: () => st);
      final district = _districts.firstWhere((d) => d['id'] == _districtId, orElse: () => st);
      final facility = _facilityId != null ? _facilities.firstWhere((f) => (f['id'] ?? f['code']).toString() == _facilityId, orElse: () => {}) : null;

      final dests = _destinations.where((d) => d['region_id'] != null).map((d) => {
        'region_id': d['region_id'],
        'region_name': d['region_name'] ?? '',
        'district_id': d['district_id'],
        'district_name': d['district_name'],
        'facility_id': null,
        'facility_name': null,
      }).toList();

      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        'phone_alt': _phoneAltCtrl.text.trim().isNotEmpty ? _phoneAltCtrl.text.trim() : null,
        if (_cadreCode.isNotEmpty) 'cadre_code': _cadreCode,
        if (_selectedSubjects.isNotEmpty) 'subjects': _selectedSubjects,
        'current_station': {
          'region_id': _regionId,
          'region_name': region['name'] ?? st['region_name'],
          'district_id': _districtId,
          'district_name': district['name'] ?? st['district_name'],
          'facility_id': _facilityId,
          'facility_name': facility?['name'] ?? st['facility_name'],
        },
        if (dests.isNotEmpty) 'desired_destinations': dests,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wasifu umehifadhiwa!'), backgroundColor: AppColors.success));
        widget.onSaved();
      }
    } catch (e) {
      String msg = 'Hitilafu — jaribu tena';
      try {
        final d = (e as dynamic).response?.data?['detail'];
        if (d is String) msg = d;
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
