import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminDataPage extends StatefulWidget {
  const AdminDataPage({super.key});
  @override
  State<AdminDataPage> createState() => _AdminDataPageState();
}

class _AdminDataPageState extends State<AdminDataPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};
  final Map<String, List<dynamic>> _cache = {};
  final Map<String, TextEditingController> _searchCtrls = {};
  final Map<String, String> _levelFilters = {};

  static const _types = ['departments', 'subjects', 'cadres', 'regions', 'facilities'];
  static const _typeLabels = ['Idara', 'Masomo', 'Kada', 'Mikoa', 'Vituo'];
  static const _typeIcons = [
    Icons.business_outlined,
    Icons.menu_book_outlined,
    Icons.work_outline,
    Icons.map_outlined,
    Icons.local_hospital_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _types.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final type = _types[_tabCtrl.index];
        if (!_cache.containsKey(type)) _loadType(type);
      }
    });
    for (final t in _types) {
      _searchCtrls[t] = TextEditingController()..addListener(() => setState(() {}));
    }
    _loadType('departments');
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in _searchCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadType(String type) async {
    setState(() { _loading[type] = true; _errors[type] = null; });
    try {
      final res = await ApiService().adminListData(type);
      if (!mounted) return;
      final data = res.data;
      _cache[type] = data is List ? data : (data['results'] as List? ?? []);
      setState(() { _loading[type] = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading[type] = false; _errors[type] = e.toString(); });
    }
  }

  List<dynamic> _filtered(String type) {
    final all = _cache[type] ?? [];
    final q = _searchCtrls[type]?.text.toLowerCase() ?? '';
    final lf = _levelFilters[type] ?? '';
    return all.where((item) {
      final m = item as Map<String, dynamic>;
      final name = (m['name'] as String? ?? '').toLowerCase();
      final code = (m['code'] as String? ?? '').toLowerCase();
      final level = (m['level'] as String? ?? m['type'] as String? ?? '').toLowerCase();
      final matchQ = q.isEmpty || name.contains(q) || code.contains(q);
      final matchLevel = lf.isEmpty || level.contains(lf.toLowerCase());
      return matchQ && matchLevel;
    }).toList();
  }

  Color _itemColor(String type, Map<String, dynamic> item) {
    final category = (item['category'] as String? ?? '').toLowerCase();
    final level = (item['level'] as String? ?? item['type'] as String? ?? '').toLowerCase();
    switch (type) {
      case 'departments':
        return category.contains('health') || category.contains('afya') ? _kRed : _kGreen;
      case 'subjects':
        if (level.contains('secondary')) return _kAmber;
        if (level.contains('primary')) return _kBlue;
        return _kGrey500;
      case 'cadres':
        return category.contains('health') || category.contains('afya') ? _kRed : _kGreen;
      case 'regions':
        return _kBlue;
      case 'facilities':
        if (level.contains('dispensary') || level.contains('lab')) return _kRed;
        if (level.contains('health center')) return _kGreen;
        return _kBlue;
      default:
        return _kBlue;
    }
  }

  Color _itemBg(String type, Map<String, dynamic> item) {
    final c = _itemColor(type, item);
    if (c == _kRed) return _kRedBg;
    if (c == _kGreen) return _kGreenBg;
    if (c == _kAmber) return _kAmberBg;
    return _kBlueBg;
  }

  IconData _itemIcon(String type, Map<String, dynamic> item) {
    final level = (item['level'] as String? ?? item['type'] as String? ?? '').toLowerCase();
    switch (type) {
      case 'departments':
        final cat = (item['category'] as String? ?? '').toLowerCase();
        return cat.contains('health') || cat.contains('afya')
            ? Icons.medical_services_outlined
            : Icons.menu_book_outlined;
      case 'subjects':
        return Icons.menu_book_outlined;
      case 'cadres':
        return Icons.work_outline;
      case 'regions':
        return Icons.map_outlined;
      case 'facilities':
        return Icons.local_hospital_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  String _badgeLabel(String type, Map<String, dynamic> item) {
    switch (type) {
      case 'departments':
        return item['category'] as String? ?? '';
      case 'subjects':
        return item['level'] as String? ?? '';
      case 'cadres':
        return item['category'] as String? ?? '';
      case 'regions':
        return 'Mkoa';
      case 'facilities':
        return item['level'] as String? ?? item['type'] as String? ?? '';
      default:
        return '';
    }
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
        onSaved: () {
          _cache.remove(type);
          _loadType(type);
        },
      ),
    );
  }

  Future<void> _delete(String type, Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa'),
        content: Text('Futa "${item['name']}"?'),
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

  List<String> _levelOptions(String type) {
    switch (type) {
      case 'subjects': return ['', 'Primary', 'Secondary'];
      case 'facilities': return ['', 'Dispensary', 'Health center', 'Laboratory', 'Hospital', 'Clinic'];
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.bar_chart, color: _kBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                    Text('Simamia data za mfumo', style: TextStyle(fontSize: 12, color: _kGrey500)),
                  ],
                ),
              ],
            ),
          ),
          // Custom tab bar
          Container(
            height: 44,
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _kBlue,
              unselectedLabelColor: _kGrey500,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: _kBlue, width: 2),
              ),
              tabs: List.generate(_types.length, (i) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcons[i], size: 15),
                    const SizedBox(width: 5),
                    Text(_typeLabels[i]),
                  ],
                ),
              )),
            ),
          ),
          const Divider(height: 1, color: _kGrey200),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: _types.map((type) {
                final loading = _loading[type] ?? false;
                final error = _errors[type];
                final filtered = _filtered(type);
                final allItems = _cache[type] ?? [];
                final levelOpts = _levelOptions(type);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${allItems.length} ${_typeLabels[_types.indexOf(type)]} yaliyosajiliwa',
                              style: TextStyle(fontSize: 13, color: _kGrey700),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAddEdit(type),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Ongeza', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchCtrls[type],
                        decoration: InputDecoration(
                          hintText: 'Tafuta...',
                          prefixIcon: const Icon(Icons.search, color: _kGrey500, size: 18),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kGrey200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kGrey200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kBlue),
                          ),
                        ),
                      ),
                    ),
                    if (levelOpts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: levelOpts.map((opt) {
                            final selected = (_levelFilters[type] ?? '') == opt;
                            final label = opt.isEmpty ? 'Zote' : opt;
                            return GestureDetector(
                              onTap: () { setState(() { _levelFilters[type] = opt; }); },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selected ? _kBlueBg : Colors.white,
                                  border: Border.all(color: selected ? _kBlue : _kGrey200),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected ? _kBlue : _kGrey700,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                    )),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (loading)
                      const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
                    else if (error != null)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: _kRed, size: 48),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () { _cache.remove(type); _loadType(type); },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Jaribu tena'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBlue, foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_typeIcons[_types.indexOf(type)], color: _kGrey500, size: 48),
                              const SizedBox(height: 12),
                              Text('Hakuna data', style: TextStyle(color: _kGrey500)),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            _cache.remove(type);
                            await _loadType(type);
                          },
                          color: _kBlue,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final item = filtered[i] as Map<String, dynamic>;
                              final name = item['name'] as String? ?? '';
                              final code = item['code'] as String? ?? '';
                              final badge = _badgeLabel(type, item);
                              final color = _itemColor(type, item);
                              final bg = _itemBg(type, item);
                              final icon = _itemIcon(type, item);
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: _kGrey200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900)),
                                          if (code.isNotEmpty)
                                            Text(code, style: TextStyle(fontSize: 11, color: _kGrey500)),
                                          if (badge.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: bg,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(badge,
                                                  style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    _EditBtn(onTap: () => _showAddEdit(type, item: item)),
                                    const SizedBox(width: 4),
                                    _DeleteBtn(onTap: () => _delete(type, item)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EditBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.edit_outlined, size: 16, color: _kGrey700),
      ),
    );
  }
}

