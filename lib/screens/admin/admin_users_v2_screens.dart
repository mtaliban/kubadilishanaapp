import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'admin_theme.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
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
Widget v2SectionHeader(BuildContext context, String title, IconData icon) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
    child: Row(children: [
      Icon(icon, size: 14, color: v2AccentOf(context)),
      SizedBox(width: 6),
      Text(title.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
              color: v2TextSecondaryOf(context))),
      SizedBox(width: 10),
      Expanded(child: Divider(height: 1, color: v2BorderOf(context))),
    ]),
  );
}

/// Field decoration ya pamoja (nyeupe, border ya kijivu)
InputDecoration v2FieldDec(BuildContext context, String hint, {Widget? prefixIcon}) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: v2TextMutedOf(context)),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Ad.card(context),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Color(0xFFD0D7E2))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Color(0xFFD0D7E2))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: v2AccentOf(context), width: 1.5)),
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
      backgroundColor: Ad.card(context),
      appBar: AppBar(
        backgroundColor: Ad.card(context),
        surfaceTintColor: Ad.card(context),
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: v2TextPrimaryOf(context))),
          if (widget.subtitle != null)
            Text(widget.subtitle!,
                style: TextStyle(fontSize: 11, color: v2TextMutedOf(context))),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: v2FieldDec(context,
              'Tafuta ${widget.title.toLowerCase()}...',
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(PhosphorIcons.magnifyingGlass(),
                    size: 16, color: v2TextMutedOf(context)),
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
                      color: v2SurfaceMutedOf(context),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(PhosphorIcons.globe(),
                      size: 17, color: v2TextSecondaryOf(context)),
                ),
                title: Text(widget.allLabel,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                trailing: widget.selectedId == null
                    ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: v2AccentOf(context), size: 18)
                    : null,
                onTap: () => Navigator.pop(context, (id: null, name: null)),
              ),
              Divider(height: 1, color: v2BorderOf(context)),
              for (final o in filtered)
                ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: v2AccentBgOf(context),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(widget.icon, size: 17, color: v2AccentOf(context)),
                  ),
                  title: Text(o.name, style: TextStyle(fontSize: 13.5)),
                  subtitle: o.subtitle != null
                      ? Text(o.subtitle!,
                          style: TextStyle(
                              fontSize: 11, color: v2TextMutedOf(context)))
                      : null,
                  trailing: widget.selectedId == o.id
                      ? Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                          color: v2AccentOf(context), size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, (id: o.id, name: o.name)),
                ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                      child: Text('Hakuna kilichopatikana',
                          style: TextStyle(color: v2TextMutedOf(context)))),
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
    if (_jinaCtrl.text.trim().isEmpty || _simuCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Jaza jina na namba ya simu kwanza');
      return;
    }
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
            // Masomo ya mwalimu — yalikuwa hayatumwi kwenye save (data ilipotea!)
            if (_category == 'education') 'subjects': _masomo.toList(),
            if (_wizara != null && _wizara!.isNotEmpty)
              'employment_sector': _wizara,
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
          // Masomo ya mwalimu — yalikuwa hayatumwi kwenye create pia
          if (_category == 'education') 'subjects': _masomo.toList(),
          if (_wizara != null && _wizara!.isNotEmpty)
            'employment_sector': _wizara,
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
        _error = friendlyError(e);
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

  static String _deptSub(String code) {
    switch (code.toLowerCase()) {
      case 'health':     return 'Watumishi wa afya';
      case 'education':  return 'Walimu';
      case 'agriculture': return 'Wataalam wa kilimo';
      case 'water':      return 'Wataalam wa maji';
      default:           return '';
    }
  }

  Widget _errorBox() => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: v2DangerBgOf(context), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(PhosphorIcons.warningCircle(), size: 15, color: v2DangerOf(context)),
          SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: TextStyle(fontSize: 12.5, color: v2DangerOf(context)))),
        ]),
      );

  Widget _secHdr(String title, IconData icon, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Row(children: [
          Icon(icon, size: 18, color: v2AccentOf(context)),
          SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: v2TextPrimaryOf(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
          if (trailing != null)
            Text(trailing,
                style: TextStyle(color: v2TextMutedOf(context), fontSize: 12)),
        ]),
      );

  Widget _lbl(String text,
          {bool req = false, String? trailing, Color? trailingColor}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(
              text: text,
              style: TextStyle(
                  color: v2TextPrimaryOf(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              children: [
                if (req)
                  TextSpan(
                      text: ' *', style: TextStyle(color: v2DangerOf(context))),
              ],
            )),
          ),
          if (trailing != null)
            Text(trailing,
                style: TextStyle(
                    color: trailingColor ?? v2TextMutedOf(context),
                    fontSize: 12,
                    fontWeight: trailingColor != null
                        ? FontWeight.w600
                        : FontWeight.w400)),
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
      hintStyle: TextStyle(color: v2TextMutedOf(context), fontSize: 14),
      isDense: true,
      filled: true,
      fillColor: Ad.card(context),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: iconColor ?? v2TextMutedOf(context)),
          if (prefix255) ...[
            SizedBox(width: 10),
            Text('+255', style: TextStyle(color: v2TextMutedOf(context), fontSize: 14)),
            SizedBox(width: 8),
            Container(width: 1, height: 18, color: v2BorderOf(context)),
          ],
        ]),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: b(const Color(0xFFCFD5DF)),
      enabledBorder: b(const Color(0xFFCFD5DF)),
      focusedBorder: b(v2AccentOf(context), 1.5),
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
                        style: TextStyle(
                            color: v2TextPrimaryOf(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(sub,
                        style: TextStyle(
                            color: v2TextMutedOf(context), fontSize: 12)),
                  ]),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: value,
                onChanged: onChange,
                activeTrackColor: v2AccentOf(context),
                inactiveTrackColor: Color(0xFFCFD5DF),
                thumbColor: WidgetStatePropertyAll(Ad.card(context)),
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
              border: Border.all(color: v2BorderOf(context)),
              borderRadius: BorderRadius.circular(11),
              color: Ad.card(context)),
          child: Row(children: [
            Icon(icon, size: 16, color: v2TextSecondaryOf(context)),
            SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 13,
                        color: empty ? v2TextMutedOf(context) : v2TextPrimaryOf(context)))),
            Icon(PhosphorIcons.caretDown(), size: 14, color: v2TextMutedOf(context)),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════ BUILD (wizard) ══════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ad.card(context),
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
      decoration: BoxDecoration(
        color: Ad.card(context),
        border: Border(bottom: BorderSide(color: v2BorderOf(context))),
      ),
      child: Column(children: [
        Row(children: [
          IconButton(
            onPressed: _back,
            icon: Icon(PhosphorIcons.arrowLeft(), size: 20, color: v2TextPrimaryOf(context)),
          ),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isEditing ? 'Hariri Mtumiaji' : 'Mtumiaji mpya',
                      style: TextStyle(
                          color: v2TextPrimaryOf(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  Text(
                      'Hatua ${_step + 1} kati ya 3 · ${_stepTitles[_step]}',
                      style: TextStyle(color: v2TextMutedOf(context), fontSize: 12)),
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
                    color: i <= _step ? v2AccentOf(context) : const Color(0xFFCFD5DF),
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
      decoration: BoxDecoration(
        color: Ad.card(context),
        border: Border(top: BorderSide(color: v2BorderOf(context))),
      ),
      child: Row(children: [
        if (_step > 0)
          TextButton.icon(
            onPressed: _saving ? null : _back,
            icon: Icon(PhosphorIcons.caretLeft(), size: 18, color: v2TextSecondaryOf(context)),
            label: Text('Rudi',
                style: TextStyle(
                    color: v2TextSecondaryOf(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        const Spacer(),
        SizedBox(
          height: 40,
          child: FilledButton(
            onPressed: _saving ? null : _next,
            style: FilledButton.styleFrom(
              backgroundColor: v2AccentOf(context),
              foregroundColor: Ad.card(context),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Ad.card(context)))
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
        style: TextStyle(color: v2TextPrimaryOf(context), fontSize: 14),
        decoration: _inDec(TablerIcons.user, 'mf. Juma Kiswili'),
      ),
      _lbl('Namba ya simu', req: true),
      TextField(
        controller: _simuCtrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(color: v2TextPrimaryOf(context), fontSize: 14),
        decoration:
            _inDec(TablerIcons.phone, '712 345 678', prefix255: true),
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
                activeColor: v2AccentOf(context),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            SizedBox(width: 8),
            // Expanded: maandishi yafuata nafasi — font kubwa ya mtumiaji
            // (scale 1.3+) haivunji row tena kwenye simu ndogo.
            Expanded(
              child: Text('Ni sawa na namba ya simu',
                  style: TextStyle(color: v2TextPrimaryOf(context), fontSize: 13)),
            ),
          ]),
        ),
      ),
      if (!_sameAsPhone)
        TextField(
          controller: _waCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: v2TextPrimaryOf(context), fontSize: 14),
          decoration: _inDec(
              TablerIcons.brandWhatsapp,
              '689 225 170',
              prefix255: true,
              iconColor: v2SuccessOf(context)),
        ),
      _lbl(_isEditing ? 'Nywila mpya (hiari)' : 'Nywila', req: !_isEditing),
      TextField(
        controller: _passCtrl,
        obscureText: !_showPass,
        style: TextStyle(color: v2TextPrimaryOf(context), fontSize: 14),
        decoration:
            _inDec(TablerIcons.lock, 'Angalau herufi 6').copyWith(
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showPass = !_showPass),
            icon: Icon(
                _showPass ? PhosphorIcons.eyeSlash() : PhosphorIcons.eye(),
                size: 16,
                color: v2TextMutedOf(context)),
          ),
        ),
      ),
      SizedBox(height: 4),
      Text('Angalau herufi 6',
          style: TextStyle(color: v2TextMutedOf(context), fontSize: 12)),
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
              color: v2SurfaceMutedOf(context),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: v2AccentOf(context))),
            SizedBox(width: 10),
            Text('Inapakia idara...', style: TextStyle(fontSize: 12, color: v2TextMutedOf(context))),
          ]),
        )
      else
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _departments)
                  SizedBox(
                    width: w,
                    child: _V2IdaraCard(
                      code: '${d['code']}',
                      label: '${d['display_name'] ?? d['name'] ?? d['code']}',
                      sub: _deptSub('${d['code']}'),
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
                  ),
              ],
            );
          },
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
        _lbl('Masomo anayofundisha',
            trailing: _masomo.isEmpty ? null : '${_masomo.length} umechagua',
            trailingColor: _masomo.isEmpty ? null : v2AccentOf(context)),
        if (_subjects.isEmpty && _masomo.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                      color: v2SurfaceMutedOf(context),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: v2AccentOf(context))),
                    SizedBox(width: 10),
                    Text('Inapakia masomo...',
                        style: TextStyle(fontSize: 12, color: v2TextMutedOf(context))),
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
      SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Ad.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: v2BorderOf(context)),
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
                          color: v2AccentBgOf(context),
                          borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        // ConstrainedBox + ellipsis: wilaya ndefu kwenye simu
                        // ndogo (320) ilinyonya Row hadi kuvuja 54px. Sasa
                        // chip inafuata nafasi iliyoachwa na Wrap.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width -
                                  110),
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: v2AccentOf(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        SizedBox(width: 4),
                        Icon(PhosphorIcons.x(), size: 13, color: v2AccentOf(context)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Bado hujaongeza mkoa wowote.',
                  style: TextStyle(color: v2TextMutedOf(context), fontSize: 12)),
            ),
          _V2DashedAddButton(
            label: 'Ongeza mkoa',
            onTap: _addKwenda,
          ),
        ]),
      ),

      _secHdr('Hali ya akaunti', PhosphorIcons.gearSix()),
      SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Ad.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: v2BorderOf(context)),
        ),
        child: Column(children: [
          _toggleRow('Akaunti hai', 'Anaweza kuingia kwenye app', _active,
              (v) => setState(() => _active = v)),
          Divider(height: 1, color: v2BorderOf(context)),
          _toggleRow('Haki za admin', 'Anaweza kusimamia watumiaji', _admin,
              (v) => setState(() => _admin = v)),
          Divider(height: 1, color: v2BorderOf(context)),
          _toggleRow('Amelipa', 'Malipo yamethibitishwa', _verified,
              (v) => setState(() => _verified = v)),
        ]),
      ),
    ]);
  }

  Widget _subjectChip(String label, String code) {
    final selected = _masomo.contains(code);
    return GestureDetector(
      onTap: () =>
          setState(() => selected ? _masomo.remove(code) : _masomo.add(code)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? v2AccentOf(context) : Ad.card(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? v2AccentOf(context) : Color(0xFFCFD5DF),
              width: selected ? 1.5 : 1.0),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[
            Icon(PhosphorIcons.check(), size: 13, color: Ad.card(context)),
            SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : v2TextPrimaryOf(context))),
        ]),
      ),
    );
  }

}

