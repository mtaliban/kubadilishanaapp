// =============================================================================
//  statistics_page.dart  -  Kubadilishana (EssTransfer) admin panel
//  "Statistics" page. Single file, ready to drop in.
//
//  Usage (inside the existing admin shell, which already has the top bar,
//  drawer and bottom navigation - this widget is only the page BODY):
//
//    StatisticsPage(
//      data: statsFromBackend,            // null = demo data
//      onFiltersChanged: (mkoa, idara, ngazi) { /* refetch */ },
//    )
//
//  This file matches the approved mockup EXACTLY (layout, colors, icons,
//  sizes). Do not restyle it.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart' show friendlyError;

// ----------------------------------------------------------------------------
// Colors (from the approved mockup)
// ----------------------------------------------------------------------------
class _C {
  static const blue = Color(0xFF1A3FA8);
  static const ink = Color(0xFF14224D);
  static const title = Color(0xFF0F1B4A);
  static const muted = Color(0xFF5A6B92);
  static const muted2 = Color(0xFF7686AB);
  static const muted3 = Color(0xFF6B7BA3);
  static const border = Color(0xFFD6E2F6);
  static const soft = Color(0xFFE6ECF8);
  static const tileBg = Color(0xFFEEF2FC);
  static const iconTile = Color(0xFFE3EAFC);
  static const tagBg = Color(0xFFE6EDFB);
  static const barBg = Color(0xFFEEF0F6);
  static const jmBg = Colors.white; // nyeupe kabisa (ilikuwa #F7F8FC)
  static const orange = Color(0xFFE8590C);
  static const green = Color(0xFF1D9E5A);
  static const greenFg = Color(0xFF0F6E3A);
  static const greenBg = Color(0xFFDCF5E5);
  static const purple = Color(0xFF5B3FC2);
  static const donutLight = Color(0xFFB9C7EC);
  static const arrow = Color(0xFF8A9BC2);
  static const optBorder = Color(0xFFE1E8F6);
  static const heroTop = Colors.white; // nyeupe kabisa (ilikuwa #F4F7FF)
}

// ----------------------------------------------------------------------------
// Models
// ----------------------------------------------------------------------------
class StatsEvent {
  final IconData icon;
  final String text;
  final String time;
  const StatsEvent(this.icon, this.text, this.time);
}

class DeptStat {
  final String name;
  final IconData icon;
  final Color color;
  final int count;
  const DeptStat(this.name, this.icon, this.color, this.count);
}

class KadaStat {
  final String name;
  final int count;
  const KadaStat(this.name, this.count);
}

class RegionStat {
  final String name;
  final int resident; // waliopo
  final int moving; // wanaohamia
  const RegionStat(this.name, this.resident, this.moving);
  int get total => resident + moving;
}

class DistrictStat {
  final String name;
  final String region;
  final int resident;
  final int moving;
  const DistrictStat(this.name, this.region, this.resident, this.moving);
  int get total => resident + moving;
}

class MoveFlow {
  final String from;
  final String to;
  final int count;
  const MoveFlow(this.from, this.to, this.count);
}

class StatsData {
  final int totalUsers; // watumiaji waliopo
  final int newThisWeek; // +258 wanatumia siku 7
  final List<int> weeklyNew; // 7 values for the sparkline
  final int totalMovers; // wanaohamia wote
  final int verified; // imethibitishwa
  final int regionsCount;
  final int districtsCount;
  final List<StatsEvent> events;
  final List<DeptStat> departments;
  final int activeCount; // Hai (active)
  final int teachersPrimary;
  final int teachersSecondary;
  final int teachersNone;
  final List<KadaStat> kada;
  final int kadaTotal;
  final List<RegionStat> regions;
  final List<MoveFlow> flows;
  final List<DistrictStat> districts;

  const StatsData({
    required this.totalUsers,
    required this.newThisWeek,
    required this.weeklyNew,
    required this.totalMovers,
    required this.verified,
    required this.regionsCount,
    required this.districtsCount,
    required this.events,
    required this.departments,
    required this.activeCount,
    required this.teachersPrimary,
    required this.teachersSecondary,
    required this.teachersNone,
    required this.kada,
    required this.kadaTotal,
    required this.regions,
    required this.flows,
    required this.districts,
  });

