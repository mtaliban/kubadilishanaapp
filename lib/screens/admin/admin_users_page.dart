import 'dart:async';
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
  Set<String> _selected = {};
  bool _selectAll = false;

  final _searchCtrl = TextEditingController();
  String _category = '';
  String? _regionId;
  String? _regionName;
  String? _districtId;
  String? _districtName;
  String? _subject;

  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _subjects = [];
  List<dynamic> _cadres = [];
  bool _refsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRefs();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRefs() async {
    try {
      final results = await Future.wait([
        ApiService().getRegions(),
        ApiService().getSubjects(),
        ApiService().getCadres(),
      ]);
      if (!mounted) return;
      setState(() {
        final rd = results[0].data;
        _regions = rd is List ? rd : (rd['results'] as List? ?? []);
        final sd = results[1].data;
        _subjects = sd is List ? sd : (sd['results'] as List? ?? []);
        final cd = results[2].data;
        _cadres = cd is List ? cd : (cd['results'] as List? ?? []);
        _refsLoaded = true;
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

  Timer? _debounce;

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{};
      if (_searchCtrl.text.isNotEmpty) params['q'] = _searchCtrl.text;
      if (_category.isNotEmpty) params['category'] = _category;
      if (_regionId != null) params['region'] = _regionId;
      if (_districtId != null) params['district'] = _districtId;
      if (_subject != null) params['subject'] = _subject;
      final res = await ApiService().adminUsers(params: params, useCache: false);
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _users = data is List ? data : (data['results'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selected.clear();
        _selectAll = false;
      } else {
        _selected = _users.map((u) => (u as Map)['user_id']?.toString() ?? '').toSet();
        _selectAll = true;
      }
    });
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Watumiaji'),
        content: Text('Futa watumiaji ${_selected.length} waliochaguliwa?'),
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
    for (final id in _selected) {
      try { await ApiService().adminDeleteUser(id); } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _selected.clear(); _selectAll = false; });
    _load();
  }

  void _showDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UserDetailSheet(user: user),
    );
  }

  void _showEdit(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UserEditSheet(
        user: user,
        cadres: _cadres,
        subjects: _subjects,
        onSaved: _load,
      ),
    );
  }

  void _showAddAdmin() {
    showDialog(
      context: context,
      builder: (ctx) => _AddAdminDialog(onAdded: _load),
    );
  }

  void _showAddUser() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddUserSheet(
        regions: _regions,
        cadres: _cadres,
        subjects: _subjects,
        onAdded: _load,
      ),
    );
  }

  Future<void> _deleteUser(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Mtumiaji'),
        content: const Text('Una uhakika unataka kufuta mtumiaji huyu?'),
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
      await ApiService().adminDeleteUser(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  void _pickCategory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CategoryPicker(
        current: _category,
        onPicked: (v) {
          setState(() { _category = v; });
          _load();
        },
      ),
    );
  }

  void _pickRegion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _RegionPicker(
        regions: _regions,
        currentId: _regionId,
        onPicked: (id, name) {
          setState(() {
            _regionId = id;
            _regionName = name;
            _districtId = null;
            _districtName = null;
            _districts = [];
          });
          if (id != null) _loadDistricts(id);
          _load();
        },
      ),
    );
  }

  void _pickDistrict() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DistrictPicker(
        districts: _districts,
        currentId: _districtId,
        onPicked: (id, name) {
          setState(() { _districtId = id; _districtName = name; });
          _load();
        },
      ),
    );
  }

  void _pickSubject() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SubjectPicker(
        subjects: _subjects,
        currentCode: _subject,
        onPicked: (code) {
          setState(() { _subject = code; });
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header container
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.group_rounded, color: _kBlue, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Watumiaji',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _kGreenBg, borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 6, height: 6,
                                      decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
                                  const SizedBox(width: 3),
                                  Text('LIVE', style: TextStyle(fontSize: 9, color: _kGreen, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text('${_users.length} watumiaji wote',
                            style: TextStyle(fontSize: 12, color: _kGrey500)),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddUser,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Ongeza', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _IconBtn(
                      icon: Icons.delete_outline,
                      color: _selected.isEmpty ? _kGrey400 : _kRed,
                      bg: _selected.isEmpty ? _kGrey100 : _kRedBg,
                      onTap: _selected.isEmpty ? null : _bulkDelete,
                      border: _selected.isEmpty ? _kGrey200 : _kRed,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _showAddAdmin,
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
                      label: const Text('Admin', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kBlue,
                        side: const BorderSide(color: _kBlue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.upload_file_outlined, size: 14),
                      label: const Text('Import', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGrey700,
                        side: const BorderSide(color: _kGrey200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _toggleSelectAll,
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectAll,
                        onChanged: (_) => _toggleSelectAll(),
                        activeColor: _kBlue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text('Chagua zote (${_users.length})',
                          style: TextStyle(fontSize: 13, color: _kGrey700)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Tafuta kwa jina, simu au...',
                    prefixIcon: const Icon(Icons.search, color: _kGrey500, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _FilterDropBtn(
                      label: _category.isEmpty ? 'Idara zote' : (_category == 'health' ? 'Afya' : 'Elimu'),
                      onTap: _pickCategory,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterDropBtn(
                      label: _regionName ?? 'Mkoa',
                      onTap: _pickRegion,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _FilterDropBtn(
                      label: _districtName ?? 'Wilaya zote',
                      onTap: _pickDistrict,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterDropBtn(
                      label: _subject ?? 'Masomo yote',
                      onTap: _pickSubject,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Jumla: ${_users.length}',
                      style: TextStyle(fontSize: 12, color: _kGrey500)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kGrey200),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: _kRed, size: 48),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
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
          else if (_users.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, color: _kGrey500, size: 48),
                    const SizedBox(height: 12),
                    Text('Hakuna watumiaji', style: TextStyle(color: _kGrey500)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final user = _users[i] as Map<String, dynamic>;
                    final uid = user['user_id']?.toString() ?? '';
                    return _UserCard(
                      user: user,
                      selected: _selected.contains(uid),
                      onToggleSelect: () {
                        setState(() {
                          if (_selected.contains(uid)) {
                            _selected.remove(uid);
                          } else {
                            _selected.add(uid);
                          }
                          _selectAll = _selected.length == _users.length;
                        });
                      },
                      onDetail: () => _showDetail(user),
                      onEdit: () => _showEdit(user),
                      onDelete: () => _deleteUser(uid),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterDropBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FilterDropBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label,
                style: TextStyle(fontSize: 12, color: _kGrey700),
                overflow: TextOverflow.ellipsis)),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: _kGrey500),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final Color border;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.color, required this.bg, required this.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.selected,
    required this.onToggleSelect,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final category = user['category'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ?? user['cadre_name'] as String? ?? '';
    final region = (user['current_station'] as Map?)?['region'] as String? ?? user['region'] as String? ?? '';
    final isActive = user['is_active'] as bool? ?? true;
    final isPaid = user['is_paid'] as bool? ?? false;
    final isAdmin = user['is_admin'] as bool? ?? false;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final catColor = category.toLowerCase().contains('health') || category.toLowerCase() == 'afya' ? _kRed : _kGreen;
    final catBg = category.toLowerCase().contains('health') || category.toLowerCase() == 'afya'
        ? _kRedBg : _kGreenBg;
    final index = (user['_index'] as int?) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: selected ? _kBlue : _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (_) => onToggleSelect(),
                  activeColor: _kBlue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _kGreenBg,
                  child: Text(initials,
                      style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                      if (phone.isNotEmpty)
                        Text(phone, style: TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: [
                          if (category.isNotEmpty)
                            _Badge(label: category, color: catColor, bg: catBg),
                          if (cadre.isNotEmpty)
                            _Badge(label: cadre, color: _kGreen, bg: _kGreenBg),
                          if (isAdmin)
                            _Badge(label: 'Admin', color: _kBlue, bg: _kBlueBg),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (region.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 12, color: _kGrey500),
                            const SizedBox(width: 3),
                            Text(region, style: TextStyle(fontSize: 11, color: _kGrey500)),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Badge(
                            label: isActive ? 'Hai' : 'Amesitishwa',
                            color: isActive ? _kGreen : _kAmber,
                            bg: isActive ? _kGreenBg : _kAmberBg,
                          ),
                          const SizedBox(width: 6),
                          _Badge(
                            label: isPaid ? 'Amelipa' : 'Hajalipa',
                            color: isPaid ? _kGreen : _kRed,
                            bg: isPaid ? _kGreenBg : _kRedBg,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kGrey200),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _ActionBtn(icon: Icons.open_in_new, color: _kBlue, onTap: onDetail),
                const SizedBox(width: 6),
                _ActionBtn(icon: Icons.edit_outlined, color: _kGrey700, onTap: onEdit),
                const Spacer(),
                _ActionBtn(icon: Icons.block_outlined, color: _kAmber, onTap: () {}),
                const SizedBox(width: 6),
                _ActionBtn(icon: Icons.phone_outlined, color: _kGreen, onTap: () {}),
                const SizedBox(width: 6),
                _ActionBtn(icon: Icons.delete_outline, color: _kRed, onTap: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

// ── PICKERS ──

class _CategoryPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onPicked;
  const _CategoryPicker({required this.current, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Chagua idara',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          _PickerItem(
            icon: Icons.apps_outlined,
            iconColor: _kBlue,
            iconBg: _kBlueBg,
            label: 'Zote',
            selected: current.isEmpty,
            onTap: () { Navigator.pop(context); onPicked(''); },
          ),
          _PickerItem(
            icon: Icons.medical_services_outlined,
            iconColor: _kRed,
            iconBg: _kRedBg,
            label: 'Afya',
            selected: current == 'health',
            onTap: () { Navigator.pop(context); onPicked('health'); },
          ),
          _PickerItem(
            icon: Icons.menu_book_outlined,
            iconColor: _kGreen,
            iconBg: _kGreenBg,
            label: 'Elimu',
            selected: current == 'education',
            onTap: () { Navigator.pop(context); onPicked('education'); },
          ),
        ],
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PickerItem({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.label, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(label, style: TextStyle(fontSize: 14, color: _kGrey900)),
      trailing: selected ? const Icon(Icons.check, color: _kBlue) : null,
      tileColor: selected ? _kBlueBg : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _RegionPicker extends StatefulWidget {
  final List<dynamic> regions;
  final String? currentId;
  final void Function(String?, String?) onPicked;
  const _RegionPicker({required this.regions, this.currentId, required this.onPicked});
  @override
  State<_RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<_RegionPicker> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.regions);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? List.from(widget.regions)
            : widget.regions.where((r) {
                return ((r as Map)['name'] as String? ?? '').toLowerCase().contains(q);
              }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Chagua mkoa',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tafuta mkoa...',
                prefixIcon: const Icon(Icons.search, size: 18, color: _kGrey500),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Mkoa wote'),
            trailing: widget.currentId == null ? const Icon(Icons.check, color: _kBlue) : null,
            onTap: () { Navigator.pop(context); widget.onPicked(null, null); },
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final r = _filtered[i] as Map<String, dynamic>;
                final id = r['id']?.toString() ?? '';
                final name = r['name'] as String? ?? '';
                return ListTile(
                  title: Text(name),
                  trailing: widget.currentId == id ? const Icon(Icons.check, color: _kBlue) : null,
                  onTap: () { Navigator.pop(context); widget.onPicked(id, name); },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DistrictPicker extends StatefulWidget {
  final List<dynamic> districts;
  final String? currentId;
  final void Function(String?, String?) onPicked;
  const _DistrictPicker({required this.districts, this.currentId, required this.onPicked});
  @override
  State<_DistrictPicker> createState() => _DistrictPickerState();
}

class _DistrictPickerState extends State<_DistrictPicker> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.districts);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? List.from(widget.districts)
            : widget.districts.where((d) {
                return ((d as Map)['name'] as String? ?? '').toLowerCase().contains(q);
              }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Chagua wilaya',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tafuta wilaya...',
                prefixIcon: const Icon(Icons.search, size: 18, color: _kGrey500),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Wilaya zote'),
            trailing: widget.currentId == null ? const Icon(Icons.check, color: _kBlue) : null,
            onTap: () { Navigator.pop(context); widget.onPicked(null, null); },
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: widget.districts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Chagua mkoa kwanza', textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final d = _filtered[i] as Map<String, dynamic>;
                      final id = d['id']?.toString() ?? '';
                      final name = d['name'] as String? ?? '';
                      return ListTile(
                        title: Text(name),
                        trailing: widget.currentId == id ? const Icon(Icons.check, color: _kBlue) : null,
                        onTap: () { Navigator.pop(context); widget.onPicked(id, name); },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SubjectPicker extends StatefulWidget {
  final List<dynamic> subjects;
  final String? currentCode;
  final ValueChanged<String?> onPicked;
  const _SubjectPicker({required this.subjects, this.currentCode, required this.onPicked});
  @override
  State<_SubjectPicker> createState() => _SubjectPickerState();
}

class _SubjectPickerState extends State<_SubjectPicker> {
  final _searchCtrl = TextEditingController();
  List<dynamic> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.subjects);
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? List.from(widget.subjects)
            : widget.subjects.where((s) {
                return ((s as Map)['name'] as String? ?? '').toLowerCase().contains(q);
              }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Chagua somo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tafuta somo...',
                prefixIcon: const Icon(Icons.search, size: 18, color: _kGrey500),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Masomo yote'),
            trailing: widget.currentCode == null ? const Icon(Icons.check, color: _kBlue) : null,
            onTap: () { Navigator.pop(context); widget.onPicked(null); },
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final s = _filtered[i] as Map<String, dynamic>;
                final code = s['code'] as String? ?? s['name'] as String? ?? '';
                final name = s['name'] as String? ?? '';
                return ListTile(
                  title: Text(name),
                  trailing: widget.currentCode == code ? const Icon(Icons.check, color: _kBlue) : null,
                  onTap: () { Navigator.pop(context); widget.onPicked(code); },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── USER DETAIL SHEET ──

class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final whatsapp = user['phone_whatsapp'] as String? ?? '';
    final category = user['category'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ?? '';
    final station = user['current_station'] as Map<String, dynamic>? ?? {};
    final region = station['region'] as String? ?? user['region'] as String? ?? '';
    final district = station['district'] as String? ?? user['district'] as String? ?? '';
    final facility = station['name'] as String? ?? '';
    final destinations = (user['destination_regions'] as List?)?.map((r) => r.toString()).toList() ?? [];
    final isActive = user['is_active'] as bool? ?? true;
    final isPaid = user['is_paid'] as bool? ?? false;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kBlue, const Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(48),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900),
              textAlign: TextAlign.center),
          if (cadre.isNotEmpty)
            Text(cadre, style: TextStyle(fontSize: 13, color: _kGrey500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(
                label: isActive ? 'Hai' : 'Amesitishwa',
                color: isActive ? _kGreen : _kAmber,
                bg: isActive ? _kGreenBg : _kAmberBg,
              ),
              const SizedBox(width: 8),
              _Badge(
                label: isPaid ? 'Amelipa' : 'Hajalipa',
                color: isPaid ? _kGreen : _kRed,
                bg: isPaid ? _kGreenBg : _kRedBg,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: _kGrey200),
          _InfoRow(label: 'Simu', value: phone, valueColor: _kBlue),
          if (whatsapp.isNotEmpty) _InfoRow(label: 'WhatsApp', value: whatsapp, valueColor: _kBlue),
          if (category.isNotEmpty) _InfoRow(label: 'Idara', value: category),
          if (region.isNotEmpty) _InfoRow(label: 'Mkoa', value: region),
          if (district.isNotEmpty) _InfoRow(label: 'Wilaya', value: district),
          if (facility.isNotEmpty) _InfoRow(label: 'Kituo', value: facility),
          if (destinations.isNotEmpty) ...[
            const Divider(color: _kGrey200),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Mikoa anayotaka kwenda',
                  style: TextStyle(fontSize: 12, color: _kGrey500)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: destinations.map((d) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(6)),
                child: Text(d, style: TextStyle(fontSize: 12, color: _kBlue)),
              )).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGrey700,
                    side: const BorderSide(color: _kGrey200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Funga'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Hariri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 13, color: _kGrey500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: valueColor ?? _kGrey900,
                )),
          ),
        ],
      ),
    );
  }
}

// ── USER EDIT SHEET ──

class _UserEditSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<dynamic> cadres;
  final List<dynamic> subjects;
  final VoidCallback onSaved;
  const _UserEditSheet({
    required this.user, required this.cadres, required this.subjects, required this.onSaved,
  });
  @override
  State<_UserEditSheet> createState() => _UserEditSheetState();
}

class _UserEditSheetState extends State<_UserEditSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  bool _isActive = true;
  bool _isPaid = false;
  bool _isAdmin = false;
  String? _cadreCode;
  Set<String> _selectedSubjects = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl.text = u['full_name'] as String? ?? '';
    _phoneCtrl.text = u['phone_primary'] as String? ?? u['phone'] as String? ?? '';
    _waCtrl.text = u['phone_whatsapp'] as String? ?? '';
    _isActive = u['is_active'] as bool? ?? true;
    _isPaid = u['is_paid'] as bool? ?? false;
    _isAdmin = u['is_admin'] as bool? ?? false;
    _cadreCode = u['cadre_code'] as String?;
    _selectedSubjects = Set.from((u['subjects'] as List?)?.map((s) => s.toString()) ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; });
    try {
      final id = widget.user['user_id']?.toString() ?? '';
      await ApiService().adminUpdateUser(id, {
        'full_name': _nameCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim(),
        if (_waCtrl.text.isNotEmpty) 'phone_whatsapp': _waCtrl.text.trim(),
        'is_active': _isActive,
        'is_paid': _isPaid,
        if (_cadreCode != null) 'cadre_code': _cadreCode,
        'subjects': _selectedSubjects.toList(),
      });
      if (_isAdmin != (widget.user['is_admin'] as bool? ?? false)) {
        if (_isAdmin) {
          await ApiService().adminGrant(id);
        } else {
          await ApiService().adminRevoke(id);
        }
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
              Text('Hariri Mtumiaji',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          // Personal info section
          _SectionHeader(icon: Icons.person_outline, label: 'MAELEZO BINAFSI'),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            decoration: _inputDec('Jina kamili *'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _phoneCtrl, decoration: _inputDec('Simu'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _waCtrl, decoration: _inputDec('WhatsApp'))),
            ],
          ),
          const SizedBox(height: 16),
          // Status section
          _SectionHeader(icon: Icons.shield_outlined, label: 'HALI NA HADHI'),
          const SizedBox(height: 10),
          Row(
            children: [
              _TogglePill2(label: 'Hai', selected: _isActive, color: _kGreen,
                  onTap: () => setState(() { _isActive = true; })),
              const SizedBox(width: 8),
              _TogglePill2(label: 'Amesitishwa', selected: !_isActive, color: _kAmber,
                  onTap: () => setState(() { _isActive = false; })),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _isPaid,
                onChanged: (v) => setState(() { _isPaid = v ?? false; }),
                activeColor: _kBlue,
              ),
              const Text('Amelipa'),
              const SizedBox(width: 16),
              Checkbox(
                value: _isAdmin,
                onChanged: (v) => setState(() { _isAdmin = v ?? false; }),
                activeColor: _kBlue,
              ),
              const Text('Admin'),
            ],
          ),
          const SizedBox(height: 16),
          // Cadre & subjects section
          _SectionHeader(icon: Icons.work_outline, label: 'KADA NA MASOMO'),
          const SizedBox(height: 10),
          if (widget.cadres.isNotEmpty)
            DropdownButtonFormField<String>(
              value: widget.cadres.any((c) => c['code'] == _cadreCode) ? _cadreCode : null,
              decoration: _inputDec('Chagua kada'),
              items: widget.cadres.map((c) => DropdownMenuItem<String>(
                value: c['code'] as String? ?? '',
                child: Text(c['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) => setState(() { _cadreCode = v; }),
            ),
          if (widget.subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Masomo', style: TextStyle(fontSize: 12, color: _kGrey700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: widget.subjects.map((s) {
                final code = s['code'] as String? ?? s['name'] as String? ?? '';
                final name = s['name'] as String? ?? '';
                final selected = _selectedSubjects.contains(code);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedSubjects.remove(code);
                      } else {
                        _selectedSubjects.add(code);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _kBlueBg : Colors.white,
                      border: Border.all(color: selected ? _kBlue : _kGrey200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(name,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? _kBlue : _kGrey700,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGrey700,
                    side: const BorderSide(color: _kGrey200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Ghairi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Hifadhi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kGrey500),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 11, color: _kGrey500, fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ],
    );
  }
}

class _TogglePill2 extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TogglePill2({required this.label, required this.selected, required this.color, required this.onTap});

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

// ── ADD ADMIN DIALOG ──

class _AddAdminDialog extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddAdminDialog({required this.onAdded});
  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() { _adding = true; });
    try {
      await ApiService().adminCreateUser({
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim(),
        'password': _passCtrl.text,
        'is_admin': true,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() { _adding = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.admin_panel_settings_outlined, color: _kBlue, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Ongeza Admin'),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nameCtrl, decoration: _inputDec('Jina Kamili')),
          const SizedBox(height: 10),
          TextField(controller: _emailCtrl, decoration: _inputDec('Barua Pepe')),
          const SizedBox(height: 10),
          TextField(controller: _phoneCtrl, decoration: _inputDec('Simu')),
          const SizedBox(height: 10),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: _inputDec('Nenosiri'),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _adding ? null : _add,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _adding
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Ongeza Admin'),
          ),
        ),
      ],
    );
  }
}

// ── ADD USER SHEET ──

class _AddUserSheet extends StatefulWidget {
  final List<dynamic> regions;
  final List<dynamic> cadres;
  final List<dynamic> subjects;
  final VoidCallback onAdded;
  const _AddUserSheet({
    required this.regions, required this.cadres, required this.subjects, required this.onAdded,
  });
  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _category = 'health';
  String? _cadreCode;
  String? _regionId;
  bool _isAdmin = false;
  bool _isPaid = false;
  Set<String> _selectedSubjects = {};
  bool _adding = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    setState(() { _adding = true; });
    try {
      await ApiService().adminCreateUser({
        'full_name': _nameCtrl.text.trim(),
        'phone_primary': _phoneCtrl.text.trim(),
        if (_waCtrl.text.isNotEmpty) 'phone_whatsapp': _waCtrl.text.trim(),
        if (_passCtrl.text.isNotEmpty) 'password': _passCtrl.text,
        'category': _category,
        if (_cadreCode != null) 'cadre_code': _cadreCode,
        'is_admin': _isAdmin,
        'is_paid': _isPaid,
        if (_regionId != null) 'region_id': _regionId,
        'subjects': _selectedSubjects.toList(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() { _adding = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
  );

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
              Text('Ongeza Mtumiaji',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          _SectionHeader(icon: Icons.person_outline, label: 'MAELEZO BINAFSI'),
          const SizedBox(height: 10),
          TextField(controller: _nameCtrl, decoration: _inputDec('Jina Kamili *')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _phoneCtrl, decoration: _inputDec('Simu *'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _waCtrl, decoration: _inputDec('WhatsApp'))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: _passCtrl, obscureText: true, decoration: _inputDec('Nenosiri')),
          const SizedBox(height: 16),
          _SectionHeader(icon: Icons.work_outline, label: 'SEKTA NA KADA'),
          const SizedBox(height: 10),
          Row(
            children: [
              _TogglePill2(label: 'Afya', selected: _category == 'health', color: _kRed,
                  onTap: () => setState(() { _category = 'health'; })),
              const SizedBox(width: 8),
              _TogglePill2(label: 'Elimu', selected: _category == 'education', color: _kGreen,
                  onTap: () => setState(() { _category = 'education'; })),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.cadres.isNotEmpty)
            DropdownButtonFormField<String>(
              value: widget.cadres.any((c) => c['code'] == _cadreCode) ? _cadreCode : null,
              decoration: _inputDec('Chagua kada'),
              items: widget.cadres.map((c) => DropdownMenuItem<String>(
                value: c['code'] as String? ?? '',
                child: Text(c['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) => setState(() { _cadreCode = v; }),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _isPaid,
                onChanged: (v) => setState(() { _isPaid = v ?? false; }),
                activeColor: _kBlue,
              ),
              const Text('Amelipa'),
              const SizedBox(width: 16),
              Checkbox(
                value: _isAdmin,
                onChanged: (v) => setState(() { _isAdmin = v ?? false; }),
                activeColor: _kBlue,
              ),
              const Text('Admin'),
            ],
          ),
          const SizedBox(height: 16),
          _SectionHeader(icon: Icons.location_on_outlined, label: 'KITUO CHA SASA'),
          const SizedBox(height: 10),
          if (widget.regions.isNotEmpty)
            DropdownButtonFormField<String>(
              value: widget.regions.any((r) => r['id'].toString() == _regionId) ? _regionId : null,
              decoration: _inputDec('Chagua mkoa'),
              items: widget.regions.map((r) => DropdownMenuItem<String>(
                value: r['id'].toString(),
                child: Text(r['name'] as String? ?? ''),
              )).toList(),
              onChanged: (v) => setState(() { _regionId = v; }),
            ),
          const SizedBox(height: 16),
          if (widget.subjects.isNotEmpty) ...[
            _SectionHeader(icon: Icons.menu_book_outlined, label: 'MIKOA ANAYOTAKA KWENDA'),
            const SizedBox(height: 10),
            Text('Masomo', style: TextStyle(fontSize: 12, color: _kGrey700, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: widget.subjects.map((s) {
                final code = s['code'] as String? ?? s['name'] as String? ?? '';
                final name = s['name'] as String? ?? '';
                final selected = _selectedSubjects.contains(code);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedSubjects.remove(code);
                      } else {
                        _selectedSubjects.add(code);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _kBlueBg : Colors.white,
                      border: Border.all(color: selected ? _kBlue : _kGrey200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(name,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? _kBlue : _kGrey700,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _adding ? null : _add,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _adding
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Ongeza Mtumiaji', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
