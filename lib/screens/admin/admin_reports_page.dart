// STATISTICS — esstranfer.com/admin look
// ─────────────────────────────────────────────────────────────────────────────
// Muonekano na MPANGILIO kama web:
//   Title + LIVE badge → stat cards (Watumiaji/Imethibitishwa/Mikoa) →
//   MATUKIO YA HIVI KARIBUNI (getNotifications — API ile ile ya web:
//   "X amejiunga", "Match mpya: A ↔ B") → mini tabs (Statistics/Watumiaji) →
//   filters (Mkoa/Idara/Ngazi) → stat grid (Mikoa/Wilaya/Waliopo/Wanaohamia) →
//   jedwali: Kwa Idara, Kwa Hali, Mkoa migration (progress), Watu kwa Wilaya,
//   Walimu kwa Ngazi, Kwa Kada, Wanaohamia wanatoka wapi.
// Background NYEUPE, kadi grey nyepesi (#F7F8FA), namba bluu (#1959D6) na
// chungwa (#EA5A0C) — hakuna gradient kubwa ya bluu.
// Data halisi: adminStats + adminReports + getNotifications (+adminEvents fallback)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Rangi (zinazolingana na esstranfer.com/admin) ───────────────────────────
const _cBlue      = Color(0xFF1959D6);
const _cBlueBg    = Color(0xFFEAF1FF);
const _cOrange    = Color(0xFFEA5A0C);
const _cBg        = Colors.white;
const _cCardBg    = Color(0xFFF7F8FA);
const _cChipBg    = Color(0xFFF3F4F6);
const _cBorder    = Color(0xFFECEEF1);
const _cTextDark  = Color(0xFF16181D);
const _cTextGrey  = Color(0xFF6B7280);
const _cTextFaint = Color(0xFF9CA3AF);
const _cLiveGreen = Color(0xFF16A34A);

