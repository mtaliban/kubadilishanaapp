import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../widgets/select_sheet.dart';
import 'admin_users_v2_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// V2 SCREENS: Picker (ukurasa kamili na search), Fomu (unda/hariri),
// Detail, AddAdmin, Import — zote kwa mtindo wa watumiaji_v2 + API halisi.
// ═══════════════════════════════════════════════════════════════════════════

/// Chaguo la picker: id + jina (id inaweza kuwa null = "yote/hiari")
typedef V2PickOption = ({String? id, String name});

// ═══════════════════════════════ PICKER SCREEN ═══════════════════════════════
class V2PickerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String allLabel;
  final List<V2PickOption> options;
  final String? selectedId;

  const V2PickerScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.allLabel,
    required this.options,
    this.selectedId,
  });

  @override
  State<V2PickerScreen> createState() => _V2PickerScreenState();
}

class _V2PickerScreenState extends State<V2PickerScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final filtered = widget.options
        .where((o) => o.name.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (widget.subtitle != null)
            Text(widget.subtitle!,
                style: const TextStyle(fontSize: 11, color: v2TextMuted)),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Tafuta ${widget.title.toLowerCase()}...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              // Safu ya "yote / ghairi"
              ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: v2SurfaceMuted,
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.public_outlined,
                      size: 17, color: v2TextSecondary),
                ),
                title: Text(widget.allLabel,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: widget.selectedId == null
                    ? const Icon(Icons.check_circle, color: v2Accent, size: 18)
                    : null,
                onTap: () =>
                    Navigator.pop(context, (id: null, name: null)),
              ),
              const Divider(height: 1, color: v2Border),
              for (final o in filtered)
                ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(                      color: v2AccentBg,
                      borderRadius: BorderRadius.circular(9)),
                    child: Icon(widget.icon, size: 17, color: v2Accent),
                  ),
                  title: Text(o.name, style: const TextStyle(fontSize: 13.5)),
                  trailing: widget.selectedId == o.id
                      ? const Icon(Icons.check_circle, color: v2Accent, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, (id: o.id, name: o.name)),
                ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: Text('Hakuna kilicho Patikana',
                          style: TextStyle(color: v2TextMuted))),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ USER FORM ═══════════════════════════════
class V2UserFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<dynamic> regions;
  const V2UserFormScreen({super.key, this.existing, required this.regions});

  @override
  State<V2UserFormScreen> createState() => _V2UserFormScreenState();
}

