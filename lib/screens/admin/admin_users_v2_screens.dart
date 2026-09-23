import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../widgets/select_sheet.dart';
import 'admin_users_v2_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// V2 SCREENS: Picker (ukurasa kamili na search), Fomu (unda/hariri),
// Detail, AddAdmin, Import — icons zote Phosphor, background NYEUPE,
// fomu inayojitosheleza (inapakia refs zake mwenyewe).
// ═══════════════════════════════════════════════════════════════════════════

/// Chaguo la picker: id + jina + subtitle (zote isipokuwa jina zinaweza null)
typedef V2PickOption = ({String? id, String name, String? subtitle});

// ═══════════════════════════════ SHARED HELPERS ═════════════════════════════

String _deptDisplayName(String code) {
  switch (code) {
    case 'health':
      return 'Afya';
    case 'education':
      return 'Elimu';
    case 'service':
      return 'Utumishi';
    case 'kilimo':
      return 'Kilimo';
    default:
      return code;
  }
}

/// Kichwa cha section kwenye fomu (icon + label)
Widget v2SectionHeader(String title, IconData icon) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
    child: Row(children: [
      Icon(icon, size: 14, color: v2Accent),
      const SizedBox(width: 6),
      Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              color: v2TextSecondary)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(height: 1, color: v2Border)),
    ]),
  );
}

