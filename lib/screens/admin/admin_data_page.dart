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
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminDataPage extends StatefulWidget {
  const AdminDataPage({super.key});
  @override
  State<AdminDataPage> createState() => _AdminDataPageState();
}

class _AdminDataPageState extends State<AdminDataPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _types = ['departments', 'subjects', 'cadres', 'regions', 'facilities'];
  static const _labels = ['Idara', 'Masomo', 'Kada', 'Mikoa', 'Vituo'];
  static const _icons = [Icons.grid_view_rounded, Icons.menu_book_rounded, Icons.work_outline_rounded, Icons.map_outlined, Icons.local_hospital_outlined];

  final Map<String, bool> _loading = {};
  final Map<String, String?> _errors = {};
  final Map<String, List> _data = {};
  final Map<String, String> _search = {};
  String _levelFilter = '';
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) _loadIfNeeded(_tab.index); });
    _loadIfNeeded(0);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _loadIfNeeded(int i) {
    final t = _types[i];
    if (_data[t] == null && _loading[t] != true) _loadType(t);
  }

  Future<void> _loadType(String type) async {
    setState(() { _loading[type] = true; _errors[type] = null; });
    try {
      final res = await ApiService().adminListData(type);
      if (!mounted) return;
      final raw = res.data;
      List items = raw is List ? raw : (raw is Map ? (raw[type] ?? raw['data'] ?? raw['results'] ?? []) : []);
      setState(() { _data[type] = items; _loading[type] = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errors[type] = e.toString(); _loading[type] = false; });
    }
  }

  List _filtered(String type) {
    final all = _data[type] ?? [];
    final q = (_search[type] ?? '').toLowerCase();
    var items = q.isEmpty ? all : all.where((it) {
      final n = ((it as Map)['name'] ?? it['display'] ?? '').toString().toLowerCase();
      final c = (it['code'] ?? it['cadre_code'] ?? '').toString().toLowerCase();
      return n.contains(q) || c.contains(q);
    }).toList();

    if (type == 'subjects' && _levelFilter.isNotEmpty) {
      items = items.where((it) => (it as Map)['level']?.toString() == _levelFilter).toList();
    }
    if (type == 'facilities' && _typeFilter.isNotEmpty) {
      items = items.where((it) => (it as Map)['type']?.toString() == _typeFilter || (it as Map)['facility_type']?.toString() == _typeFilter).toList();
    }
    return items;
  }

  Future<void> _delete(String type, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Futa', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Una uhakika wa kufuta "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white), child: const Text('Futa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().adminDeleteData(type, id);
      if (!mounted) return;
      _snack('Imefutwa', _kGreen);
      setState(() { _data[type] = null; });
      _loadType(type);
    } catch (e) {
      if (!mounted) return;
      _snack('Hitilafu: $e', _kRed);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showForm(String type, {Map? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final codeCtrl = TextEditingController(text: existing?['code'] as String? ?? existing?['cadre_code'] as String? ?? '');
    String level = existing?['level'] as String? ?? 'Primary';
    String category = existing?['category'] as String? ?? 'Elimu';
    String facilityType = existing?['type'] as String? ?? existing?['facility_type'] as String? ?? 'Dispensary';
    bool saving = false;
    final isEdit = existing != null;
    final id = existing?['_id'] as String? ?? existing?['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Hariri ${_labels[_types.indexOf(type)]}' : 'Ongeza ${_labels[_types.indexOf(type)]}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900)),
                  const Text('Jaza maelezo hapa chini', style: TextStyle(fontSize: 12, color: _kGrey500)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 34, height: 34, decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.close, size: 18, color: _kGrey700)),
                ),
              ]),
              const SizedBox(height: 20),
              _field('Jina', nameCtrl, 'Weka jina...'),
              const SizedBox(height: 12),
              _field('Msimbo (code)', codeCtrl, 'Mfano: KISW'),
              const SizedBox(height: 12),
              if (type == 'subjects') ...[
                const Text('Kiwango', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
                const SizedBox(height: 8),
                Row(children: [
                  _pill('Primary', level == 'Primary', () => setInner(() => level = 'Primary')),
                  const SizedBox(width: 8),
                  _pill('Secondary', level == 'Secondary', () => setInner(() => level = 'Secondary')),
                ]),
              ],
              if (type == 'departments' || type == 'cadres') ...[
                const Text('Kategoria', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
                const SizedBox(height: 8),
                Row(children: [
                  _pill('Elimu', category == 'Elimu', () => setInner(() => category = 'Elimu')),
                  const SizedBox(width: 8),
                  _pill('Afya', category == 'Afya', () => setInner(() => category = 'Afya')),
                ]),
              ],
              if (type == 'facilities') ...[
                const Text('Aina ya kituo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: ['Dispensary', 'Health center', 'Laboratory', 'Hospital'].map((t) =>
                  _pill(t, facilityType == t, () => setInner(() => facilityType = t))
                ).toList()),
              ],
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: const BorderSide(color: _kGrey200), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Ghairi'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (nameCtrl.text.trim().isEmpty) { _snack('Weka jina', _kAmber); return; }
                    setInner(() => saving = true);
                    try {
                      final payload = <String, dynamic>{
                        'name': nameCtrl.text.trim(),
                        'code': codeCtrl.text.trim(),
                        if (type == 'subjects') 'level': level,
                        if (type == 'departments' || type == 'cadres') 'category': category,
                        if (type == 'facilities') 'type': facilityType,
                      };
                      if (isEdit) {
                        await ApiService().adminUpdateData(type, id, payload);
                      } else {
                        await ApiService().adminCreateData(type, payload);
                      }
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _snack(isEdit ? 'Imehifadhiwa' : 'Imeongezwa', _kGreen);
                      setState(() => _data[type] = null);
                      _loadType(type);
                    } catch (e) {
                      setInner(() => saving = false);
                      if (!mounted) return;
                      _snack('Hitilafu: $e', _kRed);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Hifadhi' : 'Ongeza', style: const TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: _kGrey400, fontSize: 13),
          fillColor: Colors.white, filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kBlue : _kGrey200),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? _kBlue : _kGrey700)),
      ),
    );
  }

  Widget _badge(String text, {Color bg = _kBlueBg, Color fg = _kBlue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Color _iconBoxColor(String type, Map item) {
    if (type == 'departments' || type == 'cadres') {
      final cat = item['category'] as String? ?? '';
      return cat == 'Afya' ? _kRedBg : _kGreenBg;
    }
    if (type == 'subjects') {
      final lv = item['level'] as String? ?? '';
      return lv == 'Secondary' ? _kAmberBg : _kBlueBg;
    }
    if (type == 'facilities') {
      final ft = item['type'] as String? ?? item['facility_type'] as String? ?? '';
      if (ft == 'Health center') return _kGreenBg;
      if (ft == 'Laboratory') return _kRedBg;
      return _kAmberBg;
    }
    return _kBlueBg;
  }

  Color _iconColor(String type, Map item) {
    if (type == 'departments' || type == 'cadres') {
      final cat = item['category'] as String? ?? '';
      return cat == 'Afya' ? _kRed : _kGreen;
    }
    if (type == 'subjects') {
      final lv = item['level'] as String? ?? '';
      return lv == 'Secondary' ? _kAmber : _kBlue;
    }
    if (type == 'facilities') {
      final ft = item['type'] as String? ?? item['facility_type'] as String? ?? '';
      if (ft == 'Health center') return _kGreen;
      if (ft == 'Laboratory') return _kRed;
      return _kAmber;
    }
    return _kBlue;
  }

  Widget? _typeBadge(String type, Map item) {
    if (type == 'subjects') {
      final lv = item['level'] as String? ?? '';
      if (lv.isEmpty) return null;
      return _badge(lv, bg: lv == 'Secondary' ? _kAmberBg : _kBlueBg, fg: lv == 'Secondary' ? _kAmber : _kBlue);
    }
    if (type == 'facilities') {
      final ft = item['type'] as String? ?? item['facility_type'] as String? ?? '';
      if (ft.isEmpty) return null;
      Color bg, fg;
      if (ft == 'Health center') { bg = _kGreenBg; fg = _kGreen; }
      else if (ft == 'Laboratory') { bg = _kRedBg; fg = _kRed; }
      else { bg = _kAmberBg; fg = _kAmber; }
      return _badge(ft, bg: bg, fg: fg);
    }
    if (type == 'departments' || type == 'cadres') {
      final cat = item['category'] as String? ?? '';
      if (cat.isEmpty) return null;
      return _badge(cat, bg: cat == 'Afya' ? _kRedBg : _kGreenBg, fg: cat == 'Afya' ? _kRed : _kGreen);
    }
    return null;
  }

  Widget _buildTab(String type, int tabIdx) {
    final isLoading = _loading[type] ?? false;
    final error = _errors[type];
    final items = _filtered(type);
    final total = (_data[type] ?? []).length;
    final icon = _icons[tabIdx];

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$total vilivyosajiliwa', style: const TextStyle(fontSize: 13, color: _kGrey500)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showForm(type),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ongeza', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _search[type] = v),
            decoration: InputDecoration(
              hintText: 'Tafuta ${_labels[tabIdx].toLowerCase()}...',
              hintStyle: const TextStyle(color: _kGrey400, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 18),
              fillColor: Colors.white, filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
            ),
          ),
          if (type == 'subjects') ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _pill('Viwango vyote', _levelFilter.isEmpty, () => setState(() => _levelFilter = '')),
                const SizedBox(width: 8),
                _pill('Primary', _levelFilter == 'Primary', () => setState(() => _levelFilter = 'Primary')),
                const SizedBox(width: 8),
                _pill('Secondary', _levelFilter == 'Secondary', () => setState(() => _levelFilter = 'Secondary')),
              ]),
            ),
          ],
          if (type == 'facilities') ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _pill('Zote', _typeFilter.isEmpty, () => setState(() => _typeFilter = '')),
                const SizedBox(width: 8),
                _pill('Dispensary', _typeFilter == 'Dispensary', () => setState(() => _typeFilter = 'Dispensary')),
                const SizedBox(width: 8),
                _pill('Health center', _typeFilter == 'Health center', () => setState(() => _typeFilter = 'Health center')),
                const SizedBox(width: 8),
                _pill('Laboratory', _typeFilter == 'Laboratory', () => setState(() => _typeFilter = 'Laboratory')),
              ]),
            ),
          ],
        ]),
      ),
      Container(height: 1, color: _kGrey200),
      Expanded(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: _kBlue))
            : error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
                    const SizedBox(height: 12),
                    Text(error, style: const TextStyle(color: _kGrey700), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => _loadType(type), style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white), child: const Text('Jaribu Tena')),
                  ]))
                : items.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 56, color: _kGrey400),
                        const SizedBox(height: 12),
                        const Text('Hakuna data', style: TextStyle(fontSize: 16, color: _kGrey500, fontWeight: FontWeight.w500)),
                      ]))
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final item = items[i] as Map;
                          final name = (item['name'] ?? item['display'] ?? item['title'] ?? 'Item').toString();
                          final code = (item['code'] ?? item['cadre_code'] ?? '').toString();
                          final id = (item['_id'] ?? item['id'] ?? '').toString();
                          final boxBg = _iconBoxColor(type, item);
                          final boxFg = _iconColor(type, item);
                          final badge = _typeBadge(type, item);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kGrey200)),
                            child: Row(children: [
                              Container(width: 44, height: 44, decoration: BoxDecoration(color: boxBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 22, color: boxFg)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kGrey900)),
                                if (code.isNotEmpty) Text(code, style: const TextStyle(fontSize: 11, color: _kGrey500)),
                              ])),
                              if (badge != null) ...[badge, const SizedBox(width: 8)],
                              GestureDetector(
                                onTap: () => _showForm(type, existing: item as Map<String, dynamic>),
                                child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kGrey200)), child: const Icon(Icons.edit_outlined, size: 16, color: _kGrey700)),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: id.isNotEmpty ? () => _delete(type, id, name) : null,
                                child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _kRedBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kRed.withValues(alpha: 0.3))), child: const Icon(Icons.delete_outline_rounded, size: 16, color: _kRed)),
                              ),
                            ]),
                          );
                        },
                      ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.bar_chart_rounded, color: _kBlue, size: 24)),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
              Text('Simamia data za mfumo', style: TextStyle(fontSize: 13, color: _kGrey500)),
            ]),
          ]),
          const SizedBox(height: 16),
          TabBar(
            controller: _tab,
            labelColor: _kBlue,
            unselectedLabelColor: _kGrey500,
            indicatorColor: _kBlue,
            indicatorWeight: 2.5,
            isScrollable: true,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: List.generate(5, (i) => Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_icons[i], size: 16),
                const SizedBox(width: 6),
                Text(_labels[i]),
              ]),
            )),
          ),
        ]),
      ),
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: List.generate(5, (i) => _buildTab(_types[i], i)),
        ),
      ),
    ]);
  }
}
