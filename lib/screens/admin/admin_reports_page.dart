// Statistiki — muundo unafanana na web/admin/page.tsx kwa mobile:
//  1. Vitendo 3 kuu (Users, Verified, Mikoa) — kutoka adminStats
//  2. Matukio ya Hivi Karibuni
//  3. Tabs: Muhtasari | Watumiaji
//  4. Muhtasari: filters (Mkoa/Idara/Ngazi) + namba 4 + majedwali sahihi
//  5. Watumiaji: search + orodha

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/select_sheet.dart';

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
      setState(() => _departments = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _load({bool refresh = false}) async {
    // Kama web: spinner ya full-screen iko MARA YA KWANZA tu; filter ikibadilika
    // au RefreshIndicator ikivutwa — data inasasisha KIMYA KIMYA (content inabaki).
    final firstLoad = _data.isEmpty;
    setState(() { if (firstLoad) _loading = true; _error = null; });
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      setState(() => _stats = (r.data as Map<String, dynamic>?) ?? {});
    } catch (_) {}
    try {
      final r = await ApiService().adminEvents(limit: 6);
      if (!mounted) return;
      final d = r.data as Map? ?? {};
      setState(() => _events = (d['events'] as List?) ?? []);
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

  // ── Pickers ───────────────────────────────────────────────────────────────
  Future<void> _pickRegion() async {
    // Kama web: orodha ina mikoa iliyo kwenye takwimu (waliopo + wanaohamia)
    // — sio mikoa yote ya TZ. Hakuna data →anguka kwenye orodha ya mikoa yote.
    final inData = <String>{
      for (final r in _list('users_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
      for (final r in _list('incoming_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
    }.toList()..sort();
    final source = inData.isNotEmpty
        ? inData.map((n) => {'name': n}).toList()
        : _regions;
    final items = <({String value, String label, String? subtitle})>[
      (value: '__all__', label: 'Mkoa wote', subtitle: 'Onyesha mikoa yote'),
      for (final r in source)
        (value: '${r['id'] ?? r['region_id'] ?? r['name']}',
         label: '${r['name'] ?? r['region_name'] ?? ''}',
         subtitle: null),
    ];
    final picked = await showSelectSheet<String>(context,
        title: 'Chagua Mkoa', items: items,
        selected: _regionId ?? '__all__', searchable: true);
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
    final items = <({String value, String label, String? subtitle})>[
      (value: '__all__', label: 'Idara zote', subtitle: 'Onyesha idara zote'),
      for (final d in _departments)
        (value: '${d['code']}',
         label: '${d['name'] ?? d['code']}',
         subtitle: '${d['code']}'),
    ];
    final picked = await showSelectSheet<String>(context,
        title: 'Chagua Idara', items: items,
        selected: _category ?? '__all__', searchable: true);
    if (picked == null || !mounted) return;
    final d = _departments.firstWhere(
        (x) => '${x['code']}' == picked, orElse: () => null);
    setState(() {
      _category = picked == '__all__' ? null : picked;
      _categoryName = picked == '__all__' ? '' : '${d?['name'] ?? picked}';
    });
    _load();
  }

  Future<void> _pickLevel() async {
    final items = <({String value, String label, String? subtitle})>[
      (value: '', label: 'Ngazi zote', subtitle: 'Primary na Secondary'),
      (value: 'Primary', label: 'Primary (Msingi)', subtitle: null),
      (value: 'Secondary', label: 'Secondary (Sekondari)', subtitle: null),
    ];
    final picked = await showSelectSheet<String>(context,
        title: 'Chagua Ngazi', items: items, selected: _level);
    if (picked == null || !mounted) return;
    setState(() => _level = picked);
    _load();
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totals = _stats['totals'] as Map<String, dynamic>? ?? {};
    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else ...[
              // ── 3 global cards (grid-cols-2 md:grid-cols-3, kama web) ─────
              // grid-cols-2 gap-3 — mobile: 2 kwa safu, ya 3 chini peke yake
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _topCard(
                        '${totals['users'] ?? '—'}', 'Watumiaji',
                        AppColors.primary,
                        sub: '+${totals['users_active_7d'] ?? 0} wanatumia siku 7',
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _topCard(
                        '${totals['users_verified'] ?? '—'}', 'Imethibitishwa',
                        _kAmber,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _topCard(
                        '${_int('regions_total')}', 'Mikoa yote',
                        AppColors.success,
                      )),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ]),
                  ]),
                ),
              ),
              // ── Matukio ya Hivi Karibuni ──────────────────────────────────
              if (_events.isNotEmpty)
                SliverToBoxAdapter(child: _recentActivity()),
              // ── Tabs ──────────────────────────────────────────────────────
              SliverToBoxAdapter(child: _tabBar()),
              // ── Tab content ───────────────────────────────────────────────
              if (_tab == 'overview')
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_error != null) _errorBanner(),
                      _filters(),
                      ..._sections(),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(_usersTabContent()),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header — kama web: flex items-center justify-between, h1 text-2xl font-bold + p text-sm + Live badge ──
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // h1 text-2xl (24px) font-bold text-brand-grey-900 — sawa na web
              Text('Statistics',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              SizedBox(height: 4),
              // p text-sm (14px) text-brand-grey-500 — sawa na web
              Text('Takwimu za mfumo mzima — mikoa, idara, kada, michango (real-time)',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(width: 8),
          // Live badge — inline-flex items-center gap-1.5 text-[11px] font-bold px-2.5(10px) py-1.5(6px) rounded-full border
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // w-2 h-2 rounded-full bg-brand-grey-300
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppColors.grey300, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('Live',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Top 3 global cards (kama web Big component) ───────────────────────────
  // Web: text-3xl (30px) value, text-xs (12px) label — card class (16px radius, grey100 border, shadow)
  Widget _topCard(String value, String label, Color color, {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
        ],
      ]),
    );
  }

  // ── Recent Activity (kama web RecentActivity component) ───────────────────
  Widget _recentActivity() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.notifications_rounded, size: 15, color: AppColors.textPrimary),
            SizedBox(width: 6),
            Text('Matukio ya Hivi Karibuni',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 8),
          ..._events.take(6).map((e) {
            final m = e as Map<String, dynamic>;
            final type = m['event_type'] as String? ?? '';
            final title = m['title'] as String? ?? _eventTitle(type);
            final time = m['occurred_at'] as String? ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFF9FAFB), width: 1))),
              child: Row(children: [
                _eventIcon(type),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey700),
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text(_fmtTime(time),
                    style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  // ── Tabs (kama web: px-4 py-2 text-sm font-semibold border-b-2) ──────────
  Widget _tabBar() {
    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.grey200))),
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
                    color: _tab == key ? AppColors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(lbl,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _tab == key ? AppColors.primary : AppColors.textSecondary,
                  )),
            ),
          ),
        ]
      ]),
    );
  }

  // ── Filters (3 stacked selects kama web flex-col sm:flex-row) ─────────────
  // Maelezo kama web: 'Mkoa wote' / 'Idara zote' / 'Ngazi zote'
  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        SelectField(
          hint: 'Mkoa wote',
          value: _region == null || _region!.isEmpty ? 'Mkoa wote' : _region,
          onTap: _pickRegion,
          leading: const Icon(Icons.map_outlined, size: 15, color: AppColors.textLight),
        ),
        const SizedBox(height: 8),
        SelectField(
          hint: 'Idara zote',
          value: _category == null ? 'Idara zote' : _categoryName,
          onTap: _pickCategory,
          leading: const Icon(Icons.category_outlined, size: 15, color: AppColors.textLight),
        ),
        const SizedBox(height: 8),
        SelectField(
          hint: 'Ngazi zote',
          value: _level.isEmpty ? 'Ngazi zote' : _level,
          onTap: _pickLevel,
          leading: const Icon(Icons.school_outlined, size: 15, color: AppColors.textLight),
        ),
      ]),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Hitilafu kupakua takwimu — tena.',
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        ),
        GestureDetector(
          onTap: () => _load(refresh: true),
          child: const Text('Jaribu tena',
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ── Overview sections (mpangilio kama web) ────────────────────────────────
  List<Widget> _sections() {
    final incomingTotal = _list('incoming_by_region')
        .fold<int>(0, (s, r) => s + ((r['count'] as num?)?.toInt() ?? 0));

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

    return [
      // ── 4 filtered big cards (gap-3 = 12px) — MPANGILIO KAMA WEB: mikoa, wilaya, watumiaji, wanaohamia ──
      Row(children: [
        Expanded(child: _bigCard('Mikoa yote', _int('regions_total'), AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _bigCard('Wilaya zote', _int('districts_total'), _kAmber)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _bigCard('Watumiaji waliopo', _reportUsersTotal, AppColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _bigCard('Wanaohamia wote', incomingTotal, _kOrange)),
      ]),
      const SizedBox(height: 16),

      // ── Idara + Status (web: grid-cols-2) ──
      _card(
        title: 'Kwa Idara',
        child: _numTable([
          for (final c in _list('users_by_category')
              ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
                  .compareTo((a['count'] as num?)?.toInt() ?? 0)))
            ('${c['name'] ?? _deptLabel('${c['category']}')}',
             (c['count'] as num?)?.toInt() ?? 0),
        ]),
      ),

      _card(
        title: 'Kwa Hali',
        child: _numTable([
          for (final s in _list('users_by_status')
              ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
                  .compareTo((a['count'] as num?)?.toInt() ?? 0)))
            (_statusLabel('${s['status']}'), (s['count'] as num?)?.toInt() ?? 0),
        ]),
      ),

      // ── Mikoa: # | Mkoa | Waliopo | Wanaohamia | Bar (vichwa kama web: MKOA/WALIOPO/WANAOHAMIA) ──
      _card(
        title: 'Waliopo na Wanaohamia kwa Mkoa',
        hint: 'Walio (kijani-bluu) + Wanaohamia (chungwa) — kila mkoa',
        child: _regTable(_byRegion.take(40).toList()),
      ),

      // ── Wilaya: # | Wilaya | Waliopo | Wanaohamia | JUMLA (vichwa kama web) ──
      _card(
        title: 'Watu kwa Wilaya${_region != null && _region!.isNotEmpty ? ' — $_region' : ''}',
        child: _districtTable(_byDistrict()),
      ),

      // ── Ngazi: Primary / Secondary / Hakuna ngazi (matare kama web) ──
      _card(
        title: 'Walimu kwa Ngazi (Primary/Secondary)',
        child: _numTable([
          ('Walimu wa Msingi', priCount),
          ('Walimu wa Sekondari', secCount),
          if (noneCount > 0) ('Hakuna ngazi', noneCount),
        ]),
      ),

      // ── Kada (max 20 kama web) ──
      _card(
        title: 'Kwa Kada',
        child: _numTable([
          for (final c in (_list('users_by_cadre').toList()
                ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
                    .compareTo((a['count'] as num?)?.toInt() ?? 0)))
              .take(20))
            ('${c['cadre_name'] ?? c['cadre']}${(c['level'] ?? '').toString().isEmpty ? '' : ' (${c['level']})'}',
             (c['count'] as num?)?.toInt() ?? 0),
        ]),
      ),

      // ── Wanaohamia sources ──
      if (_list('incoming_sources').isNotEmpty)
        _card(
          title: 'Wanaohamia wanatoka wapi${_region != null && _region!.isNotEmpty ? ' — $_region' : ''}',
          hint: 'Kila mkoa wanaohamia — wanatoka mikoa ipi',
          child: _sourcesTable(_list('incoming_sources').take(30).toList()),
        ),

    ];
  }

  // ── Users Tab ─────────────────────────────────────────────────────────────
  List<Widget> _usersTabContent() {
    return [
      TextField(
        controller: _usersCtrl,
        decoration: AppColors.inputDecoration('Tafuta mtumiaji...'),
        style: const TextStyle(fontSize: 13),
        onChanged: (v) => _loadUsers(q: v),
      ),
      const SizedBox(height: 8),
      Text('Jumla: ${_usersLoading ? '...' : _usersTotal}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      if (_usersLoading)
        const Center(
            child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.primary),
        ))
      else
        ..._users.map(_userRow),
    ];
  }

  Widget _userRow(dynamic u) {
    final m = u as Map<String, dynamic>;
    final name = (m['full_name'] ?? '') as String;
    final phone = (m['phone_primary'] ?? m['phone'] ?? '') as String;
    final cadre = (m['cadre_code'] ?? '') as String;
    final station = (m['current_station'] as Map?) ?? {};
    final region = (station['region_name'] ?? '') as String;
    final dests = ((m['desired_destinations'] as List?) ?? [])
        .map((d) => (d as Map)['region_name'] ?? '')
        .where((s) => s.toString().isNotEmpty)
        .join(', ');
    final isAdmin = (m['is_admin'] as bool?) ?? false;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: AppColors.cardDecoration(),
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.blue50,
          child: Text(initial,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis)),
              if (isAdmin)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.blue50, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.shield_rounded, size: 11, color: AppColors.primary),
                ),
            ]),
            if (phone.isNotEmpty)
              Text(phone,
                  style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            if (cadre.isNotEmpty || region.isNotEmpty)
              Text([cadre, region].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
            if (dests.isNotEmpty)
              Text('→ $dests',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
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

  // ── Widget helpers ────────────────────────────────────────────────────────

  // 4 overview filtered cards (kama web Big component ndani ya Overview)
  Widget _bigCard(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          value >= 1000 ? _thousands(value) : '$value',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
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

  // Section card wrapper — margin 16px (space-y-4 kama web)
  Widget _card({
    required String title,
    String? hint,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
        const SizedBox(height: 10),
        const Divider(height: 1, thickness: 1, color: AppColors.borderLight),
        const SizedBox(height: 4),
        child,
      ]),
    );
  }

  // ── NumberTable: # | Jina | % | Idadi + jumla (kama web NumberTable) ──────
  // Web: row py-2(8px), label text-sm(14px), count text-lg(18px) font-bold, % text-xs(12px)
  Widget _numTable(List<(String, int)> rows) {
    if (rows.isEmpty) return _empty();
    final total = rows.fold<int>(0, (s, r) => s + r.$2);
    const hs = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textLight,
        letterSpacing: 0.5);

    final rowsCol = Column(children: [
      for (final (i, row) in rows.indexed)
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1))),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 24,
              child: Text('${i + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(row.$1,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            SizedBox(
              width: 40,
              child: Text(
                  total > 0 ? '${((row.$2 / total) * 100).round()}%' : '—',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            ),
            SizedBox(
              width: 48,
              child: Text(
                  row.$2 >= 1000 ? _thousands(row.$2) : '${row.$2}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
        ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 24),
        const SizedBox(width: 12),
        const Expanded(child: Text('JINA', style: hs)),
        const SizedBox(width: 40, child: Text('%', textAlign: TextAlign.right, style: hs)),
        const SizedBox(width: 48, child: Text('HESABU', textAlign: TextAlign.right, style: hs)),
      ]),
      const Divider(height: 8, thickness: 1, color: AppColors.borderLight),
      if (rows.length > 12)
        ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 384),
            child: SingleChildScrollView(child: rowsCol))
      else
        rowsCol,
      const Divider(height: 8, thickness: 1, color: AppColors.borderLight),
      Row(children: [
        const Expanded(
            child: Text('Jumla:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Text(total >= 1000 ? _thousands(total) : '$total',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ]),
    ]);
  }

  // ── Mikoa table: # | Mkoa | Waliopo (grey-700) | Wanaohamia (orange) | Bar ─
  // Web: current=text-brand-grey-700, incoming=text-brand-orange, bar=rounded-full h-1.5(6px)
  Widget _regTable(List<({String region, int current, int incoming})> rows) {
    if (rows.isEmpty) return _empty();
    final maxTotal = rows.fold<int>(1, (m, r) {
      final t = r.current + r.incoming;
      return t > m ? t : m;
    });
    // header: text-[10px] uppercase tracking-wider font-bold text-brand-grey-400
    const hs = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textLight);

    final rowsCol = Column(children: [
      for (final (i, r) in rows.indexed)
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1))),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 24,
              child: Text('${i + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(r.region,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            // Waliopo: text-brand-grey-700 font-semibold (kama web)
            SizedBox(
              width: 64,
              child: Text('${r.current}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey700)),
            ),
            const SizedBox(width: 12),
            // Wanaohamia: text-brand-orange font-semibold
            SizedBox(
              width: 64,
              child: Text('${r.incoming}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _kOrange)),
            ),
            const SizedBox(width: 12),
            // Bar: rounded-full h-1.5(6px) bg-brand-grey-100/blue
            SizedBox(
              width: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: maxTotal > 0 ? (r.current + r.incoming) / maxTotal : 0,
                  backgroundColor: AppColors.borderLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ),
          ]),
        ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 24),
        const SizedBox(width: 12),
        const Expanded(child: Text('MKOA', style: hs)),
        const SizedBox(width: 12),
        const SizedBox(width: 64, child: Text('WALIOPO', textAlign: TextAlign.right, style: hs)),
        const SizedBox(width: 12),
        const SizedBox(width: 64, child: Text('WANAOHAMIA', textAlign: TextAlign.right, style: hs)),
        const SizedBox(width: 68),
      ]),
      const Divider(height: 8, thickness: 1, color: AppColors.borderLight),
      if (rows.length > 12)
        ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 384),
            child: SingleChildScrollView(child: rowsCol))
      else
        rowsCol,
    ]);
  }

  // ── Wilaya table: # | Wilaya | Waliopo | Wanaoingia | JUMLA (text-lg) ──────
  // Web: jumla = text-lg font-bold text-brand-blue (18px)
  Widget _districtTable(List<({String region, int current, int incoming})> rows) {
    if (rows.isEmpty) return _empty();
    const hs = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textLight);

    final rowsCol = Column(children: [
      for (final (i, r) in rows.indexed)
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1))),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 24,
              child: Text('${i + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(r.region,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text('${r.current}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey700)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text('${r.incoming}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _kOrange)),
            ),
            const SizedBox(width: 12),
            // JUMLA: text-lg font-bold text-brand-blue (kama web)
            SizedBox(
              width: 56,
              child: Text('${r.current + r.incoming}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
        ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 24),
        const SizedBox(width: 12),
        const Expanded(child: Text('WILAYA', style: hs)),
        const SizedBox(width: 12),
        const SizedBox(width: 64, child: Text('WALIOPO', textAlign: TextAlign.right, style: hs)),
        const SizedBox(width: 12),
        const SizedBox(width: 64, child: Text('WANAOHAMIA', textAlign: TextAlign.right, style: hs)),
        const SizedBox(width: 12),
        const SizedBox(width: 56, child: Text('JUMLA', textAlign: TextAlign.right, style: hs)),
      ]),
      const Divider(height: 8, thickness: 1, color: AppColors.borderLight),
      if (rows.length > 12)
        ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 384),
            child: SingleChildScrollView(child: rowsCol))
      else
        rowsCol,
    ]);
  }

  // ── Sources table: # | Kutoka | → | Kwenda (orange) | N (text-lg) ─────────
  Widget _sourcesTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return _empty();
    const hs = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textLight);

    final rowsCol = Column(children: [
      for (final (i, s) in rows.indexed)
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.borderLight, width: 1))),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 24,
              child: Text('${i + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text('${s['from']}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text('${s['to']}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, color: _kOrange),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 48,
              child: Text('${s['count']}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
        ),
    ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 24),
        const SizedBox(width: 12),
        const Expanded(child: Text('WANATOKA', style: hs)),
        const SizedBox(width: 12),
        const SizedBox(width: 64, child: Text('WANAELEKEA', textAlign: TextAlign.right, style: hs)),
        const SizedBox(width: 12),
        const SizedBox(width: 48, child: Text('HESABU', textAlign: TextAlign.right, style: hs)),
      ]),
      const Divider(height: 8, thickness: 1, color: AppColors.borderLight),
      if (rows.length > 12)
        ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 384),
            child: SingleChildScrollView(child: rowsCol))
      else
        rowsCol,
    ]);
  }

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('Hakuna data kwa kipindi hiki',
            style: TextStyle(fontSize: 13, color: AppColors.textLight)),
      );

  // Event helpers
  static Widget _eventIcon(String type) {
    const s = 14.0;
    if (type == 'user.registered') return const Icon(Icons.person_add_rounded, size: s, color: Color(0xFF3B82F6));
    if (type.startsWith('payment.')) return const Icon(Icons.payments_rounded, size: s, color: Color(0xFF22C55E));
    if (type.startsWith('feedback.')) return const Icon(Icons.assignment_rounded, size: s, color: Color(0xFFF97316));
    if (type.startsWith('password_reset.')) return const Icon(Icons.key_rounded, size: s, color: Color(0xFFA855F7));
    if (type.startsWith('match.')) return const Icon(Icons.favorite_rounded, size: s, color: Color(0xFF22C55E));
    if (type == 'data.changed' || type.startsWith('data.')) return const Icon(Icons.bolt_rounded, size: s, color: Color(0xFFEAB308));
    return const Icon(Icons.notifications_rounded, size: s, color: Color(0xFF9CA3AF));
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

const _kAmber  = Color(0xFFD97706);
const _kOrange = Color(0xFFF97316);
