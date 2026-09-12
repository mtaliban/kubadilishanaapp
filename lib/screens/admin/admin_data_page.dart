// Admin data management page — Idara, Masomo, Kada, Mikoa, Wilaya, Vituo
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Colour palette ─────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey50  = Color(0xFFF9FAFB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey700 = Color(0xFF374151);
const _kGrey900 = Color(0xFF111827);
const _kGreen50  = Color(0xFFF0FDF4);
const _kGreen600 = Color(0xFF16A34A);
const _kRed     = Color(0xFFDC2626);
const _kRed50   = Color(0xFFFEF2F2);
const _kGold50       = Color(0xFFFFFBEB);
const _kGold600      = Color(0xFFD97706);
const _kGoldBorder   = Color(0xFFFBBF24);

// ── Shared helpers ─────────────────────────────────────────────────────────

const _labelStyle = TextStyle(
  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kGrey500,
);

InputDecoration _inp(String hint, {bool enabled = true}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  filled: true,
  fillColor: enabled ? Colors.white : _kGrey50,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
  disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey100)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
);

void _toast(BuildContext context, String msg, {bool ok = true}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
    backgroundColor: ok ? _kGreen600 : _kRed,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    duration: const Duration(seconds: 3),
  ));
}

Future<bool> _confirmDialog(BuildContext context, String name) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 40,
          decoration: const BoxDecoration(color: _kRed50, shape: BoxShape.circle),
          child: const Icon(Icons.delete_outline, color: _kRed, size: 20)),
        const SizedBox(height: 12),
        const Text('Thibitisha Kufuta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kGrey900)),
        const SizedBox(height: 6),
        RichText(textAlign: TextAlign.center, text: TextSpan(
          style: const TextStyle(fontSize: 13, color: _kGrey500),
          children: [
            const TextSpan(text: 'Una uhakika wa kufuta '),
            TextSpan(text: '"$name"', style: const TextStyle(fontWeight: FontWeight.w700, color: _kGrey700)),
            const TextSpan(text: '?'),
          ],
        )),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _kGrey200), foregroundColor: _kGrey700,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Hapana'),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _kRed,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Futa'),
          )),
        ]),
        const SizedBox(height: 4),
      ]),
    ),
  );
  return result == true;
}

String _errMsg(Object e) {
  try {
    final d = (e as dynamic).response?.data?['detail'];
    return d is String ? d : 'Jaribu tena';
  } catch (_) {
    return 'Jaribu tena';
  }
}

List<dynamic> _parseList(dynamic data, List<String> keys) {
  if (data is List) return data;
  if (data is Map) {
    for (final k in keys) {
      if (data[k] is List) return data[k] as List<dynamic>;
    }
    if (data['items'] is List) return data['items'] as List<dynamic>;
    if (data['data']  is List) return data['data']  as List<dynamic>;
  }
  return [];
}

// ── Shared UI helpers ──────────────────────────────────────────────────────

Widget _sectionLabel(String text) => Text(text, style: _labelStyle);

Widget _formField(String hint, {
  TextEditingController? controller,
  bool enabled = true,
  TextCapitalization cap = TextCapitalization.none,
  int maxLines = 1,
}) => TextField(
  controller: controller,
  enabled: enabled,
  maxLines: maxLines,
  textCapitalization: cap,
  style: TextStyle(fontSize: 13, color: enabled ? _kGrey900 : _kGrey400),
  decoration: _inp(hint, enabled: enabled),
);

// ── Bottom-sheet wrapper ───────────────────────────────────────────────────

Widget _sheetWrap({
  required BuildContext context,
  required String title,
  required List<Widget> fields,
  required bool saving,
  required VoidCallback onSave,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)),
        ),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
          child: Row(children: [
            Expanded(child: Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kGrey900))),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(999)),
                child: const Icon(Icons.close, size: 15, color: _kGrey500),
              ),
            ),
          ]),
        ),
        // Fields
        Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: fields),
        )),
        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: SizedBox(
            width: double.infinity, height: 46,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: _kBlue,
                disabledBackgroundColor: _kBlue.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Hifadhi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    ),
  );
}

// ── Item card ──────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? badge;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.title,
    required this.subtitle,
    this.badge,
    this.icon = Icons.label_outline,
    this.iconColor = _kBlue,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = iconColor.withValues(alpha: 0.1);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left:   BorderSide(color: iconColor, width: 4),
          top:    const BorderSide(color: _kGrey100),
          right:  const BorderSide(color: _kGrey100),
          bottom: const BorderSide(color: _kGrey100),
        ),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(children: [
          // Icon avatar
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 10),
          // Text
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _kGrey900)),
              const SizedBox(height: 1),
              Text(subtitle, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: _kGrey400)),
              if (badge != null) ...[const SizedBox(height: 4), badge!],
            ],
          )),
          const SizedBox(width: 6),
          // Edit
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: _kBlue50, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit_outlined, size: 15, color: _kBlue),
            ),
          ),
          const SizedBox(width: 6),
          // Delete
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: _kRed50, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline, size: 15, color: _kRed),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Status / level / category badges ──────────────────────────────────────

Widget _statusBadge(String status) {
  final active = status == 'active';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: active ? _kGreen50 : _kRed50,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: active ? _kGreen600 : _kRed, width: 0.5),
    ),
    child: Text(active ? '● Hai' : '✗ Imezimwa',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? _kGreen600 : _kRed)),
  );
}

Widget _levelBadge(String level) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: _kGold50, borderRadius: BorderRadius.circular(999),
    border: Border.all(color: _kGoldBorder, width: 0.8),
  ),
  child: Text(level, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kGold600)),
);

