import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import '../../services/api_service.dart';
import '../../services/cached_repository.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/no_cached_data_widget.dart';

// OFFLINE-FIRST — funguo za diski za CachedRepository.
//   page:admin/dashboard → {'stats','reports','events'} (bundle moja)
//   page:admin/dashboard/users → orodha ya watumiaji (tab ya 2)
//   page:admin/dashboard/depts → orodha ya idara (vichujio)
const _kDashKey = 'page:admin/dashboard';
const _kDashUsersKey = 'page:admin/dashboard/users';
const _kDashDeptsKey = 'page:admin/dashboard/depts';

// ─── Colors ──────────────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kAmber   = Color(0xFFD97706);
const _kRed     = Color(0xFFDC2626);
const _kOrange  = Color(0xFFF97316);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey50  = Colors.white;

// ─── Page ────────────────────────────────────────────────────────────────────
class AdminDashboardPage extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const AdminDashboardPage({super.key, this.onNavigate});
  @override
  State<AdminDashboardPage> createState() => _State();
}

class _State extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  bool   _loading = true; // bado tuna diski KABISA
  Map<String, dynamic> _stats   = {};
  Map<String, dynamic> _reports = {};
  List<dynamic>        _events  = [];
  late TabController   _tabCtrl;

  // Filters — same as web's Overview component
  String        _region     = '';
  String        _dept       = '';
  String        _level      = '';
  List<dynamic> _departments = [];

  // Users tab state
  bool          _usersLoading = false;
  List<dynamic> _usersList    = [];
  int           _usersTotal   = 0;

  @override
  void initState() {
    super.initState();
    CachedRepository().addListener(_onRepoChange);
    // DISKI PAPO HAPO — dashibodi na idara kwenye frame ya KWANZA
    // (hakuna spring, hakuna kusubiri mtandao).
    final repo = CachedRepository();
    repo.hydrate(_kDashKey, _applyDash);
    repo.hydrate(_kDashDeptsKey, _applyDepts);
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging &&
          _tabCtrl.index == 1 &&
          _usersList.isEmpty) {
        _loadUsers();
      }
    });
    _load();
    _loadDepts();
  }

  @override
  void dispose() {
    CachedRepository().removeListener(_onRepoChange);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: data ya diski inabaki.
    await CachedRepository().loadPage(_kDashKey, _fetchAll, _applyDash);
    await _loadDepts();
  }

  /// Diski/API → dashibodi (SYNC: frame ya kwanza, hakuna spring).
  void _applyDash(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final m = data as Map;
    setState(() {
      _stats = asMapOrNull(m['stats']) ?? {};
      _reports = asMapOrNull(m['reports']) ?? {};
      final d = asMapOrNull(m['events']) ?? <String, dynamic>{};
      // Kama web dashboard: chuja presence ("Mtumiaji ameingia mtandaoni")
      // KABLA ya kuchukua 6 — matukio halisi (amejiunga, match, malipo...)
      // yabakiye yanaonekana.
      final all = (d['events'] as List?) ?? [];
      _events = all.where((e) {
        final ev = asMap(e);
        final type = '${ev['event_type'] ?? ev['type'] ?? ''}';
        return !['user.presence', 'user.online', 'user.offline',
                 'user.connected', 'user.disconnected'].contains(type);
      }).toList();
      _loading = false;
    });
  }

  /// API za ukurasa huu — huitwa na CachedRepository nyuma ya pazia.
  Future<Map<String, dynamic>> _fetchAll() async {
    final s = await ApiService().adminStats();
    final r = await ApiService().adminReports(
      region: _region.isEmpty   ? null : _region,
      category: _dept.isEmpty   ? null : _dept,
      level: _level.isEmpty     ? null : _level,
    );
    final e = await ApiService().adminEvents(limit: 30);
    return {'stats': s.data, 'reports': r.data, 'events': e.data};
  }

  /// Vichujio (mkoa/idara/ngazi) vimetofautisha — pakia bundle mpya (diski
  /// kwanza kama kawaida, kisha refresh nyuma ya pazia).
  Future<void> _loadReports() => _load();

  Future<void> _loadDepts() async {
    await CachedRepository()
        .loadPage(_kDashDeptsKey,
            () async => (await ApiService().adminListData('departments')).data,
            _applyDepts);
  }

  void _applyDepts(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final d = data;
    setState(() {
      _departments = d is List
          ? d
          : ((asMap(d)['results'] ?? asMap(d)['items'] ?? []) as List);
    });
  }

  Future<void> _loadUsers({String? q}) async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Funguo ina utafutaji (q) — kila q ni funguo tofauti ya diski; utafutaji
    // mpya bila diski unaonyesha "haijapakuliwa" hadi API ijibu.
    final key = q == null || q.isEmpty ? _kDashUsersKey : '$_kDashUsersKey?q=$q';
    setState(() => _usersLoading = true);
    await CachedRepository().loadPage(key,
        () async =>
            (await ApiService().adminUsers(params: {'limit': 100, if (q != null && q.isNotEmpty) 'q': q})).data,
        (data) async {
      if (!mounted || data == null) {
        if (mounted && CachedRepository().readOrNull<dynamic>(key) == null) {
          setState(() => _usersLoading = false);
        }
        return; // API imeshindwa na hakuna diski → widget ya NoCachedData
      }
      final raw = data;
      final list = raw is List
          ? raw
          : (asMap(raw)['users'] ?? asMap(raw)['data'] ?? asMap(raw)['results'] ?? []) as List;
      if (!mounted) return;
      setState(() {
        _usersList   = list;
        _usersTotal  = raw is Map ? ((raw['total'] as num?)?.toInt() ?? list.length) : list.length;
        _usersLoading = false;
      });
    });
    if (mounted && _usersLoading) setState(() => _usersLoading = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totals  = asMapOrNull(_stats['totals']) ?? {};
    final regTot  = (_reports['regions_total'] as num?)?.toInt();

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF0F172A)
          : Ad.card(context),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Panel',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                                  color: Ad.ink(context), height: 7 / 6)),
                          SizedBox(height: 4),
                          Text('Muhtasari wa mfumo',
                              style: TextStyle(fontSize: 14, color: Ad.muted(context), height: 10 / 7)),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Ad.card(context),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Ad.border(context)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 8, height: 8,
                            child: DecoratedBox(decoration: BoxDecoration(
                                color: Color(0xFFD1D5DB), shape: BoxShape.circle))),
                        SizedBox(width: 6),
                        Text('Live',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: Ad.muted(context), height: 1.5)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading && _stats.isEmpty)
              const SliverFillRemaining(child: NoCachedDataWidget())
            else ...[
              // ── Top 3 Big cards ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(children: [
                    Expanded(child: _BigCard(
                      value: '${totals['users'] ?? 0}',
                      label: 'Watumiaji',
                      color: _kBlue,
                      sub: '+${totals['users_active_7d'] ?? 0} wiki 7',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _BigCard(
                      value: '${totals['users_verified'] ?? 0}',
                      label: 'Wanaolipa',
                      color: _kAmber,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _BigCard(
                      value: regTot != null ? '$regTot' : '—',
                      label: 'Mikoa',
                      color: _kGreen,
                    )),
                  ]),
                ),
              ),

              // ── Recent Activity ──────────────────────────────────────────
              if (_events.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildRecentActivity(),
                  ),
                ),

              // ── Tabs ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Ad.card(context),
                    border: Border(bottom: BorderSide(color: Ad.border(context))),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    labelColor: _kBlue,
                    unselectedLabelColor: Ad.muted(context),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, height: 10 / 7),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, height: 10 / 7),
                    indicator: const UnderlineTabIndicator(
                        borderSide: BorderSide(color: _kBlue, width: 2)),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(height: 40, child: Text('Muhtasari')),
                      Tab(height: 40, child: Text('Watumiaji')),
                    ],
                  ),
                ),
              ),

              // ── Tab body ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: _tabCtrl,
                  builder: (ctx, snap) => _tabCtrl.index == 0
                      ? _buildOverview()
                      : _buildUsersTab(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Recent Activity ────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ad.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Ad.tile(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notifications_rounded, size: 15, color: Ad.ink(context)),
            SizedBox(width: 6),
            Flexible(
              child: Text('Matukio ya Hivi Karibuni',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Ad.ink(context), height: 1.5)),
            ),
          ]),
          const SizedBox(height: 10),
          ..._events.take(6).map((e) {
            final m = asMap(e);
            final type = m['event_type'] as String? ?? '';
            final time = m['occurred_at'] as String? ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Ad.tile(context), width: 1))),
              child: Row(children: [
                _eventIcon(type),
                SizedBox(width: 8),
                Expanded(
                  child: Text(_eventTitle(type),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                          color: Ad.inkStrong(context), height: 4 / 3),
                      overflow: TextOverflow.ellipsis),
                ),
                SizedBox(width: 6),
                Text(_fmtTime(time),
                    style: TextStyle(fontSize: 10, color: Ad.muted2(context), height: 1.5)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ── Overview tab ───────────────────────────────────────────────────────────

  Widget _buildOverview() {
    final usersByRegion     = (_reports['users_by_region']     as List? ?? []).cast<Map>();
    final incomingByRegion  = (_reports['incoming_by_region']  as List? ?? []).cast<Map>();
    final usersByDistrict   = (_reports['users_by_district']   as List? ?? []).cast<Map>();
    final incomingByDistrict = (_reports['incoming_by_district'] as List? ?? []).cast<Map>();
    final incomingSources   = (_reports['incoming_sources']    as List? ?? []).cast<Map>();
    final rawCadre          = (_reports['users_by_cadre']      as List? ?? []).cast<Map>();
    final rawCategory       = (_reports['users_by_category']   as List? ?? []).cast<Map>();
    final rawStatus         = (_reports['users_by_status']     as List? ?? []).cast<Map>();

    // Sort descending
    final byCadre    = [...rawCadre]   ..sort((a, b) => ((b['count'] as int? ?? 0) - (a['count'] as int? ?? 0)));
    final byCategory = [...rawCategory]..sort((a, b) => ((b['count'] as int? ?? 0) - (a['count'] as int? ?? 0)));
    final byStatus   = [...rawStatus]  ..sort((a, b) => ((b['count'] as int? ?? 0) - (a['count'] as int? ?? 0)));

    // Cadre level totals
    int cadreP = 0, cadreS = 0, cadreN = 0;
    for (final c in byCadre) {
      final cnt = (c['count'] as int?) ?? 0;
      final l   = c['level'] as String? ?? '';
      if (l == 'Primary')        { cadreP += cnt; }
      else if (l == 'Secondary') { cadreS += cnt; }
      else                       { cadreN += cnt; }
    }

    // Unique region names from both lists
    final allNames = <String>{};
    for (final r in usersByRegion)   { final n = r['region'] as String? ?? ''; if (n.isNotEmpty) allNames.add(n); }
    for (final r in incomingByRegion){ final n = r['region'] as String? ?? ''; if (n.isNotEmpty) allNames.add(n); }

    // Merged region rows filtered by selected region
    final byRegion = allNames
        .where((name) => _region.isEmpty || name == _region)
        .map((name) {
          final cur = usersByRegion.where((r) => r['region'] == name)
              .map((r) => (r['count'] as int?) ?? 0).firstOrNull ?? 0;
          final inc = incomingByRegion.where((r) => r['region'] == name)
              .map((r) => (r['count'] as int?) ?? 0).firstOrNull ?? 0;
          return _RRow(name, '', cur, inc);
        })
        .toList()
        ..sort((a, b) => (b.current + b.incoming) - (a.current + a.incoming));

    // District rows
    final byDistrict = usersByDistrict.map((d) {
      final reg  = d['region']   as String? ?? '';
      final dist = d['district'] as String? ?? '';
      final cur  = (d['count'] as int?) ?? 0;
      final inc  = incomingByDistrict
          .where((x) => x['district'] == dist && x['region'] == reg)
          .map((x) => (x['count'] as int?) ?? 0)
          .firstOrNull ?? 0;
      return _RRow(reg, dist, cur, inc);
    })
    .where((r) => r.current + r.incoming > 0)
    .toList()
    ..sort((a, b) => (b.current + b.incoming) - (a.current + a.incoming));

    // Totals for this filtered view
    final regTotal  = (_reports['regions_total']   as num?)?.toInt() ?? allNames.length;
    final distTotal = (_reports['districts_total'] as num?)?.toInt() ?? byDistrict.length;
    final usrTotal  = byRegion.fold(0, (s, r) => s + r.current);
    final incTotal  = incomingByRegion.fold<int>(0, (s, r) => s + ((r['count'] as int?) ?? 0));

    // Department name lookup
    String deptName(String code) {
      if (code.isEmpty) return '—';
      for (final d in _departments) {
        final dm = d as Map;
        if (dm['code'] == code) {
          final ico  = dm['icon'] as String? ?? '';
          final name = dm['name'] as String? ?? code;
          return ico.isNotEmpty ? '$ico $name' : name;
        }
      }
      return code;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 3 Filter dropdowns ─────────────────────────────────────────
          _filterDrop(
            icon: TablerIcons.map2,
            value: _region,
            items: [
              const DropdownMenuItem(value: '', child: Text('Mikoa yote')),
              ...(allNames.toList()..sort()).map((n) => DropdownMenuItem(value: n, child: Text(n))),
            ],
            onChanged: (v) { setState(() => _region = v ?? ''); _loadReports(); },
          ),
          const SizedBox(height: 8),
          _filterDrop(
            icon: TablerIcons.building,
            value: _dept,
            items: [
              const DropdownMenuItem(value: '', child: Text('Idara zote')),
              ..._departments.map((d) {
                final dm  = d as Map;
                final code = dm['code'] as String? ?? '';
                final ico  = dm['icon'] as String? ?? '';
                final name = dm['name'] as String? ?? code;
                return DropdownMenuItem(value: code,
                    child: Text(ico.isNotEmpty ? '$ico $name' : name));
              }),
            ],
            onChanged: (v) { setState(() => _dept = v ?? ''); _loadReports(); },
          ),
          const SizedBox(height: 8),
          _filterDrop(
            icon: TablerIcons.school,
            value: _level,
            items: const [
              DropdownMenuItem(value: '',          child: Text('Viwango vyote')),
              DropdownMenuItem(value: 'Primary',   child: Text('Primary (Msingi)')),
              DropdownMenuItem(value: 'Secondary', child: Text('Secondary (Sekondari)')),
            ],
            onChanged: (v) { setState(() => _level = v ?? ''); _loadReports(); },
          ),

          const SizedBox(height: 12),

          // ── 4 Big numbers ───────────────────────────────────────────────
          Row(children: [
            Expanded(child: _BigCard(value: '$regTotal',  label: 'Mikoa',       color: _kBlue)),
            const SizedBox(width: 8),
            Expanded(child: _BigCard(value: '$distTotal', label: 'Wilaya',      color: _kAmber)),
            const SizedBox(width: 8),
            Expanded(child: _BigCard(value: '$usrTotal',  label: 'Waliopo',     color: _kGreen)),
            const SizedBox(width: 8),
            Expanded(child: _BigCard(value: '$incTotal',  label: 'Wanaohamia',  color: _kOrange)),
          ]),

          const SizedBox(height: 12),

          // ── By department + By status ───────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _card('Kwa Idara', _NumberTable(
              rows: byCategory.map((c) => _NRow(
                  deptName(c['category'] as String? ?? ''),
                  (c['count'] as int?) ?? 0)).toList(),
            ))),
            const SizedBox(width: 12),
            Expanded(child: _card('Kwa Hali', _NumberTable(
              rows: byStatus.map((s) => _NRow(
                  s['status'] as String? ?? '', (s['count'] as int?) ?? 0)).toList(),
            ))),
          ]),

          const SizedBox(height: 12),

          // ── Regions table ───────────────────────────────────────────────
          _card('Takwimu za Mikoa',
            _RegionDistrictTable(
              rows: byRegion,
              showRegion: true,
              showBar: true,
              regionHeader: 'Mkoa',
            ),
          ),

          const SizedBox(height: 12),

          // ── Districts table ─────────────────────────────────────────────
          _card(
            _region.isNotEmpty ? 'Wilaya — $_region' : 'Takwimu za Wilaya',
            _RegionDistrictTable(
              rows: byDistrict,
              showRegion: _region.isEmpty,
              showBar: false,
              regionHeader: _region.isEmpty ? 'Mkoa / Wilaya' : 'Wilaya',
            ),
          ),

          const SizedBox(height: 12),

          // ── Cadre level ─────────────────────────────────────────────────
          _card('Kwa Kiwango', _NumberTable(rows: [
            _NRow('Walimu wa Msingi',    cadreP),
            _NRow('Walimu wa Sekondari', cadreS),
            _NRow('Bila kiwango',        cadreN),
          ])),

          const SizedBox(height: 12),

          // ── Cadre + Incoming sources ────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _card('Kwa Kada', _NumberTable(
              rows: byCadre.take(20).map((c) {
                final name  = c['cadre_name'] as String? ?? c['cadre'] as String? ?? '';
                final level = c['level'] as String? ?? '';
                return _NRow(level.isNotEmpty ? '$name ($level)' : name,
                    (c['count'] as int?) ?? 0);
              }).toList(),
              scrollable: true,
            ))),
            const SizedBox(width: 12),
            Expanded(child: _card(
              _region.isNotEmpty ? 'Wanakuja — $_region' : 'Wanaohamia',
              _IncomingTable(rows: incomingSources),
            )),
          ]),
        ],
      ),
    );
  }

  // ── Users tab ──────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (q) => _loadUsers(q: q),
            style: TextStyle(fontSize: 14, color: Ad.ink(context)),
            decoration: InputDecoration(
              hintText: 'Tafuta jina, simu, kada...',
              hintStyle: TextStyle(fontSize: 14, color: Ad.muted(context)),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: Ad.muted(context)),
              filled: true, fillColor: Ad.card(context), isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Ad.border(context))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Ad.border(context))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kBlue)),
            ),
          ),
          SizedBox(height: 8),
          Text('Jumla: $_usersTotal',
              style: TextStyle(fontSize: 12, color: Ad.muted(context), height: 4 / 3)),
          const SizedBox(height: 8),
          if (_usersLoading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(color: _kBlue),
            ))
          else if (_usersList.isEmpty)
            Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('Hakuna watumiaji',
                  style: TextStyle(fontSize: 14, color: Ad.muted(context))),
            ))
          else
            Container(
              decoration: BoxDecoration(
                color: Ad.card(context),
                border: Border.all(color: Ad.tile(context)),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: _usersList.asMap().entries.map((entry) {
                  final last = entry.key == _usersList.length - 1;
                  final m    = asMap(entry.value);
                  final name = m['full_name'] as String? ?? '';
                  final phone = m['phone_primary'] as String? ?? '';
                  final cadre = m['cadre_code'] as String? ?? m['cadre_display'] as String? ?? '';
                  final station = m['current_station'] as Map? ?? {};
                  final region  = station['region_name'] as String? ?? '';
                  final dests = (m['desired_destinations'] as List?)
                      ?.whereType<Map>()
                      .map((d) => d['region_name'] as String? ?? '')
                      .where((s) => s.isNotEmpty)
                      .join(', ') ?? '';
                  final isAdmin = m['is_admin'] as bool? ?? false;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: last ? null : Border(bottom: BorderSide(color: Ad.tile(context))),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(name,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: Ad.ink(context), height: 4 / 3),
                                overflow: TextOverflow.ellipsis)),
                            if (isAdmin) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_user_rounded, size: 13, color: _kBlue),
                            ],
                          ]),
                          Text(phone,
                              style: TextStyle(fontSize: 12, color: _kBlue, height: 4 / 3,
                                  fontWeight: FontWeight.w600)),
                          if (dests.isNotEmpty)
                            Text(dests,
                                style: TextStyle(fontSize: 10, color: Ad.muted(context), height: 1.5),
                                overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (cadre.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Ad.blueSoft(context), borderRadius: BorderRadius.circular(4)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.menu_book_outlined, size: 10, color: _kBlue),
                              const SizedBox(width: 3),
                              Flexible(child: Text(cadre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                      color: _kBlue, height: 1.5))),
                            ]),
                          ),
                        if (region.isNotEmpty)
                          Text(region,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Ad.muted(context), height: 1.5)),
                      ]),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _card(String title, Widget body) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Ad.card(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Ad.border(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: Ad.ink(context), height: 4 / 3)),
        const SizedBox(height: 8),
        body,
      ],
    ),
  );

  Widget _filterDrop({
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, size: 17, color: _kBlue),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 44),
      filled: true, fillColor: Ad.card(context),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Ad.border(context))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Ad.border(context))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _kBlue)),
    ),
    style: TextStyle(fontSize: 13.5, color: Ad.ink(context)),
    items: items,
    onChanged: onChanged,
  );

  static Widget _eventIcon(String type) {
    const s = 14.0;
    if (type == 'user.registered')           return const Icon(Icons.person_add_rounded, size: s, color: Color(0xFF3B82F6));
    if (type.startsWith('payment.'))         return const Icon(Icons.payments_rounded, size: s, color: Color(0xFF16A34A));
    if (type.startsWith('feedback.'))        return const Icon(Icons.assignment_rounded, size: s, color: Color(0xFFF97316));
    if (type.startsWith('password_reset.'))  return const Icon(Icons.lock_reset_rounded, size: s, color: Color(0xFF7C3AED));
    if (type.startsWith('match.'))           return const Icon(Icons.favorite_rounded, size: s, color: Color(0xFF16A34A));
    if (type.startsWith('data.'))            return const Icon(Icons.bolt_rounded, size: s, color: Color(0xFFF59E0B));
    return const Icon(Icons.notifications_rounded, size: s, color: Color(0xFF9CA3AF));
  }

  static String _eventTitle(String type) {
    switch (type) {
      case 'user.registered':          return 'Mtumiaji mpya amejiunga';
      case 'payment.submitted':        return 'Malipo yamewasilishwa';
      case 'payment.approved':         return 'Malipo yamekubaliwa';
      case 'payment.rejected':         return 'Malipo yamekataliwa';
      case 'feedback.new':             return 'Maoni mapya';
      case 'feedback.replied':         return 'Maoni yamejibiwa';
      case 'match.found':              return 'Match mpya imepatikana';
      case 'data.changed':             return 'Data imebadilishwa';
      case 'password_reset.requested': return 'Ombi la kubadilisha nenosiri';
      default: return type.replaceAll('.', ' ').replaceAll('_', ' ');
    }
  }

  static String _fmtTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

