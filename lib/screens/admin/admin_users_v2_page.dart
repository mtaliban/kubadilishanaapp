import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/select_sheet.dart';
import 'admin_users_v2_screens.dart';
import 'admin_users_v2_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WATUMIAJI V2 — API halisi na PAGINATION YA SERVER (50/page: Inayofuata/
// Iliyopita), stats chips JUU na idadi halisi kutoka backend, scroll NZIMA —
// hakuna kitu static, foma wala footer iliyobanwa.
// ═══════════════════════════════════════════════════════════════════════════

class AdminUsersV2Page extends StatefulWidget {
  const AdminUsersV2Page({super.key});
  @override
  State<AdminUsersV2Page> createState() => _AdminUsersV2PageState();
}

class _AdminUsersV2PageState extends State<AdminUsersV2Page> {
  static const int _pageSize = 50;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<dynamic> _users = [];
  int _total = 0; // idadi HALISI kutoka backend
  bool _live = false;

  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _msgTimer;
  String? _message;
  VoidCallback? _undoFn;

  String _category = '';
  String? _status; // null=zote, 'active', 'disabled'
  int? _regionId;
  String? _regionName;
  int? _districtId;
  String? _districtName;
  String? _facilityId;
  String? _facilityName;
  String? _subjectCode;
  String? _subjectName;

  List<dynamic> _regions = [];
  List<dynamic> _departments = [];

  final List<Map<String, dynamic>> _trash = [];