Widget _categoryBadge(String cat) {
  final isEdu = cat == 'education';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: isEdu ? _kGold50 : _kBlue50,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: isEdu ? _kGoldBorder : _kBlue.withValues(alpha: 0.3), width: 0.8),
    ),
    child: Text(isEdu ? '📚 Elimu' : '🏥 Afya',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isEdu ? _kGold600 : _kBlue)),
  );
}

// ── Toolbar helpers ────────────────────────────────────────────────────────

Widget _countBadge(int n) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  decoration: BoxDecoration(color: _kBlue50, borderRadius: BorderRadius.circular(999)),
  child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kBlue)),
);

Widget _addButton(String label, VoidCallback onPressed) => FilledButton.icon(
  onPressed: onPressed,
  icon: const Icon(Icons.add, size: 16),
  label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  style: FilledButton.styleFrom(
    backgroundColor: _kBlue,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);

Widget _searchField(TextEditingController ctrl, String hint) => TextField(
  controller: ctrl,
  style: const TextStyle(fontSize: 13),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
    prefixIcon: const Icon(Icons.search, size: 18, color: _kGrey400),
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
  ),
);

InputDecoration _dropInp(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  filled: true, fillColor: Colors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
);

// ── Tab button ─────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? _kBlue : Colors.transparent, width: 2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? _kBlue : _kGrey400),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? _kBlue : _kGrey500,
          )),
        ]),
      ),
    );
  }
}

// ── Main page ──────────────────────────────────────────────────────────────

class AdminDataPage extends StatefulWidget {
  const AdminDataPage({super.key});
  @override
  State<AdminDataPage> createState() => _AdminDataPageState();
}

class _AdminDataPageState extends State<AdminDataPage> {
  String _tab = 'departments';

  void _flash(String msg, {bool ok = true}) {
    if (mounted) _toast(context, msg, ok: ok);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kBlue, Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storage_outlined, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kGrey900)),
              Text('Simamia data za mfumo', style: TextStyle(fontSize: 12, color: _kGrey500)),
            ]),
          ]),
        ),

        // Tab bar
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kGrey200))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              _TabBtn(label: 'Idara',  icon: Icons.business_outlined,      active: _tab == 'departments', onTap: () => setState(() => _tab = 'departments')),
              _TabBtn(label: 'Masomo', icon: Icons.menu_book_outlined,     active: _tab == 'subjects',    onTap: () => setState(() => _tab = 'subjects')),
              _TabBtn(label: 'Kada',   icon: Icons.badge_outlined,         active: _tab == 'cadres',      onTap: () => setState(() => _tab = 'cadres')),
              _TabBtn(label: 'Mikoa',  icon: Icons.map_outlined,           active: _tab == 'regions',     onTap: () => setState(() => _tab = 'regions')),
              _TabBtn(label: 'Wilaya', icon: Icons.location_city_outlined,  active: _tab == 'districts',   onTap: () => setState(() => _tab = 'districts')),
              _TabBtn(label: 'Vituo',  icon: Icons.local_hospital_outlined, active: _tab == 'facilities',  onTap: () => setState(() => _tab = 'facilities')),
            ]),
          ),
        ),

        // Content
        Expanded(child: switch (_tab) {
          'departments' => _DepsTab(flash: _flash),
          'subjects'    => _SubjectsTab(flash: _flash),
          'cadres'      => _CadresTab(flash: _flash),
          'regions'     => _RegionsTab(flash: _flash),
          'districts'   => _DistrictsTab(flash: _flash),
          'facilities'  => _FacilitiesTab(flash: _flash),
          _             => _DepsTab(flash: _flash),
        }),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. IDARA (Departments)
// ══════════════════════════════════════════════════════════════════════════════

class _DepsTab extends StatefulWidget {
  final void Function(String, {bool ok}) flash;
  const _DepsTab({required this.flash});
  @override
  State<_DepsTab> createState() => _DepsTabState();
}