class _V2UserFormScreenState extends State<V2UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _jinaCtrl;
  late final TextEditingController _simuCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _passCtrl;

  String _category = 'education';
  String? _cadreCode;
  String? _wizara;
  final Set<String> _masomo = {};
  int? _regionId; String? _regionName;
  int? _districtId; String? _districtName;
  String? _facilityId; String? _facilityName;
  bool _active = true;
  bool _admin = false;
  bool _verified = false;
  final List<Map<String, String>> _kwenda = []; // region_id/name + district_id/name

  List<dynamic> _departments = [];
  List<dynamic> _cadres = [];
  List<dynamic> _subjects = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _jinaCtrl = TextEditingController(text: m?['full_name'] as String? ?? '');
    _simuCtrl =
        TextEditingController(text: m?['phone_primary'] as String? ?? '');
    _waCtrl = TextEditingController(
        text: m?['phone_alt'] as String? ?? m?['phone_whatsapp'] as String? ?? '');
    _passCtrl = TextEditingController();
    _category = '${m?['category'] ?? 'education'}';
    _cadreCode = m?['cadre_code'] as String?;
    _wizara = m?['ministry'] as String?;
    _active = '${m?['status'] ?? 'active'}'.toLowerCase() != 'disabled';
    _admin = m?['is_admin'] as bool? ?? false;
    _verified = m?['is_verified'] as bool? ?? false;
    final st = m?['current_station'] as Map? ?? {};
    _regionId = st['region_id'] as int?;
    _regionName = st['region_name'] as String?;
    _districtId = st['district_id'] as int?;
    _districtName = st['district_name'] as String?;
    _facilityId = st['facility_id']?.toString();
    _facilityName = st['facility_name'] as String?;
    for (final s in (m?['subjects'] as List? ?? [])) {
      _masomo.add('${s['code'] ?? s['name'] ?? s}');
    }
    for (final d in (m?['desired_destinations'] as List? ?? [])) {
      if (d is Map) {
        _kwenda.add({
          'region_id': '${d['region_id'] ?? ''}',
          'region_name': '${d['region_name'] ?? d['region'] ?? ''}',
          'district_id': '${d['district_id'] ?? ''}',
          'district_name': '${d['district_name'] ?? ''}',
        });
      }
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      if (!mounted) return;
      setState(() => _departments =
          raw is List ? raw : (raw['results'] ?? raw['items'] ?? raw['data'] ?? []));
    } catch (_) {}
    _loadCadres();
    if (_category == 'education') _loadSubjects();
    if (_regionId != null) _loadDistricts();
    if (_districtId != null) _loadFacilities();
  }

  Future<void> _loadCadres() async {
    try {
      final r = await ApiService().getCadres(category: _category);
      final raw = r.data;
      if (!mounted) return;
      setState(() => _cadres = raw is List ? raw : (raw['cadres'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    try {
      final r = await ApiService().getSubjects(level: 'Primary');
      final raw = r.data;
      if (!mounted) return;
      setState(() => _subjects = raw is List ? raw : (raw['subjects'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadDistricts() async {
    if (_regionId == null) return;
    try {
      final r = await ApiService().getDistricts(_regionId!);
      final raw = r.data;
      if (!mounted) return;
      setState(() => _districts = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadFacilities() async {
    if (_districtId == null) return;
    try {
      final r = await ApiService().getFacilities(_districtId!, category: _category);
      final raw = r.data;
      if (!mounted) return;
      setState(
          () => _facilities = raw is List ? raw : (raw['facilities'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  String _deptLabel() {
    for (final d in _departments) {
      if ('${d['code']}' == _category) {
        return '${d['display_name'] ?? d['name'] ?? _category}';
      }
    }
    if (_category == 'health') return 'Afya';
    if (_category == 'education') return 'Elimu';
    if (_category == 'service') return 'Utumishi';
    return _category.isEmpty ? 'Chagua idara' : _category;
  }

  String _cadreLabel() {
    for (final c in _cadres) {
      if ('${c['code']}' == _cadreCode) {
        return '${c['display_name'] ?? c['name'] ?? _cadreCode}';
      }
    }
    return _cadreCode ?? '';
  }

  Future<void> _pickCategory() async {
    final opts = <({String value, String label, String? subtitle})>[
      for (final d in _departments)
        (
          value: '${d['code']}',
          label: '${d['display_name'] ?? d['name'] ?? d['code']}',
          subtitle: null
        ),
    ];
    if (opts.isEmpty) return;
    final picked = await showSelectSheet<String>(context,
        title: 'Chagua Idara', items: opts, selected: _category, searchable: false);
    if (picked == null || picked == _category) return;
    setState(() {
      _category = picked;
      _cadreCode = null;
      _cadres = [];
      _masomo.clear();
      _subjects = [];
    });
    _loadCadres();
    if (picked == 'education') _loadSubjects();
  }

  Future<void> _pickCadre() async {
    final opts = <({String value, String label, String? subtitle})>[
      for (final c in _cadres)
        (
          value: '${c['code']}',
          label: '${c['display_name'] ?? c['name'] ?? c['code']}',
          subtitle: '${c['code']}'
        ),
    ];
    final picked = await showSelectSheet<String>(context,
        title: 'Chagua Kada', items: opts, selected: _cadreCode, searchable: true);
    if (picked != null) setState(() => _cadreCode = picked);
  }

  Future<void> _pickMkoa() async {
    final picked = await _openPicker(
      title: 'Chagua Mkoa',
      allLabel: 'Mikoa yote',
      options: [
        for (final r in widget.regions)
          (
            id: '${r['id'] ?? r['region_id'] ?? ''}',
            name: '${r['name'] ?? r['region_name'] ?? ''}'
          ),
      ],
      selectedId: _regionId?.toString(),
    );
    if (picked == null) return;
    setState(() {
      _regionId = picked.id == null ? null : int.tryParse(picked.id!);
      _regionName = picked.name;
      _districtId = null; _districtName = null;
      _facilityId = null; _facilityName = null;
      _districts = []; _facilities = [];
    });
    if (picked.id != null) _loadDistricts();
  }

  Future<void> _pickWilaya() async {
    if (_regionId == null) return;
    final picked = await _openPicker(
      title: 'Chagua Wilaya',
      subtitle: 'Ndani ya ${_regionName ?? ''}',
      allLabel: 'Wilaya zote',
      options: [
        for (final d in _districts)
          (
            id: '${d['id'] ?? d['district_id'] ?? ''}',
            name: '${d['name'] ?? d['district_name'] ?? ''}'
          ),
      ],
      selectedId: _districtId?.toString(),
    );
    if (picked == null) return;
    setState(() {
      _districtId = picked.id == null ? null : int.tryParse(picked.id!);
      _districtName = picked.name;
      _facilityId = null; _facilityName = null;
      _facilities = [];
    });
    if (picked.id != null) _loadFacilities();
  }

  Future<void> _pickKituo() async {
    if (_districtId == null) return;
    final picked = await _openPicker(
      title: 'Chagua Kituo',
      subtitle: 'Ndani ya ${_districtName ?? ''}',
      allLabel: 'Vituo vyote',
      options: [
        for (final f in _facilities)
          (
            id: '${f['id'] ?? f['code'] ?? ''}',
            name: '${f['name'] ?? f['facility_name'] ?? ''}'
          ),
      ],
      selectedId: _facilityId,
    );
    if (picked == null) return;
    setState(() {
      _facilityId = picked.id;
      _facilityName = picked.name;
    });
  }

  Future<void> _addKwenda() async {
    final mkoa = await _openPicker(
      title: 'Mkoa anaotaka kwenda',
      allLabel: '-- Chagua mkoa --',
      options: [
        for (final r in widget.regions)
          (
            id: '${r['id'] ?? r['region_id'] ?? ''}',
            name: '${r['name'] ?? r['region_name'] ?? ''}'
          ),
      ],
    );
    if (mkoa == null || mkoa.id == null) return;
    // Wilaya (hiari)
    List<dynamic> dists = [];
    try {
      final r = await ApiService().getDistricts(int.parse(mkoa.id!));
      final raw = r.data;
      dists = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []);
    } catch (_) {}
    String? distId; String? distName;
    if (dists.isNotEmpty && mounted) {
      final wilaya = await _openPicker(
        title: 'Wilaya (hiari)',
        subtitle: 'Ndani ya ${mkoa.name}',
        allLabel: '-- Wilaya yoyote --',
        options: [
          for (final d in dists)
            (
              id: '${d['id'] ?? d['district_id'] ?? ''}',
              name: '${d['name'] ?? d['district_name'] ?? ''}'
            ),
        ],
      );
      if (wilaya != null && wilaya.id != null) {
        distId = wilaya.id;
        distName = wilaya.name;
      }
    }
    setState(() => _kwenda.add({
          'region_id': mkoa.id!,
          'region_name': mkoa.name,
          'district_id': distId ?? '',
          'district_name': distName ?? '',
        }));
  }

  Future<V2PickOption?> _openPicker({
    required String title,
    String? subtitle,
    required String allLabel,
    required List<V2PickOption> options,
    String? selectedId,
  }) {
    return Navigator.of(context).push<V2PickOption>(MaterialPageRoute(
      builder: (_) => V2PickerScreen(
          title: title,
          subtitle: subtitle,
          icon: Icons.location_on_outlined,
          allLabel: allLabel,
          options: options,
          selectedId: selectedId),
    ));
  }

  Future<void> _hifadhi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cadreCode == null) {
      setState(() => _error = 'Chagua idara na kada kwanza');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final station = <String, dynamic>{
      if (_regionId != null) 'region_id': _regionId,
      if (_regionName != null && _regionName!.isNotEmpty)
        'region_name': _regionName,
      if (_districtId != null) 'district_id': _districtId,
      if (_districtName != null && _districtName!.isNotEmpty)
        'district_name': _districtName,
      if (_facilityId != null && _facilityId!.isNotEmpty)
        'facility_id': _facilityId,
      if (_facilityName != null && _facilityName!.isNotEmpty)
        'facility_name': _facilityName,
    };
    final dests = [
      for (final k in _kwenda)
        {
          'region_id': int.tryParse(k['region_id'] ?? '') ?? 0,
          'region_name': k['region_name'],
          if ((k['district_id'] ?? '').isNotEmpty)
            'district_id': int.tryParse(k['district_id']!),
          if ((k['district_name'] ?? '').isNotEmpty)
            'district_name': k['district_name'],
        },
    ];
    try {
      if (_isEditing) {
        await ApiService().adminUpdateUser(
          '${widget.existing!['user_id'] ?? widget.existing!['_id']}',
          {
            'full_name': _jinaCtrl.text.trim(),
            'phone_primary': _simuCtrl.text.trim(),
            'phone_alt': _waCtrl.text.trim().isEmpty ? null : _waCtrl.text.trim(),
            'category': _category,
            'cadre_code': _cadreCode,
            'status': _active ? 'active' : 'disabled',
            'is_admin': _admin,
            'is_verified': _verified,
            'current_station': station,
            'desired_destinations': dests,
            if (_passCtrl.text.isNotEmpty) 'new_password': _passCtrl.text,
          },
        );
      } else {
        await ApiService().adminCreateUser({
          'full_name': _jinaCtrl.text.trim(),
          'phone_primary': _simuCtrl.text.trim(),
          if (_waCtrl.text.trim().isNotEmpty) 'phone_alt': _waCtrl.text.trim(),
          'password': _passCtrl.text,
          'category': _category,
          'cadre_code': _cadreCode,
          'is_admin': _admin,
          'is_verified': _verified,
          'status': _active ? 'active' : 'disabled',
          if (station.isNotEmpty) 'current_station': station,
          if (dests.isNotEmpty) 'desired_destinations': dests,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    _jinaCtrl.dispose();
    _simuCtrl.dispose();
    _waCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showMasomo = _category == 'education';
    final showWizara = _category != 'education';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(_isEditing ? 'Hariri Mtumiaji' : 'Unda Mtumiaji Mpya',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _hifadhi,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(PhosphorIcons.check(), size: 17),
              label: const Text('Hifadhi',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: v2Accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: v2DangerBg, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12.5, color: v2Danger)),
              ),

            _label('Jina Kamili *'),
            TextFormField(
              controller: _jinaCtrl,
              decoration: const InputDecoration(hintText: 'Juma Kiswili'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Jina linahitajika' : null,
            ),
            const SizedBox(height: 12),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Namba ya Simu *'),
                      TextFormField(
                        controller: _simuCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration:
                            const InputDecoration(hintText: '0712345678'),
                        validator: (v) => (v == null || v.trim().length < 9)
                            ? 'Namba si sahihi'
                            : null,
                      ),
                    ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('WhatsApp'),
                      TextFormField(
                        controller: _waCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration:
                            const InputDecoration(hintText: '0755666777'),
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 12),

            _label(_isEditing ? 'Nywila Mpya (acha wazi kama hubadilishi)' : 'Nywila *'),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: '••••••'),
              validator: (v) {
                if (_isEditing && (v == null || v.isEmpty)) return null;
                if (v == null || v.length < 6) return 'Herufi 6+';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _label('Idara *'),
            InkWell(
              onTap: _pickCategory,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: v2Border),
                    borderRadius: BorderRadius.circular(10),
                    color: v2Surface),
                child: Row(children: [
                  Icon(PhosphorIcons.squaresFour(),
                      size: 16, color: v2TextSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_deptLabel(),
                          style: const TextStyle(fontSize: 13))),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: v2TextMuted),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            _label('Kada *'),
            InkWell(
              onTap: _pickCadre,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                    border: Border.all(color: v2Border),
                    borderRadius: BorderRadius.circular(10),
                    color: v2Surface),
                child: Row(children: [
                  Icon(PhosphorIcons.identificationBadge(),
                      size: 16, color: v2TextSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_cadreLabel().isEmpty
                          ? (_category.isEmpty
                              ? 'Chagua idara kwanza'
                              : 'Chagua kada')
                          : _cadreLabel(),
                          style: TextStyle(
                              fontSize: 13,
                              color: _cadreLabel().isEmpty
                                  ? v2TextMuted
                                  : v2TextPrimary))),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 16, color: v2TextMuted),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            if (showWizara) ...[
              _label('Wizara / Taasisi'),
              TextFormField(
                initialValue: _wizara,
                onChanged: (v) => _wizara = v,
                decoration:
                    const InputDecoration(hintText: 'mf. Wizara ya Afya'),
              ),
              const SizedBox(height: 12),
            ],

            if (showMasomo) ...[
              _label('Masomo (chagua unayofundisha)'),
              if (_subjects.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('Hakuna masomo yaliyopakiwa',
                      style: TextStyle(fontSize: 12, color: v2TextMuted)),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in _subjects)
                      _subjectChip(
                        '${s['name'] ?? s['display_name'] ?? s['code'] ?? s}',
                        '${s['code'] ?? s['subject_code'] ?? s['name'] ?? s}',
                      ),
                  ],
                ),
              const SizedBox(height: 12),
            ],

            _label('Mkoa'), _pickerRow(_regionName ?? 'Mikoa yote', _pickMkoa),
            const SizedBox(height: 10),
            _label('Wilaya'), _pickerRow(_districtName ?? 'Wilaya zote', _pickWilaya, enabled: _regionId != null),
            const SizedBox(height: 10),
            _label('Kituo / Shule'), _pickerRow(_facilityName ?? 'Vituo vyote', _pickKituo, enabled: _districtId != null),
            const SizedBox(height: 14),

            _label('Mahali Anapotaka Kwenda (${_kwenda.length})'),
            ..._kwenda.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: v2Surface,
                      border: Border.all(color: v2Border),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(PhosphorIcons.flag(), size: 15, color: v2Accent),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            e.value['district_name']!.isNotEmpty
                                ? '${e.value['district_name']}, ${e.value['region_name']}'
                                : e.value['region_name'] ?? '',
                            style: const TextStyle(fontSize: 12.5))),
                    InkWell(
                      onTap: () => setState(() => _kwenda.removeAt(e.key)),
                      child: const Icon(Icons.close,
                          size: 15, color: v2Danger),
                    ),
                  ]),
                )),
            InkWell(
              onTap: _addKwenda,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: v2Accent, style: BorderStyle.solid, width: 1.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add, size: 16, color: v2Accent),
                  SizedBox(width: 6),
                  Text('Ongeza mahali',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: v2Accent)),
                ]),
              ),
            ),
            const SizedBox(height: 14),

            // ── Checks ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: v2Surface,
                  border: Border.all(color: v2Border),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                _check('Akaunti hai', _active, (v) => setState(() => _active = v)),
                _check('Mwenye haki za Admin', _admin, (v) => setState(() => _admin = v)),
                _check('Amelipa / Amethibitishwa', _verified, (v) => setState(() => _verified = v)),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _subjectChip(String label, String code) {
    final selected = _masomo.contains(code);
    return InkWell(
      onTap: () => setState(
          () => selected ? _masomo.remove(code) : _masomo.add(code)),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? v2Accent : v2Surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? v2Accent : v2Border,
              width: selected ? 1.2 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? Colors.white : v2TextSecondary)),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: v2TextSecondary)),
      );

  Widget _pickerRow(String label, VoidCallback onTap, {bool enabled = true}) =>
      InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
                border: Border.all(color: v2Border),
                borderRadius: BorderRadius.circular(10),
                color: v2Surface),
            child: Row(children: [
              Icon(PhosphorIcons.mapPin(),
                  size: 16, color: v2TextSecondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 13))),
              Icon(PhosphorIcons.caretDown(),
                  size: 14, color: v2TextMuted),
            ]),
          ),
        ),
      );

  Widget _check(String label, bool value, ValueChanged<bool> onChange) =>
      CheckboxListTile(
        value: value,
        onChanged: (v) => onChange(v ?? false),
        activeColor: v2Accent,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13)),
      );
}