// ── _V2IdaraCard — dept selection card ────────────────────────────────────────
class _V2IdaraCard extends StatelessWidget {
  final String code;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _V2IdaraCard({
    required this.code,
    required this.label,
    required this.sub,
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
    return Material(
      color: selected ? color.withValues(alpha: 0.09) : Ad.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : const Color(0xFFCFD5DF),
              width: selected ? 1.5 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 22, color: color),
              SizedBox(height: 6),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: v2TextPrimaryOf(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              if (sub.isNotEmpty)
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: v2TextMutedOf(context), fontSize: 12)),
            ],
          ),
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: v2AccentOf(context).withValues(alpha: 0.6),
          radius: 10,
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.plus(), size: 16, color: v2AccentOf(context)),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: v2AccentOf(context),
                ),
              ),
            ],
          ),
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
        AppToast.success(active ? 'Amesitishwa' : 'Amewezeshwa');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(friendlyError(e));
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
      backgroundColor: Ad.card(context),
      appBar: AppBar(
        backgroundColor: Ad.card(context),
        surfaceTintColor: Ad.card(context),
        elevation: 0,
        title: Text('Taarifa za Mtumiaji',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: v2TextPrimaryOf(context))),
        actions: [
          if (onHariri != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: onHariri,
                icon: Icon(PhosphorIcons.pencilSimple(), size: 14),
                label: Text('Hariri'),
                style: TextButton.styleFrom(
                    foregroundColor: v2AccentOf(context),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          if (onFuta != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: V2IconChip(
                  icon: PhosphorIcons.trash(),
                  color: v2DangerOf(context),
                  background: v2DangerBgOf(context),
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
              color: v2SurfaceMutedOf(context), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                    color: v2AccentOf(context), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(init,
                    style: TextStyle(
                        color: Ad.card(context),
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
                    color: isActive ? v2SuccessOf(context) : v2DangerOf(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: v2SurfaceMutedOf(context), width: 2.5),
                  ),
                ),
              ),
            ]),
            SizedBox(height: 10),
            Text(v2TitleCase(name),
                style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: v2TextPrimaryOf(context))),
            SizedBox(height: 3),
            Text(cadre.isEmpty ? '—' : cadre,
                style:
                    TextStyle(color: v2TextSecondaryOf(context), fontSize: 12.5)),
            const SizedBox(height: 14),
            // Wrap (si Row): simu ndogo (320) na font kubwa, quick actions
            // 3 (Piga/WhatsApp/Funga) zilivuja 24px. Wrap inazigawa mistari
            // miwili ikibidi — hakuna overflow.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 22,
              runSpacing: 10,
              children: [
                _quick(context,
                    PhosphorIcons.phoneCall(),
                    'Piga',
                    v2AccentOf(context),
                    phone.isEmpty
                        ? null
                        : () => v2Launch(
                            'tel:+${phone.replaceAll(RegExp(r'\D'), '')}')),
                _quick(context,
                    PhosphorIcons.whatsappLogo(),
                    'WhatsApp',
                    v2SuccessOf(context),
                    wa.isEmpty
                        ? null
                        : () => v2Launch('https://wa.me/$waIntl')),
                _quick(context,
                    isActive
                        ? PhosphorIcons.prohibit()
                        : PhosphorIcons.checkCircle(),
                    isActive ? 'Funga' : 'Fungua',
                    v2WarningOf(context),
                    () => _toggleSuspend(context)),
              ],
            ),
          ]),
        ),
        SizedBox(height: 16),
        // ── Info card ──
        Container(
          decoration: BoxDecoration(
            color: v2SurfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: v2BorderOf(context), width: 0.7),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            _row(context, 'SIMU', phone.isEmpty ? '—' : v2FmtPhone(phone),
                valueColor: v2AccentOf(context)),
            if (wa.isNotEmpty)
              _row(context, 'WHATSAPP', v2FmtPhone(wa), valueColor: v2SuccessOf(context)),
            _row(context, 'IDARA', _deptDisplayName(category)),
            _row(context, 'KADA', cadre.isEmpty ? '—' : cadre),
            if (subjects.isNotEmpty) _row(context, 'MASOMO', subjects.join(', ')),
            _row(context, 'MKOA / WILAYA',
                region.isEmpty ? '—' : (district.isEmpty ? region : '$region, $district')),
            _row(context, 'KITUO', facility.isEmpty ? '—' : facility),
            _row(context, 'ANAKWENDA', dests.isEmpty ? '—' : dests.join(' · ')),
            _row(context, 'HALI', null, trailing: V2StatusBadge(active: isActive)),
            _row(context, 'AMELIPA', isPaid ? 'Ndiyo' : 'Hapana'),
            _row(context, 'WAJIBU', isAdmin ? 'Admin' : 'Mtumiaji'),
            _row(context, 'IMEUNDWA', _fmtDate('${user['created_at'] ?? ''}'),
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

  Widget _quick(BuildContext context, IconData icon, String label, Color color, VoidCallback? onTap) {
    final chip = V2IconChip(
        icon: icon,
        color: onTap == null ? v2TextMutedOf(context) : color,
        background: Ad.card(context),
        size: 40,
        onTap: onTap);
    return Column(children: [
      chip,
      SizedBox(height: 5),
      Text(label,
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color:
                  onTap == null ? v2TextMutedOf(context) : v2TextSecondaryOf(context))),
    ]);
  }

  Widget _row(BuildContext context, String label, String? value,
      {Color? valueColor, Widget? trailing, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: v2BorderOf(context)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: v2TextMutedOf(context)))),
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
                        color: valueColor ?? v2TextPrimaryOf(context))),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ ADD ADMIN ═══════════════════════════════