class _DepsTabState extends State<_DepsTab> {
  List<dynamic> _items    = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res  = await ApiService().get('/admin/data/departments');
      if (!mounted) return;
      final list = _parseList(res.data, ['departments']);
      setState(() { _items = list; _filter(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.flash(_errMsg(e), ok: false);
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? List.from(_items)
          : _items.where((x) =>
              (x['name'] ?? '').toString().toLowerCase().contains(q) ||
              (x['code'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _showModal({dynamic item}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DeptSheet(item: item),
    );
    if (result == true) {
      await _load();
      widget.flash(item == null ? 'Idara imeongezwa!' : 'Idara imesasishwa!');
    }
  }

  Future<void> _delete(dynamic item) async {
    final ok = await _confirmDialog(context, item['name'] ?? '');
    if (!ok) return;
    try {
      await ApiService().delete('/admin/data/departments/${item['code'] ?? ''}');
      await _load();
      widget.flash('Idara imefutwa!');
    } catch (e) { widget.flash(_errMsg(e), ok: false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          Expanded(child: _searchField(_search, 'Tafuta idara...')),
          const SizedBox(width: 8),
          _countBadge(_filtered.length),
          const SizedBox(width: 8),
          _addButton('Ongeza', () => _showModal()),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : RefreshIndicator(
              onRefresh: _load, color: _kBlue,
              child: _filtered.isEmpty
                  ? const Center(child: Text('Hakuna idara', style: TextStyle(color: _kGrey500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final x = _filtered[i];
                        return _ItemCard(
                          title: x['name'] ?? '',
                          subtitle: x['code'] ?? '',
                          icon: Icons.business_outlined,
                          badge: _statusBadge(x['status'] ?? 'active'),
                          onEdit: () => _showModal(item: x),
                          onDelete: () => _delete(x),
                        );
                      },
                    ),
            )),
    ]);
  }
}

class _DeptSheet extends StatefulWidget {
  final dynamic item;
  const _DeptSheet({this.item});
  @override
  State<_DeptSheet> createState() => _DeptSheetState();
}

class _DeptSheetState extends State<_DeptSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _icon = TextEditingController();
  String _status = 'active';
  bool _saving = false;
  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _code.text   = widget.item['code']   ?? '';
      _name.text   = widget.item['name']   ?? '';
      _icon.text   = widget.item['icon']   ?? '';
      _status      = widget.item['status'] ?? 'active';
    }
  }

  @override
  void dispose() { _code.dispose(); _name.dispose(); _icon.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'icon': _icon.text.trim().isEmpty ? '🏢' : _icon.text.trim(),
        'status': _status,
      };
      if (_isEdit) {
        await ApiService().patch('/admin/data/departments/${widget.item['code'] ?? ''}', data: body);
      } else {
        final codeVal = _code.text.trim().toLowerCase();
        if (codeVal.isEmpty) { setState(() => _saving = false); return; }
        await ApiService().post('/admin/data/departments', data: {...body, 'code': codeVal});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context, _errMsg(e), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) => _sheetWrap(
    context: context,
    title: _isEdit ? 'Hariri Idara' : 'Ongeza Idara',
    saving: _saving,
    onSave: _save,
    fields: [
      _sectionLabel('MSIMBO'),
      const SizedBox(height: 4),
      _formField(_isEdit ? (_code.text.isEmpty ? '—' : _code.text) : 'Mfano: elimu',
          controller: _code, enabled: !_isEdit, cap: TextCapitalization.none),
      const SizedBox(height: 14),
      _sectionLabel('JINA'),
      const SizedBox(height: 4),
      _formField('Jina la idara', controller: _name),
      const SizedBox(height: 14),
      _sectionLabel('AIKONI (Hiari)'),
      const SizedBox(height: 4),
      _formField('🏢', controller: _icon),
      const SizedBox(height: 14),
      _sectionLabel('HALI'),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: _status,
        decoration: _dropInp('Hali'),
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        items: const [
          DropdownMenuItem(value: 'active',   child: Text('Hai (active)')),
          DropdownMenuItem(value: 'disabled', child: Text('Imezimwa (disabled)')),
        ],
        onChanged: (v) => setState(() => _status = v ?? 'active'),
      ),
      const SizedBox(height: 4),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. MASOMO (Subjects)
// ══════════════════════════════════════════════════════════════════════════════

class _SubjectsTab extends StatefulWidget {
  final void Function(String, {bool ok}) flash;
  const _SubjectsTab({required this.flash});
  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  List<dynamic> _items    = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  String _level = '';

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_level.isNotEmpty) params['level'] = _level;
      final res  = await ApiService().get('/admin/data/subjects',
          queryParameters: params.isEmpty ? null : params);
      if (!mounted) return;
      final list = _parseList(res.data, ['subjects']);
      setState(() { _items = list; _filter(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.flash(_errMsg(e), ok: false);
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? List.from(_items)
          : _items.where((x) =>
              (x['name'] ?? '').toString().toLowerCase().contains(q) ||
              (x['code'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _showModal({dynamic item}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SubjectSheet(item: item),
    );
    if (result == true) {
      await _load();
      widget.flash(item == null ? 'Somo limeongezwa!' : 'Somo limesasishwa!');
    }
  }

  Future<void> _delete(dynamic item) async {
    final ok = await _confirmDialog(context, item['name'] ?? '');
    if (!ok) return;
    try {
      await ApiService().delete('/admin/data/subjects/${item['code'] ?? ''}');
      await _load();
      widget.flash('Somo limefutwa!');
    } catch (e) { widget.flash(_errMsg(e), ok: false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Level filter
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: DropdownButtonFormField<String>(
          value: _level,
          decoration: _dropInp('Kichujio: Viwango Vyote'),
          style: const TextStyle(fontSize: 13, color: _kGrey900),
          items: const [
            DropdownMenuItem(value: '',          child: Text('Viwango Vyote')),
            DropdownMenuItem(value: 'Primary',   child: Text('Primary (Msingi)')),
            DropdownMenuItem(value: 'Secondary', child: Text('Secondary (Sekondari)')),
          ],
          onChanged: (v) { setState(() => _level = v ?? ''); _load(); },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(child: _searchField(_search, 'Tafuta masomo...')),
          const SizedBox(width: 8),
          _countBadge(_filtered.length),
          const SizedBox(width: 8),
          _addButton('Ongeza', () => _showModal()),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : RefreshIndicator(
              onRefresh: _load, color: _kBlue,
              child: _filtered.isEmpty
                  ? const Center(child: Text('Hakuna masomo', style: TextStyle(color: _kGrey500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final x   = _filtered[i];
                        final lvl = x['level'] ?? '';
                        return _ItemCard(
                          title: x['name'] ?? '',
                          subtitle: x['code'] ?? '',
                          icon: Icons.menu_book_outlined,
                          iconColor: _kGold600,
                          badge: lvl.isNotEmpty ? _levelBadge(lvl) : null,
                          onEdit: () => _showModal(item: x),
                          onDelete: () => _delete(x),
                        );
                      },
                    ),
            )),
    ]);
  }
}

class _SubjectSheet extends StatefulWidget {
  final dynamic item;
  const _SubjectSheet({this.item});
  @override
  State<_SubjectSheet> createState() => _SubjectSheetState();
}

class _SubjectSheetState extends State<_SubjectSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  String _level = 'Primary';
  bool _saving = false;
  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _code.text = widget.item['code'] ?? '';
      _name.text = widget.item['name'] ?? '';
      _level     = widget.item['level'] ?? 'Primary';
    }
  }

  @override
  void dispose() { _code.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = {'name': _name.text.trim(), 'level': _level};
      if (_isEdit) {
        await ApiService().patch('/admin/data/subjects/${widget.item['code'] ?? ''}', data: body);
      } else {
        final codeVal = _code.text.trim().toUpperCase();
        if (codeVal.isEmpty) { setState(() => _saving = false); return; }
        await ApiService().post('/admin/data/subjects', data: {...body, 'code': codeVal});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context, _errMsg(e), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) => _sheetWrap(
    context: context,
    title: _isEdit ? 'Hariri Somo' : 'Ongeza Somo',
    saving: _saving,
    onSave: _save,
    fields: [
      _sectionLabel('MSIMBO'),
      const SizedBox(height: 4),
      _formField(_isEdit ? _code.text : 'Mfano: MATH',
          controller: _code, enabled: !_isEdit, cap: TextCapitalization.characters),
      const SizedBox(height: 14),
      _sectionLabel('JINA'),
      const SizedBox(height: 4),
      _formField('Jina la somo', controller: _name),
      const SizedBox(height: 14),
      _sectionLabel('KIWANGO'),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: _level,
        decoration: _dropInp('Kiwango'),
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        items: const [
          DropdownMenuItem(value: 'Primary',   child: Text('Primary (Msingi)')),
          DropdownMenuItem(value: 'Secondary', child: Text('Secondary (Sekondari)')),
        ],
        onChanged: (v) => setState(() => _level = v ?? 'Primary'),
      ),
      const SizedBox(height: 4),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. KADA (Cadres)
// ══════════════════════════════════════════════════════════════════════════════

class _CadresTab extends StatefulWidget {
  final void Function(String, {bool ok}) flash;
  const _CadresTab({required this.flash});
  @override
  State<_CadresTab> createState() => _CadresTabState();
}

class _CadresTabState extends State<_CadresTab> {
  List<dynamic> _items    = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res  = await ApiService().get('/admin/data/cadres');
      if (!mounted) return;
      final list = _parseList(res.data, ['cadres']);
      setState(() { _items = list; _filter(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.flash(_errMsg(e), ok: false);
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? List.from(_items)
          : _items.where((x) =>
              (x['display_name'] ?? '').toString().toLowerCase().contains(q) ||
              (x['code'] ?? '').toString().toLowerCase().contains(q) ||
              (x['category'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _showModal({dynamic item}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CadreSheet(item: item),
    );
    if (result == true) {
      await _load();
      widget.flash(item == null ? 'Kada imeongezwa!' : 'Kada imesasishwa!');
    }
  }

  Future<void> _delete(dynamic item) async {
    final name = item['display_name'] ?? item['code'] ?? '';
    final ok   = await _confirmDialog(context, name);
    if (!ok) return;
    try {
      await ApiService().delete('/admin/data/cadres/${item['code'] ?? ''}');
      await _load();
      widget.flash('Kada imefutwa!');
    } catch (e) { widget.flash(_errMsg(e), ok: false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          Expanded(child: _searchField(_search, 'Tafuta kada...')),
          const SizedBox(width: 8),
          _countBadge(_filtered.length),
          const SizedBox(width: 8),
          _addButton('Ongeza', () => _showModal()),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : RefreshIndicator(
              onRefresh: _load, color: _kBlue,
              child: _filtered.isEmpty
                  ? const Center(child: Text('Hakuna kada', style: TextStyle(color: _kGrey500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final x   = _filtered[i];
                        final cat = x['category'] ?? '';
                        return _ItemCard(
                          title: x['display_name'] ?? '',
                          subtitle: x['code'] ?? '',
                          icon: Icons.badge_outlined,
                          iconColor: _kGreen600,
                          badge: cat.isNotEmpty
                              ? Text(cat, style: const TextStyle(fontSize: 11, color: _kGrey500))
                              : null,
                          onEdit: () => _showModal(item: x),
                          onDelete: () => _delete(x),
                        );
                      },
                    ),
            )),
    ]);
  }
}

class _CadreSheet extends StatefulWidget {
  final dynamic item;
  const _CadreSheet({this.item});
  @override
  State<_CadreSheet> createState() => _CadreSheetState();
}

class _CadreSheetState extends State<_CadreSheet> {
  final _code        = TextEditingController();
  final _displayName = TextEditingController();
  String _category   = '';
  String _level      = '';
  bool _requiresSubjects = false;
  bool _saving       = false;
  List<dynamic> _departments = [];
  bool _loadingDeps  = true;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _code.text        = widget.item['code']         ?? '';
      _displayName.text = widget.item['display_name'] ?? '';
      _category         = widget.item['category']     ?? '';
      _level            = widget.item['level']        ?? '';
      _requiresSubjects = widget.item['requires_subjects'] == true;
    }
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final res  = await ApiService().get('/admin/data/departments');
      if (!mounted) return;
      final list = _parseList(res.data, ['departments']);
      setState(() {
        _departments = list;
        _loadingDeps = false;
        if (!_isEdit && list.isNotEmpty && _category.isEmpty) {
          _category = (list.first['code'] ?? '').toString();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDeps = false);
    }
  }

  @override
  void dispose() { _code.dispose(); _displayName.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_displayName.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'display_name': _displayName.text.trim(),
        'category': _category,
        'level': _level,
        'requires_subjects': _requiresSubjects,
      };
      if (_isEdit) {
        await ApiService().patch('/admin/data/cadres/${widget.item['code'] ?? ''}', data: body);
      } else {
        final codeVal = _code.text.trim().toUpperCase();
        if (codeVal.isEmpty) { setState(() => _saving = false); return; }
        await ApiService().post('/admin/data/cadres', data: {...body, 'code': codeVal});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context, _errMsg(e), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDeps) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        height: 160,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }
    return _sheetWrap(
      context: context,
      title: _isEdit ? 'Hariri Kada' : 'Ongeza Kada',
      saving: _saving,
      onSave: _save,
      fields: [
        _sectionLabel('MSIMBO'),
        const SizedBox(height: 4),
        _formField(_isEdit ? _code.text : 'Mfano: TCH_PRI',
            controller: _code, enabled: !_isEdit, cap: TextCapitalization.characters),
        const SizedBox(height: 14),
        _sectionLabel('JINA LA KUONYESHA'),
        const SizedBox(height: 4),
        _formField('Jina kamili la kada', controller: _displayName),
        const SizedBox(height: 14),
        _sectionLabel('IDARA'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _category.isEmpty ? null : _category,
          decoration: _dropInp('Chagua idara'),
          style: const TextStyle(fontSize: 13, color: _kGrey900),
          items: _departments.map((d) => DropdownMenuItem<String>(
            value: (d['code'] ?? '').toString(),
            child: Text(d['name'] ?? d['code'] ?? ''),
          )).toList(),
          onChanged: (v) => setState(() => _category = v ?? ''),
        ),
        const SizedBox(height: 14),
        _sectionLabel('KIWANGO'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _level.isEmpty ? '' : _level,
          decoration: _dropInp('Kiwango (hiari)'),
          style: const TextStyle(fontSize: 13, color: _kGrey900),
          items: const [
            DropdownMenuItem(value: '',          child: Text('—')),
            DropdownMenuItem(value: 'Primary',   child: Text('Primary (Msingi)')),
            DropdownMenuItem(value: 'Secondary', child: Text('Secondary (Sekondari)')),
          ],
          onChanged: (v) => setState(() => _level = v ?? ''),
        ),
        const SizedBox(height: 12),
        // Requires subjects toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _kGrey50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kGrey200),
          ),
          child: Row(children: [
            const Icon(Icons.menu_book_outlined, size: 16, color: _kGrey500),
            const SizedBox(width: 8),
            const Expanded(child: Text('Inahitaji masomo',
                style: TextStyle(fontSize: 13, color: _kGrey700))),
            Switch(
              value: _requiresSubjects,
              activeColor: _kBlue,
              onChanged: (v) => setState(() => _requiresSubjects = v),
            ),
          ]),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. MIKOA (Regions)
// ══════════════════════════════════════════════════════════════════════════════

class _RegionsTab extends StatefulWidget {
  final void Function(String, {bool ok}) flash;
  const _RegionsTab({required this.flash});
  @override
  State<_RegionsTab> createState() => _RegionsTabState();
}

class _RegionsTabState extends State<_RegionsTab> {
  List<dynamic> _items    = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _load(); _search.addListener(_filter); }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res  = await ApiService().get('/admin/data/regions');
      if (!mounted) return;
      final list = _parseList(res.data, ['regions']);
      setState(() { _items = list; _filter(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.flash(_errMsg(e), ok: false);
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? List.from(_items)
          : _items.where((x) =>
              (x['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _showModal({dynamic item}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RegionSheet(item: item),
    );
    if (result == true) {
      await _load();
      widget.flash(item == null ? 'Mkoa umeongezwa!' : 'Mkoa umesasishwa!');
    }
  }

  Future<void> _delete(dynamic item) async {
    final ok = await _confirmDialog(context, item['name'] ?? '');
    if (!ok) return;
    try {
      await ApiService().delete('/admin/data/regions/${item['id']}');
      await _load();
      widget.flash('Mkoa umefutwa!');
    } catch (e) { widget.flash(_errMsg(e), ok: false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          Expanded(child: _searchField(_search, 'Tafuta mkoa...')),
          const SizedBox(width: 8),
          _countBadge(_filtered.length),
          const SizedBox(width: 8),
          _addButton('Ongeza', () => _showModal()),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : RefreshIndicator(
              onRefresh: _load, color: _kBlue,
              child: _filtered.isEmpty
                  ? const Center(child: Text('Hakuna mikoa', style: TextStyle(color: _kGrey500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final x = _filtered[i];
                        return _ItemCard(
                          title: x['name'] ?? '',
                          subtitle: 'ID: ${x['id'] ?? ''}',
                          icon: Icons.map_outlined,
                          iconColor: _kGreen600,
                          onEdit: () => _showModal(item: x),
                          onDelete: () => _delete(x),
                        );
                      },
                    ),
            )),
    ]);
  }
}

class _RegionSheet extends StatefulWidget {
  final dynamic item;
  const _RegionSheet({this.item});
  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  final _name = TextEditingController();
  bool _saving = false;
  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _name.text = widget.item['name'] ?? '';
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = {'name': _name.text.trim()};
      if (_isEdit) {
        await ApiService().patch('/admin/data/regions/${widget.item['id']}', data: body);
      } else {
        await ApiService().post('/admin/data/regions', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context, _errMsg(e), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) => _sheetWrap(
    context: context,
    title: _isEdit ? 'Hariri Mkoa' : 'Ongeza Mkoa',
    saving: _saving,
    onSave: _save,
    fields: [
      if (_isEdit) ...[
        _sectionLabel('ID'),
        const SizedBox(height: 4),
        _formField('${widget.item['id'] ?? ''}', enabled: false),
        const SizedBox(height: 14),
      ],
      _sectionLabel('JINA LA MKOA'),
      const SizedBox(height: 4),
      _formField('Jina la mkoa', controller: _name),
      const SizedBox(height: 4),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 5. WILAYA (Districts)
// ══════════════════════════════════════════════════════════════════════════════

class _DistrictsTab extends StatefulWidget {
  final void Function(String, {bool ok}) flash;
  const _DistrictsTab({required this.flash});
  @override
  State<_DistrictsTab> createState() => _DistrictsTabState();
}

class _DistrictsTabState extends State<_DistrictsTab> {
  List<dynamic> _items    = [];
  List<dynamic> _filtered = [];
  List<dynamic> _regions  = [];
  bool _loading        = true;
  bool _loadingRegions = true;
  final _search = TextEditingController();
  int? _regionFilter;

  @override
  void initState() { super.initState(); _loadRegions(); _load(); _search.addListener(_filter); }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().get('/admin/data/regions');
      if (!mounted) return;
      setState(() { _regions = _parseList(res.data, ['regions']); _loadingRegions = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRegions = false);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_regionFilter != null) params['region_id'] = _regionFilter;
      final res  = await ApiService().get('/admin/data/districts',
          queryParameters: params.isEmpty ? null : params);
      if (!mounted) return;
      final list = _parseList(res.data, ['districts']);
      setState(() { _items = list; _filter(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.flash(_errMsg(e), ok: false);
    }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? List.from(_items)
          : _items.where((x) =>
              (x['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _showModal({dynamic item}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DistrictSheet(item: item, regions: _regions),
    );
    if (result == true) {
      await _load();
      widget.flash(item == null ? 'Wilaya imeongezwa!' : 'Wilaya imesasishwa!');
    }
  }

  Future<void> _delete(dynamic item) async {
    final ok = await _confirmDialog(context, item['name'] ?? '');
    if (!ok) return;
    try {
      await ApiService().delete('/admin/data/districts/${item['id']}');
      await _load();
      widget.flash('Wilaya imefutwa!');
    } catch (e) { widget.flash(_errMsg(e), ok: false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Region filter
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _loadingRegions
            ? const SizedBox(height: 44)
            : DropdownButtonFormField<int?>(
                value: _regionFilter,
                decoration: _dropInp('Kichujio: Mikoa Yote'),
                style: const TextStyle(fontSize: 13, color: _kGrey900),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Mikoa Yote')),
                  ..._regions.map((r) => DropdownMenuItem<int?>(
                    value: r['id'] as int?,
                    child: Text(r['name'] ?? ''),
                  )),
                ],
                onChanged: (v) { setState(() => _regionFilter = v); _load(); },
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(child: _searchField(_search, 'Tafuta wilaya...')),
          const SizedBox(width: 8),
          _countBadge(_filtered.length),
          const SizedBox(width: 8),
          _addButton('Ongeza', () => _showModal()),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : RefreshIndicator(
              onRefresh: _load, color: _kBlue,
              child: _filtered.isEmpty
                  ? const Center(child: Text('Hakuna wilaya', style: TextStyle(color: _kGrey500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final x = _filtered[i];
                        final regionInfo = x['region_name'] != null
                            ? x['region_name'].toString()
                            : 'Mkoa ID: ${x['region_id'] ?? ''}';
                        return _ItemCard(
                          title: x['name'] ?? '',
                          subtitle: regionInfo,
                          icon: Icons.location_city_outlined,
                          iconColor: _kBlue,
                          onEdit: () => _showModal(item: x),
                          onDelete: () => _delete(x),
                        );
                      },
                    ),
            )),
    ]);
  }
}

class _DistrictSheet extends StatefulWidget {
  final dynamic       item;
  final List<dynamic> regions;
  const _DistrictSheet({this.item, required this.regions});
  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  final _name = TextEditingController();
  int? _regionId;
  bool _saving = false;
  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _name.text = widget.item['name'] ?? '';
      final rid  = widget.item['region_id'];
      _regionId  = rid is int ? rid : int.tryParse(rid.toString());
    } else if (widget.regions.isNotEmpty) {
      final first = widget.regions.first['id'];
      _regionId   = first is int ? first : int.tryParse(first.toString());
    }
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _regionId == null) return;
    setState(() => _saving = true);
    try {
      final body = {'name': _name.text.trim(), 'region_id': _regionId};
      if (_isEdit) {
        await ApiService().patch('/admin/data/districts/${widget.item['id']}', data: body);
      } else {
        await ApiService().post('/admin/data/districts', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context, _errMsg(e), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) => _sheetWrap(
    context: context,
    title: _isEdit ? 'Hariri Wilaya' : 'Ongeza Wilaya',
    saving: _saving,
    onSave: _save,
    fields: [
      if (_isEdit) ...[
        _sectionLabel('ID'),
        const SizedBox(height: 4),
        _formField('${widget.item['id'] ?? ''}', enabled: false),
        const SizedBox(height: 14),
      ],
      _sectionLabel('JINA LA WILAYA'),
      const SizedBox(height: 4),
      _formField('Jina la wilaya', controller: _name),
      const SizedBox(height: 14),
      _sectionLabel('MKOA'),
      const SizedBox(height: 4),
      DropdownButtonFormField<int?>(
        value: _regionId,
        decoration: _dropInp('Chagua mkoa'),
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        items: widget.regions.map((r) {
          final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString());
          return DropdownMenuItem<int?>(value: id, child: Text(r['name'] ?? ''));
        }).toList(),
        onChanged: (v) => setState(() => _regionId = v),
      ),
      const SizedBox(height: 4),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 6. VITUO (Facilities)
// ══════════════════════════════════════════════════════════════════════════════

class _FacilitiesTab extends StatefulWidget {
  final void Function(String, {bool ok}) flash;
  const _FacilitiesTab({required this.flash});
  @override
  State<_FacilitiesTab> createState() => _FacilitiesTabState();
}

class _FacilitiesTabState extends State<_FacilitiesTab> {
  List<dynamic> _items   = [];
  bool _loading          = true;
  final _search          = TextEditingController();
  String _category       = '';
  int?   _regionId;
  int?   _districtId;
  List<dynamic> _regions   = [];
  List<dynamic> _districts = [];
  bool _loadingRegions   = true;
  bool _loadingDistricts = false;
  Timer? _debounce;

  @override
  void initState() { super.initState(); _loadRegions(); _load(); _search.addListener(_onSearchChanged); }

  @override
  void dispose() { _debounce?.cancel(); _search.dispose(); super.dispose(); }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().get('/admin/data/regions');
      if (!mounted) return;
      setState(() { _regions = _parseList(res.data, ['regions']); _loadingRegions = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRegions = false);
    }
  }

  Future<void> _loadDistricts(int regionId) async {
    setState(() { _loadingDistricts = true; _districts = []; _districtId = null; });
    try {
      final res = await ApiService().get('/admin/data/districts', queryParameters: {'region_id': regionId});
      if (!mounted) return;
      setState(() { _districts = _parseList(res.data, ['districts']); _loadingDistricts = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDistricts = false);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{};
      if (_category.isNotEmpty)  params['category']    = _category;
      if (_regionId != null)     params['region_id']   = _regionId;
      if (_districtId != null)   params['district_id'] = _districtId;
      final q = _search.text.trim();
      if (q.isNotEmpty) params['q'] = q;
      final res  = await ApiService().get('/admin/data/facilities',
          queryParameters: params.isEmpty ? null : params);
      if (!mounted) return;
      setState(() { _items = _parseList(res.data, ['facilities', 'items']); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      widget.flash(_errMsg(e), ok: false);
    }
  }

  Future<void> _showModal({dynamic item}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FacilitySheet(item: item, regions: _regions),
    );
    if (result == true) {
      await _load();
      widget.flash(item == null ? 'Kituo kimeongezwa!' : 'Kituo kimesasishwa!');
    }
  }

  Future<void> _delete(dynamic item) async {
    final ok = await _confirmDialog(context, item['name'] ?? '');
    if (!ok) return;
    try {
      final id  = item['id'] ?? item['code'] ?? '';
      final cat = item['category'] ?? '';
      await ApiService().delete('/admin/data/facilities/$id',
          queryParameters: cat.isNotEmpty ? {'category': cat} : null);
      await _load();
      widget.flash('Kituo kimefutwa!');
    } catch (e) { widget.flash(_errMsg(e), ok: false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filters row 1
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _category.isEmpty ? '' : _category,
            decoration: _dropInp('Aina: Zote'),
            style: const TextStyle(fontSize: 12, color: _kGrey900),
            items: const [
              DropdownMenuItem(value: '',          child: Text('Zote')),
              DropdownMenuItem(value: 'health',    child: Text('Afya')),
              DropdownMenuItem(value: 'education', child: Text('Elimu')),
            ],
            onChanged: (v) { setState(() => _category = v ?? ''); _load(); },
          )),
          const SizedBox(width: 8),
          Expanded(child: _loadingRegions
              ? const SizedBox(height: 44)
              : DropdownButtonFormField<int?>(
                  value: _regionId,
                  decoration: _dropInp('Mkoa: Yote'),
                  style: const TextStyle(fontSize: 12, color: _kGrey900),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Yote')),
                    ..._regions.map((r) {
                      final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString());
                      return DropdownMenuItem<int?>(value: id, child: Text(r['name'] ?? '', overflow: TextOverflow.ellipsis));
                    }),
                  ],
                  onChanged: (v) {
                    setState(() { _regionId = v; _districtId = null; _districts = []; });
                    if (v != null) _loadDistricts(v);
                    _load();
                  },
                )),
        ]),
      ),
      // District filter
      if (_regionId != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: _loadingDistricts
              ? const LinearProgressIndicator(color: _kBlue)
              : DropdownButtonFormField<int?>(
                  value: _districtId,
                  decoration: _dropInp('Wilaya Zote'),
                  style: const TextStyle(fontSize: 13, color: _kGrey900),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Wilaya Zote')),
                    ..._districts.map((d) {
                      final id = d['id'] is int ? d['id'] as int : int.tryParse(d['id'].toString());
                      return DropdownMenuItem<int?>(value: id, child: Text(d['name'] ?? ''));
                    }),
                  ],
                  onChanged: (v) { setState(() => _districtId = v); _load(); },
                ),
        ),
      // Search + add
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(child: _searchField(_search, 'Tafuta vituo...')),
          const SizedBox(width: 8),
          _countBadge(_items.length),
          const SizedBox(width: 8),
          _addButton('Ongeza', () => _showModal()),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : RefreshIndicator(
              onRefresh: _load, color: _kBlue,
              child: _items.isEmpty
                  ? const Center(child: Text('Hakuna vituo', style: TextStyle(color: _kGrey500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final x            = _items[i];
                        final cat          = x['category'] ?? '';
                        final typeOrLevel  = x['type'] ?? x['level'] ?? '';
                        final regionDistrict = [x['region_name'], x['district_name']]
                            .where((v) => v != null && v.toString().isNotEmpty).join(' › ');
                        final isEdu = cat == 'education';
                        return _ItemCard(
                          title: x['name'] ?? '',
                          subtitle: '${x['code'] ?? x['school_code'] ?? x['id'] ?? ''}'
                              '${regionDistrict.isNotEmpty ? '  ·  $regionDistrict' : ''}',
                          icon: isEdu ? Icons.school_outlined : Icons.local_hospital_outlined,
                          iconColor: isEdu ? _kGold600 : _kRed,
                          badge: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (cat.isNotEmpty) _categoryBadge(cat),
                            if (typeOrLevel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(typeOrLevel, style: const TextStyle(fontSize: 11, color: _kGrey500)),
                            ],
                          ]),
                          onEdit: () => _showModal(item: x),
                          onDelete: () => _delete(x),
                        );
                      },
                    ),
            )),
    ]);
  }
}

class _FacilitySheet extends StatefulWidget {
  final dynamic       item;
  final List<dynamic> regions;
  const _FacilitySheet({this.item, required this.regions});
  @override
  State<_FacilitySheet> createState() => _FacilitySheetState();
}

class _FacilitySheetState extends State<_FacilitySheet> {
  final _name    = TextEditingController();
  String _category    = 'health';
  int?   _regionId;
  int?   _districtId;
  String _typeOrLevel = '';
  List<dynamic> _districts = [];
  bool _loadingDistricts = false;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  static const _healthTypes = ['Dispensary', 'Health Center', 'Hospital', 'Regional Hospital', 'Referral Hospital'];
  static const _eduLevels   = ['Primary', 'Secondary'];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _name.text   = widget.item['name']     ?? '';
      _category    = widget.item['category'] ?? 'health';
      _typeOrLevel = widget.item['type']     ?? widget.item['level'] ?? '';
      final rid    = widget.item['region_id'];
      _regionId    = rid is int ? rid : (rid != null ? int.tryParse(rid.toString()) : null);
      final did    = widget.item['district_id'];
      _districtId  = did is int ? did : (did != null ? int.tryParse(did.toString()) : null);
      if (_regionId != null) _loadDistricts(_regionId!);
    } else if (widget.regions.isNotEmpty) {
      final first = widget.regions.first['id'];
      _regionId   = first is int ? first : int.tryParse(first.toString());
      if (_regionId != null) _loadDistricts(_regionId!);
    }
  }

  Future<void> _loadDistricts(int regionId) async {
    setState(() { _loadingDistricts = true; _districts = []; });
    try {
      final res = await ApiService().get('/admin/data/districts', queryParameters: {'region_id': regionId});
      if (!mounted) return;
      setState(() {
        _districts = _parseList(res.data, ['districts']);
        _loadingDistricts = false;
        if (!_isEdit && _districts.isNotEmpty) {
          final first = _districts.first['id'];
          _districtId = first is int ? first : int.tryParse(first.toString());
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDistricts = false);
    }
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _regionId == null || _districtId == null) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'category': _category,
        'region_id': _regionId,
        'district_id': _districtId,
      };
      if (_typeOrLevel.isNotEmpty) {
        body[_category == 'health' ? 'type' : 'level'] = _typeOrLevel;
      }
      if (_isEdit) {
        final id = widget.item['id'] ?? widget.item['code'] ?? '';
        await ApiService().patch('/admin/data/facilities/$id', data: body);
      } else {
        await ApiService().post('/admin/data/facilities', data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context, _errMsg(e), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeOptions    = _category == 'health' ? _healthTypes : _eduLevels;
    final validTypeOrLevel = typeOptions.contains(_typeOrLevel) ? _typeOrLevel : null;

    return _sheetWrap(
      context: context,
      title: _isEdit ? 'Hariri Kituo' : 'Ongeza Kituo',
      saving: _saving,
      onSave: _save,
      fields: [
        _sectionLabel('AINA YA KITUO'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: _dropInp('Aina'),
          style: const TextStyle(fontSize: 13, color: _kGrey900),
          items: const [
            DropdownMenuItem(value: 'health',    child: Text('🏥 Afya')),
            DropdownMenuItem(value: 'education', child: Text('📚 Elimu')),
          ],
          onChanged: (v) => setState(() { _category = v ?? 'health'; _typeOrLevel = ''; }),
        ),
        const SizedBox(height: 14),
        _sectionLabel('MKOA'),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          value: _regionId,
          decoration: _dropInp('Chagua mkoa'),
          style: const TextStyle(fontSize: 13, color: _kGrey900),
          items: widget.regions.map((r) {
            final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString());
            return DropdownMenuItem<int?>(value: id, child: Text(r['name'] ?? '', overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (v) {
            setState(() { _regionId = v; _districtId = null; _districts = []; });
            if (v != null) _loadDistricts(v);
          },
        ),
        const SizedBox(height: 14),
        _sectionLabel('WILAYA'),
        const SizedBox(height: 4),
        _loadingDistricts
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(color: _kBlue))
            : DropdownButtonFormField<int?>(
                value: _districtId,
                decoration: _dropInp('Chagua wilaya'),
                style: const TextStyle(fontSize: 13, color: _kGrey900),
                items: _districts.map((d) {
                  final id = d['id'] is int ? d['id'] as int : int.tryParse(d['id'].toString());
                  return DropdownMenuItem<int?>(value: id, child: Text(d['name'] ?? ''));
                }).toList(),
                onChanged: (v) => setState(() => _districtId = v),
              ),
        const SizedBox(height: 14),
        _sectionLabel('JINA LA KITUO'),
        const SizedBox(height: 4),
        _formField('Jina la kituo', controller: _name),
        const SizedBox(height: 14),
        _sectionLabel(_category == 'health' ? 'AINA (NGAZI)' : 'KIWANGO'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: validTypeOrLevel,
          decoration: _dropInp(_category == 'health' ? 'Aina ya kituo' : 'Kiwango'),
          style: const TextStyle(fontSize: 13, color: _kGrey900),
          items: typeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _typeOrLevel = v ?? ''),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
