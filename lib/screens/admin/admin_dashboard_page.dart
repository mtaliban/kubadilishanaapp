import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';

// ── Exact brand colors from globals.css ───────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);  // brand-blue
const _kBlue50  = Color(0xFFEFF6FF);  // brand-blue-50
const _kOrange  = Color(0xFFEA580C);  // brand-orange = #EA580C (light mode)
const _kGold    = Color(0xFFF59E0B);  // brand-gold   = #F59E0B
const _kGreen   = Color(0xFF22C55E);  // green-500 (brand-green fallback = Tailwind green-500)
const _kGrey900 = Color(0xFF111827);  // brand-grey-900
const _kGrey700 = Color(0xFF374151);  // brand-grey-700
const _kGrey500 = Color(0xFF6B7280);  // brand-grey-500
const _kGrey400 = Color(0xFF9CA3AF);  // brand-grey-400
const _kGrey300 = Color(0xFFD1D5DB);  // brand-grey-300
const _kGrey200 = Color(0xFFE5E7EB);  // brand-grey-200
const _kGrey100 = Color(0xFFF3F4F6);  // brand-grey-100  ← card border
const _kGrey50  = Color(0xFFF9FAFB);  // brand-grey-50   ← page bg

// .card = bg-white rounded-2xl shadow-soft border border-brand-grey-100 p-6
BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),          // rounded-2xl
  border: Border.all(color: _kGrey100),             // border-brand-grey-100
  boxShadow: const [BoxShadow(
    color: Color(0x0F000000),                        // rgba(0,0,0,0.06) shadow-soft
    blurRadius: 20,
    offset: Offset(0, 4),
  )],
);

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic> _stats   = {};
  Map<String, dynamic> _reports = {};
  List<dynamic> _departments    = [];
  List<dynamic> _activity       = [];
  List<dynamic> _usersTabData   = [];
  int  _usersTotal = 0;
  String _usersQ   = '';
  bool _loading    = true;
  bool _live       = false;
  int  _tab        = 0; // 0=Muhtasari 1=Watumiaji

  // Filters
  String _fRegion = '';
  String _fDept   = '';
  String _fLevel  = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadDepts();
    _loadActivity();
    _setupRealtime();
  }

  void _setupRealtime() {
    WebSocketService().onAny((_) {
      if (!mounted) return;
      setState(() => _live = true);
      _loadAll();
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _live = false);
      });
    });
  }

  Future<void> _loadAll() async {
    try {
      final r1 = await ApiService().adminStats();
      final r2 = await ApiService().adminReports(
        days: 365,
        region:   _fRegion.isNotEmpty ? _fRegion : null,
        category: _fDept.isNotEmpty   ? _fDept   : null,
        level:    _fLevel.isNotEmpty  ? _fLevel  : null,
      );
      if (!mounted) return;
      setState(() {
        _stats   = (r1.data as Map<String, dynamic>?) ?? {};
        _reports = (r2.data as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDepts() async {
    try {
      final res = await ApiService().adminListDepartments();
      if (mounted) setState(() => _departments = res.data is List ? res.data : []);
    } catch (_) {}
  }

  Future<void> _loadActivity() async {
    try {
      final res = await ApiService().getNotifications(limit: 10);
      final data = res.data;
      final List<dynamic> items = data is List ? data
          : (data['notifications'] ?? data['items'] ?? []);
      if (mounted) setState(() => _activity = items.take(6).toList());
    } catch (_) {}
  }

  Future<void> _loadUsersTab() async {
    try {
      final res = await ApiService().adminUsers(
          params: {if (_usersQ.isNotEmpty) 'q': _usersQ, 'limit': 100});
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _usersTabData = data['users'] ?? [];
          _usersTotal   = data['total'] ?? 0;
        });
      }
    } catch (_) {}
  }

  // ── Computed ──────────────────────────────────────────────────────────────
  Map<String, dynamic> get _totals =>
      (_stats['totals'] as Map<String, dynamic>?) ?? {};

  List<Map<String, dynamic>> get _byRegion {
    final cur = (_reports['users_by_region']   as List?) ?? [];
    final inc = (_reports['incoming_by_region'] as List?) ?? [];
    final names = <String>{
      ...cur.map((r) => '${r['region']}'),
      ...inc.map((r) => '${r['region']}'),
    }.where((s) => s.isNotEmpty).toList()..sort();

    return names.map((name) {
      final c = _findCount(cur, 'region', name);
      final i = _findCount(inc, 'region', name);
      return {'region': name, 'current': c, 'incoming': i};
    }).where((r) => _fRegion.isEmpty || r['region'] == _fRegion)
      .toList()
      ..sort((a, b) => (_total(b) - _total(a)));
  }

  List<Map<String, dynamic>> get _byDistrict {
    final cur = (_reports['users_by_district']    as List?) ?? [];
    final inc = (_reports['incoming_by_district'] as List?) ?? [];
    return cur.map((d) {
      final i = (inc.firstWhere(
        (x) => x['district'] == d['district'] && x['region'] == d['region'],
        orElse: () => {})['count'] ?? 0) as int;
      return {'region': '${d['region']}', 'district': '${d['district']}',
              'current': (d['count'] ?? 0) as int, 'incoming': i};
    }).where((d) => (d['current'] as int) > 0 || (d['incoming'] as int) > 0)
      .toList()
      ..sort((a, b) => (_total(b) - _total(a)));
  }

  List<dynamic> get _byCadre =>
      [...((_reports['users_by_cadre'] as List?) ?? [])]
        ..sort((a, b) => (_cnt(b) - _cnt(a)));

  List<dynamic> get _byCategory =>
      [...((_reports['users_by_category'] as List?) ?? [])]
        ..sort((a, b) => (_cnt(b) - _cnt(a)));

  List<dynamic> get _byStatus =>
      [...((_reports['users_by_status'] as List?) ?? [])]
        ..sort((a, b) => (_cnt(b) - _cnt(a)));

  List<dynamic> get _incomingSources =>
      (_reports['incoming_sources'] as List?) ?? [];

  int _findCount(List<dynamic> list, String key, String val) =>
      (list.firstWhere((r) => r[key] == val, orElse: () => {})['count'] ?? 0) as int;

  int _total(Map m) => ((m['current'] ?? 0) as int) + ((m['incoming'] ?? 0) as int);
  int _cnt(dynamic r) => (r['count'] ?? 0) as int;

  String _deptName(String code) {
    if (code.isEmpty) return '-';
    final d = _departments.firstWhere((d) => d['code'] == code, orElse: () => null);
    if (d == null) return code;
    final icon = (d['icon'] ?? '') as String;
    final name = (d['name'] ?? code) as String;
    return icon.isNotEmpty ? '$icon $name' : name;
  }

  Map<String, int> get _cadreLevel {
    int primary = 0, secondary = 0, none = 0;
    for (final c in (_reports['users_by_cadre'] as List?) ?? []) {
      final lvl = (c['level'] ?? '') as String;
      final cnt = (c['count'] ?? 0) as int;
      if (lvl == 'Primary') { primary += cnt; }
      else if (lvl == 'Secondary') { secondary += cnt; }
      else { none += cnt; }
    }
    return {'primary': primary, 'secondary': secondary, 'none': none};
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
            SizedBox(height: 8),
            Text('Inapakia...', style: TextStyle(fontSize: 13, color: _kGrey400)),
          ])));
    }

    final regsTotal = _reports['regions_total'] ?? _byRegion.length;
    final distTotal = _reports['districts_total'] ?? _byDistrict.length;
    final usersTotal = _byRegion.fold<int>(0, (s, r) => s + (r['current'] as int));
    final incomTotal = _byRegion.fold<int>(0, (s, r) => s + (r['incoming'] as int));

    // p-4 space-y-6 → 16px padding, 24px between sections
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _kBlue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // p-4 + pb-20
        children: [

          // ── 1. HEADER ─────────────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Admin Panel',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kGrey900)),
              const SizedBox(height: 4),
              const Text('Takwimu na usimamizi wa mfumo',
                style: TextStyle(fontSize: 13, color: _kGrey500)),
            ])),
            _LiveBadge(live: _live),
          ]),
          const SizedBox(height: 24), // space-y-6

          // ── 2. BIG TOP CARDS (3) — grid-cols-2 mobile: 3rd card half-width ──
          LayoutBuilder(builder: (ctx, cst) {
            final w = (cst.maxWidth - 12) / 2; // gap-3=12px
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: w, child: _BigCard(
                color: _kBlue, value: '${_totals['users'] ?? 0}',
                label: 'Watumiaji',
                sub: '+${_totals['users_active_7d'] ?? 0} hai 7d')),
              SizedBox(width: w, child: _BigCard(
                color: _kGold, value: '${_totals['users_verified'] ?? 0}',
                label: 'Waliolipia')),
              SizedBox(width: w, child: _BigCard(
                color: _kGreen, value: '$regsTotal', label: 'Mikoa (jumla)')),
            ]);
          }),
          const SizedBox(height: 24), // space-y-6

          // ── 3. RECENT ACTIVITY ────────────────────────────────────────────
          if (_activity.isNotEmpty) ...[
            _RecentActivityCard(events: _activity),
            const SizedBox(height: 24),
          ],

          // ── 4. TABS ───────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kGrey200))),
            child: Row(children: [
              _TabBtn(label: 'Muhtasari', active: _tab == 0,
                onTap: () => setState(() => _tab = 0)),
              _TabBtn(label: 'Watumiaji', active: _tab == 1,
                onTap: () {
                  setState(() => _tab = 1);
                  if (_usersTabData.isEmpty) _loadUsersTab();
                }),
            ]),
          ),
          const SizedBox(height: 24),

          // ── 5. CONTENT ────────────────────────────────────────────────────
          if (_tab == 0) ...[

            // 5a. Filters row (3 dropdowns) kama web
            _FiltersRow(
              allRegions:  _byRegion.map((r) => r['region'] as String).toList(),
              departments: _departments,
              fRegion: _fRegion, fDept: _fDept, fLevel: _fLevel,
              onRegion: (v) { setState(() => _fRegion = v); _loadAll(); },
              onDept:   (v) { setState(() => _fDept   = v); _loadAll(); },
              onLevel:  (v) { setState(() => _fLevel  = v); _loadAll(); },
            ),
            const SizedBox(height: 24),

            // 5b. Second row of 4 big numbers (kama web grid-cols-2)
            Row(children: [
              Expanded(child: _BigCard(color: _kBlue,   value: '$regsTotal',  label: 'Mikoa')),
              const SizedBox(width: 12),
              Expanded(child: _BigCard(color: _kGold,   value: '$distTotal',  label: 'Wilaya')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _BigCard(color: _kGreen,  value: '$usersTotal', label: 'Watumiaji')),
              const SizedBox(width: 12),
              Expanded(child: _BigCard(color: _kOrange, value: '$incomTotal', label: 'Wanaohamia')),
            ]),
            const SizedBox(height: 24),

            // 5c. By Department + By Status (2 cards kama web grid-cols-2)
            _SCard(title: 'Kwa Idara',
              child: _NumberTable(rows: _byCategory.map((c) =>
                _NRow(_deptName('${c['category'] ?? ''}'), _cnt(c))).toList())),
            const SizedBox(height: 12),
            _SCard(title: 'Kwa Hali',
              child: _NumberTable(rows: _byStatus.map((s) =>
                _NRow('${s['status'] ?? ''}', _cnt(s))).toList())),
            const SizedBox(height: 24),

            // 5d. Mikoa table (with progress bar)
            _SCard(
              title: 'Takwimu za Mikoa',
              subtitle: 'Waliopo + Wanaohamia kila mkoa',
              child: _RegionsTable(rows: _byRegion)),
            const SizedBox(height: 12),

            // 5e. Wilaya table
            _SCard(
              title: 'Kwa Wilaya${_fRegion.isNotEmpty ? " — $_fRegion" : ""}',
              child: _DistrictsTable(rows: _byDistrict, filterRegion: _fRegion)),
            const SizedBox(height: 24),

            // 5f. Cadre level
            _SCard(title: 'Kwa Ngazi ya Kada',
              child: _NumberTable(rows: [
                _NRow('Walimu wa Msingi (Primary)', _cadreLevel['primary'] ?? 0),
                _NRow('Walimu wa Sekondari (Secondary)', _cadreLevel['secondary'] ?? 0),
                _NRow('Bila Ngazi', _cadreLevel['none'] ?? 0),
              ])),
            const SizedBox(height: 12),

            // 5g. By Cadre + Incoming Sources
            _SCard(title: 'Kwa Kada (20 za juu)',
              child: _NumberTable(
                maxH: true,
                rows: _byCadre.take(20).map((c) {
                  final name = (c['cadre_name'] ?? c['cadre'] ?? '') as String;
                  final lvl  = (c['level'] ?? '') as String;
                  return _NRow(lvl.isNotEmpty ? '$name ($lvl)' : name, _cnt(c));
                }).toList())),
            const SizedBox(height: 12),
            _SCard(
              title: 'Wanaohamia wanatoka${_fRegion.isNotEmpty ? " — $_fRegion" : ""}',
              subtitle: 'Mkoa wa asili → Mkoa wanaotaka',
              child: _IncomingSourcesTable(rows: _incomingSources)),

          ] else ...[

            // 5h. Watumiaji tab
            _UsersTab(
              users: _usersTabData, total: _usersTotal, q: _usersQ,
              onSearch: (v) { setState(() => _usersQ = v); _loadUsersTab(); }),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LIVE BADGE — with CSS animate-pulse equivalent
// ─────────────────────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  final bool live;
  const _LiveBadge({required this.live});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // pulse 2s kama Tailwind
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // px-2.5 py-1
      decoration: BoxDecoration(
        color: live ? const Color(0xFFF0FDF4) : _kGrey50, // green-50 / grey-50
        border: Border.all(
          color: live ? const Color(0xFF86EFAC) : _kGrey200), // green-300 / grey-200
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Pulsing dot — kama animate-pulse
        AnimatedBuilder(
          animation: _anim,
          builder: (_, snap) => Opacity(
            opacity: live ? _anim.value : 1.0,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? const Color(0xFF22C55E) : _kGrey300, // green-500 / grey-300
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('LIVE', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: live ? const Color(0xFF16A34A) : _kGrey400, // green-700 / grey-400
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BIG CARD — .card with colored number
// ─────────────────────────────────────────────────────────────────────────────
class _BigCard extends StatelessWidget {
  final Color color;
  final String value;
  final String label;
  final String? sub;
  const _BigCard({required this.color, required this.value,
      required this.label, this.sub});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(
          fontSize: 30, fontWeight: FontWeight.bold, color: color,
          fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Text(label,
          style: const TextStyle(fontSize: 11, color: _kGrey500)), // text-xs text-grey-500
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!,
            style: const TextStyle(fontSize: 10, color: _kGrey400)), // text-[10px] text-grey-400
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION CARD — .card wrapper with title
// ─────────────────────────────────────────────────────────────────────────────
class _SCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SCard({required this.title, required this.child, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24), // p-6
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kGrey900)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
            style: const TextStyle(fontSize: 11, color: _kGrey500)),
        ],
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8), // px-4 py-2
          child: Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? _kBlue : _kGrey500))),
        // border-b-2 active indicator
        Container(height: 2, width: 56,
          decoration: BoxDecoration(
            color: active ? _kBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(999))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FILTERS ROW — 3 dropdowns (mkoa / idara / ngazi)
// ─────────────────────────────────────────────────────────────────────────────
class _FiltersRow extends StatelessWidget {
  final List<String>  allRegions;
  final List<dynamic> departments;
  final String fRegion, fDept, fLevel;
  final ValueChanged<String> onRegion, onDept, onLevel;
  const _FiltersRow({
    required this.allRegions, required this.departments,
    required this.fRegion, required this.fDept, required this.fLevel,
    required this.onRegion, required this.onDept, required this.onLevel,
  });
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Drop(
        value: fRegion, hint: 'Mikoa Yote',
        items: [
          const DropdownMenuItem(value: '', child: Text('Mikoa Yote', style: TextStyle(fontSize: 13))),
          ...allRegions.map((r) => DropdownMenuItem(value: r,
            child: Text(r, style: const TextStyle(fontSize: 13)))),
        ],
        onChange: onRegion,
      ),
      const SizedBox(height: 8),
      _Drop(
        value: fDept, hint: 'Idara Zote',
        items: [
          const DropdownMenuItem(value: '', child: Text('Idara Zote', style: TextStyle(fontSize: 13))),
          ...departments.map((d) {
            final icon = (d['icon'] ?? '') as String;
            final name = (d['name'] ?? d['code'] ?? '') as String;
            return DropdownMenuItem(value: '${d['code']}',
              child: Text(icon.isNotEmpty ? '$icon $name' : name,
                style: const TextStyle(fontSize: 13)));
          }),
        ],
        onChange: onDept,
      ),
      const SizedBox(height: 8),
      _Drop(
        value: fLevel, hint: 'Ngazi Zote',
        items: const [
          DropdownMenuItem(value: '', child: Text('Ngazi Zote', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'Primary',   child: Text('Primary (Msingi)', style: TextStyle(fontSize: 13))),
          DropdownMenuItem(value: 'Secondary', child: Text('Secondary (Sekondari)', style: TextStyle(fontSize: 13))),
        ],
        onChange: onLevel,
      ),
    ]);
  }
}