  // ── Server pagination ──
  int _page = 0;
  bool get _hasNext => (_page + 1) * _pageSize < _total;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _msgTimer?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    if (mounted) setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _page = 0;
      _load();
    });
  }

  void _flashLive() {
    setState(() => _live = true);
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _live = false);
    });
  }

  // ── Refs (mikoa / idara) ────────────────────────────────────────────────
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
      setState(() => _departments =
          raw is List ? raw : (raw['results'] ?? raw['items'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Map<String, dynamic> get _queryParams {
    final q = _search.text.trim();
    return {
      'limit': _pageSize,
      'skip': _page * _pageSize,
      if (q.isNotEmpty) 'q': q,
      if (_category.isNotEmpty) 'category': _category,
      if (_status != null) 'status': _status!,
      if (_regionId != null) 'region_id': _regionId,
      if (_districtId != null) 'district_id': _districtId,
      if (_facilityId != null) 'facility_id': _facilityId,
      if (_subjectCode != null) 'subject': _subjectCode,
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiService()
          .adminUsers(params: _queryParams, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final map = raw is Map ? raw : {};
      final list =
          (map['users'] ?? (raw is List ? raw : map['data'] ?? map['results'] ?? [])) as List;
      setState(() {
        _users = list;
        _total = (map['total'] as num?)?.toInt() ?? list.length;
        _loading = false;
      });
      _flashLive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _nextPage() async {
    if (_loading || _loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);
    final prevCount = _users.length;
    try {
      _page += 1;
      final r = await ApiService()
          .adminUsers(params: _queryParams, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final map = raw is Map ? raw : {};
      final list =
          (map['users'] ?? (raw is List ? raw : map['data'] ?? map['results'] ?? [])) as List;
      setState(() {
        _users = list;
        _total = (map['total'] as num?)?.toInt() ?? _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _page -= 1; // rudisha ukurasa — jaribu tena
        _loadingMore = false;
      });
      _showMsg('Imeshindikana kupakia ukurasa unaofuata. Jaribu tena.');
      // wasilisha kasoro kwa kutumia prevCount (ili kuepuka unused warning)
      assert(prevCount >= 0);
    }
  }

  Future<void> _prevPage() async {
    if (_loading || _loadingMore || _page == 0) return;
    setState(() => _loadingMore = true);
    try {
      _page -= 1;
      final r = await ApiService()
          .adminUsers(params: _queryParams, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final map = raw is Map ? raw : {};
      final list =
          (map['users'] ?? (raw is List ? raw : map['data'] ?? map['results'] ?? [])) as List;
      setState(() {
        _users = list;
        _total = (map['total'] as num?)?.toInt() ?? _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _showMsg('Imeshindikana kupakia ukurasa uliopita. Jaribu tena.');
    }
  }

  // ── Counts (JUU): kutoka /admin/stats — idadi halisi ──────────────────────
  int _statsTotal = 0, _statsActive = 0, _statsSuspended = 0, _statsAdmin = 0;

  Future<void> _loadCounts() async {
    try {
      final r = await ApiService().adminStats();
      if (!mounted) return;
      final raw = r.data;
      if (raw is! Map) return;
      final totals = (raw['totals'] as Map?) ?? {};
      final byRole = (raw['by_role'] as List?) ?? const [];
      int admins = 0;
      for (final x in byRole) {
        if (x is Map && '${x['is_admin'] ?? x['_id'] ?? ''}' == 'true') {
          admins = ((x['count'] ?? x['n']) as num?)?.toInt() ?? 0;
        }
      }
      final total = (totals['users'] as num?)?.toInt() ?? 0;
      final suspended = (totals['users_suspended'] as num?)?.toInt() ??
          (total - ((totals['users_verified'] as num?)?.toInt() ?? 0));
      setState(() {
        _statsTotal = total;
        _statsSuspended = suspended.clamp(0, total).toInt();
        _statsActive = total - _statsSuspended;
        _statsAdmin = admins;
      });
    } catch (_) {
      // angalizo: inarudi kwa idadi ya ukurasa huu
      setState(() {
        _statsTotal = _total;
        _statsActive = _users.where((u) => '${(u as Map)['status'] ?? 'active'}' == 'active').length;
        _statsSuspended = _users.where((u) => '${(u as Map)['status'] ?? 'active'}' != 'active').length;
        _statsAdmin = _users.where((u) => (u as Map)['is_admin'] == true).length;
      });
    }
  }

  int get _activeFilterCount => [
        _category.isNotEmpty,
        _status != null,
        _regionId != null,
        _districtId != null,
        _facilityId != null,
        _subjectCode != null,
      ].where((e) => e).length;

  void _clearAllFilters() {
    setState(() {
      _category = '';
      _status = null;
      _regionId = null; _regionName = null;
      _districtId = null; _districtName = null;
      _facilityId = null; _facilityName = null;
      _subjectCode = null; _subjectName = null;
      _page = 0;
    });
    _load();
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  String _uid(dynamic u) =>
      (u as Map)['user_id']?.toString() ?? u['_id']?.toString() ?? '';

  String _deptName(String code) {
    for (final d in _departments) {
      if ('${d['code']}' == code) return '${d['display_name'] ?? d['name'] ?? code}';
    }
    if (code == 'health') return 'Afya';
    if (code == 'education') return 'Elimu';
    if (code == 'service') return 'Utumishi';
    return code;
  }

  IconData _deptIcon(String code) {
    switch (code) {
      case 'health':
        return PhosphorIcons.heartbeat();
      case 'education':
        return PhosphorIcons.graduationCap();
      case 'service':
        return PhosphorIcons.briefcase();
      default:
        return PhosphorIcons.buildings();
    }
  }

  Future<void> _deleteUser(String id, String name, String phone) async {
    if (await v2ConfirmDelete(context, jina: name, simu: phone) != true) return;
    try {
      await ApiService().adminDeleteUser(id);
      if (!mounted) return;
      final removed = _users.where((u) => _uid(u) == id).toList();
      setState(() {
        _users.removeWhere((u) => _uid(u) == id);
        _total = (_total - 1).clamp(0, 1 << 30).toInt();
        _statsTotal = (_statsTotal - 1).clamp(0, 1 << 30).toInt();
        _trash.addAll(removed.map(asMap));
      });
      _showMsg('$name amefutwa');
    } catch (e) {
      if (!mounted) return;
      _showMsg('Hitilafu: $e');
    }
  }

  Future<void> _toggleSuspend(Map user) async {
    final active = '${user['status'] ?? 'active'}'.toLowerCase() != 'disabled';
    try {
      await ApiService()
          .adminUpdateUser(_uid(user), {'status': active ? 'disabled' : 'active'});
      if (!mounted) return;
      setState(() => user['status'] = active ? 'disabled' : 'active');
      _showMsg(active ? 'Amesitishwa' : 'Amewezeshwa', undo: () async {
        try {
          await ApiService()
              .adminUpdateUser(_uid(user), {'status': active ? 'active' : 'disabled'});
          if (!mounted) return;
          setState(() => user['status'] = active ? 'active' : 'disabled');
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      _showMsg('Hitilafu: $e');
    }
  }

  Future<void> _toggleContact(Map user) async {
    try {
      await ApiService().adminToggleContact(_uid(user));
      if (!mounted) return;
      final was = user['contact_enabled'] as bool? ?? false;
      setState(() => user['contact_enabled'] = !was);
      _showMsg(was ? 'Haki ya kupiga simu imeondolewa' : 'Ameruhusiwa kupiga simu');
    } catch (e) {
      if (!mounted) return;
      _showMsg('Hitilafu: $e');
    }
  }

  Future<void> _onDotsTap(Map user) async {
    final action = await showV2CardActionsSheet(context, asMap(user));
    if (action == null || !mounted) return;
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? '';
    switch (action) {
      case V2Action.angalia:
        final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => V2UserDetailScreen(user: asMap(user)),
        ));
        if (changed == true) _load();
        break;
      case V2Action.hariri:
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => V2UserFormScreen(existing: asMap(user), regions: _regions),
        ));
        if (saved == true) _load();
        break;
      case V2Action.ruhusu:
        await _toggleContact(user);
        break;
      case V2Action.funga:
        await _toggleSuspend(user);
        break;
      case V2Action.futa:
        await _deleteUser(_uid(user), name, phone);
        break;
    }
  }

  void _showMsg(String msg, {VoidCallback? undo}) {
    _undoFn = undo;
    if (_message == msg) {
      _msgTimer?.cancel();
      setState(() {
        _message = null;
        _undoFn = null;
      });
      return;
    }
    _msgTimer?.cancel();
    setState(() => _message = msg);
    _msgTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _message = null;
          _undoFn = null;
        });
      }
    });
  }

  // ── Add options (+) ──────────────────────────────────────────────────────
  Future<void> _openAddOptions() async {
    final opt = await showV2AddOptionsSheet(context);
    if (opt == null || !mounted) return;
    switch (opt) {
      case V2AddOption.mtumiajiMpya:
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => V2UserFormScreen(regions: _regions),
        ));
        if (saved == true) _load();
        break;
      case V2AddOption.ongezaAdmin:
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => const V2AddAdminScreen(),
        ));
        if (saved == true) _load();
        break;
      case V2AddOption.importWatumiaji:
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => V2ImportScreen(departments: _departments),
        ));
        if (saved == true) _load();
        break;
    }
  }

  // ── Filters sheet (inline — v2 style) ────────────────────────────────────
  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _V2FiltersSheet(parent: this),
    );
  }

  void _applySheetFilters() {
    _page = 0;
    _load();
    _loadCounts();
  }

  // ── Trash sheet (zilizofutwa kipindi hii) ────────────────────────────────
  void _showTrashSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Center(
              child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                      color: v2Border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 12),
          const Text('Zilizofutwa (kipindi hii)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Text(
              'Zimefutwa kweli kwenye server — kurejesha hakipatikani.',
              style: TextStyle(fontSize: 11.5, color: v2TextMuted),
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in _trash)
                  ListTile(
                    dense: true,
                    leading: Icon(PhosphorIcons.user(), size: 18, color: v2TextMuted),
                    title: Text(v2TitleCase('${t['full_name'] ?? ''}'),
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${t['phone_primary'] ?? ''}',
                        style: const TextStyle(fontSize: 11.5, color: v2TextMuted)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _trash.clear());
                  Navigator.pop(ctx);
                },
                child: const Text('Futa orodha'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════ BUILD ═══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final from = _total == 0 ? 0 : _page * _pageSize + 1;
    final to = _page * _pageSize + _users.length;

    return Scaffold(
      // ── Background NYEUPE (siyo bluu) ──
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          const Text('Watumiaji'),
          const SizedBox(width: 8),
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _live ? v2Success : v2TextMuted)),
          const SizedBox(width: 4),
          Text(_live ? 'Live' : 'Offline',
              style: TextStyle(fontSize: 12, color: _live ? v2Success : v2TextMuted)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Zilizofutwa',
            onPressed: _trash.isEmpty ? null : _showTrashSheet,
            icon: Badge(
              label: Text('${_trash.length}'),
              isLabelVisible: _trash.isNotEmpty,
              child: Icon(PhosphorIcons.trash(), size: 20),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        // ── Search + tune ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                    hintText: 'Tafuta jina, simu, kada...',
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: v2SurfaceMuted,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none)),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: v2Accent, borderRadius: BorderRadius.circular(12)),
                child: Stack(children: [
                  Center(
                      child: Icon(PhosphorIcons.funnel(),
                          color: Colors.white, size: 18)),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration:
                            const BoxDecoration(color: v2Danger, shape: BoxShape.circle),
                        child: Center(
                            child: Text('$_activeFilterCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9))),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),

        // ── STATS CHIPS — JUU, na idadi halisi ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _statChip(
                    PhosphorIcons.usersThree(),
                    'Wote',
                    v2FmtNum(_statsTotal),
                    selected: _status == null,
                    onTap: () => _setStatus(null)),
                _statChip(
                    PhosphorIcons.checkCircle(),
                    'Hai',
                    v2FmtNum(_statsActive),
                    selected: _status == 'active',
                    onTap: () => _setStatus('active')),
                _statChip(
                    PhosphorIcons.prohibit(),
                    'Wamesitishwa',
                    v2FmtNum(_statsSuspended),
                    selected: _status == 'disabled',
                    onTap: () => _setStatus('disabled')),
                _statChip(
                    PhosphorIcons.shieldCheck(),
                    'Admin',
                    v2FmtNum(_statsAdmin),
                    selected: false,
                    color: v2Accent,
                    bg: v2AccentBg,
                    onTap: _openAdminFilter),
              ],
            ),
          ),
        ),

        // ── Message bar (na Tendua) ──────────────────────────────────────
        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              decoration: BoxDecoration(
                  color: v2SurfaceMuted, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(
                    child: Text(_message!,
                        style: const TextStyle(fontSize: 13, color: v2TextPrimary))),
                if (_undoFn != null)
                  TextButton(
                    onPressed: () {
                      _msgTimer?.cancel();
                      setState(() => _message = null);
                      _undoFn!();
                    },
                    child: const Text('Tendua',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
              ]),
            ),
          ),

        const Divider(height: 1, color: v2Border),

        // ── List / states — SCROLL NZIMA, hakuna footer static ──────────
        Expanded(
          child: _loading && _users.isEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: 5,
                  itemBuilder: (_, _) => const V2SkeletonCard())
              : _error != null
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      Column(children: [
                        Icon(PhosphorIcons.cloudSlash(),
                            size: 44, color: v2TextMuted),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontSize: 12, color: v2TextMuted)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
                          label: const Text('Jaribu tena'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: v2Accent,
                              foregroundColor: Colors.white),
                        ),
                      ]),
                    ])
                  : _users.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Column(children: [
                            Icon(PhosphorIcons.userFocus(),
                                size: 48, color: v2TextMuted),
                            const SizedBox(height: 12),
                            const Text('Hakuna watumiaji wanaolingana',
                                style: TextStyle(color: v2TextMuted)),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                  onPressed: _clearAllFilters,
                                  child: const Text('Ondoa vichujio')),
                            ],
                          ]),
                        ])
                      : RefreshIndicator(
                          color: v2Accent,
                          onRefresh: () async {
                            await _load();
                            _loadCounts();
                          },
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            itemCount: _users.length,
                            itemBuilder: (context, i) {
                              final u = asMap(_users[i]);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: V2UserCard(
                                  user: u,
                                  timeText: _timeAgo(u),
                                  isNewest: i == 0 && _page == 0,
                                  isLast: i == _users.length - 1,
                                  deptName:
                                      _deptName('${u['category'] ?? ''}'),
                                  deptIcon:
                                      _deptIcon('${u['category'] ?? ''}'),
                                  onDotsTap: () => _onDotsTap(u),
                                ),
                              );
                            },
                          ),
                        ),
        ),

        // ── PAGINATION YA SERVER — chini ya orodha, si static footer ────
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: v2Border))),
            child: Row(children: [
              Expanded(
                child: Text(
                  _total > 0
                      ? 'Watu ${v2FmtNum(from)}–${v2FmtNum(to)} kati ya ${v2FmtNum(_total)}'
                      : 'Hakuna watu',
                  style: const TextStyle(fontSize: 11.5, color: v2TextMuted),
                ),
              ),
              _pageBtn(
                icon: PhosphorIcons.caretLeft(),
                enabled: _page > 0 && !_loadingMore,
                onTap: _prevPage,
              ),
              const SizedBox(width: 10),
              Text('Ukurasa ${_page + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              _pageBtn(
                icon: PhosphorIcons.caretRight(),
                enabled: _hasNext && !_loadingMore,
                onTap: _nextPage,
              ),
            ]),
          ),
        ),
      ]),
      // ── FAB "+" robo tatu ya urefu, kulia (kama prototype) ──
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddOptions,
        backgroundColor: v2Accent,
        shape: const CircleBorder(),
        child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 22),
      ),
    );
  }

  void _setStatus(String? s) {
    setState(() {
      _status = s;
      _page = 0;
    });
    _load();
  }

  Future<void> _openAdminFilter() async {
    setState(() {
      _status = null;
      _page = 0;
    });
    // Onyesha admin PEKEE kwa kutumia is_admin=true (backend)
    setState(() => _loading = true);
    try {
      final p = _queryParams;
      p['is_admin'] = true;
      p['skip'] = 0;
      final r =
          await ApiService().adminUsers(params: p, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final map = raw is Map ? raw : {};
      final list =
          (map['users'] ?? (raw is List ? raw : map['data'] ?? [])) as List;
      setState(() {
        _users = list;
        _total = (map['total'] as num?)?.toInt() ?? list.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _statChip(IconData icon, String label, String count,
      {required bool selected,
      required VoidCallback onTap,
      Color color = v2TextSecondary,
      Color bg = v2SurfaceMuted}) {
    final c = selected ? v2Accent : color;
    final b = selected ? v2AccentBg : bg;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: b,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: selected ? v2Accent : v2Border,
                  width: selected ? 1.2 : 1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
            Text('$label ${count == '0' ? '' : count}'.trim(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c)),
          ]),
        ),
      ),
    );
  }

  Widget _pageBtn({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: enabled ? v2SurfaceMuted : v2Surface,
            border: Border.all(color: enabled ? v2Border : v2Border),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon,
            size: 15, color: enabled ? v2TextPrimary : v2TextMuted),
      ),
    );
  }

  String _timeAgo(Map u) {
    try {
      final raw = u['created_at']?.toString() ?? '';
      if (raw.isEmpty) return '';
      final dt = DateTime.parse(raw).toLocal();
      final d = DateTime.now().difference(dt);
      if (d.inMinutes < 1) return 'sasa hivi';
      if (d.inMinutes < 60) return 'dakika ${d.inMinutes} zilizopita';
      if (d.inHours < 24) return 'saa ${d.inHours} zilizopita';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ═══════════════════════════════ FILTERS SHEET ═══════════════════════════════
class _V2FiltersSheet extends StatefulWidget {
  final _AdminUsersV2PageState parent;
  const _V2FiltersSheet({required this.parent});
  @override
  State<_V2FiltersSheet> createState() => _V2FiltersSheetState();
}

class _V2FiltersSheetState extends State<_V2FiltersSheet> {
  late String _category = widget.parent._category;
  late int? _regionId = widget.parent._regionId;
  late String? _regionName = widget.parent._regionName;
  late int? _districtId = widget.parent._districtId;
  late String? _districtName = widget.parent._districtName;
  late String? _facilityId = widget.parent._facilityId;
  late String? _facilityName = widget.parent._facilityName;
  late String? _subjectCode = widget.parent._subjectCode;
  late String? _subjectName = widget.parent._subjectName;
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    if (_regionId != null) _loadDistricts();
    if (_districtId != null) _loadFacilities();
    if (_category == 'education') _loadSubjects();
  }

  Future<void> _loadDistricts() async {
    if (_regionId == null) return;
    try {
      final r = await ApiService().getDistricts(_regionId!);
      if (!mounted) return;
      final raw = r.data;
      setState(() => _districts = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadFacilities() async {
    if (_districtId == null) return;
    try {
      final cat = _category.isEmpty ? 'health' : _category;
      final r = await ApiService().getFacilities(_districtId!, category: cat);
      if (!mounted) return;
      final raw = r.data;
      setState(
          () => _facilities = raw is List ? raw : (raw['facilities'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadSubjects() async {
    if (_category != 'education') return;
    try {
      final r = await ApiService().getSubjects(level: 'Primary');
      if (!mounted) return;
      final raw = r.data;
      setState(() => _subjects = raw is List ? raw : (raw['subjects'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _pickCategory() async {
    final opts = <({String value, String label, String? subtitle})>[
      const (value: '', label: 'Zote', subtitle: null),
      for (final d in widget.parent._departments)
        (
          value: '${d['code']}',
          label: '${d['display_name'] ?? d['name'] ?? d['code']}',
          subtitle: null
        ),
    ];
    final picked = await showSelectSheet<String>(context,
        title: 'Chagua Idara', items: opts, selected: _category, searchable: false);
    if (picked == null) return;
    setState(() {
      _category = picked;
      _subjects = [];
    });
    if (picked == 'education') _loadSubjects();
  }

  Future<void> _pickRegion() async {
    final picked = await Navigator.of(context).push<({String? id, String? name})>(
      MaterialPageRoute(
        builder: (_) => V2PickerScreen(
          title: 'Chagua Mkoa',
          icon: PhosphorIcons.mapPin(),
          allLabel: 'Mikoa yote',
          options: [
            for (final r in widget.parent._regions)
              (
                id: '${r['id'] ?? r['region_id'] ?? ''}',
                name: '${r['name'] ?? r['region_name'] ?? ''}'
              ),
          ],
          selectedId: _regionId?.toString(),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _regionId = picked.id == null ? null : int.tryParse(picked.id!);
      _regionName = picked.name;
      _districtId = null;
      _districtName = null;
      _facilityId = null;
      _facilityName = null;
      _districts = [];
      _facilities = [];
    });
    if (picked.id != null) _loadDistricts();
  }

  Future<void> _pickDistrict() async {
    if (_regionId == null) return;
    final picked = await Navigator.of(context).push<({String? id, String? name})>(
      MaterialPageRoute(
        builder: (_) => V2PickerScreen(
          title: 'Chagua Wilaya',
          subtitle: 'Ndani ya ${_regionName ?? ''}',
          icon: PhosphorIcons.city(),
          allLabel: 'Wilaya zote',
          options: [
            for (final d in _districts)
              (
                id: '${d['id'] ?? d['district_id'] ?? ''}',
                name: '${d['name'] ?? d['district_name'] ?? ''}'
              ),
          ],
          selectedId: _districtId?.toString(),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _districtId = picked.id == null ? null : int.tryParse(picked.id!);
      _districtName = picked.name;
      _facilityId = null;
      _facilityName = null;
      _facilities = [];
    });
    if (picked.id != null) _loadFacilities();
  }

  Future<void> _pickFacility() async {
    if (_districtId == null) return;
    final picked = await Navigator.of(context).push<({String? id, String? name})>(
      MaterialPageRoute(
        builder: (_) => V2PickerScreen(
          title: 'Chagua Kituo',
          subtitle: 'Ndani ya ${_districtName ?? ''}',
          icon: PhosphorIcons.buildings(),
          allLabel: 'Vituo vyote',
          options: [
            for (final f in _facilities)
              (
                id: '${f['id'] ?? f['code'] ?? ''}',
                name: '${f['name'] ?? f['facility_name'] ?? ''}'
              ),
          ],
          selectedId: _facilityId,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _facilityId = picked.id;
      _facilityName = picked.name;
    });
  }

  Future<void> _pickSubject() async {
    final picked = await Navigator.of(context).push<({String? id, String? name})>(
      MaterialPageRoute(
        builder: (_) => V2PickerScreen(
          title: 'Chagua Somo',
          icon: PhosphorIcons.bookOpen(),
          allLabel: 'Masomo yote',
          options: [
            for (final s in _subjects)
              (
                id: '${s['code'] ?? s['subject_code'] ?? ''}',
                name: '${s['name'] ?? s['subject_name'] ?? ''}'
              ),
          ],
          selectedId: _subjectCode,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _subjectCode = picked.id;
      _subjectName = picked.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parent;
    Widget sel(IconData icon, String label, VoidCallback onTap,
            {bool enabled = true, bool active = false}) =>
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: active ? v2Accent : v2Border,
                      width: active ? 1.4 : 1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(icon,
                    size: 16, color: active ? v2Accent : v2TextSecondary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            color: active ? v2Accent : v2TextPrimary))),
                Icon(PhosphorIcons.caretDown(),
                    size: 14, color: v2TextMuted),
              ]),
            ),
          ),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(PhosphorIcons.funnel(), size: 17, color: v2TextSecondary),
              const SizedBox(width: 10),
              const Text('Vichujio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                onTap: () => setState(() {
                  _category = '';
                  _regionId = null; _regionName = null;
                  _districtId = null; _districtName = null;
                  _facilityId = null; _facilityName = null;
                  _subjectCode = null; _subjectName = null;
                }),
                child: Row(children: [
                  Icon(PhosphorIcons.arrowClockwise(), size: 13, color: v2Accent),
                  SizedBox(width: 4),
                  Text('Futa vyote',
                      style: TextStyle(fontSize: 12, color: v2Accent)),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: v2Border),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IDARA',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMuted)),
                  const SizedBox(height: 8),
                  sel(PhosphorIcons.squaresFour(),
                      _category.isEmpty
                          ? 'Idara zote'
                          : p._deptName(_category),
                      _pickCategory,
                      active: _category.isNotEmpty),
                  const SizedBox(height: 14),
                  const Text('MKOA',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMuted)),
                  const SizedBox(height: 8),
                  sel(PhosphorIcons.mapPin(), _regionName ?? 'Mikoa yote',
                      _pickRegion,
                      active: _regionId != null),
                  const SizedBox(height: 14),
                  const Text('WILAYA',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMuted)),
                  const SizedBox(height: 8),
                  sel(PhosphorIcons.city(), _districtName ?? 'Wilaya zote',
                      _pickDistrict,
                      enabled: _regionId != null, active: _districtId != null),
                  const SizedBox(height: 14),
                  const Text('KITUO / MASOMO',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMuted)),
                  const SizedBox(height: 8),
                  if (_category == 'education')
                    sel(PhosphorIcons.bookOpen(), _subjectName ?? 'Masomo yote',
                        _pickSubject,
                        active: _subjectCode != null)
                  else
                    sel(PhosphorIcons.buildings(), _facilityName ?? 'Vituo vyote',
                        _pickFacility,
                        enabled: _districtId != null,
                        active: _facilityId != null),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: v2Border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      border: Border.all(color: v2Border),
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      Icon(PhosphorIcons.x(), size: 17, color: v2TextSecondary),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  p.setState(() {
                    p._category = _category;
                    p._regionId = _regionId; p._regionName = _regionName;
                    p._districtId = _districtId; p._districtName = _districtName;
                    p._facilityId = _facilityId; p._facilityName = _facilityName;
                    p._subjectCode = _subjectCode; p._subjectName = _subjectName;
                  });
                  p._applySheetFilters();
                  Navigator.of(context).pop();
                },
                icon: Icon(PhosphorIcons.check(), size: 15),
                label: const Text('Tumia'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: v2Accent, foregroundColor: Colors.white),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