// ═══════════════════════════════ DETAIL SCREEN ═══════════════════════════════
class V2UserDetailScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onHariri;
  final VoidCallback? onFuta;
  const V2UserDetailScreen(
      {super.key, required this.user, this.onHariri, this.onFuta});

  Future<void> _toggleSuspend(BuildContext context) async {
    final id = user['user_id']?.toString() ?? user['_id']?.toString() ?? '';
    final active = '${user['status'] ?? 'active'}'.toLowerCase() != 'disabled';
    try {
      await ApiService()
          .adminUpdateUser(id, {'status': active ? 'disabled' : 'active'});
      user['status'] = active ? 'disabled' : 'active';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(active ? 'Amesitishwa' : 'Amewezeshwa')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hitilafu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? '';
    final wa = user['phone_alt'] as String? ?? user['phone_whatsapp'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ?? user['cadre_code'] as String? ?? '';
    final category = user['category'] as String? ?? '';
    final isPaid = (user['is_verified'] as bool?) ?? false;
    final isAdmin = user['is_admin'] as bool? ?? false;
    final isActive = '${user['status'] ?? 'active'}'.toLowerCase() == 'active';
    final station = user['current_station'] as Map? ?? {};
    final region = station['region_name'] as String? ?? '';
    final district = station['district_name'] as String? ?? '';
    final facility = station['facility_name'] as String? ?? '';
    final subjects = (user['subjects'] as List?)
            ?.map((s) => '${s['name'] ?? s['code'] ?? s}')
            .toList() ??
        [];
    final dests = ((user['desired_destinations'] ?? user['destinations'])
            as List?)
            ?.map((d) => d is Map
                ? ((d['district_name'] ?? '') is String &&
                        (d['district_name'] ?? '').toString().isNotEmpty
                    ? '${d['district_name']}, ${d['region_name'] ?? ''}'
                    : '${d['region_name'] ?? d['region'] ?? ''}')
                : '$d')
            .toList() ??
        [];
    final init = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final waDigits = wa.replaceAll(RegExp(r'\D'), '');
    final waIntl = waDigits.startsWith('0')
        ? '255${waDigits.substring(1)}'
        : waDigits;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Taarifa za Mtumiaji',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: V2IconChip(
                icon: Icons.edit_outlined,
                color: v2Accent,
                background: v2AccentBg,
                onTap: onHariri,
                size: 34),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: V2IconChip(
                icon: Icons.delete_outline,
                color: v2Danger,
                background: v2DangerBg,
                onTap: onFuta,
                size: 34),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              color: v2Surface, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: v2Accent,
              child: Text(init,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Text(v2TitleCase(name),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(cadre,
                style:
                    const TextStyle(color: v2TextSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _quick(PhosphorIcons.phoneCall(), 'Piga', v2Accent, phone.isEmpty ? null : () => v2Launch('tel:+${phone.replaceAll(RegExp(r'\D'), '')}')),
              const SizedBox(width: 22),
              _quick(PhosphorIcons.whatsappLogo(), 'WhatsApp', v2Success,
                  wa.isEmpty ? null : () => v2Launch('https://wa.me/$waIntl')),
              const SizedBox(width: 22),
              _quick(
                  isActive ? PhosphorIcons.prohibit() : PhosphorIcons.checkCircle(),
                  isActive ? 'Funga' : 'Fungua',
                  v2Warning,
                  () => _toggleSuspend(context)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: v2Surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: v2Border, width: 0.7),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _row('SIMU', phone.isEmpty ? '—' : v2FmtPhone(phone),
                valueColor: v2Accent),
            if (wa.isNotEmpty) _row('WHATSAPP', v2FmtPhone(wa), valueColor: v2Success),
            _row('IDARA', _deptDisplay(category)),
            _row('KADA', cadre.isEmpty ? '—' : cadre),
            if (subjects.isNotEmpty) _row('MASOMO', subjects.join(', ')),
            _row('MKOA / WILAYA',
                region.isEmpty ? '—' : (district.isEmpty ? region : '$region, $district')),
            _row('KITUO', facility.isEmpty ? '—' : facility),
            _row('ANAKWENDA',
                dests.isEmpty ? '—' : dests.join(' · ')),
            _row('HALI', null,
                trailing: V2StatusBadge(active: isActive)),
            _row('AMELIPA', isPaid ? 'Ndiyo' : 'Hapana'),
            _row('WAJIBU', isAdmin ? 'Admin' : 'Mtumiaji'),
            _row('IMEUNDWA', _fmtDate('${user['created_at'] ?? ''}'), isLast: true),
          ]),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  String _deptDisplay(String code) {
    switch (code) {
      case 'health':
        return 'Afya';
      case 'education':
        return 'Elimu';
      case 'service':
        return 'Utumishi';
      default:
        return code.isEmpty ? '—' : code;
    }
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Widget _quick(IconData icon, String label, Color color, VoidCallback? onTap) {
    final chip = V2IconChip(
        icon: icon, color: onTap == null ? v2TextMuted : color,
        background: v2Surface, size: 30, onTap: onTap);
    return Column(children: [
      chip,
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, color: onTap == null ? v2TextMuted : v2TextSecondary)),
    ]);
  }

  Widget _row(String label, String? value,
      {Color? valueColor, Widget? trailing, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border:
              isLast ? null : const Border(bottom: BorderSide(color: v2Border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: v2TextMuted))),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: trailing ??
                Text(value ?? '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: valueColor ?? v2TextPrimary)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ ADD ADMIN ═══════════════════════════════
class V2AddAdminScreen extends StatefulWidget {
  const V2AddAdminScreen({super.key});
  @override
  State<V2AddAdminScreen> createState() => _V2AddAdminScreenState();
}

class _V2AddAdminScreenState extends State<V2AddAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jina = TextEditingController();
  final _barua = TextEditingController();
  final _simu = TextEditingController();
  final _pass = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _hifadhi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService().adminCreateUser({
        'full_name': _jina.text.trim(),
        'email': _barua.text.trim(),
        'phone_primary': _simu.text.trim(),
        'password': _pass.text,
        'is_admin': true,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    _jina.dispose(); _barua.dispose(); _simu.dispose(); _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Ongeza Admin',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _hifadhi,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(PhosphorIcons.check(), size: 17),
              label: const Text('Hifadhi',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: v2Accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: v2DangerBg, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!,
                  style: const TextStyle(fontSize: 12.5, color: v2Danger)),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text('Anaingia kwa email — hana idara wala kada.',
                style: TextStyle(fontSize: 12.5, color: v2TextSecondary)),
          ),
          _fld(_jina, 'Jina Kamili', Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Inahitajika' : null),
          const SizedBox(height: 12),
          _fld(_barua, 'Barua Pepe', Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Barua si sahihi' : null),
          const SizedBox(height: 12),
          _fld(_simu, 'Namba ya Simu', Icons.call_outlined,
              keyboard: TextInputType.phone,
              validator: (v) => (v == null || v.trim().length < 9) ? 'Namba si sahihi' : null),
          const SizedBox(height: 12),
          _fld(_pass, 'Nywila', Icons.lock_outline,
              obscure: true,
              validator: (v) => (v == null || v.length < 6) ? 'Herufi 6+' : null),
        ]),
      ),
    );
  }

  Widget _fld(TextEditingController c, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text,
      bool obscure = false,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 19)),
    );
  }
}