class _Drop extends StatelessWidget {
  final String value, hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChange;
  const _Drop({required this.value, required this.hint,
      required this.items, required this.onChange});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12), // .input = rounded-xl
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          style: const TextStyle(fontSize: 13, color: _kGrey700),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kGrey400),
          onChanged: (v) => onChange(v ?? ''),
          items: items,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NUMBER TABLE — # | Jina | % | Idadi (kama web NumberTable)
// ─────────────────────────────────────────────────────────────────────────────
class _NRow { final String label; final int count; const _NRow(this.label, this.count); }

class _NumberTable extends StatelessWidget {
  final List<_NRow> rows;
  final bool maxH;
  const _NumberTable({required this.rows, this.maxH = false});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400)));
    }
    final total     = rows.fold<int>(0, (s, r) => s + r.count);
    final safeTotal = total == 0 ? 1 : total;

    Widget content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          _hcell('#',      24),
          const SizedBox(width: 8),
          const Expanded(child: Text('JINA', style: _hStyle)),
          _hcell('%',      40, right: true),
          _hcell('IDADI',  48, right: true),
        ]),
      ),
      Container(height: 1, color: _kGrey100),
      // Rows
      ...rows.asMap().entries.map((entry) {
        final i   = entry.key;
        final r   = entry.value;
        final pct = ((r.count / safeTotal) * 100).round();
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: i < rows.length - 1
                ? const Border(bottom: BorderSide(color: _kGrey100))
                : null),
          child: Row(children: [
            SizedBox(width: 24, child: Text('${i + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kGrey400))),
            const SizedBox(width: 8),
            Expanded(child: Text(r.label,
              style: const TextStyle(fontSize: 13, color: _kGrey700),
              overflow: TextOverflow.ellipsis)),
            SizedBox(width: 40, child: Text('$pct%', textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: _kGrey400))),
            SizedBox(width: 48, child: Text('${r.count}', textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kBlue,
                fontFeatures: [FontFeature.tabularFigures()]))),
          ]),
        );
      }),
      // Total footer
      Container(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kGrey100))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Jumla', style: TextStyle(fontSize: 12, color: _kGrey500)),
          Text('$total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
            color: _kGrey900, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
    ]);

    if (maxH) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(child: content));
    }
    return content;
  }

  static const _hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kGrey400);
  static Widget _hcell(String t, double w, {bool right = false}) => SizedBox(
    width: w,
    child: Text(t, textAlign: right ? TextAlign.right : TextAlign.left, style: _hStyle));
}

