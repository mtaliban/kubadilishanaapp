import 'package:flutter/material.dart';
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

  void _onSaved(Map<String, dynamic> p) {
    setState(() { _profile = p; _editing = false; _message = 'Imehifadhiwa!'; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _message = null); });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return Scaffold(
        appBar: AppBar(title: const Text('Wasifu')),
        body: const Center(child: Text('Imeshindikana kupakia')));

    final isAdmin = _profile!['is_admin'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(isAdmin ? 'Wasifu wa Admin' : 'Wasifu Wangu'),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
              child: Text(_message!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
          if (_editing)
            isAdmin
                ? _EditAdminProfile(profile: _profile!, onSaved: _onSaved)
                : _EditProfile(profile: _profile!, onSaved: _onSaved)
          else
            isAdmin ? _ViewAdmin(profile: _profile!) : _ViewUser(profile: _profile!),
        ]),
      ),
    );
  }
}

// ── View: Admin ───────────────────────────────────────────────────────────────
class _ViewAdmin extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ViewAdmin({required this.profile});
  @override
  Widget build(BuildContext context) {
    return _InfoCard(title: 'Taarifa za Admin', rows: [
      _InfoRow('Jina', profile['full_name']),
      _InfoRow('Email', profile['email']),
      _InfoRow('Simu', profile['phone_primary']),
      _InfoRow('Hali ya Email', profile['email_verified'] == true ? 'Imethibitishwa ✓' : 'Haijathibitishwa'),
      _InfoRow('Jukumu', 'Administrator'),
    ]);
  }
}

// ── View: Regular User ────────────────────────────────────────────────────────
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
      _InfoCard(title: 'Utambulisho', rows: [
        _InfoRow('Jina Kamili', profile['full_name']),
        _InfoRow('Namba ya Simu', profile['phone_primary']),
        if ((profile['phone_alt'] ?? '').toString().isNotEmpty) _InfoRow('Simu ya pili', profile['phone_alt']),
        _InfoRow('Idara', cat == 'health' ? 'Afya' : cat == 'education' ? 'Elimu' : cat),
        if (cat == 'health' && sector.toString().isNotEmpty)
          _InfoRow('Wizara', sector == 'wizara_afya' ? 'Wizara ya Afya' : 'TAMISEMI'),
        _InfoRow('Kada', profile['cadre_display'] ?? profile['cadre_code'] ?? ''),
        if (subjects.isNotEmpty) _InfoRow('Masomo', subjects.join(', ')),
      ]),
      const SizedBox(height: 12),
      _InfoCard(title: 'Kituo cha Sasa', rows: [
        _InfoRow('Mkoa', cs['region_name']),
        _InfoRow('Wilaya', cs['district_name']),
        _InfoRow('Kituo', cs['facility_name'] ?? '(Hakuna)'),
      ]),
      const SizedBox(height: 12),
      _InfoCard(title: 'Ninataka Kwenda', children: [
        if (dests.isEmpty)
          const Text('Hakuna lengo', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
        else
          ...dests.map((d) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d['region_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                '${d['district_name'] ?? 'Wilaya yoyote'}${d['facility_name'] != null ? ' • ${d['facility_name']}' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          )),
      ]),
      const SizedBox(height: 60),
    ]);
  }
}

// ── Edit: Admin ───────────────────────────────────────────────────────────────
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
      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_alt': _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      });
      final res = await ApiService().getMyProfile();
      widget.onSaved(res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() { _saving = false; _error = _parseErr(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) _ErrBox(_error!),
      _InfoCard(title: 'Taarifa za Admin', children: [
        _formField('Jina', _nameCtrl),
        const SizedBox(height: 10),
        _formField('Simu ya Pili (hiari)', _altCtrl),
        const SizedBox(height: 10),
        _disabledField('Email', widget.profile['email'] ?? ''),
      ]),
      const SizedBox(height: 14),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Hifadhi')),
      const SizedBox(height: 60),
    ]);
  }
}