  /// Demo data (same numbers as the approved mockup).
  factory StatsData.demo() => const StatsData(
        totalUsers: 1349,
        newThisWeek: 258,
        weeklyNew: [28, 35, 31, 44, 39, 52, 29],
        totalMovers: 3031,
        verified: 45,
        regionsCount: 28,
        districtsCount: 194,
        events: [
          StatsEvent(TablerIcons.user_plus, 'Rahabu titho amejiunga', '08:25'),
          StatsEvent(TablerIcons.link, 'Match mpya: Zuberi Manyehe ↔ J…', '21:45'),
          StatsEvent(TablerIcons.user_plus, 'Jacklini Matandala amejiunga', '21:45'),
          StatsEvent(TablerIcons.user_plus, 'Aman Mngazia amejiunga', '17:04'),
        ],
        departments: [
          DeptStat('Elimu', TablerIcons.school, Color(0xFF1A3FA8), 883),
          DeptStat('Afya', TablerIcons.stethoscope, Color(0xFFE8590C), 445),
          DeptStat('Watumishi wa Umma', TablerIcons.building_community, Color(0xFF1D9E5A), 9),
          DeptStat('waumma', TablerIcons.users, Color(0xFF7A9BE8), 5),
          DeptStat('Kilimo na ufugaji', TablerIcons.plant_2, Color(0xFFB58105), 4),
          DeptStat('unknown', TablerIcons.help_circle, Color(0xFF9AA8C8), 3),
        ],
        activeCount: 1349,
        teachersPrimary: 252,
        teachersSecondary: 631,
        teachersNone: 466,
        kada: [
          KadaStat('Mwalimu wa Elimu ya Sekondari', 631),
          KadaStat('Mwalimu wa Elimu ya Msingi', 252),
          KadaStat('Assistant Nursing Officer', 150),
          KadaStat('Clinical Officer', 63),
          KadaStat('Health Assistant (HA)', 59),
          KadaStat('Enrolled Nurse (EN)', 36),
          KadaStat('Nursing Officer (NO)', 22),
          KadaStat('Assistant Clinical Officer', 14),
          KadaStat('Medical Attendant (MA)', 10),
          KadaStat('Laboratory Technologist II', 10),
          KadaStat('Pharmaceutical Technician', 10),
          KadaStat('Idara ya Utawala (VEO)', 9),
          KadaStat('Nurse II', 9),
          KadaStat('Medical Doctor (MD)', 9),
        ],
        kadaTotal: 1290,
        regions: [
          RegionStat('Mwanza', 72, 308), RegionStat('Dar Es Salaam', 19, 279),
          RegionStat('Morogoro', 47, 232), RegionStat('Pwani', 35, 216),
          RegionStat('Geita', 50, 187), RegionStat('Dodoma', 52, 181),
          RegionStat('Mbeya', 51, 170), RegionStat('Tanga', 63, 131),
          RegionStat('Shinyanga', 51, 125), RegionStat('Arusha', 33, 138),
          RegionStat('Kilimanjaro', 63, 105), RegionStat('Manyara', 52, 116),
          RegionStat('Tabora', 48, 99), RegionStat('Kagera', 91, 47),
          RegionStat('Kigoma', 91, 46), RegionStat('Mara', 89, 45),
          RegionStat('Iringa', 34, 94), RegionStat('Ruvuma', 61, 49),
          RegionStat('Singida', 41, 67), RegionStat('Njombe', 36, 65),
          RegionStat('Songwe', 37, 58), RegionStat('Mtwara', 72, 21),
          RegionStat('Lindi', 66, 24), RegionStat('Katavi', 30, 47),
          RegionStat('Simiyu', 33, 40), RegionStat('Rukwa', 25, 26),
          RegionStat('Coast', 2, 30), RegionStat('pwani', 1, 6),
        ],
        flows: [
          MoveFlow('Mtwara', 'Mwanza', 35),
          MoveFlow('Kigoma', 'Morogoro', 32),
          MoveFlow('Kigoma', 'Mbeya', 29),
          MoveFlow('Kigoma', 'Dar Es Salaam', 23),
          MoveFlow('Lindi', 'Geita', 22),
          MoveFlow('Kilimanjaro', 'Mwanza', 22),
          MoveFlow('Kilimanjaro', 'Dar Es Salaam', 21),
          MoveFlow('Kagera', 'Mwanza', 20),
          MoveFlow('Lindi', 'Pwani', 20),
          MoveFlow('Kigoma', 'Dodoma', 20),
          MoveFlow('Kilimanjaro', 'Pwani', 19),
        ],
        districts: [
          DistrictStat('Dodoma Cc', 'Dodoma', 9, 83),
          DistrictStat('Mbeya Cc', 'Mbeya', 11, 58),
          DistrictStat('Mbeya Dc', 'Mbeya', 14, 29),
          DistrictStat('Mbozi Dc', 'Songwe', 17, 23),
          DistrictStat('Moshi Dc', 'Kilimanjaro', 11, 27),
          DistrictStat('Chamwino Dc', 'Dodoma', 12, 25),
          DistrictStat('Chato Dc', 'Geita', 12, 24),
          DistrictStat('Nachingwea Dc', 'Lindi', 28, 3),
          DistrictStat('Rombo Dc', 'Kilimanjaro', 19, 11),
          DistrictStat('Kwimba Dc', 'Mwanza', 24, 5),
          DistrictStat('Hanang Dc', 'Manyara', 9, 19),
          DistrictStat('Mbogwe Dc', 'Geita', 9, 16),
        ],
      );
}

class FilterOption {
  final String label;
  final IconData icon;
  final String subtitle;
  const FilterOption(this.label, this.icon, [this.subtitle = '']);
}

// ----------------------------------------------------------------------------
// Page
// ----------------------------------------------------------------------------
enum _Sort { moving, resident, total }

class StatisticsPage extends StatefulWidget {
  /// Real data from backend. If null, demo data is shown.
  final StatsData? data;

  /// Called whenever a filter changes (labels like 'Mkoa wote', 'Elimu', ...).
  final void Function(String mkoa, String idara, String ngazi)? onFiltersChanged;

  const StatisticsPage({super.key, this.data, this.onFiltersChanged});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late final StatsData d = widget.data ?? StatsData.demo();

  String _mkoa = 'Mkoa wote';
  String _idara = 'Idara zote';
  String _ngazi = 'Ngazi zote';
  _Sort _regionSort = _Sort.moving;
  _Sort _districtSort = _Sort.moving;

  List<FilterOption> get _mkoaOptions => [
        const FilterOption('Mkoa wote', TablerIcons.map_2, 'Onyesha mikoa yote'),
        ...(d.regions.map((r) => r.name).toList()..sort())
            .map((n) => FilterOption(n, TablerIcons.map_pin)),
      ];

  static const _idaraOptions = [
    FilterOption('Idara zote', TablerIcons.layout_grid, 'Onyesha idara zote'),
    FilterOption('Afya', TablerIcons.stethoscope),
    FilterOption('Elimu', TablerIcons.school),
    FilterOption('Kilimo na ufugaji', TablerIcons.plant_2),
    FilterOption('Watumishi wa Umma', TablerIcons.building_community),
  ];

  static const _ngaziOptions = [
    FilterOption('Ngazi zote', TablerIcons.school, 'Primary na Secondary'),
    FilterOption('Primary (Msingi)', TablerIcons.backpack),
    FilterOption('Secondary (Sekondari)', TablerIcons.book_2),
  ];

