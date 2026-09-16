import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/select_sheet.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

// ── Page ───────────────────────────────────────────────────────────────────
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _users = [];
  final _search = TextEditingController();
  Timer? _debounce;

  // filters
  String _category = '';
  int? _regionId;
  String? _regionName;
  int? _districtId;
  String? _districtName;
  String? _subjectCode;
  String? _subjectName;

  // reference data
  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _subjects = [];
  List<dynamic> _departments = [];

  // selection
  Set<String> _selected = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> _loadRefs() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _regions = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []));
    } catch (_) {}
    // Idara DYNAMIC (health/education/watumishi_wa_umma + mpya za admin).
    try {
      final r = await ApiService().getDepartments();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _departments = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []));
    } catch (_) {}
    try {
      final r = await ApiService().getSubjects();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _subjects = raw is List ? raw : (raw['subjects'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadDistricts(int regionId) async {
    try {
      final r = await ApiService().getDistricts(regionId);
      if (!mounted) return;
      final raw = r.data;
      setState(() => _districts = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Backend inasoma `region_id` / `district_id` — sio `region`/`district`.
      // (Zamani filter za mkoa/wilaya zilikuwa zinatumwa kwa majina yasiyopo
      // hivyo backend ilizipuuza kimya na orodha haikuchujwa.)
      final p = <String, dynamic>{'limit': 200};
      if (_search.text.isNotEmpty) p['q'] = _search.text;
      if (_category.isNotEmpty) p['category'] = _category;
      if (_regionId != null) p['region_id'] = _regionId;
      if (_districtId != null) p['district_id'] = _districtId;
      if (_subjectCode != null) p['subject'] = _subjectCode;
      final r = await ApiService().adminUsers(params: p, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List ? raw : (raw['users'] ?? raw['data'] ?? raw['results'] ?? []) as List;
      setState(() { _users = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selected.clear();
        _selectAll = false;
      } else {
        _selected = _users.map((u) => _uid(u)).toSet();
        _selectAll = true;
      }
    });
  }

  String _uid(dynamic u) => (u as Map)['user_id']?.toString() ?? (u)['_id']?.toString() ?? '';

  Future<void> _deleteUser(String id, String name) async {
    final ok = await _confirm('Futa "$name"?', 'Hatua hii haiwezi kutenduliwa.');
    if (ok != true) return;
    try {
      await ApiService().adminDeleteUser(id);
      if (!mounted) return;
      _snack('Mtumiaji amefutwa', _kGreen);
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Hitilafu: $e', _kRed);
    }
  }

  Future<void> _toggleSuspend(Map u) async {
    final id = _uid(u);
    // Hali halisi ni `status` = active | disabled (kama web). `is_active`
    // haipo kwenye backend — ilifanya kila mtumiaji aonekane "Hai".
    final status = '${u['status'] ?? 'active'}'.toLowerCase();
    final isActive = status != 'disabled' && status != 'suspended';
    try {
      await ApiService().adminUpdateUser(id, {'status': isActive ? 'disabled' : 'active'});
      if (!mounted) return;
      _snack(isActive ? 'Amesitishwa' : 'Amewezeshwa', _kAmber);
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Hitilafu: $e', _kRed);
    }
  }

  Future<void> _toggleAdmin(Map u) async {
    final id = _uid(u);
    final isAdmin = u['is_admin'] as bool? ?? false;
    try {
      if (isAdmin) {
        await ApiService().adminRevoke(id);
      } else {
        await ApiService().adminGrant(id);
      }
      if (!mounted) return;
      _snack(isAdmin ? 'Haki za admin zimeondolewa' : 'Amepewa haki za admin', _kGreen);
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Hitilafu: $e', _kRed);
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Ndio', style: TextStyle(color: _kRed, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  void _openCategoryPicker() {
    _showListPicker(
      title: 'Chagua Idara',
      items: <Map<String, dynamic>>[
        {'label': 'Idara zote', 'value': ''},
        for (final d in _departments)
          {'label': '${d['name'] ?? d['code']}', 'value': '${d['code']}'},
      ],
      current: _category,
      onPick: (v) { setState(() { _category = v; }); _load(); },
      getLabel: (i) => i['label'] as String,
      getValue: (i) => i['value'] as String,
    );
  }

  /// Jina la idara kwa `code` (dynamic — idara mpya za admin zinajulikana).
  String _deptName(String code) {
    final d = _departments.firstWhere((x) => '${x['code']}' == code, orElse: () => null);
    return d == null ? code : '${d['name'] ?? code}';
  }

  void _openRegionPicker() {
    final items = [
      {'label': 'Mkoa wote', 'id': null},
      ...List<Map<String, dynamic>>.from(_regions.map((r) => {
        'label': r['name'] ?? r['region_name'] ?? '',
        'id': r['id'] ?? r['region_id'],
      })),
    ];
    _showListPicker(
      title: 'Chagua Mkoa',
      items: items,
      current: _regionId?.toString() ?? '',
      onPick: (v) {
        final id = v.isEmpty ? null : int.tryParse(v);
        final name = id == null ? null : items.firstWhere((i) => i['id'] == id, orElse: () => {})['label'] as String?;
        setState(() { _regionId = id; _regionName = name; _districtId = null; _districtName = null; _districts = []; });
        if (id != null) _loadDistricts(id);
        _load();
      },
      getLabel: (i) => i['label'] as String,
      getValue: (i) => i['id'] == null ? '' : i['id'].toString(),
    );
  }

  void _openDistrictPicker() {
    if (_regionId == null) { _snack('Chagua mkoa kwanza', _kAmber); return; }
    final items = [
      {'label': 'Wilaya zote', 'id': null},
      ...List<Map<String, dynamic>>.from(_districts.map((d) => {
        'label': d['name'] ?? d['district_name'] ?? '',
        'id': d['id'] ?? d['district_id'],
      })),
    ];
    _showListPicker(
      title: 'Chagua Wilaya',
      items: items,
      current: _districtId?.toString() ?? '',
      onPick: (v) {
        final id = v.isEmpty ? null : int.tryParse(v);
        final name = id == null ? null : items.firstWhere((i) => i['id'] == id, orElse: () => {})['label'] as String?;
        setState(() { _districtId = id; _districtName = name; });
        _load();
      },
      getLabel: (i) => i['label'] as String,
      getValue: (i) => i['id'] == null ? '' : i['id'].toString(),
    );
  }

  void _openSubjectPicker() {
    final items = [
      {'label': 'Masomo yote', 'code': ''},
      ...List<Map<String, dynamic>>.from(_subjects.map((s) => {
        'label': s['name'] ?? s['subject_name'] ?? '',
        'code': s['code'] ?? s['subject_code'] ?? '',
      })),
    ];
    _showListPicker(
      title: 'Chagua Somo',
      items: items,
      current: _subjectCode ?? '',
      onPick: (v) {
        final name = items.firstWhere((i) => i['code'] == v, orElse: () => {})['label'] as String?;
        setState(() { _subjectCode = v.isEmpty ? null : v; _subjectName = name; });
        _load();
      },
      getLabel: (i) => i['label'] as String,
      getValue: (i) => i['code'] as String,
    );
  }

  void _showListPicker<T>({
    required String title,
    required List<T> items,
    required String current,
    required Function(String) onPick,
    required String Function(T) getLabel,
    required String Function(T) getValue,
  }) {
    final searchCtrl = TextEditingController();
    List<T> filtered = List.from(items);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900))),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (q) {
                    final ql = q.toLowerCase();
                    setSheet(() => filtered = items.where((i) => getLabel(i).toLowerCase().contains(ql)).toList());
                  },
                  decoration: InputDecoration(
                    hintText: 'Tafuta...',
                    hintStyle: TextStyle(color: _kGrey400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 18),
                    fillColor: _kGrey100,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: _kGrey200),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final val = getValue(item);
                    final selected = val == current;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onPick(val);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? _kBlueBg : Colors.transparent,
                          border: Border(bottom: BorderSide(color: _kGrey200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(getLabel(item), style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? _kBlue : _kGrey900))),
                            if (selected) const Icon(Icons.check_rounded, color: _kBlue, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom sheets ─────────────────────────────────────────────────────────
  void _showAdd() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final waCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool saving = false;
    // Backend inahitaji IDARA + KADA kwa mtumiaji wa kawaida (bila hizi
    // ombi linarudi 422 na mtumiaji hakuwahi kuongezwa).
    String? catCode;
    String? cadreCode;
    String? regId;
    String? distId;
    List<dynamic> cadres = [];
    List<dynamic> districts = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.person_add_rounded, color: _kBlue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ongeza Mtumiaji', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kGrey900)),
                  Text('Jaza taarifa za mtumiaji mpya', style: TextStyle(fontSize: 12, color: _kGrey500)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700)),
                ),
              ]),
              const SizedBox(height: 20),
              _label('Jina Kamili *'),
              _input(nameCtrl, 'Jina kamili', icon: Icons.person_outline_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('Simu'), _input(phoneCtrl, '+255...', keyboard: TextInputType.phone),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label('WhatsApp'), _input(waCtrl, '+255...', keyboard: TextInputType.phone),
                ])),
              ]),
              const SizedBox(height: 12),
              _label('Nywila *'),
              _input(passCtrl, '••••••', icon: Icons.lock_outline_rounded, obscure: true),
              const SizedBox(height: 12),
              _label('Idara * (Elimu / Afya / n.k.)'),
              SelectField(
                hint: 'Chagua idara',
                value: catCode == null ? null : _deptName(catCode!),
                onTap: () async {
                  if (_departments.isEmpty) await _loadRefs();
                  final picked = await showSelectSheet<String>(
                    ctx,
                    title: 'Chagua Idara',
                    items: [
                      for (final d in _departments)
                        (value: '${d['code']}', label: '${d['name'] ?? d['code']}', subtitle: null),
                    ],
                    selected: catCode,
                    searchable: true,
                  );
                  if (picked == null) return;
                  // Kada zitapakiwa kwa idara hii (backend inachuja).
                  List<dynamic> list = [];
                  try {
                    final r = await ApiService().getCadres(category: picked);
                    final raw = r.data;
                    list = raw is List ? raw : (raw['cadres'] ?? raw['data'] ?? []);
                  } catch (_) {}
                  ss(() {
                    catCode = picked;
                    cadreCode = null;
                    cadres = list;
                  });
                },
                leading: const Icon(Icons.apartment_outlined, size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              _label('Kada *'),
              SelectField(
                hint: catCode == null ? 'Chagua idara kwanza' : 'Chagua kada',
                disabled: catCode == null,
                value: cadreCode == null
                    ? null
                    : '${cadres.firstWhere((c) => '${c['code']}' == cadreCode, orElse: () => {})['display_name'] ?? cadreCode}',
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    ctx,
                    title: 'Chagua Kada',
                    items: [
                      for (final c in cadres)
                        (
                          value: '${c['code']}',
                          label: '${c['display_name'] ?? c['name'] ?? c['code']}',
                          subtitle: '${c['code']}',
                        ),
                    ],
                    selected: cadreCode,
                    searchable: true,
                  );
                  if (picked != null) ss(() => cadreCode = picked);
                },
                leading: const Icon(Icons.badge_outlined, size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              _label('Mkoa (hiari)'),
              SelectField(
                hint: 'Chagua mkoa',
                value: regId == null
                    ? null
                    : '${_regions.firstWhere((r) => '${r['id'] ?? r['region_id']}' == regId, orElse: () => {})['name'] ?? ''}',
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    ctx,
                    title: 'Chagua Mkoa',
                    items: [
                      for (final r in _regions)
                        (value: '${r['id'] ?? r['region_id']}', label: '${r['name'] ?? ''}', subtitle: null),
                    ],
                    selected: regId,
                    searchable: true,
                  );
                  if (picked == null) return;
                  List<dynamic> list = [];
                  try {
                    final r = await ApiService().getDistricts(int.parse(picked));
                    final raw = r.data;
                    list = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []);
                  } catch (_) {}
                  ss(() {
                    regId = picked;
                    distId = null;
                    districts = list;
                  });
                },
                leading: const Icon(Icons.map_outlined, size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              _label('Wilaya (hiari)'),
              SelectField(
                hint: regId == null ? 'Chagua mkoa kwanza' : 'Chagua wilaya',
                disabled: regId == null,
                value: distId == null
                    ? null
                    : '${districts.firstWhere((d) => '${d['id'] ?? d['district_id']}' == distId, orElse: () => {})['name'] ?? ''}',
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    ctx,
                    title: 'Chagua Wilaya',
                    items: [
                      for (final d in districts)
                        (value: '${d['id'] ?? d['district_id']}', label: '${d['name'] ?? ''}', subtitle: null),
                    ],
                    selected: distId,
                    searchable: true,
                  );
                  if (picked != null) ss(() => distId = picked);
                },
                leading: const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: const BorderSide(color: _kGrey200), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Ghairi'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (nameCtrl.text.trim().length < 2) {
                      _snack('Jina kamili linahitajika', _kAmber);
                      return;
                    }
                    if (phoneCtrl.text.trim().isEmpty) {
                      _snack('Namba ya simu inahitajika', _kAmber);
                      return;
                    }
                    if (passCtrl.text.length < 6) {
                      _snack('Nywila iwe na herufi 6 au zaidi', _kAmber);
                      return;
                    }
                    if (catCode == null || cadreCode == null) {
                      _snack('Chagua idara na kada', _kAmber);
                      return;
                    }
                    ss(() => saving = true);
                    try {
                      // current_station inahitaji MAJINA (region_name/district_name)
                      // — ndiyo yanatumika kwenye matching na kuonyesha mahali.
                      final reg = _regions.firstWhere(
                          (r) => '${r['id'] ?? r['region_id']}' == regId,
                          orElse: () => null);
                      final dist = districts.firstWhere(
                          (d) => '${d['id'] ?? d['district_id']}' == distId,
                          orElse: () => null);
                      final wa = waCtrl.text.trim();
                      await ApiService().adminCreateUser({
                        'full_name': nameCtrl.text.trim(),
                        'phone_primary': phoneCtrl.text.trim(),
                        if (wa.isNotEmpty) 'phone_alt': wa,
                        'password': passCtrl.text,
                        'category': catCode,
                        'cadre_code': cadreCode,
                        if (regId != null)
                          'current_station': {
                            'region_id': int.tryParse(regId!) ?? 0,
                            'region_name': '${reg?['name'] ?? ''}',
                            'district_id': distId == null ? null : int.tryParse(distId!),
                            'district_name': dist == null ? null : '${dist['name'] ?? ''}',
                          },
                      });
                      if (!mounted) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('Mtumiaji ameongezwa', _kGreen);
                      _load();
                    } catch (e) {
                      ss(() => saving = false);
                      if (!mounted) return;
                      _snack('Hitilafu: $e', _kRed);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_add_rounded, size: 16), SizedBox(width: 6), Text('Ongeza Mtumiaji', style: TextStyle(fontWeight: FontWeight.w700))]),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showEdit(Map<String, dynamic> u) {
    final id = _uid(u);
    final nameCtrl = TextEditingController(text: u['full_name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: u['phone_primary'] as String? ?? u['phone'] as String? ?? '');
    // Backend inatumia `phone_alt` (sio phone_whatsapp) na `is_verified`
    // (sio is_paid); hali ni `status` = active | disabled (kama web).
    final waCtrl = TextEditingController(
        text: u['phone_alt'] as String? ?? u['phone_whatsapp'] as String? ?? '');
    final statusStr = '${u['status'] ?? 'active'}'.toLowerCase();
    String hali = (statusStr == 'disabled' || statusStr == 'suspended') ? 'disabled' : 'active';
    bool paid = (u['is_verified'] as bool?) ?? (u['contact_enabled'] as bool?) ?? false;
    bool admin = u['is_admin'] as bool? ?? false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, color: _kBlue, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Hariri Mtumiaji', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kGrey900))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 30, height: 30, decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700)),
                ),
              ]),
              const SizedBox(height: 20),
              _label('MAELEZO BINAFSI'),
              _input(nameCtrl, 'Jina kamili', icon: Icons.person_outline_rounded),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Simu'), _input(phoneCtrl, '+255...', keyboard: TextInputType.phone)])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('WhatsApp'), _input(waCtrl, '+255...', keyboard: TextInputType.phone)])),
              ]),
              const SizedBox(height: 16),
              _label('HALI NA HADHI'),
              const SizedBox(height: 8),
              Row(children: [
                _pill('Hai', hali == 'active', _kGreen, _kGreenBg, () => ss(() => hali = 'active')),
                const SizedBox(width: 8),
                _pill('Amesitishwa', hali == 'disabled', _kAmber, _kAmberBg, () => ss(() => hali = 'disabled')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _check('Amelipa', paid, (v) => ss(() => paid = v ?? false)),
                const SizedBox(width: 16),
                _check('Admin', admin, (v) => ss(() => admin = v ?? false)),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: const BorderSide(color: _kGrey200), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Ghairi'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    ss(() => saving = true);
                    try {
                      await ApiService().adminUpdateUser(id, {
                        'full_name': nameCtrl.text.trim(),
                        'phone_primary': phoneCtrl.text.trim(),
                        'phone_alt': waCtrl.text.trim().isEmpty ? null : waCtrl.text.trim(),
                        'status': hali,
                        'is_verified': paid,
                        'is_admin': admin,
                      });
                      if (!mounted) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('Imehifadhiwa', _kGreen);
                      _load();
                    } catch (e) {
                      ss(() => saving = false);
                      if (!mounted) return;
                      _snack('Hitilafu: $e', _kRed);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save_rounded, size: 16), SizedBox(width: 6), Text('Hifadhi', style: TextStyle(fontWeight: FontWeight.w700))]),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  /// Import ya watumiaji wengi kwa faili la EXCEL (.xlsx) — hatimaye
  /// imeunganishwa na backend (`POST /admin/users/import?category=...`).
  /// Kabla kitufe kilikuwa kinafunga sheet tu (hakuna kilichotokea).
  void _showImport() {
    String category = 'education';
    bool busy = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.upload_file_rounded, color: _kBlue, size: 20)),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Import Watumiaji', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Pakia faili la Excel (.xlsx)', style: TextStyle(fontSize: 12, color: _kGrey500)),
              ])),
              GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700))),
            ]),
            const SizedBox(height: 16),
            _label('CHAGUA IDARA YA FAILI'),
            Row(children: [
              _pill('Elimu', category == 'education', _kBlue, _kBlueBg, () => ss(() => category = 'education')),
              const SizedBox(width: 8),
              _pill('Afya', category == 'health', _kRed, _kRedBg, () => ss(() => category = 'health')),
              const SizedBox(width: 8),
              _pill('Utumishi', category == 'service', _kGreen, _kGreenBg, () => ss(() => category = 'service')),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _kBlue),
                const SizedBox(width: 8),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Safu za faili', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue)),
                  SizedBox(height: 2),
                  Text(
                    'Jina Kamili · Simu · WhatsApp · Kada · Kiwango (Elimu) · Somo 1 · Somo 2 · '
                    'Mkoa wa Sasa · Wilaya · Shule/Kituo · Mkoa wa Lengo 1 · Wilaya za Lengo 1 · '
                    'Mkoa wa Lengo 2 · Wilaya za Lengo 2 · Miaka ya Kazi',
                    style: TextStyle(fontSize: 11, color: _kBlue),
                  ),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      ss(() => busy = true);
                      try {
                        final res = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['xlsx'],
                        );
                        final f = res?.files.firstOrNull;
                        if (f?.path == null) {
                          ss(() => busy = false);
                          return;
                        }
                        final r = await ApiService().adminImportUsersFile(
                          path: f!.path!,
                          filename: f.name,
                          category: category,
                        );
                        final d = (r.data as Map?) ?? {};
                        final created = d['created'] ?? 0;
                        final skipped = d['skipped'] ?? 0;
                        final errs = (d['errors'] as List?)?.length ?? 0;
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        _snack(
                          'Wameongezwa $created · wamerukwa $skipped'
                          '${errs > 0 ? ' · makosa $errs' : ''}',
                          created > 0 ? _kGreen : _kAmber,
                        );
                        _load();
                      } catch (e) {
                        ss(() => busy = false);
                        if (!mounted) return;
                        _snack('Imeshindikana: $e', _kRed);
                      }
                    },
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Chagua Faili la Excel', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final bytes = await ApiService().adminImportTemplateBytes(category);
                  final path = await FilePicker.platform.saveFile(
                    fileName: 'kiolezo_$category.xlsx',
                    bytes: Uint8List.fromList(bytes),
                  );
                  if (!mounted) return;
                  _snack(path == null ? 'Imeghairiwa' : 'Kiolezo kimehifadhiwa: $path', _kBlue);
                } catch (e) {
                  if (!mounted) return;
                  _snack('Imeshindikana: $e', _kRed);
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Pakua Kiolezo (Excel)', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(foregroundColor: _kBlue, side: const BorderSide(color: _kBlue), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey500, letterSpacing: 0.8)),
  );

  Widget _input(TextEditingController ctrl, String hint, {IconData? icon, TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return TextField(
      controller: ctrl, keyboardType: keyboard, obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: _kGrey400, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: _kGrey400) : null,
        fillColor: Colors.white, filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      ),
    );
  }

  Widget _pill(String label, bool active, Color fg, Color bg, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: active ? bg : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? fg : _kGrey200)),
      child: Text(label, style: TextStyle(fontSize: 13, color: active ? fg : _kGrey700, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
    ),
  );

  Widget _check(String label, bool value, ValueChanged<bool?> onChange) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Transform.scale(scale: 0.9, child: Checkbox(value: value, onChanged: onChange, activeColor: _kBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))),
      Text(label, style: const TextStyle(fontSize: 13, color: _kGrey700)),
    ],
  );

  // ── Filter dropdown button ─────────────────────────────────────────────────
  Widget _filterBtn(String label, VoidCallback onTap, {bool active = false}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active ? _kBlueBg : Colors.white,
        border: Border.all(color: active ? _kBlue : const Color(0xFFCBD5E1), width: active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: active ? _kBlue : _kGrey900, fontWeight: active ? FontWeight.w600 : FontWeight.w400), overflow: TextOverflow.ellipsis)),
          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: active ? _kBlue : _kGrey700),
        ],
      ),
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _kBlue,
          child: CustomScrollView(
            slivers: [
              // ── Static header + filters (scroll away with list) ─────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.group_rounded, color: _kBlue, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Text('Watumiaji', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kGrey900)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: _kRed, shape: BoxShape.circle)),
                                      const SizedBox(width: 4),
                                      const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _kRed, letterSpacing: 0.5)),
                                    ]),
                                  ),
                                ]),
                                Text('${_users.length} watumiaji wote', style: const TextStyle(fontSize: 12, color: _kGrey500)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showAdd,
                            icon: const Icon(Icons.person_add_rounded, size: 14),
                            label: const Text('Ongeza', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _actionBtn(Icons.delete_outline_rounded, 'Trash', _kRed, _kRedBg, _kRed,
                              _selected.isEmpty ? null : () async {
                                final ok = await _confirm('Futa ${_selected.length} mtumiaji?', 'Hatua hii haiwezi kutenduliwa.');
                                if (ok != true) return;
                                for (final id in _selected) {
                                  try { await ApiService().adminDeleteUser(id); } catch (_) {}
                                }
                                if (!mounted) return;
                                setState(() { _selected.clear(); _selectAll = false; });
                                _load();
                              }),
                          const SizedBox(width: 8),
                          _actionBtn(Icons.admin_panel_settings_outlined, 'Admin', _kGrey700, Colors.white, _kGrey200, _showAddAdmin),
                          const SizedBox(width: 8),
                          _actionBtn(Icons.upload_file_outlined, 'Import', _kGrey700, Colors.white, _kGrey200, _showImport),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Tafuta kwa jina, simu au...',
                          hintStyle: const TextStyle(color: _kGrey400, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 20),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Filters row 1: Idara | Mkoa
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _filterBtn(_category.isEmpty ? 'Idara zote' : _deptName(_category), _openCategoryPicker, active: _category.isNotEmpty)),
                          const SizedBox(width: 8),
                          Expanded(child: _filterBtn(_regionName != null ? 'Mkoa: $_regionName' : 'Mkoa wote', _openRegionPicker, active: _regionId != null)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Filters row 2: Wilaya | Masomo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _filterBtn(_districtName ?? 'Wilaya zote', _openDistrictPicker, active: _districtId != null)),
                          const SizedBox(width: 8),
                          Expanded(child: _filterBtn(_subjectName ?? 'Masomo yote', _openSubjectPicker, active: _subjectCode != null)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Chagua zote + Jumla
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _toggleSelectAll,
                            child: Row(children: [
                              SizedBox(
                                width: 24, height: 24,
                                child: Checkbox(
                                  value: _selectAll, onChanged: (_) => _toggleSelectAll(),
                                  activeColor: _kBlue, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('Chagua zote (${_selected.length})', style: const TextStyle(fontSize: 13, color: _kGrey700)),
                            ]),
                          ),
                          const Spacer(),
                          Text('Jumla ${_users.length}', style: const TextStyle(fontSize: 13, color: _kGrey500, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _kGrey200),
                  ],
                ),
              ),
              // ── List / loading / error / empty states ───────────────────
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _kBlue)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.wifi_off_rounded, color: _kGrey400, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: _kGrey500, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Jaribu tena'), style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white)),
                  ])),
                )
              else if (_users.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.group_off_outlined, color: _kGrey400, size: 52),
                    SizedBox(height: 12),
                    Text('Hakuna watumiaji walioonekana', style: TextStyle(color: _kGrey500, fontSize: 14)),
                  ])),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final u = _users[i] as Map<String, dynamic>;
                        final uid = _uid(u);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UserCard(
                            user: u,
                            index: i + 1,
                            selected: _selected.contains(uid),
                            onToggle: () {
                              setState(() {
                                if (_selected.contains(uid)) { _selected.remove(uid); } else { _selected.add(uid); }
                                _selectAll = _selected.length == _users.length;
                              });
                            },
                            onView: () => _showDetail(u),
                            onEdit: () => _showEdit(u),
                            onSuspend: () => _toggleSuspend(u),
                            onAdmin: () => _toggleAdmin(u),
                            onDelete: () => _deleteUser(uid, u['full_name'] as String? ?? ''),
                          ),
                        );
                      },
                      childCount: _users.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color fg, Color bg, Color border, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> u) {
    final name = u['full_name'] as String? ?? '';
    final phone = u['phone_primary'] as String? ?? '';
    final wa = u['phone_alt'] as String? ?? u['phone_whatsapp'] as String? ?? '';
    final category = u['category'] as String? ?? '';
    final cadre = u['cadre_display'] as String? ?? u['cadre_name'] as String? ?? '';
    final isPaid = (u['is_verified'] as bool?) ?? (u['contact_enabled'] as bool?) ?? false;
    final isAdmin = u['is_admin'] as bool? ?? false;
    final station = u['current_station'] as Map? ?? u['station'] as Map? ?? {};
    final region = station['region_name'] as String? ?? station['region'] as String? ?? '';
    final district = station['district_name'] as String? ?? station['district'] as String? ?? '';
    final facility = station['facility_name'] as String? ?? station['facility'] as String? ?? '';
    final subjects = (u['subjects'] as List?)?.map((s) => s['name'] ?? s['code'] ?? s.toString()).toList() ?? [];
    // Backend inahifadhi `desired_destinations` (sio `destinations`).
    final dests = ((u['desired_destinations'] ?? u['destinations']) as List?)
            ?.map((d) => d is Map ? (d['region_name'] ?? d['region'] ?? d.toString()) : d.toString())
            .toList() ??
        [];
    final init = name.isNotEmpty ? name[0].toUpperCase() : '?';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, maxChildSize: 0.9, initialChildSize: 0.75,
        builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Center(child: Column(children: [
            CircleAvatar(radius: 34, backgroundColor: _kGreenBg, child: Text(init, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kGreen))),
            const SizedBox(height: 10),
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900), textAlign: TextAlign.center),
            if (cadre.isNotEmpty) Text(cadre, style: const TextStyle(fontSize: 13, color: _kGrey500)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (isPaid) _chip('Amelipa', _kGreen, _kGreenBg) else _chip('Hajalipa', _kRed, _kRedBg),
              if (isAdmin) _chip('Admin', _kBlue, _kBlueBg),
            ]),
          ])),
          const SizedBox(height: 20),
          _infoRow('Simu', phone.isNotEmpty ? phone : '—', valueColor: _kBlue),
          if (wa.isNotEmpty) _infoRow('WhatsApp', wa, valueColor: _kGreen),
          _infoRow('Idara', category.isNotEmpty ? _deptName(category) : '—'),
          if (region.isNotEmpty) _infoRow('Mkoa', region),
          if (district.isNotEmpty) _infoRow('Wilaya', district),
          if (facility.isNotEmpty) _infoRow('Kituo', facility),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Masomo', style: TextStyle(fontSize: 11, color: _kGrey500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: subjects.map((s) => _chip(s.toString(), _kBlue, _kBlueBg)).toList()),
          ],
          if (dests.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Anataka kwenda', style: TextStyle(fontSize: 11, color: _kGrey500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: dests.map((d) => _chip(d.toString(), _kGrey700, _kGrey100)).toList()),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: const BorderSide(color: _kGrey200), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Funga'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _showEdit(u); }, icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Hariri', style: TextStyle(fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(String t, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
  );

  Widget _infoRow(String label, String value, {Color valueColor = _kGrey900}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label:', style: const TextStyle(fontSize: 13, color: _kGrey500)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: valueColor, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
    ]),
  );

  void _showAddAdmin() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.admin_panel_settings_rounded, color: _kBlue, size: 20)),
                const SizedBox(width: 10),
                const Expanded(child: Text('Ongeza Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700))),
              ]),
              const SizedBox(height: 20),
              _label('Jina Kamili'), _input(nameCtrl, 'Jina kamili', icon: Icons.person_outline_rounded),
              const SizedBox(height: 10),
              _label('Barua Pepe'), _input(emailCtrl, 'admin@mfumo.tz', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _label('Simu'), _input(phoneCtrl, '+255...', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _label('Nenosiri'), _input(passCtrl, '••••••', icon: Icons.lock_outline_rounded, obscure: true),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: saving ? null : () async {
                  ss(() => saving = true);
                  try {
                    await ApiService().adminCreateUser({
                      'full_name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'phone_primary': phoneCtrl.text.trim(),
                      'password': passCtrl.text,
                      'is_admin': true,
                    });
                    if (!mounted) return;
                    if (ctx.mounted) Navigator.pop(ctx);
                    _snack('Admin ameongezwa', _kGreen);
                    _load();
                  } catch (e) {
                    ss(() => saving = false);
                    if (!mounted) return;
                    _snack('Hitilafu: $e', _kRed);
                  }
                },
                icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.admin_panel_settings_rounded, size: 16),
                label: const Text('Ongeza Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── User card ──────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int index;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onSuspend;
  final VoidCallback onAdmin;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.index,
    required this.selected,
    required this.onToggle,
    required this.onView,
    required this.onEdit,
    required this.onSuspend,
    required this.onAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final category = user['category'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ?? user['cadre_name'] as String? ?? '';
    final station = user['current_station'] as Map? ?? user['station'] as Map? ?? {};
    final region = station['region_name'] as String? ?? station['region'] as String? ?? '';
    final district = station['district_name'] as String? ?? station['district'] as String? ?? '';
    // Hali halisi: `status` (active | disabled). `is_active` haipo kwenye
    // backend — ilifanya kila mtumiaji aonekane "Hai".
    final statusStr = '${user['status'] ?? 'active'}'.toLowerCase();
    final isActive = statusStr != 'disabled' && statusStr != 'suspended';
    // Malipo: backend inatumia `is_verified` / `contact_enabled` (sio is_paid).
    final isPaid = (user['is_verified'] as bool?) ?? (user['contact_enabled'] as bool?) ?? false;
    final isAdmin = user['is_admin'] as bool? ?? false;
    final init = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Category display — idara zinazojulikana + code nyingine yoyote.
    final catLabel = category == 'health'
        ? 'Afya'
        : category == 'education'
            ? 'Elimu'
            : category == 'watumishi_wa_umma'
                ? 'Watumishi wa Umma'
                : category;
    final catFg = category == 'health' ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    // location
    final location = [region, district].where((s) => s.isNotEmpty).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: selected ? _kBlue : _kGreen, width: 4),
          top: BorderSide(color: _kGrey200),
          right: BorderSide(color: _kGrey200),
          bottom: BorderSide(color: _kGrey200),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card body ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 22, height: 22,
                    child: Checkbox(
                      value: selected, onChanged: (_) => onToggle(),
                      activeColor: _kBlue, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _kGreenBg,
                  child: Text(init, style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                const SizedBox(width: 10),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Numbered name
                      Text('$index. $name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kGrey900)),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(phone, style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 5),
                      // Category (outlined) + cadre (filled) kama picha
                      Wrap(spacing: 4, runSpacing: 4, children: [
                        if (catLabel.isNotEmpty) _OutlineBadge(catLabel, catFg),
                        if (cadre.isNotEmpty) _Badge(cadre, _kGreen, _kGreenBg),
                        if (isAdmin) _Badge('Admin', _kBlue, _kBlueBg),
                      ]),
                      // Location
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: _kGrey700),
                          const SizedBox(width: 3),
                          Expanded(child: Text(location, style: const TextStyle(fontSize: 11, color: _kGrey700), overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                      const SizedBox(height: 5),
                      // Status chips — outlined style kama picha
                      Wrap(spacing: 4, runSpacing: 4, children: [
                        _OutlineBadge(isActive ? 'Hai' : 'Amesitishwa', isActive ? _kGreen : _kAmber),
                        _OutlineBadge(isPaid ? 'Amelipa' : 'Hajalipa', isPaid ? _kGreen : _kRed),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Action buttons (icon-only kama picha) ────────────────
          const Divider(height: 1, color: _kGrey200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                _IcoBtn(Icons.open_in_new_rounded, _kBlue, onView),
                const SizedBox(width: 6),
                _IcoBtn(Icons.edit_rounded, _kGrey700, onEdit),
                const Spacer(),
                // Piga simu moja kwa moja (kabla hakuna kitufe cha kupiga).
                if (phone.isNotEmpty)
                  _IcoBtn(Icons.phone_outlined, _kBlue, () => _dial(phone)),
                if (phone.isNotEmpty) const SizedBox(width: 6),
                _IcoBtn(
                  isActive ? Icons.do_not_disturb_on_outlined : Icons.check_circle_outline_rounded,
                  isActive ? _kAmber : _kGreen,
                  onSuspend,
                ),
                const SizedBox(width: 6),
                _IcoBtn(
                  isAdmin ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
                  isAdmin ? _kGreen : _kGrey700,
                  onAdmin,
                ),
                const SizedBox(width: 6),
                _IcoBtn(Icons.delete_outline_rounded, _kRed, onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ── Filled badge (category/cadre) ─────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color fg, bg;
  const _Badge(this.label, this.fg, this.bg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700)),
  );
}

// ── Outlined badge (status chips kama picha) ──────────────────────────────
class _OutlineBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _OutlineBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color, width: 1.2),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

/// Piga simu — inafungua app ya simu; kama haipo, namba inanakiliwa.
Future<void> _dial(String phone) async {
  try {
    await launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: phone));
  }
}

// ── Icon-only action button (kama picha) ──────────────────────────────────
class _IcoBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IcoBtn(this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: color),
    ),
  );
}
