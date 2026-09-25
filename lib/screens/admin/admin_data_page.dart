import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import 'admin_idara_dialogs.dart';
import 'admin_masomo_dialogs.dart';
import 'admin_kada_dialogs.dart';
import 'admin_mikoa_dialogs.dart';
import 'admin_wilaya_dialogs.dart';
import 'admin_vituo_dialogs.dart';

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

  // ─── Mappers ────────────────────────────────────────────────────────────────

  Idara _toIdara(Map<String, dynamic> m) => Idara(
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    iconKey: m['icon'] as String? ?? 'briefcase',
    active: m['status'] != 'disabled',
    kadaCount: m['kada_count'] as int?,
    usersCount: m['users_count'] as int?,
  );

  Somo _toSomo(Map<String, dynamic> m) => Somo(
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    level: m['level'] as String? ?? 'Primary',
    active: m['is_active'] as bool? ?? m['status'] != 'disabled',
    kadaCount: m['kada_count'] as int?,
  );

  Kada _toKada(Map<String, dynamic> m) => Kada(
    code: m['code'] as String? ?? '',
    displayName: m['display_name'] as String? ?? m['name'] as String? ?? '',
    category: m['category'] as String? ?? '',
    categoryName: m['category_name'] as String? ?? '',
    level: m['level'] as String? ?? '',
    requiresSubjects: m['requires_subjects'] as bool? ?? false,
    active: m['is_active'] as bool? ?? true,
    usersCount: m['users_count'] as int?,
  );

  Mkoa _toMkoa(Map<String, dynamic> m) => Mkoa(
    id: m['id']?.toString() ?? '',
    name: m['name'] as String? ?? '',
    active: m['is_active'] as bool? ?? true,
    wilayaCount: m['districts_count'] as int?,
  );

  Wilaya _toWilaya(Map<String, dynamic> m) => Wilaya(
    id: m['id']?.toString() ?? '',
    name: m['name'] as String? ?? '',
    regionId: m['region_id']?.toString() ?? '',
    regionName: m['region_name'] as String? ?? _getRegionName(m),
    active: m['is_active'] as bool? ?? true,
    vituoCount: m['facilities_count'] as int?,
  );

  Kituo _toKituo(Map<String, dynamic> m) => Kituo(
    id: m['id']?.toString() ?? m['school_code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    type: m['type'] as String? ?? m['level'] as String? ?? 'dispensary',
    category: m['category'] as String? ?? 'health',
    regionId: m['region_id']?.toString() ?? '',
    regionName: _getRegionName(m),
    districtId: m['district_id']?.toString() ?? '',
    districtName: m['district_name'] as String? ?? m['district'] as String? ?? '',
    active: m['is_active'] as bool? ?? true,
    staffCount: m['staff_count'] as int?,
  );

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _showView(String type, Map<String, dynamic> item) async {
    switch (type) {
      case 'departments':
        await showIdaraViewDialog(context, _toIdara(item),
            onEdit: () => _showEdit(type, item: item));
      case 'subjects':
        await showSomoViewDialog(context, _toSomo(item),
            onEdit: () => _showEdit(type, item: item));
      case 'cadres':
        await showKadaViewDialog(context, _toKada(item),
            onEdit: () => _showEdit(type, item: item));
      case 'regions':
        await showMkoaViewDialog(context, _toMkoa(item),
            onEdit: () => _showEdit(type, item: item));
      case 'districts':
        await showWilayaViewDialog(context, _toWilaya(item),
            onEdit: () => _showEdit(type, item: item));
      case 'facilities':
        await showKituoViewDialog(context, _toKituo(item),
            onEdit: () => _showEdit(type, item: item));
    }
  }

  Future<void> _showEdit(String type, {Map<String, dynamic>? item}) async {
    Map<String, dynamic>? payload;

    switch (type) {
      case 'departments':
        final result = await showIdaraEditDialog(context,
            idara: item != null ? _toIdara(item) : null);
        if (result == null) return;
        payload = {
          'name': result.name,
          'code': result.code,
          'status': result.active ? 'active' : 'disabled',
          'icon': result.iconKey,
        };

      case 'subjects':
        final result = await showSomoEditDialog(context,
            somo: item != null ? _toSomo(item) : null);
        if (result == null) return;
        final code = result.code.isNotEmpty
            ? result.code.toUpperCase()
            : _slugify(result.name).toUpperCase();
        payload = {
          'name': result.name,
          'code': code,
          'level': result.level,
          'is_active': result.active,
        };

      case 'cadres':
        if (!_cache.containsKey('departments')) await _loadType('departments');
        final depts = (_cache['departments'] ?? []).cast<Map<String, dynamic>>();
        final idaraList = depts
            .map((d) => (code: d['code'] as String? ?? '', name: d['name'] as String? ?? ''))
            .where((e) => e.code.isNotEmpty)
            .toList();
        final result = await showKadaEditDialog(context,
            kada: item != null ? _toKada(item) : null, idara: idaraList);
        if (result == null) return;
        payload = {
          'display_name': result.displayName,
          'code': result.code,
          'category': result.category,
          'level': result.level,
          'requires_subjects': result.requiresSubjects,
          'is_active': result.active,
        };

      case 'regions':
        final result = await showMkoaEditDialog(context,
            mkoa: item != null ? _toMkoa(item) : null);
        if (result == null) return;
        payload = {
          'name': result.name,
          'is_active': result.active,
        };

      case 'districts':
        if (!_cache.containsKey('regions')) await _loadType('regions');
        final regionsList = (_cache['regions'] ?? []).cast<Map<String, dynamic>>();
        final mikoa = regionsList
            .map((r) => (id: r['id']?.toString() ?? '', name: r['name'] as String? ?? ''))
            .where((e) => e.id.isNotEmpty)
            .toList();
        final result = await showWilayaEditDialog(context,
            wilaya: item != null ? _toWilaya(item) : null, mikoa: mikoa);
        if (result == null) return;
        payload = {
          'name': result.name,
          'region_id': int.tryParse(result.regionId) ?? result.regionId,
          'is_active': result.active,
        };

      case 'facilities':
        if (!_cache.containsKey('regions')) await _loadType('regions');
        final regionsList = (_cache['regions'] ?? []).cast<Map<String, dynamic>>();
        final mikoa = regionsList
            .map((r) => (id: r['id']?.toString() ?? '', name: r['name'] as String? ?? ''))
            .where((e) => e.id.isNotEmpty)
            .toList();
        final result = await showKituoEditDialog(
          context,
          kituo: item != null ? _toKituo(item) : null,
          mikoa: mikoa,
          loadWilaya: (regionId) async {
            try {
              final res = await ApiService().getDistricts(int.parse(regionId));
              final data = res.data;
              final list = data is List ? data : (data['results'] as List? ?? []);
              return list.cast<Map<String, dynamic>>().map((d) => (
                    id: d['id']?.toString() ?? '',
                    name: d['name'] as String? ?? '',
                  )).toList();
            } catch (_) {
              return [];
            }
          },
        );
        if (result == null) return;
        payload = {
          'name': result.name,
          'category': result.category,
          'type': result.type,
          'region_id': int.tryParse(result.regionId) ?? result.regionId,
          'district_id': int.tryParse(result.districtId) ?? result.districtId,
          'is_active': result.active,
        };

      default:
        return;
    }

    try {
      final id = item?['id']?.toString() ?? item?['code']?.toString();
      if (id != null && id.isNotEmpty) {
        await ApiService().adminUpdateData(type, id, payload);
      } else {
        await ApiService().adminCreateData(type, payload);
      }
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

  Future<void> _openDelete(String type, Map<String, dynamic> item) async {
    bool ok = false;
    switch (type) {
      case 'departments':
        ok = await showIdaraDeleteDialog(context, _toIdara(item));
      case 'subjects':
        ok = await showSomoDeleteDialog(context, _toSomo(item));
      case 'cadres':
        ok = await showKadaDeleteDialog(context, _toKada(item));
      case 'regions':
        ok = await showMkoaDeleteDialog(context, _toMkoa(item));
      case 'districts':
        ok = await showWilayaDeleteDialog(context, _toWilaya(item));
      case 'facilities':
        ok = await showKituoDeleteDialog(context, _toKituo(item));
    }
    if (!ok) return;
    final id = item['id']?.toString() ?? item['code']?.toString() ?? '';
    if (id.isEmpty) return;
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

  static String _slugify(String name) {
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

  // ─── Helpers ────────────────────────────────────────────────────────────────

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
    // Rangi iko ndani ya decoration (Container hairuhusu color + decoration).
    decoration: const BoxDecoration(
      color: Colors.white,
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
      onPressed: () => _showEdit(type),
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
            onView:   () => _showView(type, item),
            onEdit:   () => _showEdit(type, item: item),
            onDelete: () => _openDelete(type, item),
          ),
        ]),
      ),
    );
  }
}

// ─── Row action buttons ───────────────────────────────────────────────────────

class _RowAction extends StatelessWidget {
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RowAction({required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _sq(PhosphorIcons.eye(), _kBlue, _kBlueBg, onView),
      const SizedBox(width: 6),
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
