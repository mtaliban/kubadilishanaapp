import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kBlue     = Color(0xFF1E40AF);
const _kBlueBg   = Color(0xFFEFF6FF);
const _kBlueDark = Color(0xFF1D4ED8);
const _kGreen    = Color(0xFF16A34A);
const _kGreenBg  = Color(0xFFDCFCE7);
const _kAmber    = Color(0xFFD97706);
const _kAmberBg  = Color(0xFFFEF3C7);
const _kRed      = Color(0xFFDC2626);
const _kRedBg    = Color(0xFFFEE2E2);
const _kGrey900  = Color(0xFF111827);
const _kGrey700  = Color(0xFF374151);
const _kGrey600  = Color(0xFF4B5563);
const _kGrey500  = Color(0xFF6B7280);
const _kGrey400  = Color(0xFF9CA3AF);
const _kGrey200  = Color(0xFFE5E7EB);
const _kGrey100  = Color(0xFFF3F4F6);
const _kGrey50   = Color(0xFFF9FAFB);

class AdminDataPage extends StatefulWidget {
  const AdminDataPage({super.key});
  @override
  State<AdminDataPage> createState() => _AdminDataPageState();
}

class _AdminDataPageState extends State<AdminDataPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final Map<String, bool>                  _loading      = {};
  final Map<String, String?>               _errors       = {};
  final Map<String, List<dynamic>>         _cache        = {};
  final Map<String, TextEditingController> _searchCtrls  = {};
  final Map<String, String>                _levelFilters = {};
  final Map<String, String>                _regionFilters = {};

  // Facilities level chip filter ('': Zote, 'Dispensary': ...etc)
  String _facLevelFilter = '';

  static const _types      = ['departments', 'subjects', 'cadres', 'regions', 'districts', 'facilities'];
  static const _typeLabels  = ['Idara', 'Masomo', 'Kada', 'Mikoa', 'Wilaya', 'Vituo'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _types.length, initialIndex: 1, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final type = _types[_tabCtrl.index];
        if (!_cache.containsKey(type)) _loadType(type);
        if ((type == 'districts' || type == 'facilities') &&
            !_cache.containsKey('regions')) {
          _loadType('regions');
        }
      }
    });
    for (final t in _types) {
      _searchCtrls[t] = TextEditingController()..addListener(() => setState(() {}));
    }
    _loadType('subjects');
    _loadType('regions');
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in _searchCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadType(String type) async {
    setState(() { _loading[type] = true; _errors[type] = null; });
    try {
      final res = await ApiService().adminListData(type);
      if (!mounted) return;
      final data = res.data;
      _cache[type] = data is List
          ? data
          : ((data['results'] ?? data['items'] ?? data['users'] ?? data['data'] ?? []) as List);
      setState(() { _loading[type] = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading[type] = false; _errors[type] = e.toString(); });
    }
  }

  List<dynamic> _filtered(String type) {
    final all = _cache[type] ?? [];
    final q   = _searchCtrls[type]?.text.toLowerCase() ?? '';

    return all.where((raw) {
      final m      = raw as Map<String, dynamic>;
      final name   = (m['name'] as String? ?? m['display_name'] as String? ?? '').toLowerCase();
      final code   = (m['code'] as String? ?? '').toLowerCase();
      final idStr  = m['id']?.toString() ?? '';
      final matchQ = q.isEmpty || name.contains(q) || code.contains(q) || idStr.contains(q);

      if (type == 'subjects') {
        final lf    = _levelFilters['subjects'] ?? '';
        final level = (m['level'] as String? ?? '').toLowerCase();
        return matchQ && (lf.isEmpty || level == lf.toLowerCase());
      }
      if (type == 'districts') {
        final rf  = _regionFilters['districts'] ?? '';
        if (rf.isEmpty) return matchQ;
        return matchQ && m['region_id']?.toString() == rf;
      }
      if (type == 'facilities') {
        if (!matchQ) return false;
        if (_facLevelFilter.isEmpty) return true;
        final lvl = (m['level'] ?? m['type'] ?? '') as String? ?? '';
        return lvl.toLowerCase() == _facLevelFilter.toLowerCase();
      }
      return matchQ;
    }).toList();
  }

  void _showAddEdit(String type, {Map<String, dynamic>? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DataFormSheet(
        type: type,
        item: item,
        onSaved: () { _cache.remove(type); _loadType(type); },
      ),
    );
  }

  Future<void> _delete(String type, Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? item['code']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa'),
        content: Text('Futa "${item['name'] ?? item['display_name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Futa', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().adminDeleteData(type, id);
      if (!mounted) return;
      _cache.remove(type);
      _loadType(type);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  String _getRegionName(Map<String, dynamic> item) {
    final direct = (item['region_name'] ?? item['region']) as String? ?? '';
    if (direct.isNotEmpty) return direct;
    final rid = item['region_id'];
    if (rid == null) return '';
    for (final r in (_cache['regions'] ?? [])) {
      final rm = r as Map<String, dynamic>;
      if (rm['id'] == rid) return rm['name'] as String? ?? '';
    }
    return rid.toString();
  }

  List<Widget> _buildBadges(String type, Map<String, dynamic> item) {
    Widget pill(String label, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, height: 1.5, color: fg)),
    );

    switch (type) {
      case 'departments':
        final disabled = item['status'] == 'disabled';
        return [pill(disabled ? 'Imezimwa' : '● Hai',
            disabled ? _kRedBg : _kGreenBg, disabled ? _kRed : _kGreen)];
      case 'subjects':
        final level = (item['level'] as String? ?? '').toLowerCase();
        if (level.isEmpty) return [];
        final isSecondary = level == 'secondary';
        return [pill(isSecondary ? 'Secondary' : 'Primary',
            isSecondary ? _kAmberBg : _kBlueBg,
            isSecondary ? _kAmber   : _kBlueDark)];
      case 'cadres':
        final cat   = item['category'] as String? ?? '';
        final level = item['level'] as String? ?? '';
        return [
          if (cat.isNotEmpty)   pill(cat,   _kBlueBg,  _kBlueDark),
          if (level.isNotEmpty) pill(level, _kAmberBg, _kAmber),
        ];
      case 'districts':
        final rn = _getRegionName(item);
        if (rn.isEmpty) return [];
        return [pill(rn, _kBlueBg, _kBlueDark)];
      case 'facilities':
        final tl = (item['level'] ?? item['type'] ?? item['type_category']) as String? ?? '';
        if (tl.isEmpty) return [];
        return [pill(tl, _kBlueBg, _kBlueDark)];
      default:
        return [];
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────

  static const _tabIcons = [
    Icons.domain_rounded,        // Idara
    Icons.menu_book_rounded,     // Masomo
    Icons.work_outline_rounded,  // Kada
    Icons.terrain_rounded,       // Mikoa
    Icons.map_outlined,          // Wilaya
    Icons.local_hospital_outlined, // Vituo
  ];

  Widget _tabBar() => Container(
    color: Colors.white,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _kGrey200)),
    ),
    child: TabBar(
      controller: _tabCtrl,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: _kBlue,
      unselectedLabelColor: _kGrey500,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: _kBlue, width: 2),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      padding: EdgeInsets.zero,
      tabs: List.generate(_typeLabels.length, (i) => Tab(
        height: 40,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_tabIcons[i], size: 14),
          const SizedBox(width: 5),
          Text(_typeLabels[i]),
        ]),
      )),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _kBlueBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.dns_rounded, color: _kBlue, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Data',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kGrey900)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6,
                              decoration: const BoxDecoration(color: _kGrey500, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('LIVE', style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: _kGrey500, letterSpacing: 0.5)),
                        ]),
                      ),
                    ]),
                    const Text('Simamia data za mfumo',
                        style: TextStyle(fontSize: 13, color: _kGrey500)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
        body: Column(
          children: [
            _tabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: _types.map(_buildTabContent).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String type) {
    final loading  = _loading[type] ?? false;
    final error    = _errors[type];
    final filtered = _filtered(type);

    return RefreshIndicator(
      onRefresh: () async { _cache.remove(type); await _loadType(type); },
      color: _kBlue,
      child: CustomScrollView(
        key: PageStorageKey<String>(type),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _buildFilterArea(type, filtered.length),
            ),
          ),
          if (loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: _kBlue)),
            )
          else if (error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: _kRed, size: 48),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () { _cache.remove(type); _loadType(type); },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Jaribu tena'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Colors.white),
                  ),
                ]),
              ),
            )
          else if (filtered.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inbox_outlined, size: 48, color: _kGrey400),
                  SizedBox(height: 8),
                  Text('Hakuna data', style: TextStyle(fontSize: 14, color: _kGrey500)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _kGrey200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildItem(type, filtered[i] as Map<String, dynamic>),
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterArea(String type, int count) {
    const countLabels = {
      'departments': 'idara', 'subjects': 'masomo', 'cadres': 'kada',
      'regions': 'mikoa', 'districts': 'wilaya', 'facilities': 'vituo',
    };
    const searchHints = {
      'departments': 'Tafuta idara...', 'subjects': 'Tafuta masomo...',
      'cadres': 'Tafuta kada...', 'regions': 'Tafuta mkoa...',
      'districts': 'Tafuta wilaya...', 'facilities': 'Tafuta kituo...',
    };
    final label = countLabels[type] ?? type;
    final hint  = searchHints[type] ?? 'Tafuta...';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Row 1: count + Ongeza
      Row(children: [
        Expanded(
          child: Text('$count $label zilizosajiliwa',
              style: const TextStyle(fontSize: 13, color: _kGrey500)),
        ),
        _addBtn(type),
      ]),
      const SizedBox(height: 10),
      // Row 2: search
      TextField(
        controller: _searchCtrls[type],
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: _kGrey400),
          filled: true,
          fillColor: _kGrey50,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        ),
      ),
      // Row 3: chips or dropdown depending on type
      if (type == 'subjects') ...[
        const SizedBox(height: 6),
        _chipRow(
          options: const {'': 'Viwango vyote', 'primary': 'Primary', 'secondary': 'Secondary'},
          selected: _levelFilters['subjects'] ?? '',
          onSelect: (v) => setState(() => _levelFilters['subjects'] = v),
        ),
      ],
      if (type == 'facilities') ...[
        const SizedBox(height: 6),
        _facChips(),
      ],
      if (type == 'districts') ...[
        const SizedBox(height: 6),
        _regionFilterChip(),
      ],
    ]);
  }

  // Chips for subjects / simple option sets
  Widget _chipRow({
    required Map<String, String> options,
    required String selected,
    required void Function(String) onSelect,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final e in options.entries) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected == e.key ? _kBlueBg : Colors.white,
                border: Border.all(
                    color: selected == e.key ? _kBlue : _kGrey200, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(e.value, style: TextStyle(
                fontSize: 12,
                fontWeight: selected == e.key ? FontWeight.w700 : FontWeight.w500,
                color: selected == e.key ? _kBlue : _kGrey700,
              )),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }

  // Dynamic chips from facility level values in data
  Widget _facChips() {
    final seen = <String>{};
    final levels = <String>[''];
    for (final raw in (_cache['facilities'] ?? [])) {
      final lvl = ((raw as Map)['level'] ?? raw['type'] ?? '') as String? ?? '';
      if (lvl.isNotEmpty && seen.add(lvl)) levels.add(lvl);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final lvl in levels) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _facLevelFilter = lvl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _facLevelFilter == lvl ? _kBlueBg : Colors.white,
                border: Border.all(
                    color: _facLevelFilter == lvl ? _kBlue : _kGrey200, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(lvl.isEmpty ? 'Zote' : lvl, style: TextStyle(
                fontSize: 12,
                fontWeight: _facLevelFilter == lvl ? FontWeight.w700 : FontWeight.w500,
                color: _facLevelFilter == lvl ? _kBlue : _kGrey700,
              )),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }

  Widget _addBtn(String type) {
    return GestureDetector(
      onTap: () => _showAddEdit(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(12)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, color: Colors.white, size: 15),
          SizedBox(width: 4),
          Text('Ongeza', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _regionFilterChip() {
    final regions = (_cache['regions'] ?? []).cast<Map<String, dynamic>>();
    final selId   = _regionFilters['districts'] ?? '';
    final selName = selId.isEmpty ? null
        : regions.firstWhere((r) => r['id'].toString() == selId,
            orElse: () => <String, dynamic>{})['name'] as String?;
    return GestureDetector(
      onTap: () => _showDataPicker(
        title: 'Chagua Mkoa',
        items: [
          (label: 'Mikoa yote', value: ''),
          ...regions.map((r) => (label: r['name'] as String? ?? '', value: r['id'].toString())),
        ],
        onPick: (v) => setState(() => _regionFilters['districts'] = v),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selId.isEmpty ? Colors.white : _kBlueBg,
          border: Border.all(color: selId.isEmpty ? _kGrey200 : _kBlue, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(selName ?? 'Mkoa wote', style: TextStyle(
            fontSize: 12,
            fontWeight: selId.isEmpty ? FontWeight.w500 : FontWeight.w700,
            color: selId.isEmpty ? _kGrey700 : _kBlue,
          )),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 14,
              color: selId.isEmpty ? _kGrey400 : _kBlue),
        ]),
      ),
    );
  }

  void _showDataPicker({
    required String title,
    required List<({String label, String value})> items,
    required void Function(String) onPick,
  }) {
    final ctrl = TextEditingController();
    List<({String label, String value})> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(children: [
            const SizedBox(height: 6),
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700),
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
                  ss(() => filtered = items.where((i) => i.label.toLowerCase().contains(ql)).toList());
                },
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 18),
                  fillColor: _kGrey100, filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: _kGrey200),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  return InkWell(
                    onTap: () { Navigator.pop(ctx); onPick(item.value); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _kGrey100)),
                      ),
                      child: Text(item.label,
                          style: const TextStyle(fontSize: 15, color: _kGrey900)),
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

  // Colored icon kwa kila aina ya data (kama mockup)
  (IconData, Color, Color) _itemIcon(String type, Map<String, dynamic> item) {
    if (type == 'facilities') {
      final hasSchool = item['school_code'] != null;
      final lvl = (item['level'] as String? ?? '').toLowerCase();
      final isEdu = hasSchool || lvl == 'primary' || lvl == 'secondary';
      return isEdu
          ? (Icons.school_outlined, const Color(0xFF15803D), const Color(0xFFF0FDF4))
          : (Icons.local_hospital_outlined, _kRed, _kRedBg);
    }
    if (type == 'cadres') {
      final cat = (item['category'] as String? ?? '').toLowerCase();
      return cat == 'education'
          ? (Icons.menu_book_rounded, const Color(0xFF15803D), const Color(0xFFF0FDF4))
          : (Icons.medical_services_outlined, _kRed, _kRedBg);
    }
    if (type == 'subjects') return (Icons.menu_book_rounded, _kAmber, _kAmberBg);
    if (type == 'departments') return (Icons.domain_rounded, _kBlue, _kBlueBg);
    if (type == 'regions') return (Icons.terrain_rounded, _kBlue, _kBlueBg);
    if (type == 'districts') return (Icons.map_outlined, _kBlue, _kBlueBg);
    return (Icons.circle_outlined, _kGrey600, _kGrey100);
  }

  Widget _buildItem(String type, Map<String, dynamic> item) {
    final name    = (item['name'] ?? item['display_name'] ?? '') as String? ?? '';
    final code    = item['code'] as String? ?? item['school_code'] as String? ?? item['id']?.toString() ?? '';
    final badges  = _buildBadges(type, item);
    final dimmed  = type == 'departments' && item['status'] == 'disabled';
    final facSub  = type == 'facilities'
        ? [_getRegionName(item), (item['district_name'] ?? item['district']) as String? ?? '']
            .where((s) => s.isNotEmpty).join(' · ')
        : '';
    final (ico, icoFg, icoBg) = _itemIcon(type, item);

    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Colored icon box
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: icoBg, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(ico, size: 20, color: icoFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey900),
                  overflow: TextOverflow.ellipsis),
              if (code.isNotEmpty || badges.isNotEmpty || facSub.isNotEmpty)
                const SizedBox(height: 3),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (code.isNotEmpty)
                  Text(code, style: const TextStyle(fontSize: 11, color: _kGrey500, fontFamily: 'monospace')),
                ...badges,
              ]),
              if (facSub.isNotEmpty)
                Text(facSub, style: const TextStyle(fontSize: 11, color: _kGrey500),
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          _RowAction(
            onEdit:   () => _showAddEdit(type, item: item),
            onDelete: () => _delete(type, item),
          ),
        ]),
      ),
    );
  }
}

