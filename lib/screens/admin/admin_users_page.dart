import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/select_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WATUMIAJI — MUUNDO MPYA (kama reference ya design)
//   - Stats row (horizontal scroll cards)
//   - Toolbar "pills" (Ongeza Mtumiaji / Import / Ongeza Admin / Futa)
//   - Search + funnel toggle → filter chips (idara dynamic kutoka DB)
//   - Kadi fupi: safu MOJA ya action icons badala ya vitufe vikubwa
//   - Bottom sheets zenye icon-prefixed fields + idara kama chips
// ─────────────────────────────────────────────────────────────────────────────

// Web `input` class ≡ py-1.5 px-2.5 text-xs rounded-md border-grey-300
const _kInputPad = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
const _kInputRadius = 8.0;
const _kInputFs = 13.0;

const _blue    = Color(0xFF1E40AF);
const _blueBg  = Color(0xFFEFF6FF);
const _blue100 = Color(0xFFDBEAFE);
const _blue700 = Color(0xFF1D4ED8);
const _green50  = Color(0xFFF0FDF4);
const _green    = Color(0xFF16A34A);
const _green700 = Color(0xFF15803D);
const _green100 = Color(0xFFDCFCE7);
const _org50   = Color(0xFFFFF7ED);
const _org700  = Color(0xFFC2410C);
const _amb100  = Color(0xFFFEF3C7);
const _amb600  = Color(0xFFD97706);
const _amb700  = Color(0xFFB45309);
const _red     = Color(0xFFDC2626);
const _red50   = Color(0xFFFEF2F2);
const _red100  = Color(0xFFFEE2E2);
const _g900 = Color(0xFF111827);
const _g700 = Color(0xFF374151);
const _g600 = Color(0xFF4B5563);
const _g500 = Color(0xFF6B7280);
const _g400 = Color(0xFF9CA3AF);
const _g300 = Color(0xFFD1D5DB);
const _g200 = Color(0xFFE5E7EB);
const _g100 = Color(0xFFF3F4F6);
const _pageBg = Color(0xFFF4F6FA);
const _cardBorder = Color(0xFFE4E8F1);

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _State();
}

