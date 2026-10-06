// =============================================================================
//  statistics_data_page.dart — "Statistics" tab ya admin shell (index 9).
//
//  Inapakia data HALISI kutoka backend (API zile zile zinazotumiwa na
//  esstranfer.com/admin) na kuimwaga kwenye StatisticsPage (ui iliyokubaliwa):
//    - adminStats()            → totals: users, users_active_7d, users_verified
//    - adminReports(...)       → users_by_region / incoming_by_region /
//                                users_by_district / incoming_by_district /
//                                users_by_cadre / users_by_category /
//                                users_by_status / incoming_sources
//    - getNotifications()      → Matukio ya Hivi Karibuni (kama web dashboard)
//    - adminEvents(user.registered) → sparkline ya siku 7 (waliopajiwa kila siku)
//    - adminListDepartments()  → ramani ya jina la idara → code (kwa vichujio)
//
//  Vichujio (Mkoa/Idara/Ngazi) vinapobadilika, tunaita tena adminReports na
//  kutengeneza StatsData mpya — kamwe hatumii demo data.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart' show friendlyError;
import 'statistics_page.dart';

class StatisticsTabPage extends StatefulWidget {
  const StatisticsTabPage({super.key});

  @override
  State<StatisticsTabPage> createState() => _StatisticsTabPageState();
}

class _StatisticsTabPageState extends State<StatisticsTabPage> {
  bool _loading = true;
  String? _error;
  StatsData? _data;

  // Vichujio vya API ('Mkoa wote'/'Idara zote'/'Ngazi zote' = hakuna vichujio)
  String? _region; // jina la mkoa
  String? _category; // code ya idara
  String _level = ''; // 'Primary' | 'Secondary' | ''

  // Ramani: jina la idara (label ya UI) → code ya API
  Map<String, String> _deptCodeByName = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // ── 1. Reports (data kuu) ──
    Map<String, dynamic> reports = {};
    try {
      final r = await ApiService().adminReports(
        days: 365,
        region: _region,
        category: _category,
        level: _level,
      );
      if (!mounted) return;
      reports = asMap(r.data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
      return;
    }

    // ── 2. Stats totals (inaweza kushindwa bila kuvuruga ukurasa) ──
    Map<String, dynamic> stats = {};
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      stats = asMap(r.data);
    } catch (_) {}

    // ── 3. Matukio (notifications — API ile ile ya web) ──
    List<Map<String, dynamic>> notifs = [];
    try {
      final r = await ApiService().getNotifications(limit: 8);
      if (!mounted) return;
      final d = r.data;
      final list = d is Map
          ? ((d['notifications'] as List?) ?? [])
          : (d is List ? d : []);
      notifs = list.whereType<Map>().map(asMap).toList();
    } catch (_) {}

    // ── 4. Sparkline: waliojiunga siku 7 zilizopita ──
    final weeklyNew = await _weeklyNew();
    if (!mounted) return;