  void _notify() => widget.onFiltersChanged?.call(_mkoa, _idara, _ngazi);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _header(),
          const SizedBox(height: 10),
          const Text(
            'Takwimu za mfumo mzima: mikoa, idara, kada, michango (real-time).',
            style: TextStyle(color: _C.muted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 14),
          _hero(),
          const SizedBox(height: 10),
          _tiles(),
          const SizedBox(height: 12),
          _eventsCard(),
          _filters(),
          const SizedBox(height: 12),
          _deptCard(),
          _statusCard(),
          _teachersCard(),
          _kadaCard(),
          _regionsCard(),
          _flowsCard(),
          _districtsCard(),
          _endMarker(),
        ],
      ),
    );
  }

  // ---- Header --------------------------------------------------------------
  Widget _header() => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.iconTile,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(TablerIcons.chart_pie, size: 22, color: _C.blue),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Statistics',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w500, color: _C.title)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _C.greenBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: _C.green),
                SizedBox(width: 6),
                Text('Live', style: TextStyle(color: _C.greenFg, fontSize: 13)),
              ],
            ),
          ),
        ],
      );

  // ---- Hero card: big number + delta chip + sparkline ---------------------
  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.border, width: 1.5),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.heroTop, Colors.white],
            stops: [0, .7],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: _C.blue),
                SizedBox(width: 7),
                Text('Watumiaji waliopo',
                    style: TextStyle(fontSize: 13.5, color: _C.muted)),
                Spacer(),
                Text('Siku 7 zilizopita',
                    style: TextStyle(fontSize: 12.5, color: _C.muted2)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fmt(d.totalUsers),
                          style: const TextStyle(
                              fontSize: 46,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              letterSpacing: -1,
                              color: _C.blue)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.greenBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(TablerIcons.trending_up,
                                size: 15, color: _C.greenFg),
                            const SizedBox(width: 4),
                            Text('+${d.newThisWeek} wanatumia siku 7',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _C.greenFg)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Flexible: sparkline inafuata nafasi uliyopo (overflow guard 320px)
                LayoutBuilder(builder: (_, c) {
                  final w = (c.maxWidth.isFinite ? c.maxWidth : 128).clamp(60.0, 128.0);
                  return CustomPaint(
                    size: Size(w, w * 0.5),
                    painter: _SparklinePainter(d.weeklyNew),
                  );
                }),
              ],
            ),
          ],
        ),
      );

  // ---- 2x2 stat tiles -------------------------------------------------------
  Widget _tiles() => Column(
        children: [
          Row(children: [
            Expanded(
                child: _tile(TablerIcons.transfer, _C.orange, 'Wanaohamia wote',
                    _fmt(d.totalMovers),
                    numColor: _C.orange)),
            const SizedBox(width: 10),
            Expanded(
                child: _tile(TablerIcons.circle_check, _C.greenFg,
                    'Imethibitishwa', _fmt(d.verified))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _tile(TablerIcons.map_2, _C.purple, 'Mikoa yote',
                    _fmt(d.regionsCount))),
            const SizedBox(width: 10),
            Expanded(
                child: _tile(TablerIcons.building_community, _C.blue,
                    'Wilaya zote', _fmt(d.districtsCount))),
          ]),
        ],
      );

  Widget _tile(IconData icon, Color iconColor, String label, String value,
          {Color numColor = _C.ink}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: _C.muted)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    letterSpacing: -.5,
                    color: numColor)),
          ],
        ),
      );

  // ---- Recent events --------------------------------------------------------
  Widget _eventsCard() => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(
                icon: TablerIcons.bell,
                title: 'Matukio ya Hivi Karibuni',
                tag: 'Live'),
            for (var i = 0; i < d.events.length; i++)
              _RowDivider(
                first: i == 0,
                child: Padding(
                  padding: EdgeInsets.only(
                      top: i == 0 ? 0 : 11, bottom: 11),
                  child: Row(
                    children: [
                      _IconTile(d.events[i].icon, size: 38, radius: 12, iconSize: 19),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(d.events[i].text,
                            style: const TextStyle(
                                fontSize: 15, height: 1.35, color: _C.ink)),
                      ),
                      const SizedBox(width: 8),
                      Text(d.events[i].time,
                          style: const TextStyle(
                              fontSize: 13.5, color: _C.muted3)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  // ---- Filter chips (open a bottom sheet with a clean list + icons) --------
  Widget _filters() => Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(TablerIcons.map_2, _mkoa, _mkoa != 'Mkoa wote', () async {
              final v = await _pick('Chagua mkoa', _mkoaOptions, _mkoa);
              if (v != null) setState(() => _mkoa = v);
              if (v != null) _notify();
            }),
            _chip(TablerIcons.building, _idara, _idara != 'Idara zote', () async {
              final v = await _pick('Chagua idara', _idaraOptions, _idara);
              if (v != null) setState(() => _idara = v);
              if (v != null) _notify();
            }),
            _chip(TablerIcons.school, _ngazi, _ngazi != 'Ngazi zote', () async {
              final v = await _pick('Chagua ngazi', _ngaziOptions, _ngazi);
              if (v != null) setState(() => _ngazi = v);
              if (v != null) _notify();
            }),
          ],
        ),
        ),
      );

  Widget _chip(IconData icon, String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? _C.tileBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _C.blue : _C.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: _C.blue),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                        color: active ? _C.blue : _C.ink)),
              ),
              const SizedBox(width: 7),
              const Icon(TablerIcons.chevron_down, size: 15, color: _C.muted),
            ],
          ),
        ),
      );

  Future<String?> _pick(
      String title, List<FilterOption> options, String selected) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final list = options
              .where((o) => o.label.toLowerCase().contains(q.toLowerCase()))
              .toList();
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * .82),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _C.ink)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(TablerIcons.x,
                            size: 22, color: _C.muted),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: TextField(
                        onChanged: (v) => setSheet(() => q = v),
                        style: const TextStyle(fontSize: 14.5, color: _C.ink),
                        decoration: InputDecoration(
                          hintText: 'Tafuta...',
                          hintStyle: const TextStyle(
                              color: Color(0xFF8A9BC2), fontSize: 14.5),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          suffixIcon: const Icon(TablerIcons.search,
                              size: 19, color: _C.blue),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: _C.border, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: _C.blue, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final o = list[i];
                          final on = o.label == selected;
                          return GestureDetector(
                            onTap: () => Navigator.pop(ctx, o.label),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: on ? _C.tileBg : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: on ? _C.blue : _C.optBorder,
                                    width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: on ? _C.blue : _C.tileBg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(o.icon,
                                        size: 19,
                                        color: on ? Colors.white : _C.blue),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(o.label,
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: on
                                                    ? _C.blue
                                                    : _C.ink)),
                                        if (o.subtitle.isNotEmpty)
                                          Text(o.subtitle,
                                              style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: _C.muted2)),
                                      ],
                                    ),
                                  ),
                                  if (on)
                                    const Icon(TablerIcons.check,
                                        size: 20, color: _C.blue),
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
        });
      },
    );
  }

  // ---- Kwa Idara ------------------------------------------------------------
  Widget _deptCard() {
    final maxC = d.departments.map((e) => e.count).reduce(math.max);
    final total = d.totalUsers;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: TablerIcons.building, title: 'Kwa Idara', tag: _fmt(total)),
          // stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              color: _C.barBg,
              child: Row(
                children: [
                  for (var i = 0; i < d.departments.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: math.max(d.departments[i].count, 8),
                      child: ColoredBox(color: d.departments[i].color),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < d.departments.length; i++)
            _RowDivider(
              first: i == 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _IconTile(d.departments[i].icon,
                        size: 36, radius: 11, iconSize: 18, bg: _C.tileBg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(d.departments[i].name,
                                  style: const TextStyle(
                                      fontSize: 15, color: _C.ink)),
                            ),
                            Text(_fmt(d.departments[i].count),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _C.blue)),
                          ]),
                          const SizedBox(height: 7),
                          _Bar(
                              fraction: math.max(
                                  d.departments[i].count / maxC, .02),
                              color: d.departments[i].color),
                          const SizedBox(height: 4),
                          Text(
                              '${(d.departments[i].count / total * 100).round()}% ya watumiaji',
                              style: const TextStyle(
                                  fontSize: 12.5, color: _C.muted2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _TotalStrip(_fmt(total)),
        ],
      ),
    );
  }

  // ---- Kwa Hali -------------------------------------------------------------
  Widget _statusCard() => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeader(icon: TablerIcons.activity, title: 'Kwa Hali'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _C.greenBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 6, backgroundColor: _C.green),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Hai (active)',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _C.greenFg)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_fmt(d.activeCount),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              height: 1,
                              color: _C.greenFg)),
                      const SizedBox(height: 3),
                      const Text('100%',
                          style: TextStyle(fontSize: 12, color: _C.greenFg)),
                    ],
                  ),
                ],
              ),
            ),
            _TotalStrip(_fmt(d.activeCount)),
          ],
        ),
      );

  // ---- Walimu kwa Ngazi (donut) --------------------------------------------
  Widget _teachersCard() {
    final total = d.totalUsers;
    final pSek = d.teachersSecondary / total;
    final pNone = d.teachersNone / total;
    final pPri = d.teachersPrimary / total;
    Widget legend(Color c, String name, double p) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 14, color: _C.ink))),
            Text('${(p * 100).round()}%',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: _C.ink)),
          ]),
        );
    Widget line(String name, int v, bool first) => _RowDivider(
          first: first,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 15, color: _C.ink))),
              Text(_fmt(v),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _C.blue)),
            ]),
          ),
        );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
              icon: TablerIcons.school,
              title: 'Walimu kwa Ngazi',
              tag: 'Primary / Secondary'),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(110, 110),
                      painter: _DonutPainter([
                        _Seg(pSek, _C.blue),
                        _Seg(pNone, _C.donutLight),
                        _Seg(pPri, _C.orange),
                      ]),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_fmt(total),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _C.ink)),
                        const Text('Jumla',
                            style: TextStyle(fontSize: 11, color: _C.muted2)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(children: [
                  legend(_C.blue, 'Walimu wa Sekondari', pSek),
                  legend(_C.donutLight, 'Hakuna ngazi', pNone),
                  legend(_C.orange, 'Walimu wa Msingi', pPri),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          line('Walimu wa Msingi', d.teachersPrimary, true),
          line('Walimu wa Sekondari', d.teachersSecondary, false),
          line('Hakuna ngazi', d.teachersNone, false),
          _TotalStrip(_fmt(total)),
        ],
      ),
    );
  }

  // ---- Kwa Kada (with percentages) -----------------------------------------
  Widget _kadaCard() {
    final maxC = d.kada.map((e) => e.count).reduce(math.max);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: TablerIcons.briefcase,
              title: 'Kwa Kada',
              tag: '${d.kada.length}'),
          for (var i = 0; i < d.kada.length; i++)
            _RowDivider(
              first: i == 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RankBadge(i + 1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(d.kada[i].name,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.3,
                                        color: _C.ink)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_fmt(d.kada[i].count),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: _C.blue)),
                                  Text(
                                      '${(d.kada[i].count / d.totalUsers * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                          fontSize: 12, color: _C.muted2)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          _Bar(fraction: d.kada[i].count / maxC, color: _C.blue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _TotalStrip(_fmt(d.kadaTotal)),
        ],
      ),
    );
  }

  // ---- Waliopo na Wanaohamia kwa Mkoa --------------------------------------
  Widget _regionsCard() {
    final list = [...d.regions]..sort((a, b) => switch (_regionSort) {
          _Sort.moving => b.moving.compareTo(a.moving),
          _Sort.resident => b.resident.compareTo(a.resident),
          _Sort.total => b.total.compareTo(a.total),
        });
    final maxT = d.regions.map((r) => r.total).reduce(math.max);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: TablerIcons.map_pin,
              title: 'Waliopo na Wanaohamia kwa Mkoa',
              tag: '${d.regions.length}'),
          const _SubText('Walio + wanaohamia (chungwa) kila mkoa'),
          _SortBar(
              value: _regionSort,
              onChanged: (s) => setState(() => _regionSort = s)),
          for (var i = 0; i < list.length; i++)
            _RowDivider(
              first: i == 0,
              child: _RankedBarRow(
                rank: i + 1,
                name: list[i].name,
                total: list[i].total,
                resident: list[i].resident,
                moving: list[i].moving,
                maxTotal: maxT,
              ),
            ),
        ],
      ),
    );
  }

  // ---- Wanaohamia wanatoka wapi --------------------------------------------
  Widget _flowsCard() {
    final maxC = d.flows.map((f) => f.count).reduce(math.max);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: TablerIcons.route,
              title: 'Wanaohamia wanatoka wapi',
              tag: 'Top ${d.flows.length}'),
          const _SubText('Kila mkoa wanaohamia — wanatoka mikoa ipi'),
          for (var i = 0; i < d.flows.length; i++)
            _RowDivider(
              first: i == 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  children: [
                    Row(children: [
                      _RankBadge(i + 1),
                      const SizedBox(width: 10),
                      Text(d.flows[i].from,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _C.ink)),
                      const SizedBox(width: 8),
                      const Icon(TablerIcons.arrow_right,
                          size: 17, color: _C.arrow),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(d.flows[i].to,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _C.orange)),
                      ),
                      Text('${d.flows[i].count}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: _C.blue)),
                    ]),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 38),
                      child:
                          _Bar(fraction: d.flows[i].count / maxC, color: _C.orange),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Watu kwa Wilaya (same style as regions) -----------------------------
  Widget _districtsCard() {
    final list = [...d.districts]..sort((a, b) => switch (_districtSort) {
          _Sort.moving => b.moving.compareTo(a.moving),
          _Sort.resident => b.resident.compareTo(a.resident),
          _Sort.total => b.total.compareTo(a.total),
        });
    final maxT = d.districts.map((x) => x.total).reduce(math.max);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
              icon: TablerIcons.building_community,
              title: 'Watu kwa Wilaya',
              tag: '${d.districtsCount}'),
          const _SubText('Walio + wanaohamia (chungwa) kila wilaya'),
          _SortBar(
              value: _districtSort,
              onChanged: (s) => setState(() => _districtSort = s)),
          for (var i = 0; i < list.length; i++)
            _RowDivider(
              first: i == 0,
              child: _RankedBarRow(
                rank: i + 1,
                name: list[i].name,
                subtitle: list[i].region,
                total: list[i].total,
                resident: list[i].resident,
                moving: list[i].moving,
                maxTotal: maxT,
              ),
            ),
          const SizedBox(height: 10),
          Center(
            child: Text(
                'Zimeonyeshwa wilaya ${list.length} kati ya ${d.districtsCount}',
                style: const TextStyle(fontSize: 13, color: _C.muted2)),
          ),
        ],
      ),
    );
  }

  Widget _endMarker() => const Padding(
        padding: EdgeInsets.fromLTRB(0, 22, 0, 8),
        child: Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFE1E8F6), thickness: 1.5)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('Mwisho wa ukurasa',
                  style: TextStyle(fontSize: 13, color: _C.arrow)),
            ),
            Expanded(child: Divider(color: Color(0xFFE1E8F6), thickness: 1.5)),
          ],
        ),
      );
}