// ─── Data models (simple records) ────────────────────────────────────────────

class _NRow {
  final String label;
  final int count;
  const _NRow(this.label, this.count);
}

class _RRow {
  final String region;
  final String district;
  final int current;
  final int incoming;
  const _RRow(this.region, this.district, this.current, this.incoming);
}

// ─── Big card ─────────────────────────────────────────────────────────────────

class _BigCard extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  final String? sub;
  const _BigCard({required this.value, required this.label, required this.color, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Ad.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Ad.border(context)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color, height: 7 / 6),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Ad.muted(context), height: 4 / 3)),
        if (sub != null) ...[
          SizedBox(height: 2),
          Text(sub!, style: TextStyle(fontSize: 10, color: Ad.muted2(context), height: 1.5)),
        ],
      ]),
    );
  }
}

// ─── Number table (# | Name | % | Count) ─────────────────────────────────────

class _NumberTable extends StatelessWidget {
  final List<_NRow> rows;
  final bool scrollable;
  const _NumberTable({required this.rows, this.scrollable = false});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Hakuna data', style: TextStyle(fontSize: 13, color: Ad.muted(context))),
      );
    }
    final total = rows.fold(0, (s, r) => s + r.count);
    final safeTotal = total == 0 ? 1 : total;

    Widget content = Column(
      children: [
        // Header
        _hdr(context),
        // Rows
        ...rows.map((r) {
          final pct = ((r.count / safeTotal) * 100).round();
          return _row(r, pct, context);
        }),
        // Footer
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Ad.tile(context)))),
          child: Row(children: [
            Expanded(child: Text('Jumla',
                style: TextStyle(fontSize: 12, color: Ad.muted(context)))),
            Text('$total',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Ad.ink(context))),
          ]),
        ),
      ],
    );

    if (scrollable) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: SingleChildScrollView(child: content),
      );
    }
    return content;
  }

  Widget _hdr(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ad.tile(context)))),
    child: Row(children: [
      SizedBox(width: 24, child: Text('#',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
          textAlign: TextAlign.center)),
      SizedBox(width: 6),
      Expanded(child: Text('Jina',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)))),
      SizedBox(width: 6,
          child: Text('%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
              textAlign: TextAlign.right)),
      SizedBox(width: 40,
          child: Text('Idadi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
              textAlign: TextAlign.right)),
    ]),
  );

  Widget _row(_NRow r, int pct, BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ad.tile(context)))),
    child: Row(children: [
      SizedBox(width: 24, child: Text('${rows.indexOf(r) + 1}',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
          textAlign: TextAlign.center)),
      SizedBox(width: 6),
      Expanded(child: Text(r.label,
          style: TextStyle(fontSize: 13, color: Ad.inkStrong(context), height: 4 / 3),
          overflow: TextOverflow.ellipsis)),
      SizedBox(width: 32, child: Text('$pct%',
          style: TextStyle(fontSize: 11, color: Ad.muted2(context)),
          textAlign: TextAlign.right)),
      SizedBox(width: 40, child: Text('${r.count}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kBlue),
          textAlign: TextAlign.right)),
    ]),
  );
}

