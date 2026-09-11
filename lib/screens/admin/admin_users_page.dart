import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/select_sheet.dart';

// ── Brand colors ──────────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kRed     = Color(0xFFDC2626);
const _kRed50   = Color(0xFFFEF2F2);
const _kRed200  = Color(0xFFFEE2E2);
const _kGrey50  = Color(0xFFF9FAFB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey300 = Color(0xFFD1D5DB);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey700 = Color(0xFF374151);
const _kGrey900 = Color(0xFF111827);
const _kGold    = Color(0xFFF59E0B);
const _kGold100 = Color(0xFFFEF3C7);
const _kGoldText = Color(0xFFD97706);
const _kGreen   = Color(0xFF22C55E);
const _kGreenDk = Color(0xFF16A34A);
const _kGreen50 = Color(0xFFF0FDF4);
const _kGreen200 = Color(0xFFBBF7D0);
const _kOrange50 = Color(0xFFFFF7ED);
const _kOrangeTx = Color(0xFFC2410C);
const _kOrange200 = Color(0xFFFED7AA);
const _kEmerald = Color(0xFF10B981);

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<dynamic> _users = [];
  bool _loading = true;
  bool _live    = false;
  String _q        = '';
  String _category = '';
  int    _page     = 1;
  int    _total    = 0;
  static const int _pageSize = 20;

  // Bulk select
  final Set<String> _selected = {};
  bool _bulkBusy = false;

  // Trash
  bool _showTrash = false;
  List<dynamic> _trash = [];
  int  _trashTotal = 0;

  // Message banner
  String? _message;
  Timer?  _msgTimer;

  final TextEditingController _searchCtrl = TextEditingController();

  // Location cascade filters
  int?   _regionId;
  int?   _districtId;
  String _facilityId    = '';
  String _subjectFilter = '';
  List<dynamic> _regions    = [];
  List<dynamic> _districts  = [];
  List<dynamic> _facilities = [];
  List<dynamic> _subjects   = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadTrash();
    _setupLive();
    _loadRegions();
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  void _setupLive() {
    WebSocketService().onAny((payload) {
      if (!mounted) return;
      final type = (payload['event_type'] ?? payload['type'] ?? '') as String;
      if (type.startsWith('user.') || type.startsWith('data.')) {
        setState(() => _live = true);
        _load();
        _loadTrash();
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) setState(() => _live = false);
        });
      }
    });
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      if (!mounted) return;
      final d = res.data;
      setState(() => _regions = d is List ? d : (d['regions'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    try {
      final level = _category == 'education' ? 'Primary' : 'Secondary';
      final res = await ApiService().getSubjects(level: level);
      if (!mounted) return;
      final d = res.data;
      setState(() => _subjects = d is List ? d : (d['subjects'] ?? []));
    } catch (_) {}
  }

  Future<void> _onRegionChange(int? id) async {
    setState(() {
      _regionId = id; _districtId = null; _facilityId = '';
      _districts = []; _facilities = []; _page = 1;
    });
    if (id != null) {
      try {
        final res = await ApiService().getDistricts(id);
        final d = res.data;
        if (mounted) setState(() => _districts = d is List ? d : (d['districts'] ?? []));
      } catch (_) {}
    }
    _load();
  }

  Future<void> _onDistrictChange(int? id) async {
    setState(() { _districtId = id; _facilityId = ''; _facilities = []; _page = 1; });
    if (id != null) {
      try {
        final res = await ApiService().getFacilities(id, category: _category.isNotEmpty ? _category : 'health');
        final d = res.data;
        if (mounted) setState(() => _facilities = d is List ? d : (d['facilities'] ?? []));
      } catch (_) {}
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().adminUsers(params: {
        if (_q.isNotEmpty) 'q': _q,
        if (_category.isNotEmpty) 'category': _category,
        if (_regionId != null) 'region_id': _regionId,
        if (_districtId != null) 'district_id': _districtId,
        if (_facilityId.isNotEmpty) 'facility_id': _facilityId,
        if (_subjectFilter.isNotEmpty) 'subject': _subjectFilter,
        'limit': 200,
      });
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      final all = (data['users'] as List?) ?? [];
      // Client-side pagination
      setState(() {
        _users = all;
        _total = (data['total'] ?? all.length) as int;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTrash() async {
    try {
      final res = await ApiService().get('/admin/trash');
      final data = res.data;
      if (!mounted) return;
      setState(() {
        _trash = (data is Map ? data['items'] : null) ?? (data is List ? data : []);
        _trashTotal = (data is Map ? data['total'] : null) ?? _trash.length;
      });
    } catch (_) {}
  }

  void _showMsg(String msg) {
    _msgTimer?.cancel();
    if (!mounted) return;
    setState(() => _message = msg);
    _msgTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _message = null);
    });
  }

  // ── Pagination ──
  int get _totalPages => (_total / _pageSize).ceil().clamp(1, 9999);
  List<dynamic> get _pageItems {
    final start = (_page - 1) * _pageSize;
    return _users.skip(start).take(_pageSize).toList();
  }

  String _uid(dynamic u) => (u['_id'] ?? u['id'] ?? '').toString();

  void _toggleOne(String id) {
    setState(() {
      if (_selected.contains(id)) { _selected.remove(id); }
      else { _selected.add(id); }
    });
  }

  void _toggleAll() {
    if (_users.every((u) => _selected.contains(_uid(u)))) {
      setState(() => _selected.clear());
    } else {
      setState(() => _selected.addAll(_users.map(_uid)));
    }
  }

  Future<void> _bulkAction(String action) async {
    if (_selected.isEmpty) return;
    final ids = List<String>.from(_selected);
    final label = action == 'delete' ? 'Futa' : action == 'disable' ? 'Simamisha' : 'Rudisha';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label ${ids.length} Watumiaji?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(label, style: TextStyle(color: action == 'delete' ? _kRed : _kBlue))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    setState(() { _bulkBusy = true; });
    try {
      await ApiService().post('/admin/users/bulk', data: {'ids': ids, 'action': action});
      setState(() { _selected.clear(); _bulkBusy = false; });
      _showMsg('$label imefanikiwa — ${ids.length} watumiaji');
      _load();
      if (action == 'delete') _loadTrash();
    } catch (e) {
      setState(() => _bulkBusy = false);
      _showMsg('Hitilafu: $e');
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> _toggleAdmin(Map<String, dynamic> u) async {
    final isAdmin = u['is_admin'] == true;
    if (isAdmin) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ondoa Admin?'),
          content: Text('${u['full_name']} (${u['phone_primary']}) atapoteza hadhi ya Admin.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ondoa', style: TextStyle(color: _kRed))),
          ],
        ),
      ) ?? false;
      if (!ok) return;
      await ApiService().adminRevoke(_uid(u));
      _showMsg('${u['full_name']}: admin imeondolewa');
    } else {
      await ApiService().adminGrant(_uid(u));
      _showMsg('${u['full_name']}: admin imewekwa');
    }
    setState(() {
      _users = _users.map((x) => _uid(x) == _uid(u) ? {...x, 'is_admin': !isAdmin} : x).toList();
    });
  }

  Future<void> _toggleSuspend(Map<String, dynamic> u) async {
    final next = u['status'] == 'disabled' ? 'active' : 'disabled';
    if (next == 'disabled') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Simamisha Mtumiaji?'),
          content: Text('${u['full_name']} (${u['phone_primary']})'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simamisha', style: TextStyle(color: _kRed))),
          ],
        ),
      ) ?? false;
      if (!ok) return;
    }
    try {
      await ApiService().adminUpdateUser(_uid(u), {'status': next});
      _showMsg('${u['full_name']}: ${next == 'disabled' ? 'Imesimamishwa' : 'Imefunguliwa'}');
      setState(() {
        _users = _users.map((x) => _uid(x) == _uid(u) ? {...x, 'status': next} : x).toList();
      });
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  Future<void> _toggleContact(Map<String, dynamic> u) async {
    try {
      final res = await ApiService().adminToggleContact(_uid(u));
      final enabled = res.data['contact_enabled'] ?? false;
      _showMsg('${u['full_name']}: ${enabled ? 'Ameruhusiwa kupiga simu/SMS' : 'Hakuruhusiwa tena'}');
      setState(() {
        _users = _users.map((x) => _uid(x) == _uid(u) ? {...x, 'contact_enabled': enabled} : x).toList();
      });
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Mtumiaji?'),
        content: Text('${u['full_name']} (${u['phone_primary']})\n\nAkaunti itakwenda kwenye Trash na inaweza kurudishwa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Futa', style: TextStyle(color: _kRed))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await ApiService().adminDeleteUser(_uid(u));
      _showMsg('Imefutwa ${u['full_name']} — kwenda Trash');
      setState(() { _users = _users.where((x) => _uid(x) != _uid(u)).toList(); _total = (_total - 1).clamp(0, 9999); });
      _loadTrash();
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  Future<void> _restoreTrash(Map<String, dynamic> u) async {
    try {
      await ApiService().post('/admin/trash/${_uid(u)}/restore');
      _showMsg('${u['full_name']} amerudishwa');
      setState(() { _trash = _trash.where((x) => _uid(x) != _uid(u)).toList(); _trashTotal = (_trashTotal - 1).clamp(0, 9999); });
      _load();
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  Future<void> _purgeTrash(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Kabisa?'),
        content: Text('${u['full_name']} — hii haiwezi kugeuzwa!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Futa Kabisa', style: TextStyle(color: _kRed))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await ApiService().delete('/admin/trash/${_uid(u)}');
      _showMsg('Imefutwa kabisa ${u['full_name']}');
      setState(() { _trash = _trash.where((x) => _uid(x) != _uid(u)).toList(); _trashTotal = (_trashTotal - 1).clamp(0, 9999); });
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  Future<void> _restoreAllTrash() async {
    if (_trash.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rudisha Zote?'),
        content: Text('Rudisha watumiaji ${_trash.length} kutoka kwenye Trash.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rudisha', style: TextStyle(color: Color(0xFF16A34A)))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await ApiService().post('/admin/trash/restore-all');
      _showMsg('Watumiaji wote wamerudishwa');
      setState(() { _trash = []; _trashTotal = 0; });
      _load();
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  Future<void> _purgeAllTrash() async {
    if (_trash.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Zote Kabisa?'),
        content: const Text('Hii haiwezi kugeuzwa! Watumiaji wote kwenye Trash watafutwa kabisa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Futa Kabisa', style: TextStyle(color: _kRed))),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await ApiService().delete('/admin/trash');
      _showMsg('Trash imefutwa kabisa');
      setState(() { _trash = []; _trashTotal = 0; });
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  // ── Add Admin Dialog ──────────────────────────────────────────────────────────
  Future<void> _showAddAdminDialog() async {
    final emailCtrl = TextEditingController();
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.shield_outlined, size: 20, color: _kBlue),
            const SizedBox(width: 8),
            const Text('Ongeza Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (err != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                  child: Text(err!, style: const TextStyle(fontSize: 12, color: _kRed)),
                ),
                const SizedBox(height: 12),
              ],
              _dialogField('Jina Kamili', nameCtrl, icon: Icons.person_outline),
              const SizedBox(height: 10),
              _dialogField('Barua Pepe', emailCtrl, icon: Icons.email_outlined, type: TextInputType.emailAddress),
              const SizedBox(height: 10),
              _dialogField('Simu', phoneCtrl, icon: Icons.phone_outlined, type: TextInputType.phone),
              const SizedBox(height: 10),
              _dialogField('Nenosiri', passCtrl, icon: Icons.lock_outline, obscure: true),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ghairi')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
                  setSt(() => err = 'Jaza sehemu zote zinazohitajika');
                  return;
                }
                try {
                  await ApiService().post('/admin/users/create-admin', data: {
                    'full_name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone_primary': phoneCtrl.text.trim(),
                    'password': passCtrl.text,
                    'is_admin': true,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showMsg('Admin ${nameCtrl.text.trim()} ameongezwa');
                  _load();
                } catch (e) {
                  setSt(() => err = 'Hitilafu: $e');
                }
              },
              child: const Text('Ongeza'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl, {
    IconData? icon, TextInputType? type, bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: _kGrey500),
        prefixIcon: icon != null ? Icon(icon, size: 18, color: _kGrey400) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final allSelected = _users.isNotEmpty && _users.every((u) => _selected.contains(_uid(u)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADER ───────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: title + primary action
            Row(children: [
              Text('Watumiaji', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kGrey900)),
              const SizedBox(width: 8),
              _LiveBadge(live: _live),
              const Spacer(),
              _PillBtn(
                label: '+ Ongeza',
                icon: Icons.person_add_outlined,
                onTap: () => _showCreateDialog(),
                primary: true,
              ),
            ]),
            const SizedBox(height: 8),
            // Row 2: secondary actions
            Wrap(spacing: 6, runSpacing: 6, children: [
              _PillBtn(
                label: 'Trash${_trashTotal > 0 ? ' ($_trashTotal)' : ''}',
                icon: Icons.delete_outline,
                onTap: () { setState(() => _showTrash = !_showTrash); },
                active: _showTrash,
                danger: _showTrash,
              ),
              _PillBtn(
                label: '+ Admin',
                icon: Icons.shield_outlined,
                onTap: () => _showAddAdminDialog(),
              ),
              _PillBtn(
                label: 'Import',
                icon: Icons.download_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Import bado haijatekelezwa')));
                },
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 8),

        // ── BULK BAR ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kGrey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              GestureDetector(
                onTap: _toggleAll,
                child: Row(children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: Checkbox(
                      value: allSelected,
                      onChanged: (_) => _toggleAll(),
                      activeColor: _kBlue,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: _kGrey300),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Chagua Zote (${_selected.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGrey700)),
                ]),
              ),
              const SizedBox(width: 12),
              if (_selected.isNotEmpty) ...[
                _SmallBtn(label: 'Fungua', color: _kGreenDk, bg: _kGreen50, border: _kGreen200,
                  onTap: _bulkBusy ? null : () => _bulkAction('enable')),
                const SizedBox(width: 6),
                _SmallBtn(label: 'Simamisha', color: _kOrangeTx, bg: _kOrange50, border: _kOrange200,
                  onTap: _bulkBusy ? null : () => _bulkAction('disable')),
                const SizedBox(width: 6),
                _SmallBtn(label: 'Futa', color: _kRed, bg: _kRed50, border: _kRed200,
                  onTap: _bulkBusy ? null : () => _bulkAction('delete')),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),

        // ── MESSAGE BANNER ───────────────────────────────────────────────────
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_message!, style: const TextStyle(fontSize: 13, color: _kBlue)),
            ),
          ),
        if (_message != null) const SizedBox(height: 8),

        // ── FILTERS ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            // Row 1: Search + Category
            Row(children: [
              Expanded(
                child: _SearchBox(
                  controller: _searchCtrl,
                  onSubmit: (v) { setState(() { _q = v; _page = 1; }); _load(); },
                  onClear: () { _searchCtrl.clear(); setState(() { _q = ''; _page = 1; }); _load(); },
                ),
              ),
              const SizedBox(width: 8),
              _SelectBox(
                value: _category,
                items: const [
                  DropdownMenuItem(value: '', child: Text('Idara Zote', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'health', child: Text('Afya', style: TextStyle(fontSize: 13))),
                  DropdownMenuItem(value: 'education', child: Text('Elimu', style: TextStyle(fontSize: 13))),
                ],
                onChange: (v) {
                  setState(() { _category = v; _page = 1; _subjectFilter = ''; _facilityId = ''; _facilities = []; });
                  _loadSubjects();
                  if (_districtId != null) { _onDistrictChange(_districtId); } else { _load(); }
                },
                width: 110,
              ),
            ]),
            // Row 2: Region → District → Facility → Subject (cascading)
            const SizedBox(height: 8),
            _LocationFiltersRow(
              regions: _regions, districts: _districts,
              facilities: _facilities, subjects: _subjects,
              regionId: _regionId, districtId: _districtId,
              facilityId: _facilityId, subjectFilter: _subjectFilter,
              onRegion: _onRegionChange,
              onDistrict: _onDistrictChange,
              onFacility: (v) { setState(() { _facilityId = v; _page = 1; }); _load(); },
              onSubject: (v) { setState(() { _subjectFilter = v; _page = 1; }); _load(); },
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // ── COUNT ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Jumla $_total',
            style: const TextStyle(fontSize: 11, color: _kGrey500)),
        ),
        const SizedBox(height: 6),

        // ── TABLE ─────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kBlue,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    children: [
                      // User cards
                      ..._buildUserList(),
                      const SizedBox(height: 12),

                      // Pagination
                      if (_totalPages > 1) _buildPagination(),

                      // Trash section
                      if (_showTrash) ...[
                        const SizedBox(height: 12),
                        _buildTrashSection(),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── USER CARDS ─────────────────────────────────────────────────────────────
  List<Widget> _buildUserList() {
    final items = _pageItems;
    if (items.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: Text('Hakuna watumiaji', style: TextStyle(color: _kGrey400, fontSize: 14))),
        ),
      ];
    }
    return items.asMap().entries.map((entry) {
      final i = entry.key;
      final u = entry.value as Map<String, dynamic>;
      final id = _uid(u);
      final isAdmin   = u['is_admin'] == true;
      final isVerified = u['is_verified'] == true;
      final status    = (u['status'] ?? 'active') as String;
      final isDisabled = status == 'disabled';
      final contactEnabled = u['contact_enabled'] == true;
      final n    = (_page - 1) * _pageSize + i + 1;
      final name = '${u['full_name'] ?? ''}';
      final phone = '${u['phone_primary'] ?? ''}';
      final cadre = '${u['cadre_code'] ?? ''}';
      final category = '${u['category'] ?? ''}';
      final isEdu = category == 'education';
      final st = (u['current_station'] as Map?) ?? {};
      final region = '${st['region_name'] ?? ''}';
      final isSelected = _selected.contains(id);
      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDisabled
                ? _kRed.withValues(alpha: 0.2)
                : isAdmin
                    ? _kGold.withValues(alpha: 0.5)
                    : _kGrey100,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(children: [
          // ── Main info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Checkbox (not for admins)
              if (!isAdmin) ...[
                SizedBox(width: 18, height: 18,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleOne(id),
                    activeColor: _kBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: _kGrey300),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Avatar
              Stack(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isAdmin ? _kGold100
                      : isEdu ? _kGreen50 : _kBlue50,
                  child: Text(initial, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: isAdmin ? _kGoldText : isEdu ? _kGreenDk : _kBlue,
                  )),
                ),
                if (isAdmin)
                  Positioned(right: 0, bottom: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: _kGold, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.shield, size: 8, color: Colors.white),
                    ),
                  ),
              ]),
              const SizedBox(width: 10),
              // Info column
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('$n. ', style: const TextStyle(fontSize: 10, color: _kGrey400, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey900),
                    overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 2),
                Text(phone, style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w500)),
                const SizedBox(height: 5),
                // Category + Cadre + Region
                Wrap(spacing: 4, runSpacing: 3, children: [
                  _badge(isEdu ? 'Elimu' : 'Afya',
                    isEdu ? _kGreenDk : _kBlue,
                    isEdu ? _kGreen50 : _kBlue50),
                  if (cadre.isNotEmpty)
                    _badge(cadre, _kEmerald, _kEmerald.withValues(alpha: 0.1)),
                  if (region.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on_outlined, size: 10, color: _kGrey400),
                      const SizedBox(width: 2),
                      Text(region, style: const TextStyle(fontSize: 10, color: _kGrey500)),
                    ]),
                ]),
                const SizedBox(height: 5),
                // Status + Payment + Admin role
                Wrap(spacing: 4, runSpacing: 3, children: [
                  _badge(isDisabled ? 'Imesimamishwa' : 'Hai',
                    isDisabled ? _kRed : _kGreenDk,
                    isDisabled ? _kRed50 : _kGreen50),
                  _badge(isVerified ? 'Amelipa' : 'Hajalipa',
                    isVerified ? _kGreenDk : _kRed,
                    isVerified ? _kGreen50 : _kRed50),
                  if (isAdmin)
                    GestureDetector(
                      onTap: () => _toggleAdmin(u),
                      child: _badge('★ Admin', _kGoldText, _kGold100),
                    ),
                  if (!isAdmin)
                    GestureDetector(
                      onTap: () => _toggleAdmin(u),
                      child: _badge('Mtumiaji', _kGrey500, _kGrey100),
                    ),
                ]),
              ])),
            ]),
          ),
          // ── Action row ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kGrey50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: const Border(top: BorderSide(color: _kGrey100)),
            ),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              _ActBtn(label: 'Angalia', icon: Icons.visibility_outlined,
                color: _kGrey500, bg: Colors.white, onTap: () => _showDetail(u)),
              _ActBtn(label: 'Hariri', icon: Icons.edit_outlined,
                color: _kBlue, bg: _kBlue50, onTap: () => _showEditDialog(u)),
              if (!isAdmin) ...[
                _ActBtn(
                  label: isDisabled ? 'Fungua' : 'Simamisha',
                  icon: isDisabled ? Icons.check_circle_outline : Icons.pause_circle_outline,
                  color: isDisabled ? _kGreenDk : _kOrangeTx,
                  bg: isDisabled ? _kGreen50 : _kOrange50,
                  onTap: () => _toggleSuspend(u),
                ),
                if (!isVerified)
                  _ActBtn(
                    label: contactEnabled ? 'Ruhusa ✓' : 'Ruhusu',
                    icon: Icons.phone_outlined,
                    color: contactEnabled ? _kGreenDk : _kGrey500,
                    bg: contactEnabled ? _kGreen50 : Colors.white,
                    onTap: () => _toggleContact(u),
                  ),
                _ActBtn(label: 'Futa', icon: Icons.delete_outline,
                  color: _kRed, bg: _kRed50, onTap: () => _delete(u)),
              ],
            ]),
          ),
        ]),
      );
    }).toList();
  }

  Widget _badge(String label, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  // ── PAGINATION ─────────────────────────────────────────────────────────────
  Widget _buildPagination() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _PageBtn(label: '← Rudi', enabled: _page > 1, onTap: () { setState(() => _page--); }),
      const SizedBox(width: 12),
      Text('$_page / $_totalPages',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey500)),
      const SizedBox(width: 12),
      _PageBtn(label: 'Endelea →', enabled: _page < _totalPages, onTap: () { setState(() => _page++); }),
    ]);
  }

  // ── TRASH SECTION ──────────────────────────────────────────────────────────
  Widget _buildTrashSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: _kRed50.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _kRed.withValues(alpha: 0.2))),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.delete_outline, size: 18, color: _kRed),
                const SizedBox(width: 8),
                Text('Trash ($_trashTotal)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showTrash = false),
                  child: const Icon(Icons.close, size: 18, color: _kGrey400),
                ),
              ]),
              if (_trash.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  GestureDetector(
                    onTap: _restoreAllTrash,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(999)),
                      child: const Text('Rudisha Zote', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  GestureDetector(
                    onTap: _purgeAllTrash,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(999)),
                      child: const Text('Futa Zote Kabisa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  GestureDetector(
                    onTap: _fixMajina,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(999)),
                      child: const Text('Fix Majina', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  GestureDetector(
                    onTap: _safishaIdara,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(999)),
                      child: const Text('Safisha Idara', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          // Content
          if (_trash.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Trash iko tupu', style: TextStyle(fontSize: 13, color: _kGrey400))),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: _trash.asMap().entries.map((entry) {
                  final u = entry.value as Map<String, dynamic>;
                  final st = (u['current_station'] as Map?) ?? {};
                  final name = '${u['full_name'] ?? ''}';
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kRed.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: _kRed50,
                        child: Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kRed))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900)),
                        const SizedBox(height: 2),
                        Text('${u['phone_primary'] ?? '—'}',
                          style: const TextStyle(fontSize: 11, color: _kBlue)),
                        if ((st['region_name'] ?? '').isNotEmpty)
                          Text('${st['region_name']}',
                            style: const TextStyle(fontSize: 10, color: _kGrey500)),
                      ])),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        _ActBtn(label: 'Rudisha', icon: Icons.restore_outlined,
                          color: _kGreenDk, bg: _kGreen50, onTap: () => _restoreTrash(u)),
                        const SizedBox(height: 4),
                        _ActBtn(label: 'Futa Kabisa', icon: Icons.delete_forever_outlined,
                          color: _kRed, bg: _kRed50, onTap: () => _purgeTrash(u)),
                      ]),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _fixMajina() async {
    try {
      final res = await ApiService().post('/admin/users/fix-names');
      final data = res.data as Map<String, dynamic>? ?? {};
      _showMsg('Fix Majina: ${data['message'] ?? 'Imekamilika'} (updated: ${data['updated'] ?? 0})');
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  Future<void> _safishaIdara() async {
    try {
      final res = await ApiService().post('/admin/departments/cleanup');
      final data = res.data as Map<String, dynamic>? ?? {};
      _showMsg('Safisha Idara: removed ${data['removed'] ?? 0}, remaining ${data['remaining'] ?? 0}');
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  // ── DETAIL MODAL ───────────────────────────────────────────────────────────
  void _showDetail(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ViewUserSheet(user: u, onEdit: () { Navigator.pop(ctx); _showEditDialog(u); }),
    );
  }

  // ── EDIT DIALOG ────────────────────────────────────────────────────────────
  Future<void> _showEditDialog(Map<String, dynamic> u) async {
    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _EditUserDialog(user: u, regions: _regions),
    );
    if (changes == null || !mounted) return;
    try {
      await ApiService().adminUpdateUser(_uid(u), changes);
      _showMsg('${changes['full_name'] ?? u['full_name']} imesasishwa');
      setState(() {
        _users = _users.map((x) => _uid(x) == _uid(u) ? {...x, ...changes} : x).toList();
      });
    } catch (e) { _showMsg('Hitilafu: $e'); }
  }

  // ── CREATE DIALOG ──────────────────────────────────────────────────────────
  Future<void> _showCreateDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateUserSheet(
        regions: _regions,
        onCreated: (created) {
          _showMsg('Mtumiaji mpya ameongezwa');
          setState(() {
            _users = [created, ..._users];
            _total++;
          });
        },
      ),
    );
  }

}