// ----------------------------------------------------------------------------
// Shared small widgets
// ----------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.border, width: 1.5),
        ),
        child: child,
      );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? tag;
  const _CardHeader({required this.icon, required this.title, this.tag});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            _IconTile(icon, size: 34, radius: 11, iconSize: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: _C.ink)),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.tagBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tag!,
                    style: const TextStyle(fontSize: 12.5, color: _C.blue)),
              ),
            ],
          ],
        ),
      );
}

class _SubText extends StatelessWidget {
  final String text;
  const _SubText(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 44, bottom: 12, top: 0),
        child: Transform.translate(
          offset: const Offset(0, -6),
          child: Text(text,
              style: const TextStyle(fontSize: 13.5, color: _C.muted3)),
        ),
      );
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;
  final Color bg;
  const _IconTile(this.icon,
      {required this.size,
      required this.radius,
      required this.iconSize,
      this.bg = _C.iconTile});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(icon, size: iconSize, color: _C.blue),
      );
}

class _RowDivider extends StatelessWidget {
  final bool first;
  final Widget child;
  const _RowDivider({required this.first, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: _C.soft, width: 1)),
        ),
        child: child,
      );
}

class _RankBadge extends StatelessWidget {
  final int n;
  const _RankBadge(this.n);

  @override
  Widget build(BuildContext context) {
    final top = n == 1;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: top ? _C.blue : _C.tileBg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text('$n',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: top ? Colors.white : _C.blue)),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  const _Bar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 6,
          color: _C.barBg,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0, 1).toDouble(),
            child: Container(color: color),
          ),
        ),
      );
}