// ─────────────────────────────────────────────────────────────────────────────
//  REGIONS TABLE — # | Mkoa | Waliopo | Wanaohamia | progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _RegionsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _RegionsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400));
    }
    final maxVal = rows.fold<int>(1, (m, r) {
      final t = (r['current'] as int) + (r['incoming'] as int);
      return t > m ? t : m;
    });

    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const SizedBox(width: 22, child: Text('#', style: _hSt)),
          const SizedBox(width: 8),
          const Expanded(child: Text('MKOA', style: _hSt)),
          const SizedBox(width: 64, child: Text('WALIOPO', textAlign: TextAlign.right, style: _hSt)),
          const SizedBox(width: 64, child: Text('WANAKUJA', textAlign: TextAlign.right, style: _hSt)),
          const SizedBox(width: 56), // progress bar space
        ]),
      ),
      Container(height: 1, color: _kGrey100),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(child: Column(
          children: rows.asMap().entries.map((entry) {
            final i   = entry.key;
            final r   = entry.value;
            final cur = r['current'] as int;
            final inc = r['incoming'] as int;
            final pct = (cur + inc) / maxVal;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? const Border(bottom: BorderSide(color: _kGrey100)) : null),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kGrey400))),
                const SizedBox(width: 8),
                Expanded(child: Text('${r['region']}',
                  style: const TextStyle(fontSize: 13, color: _kGrey700),
                  overflow: TextOverflow.ellipsis)),
                // Waliopo — grey-700 tabular
                SizedBox(width: 64, child: Text('$cur', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _kGrey700, fontFeatures: [FontFeature.tabularFigures()]))),
                // Wanaohamia — brand-orange tabular
                SizedBox(width: 64, child: Text('$inc', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _kOrange, fontFeatures: [FontFeature.tabularFigures()]))),
                // Progress bar — w-14 h-1.5 rounded-full bg-grey-100 / brand-blue fill
                SizedBox(width: 56, child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: _kGrey100,
                      valueColor: const AlwaysStoppedAnimation(_kBlue),
                    ),
                  ),
                )),
              ]),
            );
          }).toList(),
        )),
      ),
    ]);
  }

  static const _hSt = TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kGrey400);
}