// ── SMALL COMPONENTS ─────────────────────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  final bool live;
  const _LiveBadge({required this.live});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}
class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: 0.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: live ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        border: Border.all(color: live ? const Color(0xFF86EFAC) : const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, snap) => Opacity(
            opacity: live ? _anim.value : 1.0,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? _kGreen : const Color(0xFFD1D5DB),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('LIVE', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          color: live ? _kGreenDk : const Color(0xFF9CA3AF),
        )),
      ]),
    );
  }
}

class _PillBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool active;
  final bool danger;
  const _PillBtn({required this.label, required this.icon, required this.onTap,
    this.primary = false, this.active = false, this.danger = false});
  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    if (primary) {
      bg = _kBlue; fg = Colors.white; border = _kBlue;
    } else if (danger && active) {
      bg = _kRed50; fg = _kRed; border = _kRed200;
    } else {
      bg = _kGrey100; fg = _kGrey700; border = _kGrey200;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ]),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color, bg, border;
  final VoidCallback? onTap;
  const _SmallBtn({required this.label, required this.color, required this.bg, required this.border, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: border)),
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;
  const _ActBtn({required this.label, required this.icon, required this.color, required this.bg, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
        ]),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.label, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? _kGrey200 : _kGrey100),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: enabled ? _kGrey700 : _kGrey300)),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  const _SearchBox({required this.controller, required this.onSubmit, required this.onClear});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Tafuta kwa jina, simu au kada...',
          hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          prefixIcon: const Icon(Icons.search, size: 16, color: _kGrey400),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 14, color: _kGrey400), onPressed: onClear)
              : null,
        ),
        onSubmitted: onSubmit,
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String> onChange;
  final double? width;
  const _SelectBox({required this.value, required this.items, required this.onChange, this.width});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          style: const TextStyle(fontSize: 12, color: _kGrey700),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: _kGrey400),
          onChanged: (v) => onChange(v ?? ''),
          items: items,
        ),
      ),
    );
  }
}