// Fomu mpya ya mockup (bluu ya app 0xFF1E40AF, fields zenye icons + label juu).
// onSubmit inatumia adminCreateUser(is_admin:true) — API ileile ya zamani.

class V2AddAdminScreen extends StatefulWidget {
  const V2AddAdminScreen({super.key});
  @override
  State<V2AddAdminScreen> createState() => _V2AddAdminScreenState();
}

class _V2AddAdminScreenState extends State<V2AddAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await ApiService().adminCreateUser({
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone_primary': _phone.text.trim(),
        'password': _password.text,
        'is_admin': true,
      });
      if (!mounted) return;
      AppToast.success('Admin ameongezwa');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(friendlyError(e));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToastHost(
      child: Scaffold(
        backgroundColor: _aaScaffoldT(context),
        appBar: AppBar(
          backgroundColor: _aaScaffoldT(context),
          surfaceTintColor: _aaScaffoldT(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _aaTextT(context)),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            'Ongeza Admin',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: _aaTextT(context)),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: _aaFieldBorderT(context)),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ujumbe wa juu (mwembamba)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _aaBluePaleT(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(Icons.verified_user_outlined,
                          size: 17, color: _aaBlueT(context)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Anaingia kwa barua pepe — hana idara wala kada.',
                          style: TextStyle(fontSize: 12, color: _aaBlueT(context)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Kichwa cha sehemu
                  Row(children: [
                    Icon(Icons.person_outline, size: 15, color: _aaBlueT(context)),
                    const SizedBox(width: 6),
                    Text(
                      'TAARIFA ZA ADMIN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.6,
                          color: _aaLabelT(context)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Divider(height: 1, color: _aaFieldBorderT(context))),
                  ]),
                  const SizedBox(height: 10),
                  _AaField(
                    label: 'Jina Kamili',
                    hint: 'Jina la kwanza na la ukoo',
                    icon: TablerIcons.user,
                    controller: _name,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Weka jina kamili'
                        : null,
                  ),
                  _AaField(
                    label: 'Barua Pepe',
                    hint: 'jina@mfano.com',
                    icon: TablerIcons.mail,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                          ? null
                          : 'Barua pepe si sahihi';
                    },
                  ),
                  _AaField(
                    label: 'Namba ya Simu',
                    hint: '0712345678',
                    icon: TablerIcons.phone,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      final t = (v ?? '').replaceAll(' ', '');
                      return RegExp(r'^(0|\+?255)\d{9}$').hasMatch(t)
                          ? null
                          : 'Namba ya simu si sahihi';
                    },
                  ),
                  _AaField(
                    label: 'Nywila',
                    hint: '••••••••',
                    icon: TablerIcons.lock,
                    controller: _password,
                    obscure: _obscure,
                    helper: 'Angalau herufi 8',
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 17,
                        color: _aaBlueT(context),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Nywila iwe na angalau herufi 8'
                        : null,
                  ),
                  const SizedBox(height: 2),
                  // Kitufe kiko chini ya fomu moja kwa moja, kulia, kidogo
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(TablerIcons.deviceFloppy, size: 15),
                        label: const Text('Hifadhi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _aaBlueT(context),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _aaBluePaleT(context),
                          disabledForegroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0F172A) : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Rangi za fomu ya admin (theme-aware: _aa*T(context) helpers chini)
const Color _aaBlue = Color(0xFF1E40AF);
const Color _aaBluePale = Color(0xFFEEF2FF);
const Color _aaHint = Color(0xFF9CA3AF);
const Color _aaFieldBorder = Color(0xFFDDDCF3);
const Color _aaRed = Color(0xFFDC2626);

Color _aaTextT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFFE7ECF8) : const Color(0xFF111827);
Color _aaBlueT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF7AA7FF) : _aaBlue;
Color _aaBluePaleT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1C2A44) : _aaBluePale;
Color _aaHintT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF94A3B8) : _aaHint;
Color _aaFieldBorderT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF334155) : _aaFieldBorder;
Color _aaRedT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFFF87171) : _aaRed;
Color _aaLabelT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFFA9B7D6) : const Color(0xFF374151);
Color _aaScaffoldT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white;