class _TotalStrip extends StatelessWidget {
  final String value;
  const _TotalStrip(this.value);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _C.jmBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.optBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Jumla',
                style: TextStyle(fontSize: 14, color: _C.muted)),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: _C.ink)),
          ],
        ),
      );
}

class _SortBar extends StatelessWidget {
  final _Sort value;
  final ValueChanged<_Sort> onChanged;
  const _SortBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget item(_Sort s, String label) {
      final on = value == s;
      return GestureDetector(
        onTap: () => onChanged(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: on
                ? const [
                    BoxShadow(
                        color: Color(0x1A14224D),
                        blurRadius: 2,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                  color: on ? _C.blue : _C.muted)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _C.tileBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(_Sort.moving, 'Wanaohamia'),
            const SizedBox(width: 2),
            item(_Sort.resident, 'Waliopo'),
            const SizedBox(width: 2),
            item(_Sort.total, 'Jumla'),
          ],
        ),
      ),
    );
  }
}

/// Row used by BOTH the regions card and the districts card:
/// rank badge, name (+ optional region pin), total, two-colour bar, legend.
class _RankedBarRow extends StatelessWidget {
  final int rank;
  final String name;
  final String? subtitle;
  final int total;
  final int resident;
  final int moving;
  final int maxTotal;

  const _RankedBarRow({
    required this.rank,
    required this.name,
    this.subtitle,
    required this.total,
    required this.resident,
    required this.moving,
    required this.maxTotal,
  });

  @override
  Widget build(BuildContext context) {
    Widget legend(Color c, int v, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('$v',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: _C.ink)),
            Text(' $label',
                style: const TextStyle(fontSize: 13, color: _C.muted)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _RankBadge(rank),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _C.ink)),
                  if (subtitle != null)
                    Row(children: [
                      const Icon(TablerIcons.map_pin,
                          size: 13, color: _C.muted2),
                      const SizedBox(width: 3),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12.5, color: _C.muted2)),
                    ]),
                ],
              ),
            ),
            Text('$total',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: _C.ink)),
            const Text(' jumla',
                style: TextStyle(fontSize: 11.5, color: _C.muted2)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 8, bottom: 6),
            child: LayoutBuilder(builder: (_, c) {
              final w = c.maxWidth;
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 8,
                  width: w,
                  color: _C.barBg,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: w * resident / maxTotal,
                          height: 8,
                          child: const ColoredBox(color: _C.blue)),
                      SizedBox(
                          width: w * moving / maxTotal,
                          height: 8,
                          child: const ColoredBox(color: _C.orange)),
                    ],
                  ),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Wrap(
              spacing: 16,
              children: [
                legend(_C.blue, resident, 'waliopo'),
                legend(_C.orange, moving, 'wanaohamia'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Painters
// ----------------------------------------------------------------------------

/// Sparkline of the last 7 days: gradient area + line + highlighted peak dot.
class _SparklinePainter extends CustomPainter {
  final List<int> values;
  _SparklinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min).toDouble();
    final maxV = values.reduce(math.max).toDouble();
    final range = math.max(maxV - minV, 1);
    const left = 4.0, right = 124.0, topY = 12.0, botY = 50.0;
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = left + (right - left) * i / (values.length - 1);
      final y = botY - (values[i] - minV) / range * (botY - topY);
      pts.add(Offset(x, y));
    }

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, 62)
      ..lineTo(pts.first.dx, 62)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x381A3FA8), Color(0x001A3FA8)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = _C.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    var peak = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[peak]) peak = i;
    }
    canvas.drawCircle(pts[peak], 4, Paint()..color = Colors.white);
    canvas.drawCircle(
      pts[peak],
      4,
      Paint()
        ..color = _C.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.values != values;
}