// ─────────────────────────────────────────────────────────────────────────────
//  DISTRICTS TABLE — # | Mkoa/Wilaya | Waliopo | Wanaohamia | Jumla (bold blue)
// ─────────────────────────────────────────────────────────────────────────────
class _DistrictsTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String filterRegion;
  const _DistrictsTable({required this.rows, required this.filterRegion});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const SizedBox(width: 22, child: Text('#', style: _hSt)),
          const SizedBox(width: 8),
          Text(filterRegion.isNotEmpty ? 'WILAYA' : 'MKOA / WILAYA', style: _hSt),
          const Spacer(),
          const SizedBox(width: 64, child: Text('WALIOPO', textAlign: TextAlign.right, style: _hSt)),
          const SizedBox(width: 64, child: Text('WANAKUJA', textAlign: TextAlign.right, style: _hSt)),
          const SizedBox(width: 56, child: Text('JUMLA', textAlign: TextAlign.right, style: _hSt)),
        ]),
      ),
      Container(height: 1, color: _kGrey100),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(child: Column(
          children: rows.asMap().entries.map((entry) {
            final i   = entry.key;
            final d   = entry.value;
            final cur = d['current'] as int;
            final inc = d['incoming'] as int;
            final lbl = filterRegion.isNotEmpty
                ? '${d['district']}'
                : '${d['region']} — ${d['district']}';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? const Border(bottom: BorderSide(color: _kGrey100)) : null),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kGrey400))),
                const SizedBox(width: 8),
                Expanded(child: Text(lbl,
                  style: const TextStyle(fontSize: 12, color: _kGrey700),
                  overflow: TextOverflow.ellipsis)),
                SizedBox(width: 64, child: Text('$cur', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _kGrey700, fontFeatures: [FontFeature.tabularFigures()]))),
                SizedBox(width: 64, child: Text('$inc', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: _kOrange, fontFeatures: [FontFeature.tabularFigures()]))),
                SizedBox(width: 56, child: Text('${cur + inc}', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: _kBlue, fontFeatures: [FontFeature.tabularFigures()]))),
              ]),
            );
          }).toList(),
        )),
      ),
    ]);
  }

  static const _hSt = TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kGrey400);
}

