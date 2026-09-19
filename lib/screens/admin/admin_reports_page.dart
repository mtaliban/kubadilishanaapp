// Statistics — redesign kama reference mpya:
//  - Background grey (#F6F7F9), kadi white zenye border
//  - Live badge ya kijani + subtitle "real-time"
//  - Filter CHIPS (Mkoa/Idara/Ngazi) na icons — picker sheets zenye search
//  - KPI GRID yenye icons (Watumiaji waliopo +N wiki 7, Imethibitishwa,
//    Mikoa yote, Wilaya zote, Wanaohamia wote)
//  - Kwa idara / Walimu kwa ngazi → progress bars (%)
//  - Kwa kada → ranked list (1,2,3…)
//  - Kwa hali → progress bar
//  - Waliopo na wanaohamia kwa mkoa → # | Mkoa | Waliopo | Wanaohamia + bar
//  - Wanaohamia wanatoka wapi → # | Kutoka → Kwenda | hesabu
//  - Watu kwa wilaya → jedwali (Wilaya/Waliopo/Hamia/Jumla)
//  - Matukio ya hivi karibuni
//  - Tab ya Watumiaji: search + orodha (Jina/Simu/Mkoa/Hali)
//  - Data yote halisi kutoka API (adminStats + adminReports + adminUsers)

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF185FA5);
const _kBlueSel = Color(0xFF378ADD);
const _kBlueBg  = Color(0xFFE6F1FB);
const _kGreen   = Color(0xFF1D9E75);
const _kGreenBg = Color(0xFFE6F6EC);
const _kGreenTx = Color(0xFF0F6E56);
const _kOrangeTx = Color(0xFFBA7517);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFCEBEB);
const _kRedTx   = Color(0xFF791F1F);
const _kPageBg  = Color(0xFFF6F7F9);
const _kBorder  = Color(0xFFE7E7E5);
const _kBarBg   = Color(0xFFF0F0EE);
const _kT900    = Color(0xFF1F2937);
const _kT600    = Color(0xFF4B5563);
const _kT500    = Color(0xFF6B7280);
const _kT400    = Color(0xFF9CA3AF);
const _kT300    = Color(0xFFD1D5DB);

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _stats = {};
  List<dynamic> _events = [];
  String _tab = 'overview';

  // Filters — label inaonekana kwenye chips
  String? _region;
  String? _regionId;
  String? _category;
  String _categoryName = '';
  String _level = '';

  List<dynamic> _regions = [];
  List<dynamic> _departments = [];

  // Users tab
  final _usersCtrl = TextEditingController();
  List<dynamic> _users = [];
  int _usersTotal = 0;
  bool _usersLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
    _loadUsers();
  }

  @override
  void dispose() {
    _usersCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRefs() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _regions = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []));
    } catch (_) {}
    try {
      final r = await ApiService().adminListDepartments();
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []);
      setState(() => _departments = list
          .where((d) => '${d['is_active'] ?? d['active'] ?? true}' != 'false')
          .toList());
    } catch (_) {}
  }

  Future<void> _load({bool refresh = false}) async {
    final firstLoad = _data.isEmpty;
    setState(() { if (firstLoad) _loading = true; _error = null; });
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      setState(() => _stats = (r.data as Map<String, dynamic>?) ?? {});
    } catch (_) {}
    try {
      final r = await ApiService().adminEvents(limit: 20);
      if (!mounted) return;
      final d = r.data;
      List raw = [];
      if (d is List) {
        raw = d;
      } else if (d is Map) {
        raw = (d['events'] as List?) ?? [];
      }
      setState(() => _events = raw.where((e) {
        final m = e as Map;
        final type = (m['event_type'] ?? m['type'] ?? '') as String;
        return !['user.presence', 'user.online', 'user.offline',
                 'user.connected', 'user.disconnected'].contains(type);
      }).take(8).toList());
    } catch (_) {}
    try {
      final res = await ApiService().adminReports(
        days: 365,
        region: _region,
        category: _category,
        level: _level,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() { _data = (res.data as Map<String, dynamic>?) ?? {}; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); if (firstLoad) _loading = false; });
    }
  }

  Future<void> _loadUsers({String q = ''}) async {
    setState(() => _usersLoading = true);
    try {
      final r = await ApiService().adminUsers(
          params: {if (q.isNotEmpty) 'q': q, 'limit': 100}, useCache: false);
      if (!mounted) return;
      final d = r.data as Map? ?? {};
      setState(() {
        _users = (d['users'] as List?) ?? [];
        _usersTotal = (d['total'] as num?)?.toInt() ?? _users.length;
        _usersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  // ── Pickers (bottom sheet + search, kama reference) ────────────────────────
  Future<void> _pickRegion() async {
    final inData = <String>{
      for (final r in _list('users_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
      for (final r in _list('incoming_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
    }.toList()..sort();
    final source = inData.isNotEmpty
        ? inData.map((n) => {'name': n}).toList()
        : _regions;
    final items = <_PickerItem>[
      _PickerItem('Mkoa wote', 'Onyesha mikoa yote', '__all__', _regionId == null || _regionId!.isEmpty),
      for (final r in source)
        _PickerItem(
          '${r['name'] ?? r['region_name'] ?? ''}',
          null,
          '${r['id'] ?? r['region_id'] ?? r['name']}',
          '${r['id'] ?? r['region_id'] ?? r['name']}' == (_regionId ?? ''),
        ),
    ];
    final picked = await _showPickerSheet('Chagua mkoa', items, _regionId == null || _regionId!.isEmpty);
    if (picked == null || !mounted) return;
    final r = source.firstWhere(
        (x) => '${x['id'] ?? x['region_id'] ?? x['name']}' == picked, orElse: () => null);
    setState(() {
      _regionId = picked == '__all__' ? null : picked;
      _region = picked == '__all__' ? null : '${r?['name'] ?? r?['region_name'] ?? ''}';
    });
    _load();
  }

  Future<void> _pickCategory() async {
    final items = <_PickerItem>[
      const _PickerItem('Idara zote', 'Onyesha idara zote', '__all__', true),
      for (final d in _departments)
        _PickerItem(
          '${d['name'] ?? d['display_name'] ?? d['code']}',
          null,
          '${d['code']}',
          _category == '${d['code']}',
        ),
    ];
    final picked = await _showPickerSheet('Chagua idara', items, _category == null);
    if (picked == null || !mounted) return;
    final d = _departments.firstWhere(
        (x) => '${x['code']}' == picked, orElse: () => null);
    setState(() {
      _category = picked == '__all__' ? null : picked;
      _categoryName = picked == '__all__' ? '' : '${d?['name'] ?? d?['display_name'] ?? picked}';
    });
    _load();
  }

  Future<void> _pickLevel() async {
    final items = <_PickerItem>[
      const _PickerItem('Ngazi zote', 'Primary na Secondary', '', true),
      const _PickerItem('Primary (Msingi)', null, 'Primary', false),
      const _PickerItem('Secondary (Sekondari)', null, 'Secondary', false),
    ];
    final picked = await _showPickerSheet('Chagua ngazi', items, _level.isEmpty);
    if (picked == null || !mounted) return;
    setState(() => _level = picked);
    _load();
  }

  Future<String?> _showPickerSheet(String title, List<_PickerItem> items, bool allSelected) {
    final ctrl = TextEditingController();
    List<_PickerItem> filtered = List.from(items);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 6),
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _kT300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _kT900)),
                IconButton(
                  icon: Icon(PhosphorIcons.x(), size: 18, color: _kT500),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: ctrl,
                onChanged: (q) {
                  final ql = q.toLowerCase();
                  ss(() => filtered = items.where((i) => i.label.toLowerCase().contains(ql)).toList());
                },
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18, color: _kT400),
                  filled: true,
                  fillColor: _kPageBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final item in filtered)
                    _pickerTile(item.label, item.sub,
                        (item.value == '__all__' || item.value == '') ? allSelected : item.selected,
                        () => Navigator.pop(ctx, item.value)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pickerTile(String label, String? sub, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _kBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: _kBlueSel) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? _kBlue : _kT900,
                      )),
                  if (sub != null)
                    Text(sub, style: const TextStyle(fontSize: 12, color: _kT400)),
                ],
              ),
            ),
            if (selected) Icon(PhosphorIcons.check(), color: _kBlue, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Data helpers ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _list(String key) =>
      ((_data[key] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  int _int(String key) => (_data[key] as num?)?.toInt() ?? 0;

  int get _reportUsersTotal =>
      _list('users_by_region').fold(0, (s, r) => s + ((r['count'] as num?)?.toInt() ?? 0));

  List<({String region, int current, int incoming})> get _byRegion {
    final cur = _list('users_by_region');
    final inc = _list('incoming_by_region');
    final names = <String>{
      for (final r in cur) '${r['region'] ?? ''}',
      for (final r in inc) '${r['region'] ?? ''}',
    }..removeWhere((n) => n.isEmpty);
    final out = names.map((n) => (
      region: n,
      current: (cur.firstWhere((r) => '${r['region']}' == n, orElse: () => {})['count'] as num?)?.toInt() ?? 0,
      incoming: (inc.firstWhere((r) => '${r['region']}' == n, orElse: () => {})['count'] as num?)?.toInt() ?? 0,
    )).toList()
      ..sort((a, b) => (b.current + b.incoming).compareTo(a.current + a.incoming));
    return out;
  }

  List<({String region, int current, int incoming})> _byDistrict() {
    final byDist = _list('users_by_district');
    final inDist = _list('incoming_by_district');
    final rows = byDist.take(50).map((d) {
      final label = '${d['district'] ?? '—'}'
          '${(_region == null || _region!.isEmpty) && (d['region'] ?? '').toString().isNotEmpty ? ' · ${d['region']}' : ''}';
      final inc = (inDist.firstWhere(
        (x) => '${x['district']}' == '${d['district']}', orElse: () => {},
      )['count'] as num?)?.toInt() ?? 0;
      return (region: label, current: (d['count'] as num?)?.toInt() ?? 0, incoming: inc);
    }).toList()
      ..sort((a, b) => (b.current + b.incoming).compareTo(a.current + a.incoming));
    return rows;
  }

  String _deptLabel(String code) {
    final d = _departments.firstWhere((x) => '${x['code']}' == code, orElse: () => null);
    return d == null ? code : '${d['name'] ?? code}';
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active': return 'Hai (active)';
      case 'disabled': return 'Imesitishwa';
      case 'pending': return 'Inasubiri uthibitisho';
      case 'suspended': return 'Imesitishwa';
      default: return s.isEmpty ? 'Unknown' : s;
    }
  }

  static String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totals = _stats['totals'] as Map<String, dynamic>? ?? {};
    return Container(
      color: _kPageBg,
      child: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: _kBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else ...[
              SliverToBoxAdapter(child: _tab == 'users'
                  ? _usersTab()
                  : _overviewBody(totals)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Overview body (live row + chips + KPI grid + sections) ─────────────
  Widget _overviewBody(Map<String, dynamic> totals) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null) _errorBanner(),
        _liveRow(),
        const SizedBox(height: 12),
        _filterChips(),
        const SizedBox(height: 14),
        _kpiGrid(totals),
        const SizedBox(height: 14),
        ..._overviewSections(totals),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── Header (Statistics + subtitle) ────────────────────────────────────────
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Statistics',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _kT900)),
        const SizedBox(height: 2),
        const Text('Takwimu za mfumo mzima — mikoa, idara, kada (real-time)',
            style: TextStyle(fontSize: 12.5, color: _kT500)),
        const SizedBox(height: 10),
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder))),
          child: Row(children: [
            for (final (idx, (lbl, key)) in [('Statistics', 'overview'), ('Watumiaji', 'users')].indexed) ...[
              if (idx > 0) const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _tab = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == key ? _kBlue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(lbl,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _tab == key ? _kBlue : _kT500,
                      )),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  // ── Live row (kama reference: subtitle + green Live pill) ─────────────────
  Widget _liveRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text('Takwimu za mfumo mzima — real-time',
              style: TextStyle(fontSize: 13, color: _kT500)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kGreenBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIcons.circle(PhosphorIconsStyle.fill),
                size: 8, color: _kGreen),
            const SizedBox(width: 4),
            const Text('Live',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGreenTx)),
          ]),
        ),
      ],
    );
  }

  // ── Filter chips (Mkoa / Idara / Ngazi) — kama reference ──────────────────
  Widget _filterChips() {
    Widget chip(IconData icon, String label, bool active, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? _kBlueBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _kBlueSel : _kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: active ? _kBlue : _kT500),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                fontSize: 13, color: active ? _kBlue : _kT900,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
            const SizedBox(width: 4),
            Icon(PhosphorIcons.caretDown(), size: 13, color: active ? _kBlue : _kT400),
          ]),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip(PhosphorIcons.mapPin(),
            _region == null || _region!.isEmpty ? 'Mkoa wote' : _region!,
            _regionId != null, _pickRegion),
        const SizedBox(width: 8),
        chip(PhosphorIcons.buildings(),
            _category == null ? 'Idara zote' : _categoryName,
            _category != null, _pickCategory),
        const SizedBox(width: 8),
        chip(PhosphorIcons.graduationCap(),
            _level.isEmpty ? 'Ngazi zote' : _level,
            _level.isNotEmpty, _pickLevel),
      ]),
    );
  }

  // ── KPI GRID yenye icons (2 kwa safu) ─────────────────────────────────────
  Widget _kpiGrid(Map<String, dynamic> totals) {
    final incomingTotal = _list('incoming_by_region')
        .fold<int>(0, (s, r) => s + ((r['count'] as num?)?.toInt() ?? 0));
    final items = [
      _KpiItem(PhosphorIcons.users(), 'Watumiaji waliopo',
          '${_reportUsersTotal >= 1000 ? _thousands(_reportUsersTotal) : _reportUsersTotal}',
          '+${totals['users_active_7d'] ?? 0} wiki 7', _kGreen),
      _KpiItem(PhosphorIcons.shieldCheck(), 'Imethibitishwa',
          '${totals['users_verified'] ?? '—'}', null, null),
      _KpiItem(PhosphorIcons.mapPin(), 'Mikoa yote',
          '${_int('regions_total')}', null, null),
      _KpiItem(PhosphorIcons.mapTrifold(), 'Wilaya zote',
          '${_int('districts_total')}', null, null),
      _KpiItem(PhosphorIcons.arrowsLeftRight(), 'Wanaohamia wote',
          '${incomingTotal >= 1000 ? _thousands(incomingTotal) : incomingTotal}', null, null),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 18, color: _kBlue),
              const Spacer(),
              Text(item.value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: _kT900)),
              Text(item.label, style: const TextStyle(fontSize: 12, color: _kT500)),
              if (item.sub != null) ...[
                const SizedBox(height: 2),
                Text(item.sub!,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _kGreen)),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Overview sections ─────────────────────────────────────────────────────
  List<Widget> _overviewSections(Map<String, dynamic> totals) {
    final byCadreAll = _list('users_by_cadre');
    final priCount = byCadreAll
        .where((c) => (c['level'] ?? '') == 'Primary')
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));
    final secCount = byCadreAll
        .where((c) => (c['level'] ?? '') == 'Secondary')
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));
    final noneCount = byCadreAll
        .where((c) => (c['level'] ?? '').toString().isEmpty)
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));

    final byDept = _list('users_by_category')
        ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
            .compareTo((a['count'] as num?)?.toInt() ?? 0));
    final byStatus = _list('users_by_status')
        ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
            .compareTo((a['count'] as num?)?.toInt() ?? 0));
    final byCadre = (byCadreAll.toList()
          ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
              .compareTo((a['count'] as num?)?.toInt() ?? 0)));

    return [
      // ── Kwa idara — progress bars ──
      _card('Kwa idara', child: _progressList([
        for (final c in byDept)
          (
            '${c['name'] ?? _deptLabel('${c['category']}')}',
            (c['count'] as num?)?.toInt() ?? 0,
          ),
      ])),

      // ── Walimu kwa ngazi — progress bars ──
      _card('Walimu kwa ngazi', child: _progressList([
        ('Walimu wa Msingi', priCount),
        ('Walimu wa Sekondari', secCount),
        if (noneCount > 0) ('Hakuna ngazi', noneCount),
      ])),

      // ── Kwa kada — ranked list ──
      _card('Kwa kada', child: _rankedList([
        for (final c in byCadre.take(20))
          (
            '${c['cadre_name'] ?? c['cadre']}${(c['level'] ?? '').toString().isEmpty ? '' : ' (${c['level']})'}',
            (c['count'] as num?)?.toInt() ?? 0,
          ),
      ])),

      // ── Kwa hali — progress bars ──
      _card('Kwa hali', child: _progressList([
        for (final s in byStatus)
          (_statusLabel('${s['status']}'), (s['count'] as num?)?.toInt() ?? 0),
      ])),

      // ── Waliopo na wanaohamia kwa mkoa ──
      _card('Waliopo na wanaohamia kwa mkoa',
          child: _mkoaMigrationList(_byRegion.take(30).toList())),

      // ── Wanaohamia wanatoka wapi ──
      if (_list('incoming_sources').isNotEmpty)
        _card(
          'Wanaohamia wanatoka wapi${_region != null && _region!.isNotEmpty ? ' — $_region' : ''}',
          child: _migrationFlowTable(_list('incoming_sources').take(15).toList()),
        ),

      // ── Watu kwa wilaya ──
      _card(
        'Watu kwa wilaya${_region != null && _region!.isNotEmpty ? ' — $_region' : ''}',
        child: _wilayaTable(_byDistrict().take(20).toList()),
      ),

      // ── Matukio ya hivi karibuni ──
      _eventsCard(),
    ];
  }

  // ── Progress list (kama reference: label + hesabu + blue bar) ─────────────
  Widget _progressList(List<(String, int)> data) {
    if (data.isEmpty) return _empty();
    final total = data.fold<int>(0, (s, d) => s + d.$2);
    return Column(
      children: data.map((d) {
        final pct = total > 0 ? (d.$2 / total * 100).round() : 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(d.$1, style: const TextStyle(fontSize: 13, color: _kT900))),
                  Text('${d.$2 >= 1000 ? _thousands(d.$2) : d.$2}  ·  $pct%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kT900)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  backgroundColor: _kBarBg,
                  valueColor: const AlwaysStoppedAnimation(_kBlueSel),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Ranked list (1,2,3…) kama reference ───────────────────────────────────
  Widget _rankedList(List<(String, int)> data) {
    if (data.isEmpty) return _empty();
    return Column(
      children: List.generate(data.length, (i) {
        final d = data[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 12, color: _kT400)),
              ),
              Expanded(
                child: Text(d.$1,
                    style: const TextStyle(fontSize: 13, color: _kT900),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(d.$2 >= 1000 ? _thousands(d.$2) : '${d.$2}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kT900)),
            ],
          ),
        );
      }),
    );
  }

  // ── Mkoa migration list (# | Mkoa | Waliopo | Wanaohamia + bar) ───────────
  Widget _mkoaMigrationList(List<({String region, int current, int incoming})> data) {
    if (data.isEmpty) return _empty();
    final maxIncoming = data.map((e) => e.incoming).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        // header
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const SizedBox(width: 22),
            const Expanded(flex: 3, child: Text('MKOA',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kT400))),
            const Expanded(flex: 2, child: Text('WALIOPO',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kT400))),
            const SizedBox(width: 10),
            const Expanded(flex: 5, child: Text('WANAOHAMIA',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kT400))),
          ]),
        ),
        for (final (i, m) in data.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 12, color: _kT400)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(m.region,
                      style: const TextStyle(fontSize: 13, color: _kT900),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${m.current}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, color: _kT900)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Text('${m.incoming}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _kOrangeTx)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: maxIncoming > 0 ? m.incoming / maxIncoming : 0,
                            minHeight: 6,
                            backgroundColor: _kBarBg,
                            valueColor: const AlwaysStoppedAnimation(_kBlueSel),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Migration flow (# | Kutoka → Kwenda | hesabu) ─────────────────────────
  Widget _migrationFlowTable(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return _empty();
    return Column(
      children: List.generate(data.length, (i) {
        final f = data[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 12, color: _kT400)),
              ),
              Expanded(
                  child: Text('${f['from']}',
                      style: const TextStyle(fontSize: 13, color: _kT900),
                      overflow: TextOverflow.ellipsis)),
              Icon(PhosphorIcons.arrowRight(), size: 14, color: _kT400),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${f['to']}',
                    style: const TextStyle(fontSize: 13, color: _kOrangeTx),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${f['count'] ?? 0}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kT900)),
            ],
          ),
        );
      }),
    );
  }

  // ── Wilaya table (Wilaya / Waliopo / Hamia / Jumla) ───────────────────────
  Widget _wilayaTable(List<({String region, int current, int incoming})> data) {
    if (data.isEmpty) return _empty();
    const hs = TextStyle(
        fontSize: 12, color: _kT500);
    return Column(
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.5),
          },
          children: [
            const TableRow(children: [
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Wilaya', style: hs)),
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Waliopo', textAlign: TextAlign.right, style: hs)),
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Hamia', textAlign: TextAlign.right, style: hs)),
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Jumla', textAlign: TextAlign.right, style: hs)),
            ]),
            for (final w in data)
              TableRow(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _kBarBg))),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(w.region,
                        style: const TextStyle(fontSize: 13, color: _kT900),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${w.current}', textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, color: _kT900)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${w.incoming}', textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, color: _kOrangeTx)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${w.current + w.incoming}', textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _kBlue)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ── Matukio ya hivi karibuni ──────────────────────────────────────────────
  Widget _eventsCard() {
    return _card('', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(PhosphorIcons.bell(), size: 16, color: _kT900),
          const SizedBox(width: 8),
          const Text('Matukio ya hivi karibuni',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kT900)),
        ]),
        const SizedBox(height: 8),
        if (_events.isEmpty)
          const Text('Hakuna matukio ya hivi karibuni.',
              style: TextStyle(fontSize: 13, color: _kT400)),
        ..._events.take(6).map((e) {
          final m = e as Map<String, dynamic>;
          final type = m['event_type'] as String? ?? '';
          final title = m['title'] as String? ?? _eventTitle(type);
          final time = m['occurred_at'] as String? ?? '';
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kBarBg, width: 1))),
            child: Row(children: [
              _eventIcon(type),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 12, color: _kT600),
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Text(_fmtTime(time),
                  style: const TextStyle(fontSize: 10, color: _kT400)),
            ]),
          );
        }),
      ],
    ));
  }

  // ── Card wrapper (white, border, radius 14) ───────────────────────────────
  Widget _card(String title, {required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _kT900)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('Hakuna data kwa kipindi hiki',
            style: TextStyle(fontSize: 13, color: _kT400)),
      );

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kRedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        Icon(PhosphorIcons.warningCircle(), size: 16, color: _kRed),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Hitilafu kupakua takwimu — jaribu tena.',
              style: TextStyle(fontSize: 12, color: _kRed)),
        ),
        GestureDetector(
          onTap: () => _load(refresh: true),
          child: const Text('Jaribu tena',
              style: TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ── TAB: WATUMIAJI (kama reference: Jina / Simu / Mkoa / Hali) ────────────
  Widget _usersTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(children: [
        TextField(
          controller: _usersCtrl,
          decoration: InputDecoration(
            hintText: 'Tafuta mtumiaji...',
            hintStyle: const TextStyle(color: _kT400, fontSize: 13),
            prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18, color: _kT400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBlue)),
          ),
          onChanged: (v) => _loadUsers(q: v),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Jumla: ${_usersLoading ? '...' : _usersTotal}',
              style: const TextStyle(fontSize: 13, color: _kT500)),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: _usersLoading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: _kBlue)),
                )
              : _users.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Hakuna watumiaji',
                          style: TextStyle(color: _kT400), textAlign: TextAlign.center),
                    )
                  : Column(children: [
                      const Row(children: [
                        Expanded(flex: 3, child: Text('Jina',
                            style: TextStyle(fontSize: 12, color: _kT500))),
                        Expanded(flex: 3, child: Text('Simu',
                            style: TextStyle(fontSize: 12, color: _kT500))),
                        Expanded(flex: 2, child: Text('Mkoa',
                            style: TextStyle(fontSize: 12, color: _kT500))),
                        Expanded(flex: 2, child: Text('Hali',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, color: _kT500))),
                      ]),
                      const Divider(height: 16, color: _kBarBg),
                      for (final u in _users.take(50))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _userRow(u as Map<String, dynamic>),
                        ),
                    ]),
        ),
      ]),
    );
  }

  Widget _userRow(Map<String, dynamic> u) {
    final name    = (u['full_name'] ?? '') as String;
    final phone   = (u['phone_primary'] ?? u['phone'] ?? '') as String;
    final station = (u['current_station'] as Map?) ?? {};
    final region  = (station['region_name'] ?? '') as String;
    final st      = '${u['status'] ?? 'active'}'.toLowerCase();
    final hai     = st == 'active';
    return Row(children: [
      Expanded(
        flex: 3,
        child: Text(name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kT900),
            overflow: TextOverflow.ellipsis),
      ),
      Expanded(
        flex: 3,
        child: Text(phone, style: const TextStyle(fontSize: 12, color: _kBlue)),
      ),
      Expanded(
        flex: 2,
        child: Text(region,
            style: const TextStyle(fontSize: 12, color: _kT600),
            overflow: TextOverflow.ellipsis),
      ),
      Expanded(
        flex: 2,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hai ? _kGreenBg : _kRedBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hai ? 'Hai' : 'Haipo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: hai ? _kGreenTx : _kRedTx,
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // Event helpers
  static Widget _eventIcon(String type) {
    const s = 14.0;
    if (type == 'user.registered') return Icon(PhosphorIcons.userPlus(), size: s, color: const Color(0xFF3B82F6));
    if (type.startsWith('payment.')) return Icon(PhosphorIcons.wallet(), size: s, color: const Color(0xFF22C55E));
    if (type.startsWith('feedback.')) return Icon(PhosphorIcons.chatCircleText(), size: s, color: const Color(0xFFF97316));
    if (type.startsWith('password_reset.')) return Icon(PhosphorIcons.lock(), size: s, color: const Color(0xFFA855F7));
    if (type.startsWith('match.')) return Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), size: s, color: const Color(0xFF22C55E));
    if (type == 'data.changed' || type.startsWith('data.')) return Icon(PhosphorIcons.lightning(PhosphorIconsStyle.fill), size: s, color: const Color(0xFFEAB308));
    return Icon(PhosphorIcons.bell(), size: s, color: const Color(0xFF9CA3AF));
  }

  static String _eventTitle(String type) {
    switch (type) {
      case 'user.registered': return 'Mtumiaji mpya amejiunga';
      case 'payment.submitted': return 'Malipo yamewasilishwa';
      case 'payment.approved': return 'Malipo yamekubaliwa';
      case 'payment.rejected': return 'Malipo yamekataliwa';
      case 'feedback.new': return 'Maoni mapya';
      case 'feedback.replied': return 'Maoni yamejibiwa';
      case 'match.found': return 'Match mpya imepatikana';
      case 'data.changed': return 'Data imebadilishwa';
      case 'password_reset.requested': return 'Ombi la kubadilisha nenosiri';
      default: return type.replaceAll('.', ' ').replaceAll('_', ' ');
    }
  }

  static String _fmtTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _KpiItem {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  const _KpiItem(this.icon, this.label, this.value, this.sub, this.subColor);
}

class _PickerItem {
  final String label;
  final String? sub;
  final String value;
  final bool selected;
  const _PickerItem(this.label, this.sub, this.value, this.selected);
}