class _Seg {
  final double fraction;
  final Color color;
  const _Seg(this.fraction, this.color);
}

/// Donut chart: background ring + coloured arcs with a small gap between.
class _DonutPainter extends CustomPainter {
  final List<_Seg> segs;
  _DonutPainter(this.segs);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final r = size.width / 2 - stroke / 2 - 6; // radius 42 on a 110 box
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = _C.barBg
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final gap = 2 / r; // radians
    var start = -math.pi / 2;
    for (final s in segs) {
      final sweep = 2 * math.pi * s.fraction;
      canvas.drawArc(
        rect,
        start,
        math.max(sweep - gap, 0),
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.segs != segs;
}

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------
String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// ============================================================================
// INTEGRATION LAYER — data halisi kutoka backend (Kubadilishana API)
//
// GET /admin/stats   → totals (users, users_active_7d, users_verified, …)
// GET /admin/reports → users_by_region / incoming_by_region /
//                      users_by_district / incoming_by_district /
//                      users_by_category / users_by_status /
//                      users_by_cadre / incoming_sources
// GET /admin/events  → events (event_type, occurred_at)
//
// StatisticsPage haiwahi kupewa null — mpaka data ije tunapesha loading,
// ikishindikana tunapesha error + "Jaribu tena". Hakuna demo data production.
// ============================================================================
class AdminStatisticsPage extends StatefulWidget {
  const AdminStatisticsPage({super.key});

  @override
  State<AdminStatisticsPage> createState() => _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends State<AdminStatisticsPage> {
  bool _loading = true;
  String? _error;
  StatsData? _data;

  String _mkoa = 'Mkoa wote';
  String _idara = 'Idara zote';
  String _ngazi = 'Ngazi zote';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final first = _data == null;
    setState(() {
      if (first) _loading = true;
      _error = null;
    });
    try {
      final s = await ApiService().adminStats();
      final r = await ApiService().adminReports(
        region: _mkoa == 'Mkoa wote' ? null : _mkoa,
        category: _deptCode(_idara),
        level: _levelCode(_ngazi),
      );
      final e = await ApiService().adminEvents(limit: 6);
      if (!mounted) return;
      final data = _buildStats(
        asMap(s.data),
        asMap(r.data),
        asList(asMap(e.data)['events']),
      );
      if (!mounted) return;
      if (data == null) {
        // Page inahesabu asilimia na reduce() — orodha tupu zingeicha.
        // Badala ya kuonyesha demo/data bandia, tuonyeshe error ya kweli.
        setState(() {
          _loading = false;
          _error = 'Hakuna takwimu zilizopatikana bado.';
        });
        return;
      }
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(err);
      });
    }
  }

  String? _deptCode(String label) {
    switch (label) {
      case 'Afya':
        return 'health';
      case 'Elimu':
        return 'education';
      case 'Kilimo na ufugaji':
        return 'kilimo';
      case 'Watumishi wa Umma':
        return 'watumishi_wa_umma';
      default:
        return null; // 'Idara zote' = hakuna filter
    }
  }

  String? _levelCode(String label) {
    if (label.startsWith('Primary')) return 'Primary';
    if (label.startsWith('Secondary')) return 'Secondary';
    return null; // 'Ngazi zote' = hakuna filter
  }