// ── Helpers (top-level — zinatumika na widgets zote) ────────────────────────
String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Item ya picker sheet (Mkoa/Idara/Ngazi).
class _PickerItem {
  final String label;
  final String? sub;
  final String value;
  final bool selected;
  const _PickerItem(this.label, this.sub, this.value, this.selected);
}

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _stats = {};
  List<dynamic> _notifs = []; // Matukio — getNotifications (kama web)
  List<dynamic> _events = []; // fallback — /admin/events
  String _tab = 'overview';

  // Filters
  String? _region;
  String? _regionId;
  String? _category;
  String _level = '';

  List<dynamic> _regions = [];
  List<dynamic> _departments = [];

  // Users tab
  final _usersCtrl = TextEditingController();
  Timer? _usersDebounce;
  List<dynamic> _users = [];
  int _usersTotal = 0;
  bool _usersLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
    _loadUsers();
    _loadNotifs();
  }

  @override
  void dispose() {
    _usersCtrl.dispose();
    _usersDebounce?.cancel();
    super.dispose();
  }

  // ── Data loading (API zote kama web) ────────────────────────────────────────
  Future<void> _loadRefs() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _regions = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []));
    } catch (_) {}
    try {
      final r = await ApiService().adminListDepartments();
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []);
      setState(() => _departments = list
          .where((d) => '${d['is_active'] ?? d['active'] ?? true}' != 'false')
          .toList());
    } catch (_) {}
  }

  /// Matukio ya Hivi Karibuni — API ile ile inayotumiwa na web dashboard:
  /// GET /notifications (titles zimeandaliwa: "X amejiunga", "Match mpya: A ↔ B")
  Future<void> _loadNotifs() async {
    try {
      final r = await ApiService().getNotifications(limit: 12);
      if (!mounted) return;
      final d = r.data;
      final list = d is Map
          ? ((d['notifications'] as List?) ?? [])
          : (d is List ? d : []);
      if (list.isNotEmpty) setState(() => _notifs = list);
    } catch (_) {}
  }

  Future<void> _load({bool refresh = false}) async {
    final firstLoad = _data.isEmpty;
    setState(() { if (firstLoad) _loading = true; _error = null; });
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      setState(() => _stats = (r.data as Map<String, dynamic>?) ?? {});
    } catch (_) {}
    try {
      final r = await ApiService().adminEvents(limit: 20);
      if (!mounted) return;
      final d = r.data;
      List raw = [];
      if (d is List) {
        raw = d;
      } else if (d is Map) {
        raw = (d['events'] as List?) ?? [];
      }
      setState(() => _events = raw.where((e) {
        final m = e as Map;
        final type = (m['event_type'] ?? m['type'] ?? '') as String;
        return !['user.presence', 'user.online', 'user.offline',
                 'user.connected', 'user.disconnected'].contains(type);
      }).take(8).toList());
    } catch (_) {}
    try {
      final res = await ApiService().adminReports(
        days: 365,
        region: _region,
        category: _category,
        level: _level,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() { _data = (res.data as Map<String, dynamic>?) ?? {}; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); if (firstLoad) _loading = false; });
    }
    if (refresh) _loadNotifs();
  }

  Future<void> _loadUsers({String q = ''}) async {
    setState(() => _usersLoading = true);
    try {
      final r = await ApiService().adminUsers(
          params: {if (q.isNotEmpty) 'q': q, 'limit': 100}, useCache: false);
      if (!mounted) return;
      final d = r.data as Map? ?? {};
      setState(() {
        _users = (d['users'] as List?) ?? [];
        _usersTotal = (d['total'] as num?)?.toInt() ?? _users.length;
        _usersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  void _onUsersSearch(String q) {
    _usersDebounce?.cancel();
    _usersDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _loadUsers(q: q);
    });
  }

  // ── Pickers (fanya kazi — sheets zenye search) ─────────────────────────────
  Future<void> _pickRegion() async {
    final inData = <String>{
      for (final r in _list('users_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
      for (final r in _list('incoming_by_region')) if ((r['region'] ?? '').toString().isNotEmpty) '${r['region']}',
    }.toList()..sort();
    final source = inData.isNotEmpty
        ? inData.map((n) => {'name': n}).toList()
        : _regions;
    final items = <_PickerItem>[
      _PickerItem('Mkoa wote', 'Onyesha mikoa yote', '__all__',
          _regionId == null || _regionId!.isEmpty),
      for (final r in source)
        _PickerItem(
          '${r['name'] ?? r['region_name'] ?? ''}',
          null,
          '${r['id'] ?? r['region_id'] ?? r['name']}',
          '${r['id'] ?? r['region_id'] ?? r['name']}' == (_regionId ?? ''),
        ),
    ];
    final picked = await _showPickerSheet('Chagua mkoa', items,
        _regionId == null || _regionId!.isEmpty);
    if (picked == null || !mounted) return;
    final r = source.firstWhere(
        (x) => '${x['id'] ?? x['region_id'] ?? x['name']}' == picked, orElse: () => null);
    setState(() {
      _regionId = picked == '__all__' ? null : picked;
      _region = picked == '__all__' ? null : '${r?['name'] ?? r?['region_name'] ?? ''}';
    });
    _load();
  }

  Future<void> _pickCategory() async {
    final items = <_PickerItem>[
      _PickerItem('Idara zote', 'Onyesha idara zote', '__all__', _category == null),
      for (final d in _departments)
        _PickerItem(
          '${d['name'] ?? d['display_name'] ?? d['code']}',
          null,
          '${d['code']}',
          _category == '${d['code']}',
        ),
    ];
    final picked = await _showPickerSheet('Chagua idara', items, _category == null);
    if (picked == null || !mounted) return;
    setState(() {
      _category = picked == '__all__' ? null : picked;
    });
    _load();
  }

  Future<void> _pickLevel() async {
    final items = <_PickerItem>[
      const _PickerItem('Ngazi zote', 'Primary na Secondary', '', true),
      const _PickerItem('Primary (Msingi)', null, 'Primary', false),
      const _PickerItem('Secondary (Sekondari)', null, 'Secondary', false),
    ];
    final picked = await _showPickerSheet('Chagua ngazi', items, _level.isEmpty);
    if (picked == null || !mounted) return;
    setState(() => _level = picked);
    _load();
  }

  Future<String?> _showPickerSheet(String title, List<_PickerItem> items, bool allSelected) {
    final ctrl = TextEditingController();
    List<_PickerItem> filtered = List.from(items);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Expanded(child: Text(title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _cTextDark))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(width: 30, height: 30,
                      decoration: const BoxDecoration(color: _cChipBg, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 15, color: _cTextDark)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: ctrl,
                onChanged: (q) {
                  final ql = q.toLowerCase();
                  ss(() => filtered = items.where((i) => i.label.toLowerCase().contains(ql)).toList());
                },
                decoration: InputDecoration(
                  hintText: 'Tafuta...',
                  hintStyle: const TextStyle(color: _cTextFaint, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _cTextFaint),
                  filled: true,
                  fillColor: _cCardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  for (final item in filtered)
                    _pickerTile(item.label, item.sub,
                        (item.value == '__all__' || item.value == '') ? allSelected : item.selected,
                        () => Navigator.pop(ctx, item.value)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pickerTile(String label, String? sub, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _cBlueBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _cBlue : _cBorder, width: selected ? 1.4 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                      fontSize: 13.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _cBlue : _cTextDark)),
                  if (sub != null)
                    Text(sub, style: const TextStyle(fontSize: 11, color: _cTextFaint)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 18, color: _cBlue),
          ],
        ),
      ),
    );
  }

  // ── Data helpers ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _list(String key) =>
      ((_data[key] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  String _deptLabel(String code) {
    final d = _departments.firstWhere((x) => '${x['code']}' == code, orElse: () => null);
    return d == null ? code : '${d['name'] ?? code}';
  }

  String _deptIcon(String code) {
    final d = _departments.firstWhere((x) => '${x['code']}' == code, orElse: () => null);
    return d == null ? '' : '${d['icon'] ?? ''}';
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active': return 'Hai (active)';
      case 'disabled': return 'Imesitishwa';
      case 'pending': return 'Inasubiri uthibitisho';
      case 'suspended': return 'Imesitishwa';
      default: return s.isEmpty ? 'Unknown' : s;
    }
  }

  List<({String region, int current, int incoming})> get _byRegion {
    final cur = _list('users_by_region');
    final inc = _list('incoming_by_region');
    final names = <String>{
      for (final r in cur) '${r['region'] ?? ''}',
      for (final r in inc) '${r['region'] ?? ''}',
    }..removeWhere((n) => n.isEmpty);
    final out = names.map((n) => (
      region: n,
      current: (cur.firstWhere((r) => '${r['region']}' == n, orElse: () => {})['count'] as num?)?.toInt() ?? 0,
      incoming: (inc.firstWhere((r) => '${r['region']}' == n, orElse: () => {})['count'] as num?)?.toInt() ?? 0,
    )).toList()
      ..sort((a, b) => (b.current + b.incoming).compareTo(a.current + a.incoming));
    return out;
  }

  List<({String region, int current, int incoming})> _byDistrict() {
    final byDist = _list('users_by_district');
    final inDist = _list('incoming_by_district');
    final rows = byDist.take(50).map((d) {
      final label = '${d['district'] ?? '—'}'
          '${(_region == null || _region!.isEmpty) && (d['region'] ?? '').toString().isNotEmpty ? ' · ${d['region']}' : ''}';
      final inc = (inDist.firstWhere(
        (x) => '${x['district']}' == '${d['district']}', orElse: () => {},
      )['count'] as num?)?.toInt() ?? 0;
      return (region: label, current: (d['count'] as num?)?.toInt() ?? 0, incoming: inc);
    }).toList()
      ..sort((a, b) => (b.current + b.incoming).compareTo(a.current + a.incoming));
    return rows;
  }

  int get _districtsCount => <String>{
    for (final d in _list('users_by_district')) if ((d['district'] ?? '').toString().isNotEmpty) '${d['district']}',
    for (final d in _list('incoming_by_district')) if ((d['district'] ?? '').toString().isNotEmpty) '${d['district']}',
  }.length;

  String _fmtTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _eventTitle(String type) {
    switch (type) {
      case 'user.registered': return 'Mtu mpya amejiunga';
      case 'payment.submitted': return 'Malipo yamewasilishwa';
      case 'payment.approved': return 'Malipo yamethibitishwa';
      case 'feedback.new': return 'Maoni mapya ya mtumiaji';
      default: return type;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cBg,
      child: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: _cBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Statistics',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800, color: _cTextDark)),
                  const SizedBox(height: 6),
                  const Text(
                    'Takwimu za mfumo mzima — mikoa, idara, kada, michango (real-time)',
                    style: TextStyle(color: _cTextGrey, fontSize: 14, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  _liveBadge(),
                  const SizedBox(height: 16),

                  // ── Stat cards za juu (jumla ya mfumo) ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      StatCard(
                        value: _fmt(_statUsers()),
                        label: 'Watumiaji',
                        sub: '+${_fmt(_statUsers7d())} wanatumia siku 7',
                        valueColor: _cBlue,
                      ),
                      StatCard(
                        value: _fmt(_statVerified()),
                        label: 'Imethibitishwa',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StatCard(value: _fmt(_byRegion.length), label: 'Mikoa yote'),
                  const SizedBox(height: 20),

                  // ── MATUKIO YA HIVI KARIBUNI (API ya notifications kama web) ──
                  SectionCard(
                    title: 'Matukio ya Hivi Karibuni',
                    titleIcon: Icons.notifications_none_rounded,
                    child: _activityList(),
                  ),
                  const SizedBox(height: 16),

                  // ── Mini tabs: Statistics / Watumiaji ──
                  _miniTabBar(),
                  const SizedBox(height: 16),

                  // ── Filters ──
                  _FilterDropdown(
                    label: _region == null || _region!.isEmpty
                        ? 'Mkoa wote' : _region!,
                    active: _region != null && _region!.isNotEmpty,
                    onTap: _pickRegion,
                  ),
                  const SizedBox(height: 10),
                  _FilterDropdown(
                    label: _category == null || _category!.isEmpty
                        ? 'Idara zote' : _deptLabel(_category!),
                    active: _category != null && _category!.isNotEmpty,
                    onTap: _pickCategory,
                  ),
                  const SizedBox(height: 10),
                  _FilterDropdown(
                    label: _level.isEmpty ? 'Ngazi zote'
                        : (_level == 'Primary' ? 'Primary (Msingi)' : 'Secondary (Sekondari)'),
                    active: _level.isNotEmpty,
                    onTap: _pickLevel,
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _cBlue)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_error != null) _errorBanner(),
                    if (_tab == 'users') _usersTab() else ..._overviewSections(),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Stats getters ──────────────────────────────────────────────────────────
  int _statUsers() {
    final totals = _stats['totals'] as Map<String, dynamic>? ?? {};
    return (totals['users'] as num?)?.toInt() ?? _reportUsersTotal;
  }

  int _statUsers7d() {
    final totals = _stats['totals'] as Map<String, dynamic>? ?? {};
    return (totals['users_active_7d'] as num?)?.toInt() ?? 0;
  }

  int _statVerified() {
    final totals = _stats['totals'] as Map<String, dynamic>? ?? {};
    return (totals['users_verified'] as num?)?.toInt() ?? 0;
  }

  int get _reportUsersTotal =>
      _list('users_by_region').fold(0, (s, r) => s + ((r['count'] as num?)?.toInt() ?? 0));

  int get _incomingTotal =>
      _list('incoming_by_region').fold(0, (s, r) => s + ((r['count'] as num?)?.toInt() ?? 0));

  // ── LIVE badge ─────────────────────────────────────────────────────────────
  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _cCardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: _cLiveGreen, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('LIVE — mabadiliko yanaonekana papo hapo',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12.5, color: _cTextDark)),
        ],
      ),
    );
  }

  // ── Mini tab bar (Statistics / Watumiaji) ──────────────────────────────────
  Widget _miniTabBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _tabLabel('Statistics', active: _tab == 'overview', onTap: () => setState(() => _tab = 'overview')),
        const SizedBox(width: 22),
        _tabLabel('Watumiaji', active: _tab == 'users', onTap: () => setState(() => _tab = 'users')),
      ]),
      const SizedBox(height: 8),
      Container(height: 1, color: _cBorder),
    ]);
  }

  Widget _tabLabel(String text, {required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(text,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: active ? _cBlue : _cTextGrey)),
        const SizedBox(height: 8),
        if (active) Container(height: 2, width: 62, color: _cBlue),
      ]),
    );
  }

  // ── Filter dropdown row (kama web) ─────────────────────────────────────────
  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text('Imeshindikana kupakia takwimu zote — vichujio vinaendelea kufanya kazi.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF991B1B))),
    );
  }

  // ═══ MATUKIO — getNotifications (API ile ile ya web) + fallback /admin/events
  Widget _activityList() {
    // PRIMARY: notifications — titles zimeandaliwa backend kama web dashboard:
    // "Fatuma Abdallah Masebu amejiunga", "Match mpya: A ↔ B", "Maoni mapya..."
    if (_notifs.isNotEmpty) {
      return Column(
        children: [
          for (var i = 0; i < _notifs.take(6).length; i++)
            Builder(builder: (_) {
              final e = _notifs.elementAt(i) as Map;
              final type = (e['type'] ?? '') as String;
              final (ico, col) = _notifIcon(type);
              return _ActivityTile(
                icon: ico,
                iconColor: col,
                text: (e['title'] ?? '') as String? ?? '',
                time: _fmtTime((e['created_at'] ?? e['occurred_at'] ?? '') as String? ?? ''),
                isLast: i == _notifs.take(6).length - 1,
              );
            }),
        ],
      );
    }
    // FALLBACK: /admin/events (event_log)
    if (_events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Hakuna matukio ya hivi karibuni.',
            style: TextStyle(fontSize: 13, color: _cTextFaint)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _events.take(6).length; i++)
          Builder(builder: (_) {
            final e = _events.elementAt(i) as Map;
            final type = (e['event_type'] ?? e['type'] ?? '') as String;
            final (ico, col) = _notifIcon(type);
            return _ActivityTile(
              icon: ico,
              iconColor: col,
              text: (e['title'] as String?)?.isNotEmpty == true
                  ? e['title'] as String
                  : _eventTitle(type),
              time: _fmtTime((e['occurred_at'] ?? e['created_at'] ?? '') as String? ?? ''),
              isLast: i == _events.take(6).length - 1,
            );
          }),
      ],
    );
  }

  (IconData, Color) _notifIcon(String type) {
    // Mapping ile ile ya web (RecentActivity kwenye admin dashboard):
    // user.registered → UserPlus bluu; payment.* → Wallet kijani;
    // feedback.* → Clipboard chungwa; password_reset.new → Key zambarau;
    // data.changed → Zap njano; default → Bell grey.
    if (type.startsWith('user.registered') || type.startsWith('user_created')) {
      return (Icons.person_add_alt_1_rounded, _cBlue);
    }
    if (type.startsWith('payment')) return (Icons.account_balance_wallet_outlined, _cLiveGreen);
    if (type.startsWith('feedback')) return (Icons.assignment_outlined, _cOrange);
    if (type.startsWith('password_reset')) return (Icons.key_rounded, const Color(0xFF9333EA));
    if (type.startsWith('data.changed') || type.startsWith('data_')) {
      return (Icons.bolt_rounded, const Color(0xFFCA8A04));
    }
    if (type.startsWith('match')) return (Icons.link_rounded, _cBlue);
    return (Icons.notifications_none_rounded, _cTextGrey);
  }

  // ═══ OVERVIEW SECTIONS (mpangilio wa web) ═══════════════════════════════
  List<Widget> _overviewSections() {
    final totals = _stats['totals'] as Map<String, dynamic>? ?? {};

    final byCadreAll = _list('users_by_cadre');
    final priCount = byCadreAll
        .where((c) => (c['level'] ?? '') == 'Primary')
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));
    final secCount = byCadreAll
        .where((c) => (c['level'] ?? '') == 'Secondary')
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));
    final noneCount = byCadreAll
        .where((c) => (c['level'] ?? '').toString().isEmpty)
        .fold(0, (s, c) => s + ((c['count'] as num?)?.toInt() ?? 0));

    final byDept = _list('users_by_category')
        ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
            .compareTo((a['count'] as num?)?.toInt() ?? 0));
    final byStatus = _list('users_by_status')
        ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
            .compareTo((a['count'] as num?)?.toInt() ?? 0));
    final byCadre = (byCadreAll.toList()
          ..sort((a, b) => ((b['count'] as num?)?.toInt() ?? 0)
              .compareTo((a['count'] as num?)?.toInt() ?? 0)));

    final grandTotal = _reportUsersTotal;
    int pct(int n) => grandTotal == 0 ? 0 : ((n / grandTotal) * 100).round();

    final regionRows = _byRegion.take(30).map((r) =>
        RegionRow(r.region, r.current, r.incoming)).toList();
    final districtRows = _byDistrict().take(20).map((d) =>
        DistrictRow(d.region, d.current, d.incoming, d.current + d.incoming)).toList();
    final sourceRows = _list('incoming_sources').take(15).map((f) =>
        MigrationRow(0, '${f['from'] ?? ''}', '${f['to'] ?? ''}',
            (f['count'] as num?)?.toInt() ?? 0)).toList();

    return [
      // ── Stat grid ya pili (baada ya filters) ──
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: [
          StatCard(value: _fmt(_byRegion.length), label: 'Mikoa yote', valueColor: _cBlue),
          StatCard(value: _fmt(_districtsCount), label: 'Wilaya zote'),
          StatCard(value: _fmt(grandTotal), label: 'Watumiaji waliopo', valueColor: _cBlue),
          StatCard(value: _fmt(_incomingTotal), label: 'Wanaohamia wote', valueColor: _cOrange),
        ],
      ),
      const SizedBox(height: 16),

      // ── Kwa Idara ──
      RankedTable(
        title: 'Kwa Idara',
        total: grandTotal,
        rows: [
          for (final c in byDept)
            RankedRow(
              '${c['name'] ?? _deptLabel('${c['category']}')}',
              pct((c['count'] as num?)?.toInt() ?? 0),
              (c['count'] as num?)?.toInt() ?? 0,
              emoji: '${c['icon'] ?? _deptIcon('${c['category']}')}',
            ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Kwa Hali ──
      RankedTable(
        title: 'Kwa Hali',
        total: grandTotal,
        rows: [
          for (final s in byStatus)
            RankedRow(
              _statusLabel('${s['status']}'),
              pct((s['count'] as num?)?.toInt() ?? 0),
              (s['count'] as num?)?.toInt() ?? 0,
            ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Waliopo na Wanaohamia kwa Mkoa ──
      if (regionRows.isNotEmpty)
        RegionMigrationTable(
          title: 'Waliopo na Wanaohamia kwa Mkoa',
          subtitle: 'Walio + Wanaohamia (chungwa) — kila mkoa',
          rows: regionRows,
        ),
      if (regionRows.isNotEmpty) const SizedBox(height: 16),

      // ── Watu kwa Wilaya ──
      if (districtRows.isNotEmpty)
        DistrictTable(
          title: 'Watu kwa Wilaya${_region != null && _region!.isNotEmpty ? ' — $_region' : ''}',
          rows: districtRows,
        ),
      if (districtRows.isNotEmpty) const SizedBox(height: 16),

      // ── Walimu kwa Ngazi ──
      RankedTable(
        title: 'Walimu kwa Ngazi (Primary/Secondary)',
        total: grandTotal,
        rows: [
          RankedRow('Walimu wa Msingi', pct(priCount), priCount),
          RankedRow('Walimu wa Sekondari', pct(secCount), secCount),
          if (noneCount > 0) RankedRow('Hakuna ngazi', pct(noneCount), noneCount),
        ],
      ),
      const SizedBox(height: 16),

      // ── Kwa Kada ──
      RankedTable(
        title: 'Kwa Kada',
        rows: [
          for (final c in byCadre.take(15))
            RankedRow(
              '${c['cadre_name'] ?? c['cadre'] ?? ''}${(c['level'] ?? '').toString().isEmpty ? '' : ' (${c['level']})'}',
              0,
              (c['count'] as num?)?.toInt() ?? 0,
            ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Wanaohamia wanatoka wapi ──
      if (sourceRows.isNotEmpty)
        MigrationSourceTable(
          title: 'Wanaohamia wanatoka wapi',
          subtitle: 'Kila mkoa wanaohamia — wanatoka mikoa ipi',
          rows: List.generate(sourceRows.length, (i) =>
              MigrationRow(i + 1, sourceRows[i].from, sourceRows[i].to, sourceRows[i].count)),
        ),

      // Kenye totals hakuna kitu — onyesha angalau stat tupu (totals kutoka adminStats)
      if (grandTotal == 0 && byDept.isEmpty && _error == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('Hakuna takwimu bado (jumla ya watumiaji: ${_fmt((totals['users'] as num?)?.toInt() ?? 0)})',
                style: const TextStyle(color: _cTextGrey, fontSize: 13)),
          ),
        ),
    ];
  }

  // ═══ USERS TAB (Jina / Simu / Kada — horizontal scroll kama web) ════════
  Widget _usersTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _usersCtrl,
        onChanged: _onUsersSearch,
        decoration: InputDecoration(
          hintText: 'Tafuta jina au simu...',
          hintStyle: const TextStyle(color: _cTextFaint, fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: _cTextFaint),
          filled: true,
          fillColor: _cCardBg,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 12),
      Text('Jumla: ${_fmt(_usersTotal)}',
          style: const TextStyle(fontSize: 13, color: _cTextGrey)),
      const SizedBox(height: 10),
      if (_usersLoading)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: _cBlue)),
        )
      else if (_users.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            border: Border.all(color: _cBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text('Hakuna watumiaji walopatikana.',
                style: TextStyle(color: _cTextGrey)),
          ),
        )
      else
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _cBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(_cCardBg),
              headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12.5, color: _cTextDark),
              dataTextStyle: const TextStyle(fontSize: 13.5, color: _cTextDark),
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('Jina')),
                DataColumn(label: Text('Simu')),
                DataColumn(label: Text('Kada')),
              ],
              rows: [
                for (final u in _users)
                  DataRow(cells: [
                    DataCell(SizedBox(
                        width: 180,
                        child: Text('${u['full_name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)))),
                    DataCell(Text('${u['phone_primary'] ?? u['phone'] ?? ''}',
                        style: const TextStyle(
                            color: _cBlue, fontWeight: FontWeight.w600))),
                    DataCell(_KadaChip(
                        '${u['cadre_display'] ?? u['cadre_code'] ?? '—'}')),
                  ]),
              ],
            ),
          ),
        ),
    ]);
  }
}