// ─────────────────────────────────────────────────────────────────────────────
//  INCOMING SOURCES TABLE — # | Kutoka | Kwenda | Idadi
// ─────────────────────────────────────────────────────────────────────────────
class _IncomingSourcesTable extends StatelessWidget {
  final List<dynamic> rows;
  const _IncomingSourcesTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('Hakuna data', style: TextStyle(fontSize: 13, color: _kGrey400));
    }
    return Column(children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 22, child: Text('#', style: _hSt)),
          SizedBox(width: 8),
          Expanded(child: Text('KUTOKA', style: _hSt)),
          SizedBox(width: 64, child: Text('KWENDA', textAlign: TextAlign.right, style: _hSt)),
          SizedBox(width: 48, child: Text('IDADI', textAlign: TextAlign.right, style: _hSt)),
        ]),
      ),
      Container(height: 1, color: _kGrey100),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(child: Column(
          children: rows.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i < rows.length - 1
                    ? const Border(bottom: BorderSide(color: _kGrey100)) : null),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${i + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _kGrey400))),
                const SizedBox(width: 8),
                Expanded(child: Text('${s['from']}',
                  style: const TextStyle(fontSize: 12, color: _kGrey700),
                  overflow: TextOverflow.ellipsis)),
                SizedBox(width: 64, child: Text('${s['to']}', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: _kOrange), // text-brand-orange
                  overflow: TextOverflow.ellipsis)),
                SizedBox(width: 48, child: Text('${s['count']}', textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: _kBlue, fontFeatures: [FontFeature.tabularFigures()]))),
              ]),
            );
          }).toList(),
        )),
      ),
    ]);
  }

  static const _hSt = TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kGrey400);
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECENT ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RecentActivityCard extends StatelessWidget {
  final List<dynamic> events;
  const _RecentActivityCard({required this.events});

  IconData _icon(String type) => switch (type) {
    'user.registered'   => Icons.person_add_outlined,
    'payment.submitted' ||
    'payment.approved'  ||
    'payment.rejected'  => Icons.account_balance_wallet_outlined,
    'feedback.new'      ||
    'feedback.replied'  => Icons.assignment_outlined,
    'password_reset.new'=> Icons.lock_reset_outlined,
    'data.changed'      => Icons.bolt,
    _                   => Icons.notifications_outlined,
  };

  Color _color(String type) => switch (type) {
    'user.registered'   => const Color(0xFF3B82F6),
    'payment.submitted' ||
    'payment.approved'  ||
    'payment.rejected'  => const Color(0xFF22C55E),
    'feedback.new'      ||
    'feedback.replied'  => const Color(0xFFF97316),
    'password_reset.new'=> const Color(0xFF7C3AED),
    'data.changed'      => const Color(0xFFEAB308),
    _                   => _kGrey400,
  };

  String _time(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16), // activity card slightly smaller padding
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.notifications_outlined, size: 15, color: _kGrey900),
          SizedBox(width: 6),
          Text('Matukio ya Hivi Karibuni',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
        ]),
        const SizedBox(height: 8),
        ...events.map((e) {
          final type  = (e['type'] as String?) ?? '';
          final title = (e['title'] as String?) ?? type;
          final time  = _time(e['created_at'] as String?);
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kGrey50))),
            child: Row(children: [
              Icon(_icon(type), size: 14, color: _color(type)),
              const SizedBox(width: 8),
              Expanded(child: Text(title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _kGrey700),
                overflow: TextOverflow.ellipsis)),
              if (time.isNotEmpty)
                Text(time, style: const TextStyle(fontSize: 10, color: _kGrey400)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USERS TAB — search + DataTable (kama web UsersTab)
// ─────────────────────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<dynamic> users;
  final int total;
  final String q;
  final ValueChanged<String> onSearch;
  const _UsersTab({required this.users, required this.total,
      required this.q, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search — .input class (rounded-xl)
      Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(12)), // rounded-xl
        child: TextField(
          onChanged: onSearch,
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Tafuta mtumiaji...',
            hintStyle: TextStyle(fontSize: 12, color: _kGrey400),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            prefixIcon: Icon(Icons.search, size: 16, color: _kGrey400),
            prefixIconConstraints: BoxConstraints(minWidth: 32, minHeight: 32)),
        ),
      ),
      const SizedBox(height: 8),
      Text('Jumla: $total',
        style: const TextStyle(fontSize: 12, color: _kGrey500)),
      const SizedBox(height: 8),
      // Table in .card container
      Container(
        decoration: _cardDecoration(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 48,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(_kGrey50),
            headingTextStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: _kGrey500),
            dataTextStyle: const TextStyle(fontSize: 12, color: _kGrey700),
            dividerThickness: 1,
            columns: const [
              DataColumn(label: Text('JINA')),
              DataColumn(label: Text('SIMU')),
              DataColumn(label: Text('KADA')),
              DataColumn(label: Text('MKOA')),
              DataColumn(label: Text('ANAKOTAKA')),
              DataColumn(label: Text('ADMIN')),
            ],
            rows: users.map((u) {
              final isAdmin = u['is_admin'] == true;
              final station = u['current_station'] as Map? ?? {};
              final dests = (u['desired_destinations'] as List?) ?? [];
              final destsStr = dests.map((d) => '${d['region_name'] ?? d}').join(', ');
              return DataRow(cells: [
                DataCell(Text('${u['full_name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text('${u['phone_primary'] ?? ''}',
                  style: const TextStyle(color: _kBlue))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kBlue50, borderRadius: BorderRadius.circular(4)),
                  child: Text('${u['cadre_code'] ?? ''}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue)))),
                DataCell(Text('${station['region_name'] ?? ''}')),
                DataCell(Text(destsStr,
                  style: const TextStyle(fontSize: 11, color: _kGrey500),
                  overflow: TextOverflow.ellipsis)),
                DataCell(isAdmin
                    ? const Icon(Icons.shield_outlined, size: 16, color: _kBlue)
                    : const Text('—', style: TextStyle(color: _kGrey400))),
              ]);
            }).toList(),
          ),
        ),
      ),
    ]);
  }
}