/// Field yenye label juu, icon ndani, hint, validator na error ya chini.
class _AaField extends StatelessWidget {
  const _AaField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscure = false,
    this.suffix,
    this.helper,
    this.validator,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscure;
  final Widget? suffix;
  final String? helper;
  final String? Function(String?)? validator;

  OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _aaLabelT(context)),
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            obscureText: obscure,
            validator: validator,
            style: TextStyle(fontSize: 13, color: _aaTextT(context)),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13, color: _aaHintT(context)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: Icon(icon, size: 17, color: _aaBlueT(context)),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 20),
              suffixIcon: suffix,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 20),
              errorStyle: TextStyle(fontSize: 11, color: _aaRedT(context)),
              enabledBorder: _border(_aaFieldBorderT(context)),
              focusedBorder: _border(_aaBlueT(context), 1.2),
              errorBorder: _border(_aaRedT(context)),
              focusedErrorBorder: _border(_aaRedT(context), 1.2),
            ),
          ),
          if (helper != null)              Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                helper!,
                style: TextStyle(fontSize: 10.5, color: _aaHintT(context)),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════ IMPORT SCREEN ═══════════════════════════════
// UI mpya ya mockup (IDARA YA FAILI radio chips, Safu za faili, Step 1/2,
// DropZone yenye dashi, kitufe Import chini-kulia). Logic ileile:
// template → adminImportTemplateBytes (kiolezo halisi), upload → adminImportUsersFile.
class V2ImportScreen extends StatefulWidget {
  final List<dynamic> departments;
  const V2ImportScreen({super.key, required this.departments});