/// Field decoration ya pamoja (nyeupe, border ya kijivu)
InputDecoration v2FieldDec(String hint, {Widget? prefixIcon}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13.5, color: v2TextMuted),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD0D7E2))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD0D7E2))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: v2Accent, width: 1.5)),
    );

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
    final filtered =
        widget.options.where((o) => o.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: v2TextPrimary)),
          if (widget.subtitle != null)
            Text(widget.subtitle!,
                style: const TextStyle(fontSize: 11, color: v2TextMuted)),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: v2FieldDec(
              'Tafuta ${widget.title.toLowerCase()}...',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(PhosphorIcons.magnifyingGlass(),
                    size: 16, color: v2TextMuted),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: v2SurfaceMuted,
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(PhosphorIcons.globe(),
                      size: 17, color: v2TextSecondary),
                ),
                title: Text(widget.allLabel,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: widget.selectedId == null
                    ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: v2Accent, size: 18)
                    : null,
                onTap: () => Navigator.pop(context, (id: null, name: null)),
              ),
              const Divider(height: 1, color: v2Border),
              for (final o in filtered)
                ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: v2AccentBg,
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(widget.icon, size: 17, color: v2Accent),
                  ),
                  title: Text(o.name, style: const TextStyle(fontSize: 13.5)),
                  subtitle: o.subtitle != null
                      ? Text(o.subtitle!,
                          style: const TextStyle(
                              fontSize: 11, color: v2TextMuted))
                      : null,
                  trailing: widget.selectedId == o.id
                      ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                          color: v2Accent, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, (id: o.id, name: o.name)),
                ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                      child: Text('Hakuna kilichopatikana',
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
  // ── Step wizard ──
  int _step = 0;
  bool _sameAsPhone = false;
  bool _pickingDest = false;

  static const _stepTitles = [
    'Taarifa binafsi',
    'Kazi',
    'Mahali na hali ya akaunti',
  ];

  late final TextEditingController _jinaCtrl;
  late final TextEditingController _simuCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _passCtrl;
  bool _showPass = false;

  String _category = 'education';
  String? _cadreCode;
  String? _wizara;
  final Set<String> _masomo = {};
  int? _regionId;
  String? _regionName;
  int? _districtId;
  String? _districtName;
  String? _facilityId;
  String? _facilityName;
  bool _active = true;
  bool _admin = false;
  bool _verified = false;
  final List<Map<String, String>> _kwenda = [];

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
    if (_category == 'null' || _category.isEmpty) _category = 'education';
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

    // Masomo yaliyochaguliwa (codes) — kutoka record
    for (final s in (m?['subjects'] as List? ?? [])) {
      final code = s is Map
          ? '${s['code'] ?? s['subject_code'] ?? s['name'] ?? ''}'
          : '$s';
      if (code.isNotEmpty) _masomo.add(code);
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
      setState(() => _departments = raw is List
          ? raw
          : (raw['results'] ?? raw['items'] ?? raw['data'] ?? []));
    } catch (_) {}
    await _loadCadres();
    if (_category == 'education') await _loadSubjects();
    if (_regionId != null) await _loadDistricts();
    if (_districtId != null) await _loadFacilities();
  }

  Future<void> _loadCadres() async {
    if (_category.isEmpty) return;
    try {
      final r = await ApiService().getCadres(category: _category);
      final raw = r.data;
      if (!mounted) return;
      setState(
          () => _cadres = raw is List ? raw : (raw['cadres'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    if (_category != 'education') return;
    try {
      final r = await ApiService().getSubjects(level: 'Primary');
      final raw = r.data;
      if (!mounted) return;
      setState(() =>
          _subjects = raw is List ? raw : (raw['subjects'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadDistricts() async {
    if (_regionId == null) return;
    try {
      final r = await ApiService().getDistricts(_regionId!);
      final raw = r.data;
      if (!mounted) return;
      setState(() =>
          _districts = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadFacilities() async {
    if (_districtId == null) return;
    try {
      final r =
          await ApiService().getFacilities(_districtId!, category: _category);
      final raw = r.data;
      if (!mounted) return;
      setState(() => _facilities =
          raw is List ? raw : (raw['facilities'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  String _deptLabel() {
    if (_category.isEmpty) return 'Chagua idara';
    for (final d in _departments) {
      if ('${d['code']}' == _category) {
        return '${d['display_name'] ?? d['name'] ?? _category}';
      }
    }
    return _deptDisplayName(_category);
  }

  String _cadreLabel() {
    for (final c in _cadres) {
      if ('${c['code']}' == _cadreCode) {
        return '${c['display_name'] ?? c['name'] ?? _cadreCode}';
      }
    }
    return _cadreCode ?? '';
  }

  // ── Pickers ──────────────────────────────────────────────────────────────

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
        title: 'Chagua Idara',
        items: opts,
        selected: _category,
        searchable: false,
        itemIcon: PhosphorIcons.buildings());
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
    if (_category.isEmpty) return;
    final opts = <({String value, String label, String? subtitle})>[
      for (final c in _cadres)
        (
          value: '${c['code']}',
          label: '${c['display_name'] ?? c['name'] ?? c['code']}',
          subtitle: '${c['code']}'
        ),
    ];
    final picked = await showSelectSheet<String>(context,
        title: 'Chagua Kada',
        items: opts,
        selected: _cadreCode,
        searchable: true,
        itemIcon: PhosphorIcons.identificationBadge());
    if (picked != null) setState(() => _cadreCode = picked);
  }

  Future<void> _pickMkoa() async {
    final picked = await _openPicker(
      title: 'Chagua Mkoa',
      allLabel: 'Mikoa yote',
      icon: PhosphorIcons.mapPin(),
      options: [
        for (final r in widget.regions)
          (
            id: '${r['id'] ?? r['region_id'] ?? ''}',
            name: '${r['name'] ?? r['region_name'] ?? ''}',
            subtitle: null,
          ),
      ],
      selectedId: _regionId?.toString(),
    );
    if (picked == null) return;
    setState(() {
      _regionId = picked.id == null ? null : int.tryParse(picked.id!);
      _regionName = picked.name;
      _districtId = null;
      _districtName = null;
      _facilityId = null;
      _facilityName = null;
      _districts = [];
      _facilities = [];
    });
    if (picked.id != null) _loadDistricts();
  }

  Future<void> _pickWilaya() async {
    if (_regionId == null) return;
    final picked = await _openPicker(
      title: 'Chagua Wilaya',
      subtitle: 'Ndani ya ${_regionName ?? ''}',
      allLabel: 'Wilaya zote',
      icon: PhosphorIcons.city(),
      options: [
        for (final d in _districts)
          (
            id: '${d['id'] ?? d['district_id'] ?? ''}',
            name: '${d['name'] ?? d['district_name'] ?? ''}',
            subtitle: null,
          ),
      ],
      selectedId: _districtId?.toString(),
    );
    if (picked == null) return;
    setState(() {
      _districtId = picked.id == null ? null : int.tryParse(picked.id!);
      _districtName = picked.name;
      _facilityId = null;
      _facilityName = null;
      _facilities = [];
    });
    if (picked.id != null) _loadFacilities();
  }

  Future<void> _pickKituo() async {
    if (_districtId == null) return;
    final catIcon = _category == 'health'
        ? PhosphorIcons.heartbeat()
        : PhosphorIcons.buildings();
    final picked = await _openPicker(
      title: 'Chagua Kituo',
      subtitle: 'Ndani ya ${_districtName ?? ''}',
      allLabel: 'Vituo vyote',
      icon: catIcon,
      options: [
        for (final f in _facilities)
          (
            id: '${f['id'] ?? f['code'] ?? ''}',
            name: '${f['name'] ?? f['facility_name'] ?? ''}',
            subtitle: f['type'] as String?,
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
      icon: PhosphorIcons.flag(),
      options: [
        for (final r in widget.regions)
          (
            id: '${r['id'] ?? r['region_id'] ?? ''}',
            name: '${r['name'] ?? r['region_name'] ?? ''}',
            subtitle: null,
          ),
      ],
    );
    if (mkoa == null || mkoa.id == null) return;
    List<dynamic> dists = [];
    try {
      final r = await ApiService().getDistricts(int.parse(mkoa.id!));
      final raw = r.data;
      dists = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []);
    } catch (_) {}
    String? distId;
    String? distName;
    if (dists.isNotEmpty && mounted) {
      final wilaya = await _openPicker(
        title: 'Wilaya (hiari)',
        subtitle: 'Ndani ya ${mkoa.name}',
        allLabel: '-- Wilaya yoyote --',
        icon: PhosphorIcons.city(),
        options: [
          for (final d in dists)
            (
              id: '${d['id'] ?? d['district_id'] ?? ''}',
              name: '${d['name'] ?? d['district_name'] ?? ''}',
              subtitle: null,
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
    required IconData icon,
    required List<V2PickOption> options,
    String? selectedId,
  }) {
    return Navigator.of(context).push<V2PickOption>(MaterialPageRoute(
      builder: (_) => V2PickerScreen(
          title: title,
          subtitle: subtitle,
          icon: icon,
          allLabel: allLabel,
          options: options,
          selectedId: selectedId),
    ));
  }

  // ── Save ─────────────────────────────────────────────────────────────────

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

  // ── Step validation + navigation ─────────────────────────────────────────

  String? _validateStep() {
    if (_step == 0) {
      if (_jinaCtrl.text.trim().isEmpty) return 'Andika jina kamili';
      if (_simuCtrl.text.replaceAll(RegExp(r'\D'), '').length < 9) {
        return 'Namba ya simu iwe tarakimu 9 baada ya +255';
      }
      if (!_isEditing && _passCtrl.text.length < 6) {
        return 'Nywila iwe angalau herufi 6';
      }
    }
    if (_step == 1 && _cadreCode == null) return 'Chagua kada kwanza';
    return null;
  }

  Future<void> _next() async {
    final err = _validateStep();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _error = null);
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    await _hifadhi();
  }

  void _back() {
    if (_step > 0) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  // ── UI helpers ───────────────────────────────────────────────────────────

  Widget _errorBox() => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: v2DangerBg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(PhosphorIcons.warningCircle(), size: 15, color: v2Danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: const TextStyle(fontSize: 12.5, color: v2Danger))),
        ]),
      );

  Widget _secHdr(String title, IconData icon, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Row(children: [
          Icon(icon, size: 18, color: v2Accent),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: v2TextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(color: v2TextMuted, fontSize: 12)),
        ]),
      );

  Widget _lbl(String text, {bool req = false, String? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(
              text: text,
              style: const TextStyle(
                  color: v2TextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              children: [
                if (req)
                  const TextSpan(
                      text: ' *', style: TextStyle(color: v2Danger)),
              ],
            )),
          ),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(color: v2TextMuted, fontSize: 12)),
        ]),
      );

  InputDecoration _inDec(IconData icon, String hint,
      {bool prefix255 = false, Color? iconColor}) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: col, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: v2TextMuted, fontSize: 14),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: iconColor ?? v2TextMuted),
          if (prefix255) ...[
            const SizedBox(width: 10),
            Text('+255', style: const TextStyle(color: v2TextMuted, fontSize: 14)),
            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: v2Border),
          ],
        ]),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: b(const Color(0xFFCFD5DF)),
      enabledBorder: b(const Color(0xFFCFD5DF)),
      focusedBorder: b(v2Accent, 1.5),
    );
  }

  Widget _toggleRow(
          String title, String sub, bool value, ValueChanged<bool> onChange) =>
      InkWell(
        onTap: () => onChange(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: v2TextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(sub,
                        style: const TextStyle(
                            color: v2TextMuted, fontSize: 12)),
                  ]),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChange,
                activeTrackColor: v2Accent,
                inactiveTrackColor: const Color(0xFFCFD5DF),
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackOutlineColor:
                    const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ]),
        ),
      );

  Widget _selectRow({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
    String? placeholder,
    bool enabled = true,
  }) {
    final empty = placeholder != null && text == placeholder;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              border: Border.all(color: v2Border),
              borderRadius: BorderRadius.circular(11),
              color: Colors.white),
          child: Row(children: [
            Icon(icon, size: 16, color: v2TextSecondary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13,
                        color: empty ? v2TextMuted : v2TextPrimary))),
            Icon(PhosphorIcons.caretDown(), size: 14, color: v2TextMuted),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════ BUILD (wizard) ══════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Column(children: [
          _buildWizardHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
              child: [_buildStep1, _buildStep2, _buildStep3][_step](),
            ),
          ),
          _buildWizardFooter(),
        ]),
      ),
    );
  }

  Widget _buildWizardHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: v2Border)),
      ),
      child: Column(children: [
        Row(children: [
          IconButton(
            onPressed: _back,
            icon: Icon(PhosphorIcons.arrowLeft(), size: 20, color: v2TextPrimary),
          ),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isEditing ? 'Hariri Mtumiaji' : 'Mtumiaji mpya',
                      style: const TextStyle(
                          color: v2TextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text(
                      'Hatua ${_step + 1} kati ya 3 · ${_stepTitles[_step]}',
                      style: const TextStyle(color: v2TextMuted, fontSize: 12)),
                ]),
          ),
        ]),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= _step ? v2Accent : const Color(0xFFCFD5DF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _buildWizardFooter() {
    final isLast = _step == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: v2Border)),
      ),
      child: Row(children: [
        if (_step > 0)
          TextButton.icon(
            onPressed: _saving ? null : _back,
            icon: Icon(PhosphorIcons.caretLeft(), size: 18, color: v2TextSecondary),
            label: const Text('Rudi',
                style: TextStyle(
                    color: v2TextSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: FilledButton(
            onPressed: _saving ? null : _next,
            style: FilledButton.styleFrom(
              backgroundColor: v2Accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: isLast
                        ? [
                            Icon(PhosphorIcons.floppyDisk(), size: 18),
                            const SizedBox(width: 6),
                            const Text('Hifadhi'),
                          ]
                        : [
                            const Text('Endelea'),
                            const SizedBox(width: 6),
                            Icon(PhosphorIcons.arrowRight(), size: 18),
                          ],
                  ),
          ),
        ),
      ]),
    );
  }

  // ── HATUA 1: Taarifa binafsi ──────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) _errorBox(),
      _secHdr('Taarifa binafsi', PhosphorIcons.user()),
      _lbl('Jina kamili', req: true),
      TextField(
        controller: _jinaCtrl,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(color: v2TextPrimary, fontSize: 14),
        decoration: _inDec(PhosphorIcons.user(), 'mf. Juma Kiswili'),
      ),
      _lbl('Namba ya simu', req: true),
      TextField(
        controller: _simuCtrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: v2TextPrimary, fontSize: 14),
        decoration:
            _inDec(PhosphorIcons.phone(), '712 345 678', prefix255: true),
      ),
      _lbl('WhatsApp', trailing: 'hiari'),
      GestureDetector(
        onTap: () => setState(() => _sameAsPhone = !_sameAsPhone),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _sameAsPhone,
                onChanged: (v) => setState(() => _sameAsPhone = v ?? false),
                activeColor: v2Accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Ni sawa na namba ya simu',
                style: TextStyle(color: v2TextPrimary, fontSize: 13)),
          ]),
        ),
      ),
      if (!_sameAsPhone)
        TextField(
          controller: _waCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: v2TextPrimary, fontSize: 14),
          decoration: _inDec(
              PhosphorIcons.whatsappLogo(PhosphorIconsStyle.fill),
              '689 225 170',
              prefix255: true,
              iconColor: v2Success),
        ),
      _lbl(_isEditing ? 'Nywila mpya (hiari)' : 'Nywila', req: !_isEditing),
      TextField(
        controller: _passCtrl,
        obscureText: !_showPass,
        style: const TextStyle(color: v2TextPrimary, fontSize: 14),
        decoration:
            _inDec(PhosphorIcons.lockSimple(), 'Angalau herufi 6').copyWith(
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showPass = !_showPass),
            icon: Icon(
                _showPass ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye(),
                size: 16,
                color: v2TextMuted),
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Text('Angalau herufi 6',
          style: TextStyle(color: v2TextMuted, fontSize: 12)),
    ]);
  }

  // ── HATUA 2: Kazi ─────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final showMasomo = _category == 'education';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) _errorBox(),
      _secHdr('Kazi', PhosphorIcons.briefcase()),
      _lbl('Idara', req: true),
      // Dept cards (kutoka API)
      if (_departments.isEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: v2SurfaceMuted,
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: v2Accent)),
            SizedBox(width: 10),
            Text('Inapakia idara...', style: TextStyle(fontSize: 12, color: v2TextMuted)),
          ]),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _departments)
              _V2IdaraCard(
                code: '${d['code']}',
                label: '${d['display_name'] ?? d['name'] ?? d['code']}',
                selected: _category == '${d['code']}',
                onTap: () {
                  final code = '${d['code']}';
                  if (_category == code) return;
                  setState(() {
                    _category = code;
                    _cadreCode = null;
                    _cadres = [];
                    _masomo.clear();
                    _subjects = [];
                  });
                  _loadCadres();
                  if (code == 'education') _loadSubjects();
                },
              ),
          ],
        ),
      _lbl('Kada', req: true),
      _selectRow(
        icon: PhosphorIcons.identificationBadge(),
        text: _cadreLabel().isEmpty
            ? (_category.isEmpty ? 'Chagua idara kwanza' : 'Chagua kada')
            : _cadreLabel(),
        placeholder: 'Chagua kada',
        onTap: _category.isEmpty ? null : _pickCadre,
      ),
      if (showMasomo) ...[
        const SizedBox(height: 4),
        Row(children: [
          const Expanded(
              child: Text('Masomo anayofundisha',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: v2TextPrimary))),
          if (_masomo.isNotEmpty)
            Text('${_masomo.length} umechagua',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: v2Accent)),
        ]),
        const SizedBox(height: 8),
        if (_subjects.isEmpty && _masomo.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                      color: v2SurfaceMuted,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: v2Accent)),
                    SizedBox(width: 10),
                    Text('Inapakia masomo...',
                        style: TextStyle(fontSize: 12, color: v2TextMuted)),
                  ]),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Chips kutoka orodha ya masomo
                    for (final s in _subjects)
                      _subjectChip(
                        s is Map
                            ? '${s['name'] ?? s['display_name'] ?? s['code'] ?? s}'
                            : '$s',
                        s is Map
                            ? '${s['code'] ?? s['subject_code'] ?? s['name'] ?? s}'
                            : '$s',
                      ),
                    // Codes zilizochaguliwa ambazo hazipo kwenye orodha
                    for (final code in _masomo)
                      if (!_subjects.any((s) =>
                          s is Map &&
                          '${s['code'] ?? s['subject_code'] ?? s['name']}' ==
                              code))
                        _subjectChip(code, code),
                  ],
                ),
            ],

    ]); // end _buildStep2
  }

  // ── HATUA 3: Mahali na hali ya akaunti ────────────────────────────────────

  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) _errorBox(),

      _secHdr('Mahali anapofanyia kazi', PhosphorIcons.mapPin()),
      _lbl('Mkoa'),
      _selectRow(
        icon: PhosphorIcons.mapPin(),
        text: _regionName ?? 'Chagua mkoa',
        placeholder: 'Chagua mkoa',
        onTap: _pickMkoa,
      ),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _lbl('Wilaya'),
                _selectRow(
                  icon: PhosphorIcons.city(),
                  text: _districtName ?? 'Chagua',
                  placeholder: 'Chagua',
                  enabled: _regionId != null,
                  onTap: _pickWilaya,
                ),
              ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _lbl('Kituo / shule'),
                _selectRow(
                  icon: PhosphorIcons.buildings(),
                  text: _facilityName ?? 'Chagua',
                  placeholder: 'Chagua',
                  enabled: _districtId != null,
                  onTap: _pickKituo,
                ),
              ]),
        ),
      ]),

      _secHdr('Anapotaka kwenda', PhosphorIcons.flag(),
          trailing: _kwenda.isNotEmpty ? '${_kwenda.length} mikoa' : null),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: v2Border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_kwenda.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _kwenda.asMap().entries.map((e) {
                  final d = e.value;
                  final label = (d['district_name'] ?? '').isNotEmpty
                      ? d['district_name']!.split(',').first.trim()
                      : d['region_name'] ?? '';
                  return GestureDetector(
                    onTap: () => setState(() => _kwenda.removeAt(e.key)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                          color: v2AccentBg,
                          borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(label,
                            style: const TextStyle(
                                color: v2Accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(PhosphorIcons.x(), size: 13, color: v2Accent),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Bado hujaongeza mkoa wowote.',
                  style: TextStyle(color: v2TextMuted, fontSize: 12)),
            ),
          _V2DashedAddButton(
            label: 'Ongeza mkoa',
            onTap: _addKwenda,
          ),
        ]),
      ),

      _secHdr('Hali ya akaunti', PhosphorIcons.gearSix()),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: v2Border),
        ),
        child: Column(children: [
          _toggleRow('Akaunti hai', 'Anaweza kuingia kwenye app', _active,
              (v) => setState(() => _active = v)),
          const Divider(height: 1, color: v2Border),
          _toggleRow('Haki za admin', 'Anaweza kusimamia watumiaji', _admin,
              (v) => setState(() => _admin = v)),
          const Divider(height: 1, color: v2Border),
          _toggleRow('Amelipa', 'Malipo yamethibitishwa', _verified,
              (v) => setState(() => _verified = v)),
        ]),
      ),
    ]);
  }

  Widget _subjectChip(String label, String code) {
    final selected = _masomo.contains(code);
    return InkWell(
      onTap: () =>
          setState(() => selected ? _masomo.remove(code) : _masomo.add(code)),
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

}

// ── _V2IdaraCard — dept selection card ────────────────────────────────────────
class _V2IdaraCard extends StatelessWidget {
  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _V2IdaraCard({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (code.toLowerCase()) {
      case 'health':
        return PhosphorIcons.heartbeat(PhosphorIconsStyle.fill);
      case 'education':
        return PhosphorIcons.graduationCap(PhosphorIconsStyle.fill);
      case 'agriculture':
        return PhosphorIcons.plant(PhosphorIconsStyle.fill);
      case 'water':
        return PhosphorIcons.drop(PhosphorIconsStyle.fill);
      case 'finance':
        return PhosphorIcons.currencyDollar(PhosphorIconsStyle.fill);
      default:
        return PhosphorIcons.briefcase(PhosphorIconsStyle.fill);
    }
  }

  Color get _color {
    switch (code.toLowerCase()) {
      case 'health':
        return const Color(0xFF10B981);
      case 'education':
        return const Color(0xFF3B82F6);
      case 'agriculture':
        return const Color(0xFF84CC16);
      case 'water':
        return const Color(0xFF06B6D4);
      case 'finance':
        return const Color(0xFFF59E0B);
      default:
        return v2Accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 2.0 : 1.2,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.15) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, size: 20, color: selected ? color : v2TextMuted),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : v2TextSecondary,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── _V2DashedAddButton — dashed-border add button ─────────────────────────────
class _V2DashedAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _V2DashedAddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: v2Accent.withValues(alpha: 0.5),
          radius: 10,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIcons.plus(), size: 15, color: v2Accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: v2Accent,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashLen = 6.0;
    const gapLen = 4.0;
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rRect);
    final metric = path.computeMetrics().first;
    double dist = 0;
    while (dist < metric.length) {
      final end = (dist + dashLen).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(dist, end), paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
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
            content: Text(active ? 'Amesitishwa' : 'Amewezeshwa'),
            backgroundColor: v2Success));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hitilafu: $e'), backgroundColor: v2Danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? '';
    final wa =
        user['phone_alt'] as String? ?? user['phone_whatsapp'] as String? ?? '';
    final cadre =
        user['cadre_display'] as String? ?? user['cadre_code'] as String? ?? '';
    final category = user['category'] as String? ?? '';
    final isPaid = (user['is_verified'] as bool?) ?? false;
    final isAdmin = user['is_admin'] as bool? ?? false;
    final isActive = '${user['status'] ?? 'active'}'.toLowerCase() == 'active';
    final station = user['current_station'] as Map? ?? {};
    final region = station['region_name'] as String? ?? '';
    final district = station['district_name'] as String? ?? '';
    final facility = station['facility_name'] as String? ?? '';
    final subjects = (user['subjects'] as List?)
            ?.map((s) =>
                s is Map ? '${s['name'] ?? s['code'] ?? s}' : '$s')
            .toList() ??
        [];
    final dests = ((user['desired_destinations'] ?? user['destinations'])
            as List?)
            ?.map((d) => d is Map
                ? ((d['district_name'] ?? '').toString().isNotEmpty
                    ? '${d['district_name']}, ${d['region_name'] ?? ''}'
                    : '${d['region_name'] ?? d['region'] ?? ''}')
                : '$d')
            .toList() ??
        [];
    final init = v2Initials(name);
    final waDigits = wa.replaceAll(RegExp(r'\D'), '');
    final waIntl =
        waDigits.startsWith('0') ? '255${waDigits.substring(1)}' : waDigits;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text('Taarifa za Mtumiaji',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: v2TextPrimary)),
        actions: [
          if (onHariri != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: onHariri,
                icon: Icon(PhosphorIcons.pencilSimple(), size: 14),
                label: const Text('Hariri'),
                style: TextButton.styleFrom(
                    foregroundColor: v2Accent,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          if (onFuta != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: V2IconChip(
                  icon: PhosphorIcons.trash(),
                  color: v2Danger,
                  background: v2DangerBg,
                  onTap: onFuta,
                  size: 30),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── Header card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
              color: v2SurfaceMuted, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                    color: v2Accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(init,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isActive ? v2Success : v2Danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: v2SurfaceMuted, width: 2.5),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(v2TitleCase(name),
                style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: v2TextPrimary)),
            const SizedBox(height: 3),
            Text(cadre.isEmpty ? '—' : cadre,
                style:
                    const TextStyle(color: v2TextSecondary, fontSize: 12.5)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _quick(
                  PhosphorIcons.phoneCall(),
                  'Piga',
                  v2Accent,
                  phone.isEmpty
                      ? null
                      : () => v2Launch(
                          'tel:+${phone.replaceAll(RegExp(r'\D'), '')}')),
              const SizedBox(width: 22),
              _quick(
                  PhosphorIcons.whatsappLogo(),
                  'WhatsApp',
                  v2Success,
                  wa.isEmpty
                      ? null
                      : () => v2Launch('https://wa.me/$waIntl')),
              const SizedBox(width: 22),
              _quick(
                  isActive
                      ? PhosphorIcons.prohibit()
                      : PhosphorIcons.checkCircle(),
                  isActive ? 'Funga' : 'Fungua',
                  v2Warning,
                  () => _toggleSuspend(context)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        // ── Info card ──
        Container(
          decoration: BoxDecoration(
            color: v2Surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: v2Border, width: 0.7),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _row('SIMU', phone.isEmpty ? '—' : v2FmtPhone(phone),
                valueColor: v2Accent),
            if (wa.isNotEmpty)
              _row('WHATSAPP', v2FmtPhone(wa), valueColor: v2Success),
            _row('IDARA', _deptDisplayName(category)),
            _row('KADA', cadre.isEmpty ? '—' : cadre),
            if (subjects.isNotEmpty) _row('MASOMO', subjects.join(', ')),
            _row('MKOA / WILAYA',
                region.isEmpty ? '—' : (district.isEmpty ? region : '$region, $district')),
            _row('KITUO', facility.isEmpty ? '—' : facility),
            _row('ANAKWENDA', dests.isEmpty ? '—' : dests.join(' · ')),
            _row('HALI', null, trailing: V2StatusBadge(active: isActive)),
            _row('AMELIPA', isPaid ? 'Ndiyo' : 'Hapana'),
            _row('WAJIBU', isAdmin ? 'Admin' : 'Mtumiaji'),
            _row('IMEUNDWA', _fmtDate('${user['created_at'] ?? ''}'),
                isLast: true),
          ]),
        ),
        const SizedBox(height: 20),
      ]),
    );
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
        icon: icon,
        color: onTap == null ? v2TextMuted : color,
        background: Colors.white,
        size: 40,
        onTap: onTap);
    return Column(children: [
      chip,
      const SizedBox(height: 5),
      Text(label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color:
                  onTap == null ? v2TextMuted : v2TextSecondary)),
    ]);
  }

  Widget _row(String label, String? value,
      {Color? valueColor, Widget? trailing, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: v2Border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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
                        fontWeight: FontWeight.w500,
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
    _jina.dispose();
    _barua.dispose();
    _simu.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ongeza Admin',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: v2TextPrimary)),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: v2Border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _hifadhi,
              style: ElevatedButton.styleFrom(
                  backgroundColor: v2Accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: v2Accent.withValues(alpha: .55),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))),
              icon: _saving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(PhosphorIcons.floppyDisk(), size: 16),
              label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: v2DangerBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(PhosphorIcons.warningCircle(),
                        size: 15, color: v2Danger),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12.5, color: v2Danger))),
                  ]),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: v2AccentBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(PhosphorIcons.shieldCheck(),
                      size: 16, color: v2Accent),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Anaingia kwa barua pepe — hana idara wala kada.',
                          style:
                              const TextStyle(fontSize: 12.5, color: v2Accent))),
                ]),
              ),
              const SizedBox(height: 14),
              v2SectionHeader('Taarifa za admin', PhosphorIcons.user()),
              _fld(_jina, 'Jina Kamili', PhosphorIcons.user(),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Inahitajika' : null),
              const SizedBox(height: 12),
              _fld(_barua, 'Barua Pepe', PhosphorIcons.envelopeSimple(),
                  keyboard: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Barua si sahihi' : null),
              const SizedBox(height: 12),
              _fld(_simu, 'Namba ya Simu', PhosphorIcons.phone(),
                  keyboard: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 9)
                      ? 'Namba si sahihi'
                      : null),
              const SizedBox(height: 12),
              _fld(_pass, 'Nywila', PhosphorIcons.lockSimple(),
                  obscure: true,
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Herufi 6+' : null),
              const SizedBox(height: 8),
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
      decoration: v2FieldDec(hint,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, size: 16, color: v2TextMuted),
          )),
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
  int _created = 0, _skipped = 0, _errs = 0;

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
      if (!mounted) return;
      setState(() {
        _busy = false;
        _created = (d['created'] as num?)?.toInt() ?? 0;
        _skipped = (d['skipped'] as num?)?.toInt() ?? 0;
        _errs = (d['errors'] as List?)?.length ?? 0;
        _result = 'ok';
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: v2TextPrimary))),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: v2DangerBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(PhosphorIcons.warningCircle(),
                      size: 15, color: v2Danger),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 12.5, color: v2Danger))),
                ]),
              ),
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: v2SuccessBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            size: 17, color: v2Success),
                        SizedBox(width: 8),
                        Text('Import imekamilika',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: v2Success)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _stat('Wameongezwa', _created, v2Success),
                        const SizedBox(width: 10),
                        _stat('Wamerukwa', _skipped, v2Warning),
                        if (_errs > 0) ...[
                          const SizedBox(width: 10),
                          _stat('Makosa', _errs, v2Danger),
                        ],
                      ]),
                    ]),
              ),
              const SizedBox(height: 14),
            ],
            v2SectionHeader('Idara ya faili', PhosphorIcons.squaresFour()),
            Wrap(spacing: 8, runSpacing: 8, children: [
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
                          color:
                              _cat == '${d['code']}' ? v2Accent : v2Border,
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
                  color: v2SurfaceMuted,
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
                    const SizedBox(height: 6),
                    Text(
                        'Jina Kamili · Simu · WhatsApp · Kada · Kiwango · Somo 1 · Somo 2 · Mkoa · Wilaya · Shule/Kituo · Mkoa wa Lengo 1',
                        style: TextStyle(
                            fontSize: 11, color: v2TextSecondary, height: 1.5)),
                  ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _import,
                style: ElevatedButton.styleFrom(
                    backgroundColor: v2Accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(PhosphorIcons.uploadSimple(), size: 17),
                label: Text(
                    _busy ? 'Inapakia...' : 'Chagua Faili la Excel',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _template,
                style: OutlinedButton.styleFrom(
                    foregroundColor: v2Accent,
                    side: const BorderSide(color: v2Accent),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: Icon(PhosphorIcons.downloadSimple(), size: 17),
                label: const Text('Pakua Kiolezo (Excel)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            if (_result != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: v2Success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Nimemaliza',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
    );
  }

  Widget _stat(String label, int n, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$n',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color.withValues(alpha: .8))),
        ]),
      );
}