// ── LOCATION CASCADE FILTER ROW ───────────────────────────────────────────────
class _LocationFiltersRow extends StatelessWidget {
  final List<dynamic> regions;
  final List<dynamic> districts;
  final List<dynamic> facilities;
  final List<dynamic> subjects;
  final int?     regionId;
  final int?     districtId;
  final String   facilityId;
  final String   subjectFilter;
  final ValueChanged<int?>    onRegion;
  final ValueChanged<int?>    onDistrict;
  final ValueChanged<String>  onFacility;
  final ValueChanged<String>  onSubject;

  const _LocationFiltersRow({
    required this.regions,
    required this.districts,
    required this.facilities,
    required this.subjects,
    required this.regionId,
    required this.districtId,
    required this.facilityId,
    required this.subjectFilter,
    required this.onRegion,
    required this.onDistrict,
    required this.onFacility,
    required this.onSubject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _locDrop<int?>(
          value: regionId,
          hint: 'Mkoa wote',
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Mkoa wote')),
            ...regions.map((r) => DropdownMenuItem<int?>(
              value: r['id'] is int ? r['id'] : int.tryParse('${r['id']}'),
              child: Text('${r['name'] ?? r['region_name'] ?? r['id']}',
                overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => onRegion(v),
        )),
        const SizedBox(width: 6),
        Expanded(child: _locDrop<int?>(
          value: districtId,
          hint: 'Wilaya zote',
          enabled: regionId != null,
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Wilaya zote')),
            ...districts.map((d) => DropdownMenuItem<int?>(
              value: d['id'] is int ? d['id'] : int.tryParse('${d['id']}'),
              child: Text('${d['name'] ?? d['district_name'] ?? d['id']}',
                overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) => onDistrict(v),
        )),
      ]),
      if (facilities.isNotEmpty || subjects.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(children: [
          if (facilities.isNotEmpty)
            Expanded(child: _locDrop<String>(
              value: facilityId.isEmpty ? '' : facilityId,
              hint: 'Vituo vyote',
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('Vituo vyote')),
                ...facilities.map((f) => DropdownMenuItem<String>(
                  value: '${f['id'] ?? f['facility_id']}',
                  child: Text('${f['name'] ?? f['facility_name'] ?? f['id']}',
                    overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) => onFacility(v ?? ''),
            )),
          if (facilities.isNotEmpty && subjects.isNotEmpty) const SizedBox(width: 6),
          if (subjects.isNotEmpty)
            Expanded(child: _locDrop<String>(
              value: subjectFilter.isEmpty ? '' : subjectFilter,
              hint: 'Masomo yote',
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('Masomo yote')),
                ...subjects.map((s) {
                  final label = s is String ? s : '${s['name'] ?? s}';
                  final val   = s is String ? s : '${s['name'] ?? s}';
                  return DropdownMenuItem<String>(value: val, child: Text(label, overflow: TextOverflow.ellipsis));
                }),
              ],
              onChanged: (v) => onSubject(v ?? ''),
            )),
        ]),
      ],
    ]);
  }