// ─── Region / District table ──────────────────────────────────────────────────

class _RegionDistrictTable extends StatelessWidget {
  final List<_RRow> rows;
  final bool showRegion;
  final bool showBar;
  final String regionHeader;
  const _RegionDistrictTable({
    required this.rows,
    required this.showRegion,
    required this.showBar,
    required this.regionHeader,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Hakuna data', style: TextStyle(fontSize: 13, color: Ad.muted(context))),
      );
    }
    final maxTotal = rows.fold(1, (m, r) => m > r.current + r.incoming ? m : r.current + r.incoming);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ad.tile(context)))),
          child: Row(children: [
            SizedBox(width: 20, child: Text('#',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
                textAlign: TextAlign.center)),
            SizedBox(width: 6),
            Expanded(child: Text(regionHeader,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)))),
            SizedBox(width: 44, child: Text('Waliopo',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
                textAlign: TextAlign.right)),
            SizedBox(width: 48, child: Text('Wanaohamia',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
                textAlign: TextAlign.right)),
            if (!showBar) SizedBox(width: 40, child: Text('Jumla',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
                textAlign: TextAlign.right)),
            if (showBar) const SizedBox(width: 40),
          ]),
        ),
        // Rows
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final total = r.current + r.incoming;
          final label = showRegion ? (r.district.isNotEmpty ? '${r.region} — ${r.district}' : r.region) : (r.district.isNotEmpty ? r.district : r.region);
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ad.tile(context)))),
            child: Row(children: [
              SizedBox(width: 20, child: Text('${i + 1}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)),
                  textAlign: TextAlign.center)),
              SizedBox(width: 6),
              Expanded(child: Text(label,
                  style: TextStyle(fontSize: 12, color: Ad.inkStrong(context), height: 4 / 3),
                  overflow: TextOverflow.ellipsis)),
              SizedBox(width: 44, child: Text('${r.current}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Ad.inkStrong(context)),
                  textAlign: TextAlign.right)),
              SizedBox(width: 48, child: Text('${r.incoming}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kOrange),
                  textAlign: TextAlign.right)),
              if (!showBar)
                SizedBox(width: 40, child: Text('$total',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kBlue),
                    textAlign: TextAlign.right)),
              if (showBar)
                SizedBox(width: 40, child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: total / maxTotal,
                      backgroundColor: Ad.tile(context),
                      valueColor: const AlwaysStoppedAnimation<Color>(_kBlue),
                      minHeight: 5,
                    ),
                  ),
                )),
            ]),
          );
        }),
      ],
    );
  }
}

