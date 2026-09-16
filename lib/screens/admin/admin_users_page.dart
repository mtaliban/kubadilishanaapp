import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _users = [];
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selected = {};
  bool _selectAll = false;

  String _filterDept = '';
  String _filterRegion = '';
  String _filterDistrict = '';
  String _filterSubject = '';

  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _cadres = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadRegions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      List items = raw is List ? raw : (raw is Map ? (raw['regions'] ?? raw['data'] ?? []) : []);
      setState(() => _regions = items);
    } catch (_) {}
  }

  Future<void> _load({bool useCache = true}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{};
      if (_searchQuery.isNotEmpty) params['q'] = _searchQuery;
      if (_filterDept.isNotEmpty) params['category'] = _filterDept;
      if (_filterRegion.isNotEmpty) params['region'] = _filterRegion;
      if (_filterDistrict.isNotEmpty) params['district'] = _filterDistrict;
      if (_filterSubject.isNotEmpty) params['subject'] = _filterSubject;
      final res = await ApiService().adminUsers(params: params, useCache: useCache);
      if (!mounted) return;
      final raw = res.data;
      List items = raw is List ? raw : (raw is Map ? (raw['users'] ?? raw['data'] ?? raw['results'] ?? []) : []);
      setState(() { _users = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _avatarBg(String name) {
    final list = [_kGreenBg, _kBlueBg, _kAmberBg, _kRedBg, const Color(0xFFF5F3FF)];
    if (name.isEmpty) return _kBlueBg;
    return list[name.codeUnitAt(0) % list.length];
  }

  Color _avatarFg(String name) {
    final list = [_kGreen, _kBlue, _kAmber, _kRed, const Color(0xFF7C3AED)];
    if (name.isEmpty) return _kBlue;
    return list[name.codeUnitAt(0) % list.length];
  }

  Widget _badge(String text, {Color bg = _kGreenBg, Color fg = _kGreen}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _iconBtn({required IconData icon, required Color color, required Color bg, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Future<void> _deleteUser(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Futa Mtumiaji', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Una uhakika wa kufuta "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white),
            child: const Text('Futa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().adminDeleteUser(id);
      if (!mounted) return;
      _snack('Mtumiaji amefutwa', _kGreen);
      _load(useCache: false);
    } catch (e) {
      if (!mounted) return;
      _snack('Hitilafu: $e', _kRed);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showDetail(Map u) {
    final name = u['full_name'] as String? ?? 'Mtumiaji';
    final phone = u['phone_primary'] as String? ?? u['phone'] as String? ?? '';
    final category = u['category'] as String? ?? '';
    final cadre = u['cadre_name'] as String? ?? u['kada_name'] as String? ?? '';
    final isPaid = u['is_paid'] as bool? ?? false;
    final isAdmin = u['is_admin'] as bool? ?? false;
    final station = u['station'] as Map? ?? {};
    final region = station['region_name'] as String? ?? station['region'] as String? ?? '';
    final district = station['district_name'] as String? ?? station['district'] as String? ?? '';
    final facility = station['facility_name'] as String? ?? station['facility'] as String? ?? '';
    final subjects = (u['subjects'] as List?)?.map((s) => (s['code'] ?? s['name'] ?? s.toString()) as String).toList() ?? [];
    final dests = (u['destinations'] as List?)?.map((d) => (d['region_name'] ?? d['region'] ?? d.toString()) as String).toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        maxChildSize: 0.9,
        initialChildSize: 0.7,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            Center(
              child: Column(children: [
                CircleAvatar(radius: 36, backgroundColor: _avatarBg(name), child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _avatarFg(name)))),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                if (cadre.isNotEmpty) Text(cadre, style: const TextStyle(fontSize: 13, color: _kGrey500)),
                const SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _badge(isPaid ? 'Amelipa' : 'Hajalipa', bg: isPaid ? _kGreenBg : _kAmberBg, fg: isPaid ? _kGreen : _kAmber),
                  const SizedBox(width: 6),
                  if (isAdmin) _badge('Admin', bg: _kBlueBg, fg: _kBlue),
                ]),
              ]),
            ),
            const SizedBox(height: 24),
            _infoRow('Idara', category, icon: Icons.grid_view_rounded),
            _infoRow('Simu', phone, icon: Icons.phone_rounded, valueColor: _kBlue),
            if (region.isNotEmpty) _infoRow('Mkoa', region, icon: Icons.map_outlined),
            if (district.isNotEmpty) _infoRow('Wilaya', district, icon: Icons.location_city_rounded),
            if (facility.isNotEmpty) _infoRow('Kituo', facility, icon: Icons.local_hospital_outlined),
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Masomo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: subjects.map((s) => _badge(s, bg: _kBlueBg, fg: _kBlue)).toList()),
            ],
            if (dests.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Anataka:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: dests.map((d) => _badge(d, bg: _kBlueBg, fg: _kBlue)).toList()),
            ],
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(foregroundColor: _kGrey700, side: const BorderSide(color: _kGrey200), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Funga'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { Navigator.pop(context); _showEdit(u); },
                style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Hariri', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {IconData? icon, Color valueColor = _kGrey900}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        if (icon != null) Icon(icon, size: 16, color: _kGrey400),
        if (icon != null) const SizedBox(width: 8),
        Text('$label:', style: const TextStyle(fontSize: 13, color: _kGrey500, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: valueColor, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
      ]),
    );
  }

  void _showEdit(Map u) {
    final id = u['_id'] as String? ?? '';
    final nameCtrl = TextEditingController(text: u['full_name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: u['phone_primary'] as String? ?? u['phone'] as String? ?? '');
    final waCtrl = TextEditingController(text: u['phone_whatsapp'] as String? ?? '');
    String hali = u['status'] as String? ?? 'active';
    bool paid = u['is_paid'] as bool? ?? false;
    bool admin = u['is_admin'] as bool? ?? false;
    bool saving = false;

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
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hariri Mtumiaji', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900)),
                  Text('Badilisha maelezo ya mtumiaji', style: TextStyle(fontSize: 12, color: _kGrey500)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 34, height: 34, decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.close, size: 18, color: _kGrey700)),
                ),
              ]),
              const SizedBox(height: 20),
              _sectionHeader('MAELEZO BINAFSI'),
              _inputField('Jina kamili', nameCtrl, hint: 'Jina la mtumiaji'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _inputField('Simu', phoneCtrl, hint: '07XXXXXXXX', keyboard: TextInputType.phone)),
                const SizedBox(width: 10),
                Expanded(child: _inputField('WhatsApp', waCtrl, hint: '07XXXXXXXX', keyboard: TextInputType.phone)),
              ]),
              const SizedBox(height: 16),
              _sectionHeader('HALI NA HADHI'),
              const SizedBox(height: 8),
              Row(children: [
                _statusPill('Hai', hali == 'active', () => setInner(() => hali = 'active')),
                const SizedBox(width: 8),
                _statusPill('Amefutwa', hali == 'inactive', () => setInner(() => hali = 'inactive')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _checkItem('Amelipa', paid, (v) => setInner(() => paid = v ?? false)),
                const SizedBox(width: 16),
                _checkItem('Admin', admin, (v) => setInner(() => admin = v ?? false)),
              ]),
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
                    setInner(() => saving = true);
                    try {
                      await ApiService().adminUpdateUser(id, {
                        'full_name': nameCtrl.text.trim(),
                        'phone_primary': phoneCtrl.text.trim(),
                        'phone_whatsapp': waCtrl.text.trim(),
                        'status': hali,
                        'is_paid': paid,
                        'is_admin': admin,
                      });
                      if (!mounted) return;
                      if (context.mounted) Navigator.of(context).pop();
                      _snack('Imehifadhiwa', _kGreen);
                      _load(useCache: false);
                    } catch (e) {
                      setInner(() => saving = false);
                      if (!mounted) return;
                      _snack('Hitilafu: $e', _kRed);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Hifadhi', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showAdd() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final waCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool saving = false;

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
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ongeza Mtumiaji', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900)),
                  Text('Jaza maelezo ya mtumiaji mpya', style: TextStyle(fontSize: 12, color: _kGrey500)),
                ])),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 34, height: 34, decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.close, size: 18, color: _kGrey700)),
                ),
              ]),
              const SizedBox(height: 20),
              _sectionHeader('MAELEZO BINAFSI'),
              _inputField('Jina kamili', nameCtrl, hint: 'Jina kamili'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _inputField('Simu', phoneCtrl, hint: '07XXXXXXXX', keyboard: TextInputType.phone)),
                const SizedBox(width: 10),
                Expanded(child: _inputField('WhatsApp', waCtrl, hint: '07XXXXXXXX', keyboard: TextInputType.phone)),
              ]),
              const SizedBox(height: 10),
              _inputField('Nenosiri', passCtrl, hint: '••••••', obscure: true),
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
                    setInner(() => saving = true);
                    try {
                      await ApiService().adminCreateUser({
                        'full_name': nameCtrl.text.trim(),
                        'phone_primary': phoneCtrl.text.trim(),
                        'phone_whatsapp': waCtrl.text.trim(),
                        'password': passCtrl.text,
                      });
                      if (!mounted) return;
                      if (context.mounted) Navigator.of(context).pop();
                      _snack('Mtumiaji ameongezwa', _kGreen);
                      _load(useCache: false);
                    } catch (e) {
                      setInner(() => saving = false);
                      if (!mounted) return;
                      _snack('Hitilafu: $e', _kRed);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Ongeza', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kGrey400, letterSpacing: 1.2)),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, {String hint = '', TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kGrey400, fontSize: 13),
          fillColor: Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _statusPill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kGreenBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kGreen : _kGrey200),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? _kGreen : _kGrey700)),
      ),
    );
  }

  Widget _checkItem(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Transform.scale(scale: 0.9, child: Checkbox(value: value, onChanged: onChanged, activeColor: _kBlue)),
      Text(label, style: const TextStyle(fontSize: 13, color: _kGrey700)),
    ]);
  }

  void _showFilterPicker(String title, String hint, List<dynamic> items, String currentValue, ValueChanged<String> onSelected) {
    final searchCtrl = TextEditingController();
    List filtered = items;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kGrey900))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.close, size: 16, color: _kGrey700)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: _kGrey400, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 18),
                  fillColor: _kGrey100, filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                ),
                onChanged: (v) => setInner(() {
                  filtered = items.where((it) {
                    final n = (it['name'] ?? it.toString()).toString().toLowerCase();
                    return n.contains(v.toLowerCase());
                  }).toList();
                }),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(
              itemCount: filtered.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  final isAll = currentValue.isEmpty;
                  return _filterItem('Zote / Yote', isAll, () { onSelected(''); Navigator.pop(ctx); });
                }
                final it = filtered[i - 1];
                final name = (it['name'] ?? it.toString()).toString();
                final val = (it['_id'] ?? it['id'] ?? name).toString();
                final isActive = currentValue == val;
                return _filterItem(name, isActive, () { onSelected(val); Navigator.pop(ctx); });
              },
            )),
          ]),
        ),
      ),
    );
  }

  Widget _filterItem(String name, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _kBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? _kBlue : _kGrey900))),
          if (active) const Icon(Icons.check_rounded, size: 18, color: _kBlue),
        ]),
      ),
    );
  }

  Widget _filterDropdown(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kGrey200)),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: _kGrey900), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _kGrey500),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _users.length;
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.group_rounded, color: _kBlue, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Watumiaji', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _kRedBg, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 4),
                    const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kRed)),
                  ]),
                ),
              ]),
              Text('$total watumiaji wote', style: const TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
            ElevatedButton.icon(
              onPressed: _showAdd,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Ongeza', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _kRedBg, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.delete_outline_rounded, size: 16, color: _kRed), SizedBox(width: 4), Text('Trash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kRed))]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kGrey200)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.admin_panel_settings_outlined, size: 16, color: _kGrey700), SizedBox(width: 4), Text('Admin', style: TextStyle(fontSize: 12, color: _kGrey700))]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kGrey200)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.upload_rounded, size: 16, color: _kGrey700), SizedBox(width: 4), Text('Import', style: TextStyle(fontSize: 12, color: _kGrey700))]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Transform.scale(scale: 0.85, child: Checkbox(
              value: _selectAll,
              onChanged: (v) {
                setState(() {
                  _selectAll = v ?? false;
                  if (_selectAll) {
                    _selected.addAll(_users.map((u) => (u['_id'] ?? '').toString()));
                  } else {
                    _selected.clear();
                  }
                });
              },
              activeColor: _kBlue,
            )),
            Text('Chagua zote (${_selected.length})', style: const TextStyle(fontSize: 13, color: _kGrey700)),
            const Spacer(),
            Text('Jumla: $total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onSubmitted: (v) { _searchQuery = v; _load(useCache: false); },
            decoration: InputDecoration(
              hintText: 'Tafuta kwa jina, simu au...',
              hintStyle: const TextStyle(color: _kGrey400, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 20),
              fillColor: Colors.white, filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _filterDropdown(
              _filterDept.isEmpty ? 'Idara zote' : _filterDept,
              () => _showFilterPicker('Chagua idara', 'Tafuta idara...', [{'_id': 'Elimu', 'name': 'Elimu'}, {'_id': 'Afya', 'name': 'Afya'}], _filterDept, (v) { setState(() => _filterDept = v); _load(useCache: false); }),
            ),
            const SizedBox(width: 8),
            _filterDropdown(
              _filterRegion.isEmpty ? 'Mkoa: Zote' : 'Mkoa: $_filterRegion',
              () => _showFilterPicker('Chagua mkoa', 'Tafuta mkoa...', _regions, _filterRegion, (v) { setState(() { _filterRegion = v; _filterDistrict = ''; }); _load(useCache: false); }),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _filterDropdown(
              _filterDistrict.isEmpty ? 'Wilaya zote' : _filterDistrict,
              () {},
            ),
            const SizedBox(width: 8),
            _filterDropdown(
              _filterSubject.isEmpty ? 'Masomo yote' : _filterSubject,
              () {},
            ),
          ]),
        ]),
      ),
      Container(height: 1, color: _kGrey200),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kBlue))
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: _kGrey700), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white), child: const Text('Jaribu Tena')),
                  ]))
                : _users.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.group_off_rounded, size: 56, color: _kGrey400),
                        const SizedBox(height: 12),
                        const Text('Hakuna watumiaji', style: TextStyle(fontSize: 16, color: _kGrey500, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextButton.icon(onPressed: () { _searchCtrl.clear(); _searchQuery = ''; _load(useCache: false); }, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Onyesha upya')),
                      ]))
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final u = _users[i] as Map<String, dynamic>;
                          final id = u['_id'] as String? ?? u['user_id'] as String? ?? '';
                          final name = u['full_name'] as String? ?? 'Mtumiaji';
                          final phone = u['phone_primary'] as String? ?? u['phone'] as String? ?? '';
                          final category = u['category'] as String?;
                          final cadre = u['cadre_name'] as String? ?? '';
                          final region = ((u['station'] as Map?)?['region_name'] ?? (u['station'] as Map?)?['region'] ?? u['region_name'] ?? '') as String;
                          final isPaid = u['is_paid'] as bool? ?? false;
                          final isAdmin = u['is_admin'] as bool? ?? false;
                          final isSelected = _selected.contains(id);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? _kBlue : _kGrey200, width: isSelected ? 1.5 : 1),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Transform.scale(scale: 0.85, child: Checkbox(
                                  value: isSelected,
                                  onChanged: (v) => setState(() { if (v == true) _selected.add(id); else _selected.remove(id); }),
                                  activeColor: _kBlue,
                                )),
                                const SizedBox(width: 4),
                                CircleAvatar(radius: 22, backgroundColor: _avatarBg(name), child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _avatarFg(name)))),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${i + 1}. $name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kGrey900)),
                                  Text(phone, style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Wrap(spacing: 4, runSpacing: 4, children: [
                                    if (category != null && category.isNotEmpty) _badge(category, bg: category == 'Elimu' ? _kGreenBg : _kRedBg, fg: category == 'Elimu' ? _kGreen : _kRed),
                                    if (cadre.isNotEmpty) _badge(cadre, bg: _kGreenBg, fg: _kGreen),
                                  ]),
                                  if (region.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(children: [const Icon(Icons.location_on_outlined, size: 12, color: _kGrey400), const SizedBox(width: 2), Text(region, style: const TextStyle(fontSize: 11, color: _kGrey500))]),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    _badge('Hai', bg: _kGreenBg, fg: _kGreen),
                                    const SizedBox(width: 4),
                                    _badge(isPaid ? 'Amelipa' : 'Hajalipa', bg: isPaid ? _kGreenBg : _kRedBg, fg: isPaid ? _kGreen : _kRed),
                                    if (isAdmin) ...[const SizedBox(width: 4), _badge('Admin', bg: _kBlueBg, fg: _kBlue)],
                                  ]),
                                ])),
                              ]),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: _kGrey100),
                              const SizedBox(height: 8),
                              Row(children: [
                                _iconBtn(icon: Icons.open_in_new_rounded, color: _kBlue, bg: _kBlueBg, onTap: () => _showDetail(u)),
                                const SizedBox(width: 6),
                                _iconBtn(icon: Icons.edit_outlined, color: _kGrey700, bg: _kGrey100, onTap: () => _showEdit(u)),
                                const Spacer(),
                                _iconBtn(icon: Icons.block_rounded, color: _kAmber, bg: _kAmberBg, onTap: () {}),
                                const SizedBox(width: 6),
                                _iconBtn(
                                  icon: Icons.phone_rounded,
                                  color: _kGreen,
                                  bg: _kGreenBg,
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: phone));
                                    _snack('Simu imenakiliwa: $phone', _kGreen);
                                  },
                                ),
                                const SizedBox(width: 6),
                                _iconBtn(icon: Icons.delete_outline_rounded, color: _kRed, bg: _kRedBg, onTap: () => _deleteUser(id, name)),
                              ]),
                            ]),
                          );
                        },
                      ),
      ),
    ]);
  }
}
