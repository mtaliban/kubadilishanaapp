/// Ripoti (Statistics) — takwimu za mfumo kwa NAMBA halisi.
///
/// Data yote inatoka `/admin/reports` (backend) — keys halisi:
/// users_by_region / incoming_by_region / users_by_district /
/// incoming_by_district / users_by_cadre / users_by_category /
/// users_by_status / users_by_facility / incoming_sources /
/// regions_total / districts_total / revenue.
///
/// Mikoa na idara zinapakiwa DYNAMIC (`/locations/regions`,
/// `/locations/departments`) — idara mpya aliyoongeza admin inaonekana
/// hapa PAPO HAPO.
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

  // Filters — region ni JINA (backend inachuja kwa current_station.region_name)
  String? _region;
  String? _regionId;
  String? _category;
  String _categoryName = '';
  String _level = '';
  int _days = 30;

  List<dynamic> _regions = [];
  List<dynamic> _departments = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
  }

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
      setState(() => _departments = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminReports(
        days: _days,
        region: _region,
        category: _category,
        level: _level,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _data = (res.data as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  Future<void> _pickRegion() async {
    final items = <({String value, String label, String? subtitle})>[
      (value: '__all__', label: 'Mikoa Yote', subtitle: 'Onyesha mikoa yote'),
      for (final r in _regions)
        (
          value: '${r['id'] ?? r['region_id']}',
          label: '${r['name'] ?? r['region_name'] ?? ''}',
          subtitle: null,
        ),
    ];
    final picked = await showSelectSheet<String>(
      context,
      title: 'Chagua Mkoa',
      items: items,
      selected: _regionId ?? '__all__',
      searchable: true,
    );
    if (picked == null || !mounted) return;
    final r = _regions.firstWhere(
      (x) => '${x['id'] ?? x['region_id']}' == picked,
      orElse: () => null,
    );
    setState(() {
      _regionId = picked == '__all__' ? null : picked;
      _region = picked == '__all__' ? null : '${r?['name'] ?? r?['region_name'] ?? ''}';
    });
    _load();
  }

  Future<void> _pickCategory() async {
    final items = <({String value, String label, String? subtitle})>[
      (value: '__all__', label: 'Idara Zote', subtitle: 'Onyesha idara zote'),
      for (final d in _departments)
        (
          value: '${d['code']}',
          label: '${d['name'] ?? d['code']}',
          subtitle: '${d['code']}',
        ),
    ];
    final picked = await showSelectSheet<String>(
      context,
      title: 'Chagua Idara',
      items: items,
      selected: _category ?? '__all__',
      searchable: true,
    );
    if (picked == null || !mounted) return;
    final d = _departments.firstWhere((x) => '${x['code']}' == picked, orElse: () => null);
    setState(() {
      _category = picked == '__all__' ? null : picked;
      _categoryName = picked == '__all__' ? '' : '${d?['name'] ?? picked}';
    });
    _load();
  }

  Future<void> _pickLevel() async {
    final items = <({String value, String label, String? subtitle})>[
      (value: '', label: 'Ngazi Zote', subtitle: 'Primary na Secondary'),
      (value: 'Primary', label: 'Primary — Msingi', subtitle: 'Kada za shule za msingi'),
      (value: 'Secondary', label: 'Secondary — Sekondari', subtitle: 'Kada za sekondari'),
    ];
    final picked = await showSelectSheet<String>(
      context,
      title: 'Chagua Ngazi',
      items: items,
      selected: _level,
    );
    if (picked == null || !mounted) return;
    setState(() => _level = picked);
    _load();
  }

  Future<void> _pickDays() async {
    final items = <({int value, String label, String? subtitle})>[
      (value: 7, label: 'Siku 7', subtitle: 'Wiki moja'),
      (value: 30, label: 'Siku 30', subtitle: 'Mwezi mmoja'),
      (value: 90, label: 'Siku 90', subtitle: 'Miezi mitatu'),
      (value: 365, label: 'Siku 365', subtitle: 'Mwaka mmoja'),
    ];
    final picked = await showSelectSheet<int>(
      context,
      title: 'Chagua Kipindi',
      items: items,
      selected: _days,
    );
    if (picked == null || !mounted) return;
    setState(() => _days = picked);
    _load();
  }

  // ── Data helpers ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _list(String key) =>
      ((_data[key] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  int _int(String key) => (_data[key] as num?)?.toInt() ?? 0;

  int get _usersTotal => _list('users_by_region').fold(0, (s, r) => s + ((r['count'] as num?)?.toInt() ?? 0));

  /// Mkoa + waliopo + wanaohamia (kama web: current + incoming).
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
    )).toList();
    out.sort((a, b) => (b.current + b.incoming).compareTo(a.current + a.incoming));
    return out;
  }

  String _deptLabel(String code) {
    final d = _departments.firstWhere((x) => '${x['code']}' == code, orElse: () => null);
    return d == null ? code : '${d['name'] ?? code}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _filters()),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(hasScrollBody: false, child: _errorView())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_sections()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.assessment_outlined, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Statistiki',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text('Namba halisi za mfumo — mkoa, wilaya, idara na kada',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        GestureDetector(
          onTap: () => _load(refresh: true),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.grey200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, size: 19, color: AppColors.primary),
          ),
        ),
      ]),
    );
  }

  // ── Filters ───────────────────────────────────────────────────────────────
  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: SelectField(
              hint: 'Mkoa',
              value: _region == null || _region!.isEmpty ? 'Mikoa Yote' : _region,
              onTap: _pickRegion,
              leading: const Icon(Icons.map_outlined, size: 15, color: AppColors.textLight),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectField(
              hint: 'Idara',
              value: _category == null ? 'Idara Zote' : _categoryName,
              onTap: _pickCategory,
              leading: const Icon(Icons.category_outlined, size: 15, color: AppColors.textLight),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: SelectField(
              hint: 'Ngazi',
              value: _level.isEmpty ? 'Ngazi Zote' : _level,
              onTap: _pickLevel,
              leading: const Icon(Icons.school_outlined, size: 15, color: AppColors.textLight),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectField(
              hint: 'Kipindi',
              value: 'Siku $_days',
              onTap: _pickDays,
              leading: const Icon(Icons.schedule_outlined, size: 15, color: AppColors.textLight),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _load(refresh: true),
            icon: const Icon(Icons.search_rounded, size: 16),
            label: const Text('Tafuta'),
          ),
        ),
      ]),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error ?? '', textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => _load(refresh: true), child: const Text('Jaribu Tena')),
        ]),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────
  List<Widget> _sections() {
    final byRegion = _byRegion;
    final byDistricts = _list('users_by_district');
    final inDistricts = _list('incoming_by_district');
    final byCadre = _list('users_by_cadre');
    final byCategory = _list('users_by_category')
      ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0).compareTo((a['count'] as num?)?.toInt() ?? 0));
    final byStatus = _list('users_by_status')
      ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0).compareTo((a['count'] as num?)?.toInt() ?? 0));
    final byFacility = _list('users_by_facility');
    final sources = _list('incoming_sources');
    final revenue = (_data['revenue'] as Map?)?.cast<String, dynamic>() ?? {};

    final cadrePrimary = byCadre
        .where((c) => (c['level'] ?? '') == 'Primary')
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));
    final cadreSecondary = byCadre
        .where((c) => (c['level'] ?? '') == 'Secondary')
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));

    return [
      // ── Big numbers ──
      Row(children: [
        Expanded(child: _bigCard('Watumiaji', _usersTotal, AppColors.primary, AppColors.blue50)),
        const SizedBox(width: 10),
        Expanded(child: _bigCard('Mikoa', _int('regions_total'), AppColors.success,
            const Color(0xFFDCFCE7))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _bigCard('Wilaya', _int('districts_total'), _kAmber, _kAmberBg)),
        const SizedBox(width: 10),
        Expanded(child: _bigCard('Michango (TZS)',
            (revenue['total_tzs'] as num?)?.toInt() ?? 0, _kTeal, const Color(0xFFCCFBF1))),
      ]),
      const SizedBox(height: 16),

      // ── Mikoa: waliopo + wanaohamia ──
      _card(
        title: 'Kwa Mkoa — waliopo na wanaohamia',
        icon: Icons.map_outlined,
        iconColor: AppColors.primary,
        iconBg: AppColors.blue50,
        child: byRegion.isEmpty
            ? _empty()
            : Column(children: [
                for (final r in byRegion.take(40))
                  _row2(
                    r.region,
                    current: r.current,
                    incoming: r.incoming,
                  ),
              ]),
      ),

      // ── Wilaya ──
      _card(
        title: 'Kwa Wilaya',
        icon: Icons.location_city_outlined,
        iconColor: AppColors.success,
        iconBg: const Color(0xFFDCFCE7),
        child: byDistricts.isEmpty
            ? _empty()
            : Column(children: [
                for (final d in byDistricts.take(50))
                  _row2(
                    '${d['district'] ?? '—'}'
                    '${(d['region'] ?? '').toString().isEmpty ? '' : ' · ${d['region']}'}',
                    current: (d['count'] as num?)?.toInt() ?? 0,
                    incoming: (inDistricts.firstWhere(
                                (x) => '${x['district']}' == '${d['district']}',
                                orElse: () => {})['count'] as num?)
                            ?.toInt() ??
                        0,
                  ),
              ]),
      ),

      // ── Idara (dynamic) ──
      _card(
        title: 'Kwa Idara',
        icon: Icons.apartment_outlined,
        iconColor: _kAmber,
        iconBg: _kAmberBg,
        child: byCategory.isEmpty
            ? _empty()
            : Column(children: [
                for (final c in byCategory)
                  _row1(
                    '${c['name'] ?? _deptLabel('${c['category']}')}',
                    (c['count'] as num?)?.toInt() ?? 0,
                  ),
              ]),
      ),

      // ── Kada ──
      _card(
        title: 'Kwa Kada${cadrePrimary + cadreSecondary > 0 ? ' (Msingi: $cadrePrimary · Sekondari: $cadreSecondary)' : ''}',
        icon: Icons.badge_outlined,
        iconColor: _kTeal,
        iconBg: const Color(0xFFCCFBF1),
        child: byCadre.isEmpty
            ? _empty()
            : Column(children: [
                for (final c in (byCadre.toList()
                      ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
                          .compareTo((a['count'] as num?)?.toInt() ?? 0)))
                    .take(30))
                  _row1(
                    '${c['cadre_name'] ?? c['cadre']}'
                    '${(c['level'] ?? '') == '' ? '' : ' · ${c['level']}'}',
                    (c['count'] as num?)?.toInt() ?? 0,
                  ),
              ]),
      ),

      // ── Hali (status) ──
      _card(
        title: 'Kwa Hali ya Akaunti',
        icon: Icons.verified_user_outlined,
        iconColor: AppColors.primary,
        iconBg: AppColors.blue50,
        child: byStatus.isEmpty
            ? _empty()
            : Column(children: [
                for (final s in byStatus)
                  _row1(_statusLabel('${s['status']}'), (s['count'] as num?)?.toInt() ?? 0),
              ]),
      ),

      // ── Wanaohamia: wanatoka wapi ──
      if (sources.isNotEmpty)
        _card(
          title: 'Wanaohamia — wanatoka wapi',
          icon: Icons.swap_horiz_rounded,
          iconColor: _kTeal,
          iconBg: const Color(0xFFCCFBF1),
          child: Column(children: [
            for (final s in sources.take(30))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(
                    child: Text('${s['from']}  →  ${s['to']}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${s['count']}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ]),
              ),
          ]),
        ),

      // ── Vituo ──
      if (byFacility.isNotEmpty)
        _card(
          title: 'Kwa Kituo / Shule',
          icon: Icons.local_hospital_outlined,
          iconColor: AppColors.primary,
          iconBg: AppColors.blue50,
          child: Column(children: [
            for (final f in byFacility.take(40))
              _row1(
                '${f['facility'] ?? '—'}'
                '${(f['district'] ?? '').toString().isEmpty ? '' : ' · ${f['district']}'}',
                (f['count'] as num?)?.toInt() ?? 0,
              ),
          ]),
        ),

      // ── Michango kwa madhumuni ──
      if (((revenue['per_purpose'] as List?) ?? []).isNotEmpty)
        _card(
          title: 'Michango kwa Madhumuni',
          icon: Icons.payments_outlined,
          iconColor: AppColors.success,
          iconBg: const Color(0xFFDCFCE7),
          child: Column(children: [
            for (final p in (revenue['per_purpose'] as List).take(20))
              _row1('${(p as Map)['purpose'] ?? '—'}',
                  ((p['total'] as num?)?.toInt() ?? 0)),
          ]),
        ),
    ];
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

  // ── Small widgets ─────────────────────────────────────────────────────────
  Widget _bigCard(String label, int value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          value >= 1000 ? _thousands(value) : '$value',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

  Widget _card({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.borderLight),
        const SizedBox(height: 4),
        child,
      ]),
    );
  }

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('Hakuna data kwa kipindi hiki',
            style: TextStyle(fontSize: 12.5, color: AppColors.textLight)),
      );

  Widget _row1(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text('$value',
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ]),
    );
  }

  /// Mstari wa mkoa/wilaya: WALIOPO (blue) + WANAOHAMIA (green).
  Widget _row2(String label, {required int current, required int incoming}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(6)),
          child: Text('$current',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
          child: Text('$incoming',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.success)),
        ),
      ]),
    );
  }
}

const _kAmber = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kTeal = Color(0xFF0D9488);