// ─── Incoming sources table ───────────────────────────────────────────────────

class _IncomingTable extends StatelessWidget {
  final List<Map> rows;
  const _IncomingTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Hakuna data', style: TextStyle(fontSize: 13, color: Ad.muted(context))),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ad.tile(context)))),
          child: Row(children: [
            // Flexible columns — simu ndogo (320px) isifuruge (overflow guard)
            Text('#',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context))),
            SizedBox(width: 6),
            Flexible(
                flex: 3,
                child: Text('Kutoka',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context)))),
            Flexible(
                flex: 2,
                child: Text('Kwenda',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Ad.muted2(context)))),
            SizedBox(width: 8),
            Text('Idadi',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Ad.muted2(context)),
                textAlign: TextAlign.right),
          ]),
        ),
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Ad.tile(context)))),
            child: Row(children: [
              Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: Ad.muted2(context))),
              SizedBox(width: 6),
              Flexible(
                  flex: 3,
                  child: Text(s['from'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Ad.inkStrong(context), height: 4 / 3))),
              Flexible(
                  flex: 2,
                  child: Text(s['to'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: _kOrange))),
              const SizedBox(width: 8),
              Text('${s['count'] ?? 0}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _kBlue),
                  textAlign: TextAlign.right),
            ]),
          );
        }),
      ],
    );
  }
}
