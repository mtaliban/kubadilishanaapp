// STATISTICS — PREMIUM DESIGN
// ─────────────────────────────────────────────────────────────────────────────
// Interface ya kisomi: hero ya gradient, segmented tabs, KPI cards zenye
// icon-badges za rangi, progress bars zenye gradient + animation, rank
// badges za dhahabu/fedha/shaba, filters kama chips za glass.
// Data yote ni halisi kutoka API (adminStats + adminReports + adminUsers).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';

// ── Palette ya premium ──────────────────────────────────────────────────────
const _kPrimary    = Color(0xFF185FA5);
const _kPrimary2   = Color(0xFF378ADD);
const _kPageBg     = Color(0xFFF2F5F9);
const _kCard       = Colors.white;
const _kBorder     = Color(0xFFE3E9F0);
const _kHero1      = Color(0xFF0F3D73); // gradient kushoto
const _kHero2      = Color(0xFF1D6FBF); // gradient kulia
const _kGreen      = Color(0xFF0E9F6E);
const _kGreenBg    = Color(0xFFE8F9F1);
const _kGreenTx    = Color(0xFF0B7A55);
const _kOrangeTx   = Color(0xFFC2700E);
const _kOrange     = Color(0xFFF59E0B);
const _kRed        = Color(0xFFDC2626);
const _kRedBg      = Color(0xFFFCEBEB);
const _kRedTx      = Color(0xFF791F1F);
const _kGold       = Color(0xFFB8860B);
const _kGoldBg     = Color(0xFFFFF7DF);
const _kSilver     = Color(0xFF5B6478);
const _kSilverBg   = Color(0xFFEFF1F5);
const _kBronze     = Color(0xFF9A5B1F);
const _kBronzeBg   = Color(0xFFF9EDE2);
const _kT900       = Color(0xFF141A2E);
const _kT700       = Color(0xFF374151);
const _kT500       = Color(0xFF6B7280);
const _kT400       = Color(0xFF9CA3AF);
const _kBarTrack   = Color(0xFFEDF0F4);

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _stats = {};
  List<dynamic> _events = [];
  String _tab = 'overview';

  late final AnimationController _stagger = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));

  // Filters
  String? _region;
  String? _regionId;
  String? _category;
  String _categoryName = '';
  String _level = '';

  List<dynamic> _regions = [];
  List<dynamic> _departments = [];

  // Users tab
  final _usersCtrl = TextEditingController();
  Timer? _usersDebounce;
  List<dynamic> _users = [];
  int _usersTotal = 0;
  bool _usersLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
    _loadUsers();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _stagger.forward();
    });
  }

  @override
  void dispose() {
    _stagger.dispose();
    _usersCtrl.dispose();
    _usersDebounce?.cancel();
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

  // ── Pickers ────────────────────────────────────────────────────────────────
  Future<void> _pickRegion() async {
    final inData = <String>{
      for (final r in _list('users_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
      for (final r in _list('incoming_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
    }.toList()..sort();
    final source = inData.isNotEmpty
        ? inData.map((n) => {'name': n}).toList()
        : _regions;
    final items = <_PickerItem>[
      _PickerItem('Mkoa wote', 'Onyesha mikoa yote', '__all__',
          _regionId == null || _regionId!.isEmpty),
      for (final r in source)
        _PickerItem(
          '${r['name'] ?? r['region_name'] ?? ''}',
          null,
          '${r['id'] ?? r['region_id'] ?? r['name']}',
          '${r['id'] ?? r['region_id'] ?? r['name']}' == (_regionId ?? ''),
        ),
    ];
    final picked = await _showPickerSheet('Chagua mkoa', items,
        _regionId == null || _regionId!.isEmpty);
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
      _PickerItem('Idara zote', 'Onyesha idara zote', '__all__', _category == null),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.68,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Container(width: 34, height: 34,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_kHero1, _kHero2]),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(PhosphorIcons.magnifyingGlass(), size: 16, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kT900))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 30, height: 30,
                      decoration: const BoxDecoration(color: _kBarTrack, shape: BoxShape.circle),
                      child: Icon(PhosphorIcons.x(), size: 14, color: _kT700)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: ctrl,
                onChanged: (q) {
                  final ql = q.toLowerCase();
                  ss(() => filtered = items.where((i) => i.label.toLowerCase().contains(ql)).toList());
                },
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  hintStyle: const TextStyle(color: _kT400, fontSize: 13),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 17, color: _kT400),
                  filled: true,
                  fillColor: _kPageBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _kPrimary.withValues(alpha: 0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _kPrimary2 : _kBorder,
              width: selected ? 1.4 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                      fontSize: 13.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _kPrimary : _kT900)),
                  if (sub != null)
                    Text(sub, style: const TextStyle(fontSize: 11, color: _kT400)),
                ],
              ),
            ),
            if (selected)
              Container(width: 22, height: 22,
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_kHero1, _kHero2]),
                      shape: BoxShape.circle),
                  child: Icon(PhosphorIcons.check(), size: 12, color: Colors.white)),
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
        color: _kPrimary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── HERO ya gradient (imeunganisha header + live + chips) ──
            SliverToBoxAdapter(child: _hero(totals)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kPrimary)),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_error != null) _errorBanner(),
                    _segmentedTabs(),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                        animation: _stagger,
                        builder: (context, _) => _tab == 'users'
                            ? _usersTab()
                            : _overviewBody(totals)),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── HERO: gradient + title + live pill + filter chips ────────────────────
  Widget _hero(Map<String, dynamic> totals) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kHero1, _kHero2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(PhosphorIcons.chartBar(PhosphorIconsStyle.fill),
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Statistics',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Takwimu za mfumo mzima — mikoa, idara, kada',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                ]),
              ),
              // Live pill ya glass
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  const Text('LIVE',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800,
                          letterSpacing: 0.8, color: Colors.white)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            // Chips za glass
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _heroChip(PhosphorIcons.mapPin(),
                    _region == null || _region!.isEmpty ? 'Mkoa wote' : _region!,
                    _regionId != null, _pickRegion),
                const SizedBox(width: 8),
                _heroChip(PhosphorIcons.buildings(),
                    _category == null ? 'Idara zote' : _categoryName,
                    _category != null, _pickCategory),
                const SizedBox(width: 8),
                _heroChip(PhosphorIcons.graduationCap(),
                    _level.isEmpty ? 'Ngazi zote' : _level,
                    _level.isNotEmpty, _pickLevel),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _heroChip(IconData icon, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? Colors.white : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? _kPrimary : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700,
              color: active ? _kPrimary : Colors.white)),
          const SizedBox(width: 4),
          Icon(PhosphorIcons.caretDown(), size: 12,
              color: active ? _kPrimary : Colors.white70),
        ]),
      ),
    );
  }

  // ── Segmented tabs (pills ndani ya track) ────────────────────────────────
  Widget _segmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kBarTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _segTab(PhosphorIcons.chartBar(), 'Statistics', 'overview'),
        _segTab(PhosphorIcons.usersThree(), 'Watumiaji', 'users'),
      ]),
    );
  }

  Widget _segTab(IconData icon, String label, String key) {
    final active = _tab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active ? [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: active ? _kPrimary : _kT500),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? _kPrimary : _kT500)),
          ]),
        ),
      ),
    );
  }

  // ── OVERVIEW BODY ─────────────────────────────────────────────────────────
  Widget _overviewBody(Map<String, dynamic> totals) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _kpiGrid(totals),
      const SizedBox(height: 4),
      ..._overviewSections(totals),
      const SizedBox(height: 10),
    ]);
  }

  // ── KPI GRID yenye icon-badges za rangi ───────────────────────────────────
  Widget _kpiGrid(Map<String, dynamic> totals) {
    final incomingTotal = _list('incoming_by_region')
        .fold<int>(0, (s, r) => s + ((r['count'] as num?)?.toInt() ?? 0));
    final users7d = (totals['users_active_7d'] as num?)?.toInt() ?? 0;
    final items = [
      _KpiItem(PhosphorIcons.users(PhosphorIconsStyle.fill), 'Watumiaji waliopo',
          _reportUsersTotal, const [_kHero1, _kHero2],
          sub: '+$users7d wiki 7', subColor: _kGreenTx),
      _KpiItem(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), 'Imethibitishwa',
          (totals['users_verified'] as num?)?.toInt() ?? 0, [_kGreen, const Color(0xFF34D399)]),
      _KpiItem(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), 'Mikoa yote',
          _int('regions_total'), [_kOrange, const Color(0xFFFBBF24)]),
      _KpiItem(PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill), 'Wilaya zote',
          _int('districts_total'), const [Color(0xFF7C3AED), Color(0xFFA78BFA)]),
      _KpiItem(PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.fill), 'Wanaohamia wote',
          incomingTotal, [const Color(0xFFDC2626), const Color(0xFFF87171)]),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.42,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final t = _stagger.value.clamp(0.0, 1.0);
        final delay = (index * 0.08).clamp(0.0, 0.6);
        final appear = ((t - delay) / 0.4).clamp(0.0, 1.0);
        return Opacity(
          opacity: appear,
          child: Transform.translate(
            offset: Offset(0, (1 - appear) * 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: item.colors),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(item.icon, size: 15, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(item.value >= 1000 ? _thousands(item.value) : '${item.value}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, color: _kT900)),
                  const SizedBox(height: 2),
                  Text(item.label,
                      style: const TextStyle(fontSize: 11.5, color: _kT500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.sub != null) ...[
                    const SizedBox(height: 2),
                    Text(item.sub!,
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700,
                            color: item.subColor ?? _kGreenTx)),
                  ],
                ],
              ),
            ),
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
      _section('Kwa Idara', PhosphorIcons.buildings(),
          child: _progressList([
            for (final c in byDept)
              ('${c['name'] ?? _deptLabel('${c['category']}')}',
               (c['count'] as num?)?.toInt() ?? 0),
          ])),

      _section('Walimu kwa Ngazi', PhosphorIcons.graduationCap(),
          child: _progressList([
            ('Walimu wa Msingi', priCount),
            ('Walimu wa Sekondari', secCount),
            if (noneCount > 0) ('Hakuna ngazi', noneCount),
          ])),

      _section('Kwa Kada', PhosphorIcons.identificationBadge(),
          child: _rankedList([
            for (final c in byCadre.take(15))
              (
                '${c['cadre_name'] ?? c['cadre']}${(c['level'] ?? '').toString().isEmpty ? '' : ' (${c['level']})'}',
                (c['count'] as num?)?.toInt() ?? 0,
              ),
          ])),

      _section('Kwa Hali', PhosphorIcons.checkCircle(),
          child: _progressList([
            for (final s in byStatus)
              (_statusLabel('${s['status']}'), (s['count'] as num?)?.toInt() ?? 0),
          ])),

      _section('Waliopo na Wanaohamia kwa Mkoa', PhosphorIcons.mapPin(),
          hint: 'Walio (bluu) + Wanaohamia (chungwa) — kila mkoa',
          child: _mkoaMigrationList(_byRegion.take(30).toList())),

      if (_list('incoming_sources').isNotEmpty)
        _section(
          'Wanaohamia Wanatoka Wapi${_region != null && _region!.isNotEmpty ? ' — $_region' : ''}',
          PhosphorIcons.arrowsLeftRight(),
          child: _migrationFlowTable(_list('incoming_sources').take(15).toList()),
        ),

      _section(
        'Watu kwa Wilaya${_region != null && _region!.isNotEmpty ? ' — $_region' : ''}',
        PhosphorIcons.mapTrifold(),
        child: _wilayaTable(_byDistrict().take(20).toList()),
      ),

      _section('Matukio ya Hivi Karibuni', PhosphorIcons.bell(),
          child: _eventsList()),
    ];
  }

  // ── Section card yenye icon badge ─────────────────────────────────────────
  Widget _section(String title, IconData icon, {String? hint, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kHero1, _kHero2]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: _kT900))),
          ]),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 37),
              child: Text(hint, style: const TextStyle(fontSize: 11, color: _kT400)),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Progress bars zenye gradient + % pill ─────────────────────────────────
  Widget _progressList(List<(String, int)> data) {
    if (data.isEmpty) return _empty();
    final total = data.fold<int>(0, (s, d) => s + d.$2);
    return Column(
      children: data.map((d) {
        final pct = total > 0 ? (d.$2 / total * 100).round() : 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(d.$1,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kT900),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('$pct%',
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w800, color: _kPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Text('${d.$2 >= 1000 ? _thousands(d.$2) : d.$2}',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800, color: _kT900)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0, 1).toDouble(),
                  minHeight: 7,
                  backgroundColor: _kBarTrack,
                  valueColor: const AlwaysStoppedAnimation(_kPrimary2),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Ranked list na badges za dhahabu/fedha/shaba ─────────────────────────
  Widget _rankedList(List<(String, int)> data) {
    if (data.isEmpty) return _empty();
    Color rankColor(int i) => i == 0 ? _kGold : i == 1 ? _kSilver : i == 2 ? _kBronze : _kT400;
    Color rankBg(int i) => i == 0 ? _kGoldBg : i == 1 ? _kSilverBg : i == 2 ? _kBronzeBg : _kBarTrack;
    return Column(
      children: List.generate(data.length, (i) {
        final d = data[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 26, height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: rankBg(i), shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800, color: rankColor(i))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(d.$1,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kT900),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(d.$2 >= 1000 ? _thousands(d.$2) : '${d.$2}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _kT900)),
            ],
          ),
        );
      }),
    );
  }

  // ── Mkoa migration (# | Mkoa | Waliopo | Wanaohamia + gradient bar) ───────
  Widget _mkoaMigrationList(List<({String region, int current, int incoming})> data) {
    if (data.isEmpty) return _empty();
    final maxIncoming = data.map((e) => e.incoming).reduce((a, b) => a > b ? a : b);
    const hs = TextStyle(
        fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kT400);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const SizedBox(width: 26),
            const Expanded(flex: 3, child: Text('MKOA', style: hs)),
            const Expanded(flex: 2, child: Text('WALIOPO',
                textAlign: TextAlign.right, style: hs)),
            const SizedBox(width: 10),
            const Expanded(flex: 5, child: Text('WANAOHAMIA', style: hs)),
          ]),
        ),
        for (final (i, m) in data.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kT400)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(m.region,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kT900),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${m.current}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700, color: _kT700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Text('${m.incoming}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800, color: _kOrangeTx)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: maxIncoming > 0 ? m.incoming / maxIncoming : 0,
                            minHeight: 6,
                            backgroundColor: _kBarTrack,
                            valueColor: const AlwaysStoppedAnimation(_kOrange),
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

  // ── Migration flow (Kutoka → Kwenda | hesabu) ────────────────────────────
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
                width: 26,
                child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kT400)),
              ),
              Expanded(
                  child: Text('${f['from']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kT900),
                      overflow: TextOverflow.ellipsis)),
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(PhosphorIcons.arrowRight(), size: 12, color: _kOrangeTx),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${f['to']}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _kOrangeTx),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${f['count'] ?? 0}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: _kOrangeTx)),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Wilaya table (Wilaya / Waliopo / Hamia / Jumla) ──────────────────────
  Widget _wilayaTable(List<({String region, int current, int incoming})> data) {
    if (data.isEmpty) return _empty();
    const hs = TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
        letterSpacing: 0.4, color: _kT400);
    return Column(
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.4),
          },
          children: [
            const TableRow(children: [
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('WILAYA', style: hs)),
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('WALIOPO', textAlign: TextAlign.right, style: hs)),
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('HAMIA', textAlign: TextAlign.right, style: hs)),
              Padding(padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('JUMLA', textAlign: TextAlign.right, style: hs)),
            ]),
            for (final w in data)
              TableRow(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _kBarTrack))),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(w.region,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _kT900),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text('${w.current}', textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, color: _kT700)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text('${w.incoming}', textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _kOrangeTx)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _kPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(7)),
                      child: Text('${w.current + w.incoming}', textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800, color: _kPrimary)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ── Matukio ───────────────────────────────────────────────────────────────
  Widget _eventsList() {
    if (_events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Hakuna matukio ya hivi karibuni.',
            style: TextStyle(fontSize: 13, color: _kT400)),
      );
    }
    return Column(
      children: [
        for (final e in _events.take(6))
          Builder(builder: (_) {
            final m = e as Map<String, dynamic>;
            final type = m['event_type'] as String? ?? '';
            final title = m['title'] as String? ?? _eventTitle(type);
            final time = m['occurred_at'] as String? ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _kBarTrack, width: 1))),
              child: Row(children: [
                _eventIcon(type),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500, color: _kT700),
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text(_fmtTime(time),
                    style: const TextStyle(fontSize: 10.5, color: _kT400)),
              ]),
            );
          }),
      ],
    );
  }

  // ── TAB: WATUMIAJI (cards premium) ────────────────────────────────────────
  Widget _usersTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Search bar ya premium
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          Icon(PhosphorIcons.magnifyingGlass(), size: 17, color: _kT400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _usersCtrl,
              style: const TextStyle(fontSize: 13.5, color: _kT900),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
                hintText: 'Tafuta mtumiaji...',
                hintStyle: TextStyle(color: _kT400, fontSize: 13),
              ),
              onChanged: (v) {
                _usersDebounce?.cancel();
                _usersDebounce = Timer(const Duration(milliseconds: 400),
                    () => _loadUsers(q: v));
              },
            ),
          ),
          if (_usersCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _usersCtrl.clear();
                _loadUsers();
              },
              child: Icon(PhosphorIcons.x(), size: 15, color: _kT400),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Text('Jumla: ${_usersLoading ? '...' : _usersTotal}',
            style: const TextStyle(fontSize: 12.5, color: _kT500,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      if (_usersLoading && _users.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: _kPrimary)),
        )
      else if (_users.isEmpty)
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder)),
          child: Column(children: [
            Icon(PhosphorIcons.usersThree(), size: 40, color: _kT400),
            const SizedBox(height: 10),
            const Text('Hakuna watumiaji',
                style: TextStyle(color: _kT500, fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        )
      else
        ..._users.take(50).map((u) => _userCard(u as Map<String, dynamic>)),
    ]);
  }

  Widget _userCard(Map<String, dynamic> u) {
    final name    = (u['full_name'] ?? '') as String;
    final phone   = (u['phone_primary'] ?? u['phone'] ?? '') as String;
    final cadre   = (u['cadre_display'] ?? u['cadre_code'] ?? '') as String;
    final station = (u['current_station'] as Map?) ?? {};
    final region  = (station['region_name'] ?? '') as String;
    final st      = '${u['status'] ?? 'active'}'.toLowerCase();
    final hai     = st == 'active';
    final isPaid  = (u['is_verified'] as bool?) ?? false;
    final isAdmin = (u['is_admin'] as bool?) ?? false;
    final init    = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // Avatar na gradient
        Container(
          width: 42, height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_kHero1, _kHero2]),
              shape: BoxShape.circle),
          child: Text(init,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _kT900),
                  overflow: TextOverflow.ellipsis)),
              if (isAdmin) ...[
                const SizedBox(width: 4),
                Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                    size: 13, color: _kPrimary),
              ],
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Icon(PhosphorIcons.phone(), size: 11, color: _kT400),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimary)),
              if (region.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(PhosphorIcons.mapPin(), size: 11, color: _kT400),
                const SizedBox(width: 3),
                Flexible(child: Text(region,
                    style: const TextStyle(fontSize: 11.5, color: _kT500),
                    overflow: TextOverflow.ellipsis)),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Hali badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hai ? _kGreenBg : _kRedBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(hai ? 'Hai' : 'Haipo',
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w800,
                    color: hai ? _kGreenTx : _kRedTx)),
          ),
          if (cadre.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(cadre,
                style: const TextStyle(fontSize: 10, color: _kT400),
                overflow: TextOverflow.ellipsis),
          ],
          if (isPaid) ...[
            const SizedBox(height: 4),
            Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                size: 13, color: _kGreen),
          ],
        ]),
      ]),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
            size: 16, color: _kRed),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Hitilafu kupakua takwimu — jaribu tena.',
              style: TextStyle(fontSize: 12, color: _kRed)),
        ),
        GestureDetector(
          onTap: () => _load(refresh: true),
          child: const Text('Jaribu tena',
              style: TextStyle(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // Event helpers
  static Widget _eventIcon(String type) {
    const s = 13.0;
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
  final int value;
  final List<Color> colors;
  final String? sub;
  final Color? subColor;
  const _KpiItem(this.icon, this.label, this.value, this.colors,
      {this.sub, this.subColor});
}

class _PickerItem {
  final String label;
  final String? sub;
  final String value;
  final bool selected;
  const _PickerItem(this.label, this.sub, this.value, this.selected);
}