  static int _ti(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toInt() ?? 0;

  static List<Map<String, dynamic>> _list(Map<String, dynamic> reports, String k) {
    final v = reports[k];
    return (v is List ? v : const [])
        .map((e) => asMap(e))
        .toList();
  }

  static int _countFor(
      List<Map<String, dynamic>> rows, String key, String name) {
    for (final r in rows) {
      if ('${r[key]}' == name) return _ti(r, 'count');
    }
    return 0;
  }

  static String _deptLabel(String code) {
    switch (code) {
      case 'education':
        return 'Elimu';
      case 'health':
        return 'Afya';
      case 'kilimo':
        return 'Kilimo na ufugaji';
      case 'watumishi_wa_umma':
        return 'Watumishi wa Umma';
      default:
        return code.isEmpty ? 'unknown' : code;
    }
  }

  static IconData _deptIcon(String code) {
    switch (code) {
      case 'education':
        return TablerIcons.school;
      case 'health':
        return TablerIcons.stethoscope;
      case 'kilimo':
        return TablerIcons.plant_2;
      case 'watumishi_wa_umma':
        return TablerIcons.building_community;
      default:
        return TablerIcons.help_circle;
    }
  }

  static Color _deptColor(String code) {
    switch (code) {
      case 'education':
        return const Color(0xFF1A3FA8);
      case 'health':
        return const Color(0xFFE8590C);
      case 'kilimo':
        return const Color(0xFFB58105);
      case 'watumishi_wa_umma':
        return const Color(0xFF1D9E5A);
      default:
        return const Color(0xFF9AA8C8);
    }
  }

  /// Ramani kamili ya matukio halisi ya backend (event_log → GET /admin/events):
  /// kila event_type ina icon + maelezo ya Kiswahili, na pale payload ina
  /// maelezo halisi (jina, kiasi, score...) tunayatumia — SIYO majina ghafi
  /// kama "user.presence".
  /// Mkoa wa kituo (current_station) kutoka payload — hierarchic au flat.
  static String _stationRegion(Map<String, dynamic> m) {
    final payload = asMap(m['payload']);
    for (final src in [payload, m]) {
      final st = asMap(src['current_station'] ?? src['station']);
      final r = '${st['region_name'] ?? st['region'] ?? src['region_name'] ?? src['region'] ?? ''}'.trim();
      if (r.isNotEmpty) return r;
    }
    return '';
  }

  /// Maeneo ya kuomba (desired_destinations) — majina ya mikoa, yakiwa yangetenganishwa kwa koma.
  static String _destRegions(Map<String, dynamic> m) {
    final payload = asMap(m['payload']);
    for (final src in [payload, m]) {
      final raw = src['desired_destinations'] ?? src['destinations'];
      if (raw is List && raw.isNotEmpty) {
        final names = <String>[
          for (final d in raw)
            '${asMap(d)['region_name'] ?? asMap(d)['region'] ?? ''}'.trim(),
        ].where((n) => n.isNotEmpty).toList();
        if (names.isNotEmpty) return names.join(', ');
      }
      // Badiliko la destination linaweza kuja kama region moja
      final r = asMap(src['destination'])['region_name'] ?? src['region_name'];
      if ('$r'.trim().isNotEmpty) return '$r'.trim();
    }
    return '';
  }

  static (IconData, String) _eventDisplay(Map<String, dynamic> m) {
    final type = '${m['event_type'] ?? m['type'] ?? ''}';
    final payload = asMap(m['payload']);
    String p(String key) => '${payload[key] ?? m[key] ?? ''}'.trim();

    switch (type) {
      // ── Watumiaji ──
      case 'user.registered':
        final name = p('full_name');
        final cadre = p('cadre_code');
        var txt = name.isNotEmpty ? '$name amejiunga' : 'Mtumiaji mpya amejiunga';
        // Hamisho halisi: kutoka mkoa wa kituo → maeneo anayotaka kwenda.
        final from = _stationRegion(m);
        final to = _destRegions(m);
        if (from.isNotEmpty && to.isNotEmpty) {
          txt = '$txt — kutoka $from, anahamia $to';
        } else if (from.isNotEmpty) {
          txt = '$txt — kutoka $from';
        } else if (to.isNotEmpty) {
          txt = '$txt — anahamia $to';
        }
        if (cadre.isNotEmpty) txt = '$txt ($cadre)';
        return (TablerIcons.user_plus, txt);
      case 'user.profile_updated':
        final name = p('full_name');
        return (TablerIcons.user_edit,
            name.isNotEmpty ? '$name amesasisha wasifu wake' : 'Wasifu umesasishwa');
      case 'user.station_changed':
        final name = p('full_name');
        final toRegion =
            _destRegions(m).isNotEmpty ? _destRegions(m) : _stationRegion(m);
        if (name.isNotEmpty && toRegion.isNotEmpty) {
          return (TablerIcons.map_pin, '$name amehamia $toRegion');
        }
        if (name.isNotEmpty) return (TablerIcons.map_pin, '$name amehamia kituo kingine');
        return (TablerIcons.map_pin, 'Mtumiaji amehamia kituo kingine');
      case 'user.destination_changed':
        final name = p('full_name');
        final dests = _destRegions(m);
        if (name.isNotEmpty && dests.isNotEmpty) {
          return (TablerIcons.arrow_right, '$name sasa anataka kwenda $dests');
        }
        return (TablerIcons.arrow_right,
            name.isNotEmpty
                ? '$name amebadilisha maeneo anayotaka kwenda'
                : 'Maeneo ya kuomba yamebadilishwa');
      case 'user.updated_by_admin':
        return (TablerIcons.user_cog, 'Mtumiaji amesasishwa na admin');
      case 'user.deleted':
        return (TablerIcons.user_x, 'Mtumiaji amefutwa');
      case 'user.presence':
        return (TablerIcons.wifi, 'Mtumiaji ameingia mtandaoni');

      // ── Matches ──
      case 'match.found':
        final raw = payload['score'] ?? m['score'];
        var score = '';
        if (raw != null) {
          final v = double.tryParse('$raw');
          if (v != null) score = ' — ${v <= 1 ? (v * 100).round() : v.round()}%';
        }
        return (TablerIcons.link, 'Match mpya imepatikana$score');

      // ── Ujumbe na simu ──
      case 'message.sent':
        final from = p('from_full_name');
        return (TablerIcons.message,
            from.isNotEmpty ? 'Ujumbe mpya kutoka $from' : 'Ujumbe mpya umetumwa');
      case 'call.initiated':
        final from = p('from_full_name');
        return (TablerIcons.phone_call,
            from.isNotEmpty ? '$from amepigiana simu' : 'Simu imepigiana');

      // ── Malipo ──
      case 'payment.submitted':
        return (TablerIcons.wallet,
            'Mchango wa TZS ${p('amount')} unasubiri uthibitisho');
      case 'payment.approved':
        return (TablerIcons.coin,
            'Mchango wa TZS ${p('amount')} umethibitishwa');
      case 'payment.rejected':
        return (TablerIcons.credit_card, 'Mchango umekataliwa');

      // ── Maoni ──
      case 'feedback.new':
        return (TablerIcons.message_2, 'Maoni mapya yamefika');
      case 'feedback.replied':
        return (TablerIcons.shield_check, 'Maoni yamejibiwa na admin');

      // ── Matangazo na data ──
      case 'announcement':
        final title = p('title');
        return (TablerIcons.speakerphone,
            title.isNotEmpty ? 'Tangazo: $title' : 'Tangazo jipya limetumwa');
      case 'data.changed':
        final kind = _dataKindLabel(p('kind'));
        final action = _dataActionLabel(p('action'));
        return (TablerIcons.refresh, 'Data $kind $action');

      // ── Nenosiri / barua pepe ──
      case 'password_reset.requested':
        return (TablerIcons.help_circle, 'Ombi la kubadilisha nenosiri');
      case 'password_reset.completed':
        return (TablerIcons.lock, 'Nenosiri limebadilishwa');
      case 'email.verification.requested':
        return (TablerIcons.mail, 'Ombi la kuthibitisha barua pepe');
      case 'email.verified':
        return (TablerIcons.mail_opened, 'Barua pepe imethibitishwa');

      // ── Hawajulikani: tafsiri kwa uangalifu (siyo code ghafi) ──
      default:
        if (type.isEmpty) return (TablerIcons.bell, 'Tukio');
        final last = type.split('.').last.replaceAll('_', ' ').trim();
        final pretty = last.isEmpty
            ? 'Tukio'
            : last[0].toUpperCase() + last.substring(1);
        return (TablerIcons.bell, 'Tukio: $pretty');
    }
  }

  static String _dataKindLabel(String kind) {
    switch (kind) {
      case 'department': return 'ya idara';
      case 'cadre': return 'ya kada';
      case 'subject': return 'ya somo';
      case 'region': return 'ya mkoa';
      case 'district': return 'ya wilaya';
      case 'facility': return 'ya kituo';
      case 'school': return 'ya shule';
      default: return kind.isEmpty ? '' : '($kind)';
    }
  }

  static String _dataActionLabel(String action) {
    switch (action) {
      case 'created': return 'imeongezwa';
      case 'updated': return 'imesasishwa';
      case 'deleted': return 'imefutwa';
      default: return action.isEmpty ? 'imebadilishwa' : action;
    }
  }

  static String _hm(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  StatsData? _buildStats(
    Map<String, dynamic> stats,
    Map<String, dynamic> reports,
    List<dynamic> eventsRaw,
  ) {
    final totals = asMap(stats['totals']);

    final byRegion = _list(reports, 'users_by_region');
    final inRegion = _list(reports, 'incoming_by_region');
    final byDistrict = _list(reports, 'users_by_district');
    final inDistrict = _list(reports, 'incoming_by_district');
    final byCategory = _list(reports, 'users_by_category');
    final byStatus = _list(reports, 'users_by_status');
    final byCadre = _list(reports, 'users_by_cadre');
    final sources = _list(reports, 'incoming_sources');

    final totalUsers = _ti(totals, 'users');
    if (totalUsers <= 0 ||
        byRegion.isEmpty ||
        inRegion.isEmpty ||
        byDistrict.isEmpty ||
        inDistrict.isEmpty ||
        byCategory.isEmpty ||
        byCadre.isEmpty ||
        sources.isEmpty) {
      return null;
    }

    // Sparkline: backend bado haina mfululizo wa kila siku — tunagawa
    // users_active_7d sawasawa kwenye siku 7 (jumla halisi, sio demo).
    final newWeek = _ti(totals, 'users_active_7d');
    final base = newWeek ~/ 7;
    final rem = newWeek % 7;
    final weeklyNew = [for (var i = 0; i < 7; i++) base + (i < rem ? 1 : 0)];

    final departments = <DeptStat>[
      for (final m in byCategory)
        DeptStat(
          _deptLabel('${m['category'] ?? ''}'),
          _deptIcon('${m['category'] ?? ''}'),
          _deptColor('${m['category'] ?? ''}'),
          _ti(m, 'count'),
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));

    int levelCount(String level) => byCadre
        .where((c) => '${c['level'] ?? ''}' == level)
        .fold(0, (s, c) => s + _ti(c, 'count'));
    final teachersSecondary = levelCount('Secondary');
    final teachersPrimary = levelCount('Primary');
    final teachersNone = byCadre
        .where((c) => '${c['level'] ?? ''}'.isEmpty)
        .fold(0, (s, c) => s + _ti(c, 'count'));

    final kada = <KadaStat>[
      for (final m in byCadre)
        KadaStat(
          '${m['cadre'] ?? ''}'.isEmpty
              ? _deptLabel('${m['category'] ?? ''}')
              : '${m['cadre']}',
          _ti(m, 'count'),
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));
    final kadaTotal = kada.fold(0, (s, k) => s + k.count);

    final regionNames = <String>{
      for (final m in byRegion) '${m['region'] ?? ''}',
      for (final m in inRegion) '${m['region'] ?? ''}',
    }..removeWhere((n) => n.isEmpty);
    final regions = <RegionStat>[
      for (final n in regionNames)
        RegionStat(
          n,
          _countFor(byRegion, 'region', n),
          _countFor(inRegion, 'region', n),
        ),
    ];

    final flows = <MoveFlow>[
      for (final m in sources)
        MoveFlow('${m['from'] ?? ''}', '${m['to'] ?? ''}', _ti(m, 'count')),
    ];

    final districtNames = <String>{
      for (final m in byDistrict) '${m['district'] ?? ''}',
      for (final m in inDistrict) '${m['district'] ?? ''}',
    }..removeWhere((n) => n.isEmpty);
    final districts = <DistrictStat>[
      for (final n in districtNames)
        DistrictStat(
          n,
          '${asMap(byDistrict.firstWhere((d) => '${d['district']}' == n,
              orElse: () => <String, dynamic>{}))['region'] ?? ''}',
          _countFor(byDistrict, 'district', n),
          _countFor(inDistrict, 'district', n),
        ),
    ];