class _State extends State<AdminUsersPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _users = [];
  bool _live = false;

  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _msgTimer;
  String? _message;

  String _category = '';
  int?    _regionId;   String? _regionName;
  int?    _districtId; String? _districtName;
  String? _facilityId; String? _facilityName;
  String? _subjectCode; String? _subjectName;

  List<dynamic> _regions     = [];
  List<dynamic> _districts   = [];
  List<dynamic> _facilities  = [];
  List<dynamic> _subjects    = [];
  List<dynamic> _departments = [];

  Set<String> _selected = {};
  bool _selectAll = false;

  bool _showFilters = false;

  int _page = 1;
  static const _ps = 5;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
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
    _msgTimer?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() { _page = 1; });
      _load();
    });
  }

  // ── Reference data ─────────────────────────────────────────────────────────
  Future<void> _loadRefs() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _regions = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []));
    } catch (_) {}
    try {
      final r = await ApiService().getDepartments();
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []);
      setState(() => _departments = list
          .where((d) => '${d['is_active'] ?? d['active'] ?? true}' != 'false')
          .toList());
    } catch (_) {}
    if (_category == 'education') {
      try {
        final r = await ApiService().getSubjects(level: 'Primary');
        if (!mounted) return;
        final raw = r.data;
        setState(() => _subjects = raw is List ? raw : (raw['subjects'] ?? raw['data'] ?? []));
      } catch (_) {}
    } else {
      setState(() => _subjects = []);
    }
  }

  Future<void> _loadDistricts(int regionId) async {
    try {
      final r = await ApiService().getDistricts(regionId);
      if (!mounted) return;
      final raw = r.data;
      setState(() => _districts = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadFacilities(int districtId) async {
    try {
      final cat = _category.isEmpty ? 'health' : _category;
      final r = await ApiService().getFacilities(districtId, category: cat);
      if (!mounted) return;
      final raw = r.data;
      setState(() => _facilities = raw is List ? raw : (raw['facilities'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  // ── Main load ──────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = <String, dynamic>{'limit': 200};
      if (_search.text.isNotEmpty) p['q']           = _search.text;
      if (_category.isNotEmpty)   p['category']    = _category;
      if (_regionId   != null)    p['region_id']   = _regionId;
      if (_districtId != null)    p['district_id'] = _districtId;
      if (_facilityId != null)    p['facility_id'] = _facilityId;
      if (_subjectCode != null)   p['subject']     = _subjectCode;
      final r = await ApiService().adminUsers(params: p, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List
          ? raw
          : (raw['users'] ?? raw['data'] ?? raw['results'] ?? []) as List;
      setState(() {
        _users   = list;
        _loading = false;
        _page    = 1;
        _live    = true;
      });
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _live = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages => (_users.isEmpty ? 1 : (_users.length / _ps).ceil());
  int get _safePage   => _page.clamp(1, _totalPages);
  List<dynamic> get _pageItems {
    final s = (_safePage - 1) * _ps;
    return _users.sublist(s, (s + _ps).clamp(0, _users.length));
  }

  // ── Selection ──────────────────────────────────────────────────────────────
  String _uid(dynamic u) =>
      (u as Map)['user_id']?.toString() ?? u['_id']?.toString() ?? '';

  void _toggleSelectAll() => setState(() {
    if (_selectAll) {
      _selected.clear(); _selectAll = false;
    } else {
      _selected = _users.map((u) => _uid(u)).toSet(); _selectAll = true;
    }
  });

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _deleteUser(String id, String name) async {
    if (await _confirm('Futa "$name"?', 'Hatua hii haiwezi kutenduliwa.') != true) return;
    try {
      await ApiService().adminDeleteUser(id);
      if (!mounted) return;
      _snack('Mtumiaji amefutwa', _green); _load();
    } catch (e) {
      if (!mounted) return; _snack('Hitilafu: $e', _red);
    }
  }

  Future<void> _toggleContact(Map u) async {
    try {
      await ApiService().adminToggleContact(_uid(u));
      if (!mounted) return;
      final was = u['contact_enabled'] as bool? ?? false;
      _snack(was ? 'Haki ya kupiga simu imeondolewa' : 'Ameruhusiwa kupiga simu', _green);
      _load();
    } catch (e) {
      if (!mounted) return; _snack('Hitilafu: $e', _red);
    }
  }

  Future<void> _toggleSuspend(Map u) async {
    final active = '${u['status'] ?? 'active'}'.toLowerCase() != 'disabled';
    try {
      await ApiService().adminUpdateUser(_uid(u), {'status': active ? 'disabled' : 'active'});
      if (!mounted) return;
      _snack(active ? 'Amesitishwa' : 'Amewezeshwa', _amb600); _load();
    } catch (e) {
      if (!mounted) return; _snack('Hitilafu: $e', _red);
    }
  }

  Future<void> _toggleAdmin(Map u) async {
    final isAdmin = u['is_admin'] as bool? ?? false;
    try {
      if (isAdmin) {
        await ApiService().adminRevoke(_uid(u));
      } else {
        await ApiService().adminGrant(_uid(u));
      }
      if (!mounted) return;
      _snack(isAdmin ? 'Haki za admin zimeondolewa' : 'Amepewa haki za admin', _green);
      _load();
    } catch (e) {
      if (!mounted) return; _snack('Hitilafu: $e', _red);
    }
  }

  Future<void> _bulkEnable() async {
    if (_selected.isEmpty) return;
    if (await _confirm('Wezesha watumiaji ${_selected.length}?', 'Wote watakuwa "Hai".') != true) return;
    for (final id in _selected) {
      try { await ApiService().adminUpdateUser(id, {'status': 'active'}); } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _selected.clear(); _selectAll = false; });
    _snack('Wamewezeshwa', _green); _load();
  }

  Future<void> _bulkSuspend() async {
    if (_selected.isEmpty) return;
    if (await _confirm('Sitisha watumiaji ${_selected.length}?', 'Wote watasitishwa.') != true) return;
    for (final id in _selected) {
      try { await ApiService().adminUpdateUser(id, {'status': 'disabled'}); } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _selected.clear(); _selectAll = false; });
    _snack('Wamesitishwa', _amb600); _load();
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    if (await _confirm('Futa ${_selected.length} mtumiaji?', 'Hatua hii haiwezi kutenduliwa.') != true) return;
    for (final id in _selected) {
      try { await ApiService().adminDeleteUser(id); } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _selected.clear(); _selectAll = false; });
    _load();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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
          child: const Text('Ndio', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  void _snack(String msg, [Color color = _blue]) {
    if (_message == msg) {
      _msgTimer?.cancel();
      setState(() => _message = null);
      return;
    }
    _msgTimer?.cancel();
    setState(() => _message = msg);
    _msgTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _message = null);
    });
  }

  // Jina la idara kutoka DB (dynamic — si hardcoded)
  String _deptName(String code) {
    for (final d in _departments) {
      if ('${d['code']}' == code) return '${d['display_name'] ?? d['name'] ?? code}';
    }
    if (code == 'health') return 'Afya';
    if (code == 'education') return 'Elimu';
    if (code == 'service') return 'Utumishi';
    return code;
  }

  IconData _deptIcon(String code) {
    switch (code) {
      case 'health':    return PhosphorIcons.heartbeat();
      case 'education': return PhosphorIcons.graduationCap();
      case 'service':   return PhosphorIcons.briefcase();
      default:          return PhosphorIcons.buildings();
    }
  }

  // ── Pickers (searchable bottom sheet) ──────────────────────────────────────
  void _showPicker<T>({
    required String title,
    required List<T> items,
    required String current,
    required void Function(String) onPick,
    required String Function(T) label,
    required String Function(T) value,
  }) {
    final ctrl = TextEditingController();
    List<T> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(children: [
            const SizedBox(height: 6),
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _g900))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(color: _g100, shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.x(), size: 14, color: _g700),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: ctrl,
                onChanged: (q) {
                  final ql = q.toLowerCase();
                  ss(() => filtered = items.where((i) => label(i).toLowerCase().contains(ql)).toList());
                },
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  hintStyle: const TextStyle(color: _g400, fontSize: 14),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), color: _g400, size: 18),
                  fillColor: _g100, filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: _g200),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  final v = value(item);
                  final sel = v == current;
                  return InkWell(
                    onTap: () { Navigator.pop(ctx); onPick(v); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? _blueBg : Colors.transparent,
                        border: const Border(bottom: BorderSide(color: _g200)),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(label(item), style: TextStyle(
                            fontSize: 15,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel ? _blue : _g900))),
                        if (sel) Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: _blue, size: 18),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _openRegionPicker() {
    final items = [
      {'label': 'Mkoa wote', 'id': ''},
      ...List<Map<String, String>>.from(_regions.map((r) => {
        'label': '${r['name'] ?? r['region_name'] ?? ''}',
        'id':    '${r['id'] ?? r['region_id'] ?? ''}',
      })),
    ];
    _showPicker<Map<String, String>>(
      title: 'Chagua Mkoa',
      items: items,
      current: _regionId?.toString() ?? '',
      onPick: (v) {
        final id = v.isEmpty ? null : int.tryParse(v);
        final nm = v.isEmpty ? null : items.firstWhere((i) => i['id'] == v, orElse: () => {})['label'];
        setState(() {
          _regionId = id; _regionName = nm;
          _districtId = null; _districtName = null; _districts = [];
          _facilityId = null; _facilityName = null; _facilities = [];
          _page = 1;
        });
        if (id != null) _loadDistricts(id);
        _load();
      },
      label: (i) => i['label']!, value: (i) => i['id']!,
    );
  }

  void _openDistrictPicker() {
    if (_regionId == null) { _snack('Chagua mkoa kwanza', _amb600); return; }
    final items = [
      {'label': 'Wilaya zote', 'id': ''},
      ...List<Map<String, String>>.from(_districts.map((d) => {
        'label': '${d['name'] ?? d['district_name'] ?? ''}',
        'id':    '${d['id'] ?? d['district_id'] ?? ''}',
      })),
    ];
    _showPicker<Map<String, String>>(
      title: 'Chagua Wilaya',
      items: items,
      current: _districtId?.toString() ?? '',
      onPick: (v) {
        final id = v.isEmpty ? null : int.tryParse(v);
        final nm = v.isEmpty ? null : items.firstWhere((i) => i['id'] == v, orElse: () => {})['label'];
        setState(() {
          _districtId = id; _districtName = nm;
          _facilityId = null; _facilityName = null; _facilities = [];
          _page = 1;
        });
        if (id != null) _loadFacilities(id);
        _load();
      },
      label: (i) => i['label']!, value: (i) => i['id']!,
    );
  }

  void _openFacilityPicker() {
    if (_districtId == null) { _snack('Chagua wilaya kwanza', _amb600); return; }
    final items = [
      {'label': 'Vituo vyote', 'id': ''},
      ...List<Map<String, String>>.from(_facilities.map((f) => {
        'label': '${f['name'] ?? ''}',
        'id':    '${f['id'] ?? f['code'] ?? ''}',
      })),
    ];
    _showPicker<Map<String, String>>(
      title: 'Chagua Kituo',
      items: items,
      current: _facilityId ?? '',
      onPick: (v) {
        final nm = v.isEmpty ? null : items.firstWhere((i) => i['id'] == v, orElse: () => {})['label'];
        setState(() { _facilityId = v.isEmpty ? null : v; _facilityName = nm; _page = 1; });
        _load();
      },
      label: (i) => i['label']!, value: (i) => i['id']!,
    );
  }

  void _openSubjectPicker() {
    final items = [
      {'label': 'Masomo yote', 'code': ''},
      ...List<Map<String, String>>.from(_subjects.map((s) => {
        'label': '${s['name'] ?? s['subject_name'] ?? ''}',
        'code':  '${s['code'] ?? s['subject_code'] ?? ''}',
      })),
    ];
    _showPicker<Map<String, String>>(
      title: 'Chagua Somo',
      items: items,
      current: _subjectCode ?? '',
      onPick: (v) {
        final nm = v.isEmpty ? null : items.firstWhere((i) => i['code'] == v, orElse: () => {})['label'];
        setState(() { _subjectCode = v.isEmpty ? null : v; _subjectName = nm; _page = 1; });
        _load();
      },
      label: (i) => i['label']!, value: (i) => i['code']!,
    );
  }

  // ── Import modal ───────────────────────────────────────────────────────────
  void _showImport() {
    String cat = _category.isNotEmpty ? _category : 'education';
    bool busy = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4,
                decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            _sheetHeader(ctx, PhosphorIcons.uploadSimple(), 'Import Watumiaji',
                'Pakia faili la Excel (.xlsx)'),
            const SizedBox(height: 16),
            const Text('Idara ya faili',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: _g500)),
            const SizedBox(height: 8),
            // Idara kama chips — dynamic kutoka DB
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in _departments)
                _deptChip(
                  '${d['display_name'] ?? d['name'] ?? d['code']}',
                  '${d['code']}',
                  cat == '${d['code']}',
                  () => ss(() => cat = '${d['code']}'),
                ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _blueBg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(PhosphorIcons.info(PhosphorIconsStyle.fill), size: 16, color: _blue),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Safu za faili', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
                  const SizedBox(height: 2),
                  Text('Jina Kamili · Simu · WhatsApp · Kada · Kiwango · Somo 1 · Somo 2 · Mkoa · Wilaya · Shule/Kituo · Mkoa wa Lengo 1',
                      style: TextStyle(fontSize: 11, color: _blue700)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: busy ? null : () async {
                ss(() => busy = true);
                try {
                  final res = await FilePicker.platform.pickFiles(
                      type: FileType.custom, allowedExtensions: ['xlsx']);
                  final f = res?.files.firstOrNull;
                  if (f?.path == null) { ss(() => busy = false); return; }
                  final r = await ApiService().adminImportUsersFile(
                      path: f!.path!, filename: f.name, category: cat);
                  final d = (r.data as Map?) ?? {};
                  final created = d['created'] ?? 0;
                  final skipped = d['skipped'] ?? 0;
                  final errs = (d['errors'] as List?)?.length ?? 0;
                  if (!mounted) return;
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack(
                    'Wameongezwa $created · wamerukwa $skipped${errs > 0 ? ' · makosa $errs' : ''}',
                    created > 0 ? _green : _amb600,
                  );
                  _load();
                } catch (e) {
                  ss(() => busy = false);
                  if (!mounted) return; _snack('Imeshindikana: $e', _red);
                }
              },
              icon: busy
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(PhosphorIcons.fileXls(PhosphorIconsStyle.fill), size: 18),
              label: const Text('Chagua Faili la Excel', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final bytes = await ApiService().adminImportTemplateBytes(cat);
                  final path = await FilePicker.platform.saveFile(
                      fileName: 'kiolezo_$cat.xlsx', bytes: Uint8List.fromList(bytes));
                  if (!mounted) return;
                  _snack(path == null ? 'Imeghairiwa' : 'Kiolezo kimehifadhiwa: $path', _blue);
                } catch (e) {
                  if (!mounted) return; _snack('Imeshindikana: $e', _red);
                }
              },
              icon: Icon(PhosphorIcons.downloadSimple(), size: 18),
              label: const Text('Pakua Kiolezo (Excel)', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _blue, side: const BorderSide(color: _blue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Add user modal ─────────────────────────────────────────────────────────
  void _showAdd() {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final waCtrl    = TextEditingController();
    final passCtrl  = TextEditingController();
    bool saving = false;
    bool isAdmin = false;
    String? catCode; String? cadreCode; String? regId; String? distId;
    List<dynamic> cadres = []; List<dynamic> dists = [];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 38, height: 4,
                  decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 16),
              _sheetHeader(ctx, PhosphorIcons.userPlus(), 'Ongeza Mtumiaji',
                  'Jaza taarifa za mtumiaji mpya'),
              const SizedBox(height: 18),
              _lbl('Jina Kamili *'),
              _inp(nameCtrl, 'mf. Godfrey Paul', icon: PhosphorIcons.user()),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Simu'),
                  _inp(phoneCtrl, '+255...', icon: PhosphorIcons.phone(),
                      keyboard: TextInputType.phone),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('WhatsApp'),
                  _inp(waCtrl, '+255...', icon: PhosphorIcons.whatsappLogo(),
                      keyboard: TextInputType.phone),
                ])),
              ]),
              const SizedBox(height: 12),
              _lbl('Nywila *'),
              _inp(passCtrl, '••••••', icon: PhosphorIcons.lock(), obscure: true),
              const SizedBox(height: 14),
              const Text('Idara', style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12.5, color: _g500)),
              const SizedBox(height: 8),
              // Idara kama chips — dynamic kutoka DB
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in _departments)
                  _deptChipIcon(
                    '${d['display_name'] ?? d['name'] ?? d['code']}',
                    '${d['code']}',
                    catCode == '${d['code']}',
                    () async {
                      List<dynamic> list = [];
                      try {
                        final r = await ApiService().getCadres(category: '${d['code']}');
                        final raw = r.data;
                        list = raw is List ? raw : (raw['cadres'] ?? raw['data'] ?? []);
                      } catch (_) {}
                      ss(() { catCode = '${d['code']}'; cadreCode = null; cadres = list; });
                    },
                  ),
              ]),
              const SizedBox(height: 14),
              _lbl('Kada *'),
              SelectField(
                hint: catCode == null ? 'Chagua idara kwanza' : 'Chagua kada',
                disabled: catCode == null,
                value: cadreCode == null ? null
                    : '${cadres.firstWhere((c) => '${c['code']}' == cadreCode, orElse: () => {})['display_name'] ?? cadreCode}',
                onTap: () async {
                  final picked = await showSelectSheet<String>(ctx,
                      title: 'Chagua Kada',
                      items: [
                        for (final c in cadres)
                          (
                            value: '${c['code']}',
                            label: '${c['display_name'] ?? c['name'] ?? c['code']}',
                            subtitle: '${c['code']}',
                          ),
                      ],
                      selected: cadreCode, searchable: true);
                  if (picked != null) ss(() => cadreCode = picked);
                },
                leading: Icon(PhosphorIcons.identificationBadge(), size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              _lbl('Mkoa (hiari)'),
              SelectField(
                hint: 'Chagua mkoa',
                value: regId == null
                    ? null
                    : '${_regions.firstWhere((r) => '${r['id'] ?? r['region_id']}' == regId, orElse: () => {})['name'] ?? ''}',
                onTap: () async {
                  final picked = await showSelectSheet<String>(ctx,
                      title: 'Chagua Mkoa',
                      items: [
                        for (final r in _regions)
                          (value: '${r['id'] ?? r['region_id']}', label: '${r['name'] ?? ''}', subtitle: null),
                      ],
                      selected: regId, searchable: true);
                  if (picked == null) return;
                  List<dynamic> list = [];
                  try {
                    final r = await ApiService().getDistricts(int.parse(picked));
                    final raw = r.data;
                    list = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []);
                  } catch (_) {}
                  ss(() { regId = picked; distId = null; dists = list; });
                },
                leading: Icon(PhosphorIcons.mapPin(), size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              _lbl('Wilaya (hiari)'),
              SelectField(
                hint: regId == null ? 'Chagua mkoa kwanza' : 'Chagua wilaya',
                disabled: regId == null,
                value: distId == null
                    ? null
                    : '${dists.firstWhere((d) => '${d['id'] ?? d['district_id']}' == distId, orElse: () => {})['name'] ?? ''}',
                onTap: () async {
                  final picked = await showSelectSheet<String>(ctx,
                      title: 'Chagua Wilaya',
                      items: [
                        for (final d in dists)
                          (value: '${d['id'] ?? d['district_id']}', label: '${d['name'] ?? ''}', subtitle: null),
                      ],
                      selected: distId, searchable: true);
                  if (picked != null) ss(() => distId = picked);
                },
                leading: Icon(PhosphorIcons.mapTrifold(), size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => ss(() => isAdmin = !isAdmin),
                child: Row(children: [
                  Checkbox(
                    value: isAdmin,
                    activeColor: _blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => ss(() => isAdmin = v ?? false),
                  ),
                  Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), size: 16, color: _blue),
                  const SizedBox(width: 6),
                  const Text('Admin', style: TextStyle(fontSize: 13, color: _g700)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _g700, side: const BorderSide(color: _g200),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text('Ghairi'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (nameCtrl.text.trim().length < 2) {
                      _snack('Jina kamili linahitajika', _amb600); return;
                    }
                    if (phoneCtrl.text.trim().isEmpty) {
                      _snack('Namba ya simu inahitajika', _amb600); return;
                    }
                    if (passCtrl.text.length < 6) {
                      _snack('Nywila iwe na herufi 6+', _amb600); return;
                    }
                    if (catCode == null || cadreCode == null) {
                      _snack('Chagua idara na kada', _amb600); return;
                    }
                    ss(() => saving = true);
                    try {
                      final reg = _regions.firstWhere(
                          (r) => '${r['id'] ?? r['region_id']}' == regId, orElse: () => null);
                      final dist = dists.firstWhere(
                          (d) => '${d['id'] ?? d['district_id']}' == distId, orElse: () => null);
                      final wa = waCtrl.text.trim();
                      await ApiService().adminCreateUser({
                        'full_name': nameCtrl.text.trim(),
                        'phone_primary': phoneCtrl.text.trim(),
                        if (wa.isNotEmpty) 'phone_alt': wa,
                        'password': passCtrl.text,
                        'category': catCode,
                        'cadre_code': cadreCode,
                        'is_admin': isAdmin,
                        if (regId != null) 'current_station': {
                          'region_id': int.tryParse(regId!) ?? 0,
                          'region_name': '${reg?['name'] ?? ''}',
                          'district_id': distId == null ? null : int.tryParse(distId!),
                          'district_name': dist == null ? null : '${dist['name'] ?? ''}',
                        },
                      });
                      if (!mounted) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('Mtumiaji ameongezwa', _green); _load();
                    } catch (e) {
                      ss(() => saving = false);
                      if (!mounted) return; _snack('Hitilafu: $e', _red);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(PhosphorIcons.userPlus(), size: 16),
                          const SizedBox(width: 6),
                          const Text('Ongeza', style: TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Edit user modal ────────────────────────────────────────────────────────
  void _showEdit(Map<String, dynamic> u) {
    final id        = _uid(u);
    final nameCtrl  = TextEditingController(text: u['full_name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: u['phone_primary'] as String? ?? u['phone'] as String? ?? '');
    final waCtrl    = TextEditingController(text: u['phone_alt'] as String? ?? u['phone_whatsapp'] as String? ?? '');
    final passCtrl  = TextEditingController();
    final st        = '${u['status'] ?? 'active'}'.toLowerCase();
    String hali     = ['active', 'inactive', 'matched', 'disabled'].contains(st) ? st : 'active';
    bool paid       = (u['is_verified'] as bool?) ?? false;
    bool admin      = u['is_admin'] as bool? ?? false;
    bool saving     = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 38, height: 4,
                  decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 16),
              _sheetHeader(ctx, PhosphorIcons.pencilSimple(), 'Hariri Mtumiaji', null),
              const SizedBox(height: 18),
              _lbl('MAELEZO BINAFSI'),
              _inp(nameCtrl, 'Jina kamili', icon: PhosphorIcons.user()),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Simu'),
                  _inp(phoneCtrl, '+255...', icon: PhosphorIcons.phone(),
                      keyboard: TextInputType.phone),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('WhatsApp'),
                  _inp(waCtrl, '+255...', icon: PhosphorIcons.whatsappLogo(),
                      keyboard: TextInputType.phone),
                ])),
              ]),
              const SizedBox(height: 12),
              _lbl('Nywila Mpya'),
              _inp(passCtrl, 'Acha tupu kama hubadilishi',
                  icon: PhosphorIcons.lock(), obscure: true),
              const SizedBox(height: 14),
              _lbl('Hali'),
              SelectField(
                hint: 'Hali ya mtumiaji',
                value: hali == 'active' ? 'Hai' : hali == 'disabled' ? 'Amesitishwa'
                    : hali == 'matched' ? 'Amepata mwenzake' : 'Hajakamilisha',
                onTap: () async {
                  final picked = await showSelectSheet<String>(ctx,
                      title: 'Hali ya Mtumiaji',
                      items: const [
                        (value: 'active',   label: 'Hai',               subtitle: null),
                        (value: 'inactive', label: 'Hajakamilisha',      subtitle: null),
                        (value: 'matched',  label: 'Amepata mwenzake',   subtitle: null),
                        (value: 'disabled', label: 'Amesitishwa',        subtitle: null),
                      ],
                      selected: hali, searchable: false);
                  if (picked != null) ss(() => hali = picked);
                },
                leading: Icon(PhosphorIcons.checkCircle(), size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 10),
              Row(children: [
                _chk('Amelipa', paid,  (v) => ss(() => paid  = v ?? false)),
                const SizedBox(width: 16),
                _chk('Admin',   admin, (v) => ss(() => admin = v ?? false)),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _g700, side: const BorderSide(color: _g200),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
                        'status': hali, 'is_verified': paid, 'is_admin': admin,
                        if (passCtrl.text.isNotEmpty) 'new_password': passCtrl.text,
                      });
                      if (!mounted) return;
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('Imehifadhiwa', _green); _load();
                    } catch (e) {
                      ss(() => saving = false);
                      if (!mounted) return; _snack('Hitilafu: $e', _red);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(PhosphorIcons.floppyDisk(), size: 16),
                          const SizedBox(width: 6),
                          const Text('Hifadhi', style: TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Add admin modal ────────────────────────────────────────────────────────
  void _showAddAdmin() {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    bool saving = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 38, height: 4,
                  decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 16),
              _sheetHeader(ctx, PhosphorIcons.shieldCheck(), 'Ongeza Admin', null),
              const SizedBox(height: 18),
              _lbl('Jina Kamili'),
              _inp(nameCtrl,  'Jina kamili',    icon: PhosphorIcons.user()),
              const SizedBox(height: 10),
              _lbl('Barua Pepe'),
              _inp(emailCtrl, 'admin@mfumo.tz', icon: PhosphorIcons.envelopeSimple(),
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _lbl('Simu'),
              _inp(phoneCtrl, '+255...',        icon: PhosphorIcons.phone(),
                  keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _lbl('Nenosiri'),
              _inp(passCtrl,  '••••••',         icon: PhosphorIcons.lock(), obscure: true),
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
                    _snack('Admin ameongezwa', _green); _load();
                  } catch (e) {
                    ss(() => saving = false);
                    if (!mounted) return; _snack('Hitilafu: $e', _red);
                  }
                },
                icon: saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), size: 16),
                label: const Text('Ongeza Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Detail / view modal ────────────────────────────────────────────────────
  void _showDetail(Map<String, dynamic> u) {
    final name     = u['full_name'] as String? ?? '';
    final phone    = u['phone_primary'] as String? ?? '';
    final wa       = u['phone_alt'] as String? ?? u['phone_whatsapp'] as String? ?? '';
    final category = u['category'] as String? ?? '';
    final cadre    = u['cadre_display'] as String? ?? u['cadre_name'] as String? ?? '';
    final isPaid   = (u['is_verified'] as bool?) ?? false;
    final isAdmin  = u['is_admin'] as bool? ?? false;
    final station  = u['current_station'] as Map? ?? u['station'] as Map? ?? {};
    final region   = station['region_name'] as String? ?? '';
    final district = station['district_name'] as String? ?? '';
    final facility = station['facility_name'] as String? ?? '';
    final subjects = (u['subjects'] as List?)
        ?.map((s) => s['name'] ?? s['code'] ?? s.toString()).toList() ?? [];
    final dests = ((u['desired_destinations'] ?? u['destinations']) as List?)
        ?.map((d) => d is Map
            ? (d['region_name'] ?? d['region'] ?? d.toString())
            : d.toString())
        .toList() ?? [];
    final init     = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final catLabel = category.isEmpty ? '' : _deptName(category);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, maxChildSize: 0.9, initialChildSize: 0.75,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(child: Container(width: 38, height: 4,
                decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 20),
            Center(child: Column(children: [
              CircleAvatar(radius: 34, backgroundColor: _blueBg,
                  child: Text(init, style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: _blue700))),
              const SizedBox(height: 10),
              Text(name, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _g900),
                  textAlign: TextAlign.center),
              if (cadre.isNotEmpty)
                Text(cadre, style: const TextStyle(fontSize: 13, color: _g500)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                if (isPaid) ...[
                  _chip2('Amelipa', _green, _green100),
                ] else ...[
                  _chip2('Hajalipa', _red, _red100),
                ],
                if (isAdmin) _chip2('Admin', _blue, _blueBg),
              ]),
            ])),
            const SizedBox(height: 20),
            _infoRow('Simu',   phone.isNotEmpty ? phone : '—', vc: _blue),
            if (wa.isNotEmpty) ...[
              _infoRow('WhatsApp', wa, vc: _green),
            ],
            _infoRow('Idara',  catLabel.isNotEmpty ? catLabel : '—'),
            if (region.isNotEmpty)   _infoRow('Mkoa',   region),
            if (district.isNotEmpty) _infoRow('Wilaya', district),
            if (facility.isNotEmpty) _infoRow('Kituo',  facility),
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Masomo',
                  style: TextStyle(fontSize: 11, color: _g500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                  children: subjects.map((s) => _chip2(s.toString(), _blue, _blueBg)).toList()),
            ],
            if (dests.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Anataka kwenda',
                  style: TextStyle(fontSize: 11, color: _g500, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                  children: dests.map((d) => _chip2(d.toString(), _g700, _g100)).toList()),
            ],
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _g700, side: const BorderSide(color: _g200),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Funga'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); _showEdit(u); },
                icon: Icon(PhosphorIcons.pencilSimple(), size: 16),
                label: const Text('Hariri', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Sheet helpers ──────────────────────────────────────────────────────────
  Widget _sheetHeader(BuildContext ctx, IconData icon, String title, String? sub) =>
      Row(children: [
        Container(width: 38, height: 38,
            decoration: BoxDecoration(color: _blueBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _blue, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _g900)),
          if (sub != null) Text(sub, style: const TextStyle(fontSize: 12, color: _g500)),
        ])),
        GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(width: 30, height: 30,
              decoration: const BoxDecoration(color: _g100, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.x(), size: 14, color: _g700)),
        ),
      ]);

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: _g500, letterSpacing: 0.8)),
  );

  Widget _inp(TextEditingController ctrl, String hint,
      {IconData? icon, TextInputType keyboard = TextInputType.text, bool obscure = false}) =>
      TextField(
        controller: ctrl, keyboardType: keyboard, obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: _g400, fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, size: 17, color: _g400) : null,
          fillColor: Colors.white, filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _g200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _g200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _blue, width: 1.5)),
        ),
      );

  Widget _deptChip(String label, String code, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _blueBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _blue : _g200, width: active ? 1.4 : 1),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 12.5, color: active ? _blue : _g700,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ),
      );

  Widget _deptChipIcon(String label, String code, bool active, VoidCallback onTap) {
    final icon = _deptIcon(code);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _blueBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _blue : _g200, width: active ? 1.4 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? _blue : _g500),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 12.5, color: active ? _blue : _g700,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  Widget _chk(String label, bool value, ValueChanged<bool?> onChange) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Transform.scale(scale: 0.9, child: Checkbox(
            value: value, onChanged: onChange, activeColor: _blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))),
        Text(label, style: const TextStyle(fontSize: 13, color: _g700)),
      ]);

  Widget _chip2(String t, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
  );

  Widget _infoRow(String label, String val, {Color vc = _g900}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label:', style: const TextStyle(fontSize: 13, color: _g500)),
      const SizedBox(width: 8),
      Expanded(child: Text(val, style: TextStyle(fontSize: 13, color: vc, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
    ]),
  );

  // ── Filter select — compact input kama web ─────────────────────────────────
  Widget _selBtn(String label, VoidCallback onTap, {bool active = false, bool disabled = false}) =>
      GestureDetector(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            padding: _kInputPad,
            decoration: BoxDecoration(
              color: active ? _blueBg : Colors.white,
              border: Border.all(
                  color: active ? _blue : _g300,
                  width: active ? 1.5 : 1.0),
              borderRadius: BorderRadius.circular(_kInputRadius),
            ),
            child: Row(children: [
              Expanded(child: Text(label, style: TextStyle(
                  fontSize: _kInputFs,
                  color: active ? _blue : _g900,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400),
                  overflow: TextOverflow.ellipsis)),
              Icon(PhosphorIcons.caretDown(), size: 13, color: active ? _blue : _g500),
            ]),
          ),
        ),
      );

  // ── Pagination button ──────────────────────────────────────────────────────
  Widget _pageBtn(String label, VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _g200),
                borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _g700)),
          ),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final items = _pageItems;
    final total = _totalPages;
    final cur   = _safePage;

    return Container(
      color: _pageBg,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _blue,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Title ──────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildTitle()),
              // ── Stats row ──────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildStatsRow()),
              // ── Toolbar pills ──────────────────────────────────────────
              SliverToBoxAdapter(child: _buildToolbar()),
              // ── Search + funnel ────────────────────────────────────────
              SliverToBoxAdapter(child: _buildSearchBar()),
              // ── Filter chips (funnel) ──────────────────────────────────
              if (_showFilters) SliverToBoxAdapter(child: _buildFilterChips()),
              // ── Bulk bar ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildBulkBar()),
              // ── Inline message ─────────────────────────────────────────
              if (_message != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _blueBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_message!,
                          style: const TextStyle(fontSize: 13.5, color: _blue)),
                    ),
                  ),
                ),
              // ── Count ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Text(
                    'Jumla ${_loading ? '...' : _users.length}',
                    style: const TextStyle(fontSize: 12, color: _g500),
                  ),
                ),
              ),
              // ── Body ───────────────────────────────────────────────────
              if (_loading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: _blue)))
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.wifiHigh(), color: _g400, size: 44),
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: _g500, fontSize: 12),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
                      label: const Text('Jaribu tena'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _blue, foregroundColor: Colors.white),
                    ),
                  ])),
                )
              else if (_users.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.usersThree(), color: _g400, size: 48),
                    const SizedBox(height: 12),
                    const Text('Hakuna watumiaji walioonekana',
                        style: TextStyle(color: _g500, fontSize: 14)),
                  ])),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _UserCard(
                      user:      items[i] as Map<String, dynamic>,
                      selected:  _selected.contains(_uid(items[i])),
                      deptName:  _deptName('${(items[i] as Map)['category'] ?? ''}'),
                      deptIcon:  _deptIcon('${(items[i] as Map)['category'] ?? ''}'),
                      onToggle:  () => setState(() {
                        final id = _uid(items[i]);
                        if (_selected.contains(id)) {
                          _selected.remove(id);
                        } else {
                          _selected.add(id);
                        }
                        _selectAll = _selected.length == _users.length;
                      }),
                      onView:    () => _showDetail(items[i] as Map<String, dynamic>),
                      onEdit:    () => _showEdit(items[i] as Map<String, dynamic>),
                      onSuspend: () => _toggleSuspend(items[i] as Map),
                      onAdmin:   () => _toggleAdmin(items[i] as Map),
                      onDelete:  () => _deleteUser(
                          _uid(items[i]), (items[i] as Map)['full_name'] as String? ?? ''),
                      onContact: () => _toggleContact(items[i] as Map),
                    ),
                  ),
                ),
                // Pagination
                if (total > 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _pageBtn('← Rudi',
                            cur <= 1 ? null : () => setState(() => _page = cur - 1)),
                        const SizedBox(width: 12),
                        Text('$cur / $total', style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: _g500)),
                        const SizedBox(width: 12),
                        _pageBtn('Endelea →',
                            cur >= total ? null : () => setState(() => _page = cur + 1)),
                      ]),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Title ──────────────────────────────────────────────────────────────────
  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        const Expanded(
          child: Text('Watumiaji',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _g900)),
        ),
        // LIVE pill (kama esstranfer.com)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _live ? const Color(0xFFDCFCE7) : _g100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _live ? const Color(0xFF16A34A) : _g300)),
            const SizedBox(width: 6),
            Text(_live ? 'Live' : 'Offline',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _live ? const Color(0xFF15803D) : _g500)),
          ]),
        ),
      ]),
    );
  }

  // ── Stats row — horizontal scroll cards ────────────────────────────────────
  Widget _buildStatsRow() {
    int active = 0, blocked = 0, admins = 0;
    for (final u in _users) {
      final st = '${(u as Map)['status'] ?? 'active'}'.toLowerCase();
      if (st == 'disabled') {
        blocked++;
      } else {
        active++;
      }
      if ((u['is_admin'] as bool? ?? false)) admins++;
    }
    Widget stat(String n, String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(n, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: c)),
          const SizedBox(height: 3),
          Text(l, style: const TextStyle(fontSize: 12, color: _g500),
              overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: [
          stat('${_loading ? '...' : _users.length}', 'Watumiaji wote', _g900),
          stat('$active', 'Hai', const Color(0xFF15803D)),
          stat('$blocked', 'Wamesitishwa', _red),
          stat('$admins', 'Admins', _blue),
          stat('${_departments.isEmpty ? '—' : _departments.length}', 'Idara', _blue700),
        ],
      ),
    );
  }

  // ── Toolbar — pills ndogo zenye icon + jina ────────────────────────────────
  Widget _buildToolbar() {
    Widget pill(IconData icon, String label, Color bg, Color fg,
        {Color? border, VoidCallback? onTap}) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: border != null ? Border.all(color: border) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ]),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // KITUFE CHIKUU — Ongeza Mtumiaji (kubwa, bluu, wazi)
          pill(PhosphorIcons.plus(PhosphorIconsStyle.bold), 'Mtumiaji Mpya', _blue, Colors.white,
              onTap: _showAdd),
          pill(PhosphorIcons.uploadSimple(), 'Import Excel', Colors.white, _g700,
              border: _g200, onTap: _showImport),
          pill(PhosphorIcons.shieldCheck(), 'Ongeza Admin', Colors.white, _g700,
              border: _g200, onTap: _showAddAdmin),
        ],
      ),
    );
  }

  // ── Search + funnel toggle ─────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                children: [
                  Icon(PhosphorIcons.magnifyingGlass(), size: 17, color: _g400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      style: const TextStyle(fontSize: 13.5, color: _g900),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        hintText: 'Tafuta kwa jina, simu au barua pepe...',
                        hintStyle: TextStyle(fontSize: 12.5, color: _g400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _showFilters ? _blueBg : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _showFilters ? _blue : _cardBorder),
              ),
              child: Icon(PhosphorIcons.funnelSimple(),
                  color: _showFilters ? _blue : _g500, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips — idara dynamic kutoka DB + location selects ──────────────
  Widget _buildFilterChips() {
    Widget chip(String label, bool active, VoidCallback onTap,
            {IconData? icon, Color? activeBg, Color? activeFg}) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: active ? (activeBg ?? _blue) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? (activeBg ?? _blue) : _cardBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: active ? (activeFg ?? Colors.white) : _g500),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(
                      color: active ? (activeFg ?? Colors.white) : _g600,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Idara chips — dynamic, zinawrap (zinaunganishwa)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('Zote', _category.isEmpty, () {
                setState(() { _category = ''; _page = 1; });
                _loadRefs(); _load();
              }),
              for (final d in _departments)
                chip(
                  '${d['display_name'] ?? d['name'] ?? d['code']}',
                  _category == '${d['code']}',
                  () {
                    setState(() { _category = '${d['code']}'; _page = 1; });
                    _loadRefs(); _load();
                  },
                  icon: _deptIcon('${d['code']}'),
                ),
            ],
          ),
        ),
        // Location selects
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Column(children: [
            Row(children: [
              Expanded(child: _selBtn(
                _regionName != null ? 'Mkoa: $_regionName' : 'Mkoa wote',
                _openRegionPicker,
                active: _regionId != null,
              )),
              const SizedBox(width: 8),
              Expanded(child: _selBtn(
                _districtName ?? 'Wilaya zote',
                _openDistrictPicker,
                active: _districtId != null,
                disabled: _regionId == null,
              )),
            ]),
            const SizedBox(height: 6),
            if (_subjects.isNotEmpty)
              _selBtn(
                _subjectName ?? 'Masomo yote',
                _openSubjectPicker,
                active: _subjectCode != null,
              )
            else
              _selBtn(
                _facilityName ?? 'Vituo vyote',
                _openFacilityPicker,
                active: _facilityId != null,
                disabled: _districtId == null,
              ),
          ]),
        ),
      ]),
    );
  }

  // ── Bulk bar — select-all + bulk actions ───────────────────────────────────
  Widget _buildBulkBar() {
    if (_selected.isEmpty) return const SizedBox.shrink();
    Widget bulkBtn(IconData icon, String label, Color fg, Color bg, Color border,
        VoidCallback? onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                  color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: Checkbox(
              value: _selectAll,
              onChanged: (_) => _toggleSelectAll(),
              activeColor: _blue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleSelectAll,
            child: Text('Chagua zote (${_selected.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _g700)),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          bulkBtn(
            PhosphorIcons.checkCircle(), 'Wezesha',
            _green700, _green50, const Color(0xFFBBF7D0), _bulkEnable,
          ),
          const SizedBox(width: 6),
          bulkBtn(
            PhosphorIcons.prohibit(), 'Sitisha',
            _org700, _org50, const Color(0xFFFED7AA), _bulkSuspend,
          ),
          const SizedBox(width: 6),
          bulkBtn(
            PhosphorIcons.trash(), 'Futa',
            _red, _red50, _red100, _bulkDelete,
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserCard — kadi fupi: safu MOJA ya action icons (kama design mpya)
// ─────────────────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool selected;
  final String deptName;
  final IconData deptIcon;
  final VoidCallback onToggle;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onSuspend;
  final VoidCallback onAdmin;
  final VoidCallback onDelete;
  final VoidCallback onContact;

  const _UserCard({
    required this.user,
    required this.selected,
    required this.deptName,
    required this.deptIcon,
    required this.onToggle,
    required this.onView,
    required this.onEdit,
    required this.onSuspend,
    required this.onAdmin,
    required this.onDelete,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final name    = user['full_name'] as String? ?? '';
    final phone   = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final cadre   = user['cadre_display'] as String? ?? user['cadre_code'] as String? ?? '';
    final station = user['current_station'] as Map? ?? user['station'] as Map? ?? {};
    final region  = station['region_name'] as String? ?? '';
    final st      = '${user['status'] ?? 'active'}'.toLowerCase();
    final isActive  = st == 'active';
    final isPaid    = (user['is_verified'] as bool?) ?? false;
    final contact   = (user['contact_enabled'] as bool?) ?? false;
    final isAdmin   = user['is_admin'] as bool? ?? false;
    final init      = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mstari 1: checkbox + avatar + jina + simu + hali + menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: Checkbox(
                    value: selected,
                    onChanged: isAdmin ? null : (_) => onToggle(),
                    activeColor: _blue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: _blueBg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(init, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _blue700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5, color: _g900)),
                      const SizedBox(height: 2),
                      if (phone.isNotEmpty)
                        Text(phone, style: const TextStyle(
                            fontSize: 12.5, color: _blue, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusTag(st),
                const SizedBox(width: 6),
                if (isAdmin)
                  Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      size: 15, color: _blue),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _showMoreMenu(context, isAdmin: isAdmin, contact: contact,
                      isActive: isActive, isPaid: isPaid),
                  child: Icon(PhosphorIcons.dotsThreeVertical(), color: _g500, size: 18),
                ),
              ],
            ),

            const SizedBox(height: 9),

            // Mstari 2: chips (kada, idara, mkoa) + malipo
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (cadre.isNotEmpty) _tag(cadre, PhosphorIcons.bookOpen(), _blueBg, _blue700),
              if (deptName.isNotEmpty)
                _tag(deptName, deptIcon, const Color(0xFFF0F2F7), _g600),
              if (region.isNotEmpty)
                _tag(region, PhosphorIcons.mapPin(), _g100, _g500),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFDCFCE7) : _red50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(isPaid ? 'Amelipa' : 'Hajalipa',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: isPaid ? const Color(0xFF15803D) : _red)),
              ),
            ]),

            const SizedBox(height: 10),

            // Mstari 3: vitufe vya haraka (safu moja ya icons)
            Row(children: [
              _sqBtn(PhosphorIcons.eye(), 'Angalia', _g100, _g700, onView),
              const SizedBox(width: 6),
              _sqBtn(PhosphorIcons.pencilSimple(), 'Hariri', _blueBg, _blue, onEdit),
              const SizedBox(width: 6),
              if (!isAdmin)
                _sqBtn(
                  isActive ? PhosphorIcons.prohibit() : PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                  isActive ? 'Funga' : 'Ruhusu',
                  isActive ? _amb100 : _green50,
                  isActive ? _amb600 : _green,
                  onSuspend,
                )
              else
                _sqBtn(PhosphorIcons.prohibit(), 'Ondoa Admin', _red50, _red, onAdmin),
              const SizedBox(width: 6),
              if (!isPaid)
                _sqBtn(
                  PhosphorIcons.phoneCall(),
                  'Ruhusu kupiga simu',
                  contact ? _green50 : _g100,
                  contact ? _green : _g600,
                  onContact,
                )
              else
                _sqBtn(PhosphorIcons.whatsappLogo(), 'WhatsApp', _green50, _green, () async {
                  try {
                    await launchUrl(Uri.parse('https://wa.me/$phone'),
                        mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }),
              const Spacer(),
              _sqBtn(PhosphorIcons.trash(), 'Futa', _red50, _red, onDelete),
            ]),
          ],
        ),
      ),
    );
  }
  void _showMoreMenu(BuildContext context,
      {required bool isAdmin, required bool contact, required bool isActive, required bool isPaid}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(isAdmin
                ? PhosphorIcons.prohibit()
                : PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                color: isAdmin ? _red : _blue, size: 20),
            title: Text(isAdmin ? 'Ondoa haki za Admin' : 'Fanya Admin',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(ctx); onAdmin(); },
          ),
          if (!isAdmin && !isPaid)
            ListTile(
              leading: Icon(PhosphorIcons.phoneCall(),
                  color: contact ? _red : _green, size: 20),
              title: Text(contact ? 'Ondoa haki ya kupiga simu' : 'Ruhusu kupiga simu',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(ctx); onContact(); },
            ),
          if (!isAdmin)
            ListTile(
              leading: Icon(
                  isActive ? PhosphorIcons.checkCircle() : PhosphorIcons.prohibit(),
                  color: isActive ? _green : _amb600, size: 20),
              title: Text(isActive ? 'Washa tena (Hai)' : 'Sitisha akaunti',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(ctx); onSuspend(); },
            ),
          ListTile(
            leading: Icon(PhosphorIcons.eye(), color: _g700, size: 20),
            title: const Text('Angalia maelezo kamili',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(ctx); onView(); },
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  Widget _tag(String label, IconData icon, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: fg),
      const SizedBox(width: 3),
      Flexible(child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _statusTag(String st) {
    final Color bg; final Color fg; final IconData icon; final String label;
    switch (st) {
      case 'matched':
        bg = _blue100; fg = _blue700; icon = PhosphorIcons.handshake(); label = 'Amepata mwenzake';
      case 'inactive':
        bg = _amb100;  fg = _amb700;  icon = PhosphorIcons.clock();       label = 'Hajakamilisha';
      case 'disabled':
        bg = _red50;   fg = _red;     icon = PhosphorIcons.prohibit();    label = 'Amesitishwa';
      default:
        bg = _green50; fg = _green;   icon = PhosphorIcons.checkCircle(); label = 'Hai';
    }
    return _tag(label, icon, bg, fg);
  }

  // Kitufe cha square (icon pekee) — ukubwa uleule kwa vitufe vyote
  Widget _sqBtn(IconData icon, String tooltip, Color bg, Color fg, VoidCallback? onTap) =>
      Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              width: 38, height: 38,
              child: Icon(icon, size: 17, color: fg),
            ),
          ),
        ),
      );
}
