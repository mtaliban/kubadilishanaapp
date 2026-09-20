import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
const _kGrey300  = Color(0xFFD1D5DB);
const _kGrey200  = Color(0xFFE5E7EB);
const _kGrey100  = Color(0xFFF3F4F6);
const _kGrey50   = Color(0xFFF9FAFB);
const _kBgSoft   = Color(0xFFF8FAFC);

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

  String _facLevelFilter = '';

  static const _types      = ['departments', 'subjects', 'cadres', 'regions', 'districts', 'facilities'];
  static const _typeLabels = ['Idara', 'Masomo', 'Kada', 'Mikoa', 'Wilaya', 'Vituo'];

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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, height: 1.5, color: fg)),
    );

    switch (type) {
      case 'departments':
        final disabled = item['status'] == 'disabled';
        return [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: disabled ? _kRedBg : _kGreenBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: disabled ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!disabled) Container(
                width: 5, height: 5,
                decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
              ),
              if (!disabled) const SizedBox(width: 4),
              Text(
                disabled ? 'Imezimwa' : 'Hai',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, height: 1.5,
                  color: disabled ? _kRed : _kGreen,
                ),
              ),
            ]),
          ),
        ];
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
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      indicator: BoxDecoration(
        color: _kBlueBg,
        borderRadius: BorderRadius.circular(20),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      dividerColor: Colors.transparent,
      labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      padding: EdgeInsets.zero,
      tabs: List.generate(_typeLabels.length, (i) {
        final isActive = _tabCtrl.index == i;
        final icons = [
          PhosphorIcons.buildings(isActive ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
          PhosphorIcons.bookOpen(isActive ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
          PhosphorIcons.briefcase(isActive ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
          PhosphorIcons.mountains(isActive ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
          PhosphorIcons.mapTrifold(isActive ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
          PhosphorIcons.hospital(isActive ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular),
        ];
        return Tab(
          height: 40,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icons[i], size: 14),
            const SizedBox(width: 5),
            Text(_typeLabels[i]),
          ]),
        );
      }),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgSoft,
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
                  child: Icon(PhosphorIcons.database(PhosphorIconsStyle.fill), color: _kBlue, size: 26),
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
                        decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A), shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('Live', style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: Color(0xFF15803D), letterSpacing: 0.5)),
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
                  Icon(PhosphorIcons.warningCircle(), color: _kRed, size: 48),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () { _cache.remove(type); _loadType(type); },
                    icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
                    label: const Text('Jaribu tena'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Colors.white),
                  ),
                ]),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(PhosphorIcons.tray(), size: 48, color: _kGrey400),
                  const SizedBox(height: 8),
                  const Text('Hakuna data', style: TextStyle(fontSize: 14, color: _kGrey500)),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _kGrey200),
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
                      ],
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
      Row(children: [
        Expanded(
          child: Text('$count $label zilizosajiliwa',
              style: const TextStyle(fontSize: 13, color: _kGrey500)),
        ),
        _addBtn(type),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: _searchCtrls[type],
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
          prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 16, color: _kGrey400),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        ),
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
    return ElevatedButton.icon(
      onPressed: () => _showAddEdit(type),
      icon: Icon(PhosphorIcons.plus(), size: 15, color: Colors.white),
      label: const Text('Ongeza',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          Icon(PhosphorIcons.caretDown(), size: 12,
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
                    child: Icon(PhosphorIcons.x(), size: 14, color: _kGrey700),
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
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), color: _kGrey400, size: 16),
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

  (IconData, Color, Color) _itemIcon(String type, Map<String, dynamic> item) {
    if (type == 'departments') {
      final code = (item['code'] as String? ?? '').toLowerCase();
      switch (code) {
        case 'health':
          return (PhosphorIcons.heartbeat(PhosphorIconsStyle.fill),
              const Color(0xFFDC2626), const Color(0xFFFEE2E2));
        case 'education':
          return (PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
              const Color(0xFF2563EB), const Color(0xFFEFF6FF));
        case 'kilimo':
          return (PhosphorIcons.plant(PhosphorIconsStyle.fill),
              const Color(0xFF16A34A), const Color(0xFFF0FDF4));
        case 'watumishi_wa_umma':
          return (PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
              const Color(0xFF9333EA), const Color(0xFFF5F3FF));
        default:
          return (PhosphorIcons.buildings(PhosphorIconsStyle.fill),
              _kBlue, _kBlueBg);
      }
    }
    if (type == 'facilities') {
      final hasSchool = item['school_code'] != null;
      final lvl = (item['level'] as String? ?? '').toLowerCase();
      final isEdu = hasSchool || lvl == 'primary' || lvl == 'secondary';
      if (isEdu) {
        return (PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
            const Color(0xFF15803D), const Color(0xFFF0FDF4));
      }
      switch (lvl) {
        case 'hospital':
          return (PhosphorIcons.hospital(PhosphorIconsStyle.fill), _kRed, _kRedBg);
        case 'health_center':
          return (PhosphorIcons.firstAidKit(PhosphorIconsStyle.fill), _kRed, _kRedBg);
        default:
          return (PhosphorIcons.firstAid(PhosphorIconsStyle.fill), _kRed, _kRedBg);
      }
    }
    if (type == 'cadres') {
      final cat = (item['category'] as String? ?? '').toLowerCase();
      return cat == 'education'
          ? (PhosphorIcons.graduationCap(PhosphorIconsStyle.fill),
              const Color(0xFF15803D), const Color(0xFFF0FDF4))
          : (PhosphorIcons.stethoscope(PhosphorIconsStyle.fill), _kRed, _kRedBg);
    }
    if (type == 'subjects') return (PhosphorIcons.bookOpen(PhosphorIconsStyle.fill), _kAmber, _kAmberBg);
    if (type == 'regions') return (PhosphorIcons.mountains(PhosphorIconsStyle.fill), _kBlue, _kBlueBg);
    if (type == 'districts') return (PhosphorIcons.mapTrifold(PhosphorIconsStyle.fill), _kBlue, _kBlueBg);
    return (PhosphorIcons.circle(), _kGrey600, _kGrey100);
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

// ─── Row action buttons ───────────────────────────────────────────────────────

class _RowAction extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RowAction({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _sq(PhosphorIcons.pencilSimple(), _kBlue, _kBlueBg, onEdit),
      const SizedBox(width: 6),
      _sq(PhosphorIcons.trash(), _kRed, _kRedBg, onDelete),
    ]);
  }

  Widget _sq(IconData icon, Color iconColor, Color bgColor, VoidCallback onTap) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: iconColor),
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
      }    } else {
      _level = widget.type == 'subjects' ? 'Primary' : 'dispensary';
    }
    // Kada mpya: HAKUNA idara ya default — mtumiaji lazima achague (kama web fix)
    if (widget.type == 'cadres' && widget.item == null) _category = '';

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
          if (_category.isEmpty) {
            if (!mounted) return;
            setState(() { _saving = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chagua idara ya kada'), backgroundColor: _kAmber),
            );
            return;
          }
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

  Widget _pickerBtn({required String hint, String? value, required VoidCallback onTap, bool disabled = false}) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _kGrey50,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(PhosphorIcons.mapPin(), size: 16,
              color: disabled ? _kGrey300 : (value != null ? _kGrey500 : _kGrey400)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? hint,
              style: TextStyle(fontSize: 14, color: value != null ? _kGrey900 : _kGrey400),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(PhosphorIcons.caretDown(), size: 14,
              color: value != null ? _kGrey500 : _kGrey400),
        ]),
      ),
    );
  }

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
                    child: Icon(PhosphorIcons.x(), size: 14, color: _kGrey700),
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
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), color: _kGrey400, size: 16),
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

  InputDecoration _dec(String hint, {IconData? prefixIcon}) => InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon != null
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(prefixIcon, size: 16, color: _kGrey400),
          )
        : null,
    prefixIconConstraints: prefixIcon != null
        ? const BoxConstraints(minWidth: 44, minHeight: 0)
        : null,
    filled: true,
    fillColor: _kGrey50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
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
          // Modal header with grey circle close button
          Row(children: [
            Text(_title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                child: Icon(PhosphorIcons.x(), size: 14, color: _kGrey700),
              ),
            ),
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
            decoration: _dec(
              widget.type == 'cadres' ? 'Jina la kada *' : 'Jina *',
              prefixIcon: PhosphorIcons.tag(),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.type != 'facilities' && widget.type != 'regions' &&
              widget.type != 'districts')
            TextField(
              controller: _codeCtrl,
              decoration: _dec(
                'Code (ikiachiwa wazi tunautengeneza wenyewe)',
                prefixIcon: PhosphorIcons.hash(),
              ),
            ),
          if (widget.type == 'facilities') ...[
            const SizedBox(height: 12),
            Row(children: [
              _SelectableChip(label: 'Afya',  selected: _category == 'health',
                  onTap: () => setState(() => _category = 'health')),
              const SizedBox(width: 8),
              _SelectableChip(label: 'Elimu', selected: _category == 'education',
                  onTap: () => setState(() => _category = 'education')),
            ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final t in const ['dispensary', 'health_center', 'hospital', 'laboratory', 'clinic']) ...[
                  _SelectableChip(
                    label: t,
                    selected: _level.toLowerCase() == t,
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
              _SelectableChip(label: 'Hai',      selected: _status == 'active',
                  onTap: () => setState(() { _status = 'active'; })),
              const SizedBox(width: 8),
              _SelectableChip(label: 'Imezimwa', selected: _status == 'disabled',
                  onTap: () => setState(() { _status = 'disabled'; })),
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
              _SelectableChip(label: 'Bila kiwango',
                  selected: _level != 'Primary' && _level != 'Secondary',
                  onTap: () => setState(() { _level = ''; })),
              const SizedBox(width: 8),
              _SelectableChip(label: 'Primary',   selected: _level == 'Primary',
                  onTap: () => setState(() { _level = 'Primary'; })),
              const SizedBox(width: 8),
              _SelectableChip(label: 'Secondary', selected: _level == 'Secondary',
                  onTap: () => setState(() { _level = 'Secondary'; })),
            ]),
            const SizedBox(height: 10),
            // Custom checkbox row
            GestureDetector(
              onTap: () => setState(() => _requiresSubjects = !_requiresSubjects),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _kGrey50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGrey200),
                ),
                child: Row(children: [
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: _requiresSubjects ? _kBlue : Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: _requiresSubjects ? _kBlue : _kGrey300, width: 1.5),
                    ),
                    child: _requiresSubjects
                        ? Icon(PhosphorIcons.check(), size: 11, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Text('Inahitaji masomo',
                      style: TextStyle(fontSize: 13, color: _kGrey700)),
                ]),
              ),
            ),
          ],
          if (widget.type == 'subjects') ...[
            const SizedBox(height: 12),
            Row(children: [
              _SelectableChip(label: 'Primary',   selected: _level == 'Primary',
                  onTap: () => setState(() { _level = 'Primary'; })),
              const SizedBox(width: 8),
              _SelectableChip(label: 'Secondary', selected: _level == 'Secondary',
                  onTap: () => setState(() { _level = 'Secondary'; })),
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
                elevation: 0,
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

// ─── Selectable chip — uniform blue primary selected state ────────────────────

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kBlueBg : Colors.white,
          border: Border.all(color: selected ? _kBlue : _kGrey200, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? _kBlue : _kGrey700,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}