    final events = <StatsEvent>[
      for (final raw in eventsRaw.take(6))
        () {
          final m = asMap(raw);
          final (icon, text) = _eventDisplay(m);
          return StatsEvent(icon, text, _hm('${m['occurred_at'] ?? ''}'));
        }(),
    ];

    final activeRow = byStatus.isEmpty
        ? <String, dynamic>{'status': 'active', 'count': totalUsers}
        : byStatus.firstWhere(
            (m) => '${m['status']}' == 'active',
            orElse: () => byStatus.first,
          );

    return StatsData(
      totalUsers: totalUsers,
      newThisWeek: newWeek,
      weeklyNew: weeklyNew,
      totalMovers:
          inRegion.fold(0, (s, m) => s + _ti(m, 'count')),
      verified: _ti(totals, 'users_verified'),
      regionsCount: _ti(reports, 'regions_total') > 0
          ? _ti(reports, 'regions_total')
          : regions.length,
      districtsCount: _ti(reports, 'districts_total') > 0
          ? _ti(reports, 'districts_total')
          : districts.length,
      events: events,
      departments: departments,
      activeCount: _ti(activeRow, 'count'),
      teachersPrimary: teachersPrimary,
      teachersSecondary: teachersSecondary,
      teachersNone: teachersNone,
      kada: kada,
      kadaTotal: kadaTotal,
      regions: regions,
      flows: flows,
      districts: districts,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(
          child: CircularProgressIndicator(color: _C.blue));
    }
    if (_error != null && _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFE03131), size: 48),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Jaribu tena'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return StatisticsPage(
      data: _data!, // kamwe null hapa — guards hapo juu
      onFiltersChanged: (mkoa, idara, ngazi) {
        setState(() {
          _mkoa = mkoa;
          _idara = idara;
          _ngazi = ngazi;
        });
        _load();
      },
    );
  }
}