  Widget _locDrop<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF9FAFB),
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          style: TextStyle(fontSize: 12, color: enabled ? _kGrey700 : _kGrey400),
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: enabled ? _kGrey400 : _kGrey300),
          onChanged: enabled ? onChanged : null,
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: _kGrey400)),
          items: items,
        ),
      ),
    );
  }
}

// ── VIEW USER BOTTOM SHEET ────────────────────────────────────────────────────
class _ViewUserSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  const _ViewUserSheet({required this.user, required this.onEdit});
  @override
  State<_ViewUserSheet> createState() => _ViewUserSheetState();
}

class _ViewUserSheetState extends State<_ViewUserSheet> {
  List<dynamic>? _matches;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    final uid = (widget.user['_id'] ?? widget.user['id'] ?? '').toString();
    if (uid.isEmpty) return;
    try {
      final res = await ApiService().get('/admin/users/$uid/matches');
      final data = res.data;
      if (!mounted) return;
      setState(() {
        _matches = (data is Map ? data['matches'] : null) ?? (data is List ? data : []);
      });
    } catch (_) {
      if (mounted) setState(() => _matches = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final st    = (user['current_station'] as Map?) ?? {};
    final dests = (user['desired_destinations'] as List?) ?? [];
    final isAdmin    = user['is_admin'] == true;
    final isVerified = user['is_verified'] == true;
    final phoneAlt   = (user['phone_alt'] ?? '') as String;
    final email      = (user['email'] ?? '') as String;
    final hasPassword = user['has_password'] == true;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.80,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            // Avatar + name
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _kGrey50, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                CircleAvatar(radius: 28, backgroundColor: _kBlue,
                  child: Text((user['full_name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${user['full_name'] ?? ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
                  if (isAdmin) ...[const SizedBox(width: 6), const Icon(Icons.shield_outlined, size: 16, color: _kBlue)],
                ]),
                if (!isAdmin) Text('${user['cadre_display'] ?? user['cadre_code'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: _kGrey500)),
              ]),
            ),
            const SizedBox(height: 12),
            // Info rows
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kGrey100),
              ),
              child: Column(children: [
                _infoRow('Simu', user['phone_primary'] ?? '—', isBlue: true),
                if (phoneAlt.isNotEmpty) _infoRow('WhatsApp', phoneAlt, isBlue: true),
                if (isAdmin && email.isNotEmpty) _infoRow('Barua Pepe', email),
                _infoRow('Idara', user['category'] ?? '—'),
                _infoRow('Mkoa', st['region_name'] ?? '—'),
                _infoRow('Wilaya', st['district_name'] ?? '—'),
                _infoRow('Kituo', st['facility_name'] ?? '—'),
                _infoRow('Hali', user['status'] ?? 'active'),
                _infoRow('Malipo', isVerified ? '✓ Amelipa' : '✗ Hajalipa',
                  color: isVerified ? _kGreenDk : _kRed),
                _infoRowWidget('Password', Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasPassword ? _kGrey100 : _kRed50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(hasPassword ? 'Na Password' : 'Bila Password',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: hasPassword ? _kGrey500 : _kRed)),
                )),
                _infoRow('Admin', isAdmin ? 'Ndiyo' : 'Hapana'),
                if (dests.isNotEmpty)
                  _infoRow('Mikoa Anayotaka',
                    (dests.map((d) => '${d['region_name'] ?? d}')).join(', ')),
              ]),
            ),
            const SizedBox(height: 16),
            // Matches section
            const Text('Mechi / Wanaofanana',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
            const SizedBox(height: 8),
            _buildMatchesList(),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Funga'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Hariri'),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesList() {
    if (_matches == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
          SizedBox(width: 8),
          Text('Inapakia...', style: TextStyle(fontSize: 13, color: _kGrey500)),
        ]),
      );
    }
    if (_matches!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Hakuna mechi', style: TextStyle(fontSize: 13, color: _kGrey400)),
      );
    }
    return Column(
      children: _matches!.map((m) {
        final name    = '${m['full_name'] ?? ''}';
        final cadre   = '${m['cadre_display'] ?? m['cadre_code'] ?? ''}';
        final region  = '${m['region_name'] ?? ''}';
        final score   = (m['score'] ?? 0) as num;
        final online  = m['online'] == true;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kGrey50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kGrey100),
          ),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(radius: 18, backgroundColor: _kBlue,
                child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
              if (online) Positioned(right: 0, bottom: 0,
                child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)))),
            ]),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900), overflow: TextOverflow.ellipsis)),
                if (online) Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: _kGreen50, borderRadius: BorderRadius.circular(999)),
                  child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _kGreenDk)),
                ),
              ]),
              Text('$cadre • $region', style: const TextStyle(fontSize: 11, color: _kGrey500)),
            ])),
            Text('${score.round()}%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kBlue)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _infoRow(String label, String value, {bool isBlue = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kGrey100))),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: _kGrey500, letterSpacing: 0.3))),
        Expanded(child: Text(value,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 13, color: color ?? (isBlue ? _kBlue : _kGrey900),
            fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _infoRowWidget(String label, Widget widget) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kGrey100))),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: _kGrey500, letterSpacing: 0.3))),
        const Spacer(),
        widget,
      ]),
    );
  }
}