// ═══ STAT CARD (namba kubwa + lebo) ══════════════════════════════════════════
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String? sub;
  final Color valueColor;
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.sub,
    this.valueColor = _cTextDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cCardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: valueColor)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _cTextGrey, fontSize: 13.5)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!, style: const TextStyle(color: _cTextGrey, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

// ═══ SECTION CARD (white, border, title + icon) ══════════════════════════════
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? titleIcon;
  final Widget child;
  const SectionCard(
      {super.key, required this.title, this.subtitle, this.titleIcon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cBg,
        border: Border.all(color: _cBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Icon(titleIcon, size: 20, color: _cTextDark),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: _cTextDark)),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: _cTextGrey, fontSize: 12.5)),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ═══ FILTER DROPDOWN ROW (kama web: Mkoa wote / Idara zote / Ngazi zote) ═════
class _FilterDropdown extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterDropdown({required this.label, this.active = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? _cBlueBg : _cBg,
          border: Border.all(color: active ? _cBlue : _cBorder, width: active ? 1.4 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label,
                style: TextStyle(
                    color: active ? _cBlue : _cTextDark,
                    fontSize: 14.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: active ? _cBlue : _cTextGrey),
          ],
        ),
      ),
    );
  }
}

// ═══ ACTIVITY TILE (matukio — icon + text + saa) ═════════════════════════════
class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final String time;
  final bool isLast;
  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.time,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _cBorder)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: _cTextDark)),
          ),
          const SizedBox(width: 8),
          Text(time, style: const TextStyle(color: _cTextGrey, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ═══ RANKED TABLE (#, JINA, %, HESABU + Jumla) ═══════════════════════════════
class RankedRow {
  final String name;
  final int percent;
  final int count;
  final String? emoji;
  const RankedRow(this.name, this.percent, this.count, {this.emoji});
}

class RankedTable extends StatelessWidget {
  final String title;
  final List<RankedRow> rows;
  final int? total;
  const RankedTable({super.key, required this.title, required this.rows, this.total});

  @override
  Widget build(BuildContext context) {
    final computedTotal = total ?? rows.fold<int>(0, (a, b) => a + b.count);
    return SectionCard(
      title: title,
      child: Column(
        children: [
          const _TableHeaderRow(),
          ...List.generate(rows.length, (i) => _RankedRowWidget(index: i + 1, row: rows[i])),
          const Divider(height: 20, color: _cBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jumla:',
                  style: TextStyle(color: _cTextGrey, fontWeight: FontWeight.w600)),
              Text(_fmt(computedTotal),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _cTextDark)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();
  @override
  Widget build(BuildContext context) {
    const style =
        TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _cTextDark);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text('#', style: style)),
          Expanded(child: Text('JINA', style: style)),
          SizedBox(width: 44, child: Text('%', textAlign: TextAlign.right, style: style)),
          SizedBox(width: 64, child: Text('HESABU', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

class _RankedRowWidget extends StatelessWidget {
  final int index;
  final RankedRow row;
  const _RankedRowWidget({required this.index, required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _cBorder)),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 26,
              child: Text('$index',
                  style: const TextStyle(color: _cTextDark, fontWeight: FontWeight.w600))),
          Expanded(
            child: Row(
              children: [
                if (row.emoji != null && row.emoji!.isNotEmpty) ...[
                  Text(row.emoji!, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _cTextDark, fontSize: 13.5)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${row.percent}%',
                textAlign: TextAlign.right,
                style: const TextStyle(color: _cTextGrey, fontSize: 13)),
          ),
          SizedBox(
            width: 64,
            child: Text(_fmt(row.count),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: _cBlue, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

// ═══ REGION MIGRATION TABLE (progress bar + chungwa) ═════════════════════════
class RegionRow {
  final String region;
  final int waliopo;
  final int wanaohamia;
  const RegionRow(this.region, this.waliopo, this.wanaohamia);
}

class RegionMigrationTable extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<RegionRow> rows;
  const RegionMigrationTable(
      {super.key, required this.title, required this.subtitle, required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxVal = rows.map((r) => r.wanaohamia).reduce((a, b) => a > b ? a : b);
    return SectionCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 22, child: Text('#',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _cTextDark))),
                Expanded(flex: 3, child: Text('MKOA',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _cTextDark))),
                Expanded(flex: 2, child: Text('WALIOPO', textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _cTextDark))),
                Expanded(flex: 2, child: Text('WANAOHAMIA', textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: _cTextDark))),
              ],
            ),
          ),
          ...List.generate(rows.length, (i) {
            final r = rows[i];
            final barWidth = maxVal == 0 ? 0.0 : r.wanaohamia / maxVal;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _cBorder))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 22, child: Text('${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: _cTextDark))),
                      Expanded(
                          flex: 3,
                          child: Text(r.region,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _cTextDark, fontSize: 13.5))),
                      Expanded(
                          flex: 2,
                          child: Text('${r.waliopo}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: _cTextGrey))),
                      Expanded(
                          flex: 2,
                          child: Text('${r.wanaohamia}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: _cOrange, fontWeight: FontWeight.w800))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      minHeight: 6,
                      backgroundColor: _cBorder,
                      valueColor: const AlwaysStoppedAnimation(_cBlue),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══ DISTRICT TABLE (Watu kwa Wilaya) ════════════════════════════════════════
class DistrictRow {
  final String region;
  final int waliopo;
  final int wanaohamia;
  final int hesabu;
  const DistrictRow(this.region, this.waliopo, this.wanaohamia, this.hesabu);
}

class DistrictTable extends StatelessWidget {
  final String title;
  final List<DistrictRow> rows;
  const DistrictTable({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 44,
          columnSpacing: 22,
          headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12, color: _cTextDark),
          dataTextStyle: const TextStyle(fontSize: 13, color: _cTextDark),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('MKOA/WILAYA')),
            DataColumn(label: Text('WALIOPO'), numeric: true),
            DataColumn(label: Text('WANAOHAMIA'), numeric: true),
            DataColumn(label: Text('HESABU'), numeric: true),
          ],
          rows: List.generate(rows.length, (i) {
            final r = rows[i];
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(r.region)),
              DataCell(Text('${r.waliopo}')),
              DataCell(Text('${r.wanaohamia}',
                  style: const TextStyle(color: _cOrange, fontWeight: FontWeight.w700))),
              DataCell(Text('${r.hesabu}',
                  style: const TextStyle(color: _cBlue, fontWeight: FontWeight.w800))),
            ]);
          }),
        ),
      ),
    );
  }
}

// ═══ MIGRATION SOURCE TABLE (Wanaohamia wanatoka wapi) ═══════════════════════
class MigrationRow {
  final int index;
  final String from;
  final String to;
  final int count;
  const MigrationRow(this.index, this.from, this.to, this.count);
}

class MigrationSourceTable extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<MigrationRow> rows;
  const MigrationSourceTable(
      {super.key, required this.title, required this.subtitle, required this.rows});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: rows.map((r) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _cBorder))),
            child: Row(
              children: [
                SizedBox(width: 26, child: Text('${r.index}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: _cTextDark))),
                Expanded(
                    child: Text(r.from,
                        style: const TextStyle(color: _cTextDark, fontSize: 13.5))),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: _cTextGrey),
                Expanded(
                    child: Text(r.to,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: _cOrange, fontWeight: FontWeight.w600, fontSize: 13.5))),
                const SizedBox(width: 12),
                SizedBox(
                  width: 34,
                  child: Text('${r.count}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: _cBlue, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══ KADA CHIP (users table) ═════════════════════════════════════════════════
class _KadaChip extends StatelessWidget {
  final String label;
  const _KadaChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _cBlueBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 13, color: _cBlue),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _cBlue, fontWeight: FontWeight.w700, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
