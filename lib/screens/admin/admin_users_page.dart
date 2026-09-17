import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/select_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Color tokens (exact Tailwind hex, kama web)
// ─────────────────────────────────────────────────────────────────────────────
const _blue    = Color(0xFF1E40AF);   // brand-blue
const _blueBg  = Color(0xFFEFF6FF);   // blue-50
const _blue100 = Color(0xFFDBEAFE);   // blue-100
const _blue700 = Color(0xFF1D4ED8);   // blue-700
const _green50  = Color(0xFFF0FDF4);  // green-50
const _green    = Color(0xFF16A34A);  // green-600
const _green700 = Color(0xFF15803D);  // green-700
const _green100 = Color(0xFFDCFCE7);  // green-100
const _org50   = Color(0xFFFFF7ED);   // orange-50
const _org600  = Color(0xFFEA580C);   // orange-600
const _org700  = Color(0xFFC2410C);   // orange-700
const _amb100  = Color(0xFFFEF3C7);   // amber-100
const _amb600  = Color(0xFFD97706);   // amber-600
const _amb700  = Color(0xFFB45309);   // amber-700
const _red     = Color(0xFFDC2626);   // red-600
const _red50   = Color(0xFFFEF2F2);   // red-50
const _red100  = Color(0xFFFEE2E2);   // red-100
const _red400  = Color(0xFFF87171);   // red-400
const _emerald = Color(0xFF10B981);   // emerald-500
const _g900 = Color(0xFF111827);
const _g700 = Color(0xFF374151);
const _g600 = Color(0xFF4B5563);
const _g500 = Color(0xFF6B7280);
const _g400 = Color(0xFF9CA3AF);
const _g300 = Color(0xFFD1D5DB);
const _g200 = Color(0xFFE5E7EB);
const _g100 = Color(0xFFF3F4F6);