    // ── 5. Ramani ya idara (jina → code, kwa vichujio vya Idara) ──
    try {
      final r = await ApiService().adminListDepartments();
      if (!mounted) return;
      final raw = r.data;
      final list = (raw is List ? raw : (asMap(raw)['departments'] ?? []))
          .whereType<Map>()
          .map(asMap)
          .toList();
      _deptCodeByName = {
        for (final d in list)
          if ('${d['name'] ?? ''}'.isNotEmpty)
            '${d['name']}': '${d['code'] ?? d['category'] ?? d['name']}',
      };
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _data = _buildStatsData(reports, stats, notifs, weeklyNew);
      _loading = false;
    });
  }

  /// Waliojiunga kila siku (siku 7 zilizopita) — kutoka /admin/events.
  Future<List<int>> _weeklyNew() async {
    try {
      final r = await ApiService()
          .adminEvents(eventType: 'user.registered', limit: 500);
      if (!mounted) return List.filled(7, 0);
      final d = r.data;
      List raw = [];
      if (d is List) {
        raw = d;
      } else if (d is Map) {
        raw = (d['events'] as List?) ?? [];
      }
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final buckets = List.filled(7, 0);
      for (final e in raw) {
        if (e is! Map) continue;
        final ts = (e['occurred_at'] ?? e['created_at'] ?? '') as String;
        if (ts.isEmpty) continue;
        try {
          final dt = DateTime.parse(ts).toLocal();
          final day = startOfToday.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
          if (day >= 0 && day < 7) buckets[6 - day]++;
        } catch (_) {}
      }
      return buckets;
    } catch (_) {
      return List.filled(7, 0);
    }
  }

  // ── Kuunganisha API responses → StatsData ──────────────────────────────────
  StatsData _buildStatsData(
    Map<String, dynamic> reports,
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> notifs,
    List<int> weeklyNew,
  ) {
    List<Map<String, dynamic>> list(String key) =>
        ((reports[key] as List?) ?? []).whereType<Map>().map(asMap).toList();

    final totals = asMap(stats['totals']);

    int countOf(Map<String, dynamic> m) => (m['count'] as num?)?.toInt() ?? 0;

    final byRegion = list('users_by_region');
    final inRegion = list('incoming_by_region');
    final byDistrict = list('users_by_district');
    final inDistrict = list('incoming_by_district');
    final byCadre = list('users_by_cadre');
    final byDept = list('users_by_category');
    final byStatus = list('users_by_status');
    final sources = list('incoming_sources');

    final totalUsers = (totals['users'] as num?)?.toInt() ??
        byRegion.fold(0, (s, m) => s + countOf(m));
    final totalMovers =
        inRegion.fold(0, (s, m) => s + countOf(m));
    final verified = (totals['users_verified'] as num?)?.toInt() ?? 0;
    final newThisWeek = (totals['users_active_7d'] as num?)?.toInt() ?? 0;

    final regionsCount = <String>{
      for (final m in byRegion)
        if ((m['region'] ?? '').toString().isNotEmpty) '${m['region']}',
      for (final m in inRegion)
        if ((m['region'] ?? '').toString().isNotEmpty) '${m['region']}',
    }.length;
    final districtsCount = <String>{
      for (final m in byDistrict)
        if ((m['district'] ?? '').toString().isNotEmpty) '${m['district']}',
      for (final m in inDistrict)
        if ((m['district'] ?? '').toString().isNotEmpty) '${m['district']}',
    }.length;

    // ── Matukio ──
    final events = <StatsEvent>[
      for (final n in notifs.take(6))
        StatsEvent(
          _eventIcon('${n['type'] ?? ''}', '${n['title'] ?? ''}'),
          '${n['title'] ?? ''}',
          _fmtTime('${n['created_at'] ?? n['occurred_at'] ?? ''}'),
        ),
    ];

    // ── Kwa Idara (panga kwa wingi; rangi na icons zinafuata mockup) ──
    final deptPalette = const [
      Color(0xFF1A3FA8),
      Color(0xFFE8590C),
      Color(0xFF1D9E5A),
      Color(0xFF7A9BE8),
      Color(0xFFB58105),
      Color(0xFF9AA8C8),
      Color(0xFF5B3FC2),
    ];
    final sortedDepts = [...byDept]..sort(
        (a, b) => countOf(b).compareTo(countOf(a)));
    final departments = <DeptStat>[
      for (var i = 0; i < sortedDepts.length; i++)
        DeptStat(
          '${sortedDepts[i]['name'] ?? sortedDepts[i]['category'] ?? 'unknown'}',
          _deptIcon('${sortedDepts[i]['category'] ?? ''}'),
          deptPalette[i % deptPalette.length],
          countOf(sortedDepts[i]),
        ),
    ];

    // ── Kwa Hali ──
    final activeRaw = byStatus
        .where((m) => '${m['status'] ?? ''}' == 'active')
        .fold(0, (s, m) => s + countOf(m));
    final activeCount = activeRaw > 0 ? activeRaw : totalUsers;

    // ── Walimu kwa Ngazi ──
    int teachers(String level) => byCadre
        .where((m) => '${m['level'] ?? ''}' == level)
        .fold(0, (s, m) => s + countOf(m));
    final teachersPrimary = teachers('Primary');
    final teachersSecondary = teachers('Secondary');
    final teachersNone = byCadre
        .where((m) => '${m['level'] ?? ''}'.isEmpty)
        .fold(0, (s, m) => s + countOf(m));

    // ── Kwa Kada ──
    final sortedKada = [...byCadre]..sort(
        (a, b) => countOf(b).compareTo(countOf(a)));
    final kadaList = <KadaStat>[
      for (final c in sortedKada.take(20))
        KadaStat(
          '${c['cadre_name'] ?? c['cadre'] ?? ''}'
          '${('${c['level'] ?? ''}').isEmpty ? '' : ' (${c['level']})'}',
          countOf(c),
        ),
    ];
    // kadaTotal = jumla ya wote wenye kada (inaweza kuwa chini ya totalUsers
    // kwa sababu baadhi ya watumiaji hawana kada) — siyo jumla ya rows 20 tu.
    final kadaTotal =
        byCadre.fold(0, (s, c) => s + countOf(c));

    // ── Mikoa: walio + wanaohamia ──
    int regionIn(String name) => inRegion
        .where((m) => '${m['region'] ?? ''}' == name)
        .fold(0, (s, m) => s + countOf(m));
    final regions = <RegionStat>[
      for (final m in byRegion)
        if ((m['region'] ?? '').toString().isNotEmpty)
          RegionStat('${m['region']}', countOf(m), regionIn('${m['region']}')),
    ];

    // ── Wanaohamia wanatoka wapi ──
    final flows = <MoveFlow>[
      for (final f in sources.take(11))
        MoveFlow('${f['from'] ?? ''}', '${f['to'] ?? ''}', countOf(f)),
    ];

    // ── Wilaya: walio + wanaohamia ──
    int districtIn(String name) => inDistrict
        .where((m) => '${m['district'] ?? ''}' == name)
        .fold(0, (s, m) => s + countOf(m));
    final districts = <DistrictStat>[
      for (final m in byDistrict.take(12))
        if ((m['district'] ?? '').toString().isNotEmpty)
          DistrictStat(
            '${m['district']}',
            '${m['region'] ?? ''}',
            countOf(m),
            districtIn('${m['district']}'),
          ),
    ];

    return StatsData(
      totalUsers: totalUsers,
      newThisWeek: newThisWeek,
      weeklyNew: weeklyNew.length == 7 ? weeklyNew : List.filled(7, 0),
      totalMovers: totalMovers,
      verified: verified,
      regionsCount: regionsCount,
      districtsCount: districtsCount,
      events: events,
      departments: departments,
      activeCount: activeCount,
      teachersPrimary: teachersPrimary,
      teachersSecondary: teachersSecondary,
      teachersNone: teachersNone,
      kada: kadaList,
      kadaTotal: kadaTotal,
      regions: regions,
      flows: flows,
      districts: districts,
    );
  }

  IconData _eventIcon(String type, String title) {
    final t = title.toLowerCase();
    if (type.startsWith('match') || t.contains('match')) {
      return TablerIcons.link;
    }
    if (type.startsWith('user.registered') || t.contains('amejiunga')) {
      return TablerIcons.user_plus;
    }
    if (type.startsWith('payment')) return TablerIcons.wallet;
    if (type.startsWith('feedback')) return TablerIcons.message;
    if (type.startsWith('password_reset')) return TablerIcons.key;
    return TablerIcons.bell;
  }

  IconData _deptIcon(String category) {
    switch (category.toLowerCase()) {
      case 'elimu':
        return TablerIcons.school;
      case 'afya':
        return TablerIcons.stethoscope;
      case 'kilimo':
      case 'kilimo na ufugaji':
        return TablerIcons.plant_2;
      case 'watumishi wa umma':
        return TablerIcons.building_community;
      default:
        return TablerIcons.help_circle;
    }
  }

  String _fmtTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  // ── Vichujio: labels za UI → params za API ─────────────────────────────────
  void _onFiltersChanged(String mkoa, String idara, String ngazi) {
    setState(() {
      _region = mkoa == 'Mkoa wote' ? null : mkoa;
      _category = idara == 'Idara zote'
          ? null
          : (_deptCodeByName[idara] ?? idara);
      _level = switch (ngazi) {
        'Primary (Msingi)' => 'Primary',
        'Secondary (Sekondari)' => 'Secondary',
        _ => '',
      };
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1A3FA8)),
        ),
      );
    }
    if (_data == null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Imeshindikana kupakia takwimu.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF5A6B92), fontSize: 14)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3FA8),
                ),
                child: const Text('Jaribu tena'),
              ),
            ],
          ),
        ),
      );
    }
    return StatisticsPage(
      data: _data,
      onFiltersChanged: _onFiltersChanged,
    );
  }
}