// ── Edit: Regular User ────────────────────────────────────────────────────────
class _EditProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final void Function(Map<String, dynamic>) onSaved;
  const _EditProfile({required this.profile, required this.onSaved});
  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late TextEditingController _nameCtrl, _phoneCtrl, _altCtrl, _curPwdCtrl, _newPwdCtrl;

  // Cadre & Subjects
  String _cadreCode = '';
  List<dynamic> _cadres = [];
  List<dynamic> _availSubjects = [];
  List<String> _subjects = [];
  bool _loadingSubjects = false;

  // Station
  int? _stationRegionId;
  int? _stationDistrictId;
  String? _stationFacilityId;
  List<dynamic> _regions = [];
  List<dynamic> _stationDistricts = [];
  List<dynamic> _stationFacilities = [];

  // Destinations
  List<Map<String, dynamic>> _destinations = [];
  Map<int, List<dynamic>> _destDistricts = {};
  Map<int, List<dynamic>> _destFacilities = {};

  bool _saving = false, _changingPwd = false;
  String? _error, _pwdMsg;

  String get _category => widget.profile['category'] as String? ?? '';

  String? get _subjectLevel {
    if (_cadreCode.isEmpty || _cadres.isEmpty) return null;
    final cadre = _cadres.firstWhere((c) => c['code'] == _cadreCode, orElse: () => null);
    final level = cadre?['level'] as String? ?? '';
    if (level == 'Secondary') return 'Secondary';
    if (level == 'Primary') return 'Primary';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile['full_name'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile['phone_primary'] ?? '');
    _altCtrl = TextEditingController(text: widget.profile['phone_alt'] ?? '');
    _curPwdCtrl = TextEditingController();
    _newPwdCtrl = TextEditingController();

    _cadreCode = widget.profile['cadre_code'] as String? ?? '';
    _subjects = (widget.profile['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    final cs = widget.profile['current_station'] as Map? ?? {};
    _stationRegionId = cs['region_id'] as int?;
    _stationDistrictId = cs['district_id'] as int?;
    final fid = cs['facility_id'];
    _stationFacilityId = fid != null ? fid.toString() : null;

    _destinations = (widget.profile['desired_destinations'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();

    _loadInitialData();
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) return (data['items'] ?? data['results'] ?? []) as List;
    return [];
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        ApiService().getRegions().then((r) => r.data),
        ApiService().getCadres(category: _category).then((r) => r.data),
      ]);
      if (!mounted) return;
      setState(() {
        _regions = _asList(results[0]);
        _cadres = _asList(results[1]);
      });
    } catch (_) {}

    if (_subjectLevel != null) _loadSubjects(_subjectLevel!);

    if (_stationRegionId != null) {
      try {
        final r = await ApiService().getDistricts(_stationRegionId!);
        if (mounted) setState(() => _stationDistricts = _asList(r.data));
      } catch (_) {}
    }
    if (_stationDistrictId != null) {
      try {
        final r = await ApiService().getFacilities(_stationDistrictId!, category: _category);
        if (mounted) setState(() => _stationFacilities = _asList(r.data));
      } catch (_) {}
    }

    final destWithRegion = _destinations.where((d) => (d['region_id'] as int? ?? 0) > 0).toList();
    if (destWithRegion.isNotEmpty) {
      try {
        final pairs = await Future.wait(
          destWithRegion.map((d) => ApiService().getDistricts(d['region_id'] as int)
              .then((r) => MapEntry(d['region_id'] as int, _asList(r.data)))));
        if (mounted) setState(() => _destDistricts = Map.fromEntries(pairs));
      } catch (_) {}
    }
  }

  Future<void> _loadSubjects(String level) async {
    if (!mounted) return;
    setState(() { _loadingSubjects = true; _availSubjects = []; });
    try {
      final r = await ApiService().getSubjects(level: level);
      if (mounted) setState(() => _availSubjects = _asList(r.data));
    } catch (_) {}
    if (mounted) setState(() => _loadingSubjects = false);
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
      final region = _regions.firstWhere((r) => r['id'] == _stationRegionId, orElse: () => null);
      final district = _stationDistricts.firstWhere((d) => d['id'] == _stationDistrictId, orElse: () => null);
      final facility = (_stationFacilityId?.isNotEmpty == true)
          ? _stationFacilities.firstWhere((f) => (f['id'] ?? f['code']).toString() == _stationFacilityId, orElse: () => null)
          : null;

      Map<String, dynamic>? station;
      if (region != null && district != null) {
        station = {
          'region_id': region['id'],
          'region_name': region['name'],
          'district_id': district['id'],
          'district_name': district['name'],
          'facility_id': facility != null ? (facility['id'] ?? facility['code']).toString() : null,
          'facility_name': facility?['name'],
        };
      }

      final dests = _destinations.map((d) {
        final rid = d['region_id'] as int? ?? 0;
        final did = d['district_id'] as int?;
        final distList = _destDistricts[rid] ?? [];
        final dd = did != null ? distList.firstWhere((x) => x['id'] == did, orElse: () => null) : null;
        return {
          'region_id': rid,
          'region_name': d['region_name'],
          'district_id': did,
          'district_name': dd?['name'] ?? d['district_name'],
          'facility_id': d['facility_id'],
          'facility_name': d['facility_name'],
        };
      }).where((d) => (d['region_id'] as int? ?? 0) > 0).toList();

      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim(),
        'phone_alt': _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
        'cadre_code': _cadreCode.isEmpty ? null : _cadreCode,
        'subjects': _subjects,
        if (station != null) 'current_station': station,
        'desired_destinations': dests,
      });
      final res = await ApiService().getMyProfile();
      widget.onSaved(res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() { _saving = false; _error = _parseErr(e); });
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
      if (mounted) setState(() { _pwdMsg = '✓ Nenosiri limebadilishwa'; _curPwdCtrl.clear(); _newPwdCtrl.clear(); });
    } catch (e) {
      setState(() => _pwdMsg = _parseErr(e));
    }
    if (mounted) setState(() => _changingPwd = false);
  }

  void _addDest() => setState(() => _destinations.add({
    'region_id': 0, 'region_name': '', 'district_id': null, 'district_name': null,
    'facility_id': null, 'facility_name': null,
  }));

  void _delDest(int i) => setState(() => _destinations.removeAt(i));

  void _updateDest(int i, Map<String, dynamic> patch) {
    setState(() => _destinations[i] = {..._destinations[i], ...patch});
    if (patch.containsKey('region_id')) {
      final rid = patch['region_id'] as int? ?? 0;
      if (rid > 0 && !_destDistricts.containsKey(rid)) {
        ApiService().getDistricts(rid).then((r) {
          if (mounted) setState(() => _destDistricts[rid] = _asList(r.data));
        }).catchError((_) {});
      }
    }
    if (patch.containsKey('district_id') && patch['district_id'] != null) {
      final did = patch['district_id'] as int;
      if (!_destFacilities.containsKey(did)) {
        ApiService().getFacilities(did, category: _category).then((r) {
          if (mounted) setState(() => _destFacilities[did] = _asList(r.data));
        }).catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) _ErrBox(_error!),

      // Card 1: Identity + Cadre + Subjects
      _InfoCard(title: 'Utambulisho', children: [
        _formField('Jina Kamili', _nameCtrl),
        const SizedBox(height: 10),
        _formField('Namba ya Simu', _phoneCtrl, keyboard: TextInputType.phone),
        const SizedBox(height: 10),
        _formField('🟢 Simu ya pili (WhatsApp)', _altCtrl, keyboard: TextInputType.phone),
        if (_cadres.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Kada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          _Dropdown<String>(
            value: _cadres.any((c) => c['code'] == _cadreCode) ? _cadreCode : null,
            hint: '— Chagua Kada —',
            items: _cadres.map((c) => DropdownMenuItem<String>(
              value: c['code'] as String,
              child: Text(c['display_name'] ?? c['code'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) {
              setState(() { _cadreCode = v ?? ''; _subjects = []; _availSubjects = []; });
              if (_subjectLevel != null) _loadSubjects(_subjectLevel!);
            },
          ),
        ],
        if (_subjectLevel != null) ...[
          const SizedBox(height: 10),
          Text('Masomo ($_subjectLevel)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_loadingSubjects)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Wrap(spacing: 6, runSpacing: 6, children: _availSubjects.map((s) {
              final code = (s['code'] ?? s['name'] ?? '').toString();
              final name = (s['name'] ?? code).toString();
              final selected = _subjects.contains(code);
              return GestureDetector(
                onTap: () => setState(() => selected ? _subjects.remove(code) : _subjects.add(code)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? AppColors.primary : AppColors.border)),
                  child: Text(name, style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w500))),
              );
            }).toList()),
        ],
      ]),
      const SizedBox(height: 14),

      // Card 2: Station
      _InfoCard(title: 'Kituo cha Sasa', children: [
        const Text('Mkoa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _Dropdown<int>(
          value: _regions.any((r) => r['id'] == _stationRegionId) ? _stationRegionId : null,
          hint: '— Chagua Mkoa —',
          items: _regions.map((r) => DropdownMenuItem<int>(
            value: r['id'] as int,
            child: Text(r['name'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) {
            setState(() { _stationRegionId = v; _stationDistrictId = null; _stationFacilityId = null; _stationDistricts = []; _stationFacilities = []; });
            if (v != null) ApiService().getDistricts(v).then((r) { if (mounted) setState(() => _stationDistricts = _asList(r.data)); }).catchError((_) {});
          },
        ),
        const SizedBox(height: 10),
        const Text('Wilaya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _Dropdown<int>(
          value: _stationDistricts.any((d) => d['id'] == _stationDistrictId) ? _stationDistrictId : null,
          hint: '— Chagua Wilaya —',
          items: _stationDistricts.map((d) => DropdownMenuItem<int>(
            value: d['id'] as int,
            child: Text(d['name'] ?? '', style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) {
            setState(() { _stationDistrictId = v; _stationFacilityId = null; _stationFacilities = []; });
            if (v != null) ApiService().getFacilities(v, category: _category).then((r) { if (mounted) setState(() => _stationFacilities = _asList(r.data)); }).catchError((_) {});
          },
        ),
        const SizedBox(height: 10),
        Text(_category == 'health' ? 'Hospitali/Kituo (hiari)' : 'Shule (hiari)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        _Dropdown<String>(
          value: (_stationFacilityId?.isNotEmpty == true && _stationFacilities.any((f) => (f['id'] ?? f['code']).toString() == _stationFacilityId)) ? _stationFacilityId : null,
          hint: _category == 'health' ? 'Hospitali/Kituo chote cha wilaya hii' : 'Shule zote za wilaya hii',
          items: _stationFacilities.map((f) {
            final id = (f['id'] ?? f['code']).toString();
            final name = f['name'] as String? ?? id;
            final type = f['type'] as String? ?? '';
            return DropdownMenuItem<String>(value: id, child: Text(type.isNotEmpty ? '$name ($type)' : name, style: const TextStyle(fontSize: 13)));
          }).toList(),
          onChanged: _stationDistrictId == null ? null : (v) => setState(() => _stationFacilityId = v),
        ),
      ]),
      const SizedBox(height: 14),

      // Card 3: Destinations
      _InfoCard(
        title: 'Ninataka Kwenda',
        trailing: TextButton(
          onPressed: _addDest,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 28)),
          child: const Text('+ Ongeza', style: TextStyle(fontSize: 12))),
        children: [
          if (_destinations.isEmpty)
            const Text('Bonyeza "+ Ongeza" kuongeza eneo la lengo',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else
            for (int i = 0; i < _destinations.length; i++) _buildDestRow(i),
        ]),
      const SizedBox(height: 14),

      ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Hifadhi Mabadiliko', style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(height: 20),

      // Card 4: Password
      _InfoCard(title: '🔑 Badilisha Nenosiri', children: [
        if (_pwdMsg != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _pwdMsg!.startsWith('✓') ? Colors.green.shade50 : AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8)),
            child: Text(_pwdMsg!, style: TextStyle(
              fontSize: 12,
              color: _pwdMsg!.startsWith('✓') ? Colors.green.shade700 : AppColors.error))),
        _formField('Nenosiri la sasa', _curPwdCtrl, obscure: true),
        const SizedBox(height: 10),
        _formField('Nenosiri jipya (min. 6)', _newPwdCtrl, obscure: true),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _changingPwd ? null : _changePwd,
          child: _changingPwd
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Badilisha Nenosiri', style: TextStyle(fontSize: 13))),
      ]),
      const SizedBox(height: 60),
    ]);
  }

  Widget _buildDestRow(int i) {
    final d = _destinations[i];
    final regionId = d['region_id'] as int? ?? 0;
    final districtId = d['district_id'] as int?;
    final facilityId = d['facility_id'] as String?;
    final districtList = _destDistricts[regionId] ?? [];
    final facilityList = districtId != null ? (_destFacilities[districtId] ?? []) : <dynamic>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: _Dropdown<int>(
              value: regionId == 0 ? null : (_regions.any((r) => r['id'] == regionId) ? regionId : null),
              hint: '— Chagua Mkoa —',
              items: _regions.map((r) => DropdownMenuItem<int>(
                value: r['id'] as int,
                child: Text(r['name'] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) {
                if (v == null) return;
                final r = _regions.firstWhere((r) => r['id'] == v, orElse: () => null);
                _updateDest(i, {'region_id': v, 'region_name': r?['name'] ?? '', 'district_id': null, 'district_name': null, 'facility_id': null, 'facility_name': null});
              },
            ),
          ),
          IconButton(
            onPressed: () => _delDest(i),
            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 8)),
        ]),
        if (regionId > 0) ...[
          const SizedBox(height: 6),
          _Dropdown<int>(
            value: districtId != null && districtList.any((x) => x['id'] == districtId) ? districtId : null,
            hint: 'Wilaya yoyote',
            items: districtList.map((x) => DropdownMenuItem<int>(
              value: x['id'] as int,
              child: Text(x['name'] ?? '', style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => _updateDest(i, {
              'district_id': v,
              'district_name': v != null ? (districtList.firstWhere((x) => x['id'] == v, orElse: () => null)?['name']) : null,
              'facility_id': null,
              'facility_name': null,
            }),
          ),
        ],
        if (districtId != null && facilityList.isNotEmpty) ...[
          const SizedBox(height: 6),
          _Dropdown<String>(
            value: facilityId != null && facilityList.any((f) => (f['id'] ?? f['code']).toString() == facilityId) ? facilityId : null,
            hint: _category == 'health' ? 'Hospitali/Kituo chote' : 'Shule zote',
            items: facilityList.map((f) {
              final fid = (f['id'] ?? f['code']).toString();
              final fname = f['name'] as String? ?? fid;
              final ftype = f['type'] as String? ?? '';
              return DropdownMenuItem<String>(value: fid, child: Text(ftype.isNotEmpty ? '$fname ($ftype)' : fname, style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (v) {
              final fac = v != null ? facilityList.firstWhere((f) => (f['id'] ?? f['code']).toString() == v, orElse: () => null) : null;
              _updateDest(i, {'facility_id': v, 'facility_name': fac?['name']});
            },
          ),
        ],
      ]),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget>? children;
  final List<_InfoRow>? rows;
  const _InfoCard({required this.title, this.trailing, this.children, this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 10),
        if (rows != null) ...rows!,
        if (children != null) ...children!,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final v = value?.toString() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ]));
  }
}

class _ErrBox extends StatelessWidget {
  final String message;
  const _ErrBox(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12)));
  }
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  const _Dropdown({required this.hint, required this.items, this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true),
      hint: Text(hint, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      items: items,
      onChanged: onChanged,
    );
  }
}

Widget _formField(String label, TextEditingController ctrl, {TextInputType? keyboard, bool obscure = false}) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    TextField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true)),
  ]);
}

Widget _disabledField(String label, String value) {
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    TextField(
      controller: TextEditingController(text: value),
      enabled: false,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border)))),
  ]);
}

String _parseErr(dynamic e) {
  try { final d = (e as dynamic).response?.data?['detail']; if (d is String) return d; } catch (_) {}
  return 'Imeshindikana';
}