class _DeleteBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          border: Border.all(color: _kRed.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, size: 16, color: _kRed),
      ),
    );
  }
}

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
  String _level = 'primary';
  bool _saving = false;
  List<dynamic> _regions = [];
  String? _selectedRegionId;
  String? _selectedDistrictId;
  List<dynamic> _districts = [];

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!['name'] as String? ?? '';
      _codeCtrl.text = widget.item!['code'] as String? ?? '';
      _category = widget.item!['category'] as String? ?? 'health';
      _level = widget.item!['level'] as String? ?? widget.item!['type'] as String? ?? 'primary';
    }
    if (widget.type == 'facilities') _loadRegions();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() { _saving = true; });
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        if (_codeCtrl.text.trim().isNotEmpty) 'code': _codeCtrl.text.trim(),
      };
      if (widget.type == 'departments' || widget.type == 'cadres') {
        data['category'] = _category;
      }
      if (widget.type == 'subjects') {
        data['level'] = _level;
      }
      if (widget.type == 'facilities') {
        data['type'] = _level;
        if (_selectedRegionId != null) data['region_id'] = _selectedRegionId;
        if (_selectedDistrictId != null) data['district_id'] = _selectedDistrictId;
      }
      final id = widget.item?['id']?.toString();
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

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
  );

  String get _title {
    final action = widget.item != null ? 'Hariri' : 'Ongeza';
    switch (widget.type) {
      case 'departments': return '$action Idara';
      case 'subjects': return '$action Somo';
      case 'cadres': return '$action Kada';
      case 'regions': return '$action Mkoa';
      case 'facilities': return '$action Kituo';
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
          Row(
            children: [
              Text(_title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.type == 'facilities') ...[
            DropdownButtonFormField<String>(
              value: _regions.any((r) => r['id'].toString() == _selectedRegionId) ? _selectedRegionId : null,
              decoration: _inputDec('Chagua mkoa'),
              items: _regions.map((r) => DropdownMenuItem<String>(
                value: r['id'].toString(),
                child: Text(r['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) {
                setState(() { _selectedRegionId = v; _selectedDistrictId = null; _districts = []; });
                if (v != null) _loadDistricts(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _districts.any((d) => d['id'].toString() == _selectedDistrictId) ? _selectedDistrictId : null,
              decoration: _inputDec('Chagua wilaya'),
              items: _districts.map((d) => DropdownMenuItem<String>(
                value: d['id'].toString(),
                child: Text(d['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) => setState(() { _selectedDistrictId = v; }),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameCtrl,
            decoration: _inputDec('Jina *'),
          ),
          const SizedBox(height: 12),
          if (widget.type != 'facilities')
            TextField(
              controller: _codeCtrl,
              decoration: _inputDec('Code'),
            ),
          if (widget.type == 'facilities') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _level,
              decoration: _inputDec('Aina ya kituo'),
              items: ['dispensary', 'health_center', 'laboratory', 'hospital', 'clinic']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() { _level = v ?? 'dispensary'; }),
            ),
          ],
          if (widget.type == 'departments') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _TogglePill(label: 'Afya', selected: _category == 'health',
                    color: _kRed, onTap: () => setState(() { _category = 'health'; })),
                const SizedBox(width: 8),
                _TogglePill(label: 'Elimu', selected: _category == 'education',
                    color: _kGreen, onTap: () => setState(() { _category = 'education'; })),
              ],
            ),
          ],
          if (widget.type == 'cadres') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _TogglePill(label: 'Afya', selected: _category == 'health',
                    color: _kRed, onTap: () => setState(() { _category = 'health'; })),
                const SizedBox(width: 8),
                _TogglePill(label: 'Elimu', selected: _category == 'education',
                    color: _kGreen, onTap: () => setState(() { _category = 'education'; })),
              ],
            ),
          ],
          if (widget.type == 'subjects') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _TogglePill(label: 'Primary', selected: _level == 'primary',
                    color: _kBlue, onTap: () => setState(() { _level = 'primary'; })),
                const SizedBox(width: 8),
                _TogglePill(label: 'Secondary', selected: _level == 'secondary',
                    color: _kAmber, onTap: () => setState(() { _level = 'secondary'; })),
              ],
            ),
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