// ── EDIT USER DIALOG ─────────────────────────────────────────────────────────
class _EditUserDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<dynamic> regions;
  const _EditUserDialog({required this.user, required this.regions});
  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _phoneAltCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _pwCtrl;

  late String _status;
  late bool _isVerified;
  late bool _isAdmin;
  late String _category;
  String _cadreCode = '';
  int?   _regionId;
  int?   _districtId;
  String _facilityId = '';

  List<dynamic> _cadres    = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  List<dynamic> _subjects  = [];
  Set<String>   _selectedSubjects = {};
  bool _initLoading = true;

  // Desired destinations: list of {regionId, districtId, regionName, districtName}
  List<Map<String, dynamic>> _destinations = [];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl     = TextEditingController(text: '${u['full_name'] ?? ''}');
    _phoneCtrl    = TextEditingController(text: '${u['phone_primary'] ?? ''}');
    _phoneAltCtrl = TextEditingController(text: '${u['phone_alt'] ?? ''}');
    _emailCtrl    = TextEditingController(text: '${u['email'] ?? ''}');
    _pwCtrl       = TextEditingController();
    _status     = (u['status'] ?? 'active') as String;
    _isVerified = u['is_verified'] == true;
    _isAdmin    = u['is_admin'] == true;
    _category   = (u['category'] ?? 'health') as String;
    _cadreCode  = (u['cadre_code'] ?? '') as String;

    final st = (u['current_station'] as Map?) ?? {};
    final rId = st['region_id'];
    final dId = st['district_id'];
    _regionId   = rId is int ? rId : (rId != null ? int.tryParse('$rId') : null);
    _districtId = dId is int ? dId : (dId != null ? int.tryParse('$dId') : null);
    _facilityId = '${st['facility_id'] ?? ''}';
    if (_facilityId == 'null') _facilityId = '';

    // Load desired_destinations
    final dests = (u['desired_destinations'] as List?) ?? [];
    _destinations = dests.map<Map<String, dynamic>>((d) {
      final rid = d['region_id'];
      final did = d['district_id'];
      return {
        'region_id':     rid is int ? rid : int.tryParse('${rid ?? ''}'),
        'district_id':   did is int ? did : int.tryParse('${did ?? ''}'),
        'region_name':   d['region_name'] ?? '',
        'district_name': d['district_name'] ?? '',
        'districts':     <dynamic>[],
      };
    }).toList();

    // Load subjects
    final subs = (u['subjects'] as List?) ?? [];
    _selectedSubjects = subs.map((s) => s is String ? s : '${s['name'] ?? s}').toSet();

    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final r = await ApiService().getCadres(category: _category.isNotEmpty ? _category : null);
      final d = r.data;
      if (mounted) setState(() => _cadres = d is List ? d : ((d as Map)['cadres'] ?? []));
    } catch (_) {}

    try {
      final level = _category == 'education' ? 'Primary' : 'Secondary';
      final r = await ApiService().getSubjects(level: level);
      final d = r.data;
      if (mounted) setState(() => _subjects = d is List ? d : ((d as Map)['subjects'] ?? []));
    } catch (_) {}

    if (_regionId != null) {
      try {
        final r = await ApiService().getDistricts(_regionId!);
        final d = r.data;
        if (mounted) setState(() => _districts = d is List ? d : ((d as Map)['districts'] ?? []));
      } catch (_) {}

      if (_districtId != null) {
        try {
          final r = await ApiService().getFacilities(_districtId!, category: _category.isEmpty ? 'health' : _category);
          final d = r.data;
          if (mounted) setState(() => _facilities = d is List ? d : ((d as Map)['facilities'] ?? []));
        } catch (_) {}
      }
    }

    // Load districts for each existing destination
    for (int i = 0; i < _destinations.length; i++) {
      final rid = _destinations[i]['region_id'] as int?;
      if (rid != null) {
        try {
          final r = await ApiService().getDistricts(rid);
          final d = r.data;
          if (mounted) {
            setState(() {
              _destinations[i]['districts'] = d is List ? d : ((d as Map)['districts'] ?? []);
            });
          }
        } catch (_) {}
      }
    }

    if (mounted) setState(() => _initLoading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneAltCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegion(int? id) async {
    setState(() { _regionId = id; _districtId = null; _facilityId = ''; _districts = []; _facilities = []; });
    if (id == null) return;
    try {
      final r = await ApiService().getDistricts(id);
      final d = r.data;
      if (mounted) setState(() => _districts = d is List ? d : ((d as Map)['districts'] ?? []));
    } catch (_) {}
  }

  Future<void> _onDistrict(int? id) async {
    setState(() { _districtId = id; _facilityId = ''; _facilities = []; });
    if (id == null) return;
    try {
      final r = await ApiService().getFacilities(id, category: _category.isEmpty ? 'health' : _category);
      final d = r.data;
      if (mounted) setState(() => _facilities = d is List ? d : ((d as Map)['facilities'] ?? []));
    } catch (_) {}
  }

  Future<void> _onDestRegion(int index, int? id) async {
    setState(() {
      _destinations[index]['region_id'] = id;
      _destinations[index]['district_id'] = null;
      _destinations[index]['districts'] = <dynamic>[];
    });
    if (id == null) return;
    try {
      final r = await ApiService().getDistricts(id);
      final d = r.data;
      if (mounted) setState(() => _destinations[index]['districts'] = d is List ? d : ((d as Map)['districts'] ?? []));
    } catch (_) {}
  }

  // Check if selected cadre has a level (for subject picker)
  bool get _showSubjects {
    if (_cadreCode.isEmpty || _cadres.isEmpty) return false;
    final cadre = _cadres.firstWhere((c) => '${c['code']}' == _cadreCode, orElse: () => null);
    if (cadre == null) return false;
    final level = (cadre['level'] ?? '') as String;
    return level.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hariri Mtumiaji',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
          const SizedBox(height: 16),

          _fld('Jina Kamili', _nameCtrl),
          const SizedBox(height: 10),
          _fld('Namba ya Simu', _phoneCtrl, keyboard: TextInputType.phone),
          const SizedBox(height: 10),
          _fld('WhatsApp (phone_alt)', _phoneAltCtrl, keyboard: TextInputType.phone),
          const SizedBox(height: 10),
          if (_isAdmin) ...[
            _fld('Barua Pepe (email)', _emailCtrl, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
          ],
          _fld('Nywila Mpya (acha tupu kubaki ile ile)', _pwCtrl, obscure: true),
          const SizedBox(height: 10),

          // Status
          _lbl('Hali'),
          const SizedBox(height: 4),
          _drop<String>(
            value: _status,
            items: const [
              DropdownMenuItem(value: 'active',   child: Text('Hai', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'inactive', child: Text('Haifanyi kazi', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'disabled', child: Text('Imesimamishwa', style: TextStyle(fontSize: 13))),
            ],
            onChange: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 10),

          // Checkboxes
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _isVerified = !_isVerified),
              child: Row(children: [
                SizedBox(width: 18, height: 18,
                  child: Checkbox(
                    value: _isVerified,
                    onChanged: (v) => setState(() => _isVerified = v!),
                    activeColor: _kBlue,
                  )),
                const SizedBox(width: 6),
                const Expanded(child: Text('Amethibitishwa', style: TextStyle(fontSize: 12))),
              ]),
            )),
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _isAdmin = !_isAdmin),
              child: Row(children: [
                SizedBox(width: 18, height: 18,
                  child: Checkbox(
                    value: _isAdmin,
                    onChanged: (v) => setState(() => _isAdmin = v!),
                    activeColor: _kBlue,
                  )),
                const SizedBox(width: 6),
                const Expanded(child: Text('Admin', style: TextStyle(fontSize: 12))),
              ]),
            )),
          ]),
          const SizedBox(height: 16),

          // Loading spinner while fetching cadres / station data
          if (_initLoading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
            ))
          else ...[
            // Cadre
            if (_cadres.isNotEmpty) ...[
              _lbl('Kada'),
              const SizedBox(height: 4),
              _drop<String>(
                value: _cadres.any((c) => '${c['code']}' == _cadreCode) ? _cadreCode : '',
                hint: 'Chagua Kada',
                items: [
                  const DropdownMenuItem(value: '', child: Text('— Bila mabadiliko —', style: TextStyle(fontSize: 12, color: _kGrey400))),
                  ..._cadres.map((c) => DropdownMenuItem<String>(
                    value: '${c['code']}',
                    child: Text('${c['name'] ?? c['code']}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChange: (v) => setState(() => _cadreCode = v),
              ),
              const SizedBox(height: 10),
            ],

            // Subjects picker (only if cadre has level)
            if (_showSubjects && _subjects.isNotEmpty) ...[
              _lbl('Masomo'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _subjects.map((s) {
                  final name = s is String ? s : '${s['name'] ?? s}';
                  final selected = _selectedSubjects.contains(name);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) { _selectedSubjects.remove(name); }
                      else { _selectedSubjects.add(name); }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? _kGold : Colors.white,
                        border: Border.all(color: selected ? _kGold : _kGrey300),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(name, style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _kGrey500)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Station: Region
            _lbl('Kituo — Mkoa'),
            const SizedBox(height: 4),
            _locDrop<int?>(
              value: _regionId,
              hint: 'Chagua Mkoa',
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('— Chagua Mkoa —')),
                ...widget.regions.map((r) {
                  final id = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}');
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text('${r['name'] ?? r['region_name'] ?? r['id']}',
                      style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  );
                }),
              ],
              onChanged: _onRegion,
            ),

            // District (shown after region selected)
            if (_regionId != null && _districts.isNotEmpty) ...[
              const SizedBox(height: 6),
              _lbl('Wilaya'),
              const SizedBox(height: 4),
              _locDrop<int?>(
                value: _districtId,
                hint: 'Chagua Wilaya',
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('— Chagua Wilaya —')),
                  ..._districts.map((d) {
                    final id = d['id'] is int ? d['id'] as int : int.tryParse('${d['id']}');
                    return DropdownMenuItem<int?>(
                      value: id,
                      child: Text('${d['name'] ?? d['district_name'] ?? d['id']}',
                        style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: _onDistrict,
              ),
            ],

            // Facility (shown after district selected)
            if (_districtId != null && _facilities.isNotEmpty) ...[
              const SizedBox(height: 6),
              _lbl('Kituo'),
              const SizedBox(height: 4),
              _locDrop<String>(
                value: _facilityId.isEmpty ? '' : _facilityId,
                hint: 'Chagua Kituo',
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('— Chagua Kituo —')),
                  ..._facilities.map((f) {
                    final id = '${f['id'] ?? f['facility_id']}';
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text('${f['name'] ?? f['facility_name'] ?? id}',
                        style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) { if (v != null) setState(() => _facilityId = v); },
              ),
            ],

            // Desired destinations section
            const SizedBox(height: 16),
            _lbl('Mikoa Anayotaka'),
            const SizedBox(height: 6),
            ..._destinations.asMap().entries.map((entry) {
              final i = entry.key;
              final dest = entry.value;
              final destDistList = dest['districts'] as List<dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: _locDrop<int?>(
                    value: dest['region_id'] as int?,
                    hint: 'Mkoa',
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— Mkoa —')),
                      ...widget.regions.map((r) {
                        final id = r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}');
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text('${r['name'] ?? r['region_name'] ?? r['id']}',
                            style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => _onDestRegion(i, v),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _locDrop<int?>(
                    value: dest['district_id'] as int?,
                    hint: 'Wilaya',
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— Wilaya —')),
                      ...destDistList.map((d) {
                        final id = d['id'] is int ? d['id'] as int : int.tryParse('${d['id']}');
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text('${d['name'] ?? d['district_name'] ?? d['id']}',
                            style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _destinations[i]['district_id'] = v),
                  )),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _destinations.removeAt(i)),
                    child: const Icon(Icons.close, size: 18, color: _kGrey400),
                  ),
                ]),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _destinations.add({'region_id': null, 'district_id': null, 'districts': <dynamic>[]})),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Ongeza Mkoa', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kBlue),
            ),
          ],

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ghairi'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
              onPressed: () {
                final changes = <String, dynamic>{
                  'full_name':    _nameCtrl.text.trim(),
                  if (_phoneCtrl.text.isNotEmpty)    'phone_primary': _phoneCtrl.text.trim(),
                  if (_phoneAltCtrl.text.isNotEmpty) 'phone_alt': _phoneAltCtrl.text.trim(),
                  if (_isAdmin && _emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
                  'status':       _status,
                  'is_verified':  _isVerified,
                  'is_admin':     _isAdmin,
                  if (_pwCtrl.text.isNotEmpty)    'new_password': _pwCtrl.text,
                  if (_cadreCode.isNotEmpty)       'cadre_code': _cadreCode,
                  if (_selectedSubjects.isNotEmpty) 'subjects': _selectedSubjects.toList(),
                  if (_regionId != null)           'region_id': _regionId,
                  if (_districtId != null)         'district_id': _districtId,
                  if (_facilityId.isNotEmpty)      'facility_id': _facilityId,
                  'desired_destinations': _destinations
                    .where((d) => d['region_id'] != null)
                    .map((d) => {
                      'region_id': d['region_id'],
                      if (d['district_id'] != null) 'district_id': d['district_id'],
                    }).toList(),
                };
                Navigator.pop(context, changes);
              },
              child: const Text('Hifadhi'),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _lbl(String t) => Text(t,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kGrey500));

  Widget _fld(String label, TextEditingController ctrl, {TextInputType? keyboard, bool obscure = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        obscureText: obscure,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 2)),
        ),
      ),
    ]);
  }

  Widget _drop<T>({required T value, required List<DropdownMenuItem<T>> items,
      required ValueChanged<T> onChange, String? hint}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint != null ? Text(hint, style: const TextStyle(fontSize: 12, color: _kGrey400)) : null,
          style: const TextStyle(fontSize: 13, color: _kGrey700),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kGrey400),
          onChanged: (v) { if (v != null) onChange(v); },
          items: items,
        ),
      ),
    );
  }

  Widget _locDrop<T>({required T value, required String hint,
      required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: _kGrey400)),
          style: const TextStyle(fontSize: 12, color: _kGrey700),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: _kGrey400),
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}