// ═══════════════════════════════ IMPORT SCREEN ═══════════════════════════════
class V2ImportScreen extends StatefulWidget {
  final List<dynamic> departments;
  const V2ImportScreen({super.key, required this.departments});
  @override
  State<V2ImportScreen> createState() => _V2ImportScreenState();
}

class _V2ImportScreenState extends State<V2ImportScreen> {
  String _cat = 'education';
  bool _busy = false;
  String? _error;
  String? _result;

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
      final f = res?.files.firstOrNull;
      if (f?.path == null) {
        setState(() => _busy = false);
        return;
      }
      final r = await ApiService().adminImportUsersFile(
          path: f!.path!, filename: f.name, category: _cat);
      final d = (r.data as Map?) ?? {};
      final created = d['created'] ?? 0;
      final skipped = d['skipped'] ?? 0;
      final errs = (d['errors'] as List?)?.length ?? 0;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result =
            'Wameongezwa $created · wamerukwa $skipped${errs > 0 ? ' · makosa $errs' : ''}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _template() async {
    try {
      final bytes = await ApiService().adminImportTemplateBytes(_cat);
      final path = await FilePicker.platform.saveFile(
          fileName: 'kiolezo_$_cat.xlsx', bytes: Uint8List.fromList(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(path == null ? 'Imeghairiwa' : 'Kiolezo: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Imeshindikana: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
          title: const Text('Import Watumiaji',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: v2DangerBg, borderRadius: BorderRadius.circular(10)),
            child: Text(_error!,
                style: const TextStyle(fontSize: 12.5, color: v2Danger)),
          ),
        if (_result != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: v2SuccessBg, borderRadius: BorderRadius.circular(10)),
            child: Text(_result!,
                style: const TextStyle(fontSize: 12.5, color: v2Success)),
          ),
        const Text('IDARA YA FAILI',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: v2TextMuted)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in widget.departments)
                InkWell(
                  onTap: () => setState(() => _cat = '${d['code']}'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _cat == '${d['code']}' ? v2AccentBg : v2Surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _cat == '${d['code']}'
                              ? v2Accent
                              : v2Border,
                          width: _cat == '${d['code']}' ? 1.4 : 1),
                    ),
                    child: Text(
                        '${d['display_name'] ?? d['name'] ?? d['code']}',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: _cat == '${d['code']}'
                                ? v2Accent
                                : v2TextSecondary,
                            fontWeight: _cat == '${d['code']}'
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ),
                ),
            ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: v2Surface,
              border: Border.all(color: v2Border),
              borderRadius: BorderRadius.circular(12)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(PhosphorIcons.info(), size: 15, color: v2Accent),
                  SizedBox(width: 8),
                  Text('Safu za faili',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: v2Accent)),
                ]),
                SizedBox(height: 6),
                Text(
                    'Jina Kamili · Simu · WhatsApp · Kada · Kiwango · Somo 1 · Somo 2 · Mkoa · Wilaya · Shule/Kituo · Mkoa wa Lengo 1',
                    style: TextStyle(fontSize: 11, color: v2TextSecondary)),
              ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _import,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(PhosphorIcons.uploadSimple(), size: 18),
            label: const Text('Chagua Faili la Excel',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor: v2Accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _template,
            icon: Icon(PhosphorIcons.downloadSimple(), size: 18),
            label: const Text('Pakua Kiolezo (Excel)'),
            style: OutlinedButton.styleFrom(
                foregroundColor: v2Accent,
                side: const BorderSide(color: v2Accent),
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(height: 12),
        // Kitufe cha kumaliza (ikiwa import imefanikiwa)
        if (_result != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: v2Success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('Nimemaliza'),
            ),
          ),
      ]),
    );
  }
}