// ─────────────────────────────────────────────────────────────────────────────
// Web `input` class ≡ py-1.5 px-2.5 text-xs rounded-md border-grey-300
// ─────────────────────────────────────────────────────────────────────────────
const _kInputPad = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
const _kInputRadius = 6.0;   // rounded-md
const _kInputFs = 12.0;      // text-xs

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
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

  List<dynamic> _regions    = [];
  List<dynamic> _districts  = [];
  List<dynamic> _facilities = [];
  List<dynamic> _subjects   = [];

  Set<String> _selected = {};
  bool _selectAll = false;

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
      final lvl = _category == 'education' ? 'Primary' : 'Secondary';
      final r = await ApiService().getSubjects(level: lvl);
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

  // Inline message — exactly like web: bg-brand-blue-50 text-brand-blue text-sm rounded-lg p-3
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

  String get _catLabel =>
      _category == 'health' ? 'Afya' : _category == 'education' ? 'Elimu' : 'Idara';

  // ── Pickers ────────────────────────────────────────────────────────────────
  void _openCategoryPicker() {
    _showPicker<Map<String, String>>(
      title: 'Chagua Idara',
      items: const [
        {'label': 'Idara zote', 'value': ''},
        {'label': 'Afya',       'value': 'health'},
        {'label': 'Elimu',      'value': 'education'},
      ],
      current: _category,
      onPick: (v) {
        setState(() { _category = v; _page = 1; _subjects = []; });
        _loadRefs(); _load();
      },
      label: (i) => i['label']!, value: (i) => i['value']!,
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
                    child: const Icon(Icons.close_rounded, size: 16, color: _g700),
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
                  prefixIcon: const Icon(Icons.search_rounded, color: _g400, size: 18),
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
                        if (sel) const Icon(Icons.check_rounded, color: _blue, size: 18),
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

  // ── Import modal ───────────────────────────────────────────────────────────
  void _showImport() {
    String cat = 'education';
    bool busy = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _blueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.upload_file_rounded, color: _blue, size: 20)),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Import Watumiaji', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Pakia faili la Excel (.xlsx)', style: TextStyle(fontSize: 12, color: _g500)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(width: 30, height: 30,
                    decoration: const BoxDecoration(color: _g100, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 16, color: _g700)),
              ),
            ]),
            const SizedBox(height: 16),
            _lbl('CHAGUA IDARA YA FAILI'),
            Row(children: [
              _pill2('Elimu',    cat == 'education', _blue,  _blueBg,   () => ss(() => cat = 'education')),
              const SizedBox(width: 8),
              _pill2('Afya',     cat == 'health',    _red,   _red100,   () => ss(() => cat = 'health')),
              const SizedBox(width: 8),
              _pill2('Utumishi', cat == 'service',   _green, _green100, () => ss(() => cat = 'service')),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _blueBg, borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _blue),
                SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Safu za faili', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
                  SizedBox(height: 2),
                  Text('Jina Kamili · Simu · WhatsApp · Kada · Kiwango · Somo 1 · Somo 2 · Mkoa · Wilaya · Shule/Kituo · Mkoa wa Lengo 1',
                      style: TextStyle(fontSize: 11, color: _blue)),
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
                  : const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Chagua Faili la Excel', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Pakua Kiolezo (Excel)', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: _blue, side: const BorderSide(color: _blue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _handle(),
              const SizedBox(height: 16),
              _sheetHeader(ctx, Icons.person_add_rounded, 'Ongeza Mtumiaji',
                  'Jaza taarifa za mtumiaji mpya'),
              const SizedBox(height: 20),
              _lbl('Jina Kamili *'),
              _inp(nameCtrl, 'Jina kamili', icon: Icons.person_outline_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Simu'),
                  _inp(phoneCtrl, '+255...', keyboard: TextInputType.phone),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('WhatsApp'),
                  _inp(waCtrl, '+255...', keyboard: TextInputType.phone),
                ])),
              ]),
              const SizedBox(height: 12),
              _lbl('Nywila *'),
              _inp(passCtrl, '••••••', icon: Icons.lock_outline_rounded, obscure: true),
              const SizedBox(height: 12),
              _lbl('Idara *'),
              SelectField(
                hint: 'Chagua idara',
                value: catCode == null
                    ? null
                    : (catCode == 'health' ? 'Afya' : catCode == 'education' ? 'Elimu' : catCode),
                onTap: () async {
                  if (!ctx.mounted) return;
                  final picked = await showSelectSheet<String>(ctx,
                      title: 'Chagua Idara',
                      items: const [
                        (value: 'health',    label: 'Afya',     subtitle: null),
                        (value: 'education', label: 'Elimu',    subtitle: null),
                        (value: 'service',   label: 'Utumishi', subtitle: null),
                      ],
                      selected: catCode, searchable: false);
                  if (picked == null) return;
                  List<dynamic> list = [];
                  try {
                    final r = await ApiService().getCadres(category: picked);
                    final raw = r.data;
                    list = raw is List ? raw : (raw['cadres'] ?? raw['data'] ?? []);
                  } catch (_) {}
                  ss(() { catCode = picked; cadreCode = null; cadres = list; });
                },
                leading: const Icon(Icons.apartment_outlined, size: 15, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
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
                leading: const Icon(Icons.badge_outlined, size: 15, color: AppColors.textLight),
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
                leading: const Icon(Icons.map_outlined, size: 15, color: AppColors.textLight),
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
                leading: const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textLight),
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
                  const Icon(Icons.shield_outlined, size: 16, color: _blue),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.person_add_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Ongeza', style: TextStyle(fontWeight: FontWeight.w700)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _handle(),
              const SizedBox(height: 16),
              _sheetHeader(ctx, Icons.edit_rounded, 'Hariri Mtumiaji', null),
              const SizedBox(height: 20),
              _lbl('MAELEZO BINAFSI'),
              _inp(nameCtrl, 'Jina kamili', icon: Icons.person_outline_rounded),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Simu'),
                  _inp(phoneCtrl, '+255...', keyboard: TextInputType.phone),
                ])),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('WhatsApp'),
                  _inp(waCtrl, '+255...', keyboard: TextInputType.phone),
                ])),
              ]),
              const SizedBox(height: 12),
              _lbl('Nywila Mpya'),
              _inp(passCtrl, 'Acha tupu kama hubadilishi',
                  icon: Icons.lock_outline_rounded, obscure: true),
              const SizedBox(height: 16),
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
                leading: const Icon(Icons.toggle_on_outlined, size: 15, color: AppColors.textLight),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.save_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Hifadhi', style: TextStyle(fontWeight: FontWeight.w700)),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _handle(),
              const SizedBox(height: 16),
              _sheetHeader(ctx, Icons.admin_panel_settings_rounded, 'Ongeza Admin', null),
              const SizedBox(height: 20),
              _lbl('Jina Kamili'),
              _inp(nameCtrl,  'Jina kamili',    icon: Icons.person_outline_rounded),
              const SizedBox(height: 10),
              _lbl('Barua Pepe'),
              _inp(emailCtrl, 'admin@mfumo.tz', icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _lbl('Simu'),
              _inp(phoneCtrl, '+255...',         icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _lbl('Nenosiri'),
              _inp(passCtrl,  '••••••',          icon: Icons.lock_outline_rounded, obscure: true),
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
                    : const Icon(Icons.admin_panel_settings_rounded, size: 16),
                label: const Text('Ongeza Admin', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
    final catLabel = category == 'health' ? 'Afya' : category == 'education' ? 'Elimu' : category;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, maxChildSize: 0.9, initialChildSize: 0.75,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(2)))),
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
                if (isPaid) _chip2('Amelipa', _green, _green100)
                else _chip2('Hajalipa', _red, _red100),
                if (isAdmin) _chip2('Admin', _blue, _blueBg),
              ]),
            ])),
            const SizedBox(height: 20),
            _infoRow('Simu',   phone.isNotEmpty ? phone : '—', vc: _blue),
            if (wa.isNotEmpty) _infoRow('WhatsApp', wa, vc: _green),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Funga'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); _showEdit(u); },
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Hariri', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _blue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Sheet helpers ──────────────────────────────────────────────────────────
  Widget _handle() => Center(child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(color: _g200, borderRadius: BorderRadius.circular(2))));

  Widget _sheetHeader(BuildContext ctx, IconData icon, String title, String? sub) =>
      Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: _blueBg, borderRadius: BorderRadius.circular(10)),
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
              child: const Icon(Icons.close_rounded, size: 16, color: _g700)),
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
          prefixIcon: icon != null ? Icon(icon, size: 18, color: _g400) : null,
          fillColor: Colors.white, filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _g200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _g200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _blue, width: 1.5)),
        ),
      );

  Widget _pill2(String label, bool active, Color fg, Color bg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? bg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? fg : _g200),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 13, color: active ? fg : _g700,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ),
      );

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

  // ── Header button (top-right 4 buttons) ───────────────────────────────────
  // Web: inline-flex items-center gap-1 text-[11px] px-2.5 py-1.5 rounded-lg font-semibold
  Widget _hdrBtn(IconData icon, String label, Color fg, Color bg, Color border, VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ── Bulk action button ─────────────────────────────────────────────────────
  // Web: flex-1 inline-flex items-center justify-center gap-1 text-[11px] py-1.5 rounded-lg
  Widget _bulkBtn(IconData icon, String label, Color fg, Color bg, Color border,
      VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
                color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 11, color: fg),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  // ── Filter select — matches web `input` class appearance ──────────────────
  // Web: <select className="input w-full"> → py-1.5 px-2.5 text-xs rounded-md border-grey-300
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
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 15, color: active ? _blue : _g500),
            ]),
          ),
        ),
      );

  // ── Pagination button ──────────────────────────────────────────────────────
  // Web: min-w-[44px] min-h-[44px] px-3 rounded-xl border-grey-200 text-sm font-semibold
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
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _blue,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ─────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),
              // ── Bulk bar ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildBulkBar()),
              // ── Inline message — web: bg-brand-blue-50 text-brand-blue text-sm rounded-lg p-3
              if (_message != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _blueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_message!,
                          style: const TextStyle(fontSize: 14, color: _blue)),
                    ),
                  ),
                ),
              // ── Filters ────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildFilters()),
              // ── Count — web: text-xs text-brand-grey-500, space-y-4 from filters
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                    const Icon(Icons.wifi_off_rounded, color: _g400, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: _g500, fontSize: 12),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Jaribu tena'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _blue, foregroundColor: Colors.white),
                    ),
                  ])),
                )
              else if (_users.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.group_off_outlined, color: _g400, size: 52),
                    SizedBox(height: 12),
                    Text('Hakuna watumiaji walioonekana',
                        style: TextStyle(color: _g500, fontSize: 14)),
                  ])),
                )
              else ...[
                // Cards — bg-white rounded-2xl border border-grey-100 overflow-hidden
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _g100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (int i = 0; i < items.length; i++)
                            _UserCard(
                              user:      items[i] as Map<String, dynamic>,
                              selected:  _selected.contains(_uid(items[i])),
                              isLast:    i == items.length - 1,
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
                        ],
                      ),
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

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title + live text
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Watumiaji',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _g900)),
                const SizedBox(width: 8),
                Text('● Live',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: _live ? const Color(0xFF22C55E) : _g300,
                    )),
              ]),
              Text('${_loading ? '...' : _users.length} watumiaji wote',
                  style: const TextStyle(fontSize: 12, color: _g500)),
            ]),
          ),
          const SizedBox(width: 8),
          // Flex-wrap buttons: Trash, + Ongeza, Admin, Import
          Wrap(
            spacing: 6, runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              _hdrBtn(Icons.delete_outline_rounded, 'Trash', _red, _red50, _red100, () {
                _snack('Orodha ya waliofutwa haijatekelezwa bado', _g700);
              }),
              _hdrBtn(Icons.person_add_rounded, '+ Ongeza', Colors.white, _blue, _blue, _showAdd),
              _hdrBtn(Icons.shield_outlined, 'Admin', _g700, Colors.white, _g200, _showAddAdmin),
              _hdrBtn(Icons.upload_file_rounded, 'Import', _g700, Colors.white, _g200, _showImport),
            ],
          ),
        ]),
        const SizedBox(height: 12),
      ]),
    );
  }

  // ── Bulk bar — select-all + count + bulk action buttons ───────────────────
  Widget _buildBulkBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Chagua zote  ·  Jumla N
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
          Text('Jumla ${_loading ? '...' : _users.length}',
              style: const TextStyle(fontSize: 12, color: _g500)),
        ]),
        // Bulk action buttons — only visible when something is selected
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _bulkBtn(
              Icons.check_circle_outline_rounded, 'Wezesha',
              _green700, _green50, const Color(0xFFBBF7D0), _bulkEnable,
            )),
            const SizedBox(width: 6),
            Expanded(child: _bulkBtn(
              Icons.block_rounded, 'Sitisha',
              _org700, _org50, const Color(0xFFFED7AA), _bulkSuspend,
            )),
            const SizedBox(width: 6),
            Expanded(child: _bulkBtn(
              Icons.delete_outline_rounded, 'Futa',
              _red, _red50, const Color(0xFFFECACA), _bulkDelete,
            )),
          ]),
        ],
      ]),
    );
  }

  // ── Filters — vertical stack kama web ──────────────────────────────────────
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Row: search + idara/category
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              style: const TextStyle(fontSize: _kInputFs, color: _g900),
              decoration: InputDecoration(
                hintText: 'Tafuta kwa jina, simu au...',
                hintStyle: const TextStyle(color: _g400, fontSize: _kInputFs),
                prefixIcon: const Icon(Icons.search_rounded, color: _g400, size: 18),
                fillColor: Colors.white, filled: true,
                isDense: true,
                contentPadding: _kInputPad,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kInputRadius),
                    borderSide: const BorderSide(color: _g300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kInputRadius),
                    borderSide: const BorderSide(color: _g300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_kInputRadius),
                    borderSide: const BorderSide(color: _blue, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _selBtn(_catLabel, _openCategoryPicker, active: _category.isNotEmpty),
        ]),
        const SizedBox(height: 6),
        // Mkoa — full width
        _selBtn(
          _regionName != null ? 'Mkoa: $_regionName' : 'Mkoa wote',
          _openRegionPicker,
          active: _regionId != null,
        ),
        const SizedBox(height: 6),
        // Wilaya — full width
        _selBtn(
          _districtName ?? 'Wilaya zote',
          _openDistrictPicker,
          active: _districtId != null,
          disabled: _regionId == null,
        ),
        const SizedBox(height: 6),
        // Vituo au Masomo — full width
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserCard — mobile card (md:hidden) — exact match ya web
// ─────────────────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool selected;
  final bool isLast;
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
    required this.isLast,
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
    final cadre   = user['cadre_code'] as String? ?? user['cadre_display'] as String? ?? '';
    final station = user['current_station'] as Map? ?? user['station'] as Map? ?? {};
    final region  = station['region_name'] as String? ?? '';
    final st      = '${user['status'] ?? 'active'}'.toLowerCase();
    final isActive  = st == 'active';
    final isPaid    = (user['is_verified'] as bool?) ?? false;
    final contact   = (user['contact_enabled'] as bool?) ?? false;
    final isAdmin   = user['is_admin'] as bool? ?? false;
    final init      = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // opacity-60 kama web wakati user amesitishwa
    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Container(
        // border-b border-grey-100 last:border-0
        decoration: BoxDecoration(
            border: isLast ? null : const Border(bottom: BorderSide(color: _g100))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Row 1: flex items-center gap-2.5 px-3 pt-3 pb-1.5 ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(children: [
              // w-4 h-4 checkbox — disabled kwa admin
              SizedBox(
                width: 16, height: 16,
                child: Checkbox(
                  value: selected,
                  onChanged: isAdmin ? null : (_) => onToggle(),
                  activeColor: _blue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(width: 10),
              // w-9 h-9 rounded-full bg-blue-50 border-blue-100 text-sm font-bold text-blue-700
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: _blueBg, shape: BoxShape.circle,
                    border: Border.all(color: _blue100)),
                alignment: Alignment.center,
                child: Text(init, style: const TextStyle(
                    fontSize: 14, height: 10 / 7, fontWeight: FontWeight.w700, color: _blue700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // font-bold text-sm + ShieldCheck(13) for admin
                  Row(children: [
                    Expanded(child: Text(name,
                        style: const TextStyle(
                            fontSize: 14, height: 10 / 7, fontWeight: FontWeight.w700, color: _g900),
                        overflow: TextOverflow.ellipsis)),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_user_rounded, size: 13, color: _blue),
                    ],
                  ]),
                  // tel: link — text-xs text-brand-blue font-semibold
                  if (phone.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        try {
                          await launchUrl(Uri.parse('tel:$phone'),
                              mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      },
                      child: Text(phone, style: const TextStyle(
                          fontSize: 12, height: 4 / 3, color: _blue, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
              const SizedBox(width: 10),
              // Malipo badge — text-[10px] font-bold text-white bg-emerald-500/red-400 rounded-full
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: isPaid ? _emerald : _red400,
                    borderRadius: BorderRadius.circular(100)),
                child: Text(isPaid ? '✓' : '✗',
                    style: const TextStyle(
                        fontSize: 10, height: 1.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
          ),

          // ── Row 2: flex flex-wrap items-center gap-1.5 px-3 pb-2 ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              // Kada — bg-blue-50 text-blue-700 BookOpen(10)
              if (cadre.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: _blueBg, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.menu_book_rounded, size: 10, color: _blue700),
                    const SizedBox(width: 4),
                    Text(cadre, style: const TextStyle(
                        fontSize: 11, height: 1.5, color: _blue700, fontWeight: FontWeight.w600)),
                  ]),
                ),
              // Region — text-[11px] text-grey-500
              if (region.isNotEmpty)
                Text(region, style: const TextStyle(fontSize: 11, height: 1.5, color: _g500)),
              // Status badge — 4 hali
              _statusBadge(st),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: isAdmin ? _amb100 : _g100,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(isAdmin ? 'Admin' : 'Mtumiaji', style: TextStyle(
                    fontSize: 10, height: 1.5, fontWeight: FontWeight.w600,
                    color: isAdmin ? _amb700 : _g500)),
              ),
            ]),
          ),

          // ── Action grid — large rounded buttons kama web (grid 2×N) ──────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(children: [
              Row(children: [
                Expanded(child: _aBtn(Icons.visibility_rounded, 'Angalia', _g700, _g100, onView)),
                const SizedBox(width: 8),
                Expanded(child: _aBtn(Icons.edit_rounded, 'Hariri', _blue, _blueBg, onEdit)),
              ]),
              if (!isAdmin) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _aBtn(
                    isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                    isActive ? 'Funga' : 'Fungua', _org600, _org50, onSuspend)),
                  if (!isPaid) ...[
                    const SizedBox(width: 8),
                    Expanded(child: _aBtn(
                      Icons.phone_rounded,
                      contact ? 'Ameruhusu' : 'Ruhusu',
                      contact ? _green700 : _g600,
                      contact ? _green50 : _g100, onContact)),
                  ],
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity,
                    child: _aBtn(Icons.delete_outline_rounded, 'Futa', _red, _red50, onDelete)),
              ] else ...[
                const SizedBox(height: 8),
                SizedBox(width: double.infinity,
                    child: _aBtn(Icons.shield_outlined, 'Ondoa Admin', _red, _red50, onAdmin)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _statusBadge(String st) {
    final Color bg; final Color fg; final IconData icon; final String label;
    switch (st) {
      case 'matched':
        bg = _blue100; fg = _blue700; icon = Icons.handshake_outlined; label = 'Amepata mwenzake';
      case 'inactive':
        bg = _amb100;  fg = _amb700;  icon = Icons.hourglass_empty_rounded; label = 'Hajakamilisha';
      case 'disabled':
        bg = _red50;   fg = _red;     icon = Icons.person_remove_rounded;   label = 'Amesitishwa';
      default:
        bg = _green50; fg = _green;   icon = Icons.how_to_reg_rounded;      label = 'Hai';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: fg),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 10, height: 1.5, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }

  // Large action button — icon + label wima, rounded-2xl kama web
  Widget _aBtn(IconData icon, String label, Color fg, Color bg, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
      );
}