  // Safu za faili zinazoonyeshwa kwenye kiolezo — zimejaa kutoka kwenye
  // mockup (pia zinapatikana kwa Elimu; zinaonyeshwa kama chips).
  @override
  State<V2ImportScreen> createState() => _V2ImportScreenState();
}

class _V2ImportScreenState extends State<V2ImportScreen> {
  String _dept = 'Elimu';
  bool _busy = false;
  String? _fileName;
  PlatformFile? _picked;

  static const List<String> _departmentsMock = [
    'Afya', 'Elimu', 'Kilimo na ufugaji', 'Watumishi wa Umma'
  ];
  static const List<String> _columns = [
    'Jina Kamili', 'Simu', 'WhatsApp', 'Kada', 'Kiwango', 'Somo 1',
    'Somo 2', 'Mkoa', 'Wilaya', 'Shule/Kituo', 'Mkoa wa Lengo 1'
  ];

  // Map ya jina la idara (kiswahili) → code ya backend
  static String _deptToCat(String dept) => switch (dept) {
        'Afya' => 'health',
        'Elimu' => 'education',
        'Kilimo na ufugaji' => 'kilimo',
        _ => 'service',
      };

  Future<void> _import() async {
    if (_picked == null) return;
    setState(() => _busy = true);
    try {
      final r = await ApiService().adminImportUsersFile(
          path: _picked!.path!, filename: _picked!.name, category: _deptToCat(_dept));
      final d = (r.data as Map?) ?? {};
      final created = (d['created'] as num?)?.toInt() ?? 0;
      if (mounted) {
        AppToast.success("Watumiaji $created wameongezwa");
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) AppToast.error(friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
      final f = res?.files.firstOrNull;
      if (f == null || f.path == null) return;
      setState(() {
        _picked = f;
        _fileName = f.name;
      });
    } catch (e) {
      if (mounted) AppToast.error(friendlyError(e));
    }
  }

  void _removeFile() {
    setState(() {
      _picked = null;
      _fileName = null;
    });
  }

  Future<void> _template() async {
    try {
      final bytes = await ApiService()
          .adminImportTemplateBytes(_deptToCat(_dept));
      final path = await FilePicker.platform.saveFile(
          fileName: "kiolezo_${_dept.toLowerCase().replaceAll(' ', '_')}.xlsx",
          bytes: Uint8List.fromList(bytes));
      if (!mounted) return;
      if (path == null) {
        AppToast.info('Imeghairiwa');
      } else {
        AppToast.success('Kiolezo imepakuliwa');
      }
    } catch (e) {
      if (mounted) AppToast.error(friendlyError(e));
    }
  }

  String get _fileInfo => _picked == null ? '' : minorInfo(_picked!);

  static String minorInfo(PlatformFile f) {
    final kb = f.size / 1024;
    final sizeStr = kb >= 1024
        ? '${(kb / 1024).toStringAsFixed(1)} MB'
        : '${kb.toStringAsFixed(0)} KB';
    return "$sizeStr · safu ${f.path != null ? '2' : '0'}";
  }

  // ─────────────── UI (mockup) ───────────────
  @override
  Widget build(BuildContext context) {
    return ToastHost(
      child: Scaffold(
        backgroundColor: _aaScaffoldT(context),
        appBar: AppBar(
          backgroundColor: _aaScaffoldT(context),
          surfaceTintColor: _aaScaffoldT(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _iuTextT(context)),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            'Import Watumiaji',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: _iuTextT(context)),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: _aaFieldBorderT(context)),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _IuSectionTitle(
                    icon: Icons.grid_view_outlined, label: 'IDARA YA FAILI'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in _departmentsMock)
                      _IuDeptChip(
                        label: d,
                        selected: d == _dept,
                        onTap: () => setState(() => _dept = d),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const _IuColumnsNote(columns: _columns),
                const SizedBox(height: 14),
                _IuStep(
                  number: '1',
                  title: 'Pakua kiolezo',
                  subtitle: 'Jaza watumiaji kwenye faili hili la Excel.',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _template,
                      icon: const Icon(Icons.download_outlined, size: 15),
                      label: const Text('Pakua Kiolezo (Excel)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _iuBlueT(context),
                        side: BorderSide(color: _iuBlueT(context)),
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _IuStep(
                  number: '2',
                  title: 'Pakia faili lililojazwa',
                  subtitle: 'Chagua faili la Excel (.xlsx).',
                  child: _fileName != null
                      ? _IuFileRow(
                          name: _fileName!,
                          info: _fileInfo,
                          onRemove: _removeFile,
                        )
                      : _IuDropZone(onTap: _pickFile),
                ),
                const SizedBox(height: 16),
                // Kitufe kiko chini ya fomu moja kwa moja, kulia, kidogo
                // (Text ina Flexible — 320px nishinawaka kwa salama)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _fileName != null
                            ? 'Faili liko tayari'
                            : 'Chagua faili kwanza',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: _iuMutedT(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton.icon(
                        onPressed: _fileName != null && !_busy ? _import : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: const Text('Import'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _iuBlueT(context),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _iuBluePaleT(context),
                          disabledForegroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0F172A) : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Rangi za Import (mockup)
const Color _iuBlue = Color(0xFF1E40AF);
const Color _iuBluePale = Color(0xFFEEF2FF);
const Color _iuText = Color(0xFF111827);
const Color _iuMuted = Color(0xFF6B7280);
const Color _iuLine = Color(0xFFE5E7EB);

Color _iuBlueT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF7AA7FF) : _iuBlue;
Color _iuBluePaleT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1C2A44) : _iuBluePale;
Color _iuTextT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFFE7ECF8) : _iuText;
Color _iuMutedT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF9AA8C7) : _iuMuted;
Color _iuLineT(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? const Color(0xFF2A3240) : _iuLine;

class _IuSectionTitle extends StatelessWidget {
  const _IuSectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15, color: _iuBlueT(context)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: _aaLabelT(context)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(height: 1, color: _iuLineT(context))),
      ]),
    );
  }
}

class _IuDeptChip extends StatelessWidget {
  const _IuDeptChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _iuBluePaleT(context) : _aaScaffoldT(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _iuLineT(context)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _IuRadioDot(selected: selected),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? _iuBlueT(context) : _iuTextT(context),
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Duara lenye kitone (si tiki)
class _IuRadioDot extends StatelessWidget {
  const _IuRadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? _iuBlueT(context) : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
          width: 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _iuBlueT(context),
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _IuColumnsNote extends StatelessWidget {
  const _IuColumnsNote({required this.columns});
  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _iuBluePaleT(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, size: 16, color: _iuBlueT(context)),
            const SizedBox(width: 6),
            Text(
              'Safu za faili',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _iuBlueT(context)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final c in columns)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _aaScaffoldT(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _iuLineT(context), width: 0.5),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                        fontSize: 10.5, color: _aaLabelT(context)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IuStep extends StatelessWidget {
  const _IuStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _iuBluePaleT(context),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _iuBlueT(context)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _iuTextT(context)),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: _iuMutedT(context)),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// Eneo la kuchagua faili lenye mstari uliokatika (dashed)
class _IuDropZone extends StatelessWidget {
  const _IuDropZone({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: _IuDashedRRectPainter(context),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                Icon(Icons.file_upload_outlined, size: 22, color: _iuBlueT(context)),
                const SizedBox(height: 4),
                Text(
                  'Chagua Faili la Excel',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _iuBlueT(context)),
                ),
                const SizedBox(height: 1),
                Text(
                  'Bonyeza hapa kuchagua faili',
                  style: TextStyle(fontSize: 10.5, color: _iuMutedT(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IuDashedRRectPainter extends CustomPainter {
  _IuDashedRRectPainter(BuildContext c) : _dark = Theme.of(c).brightness == Brightness.dark;
  final bool _dark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _dark ? const Color(0xFF334155) : const Color(0xFFC7D2FE)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IuFileRow extends StatelessWidget {
  const _IuFileRow({required this.name, required this.onRemove, this.info});
  final String name;
  final String? info;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _iuLineT(context)),
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _iuBluePaleT(context),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.table_chart_outlined,
              size: 18, color: _iuBlueT(context)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _iuTextT(context)),
              ),
              if (info != null)
                Text(info!,
                    style: TextStyle(fontSize: 10.5, color: _iuMutedT(context))),
            ],
          ),
        ),
        InkWell(
          onTap: onRemove,
          customBorder: const CircleBorder(),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, size: 13, color: _aaLabelT(context)),
          ),
        ),
      ]),
    );
  }
}