// ── CREATE USER DIALOG ────────────────────────────────────────────────────────
// ── CREATE USER BOTTOM SHEET ──────────────────────────────────────────────────
class _CreateUserSheet extends StatefulWidget {
  final List<dynamic> regions;
  final void Function(Map<String, dynamic> created) onCreated;
  const _CreateUserSheet({required this.regions, required this.onCreated});
  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _nameCtrl     = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _phoneAltCtrl = TextEditingController();
  final _pwCtrl       = TextEditingController(text: 'changeme123');

  String _category = 'health';
  String _cadreCode = '';
  String _status   = 'active';
  bool   _isAdmin  = false;
  String _sector   = 'tamisemi';

  int?   _regionId;
  String _regionName = '';
  int?   _districtId;
  String _districtName = '';
  String _facilityId = '';
  String _facilityName = '';

  List<dynamic> _cadres    = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  List<dynamic> _subjects  = [];
  final Set<String>   _selectedSubjects = {};
  final List<Map<String, dynamic>> _destinations = [];

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCadres();
    _loadSubjects();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _phoneAltCtrl.dispose(); _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCadres() async {
    try {
      final r = await ApiService().getCadres(category: _category.isNotEmpty ? _category : null);
      final d = r.data;
      if (mounted) setState(() => _cadres = d is List ? d : ((d as Map)['cadres'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    try {
      final level = _category == 'education' ? 'Primary' : 'Secondary';
      final r = await ApiService().getSubjects(level: level);
      final d = r.data;
      if (mounted) setState(() => _subjects = d is List ? d : ((d as Map)['subjects'] ?? []));
    } catch (_) {}
  }

  Future<void> _onRegion(int? id, String name) async {
    setState(() {
      _regionId = id; _regionName = name;
      _districtId = null; _districtName = ''; _facilityId = ''; _facilityName = '';
      _districts = []; _facilities = [];
    });
    if (id == null) return;
    try {
      final r = await ApiService().getDistricts(id);
      final d = r.data;
      if (mounted) setState(() => _districts = d is List ? d : ((d as Map)['districts'] ?? []));
    } catch (_) {}
  }

  Future<void> _onDistrict(int? id, String name) async {
    setState(() { _districtId = id; _districtName = name; _facilityId = ''; _facilityName = ''; _facilities = []; });
    if (id == null) return;
    try {
      final r = await ApiService().getFacilities(id, category: _category.isEmpty ? 'health' : _category);
      final d = r.data;
      if (mounted) setState(() => _facilities = d is List ? d : ((d as Map)['facilities'] ?? []));
    } catch (_) {}
  }

  Future<void> _onDestRegion(int index, int? id, String name) async {
    setState(() {
      _destinations[index]['region_id'] = id;
      _destinations[index]['region_name'] = name;
      _destinations[index]['district_id'] = null;
      _destinations[index]['district_name'] = '';
      _destinations[index]['districts'] = <dynamic>[];
    });
    if (id == null) return;
    try {
      final r = await ApiService().getDistricts(id);
      final d = r.data;
      if (mounted) setState(() => _destinations[index]['districts'] = d is List ? d : ((d as Map)['districts'] ?? []));
    } catch (_) {}
  }

  bool get _showSubjects {
    if (_cadreCode.isEmpty || _cadres.isEmpty) return false;
    final cadre = _cadres.firstWhere((c) => '${c['code']}' == _cadreCode, orElse: () => null);
    if (cadre == null) return false;
    return ((cadre['level'] ?? '') as String).isNotEmpty;
  }

  String _cadreLabel(String code) {
    if (code.isEmpty) return '';
    final c = _cadres.firstWhere((c) => '${c['code']}' == code, orElse: () => null);
    return c != null ? '${c['name'] ?? code}' : code;
  }

  Widget _lbl(String t) => Text(t,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
      color: _kGrey500, letterSpacing: 0.3));

  InputDecoration _inp(String hint, {IconData? icon}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
    prefixIcon: icon != null ? Icon(icon, size: 17, color: _kGrey400) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
  );

  Widget _field(String label, TextEditingController ctrl, {TextInputType? keyboard, bool obscure = false, IconData? icon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label),
      const SizedBox(height: 5),
      TextField(controller: ctrl, keyboardType: keyboard, obscureText: obscure,
        style: const TextStyle(fontSize: 14, color: _kGrey900),
        autocorrect: false, enableSuggestions: false,
        decoration: _inp('', icon: icon)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final regionItems = [
      (value: 0, label: '— Chagua Mkoa —', subtitle: null as String?),
      ...widget.regions.map((r) {
        final id = r['id'] is int ? r['id'] as int : (int.tryParse('${r['id']}') ?? 0);
        return (value: id, label: '${r['name'] ?? r['region_name'] ?? r['id']}', subtitle: null as String?);
      }),
    ];
    final districtItems = [
      (value: 0, label: '— Chagua Wilaya —', subtitle: null as String?),
      ..._districts.map((d) {
        final id = d['id'] is int ? d['id'] as int : (int.tryParse('${d['id']}') ?? 0);
        return (value: id, label: '${d['name'] ?? d['district_name'] ?? d['id']}', subtitle: null as String?);
      }),
    ];
    final facilityItems = [
      (value: '', label: '— Chagua Kituo —', subtitle: null as String?),
      ..._facilities.map((f) {
        final id = '${f['id'] ?? f['facility_id']}';
        return (value: id, label: '${f['name'] ?? f['facility_name'] ?? id}', subtitle: null as String?);
      }),
    ];
    final cadreItems = [
      (value: '', label: '— Chagua Kada —', subtitle: null as String?),
      ..._cadres.map((c) => (value: '${c['code']}', label: '${c['name'] ?? c['code']}', subtitle: null as String?)),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Row(children: [
              const Icon(Icons.person_add_outlined, size: 20, color: _kBlue),
              const SizedBox(width: 10),
              const Expanded(child: Text('Ongeza Mtumiaji',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kGrey900))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close, size: 16, color: _kGrey500)),
              ),
            ])),
          const Divider(height: 1),
          // Form
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _kRed50, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA))),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 16, color: _kRed),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: _kRed))),
                  ]),
                ),
                const SizedBox(height: 14),
              ],

              // ── Personal info section ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _kGrey50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGrey100)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Maelezo ya Mtumiaji',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey500, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _field('Jina Kamili *', _nameCtrl, icon: Icons.person_outline),
                  const SizedBox(height: 10),
                  _field('Namba ya Simu *', _phoneCtrl, keyboard: TextInputType.phone, icon: Icons.phone_outlined),
                  const SizedBox(height: 10),
                  _field('WhatsApp (optional)', _phoneAltCtrl, keyboard: TextInputType.phone, icon: Icons.message_outlined),
                  const SizedBox(height: 10),
                  _field('Nywila *', _pwCtrl, obscure: true, icon: Icons.lock_outlined),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Category + Sector ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _kGrey50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGrey100)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sekta na Kada',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey500, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _lbl('Idara'),
                      const SizedBox(height: 5),
                      SelectField(
                        hint: 'Chagua Idara',
                        value: _category == 'health' ? 'Afya' : 'Elimu',
                        onTap: () async {
                          final v = await showSelectSheet<String>(context,
                            title: 'Chagua Idara',
                            items: const [
                              (value: 'health', label: 'Afya', subtitle: 'Health Sector' as String?),
                              (value: 'education', label: 'Elimu', subtitle: 'Education Sector' as String?),
                            ],
                            selected: _category);
                          if (v != null && v != _category) {
                            setState(() { _category = v; _cadreCode = ''; _cadres = []; });
                            _loadCadres(); _loadSubjects();
                          }
                        },
                      ),
                    ])),
                    if (_category == 'health') ...[
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _lbl('Sekta'),
                        const SizedBox(height: 5),
                        SelectField(
                          hint: 'Chagua Sekta',
                          value: _sector == 'tamisemi' ? 'TAMISEMI' : 'Wizara ya Afya',
                          onTap: () async {
                            final v = await showSelectSheet<String>(context,
                              title: 'Chagua Sekta',
                              items: const [
                                (value: 'tamisemi', label: 'TAMISEMI', subtitle: null as String?),
                                (value: 'wizara_afya', label: 'Wizara ya Afya', subtitle: null as String?),
                              ],
                              selected: _sector);
                            if (v != null) setState(() => _sector = v);
                          },
                        ),
                      ])),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  _lbl('Kada'),
                  const SizedBox(height: 5),
                  SelectField(
                    hint: 'Chagua Kada',
                    value: _cadreLabel(_cadreCode).isEmpty ? null : _cadreLabel(_cadreCode),
                    disabled: _cadres.isEmpty,
                    onTap: _cadres.isEmpty ? null : () async {
                      final v = await showSelectSheet<String>(context,
                        title: 'Chagua Kada', items: cadreItems,
                        selected: _cadreCode, searchable: true);
                      if (v != null) setState(() => _cadreCode = v == '' ? '' : v);
                    },
                  ),
                  // Subjects
                  if (_showSubjects && _subjects.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _lbl('Masomo'),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6,
                      children: _subjects.map((s) {
                        final name = s is String ? s : '${s['name'] ?? s}';
                        final sel = _selectedSubjects.contains(name);
                        return GestureDetector(
                          onTap: () => setState(() { sel ? _selectedSubjects.remove(name) : _selectedSubjects.add(name); }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? _kGold : Colors.white,
                              border: Border.all(color: sel ? _kGold : _kGrey300),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _kGrey500)),
                          ),
                        );
                      }).toList()),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _lbl('Hali'),
                      const SizedBox(height: 5),
                      SelectField(
                        hint: 'Hali',
                        value: _status == 'active' ? 'Hai' : _status == 'inactive' ? 'Haifanyi kazi' : 'Imesimamishwa',
                        onTap: () async {
                          final v = await showSelectSheet<String>(context,
                            title: 'Chagua Hali',
                            items: const [
                              (value: 'active', label: 'Hai', subtitle: null as String?),
                              (value: 'inactive', label: 'Haifanyi kazi', subtitle: null as String?),
                              (value: 'disabled', label: 'Imesimamishwa', subtitle: null as String?),
                            ],
                            selected: _status);
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                    ])),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => _isAdmin = !_isAdmin),
                      child: Container(
                        height: 43,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _isAdmin ? _kBlue50 : Colors.white,
                          border: Border.all(color: _isAdmin ? _kBlue : _kGrey200),
                          borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          Icon(_isAdmin ? Icons.shield : Icons.shield_outlined, size: 16,
                            color: _isAdmin ? _kBlue : _kGrey400),
                          const SizedBox(width: 6),
                          Text('Admin', style: TextStyle(fontSize: 13,
                            color: _isAdmin ? _kBlue : _kGrey500,
                            fontWeight: _isAdmin ? FontWeight.w600 : FontWeight.normal)),
                        ]),
                      ),
                    )),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),

              // ── Station ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _kGrey50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGrey100)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kituo cha Sasa',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey500, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  _lbl('Mkoa'),
                  const SizedBox(height: 5),
                  SelectField(
                    hint: 'Chagua Mkoa',
                    value: _regionName.isEmpty ? null : _regionName,
                    onTap: () async {
                      final v = await showSelectSheet<int>(context,
                        title: 'Chagua Mkoa', items: regionItems,
                        selected: _regionId ?? 0, searchable: true);
                      if (v != null) {
                        final name = v == 0 ? '' : '${widget.regions.firstWhere((r) {
                          final id = r['id'] is int ? r['id'] as int : (int.tryParse('${r['id']}') ?? 0);
                          return id == v;
                        }, orElse: () => {'name': ''})['name']}';
                        _onRegion(v == 0 ? null : v, name);
                      }
                    },
                  ),
                  if (_regionId != null && _districts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _lbl('Wilaya'),
                    const SizedBox(height: 5),
                    SelectField(
                      hint: 'Chagua Wilaya',
                      value: _districtName.isEmpty ? null : _districtName,
                      onTap: () async {
                        final v = await showSelectSheet<int>(context,
                          title: 'Chagua Wilaya', items: districtItems,
                          selected: _districtId ?? 0, searchable: true);
                        if (v != null) {
                          final name = v == 0 ? '' : '${_districts.firstWhere((d) {
                            final id = d['id'] is int ? d['id'] as int : (int.tryParse('${d['id']}') ?? 0);
                            return id == v;
                          }, orElse: () => {'name': ''})['name']}';
                          _onDistrict(v == 0 ? null : v, name);
                        }
                      },
                    ),
                  ],
                  if (_districtId != null && _facilities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _lbl('Kituo'),
                    const SizedBox(height: 5),
                    SelectField(
                      hint: 'Chagua Kituo',
                      value: _facilityName.isEmpty ? null : _facilityName,
                      onTap: () async {
                        final v = await showSelectSheet<String>(context,
                          title: 'Chagua Kituo', items: facilityItems,
                          selected: _facilityId, searchable: true);
                        if (v != null) {
                          final name = v.isEmpty ? '' : '${_facilities.firstWhere((f) {
                            final id = '${f['id'] ?? f['facility_id']}';
                            return id == v;
                          }, orElse: () => {'name': ''})['name']}';
                          setState(() { _facilityId = v; _facilityName = name; });
                        }
                      },
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),

              // ── Destinations ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _kGrey50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kGrey100)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Mikoa Anayotaka Kwenda',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey500, letterSpacing: 0.5))),
                    GestureDetector(
                      onTap: () => setState(() => _destinations.add({'region_id': null, 'region_name': '', 'district_id': null, 'district_name': '', 'districts': <dynamic>[]})),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(999)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Ongeza', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ]),
                  if (_destinations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Bonyeza "Ongeza" kuongeza mkoa wa lengo',
                        style: TextStyle(fontSize: 12, color: _kGrey400)),
                    )
                  else ...[
                    const SizedBox(height: 10),
                    ..._destinations.asMap().entries.map((entry) {
                      final i = entry.key;
                      final dest = entry.value;
                      final dests = dest['districts'] as List<dynamic>;
                      final destDistItems = [
                        (value: 0, label: '— Wilaya —', subtitle: null as String?),
                        ...dests.map((d) {
                          final id = d['id'] is int ? d['id'] as int : (int.tryParse('${d['id']}') ?? 0);
                          return (value: id, label: '${d['name'] ?? d['district_name'] ?? d['id']}', subtitle: null as String?);
                        }),
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(
                            width: 24, height: 24, margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: _kBlue50, shape: BoxShape.circle),
                            child: Center(child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kBlue))),
                          ),
                          Expanded(child: SelectField(
                            hint: 'Mkoa',
                            value: (dest['region_name'] as String?)?.isNotEmpty == true ? dest['region_name'] as String : null,
                            onTap: () async {
                              final v = await showSelectSheet<int>(context,
                                title: 'Mkoa wa Lengo', items: regionItems,
                                selected: (dest['region_id'] as int?) ?? 0, searchable: true);
                              if (v != null) {
                                final name = v == 0 ? '' : '${widget.regions.firstWhere((r) {
                                  final id = r['id'] is int ? r['id'] as int : (int.tryParse('${r['id']}') ?? 0);
                                  return id == v;
                                }, orElse: () => {'name': ''})['name']}';
                                _onDestRegion(i, v == 0 ? null : v, name);
                              }
                            },
                          )),
                          if (dests.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Expanded(child: SelectField(
                              hint: 'Wilaya',
                              value: (dest['district_name'] as String?)?.isNotEmpty == true ? dest['district_name'] as String : null,
                              onTap: () async {
                                final v = await showSelectSheet<int>(context,
                                  title: 'Wilaya ya Lengo', items: destDistItems,
                                  selected: (dest['district_id'] as int?) ?? 0, searchable: true);
                                if (v != null) {
                                  final name = v == 0 ? '' : '${dests.firstWhere((d) {
                                    final id = d['id'] is int ? d['id'] as int : (int.tryParse('${d['id']}') ?? 0);
                                    return id == v;
                                  }, orElse: () => {'name': ''})['name']}';
                                  setState(() {
                                    _destinations[i]['district_id'] = v == 0 ? null : v;
                                    _destinations[i]['district_name'] = name;
                                  });
                                }
                              },
                            )),
                          ],
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _destinations.removeAt(i)),
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: _kRed50, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.close, size: 14, color: _kRed)),
                          ),
                        ]),
                      );
                    }),
                  ],
                ]),
              ),
              const SizedBox(height: 20),

              // ── Save button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    disabledBackgroundColor: _kBlue.withValues(alpha: 0.6),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _saving ? null : () async {
                    final name  = _nameCtrl.text.trim();
                    final phone = _phoneCtrl.text.trim();
                    final pw    = _pwCtrl.text;
                    if (name.isEmpty || phone.isEmpty || pw.isEmpty) {
                      setState(() => _error = 'Jaza sehemu zote zinazohitajika (*)');
                      return;
                    }
                    setState(() { _saving = true; _error = null; });
                    try {
                      final res = await ApiService().adminCreateUser({
                        'full_name': name, 'phone_primary': phone,
                        if (_phoneAltCtrl.text.isNotEmpty) 'phone_alt': _phoneAltCtrl.text.trim(),
                        'password': pw, 'category': _category,
                        'status': _status, 'is_admin': _isAdmin,
                        if (_cadreCode.isNotEmpty)           'cadre_code': _cadreCode,
                        if (_selectedSubjects.isNotEmpty)    'subjects': _selectedSubjects.toList(),
                        if (_category == 'health')           'employment_sector': _sector,
                        if (_regionId != null)               'region_id': _regionId,
                        if (_districtId != null)             'district_id': _districtId,
                        if (_facilityId.isNotEmpty)          'facility_id': _facilityId,
                        'desired_destinations': _destinations
                          .where((d) => d['region_id'] != null)
                          .map((d) => {
                            'region_id': d['region_id'],
                            if (d['district_id'] != null) 'district_id': d['district_id'],
                          }).toList(),
                      });
                      final created = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
                      if (!mounted) return;
                      widget.onCreated(created);
                      if (mounted) Navigator.pop(context); // ignore: use_build_context_synchronously
                    } catch (e) {
                      setState(() { _saving = false; _error = 'Hitilafu: $e'; });
                    }
                  },
                  child: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.person_add_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Ongeza Mtumiaji'),
                      ]),
                ),
              ),
            ],
          )),
        ]),
      ),
    );
  }
}