// ─── Row action buttons — outlined square [✎][🗑] kama mockup ────────────────

class _RowAction extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RowAction({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _sq(Icons.edit_rounded, _kGrey600, onEdit),
      const SizedBox(width: 6),
      _sq(Icons.delete_outline_rounded, _kRed, onDelete),
    ]);
  }

  Widget _sq(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _kGrey200),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: color),
        ),
      );
}

// ─── Add / Edit form sheet ────────────────────────────────────────────────────

class _DataFormSheet extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? item;
  final VoidCallback onSaved;
  const _DataFormSheet({required this.type, this.item, required this.onSaved});

  @override
  State<_DataFormSheet> createState() => _DataFormSheetState();
}

class _DataFormSheetState extends State<_DataFormSheet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _iconCtrl = TextEditingController();
  String _category        = 'health';
  String _level           = 'Primary';
  String _status          = 'active';
  bool   _requiresSubjects = false;
  bool   _saving           = false;
  List<dynamic> _regions        = [];
  String?       _selectedRegion;
  String?       _selectedDistrict;
  List<dynamic> _districts      = [];
  List<dynamic> _departments    = [];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      final it = widget.item!;
      _nameCtrl.text    = (it['display_name'] ?? it['name'] ?? '') as String? ?? '';
      _codeCtrl.text    = it['code'] as String? ?? '';
      _iconCtrl.text    = (it['icon'] ?? '') as String? ?? '';
      _category         = it['category'] as String? ?? 'health';
      _status           = it['status'] as String? ?? 'active';
      _requiresSubjects = (it['requires_subjects'] as bool?) ?? false;
      final lvl = (it['level'] ?? it['type'] ?? '') as String? ?? '';
      if (widget.type == 'subjects') {
        _level = lvl.toLowerCase() == 'secondary' ? 'Secondary' : 'Primary';
      } else {
        _level = lvl.isNotEmpty ? lvl : 'dispensary';
      }
    } else {
      _level = widget.type == 'subjects' ? 'Primary' : 'dispensary';
    }
    if (widget.type == 'facilities') {
      _loadRegions();
      if (widget.item != null) {
        final rid = widget.item!['region_id'];
        final did = widget.item!['district_id'];
        if (rid != null) {
          _selectedRegion = rid.toString();
          _loadDistricts(rid.toString());
        }
        if (did != null) _selectedDistrict = did.toString();
      }
    }
    if (widget.type == 'cadres') _loadDepartments();
  }

  static String _slug(String name) {
    final buf = StringBuffer();
    for (final ch in name.trim().toLowerCase().split('')) {
      if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buf.write(ch);
      } else if (buf.isNotEmpty && !buf.toString().endsWith('_')) {
        buf.write('_');
      }
    }
    var code = buf.toString();
    while (code.endsWith('_')) { code = code.substring(0, code.length - 1); }
    return code.isEmpty ? 'item' : code;
  }

  Future<void> _loadDepartments() async {
    try {
      final res = await ApiService().adminListData('departments');
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _departments = data is List ? data : ((data['results'] ?? data['items'] ?? []) as List);
      });
    } catch (_) {}
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _regions = data is List ? data : (data['results'] as List? ?? []);
      });
    } catch (_) {}
  }

  Future<void> _loadDistricts(String regionId) async {
    try {
      final res = await ApiService().getDistricts(int.parse(regionId));
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _districts = data is List ? data : (data['results'] as List? ?? []);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() { _saving = true; });
    try {
      final typedCode = _codeCtrl.text.trim();
      final slug = typedCode.isNotEmpty ? typedCode : _slug(name);
      final data = <String, dynamic>{'name': name};

      switch (widget.type) {
        case 'departments':
          data['code']   = slug.toLowerCase();
          data['status'] = _status;
          if (_iconCtrl.text.trim().isNotEmpty) data['icon'] = _iconCtrl.text.trim();
        case 'subjects':
          data['code']  = slug.toUpperCase();
          data['level'] = _level;
        case 'cadres':
          data.remove('name');
          data['code']              = slug.toUpperCase();
          data['display_name']      = name;
          data['category']          = _category;
          data['requires_subjects'] = _requiresSubjects;
          if (_level == 'Primary' || _level == 'Secondary') data['level'] = _level;
        case 'regions':
          break;
        case 'districts':
          break;
        case 'facilities':
          data['category'] = _category;
          data['type']     = _level;
          if (_selectedRegion != null)   data['region_id']   = int.parse(_selectedRegion!);
          if (_selectedDistrict != null) data['district_id'] = int.parse(_selectedDistrict!);
          if (_selectedRegion == null || _selectedDistrict == null) {
            if (!mounted) return;
            setState(() { _saving = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chagua mkoa na wilaya'), backgroundColor: _kAmber),
            );
            return;
          }
      }

      final id = widget.item?['id']?.toString() ?? widget.item?['code']?.toString();
      if (id != null && id.isNotEmpty) {
        await ApiService().adminUpdateData(widget.type, id, data);
      } else {
        await ApiService().adminCreateData(widget.type, data);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  // ── Display helpers ───────────────────────────────────────────────────────
  String get _deptLabel {
    if (_category.isEmpty || _departments.isEmpty) return '';
    final d = _departments.firstWhere(
      (x) => (x as Map)['code'] == _category,
      orElse: () => <String, dynamic>{},
    ) as Map<String, dynamic>;
    return d['name'] as String? ?? _category;
  }

  String? get _regionLabel {
    if (_selectedRegion == null) return null;
    for (final r in _regions) {
      if ((r as Map)['id'].toString() == _selectedRegion) return r['name'] as String?;
    }
    return _selectedRegion;
  }

  String? get _districtLabel {
    if (_selectedDistrict == null) return null;
    for (final d in _districts) {
      if ((d as Map)['id'].toString() == _selectedDistrict) return d['name'] as String?;
    }
    return _selectedDistrict;
  }

  // ── Tappable picker button ────────────────────────────────────────────────
  Widget _pickerBtn({required String hint, String? value, required VoidCallback onTap, bool disabled = false}) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: disabled ? _kGrey50 : Colors.white,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              value ?? hint,
              style: TextStyle(fontSize: 14, color: value != null ? _kGrey900 : _kGrey400),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18,
              color: value != null ? _kGrey500 : _kGrey400),
        ]),
      ),
    );
  }

  // ── Bottom-sheet picker ───────────────────────────────────────────────────
  void _openPicker({
    required String title,
    required List<({String label, String value})> items,
    required void Function(String) onPick,
  }) {
    final ctrl = TextEditingController();
    List<({String label, String value})> filtered = List.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(children: [
            const SizedBox(height: 6),
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700),
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
                  ss(() => filtered = items.where((i) => i.label.toLowerCase().contains(ql)).toList());
                },
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 18),
                  fillColor: _kGrey100, filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: _kGrey200),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  return InkWell(
                    onTap: () { Navigator.pop(ctx); onPick(item.value); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: _kGrey100)),
                      ),
                      child: Text(item.label,
                          style: const TextStyle(fontSize: 15, color: _kGrey900)),
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue)),
  );

  String get _title {
    final action = widget.item != null ? 'Hariri' : 'Ongeza';
    switch (widget.type) {
      case 'departments': return '$action Idara';
      case 'subjects':    return '$action Somo';
      case 'cadres':      return '$action Kada';
      case 'regions':     return '$action Mkoa';
      case 'districts':   return '$action Wilaya';
      case 'facilities':  return '$action Kituo';
      default: return action;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(_title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),
          if (widget.type == 'facilities') ...[
            _pickerBtn(
              hint: 'Chagua mkoa *',
              value: _regionLabel,
              onTap: () => _openPicker(
                title: 'Chagua Mkoa',
                items: _regions.map((r) => (
                    label: (r as Map)['name'] as String? ?? '',
                    value: r['id'].toString(),
                )).toList(),
                onPick: (v) {
                  setState(() { _selectedRegion = v; _selectedDistrict = null; _districts = []; });
                  _loadDistricts(v);
                },
              ),
            ),
            const SizedBox(height: 12),
            _pickerBtn(
              hint: _selectedRegion == null ? 'Chagua mkoa kwanza' : 'Chagua wilaya *',
              value: _districtLabel,
              disabled: _selectedRegion == null,
              onTap: () => _openPicker(
                title: 'Chagua Wilaya',
                items: _districts.map((d) => (
                    label: (d as Map)['name'] as String? ?? '',
                    value: d['id'].toString(),
                )).toList(),
                onPick: (v) => setState(() => _selectedDistrict = v),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameCtrl,
            decoration: _dec(widget.type == 'cadres' ? 'Jina la kada *' : 'Jina *'),
          ),
          const SizedBox(height: 12),
          if (widget.type != 'facilities' && widget.type != 'regions' &&
              widget.type != 'districts')
            TextField(
              controller: _codeCtrl,
              decoration: _dec('Code (ikiachiwa wazi tunautengeneza wenyewe)'),
            ),
          if (widget.type == 'facilities') ...[
            const SizedBox(height: 12),
            Row(children: [
              _TogglePill(label: 'Afya',  selected: _category == 'health',
                  color: _kRed,  onTap: () => setState(() => _category = 'health')),
              const SizedBox(width: 8),
              _TogglePill(label: 'Elimu', selected: _category == 'education',
                  color: _kBlue, onTap: () => setState(() => _category = 'education')),
            ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final t in const ['dispensary', 'health_center', 'hospital', 'laboratory', 'clinic']) ...[
                  _TogglePill(
                    label: t,
                    selected: _level.toLowerCase() == t,
                    color: _kBlue,
                    onTap: () => setState(() => _level = t),
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
            ),
          ],
          if (widget.type == 'departments') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _iconCtrl,
              decoration: _dec('Ikoni (emoji, k.m. 🏥 — hiari)'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _TogglePill(label: 'Hai',      selected: _status == 'active',
                  color: _kGreen, onTap: () => setState(() { _status = 'active'; })),
              const SizedBox(width: 8),
              _TogglePill(label: 'Imezimwa', selected: _status == 'disabled',
                  color: _kAmber, onTap: () => setState(() { _status = 'disabled'; })),
            ]),
          ],
          if (widget.type == 'cadres') ...[
            const SizedBox(height: 12),
            _pickerBtn(
              hint: 'Chagua idara *',
              value: _deptLabel.isEmpty ? null : _deptLabel,
              onTap: () => _openPicker(
                title: 'Chagua Idara',
                items: _departments.map((d) => (
                    label: (d as Map)['name'] as String? ?? d['code'] as String,
                    value: d['code'] as String,
                )).toList(),
                onPick: (v) => setState(() => _category = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _TogglePill(label: 'Bila kiwango',
                  selected: _level != 'Primary' && _level != 'Secondary',
                  color: _kGrey500, onTap: () => setState(() { _level = ''; })),
              const SizedBox(width: 8),
              _TogglePill(label: 'Primary',   selected: _level == 'Primary',
                  color: _kBlue,  onTap: () => setState(() { _level = 'Primary'; })),
              const SizedBox(width: 8),
              _TogglePill(label: 'Secondary', selected: _level == 'Secondary',
                  color: _kAmber, onTap: () => setState(() { _level = 'Secondary'; })),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Checkbox(
                value: _requiresSubjects,
                activeColor: _kBlue,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => setState(() { _requiresSubjects = v ?? false; }),
              ),
              const SizedBox(width: 4),
              const Text('Inahitaji masomo', style: TextStyle(fontSize: 13, color: _kGrey700)),
            ]),
          ],
          if (widget.type == 'subjects') ...[
            const SizedBox(height: 12),
            Row(children: [
              _TogglePill(label: 'Primary',   selected: _level == 'Primary',
                  color: _kBlue,  onTap: () => setState(() { _level = 'Primary'; })),
              const SizedBox(width: 8),
              _TogglePill(label: 'Secondary', selected: _level == 'Secondary',
                  color: _kAmber, onTap: () => setState(() { _level = 'Secondary'; })),
            ]),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Hifadhi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toggle pill (used in form sheet) ────────────────────────────────────────

class _TogglePill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TogglePill({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(color: selected ? color : _kGrey200, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? color : _kGrey700,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }
}
