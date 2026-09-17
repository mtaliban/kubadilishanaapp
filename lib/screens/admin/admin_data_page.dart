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

  // Facilities-specific filter state
  String        _facCategory  = 'health';
  String        _facRegion    = '';
  String        _facDistrict  = '';
  List<dynamic> _facDistricts = [];

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

  Future<void> _loadFacDistricts(String regionId) async {
    try {
      final res = await ApiService().getDistricts(int.parse(regionId));
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _facDistricts = data is List ? data : (data['results'] as List? ?? []);
      });
    } catch (_) {}
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
        final hasSchool  = m['school_code'] != null;
        final lvl        = (m['level'] as String? ?? '').toLowerCase();
        final isEdu      = hasSchool || lvl == 'primary' || lvl == 'secondary';
        final matchCat   = _facCategory == 'education' ? isEdu : !isEdu;
        final matchReg   = _facRegion.isEmpty   || m['region_id']?.toString()   == _facRegion;
        final matchDist  = _facDistrict.isEmpty || m['district_id']?.toString() == _facDistrict;
        return matchQ && matchCat && matchReg && matchDist;
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

  void _showView(String type, Map<String, dynamic> item) {
    final name = (item['name'] ?? item['display_name'] ?? '') as String? ?? '';
    final code = item['code'] as String? ?? item['school_code'] as String? ?? item['id']?.toString() ?? '';

    List<Map<String, String>> fields;
    switch (type) {
      case 'departments':
        fields = [
          {'label': 'Code',  'value': code},
          {'label': 'Jina',  'value': name},
          {'label': 'Hali',  'value': item['status'] == 'disabled' ? 'Imezimwa' : 'Hai'},
        ];
      case 'subjects':
        fields = [
          {'label': 'Code',     'value': code},
          {'label': 'Jina',     'value': name},
          {'label': 'Kiwango',  'value': item['level'] as String? ?? '—'},
        ];
      case 'cadres':
        fields = [
          {'label': 'Code',   'value': code},
          {'label': 'Jina',   'value': name},
          {'label': 'Idara',  'value': item['category'] as String? ?? '—'},
          {'label': 'Kiwango','value': item['level'] as String? ?? '—'},
        ];
      case 'regions':
        fields = [
          {'label': 'ID',   'value': code},
          {'label': 'Jina', 'value': name},
        ];
      case 'districts':
        fields = [
          {'label': 'ID',    'value': code},
          {'label': 'Jina',  'value': name},
          {'label': 'Mkoa',  'value': _getRegionName(item)},
        ];
      case 'facilities':
        fields = [
          {'label': 'Code',    'value': item['school_code'] as String? ?? code},
          {'label': 'Jina',    'value': name},
          {'label': 'Aina',    'value': item['type'] as String? ?? item['level'] as String? ?? '—'},
          {'label': 'Mkoa',    'value': item['region_name'] as String? ?? item['region']?.toString() ?? '—'},
          {'label': 'Wilaya',  'value': item['district_name'] as String? ?? item['district']?.toString() ?? '—'},
        ];
      default:
        fields = [{'label': 'Jina', 'value': name}];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900, height: 10/7))),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close_rounded, size: 20, color: _kGrey500),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _kGrey100),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: fields.asMap().entries.map((entry) {
                  final last = entry.key == fields.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: last ? null : const Border(bottom: BorderSide(color: _kGrey100)),
                    ),
                    child: Row(children: [
                      Text((entry.value['label'] ?? '').toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: _kGrey500, letterSpacing: 0.5)),
                      const Spacer(),
                      Flexible(child: Text(entry.value['value'] ?? '—',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: _kGrey900))),
                    ]),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGrey700,
                    side: const BorderSide(color: _kGrey200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Funga'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); _showAddEdit(type, item: item); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Hariri'),
                ),
              ),
            ]),
          ],
        ),
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
        final level = item['level'] as String? ?? '';
        if (level.isEmpty) return [];
        return [pill(level, _kAmberBg, _kAmber)];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.storage_rounded, size: 22, color: _kBlue),
                const SizedBox(width: 8),
                const Text('Data',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                        color: _kGrey900, height: 7 / 6)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGrey50,
                    border: Border.all(color: _kGrey200),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: _kGrey500, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      const Text('Moja kwa moja',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: _kGrey500, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kGrey200)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _kBlue,
              unselectedLabelColor: _kGrey500,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, height: 4 / 3),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, height: 4 / 3),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: _kBlue, width: 2),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.zero,
              tabs: _typeLabels.map((l) => Tab(height: 36, child: Text(l))).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _types.map(_buildTabContent).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(String type) {
    final loading  = _loading[type] ?? false;
    final error    = _errors[type];
    final filtered = _filtered(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _buildFilterArea(type, filtered.length),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
        else if (error != null)
          Expanded(
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
        else
          Expanded(child: _buildList(type, filtered)),
      ],
    );
  }

  Widget _buildFilterArea(String type, int count) {
    Widget searchRow = Row(
      children: [
        Expanded(child: _searchField(type)),
        const SizedBox(width: 8),
        _countBadge(count),
        const SizedBox(width: 8),
        _addBtn(type),
      ],
    );

    switch (type) {
      case 'subjects':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dropdownField(
            value: _levelFilters['subjects'] ?? '',
            items: const [
              DropdownMenuItem(value: '', child: Text('Viwango vyote')),
              DropdownMenuItem(value: 'primary',    child: Text('Primary (Msingi)')),
              DropdownMenuItem(value: 'secondary',  child: Text('Secondary (Sekondari)')),
            ],
            onChanged: (v) => setState(() { _levelFilters['subjects'] = v ?? ''; }),
          ),
          const SizedBox(height: 8),
          searchRow,
        ]);
      case 'districts':
        final regions = (_cache['regions'] ?? []).cast<Map<String, dynamic>>();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dropdownField(
            value: _regionFilters['districts'] ?? '',
            items: [
              const DropdownMenuItem(value: '', child: Text('Mikoa yote')),
              ...regions.map((r) => DropdownMenuItem(
                value: r['id'].toString(),
                child: Text(r['name'] as String? ?? ''),
              )),
            ],
            onChanged: (v) => setState(() { _regionFilters['districts'] = v ?? ''; }),
          ),
          const SizedBox(height: 8),
          searchRow,
        ]);
      case 'facilities':
        final regions = (_cache['regions'] ?? []).cast<Map<String, dynamic>>();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dropdownField(
            value: _facCategory,
            items: const [
              DropdownMenuItem(value: 'health',     child: Text('Vituo vya Afya')),
              DropdownMenuItem(value: 'education',  child: Text('Shule')),
            ],
            onChanged: (v) => setState(() { _facCategory = v ?? 'health'; _facDistrict = ''; }),
          ),
          const SizedBox(height: 8),
          _dropdownField(
            value: _facRegion,
            items: [
              const DropdownMenuItem(value: '', child: Text('Mikoa yote')),
              ...regions.map((r) => DropdownMenuItem(
                value: r['id'].toString(),
                child: Text(r['name'] as String? ?? ''),
              )),
            ],
            onChanged: (v) {
              setState(() { _facRegion = v ?? ''; _facDistrict = ''; _facDistricts = []; });
              if (v != null && v.isNotEmpty) _loadFacDistricts(v);
            },
          ),
          const SizedBox(height: 8),
          _dropdownField(
            value: _facDistrict,
            enabled: _facRegion.isNotEmpty,
            items: [
              const DropdownMenuItem(value: '', child: Text('Wilaya zote')),
              ..._facDistricts.cast<Map<String, dynamic>>().map((d) => DropdownMenuItem(
                value: d['id'].toString(),
                child: Text(d['name'] as String? ?? ''),
              )),
            ],
            onChanged: (v) => setState(() { _facDistrict = v ?? ''; }),
          ),
          const SizedBox(height: 8),
          searchRow,
        ]);
      default:
        return searchRow;
    }
  }

  Widget _searchField(String type) => TextField(
    controller: _searchCtrls[type],
    style: const TextStyle(fontSize: 14, color: _kGrey900),
    decoration: InputDecoration(
      hintText: 'Tafuta...',
      hintStyle: const TextStyle(fontSize: 14, color: _kGrey500),
      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kGrey500),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kBlue)),
    ),
  );

  Widget _countBadge(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(999)),
    child: Text('$count',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue, height: 4 / 3)),
  );

  Widget _addBtn(String type) {
    const labels = {
      'departments': 'Idara',  'subjects': 'Somo',
      'cadres': 'Kada',        'regions': 'Mkoa',
      'districts': 'Wilaya',   'facilities': 'Kituo',
    };
    return OutlinedButton(
      onPressed: () => _showAddEdit(type),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kGrey700,
        side: const BorderSide(color: _kGrey200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('+ ${labels[type] ?? 'Ongeza'}'),
    );
  }

  Widget _dropdownField({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool enabled = true,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: enabled ? Colors.white : _kGrey50,
      border:          OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
      enabledBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
      focusedBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kBlue)),
      disabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kGrey200)),
    ),
    style: const TextStyle(fontSize: 14, color: _kGrey900),
    items: items,
    onChanged: enabled ? onChanged : null,
  );

  Widget _buildList(String type, List<dynamic> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_outlined, size: 48, color: _kGrey500),
          const SizedBox(height: 8),
          const Text('Hakuna data',
              style: TextStyle(fontSize: 14, color: _kGrey500)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kGrey100),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: RefreshIndicator(
          onRefresh: () async { _cache.remove(type); await _loadType(type); },
          color: _kBlue,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, idx) => const Divider(height: 1, thickness: 1, color: _kGrey100),
            itemBuilder: (ctx, i) => _buildItem(type, items[i] as Map<String, dynamic>),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(String type, Map<String, dynamic> item) {
    final name    = (item['name'] ?? item['display_name'] ?? '') as String? ?? '';
    final code    = item['code'] as String? ?? item['school_code'] as String? ?? item['id']?.toString() ?? '';
    final badges  = _buildBadges(type, item);
    final dimmed  = type == 'departments' && item['status'] == 'disabled';

    // Facilities subtitle: region · district
    final facSub = type == 'facilities'
        ? [
            _getRegionName(item),
            (item['district_name'] ?? item['district']) as String? ?? '',
          ].where((s) => s.isNotEmpty).join(' · ')
        : '';

    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code + badges row
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (code.isNotEmpty)
                        Text(code,
                            style: const TextStyle(
                                fontSize: 12, height: 4 / 3, color: _kGrey500,
                                fontFamily: 'monospace')),
                      ...badges,
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, height: 10 / 7,
                          fontWeight: FontWeight.w500, color: _kGrey900),
                      overflow: TextOverflow.ellipsis),
                  if (facSub.isNotEmpty)
                    Text(facSub,
                        style: const TextStyle(fontSize: 11, height: 1.5, color: _kGrey500),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _RowAction(
              onView:   () => _showView(type, item),
              onEdit:   () => _showAddEdit(type, item: item),
              onDelete: () => _delete(type, item),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Row action buttons (Eye + Pencil + Trash) ───────────────────────────────

class _RowAction extends StatelessWidget {
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RowAction({required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.visibility_outlined,  _kGrey600, 14, onView),
        _btn(Icons.edit_outlined,        _kBlue,    13, onEdit),
        _btn(Icons.delete_outline,       _kRed,     13, onDelete),
      ],
    );
  }

  Widget _btn(IconData icon, Color color, double size, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(icon, size: size, color: color),
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
  String _category = 'health';
  String _level    = 'Primary';
  String _status   = 'active';
  bool   _saving   = false;
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
      _nameCtrl.text = (it['display_name'] ?? it['name'] ?? '') as String? ?? '';
      _codeCtrl.text = it['code'] as String? ?? '';
      _category      = it['category'] as String? ?? 'health';
      _status        = it['status'] as String? ?? 'active';
      final lvl = (it['level'] ?? it['type'] ?? '') as String? ?? '';
      if (widget.type == 'subjects') {
        _level = lvl.toLowerCase() == 'secondary' ? 'Secondary' : 'Primary';
      } else {
        _level = lvl.isNotEmpty ? lvl : 'dispensary';
      }
    } else {
      _level = widget.type == 'subjects' ? 'Primary' : 'dispensary';
    }
    if (widget.type == 'facilities') _loadRegions();
    if (widget.type == 'cadres')     _loadDepartments();
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
        case 'subjects':
          data['code']  = slug.toUpperCase();
          data['level'] = _level;
        case 'cadres':
          data.remove('name');
          data['code']         = slug.toUpperCase();
          data['display_name'] = name;
          data['category']     = _category;
          if (_level == 'Primary' || _level == 'Secondary') data['level'] = _level;
        case 'regions':
          break;
        case 'districts':
          break;
        case 'facilities':
          data['category'] = 'health';
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
            DropdownButtonFormField<String>(
              initialValue: _regions.any((r) => r['id'].toString() == _selectedRegion) ? _selectedRegion : null,
              decoration: _dec('Chagua mkoa'),
              items: _regions.map((r) => DropdownMenuItem<String>(
                value: r['id'].toString(),
                child: Text(r['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) {
                setState(() { _selectedRegion = v; _selectedDistrict = null; _districts = []; });
                if (v != null) _loadDistricts(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _districts.any((d) => d['id'].toString() == _selectedDistrict) ? _selectedDistrict : null,
              decoration: _dec('Chagua wilaya'),
              items: _districts.map((d) => DropdownMenuItem<String>(
                value: d['id'].toString(),
                child: Text(d['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) => setState(() { _selectedDistrict = v; }),
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
            DropdownButtonFormField<String>(
              initialValue: ['dispensary', 'health_center', 'laboratory', 'hospital', 'clinic']
                      .contains(_level.toLowerCase())
                  ? _level.toLowerCase()
                  : 'dispensary',
              decoration: _dec('Aina ya kituo'),
              items: ['dispensary', 'health_center', 'laboratory', 'hospital', 'clinic']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() { _level = v ?? 'dispensary'; }),
            ),
          ],
          if (widget.type == 'departments') ...[
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
            DropdownButtonFormField<String>(
              initialValue: _departments.any((d) => d['code'] == _category) ? _category : null,
              isExpanded: true,
              decoration: _dec('Chagua idara *'),
              items: _departments.map((d) => DropdownMenuItem<String>(
                value: d['code'] as String,
                child: Text(d['name'] as String? ?? d['code'] as String),
              )).toList(),
              onChanged: (v) => setState(() { _category = v ?? _category; }),
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
