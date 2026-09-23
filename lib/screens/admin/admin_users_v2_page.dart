import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/select_sheet.dart';
import 'admin_add_admin_page.dart';
import 'admin_add_user_page.dart';
import 'admin_delete_user_dialog.dart';
import 'admin_filter_users_sheet.dart';
import 'admin_import_users_page.dart';
import 'admin_users_v2_screens.dart';
import 'admin_view_user_page.dart';
import 'admin_users_v2_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WATUMIAJI (Admin) — MOCKUP TIMELINE LAYOUT:
//   Header (Watumiaji + Live pill) · Jumla ya watumiaji: N ·
//   Search + funnel button · Timeline rows (dot + mstari + muda + jina +
//   kada · mkoa + pill ya hali + ⋮) · Ukurasa N / M pagination ·
//   Kitufe cha "+".
// API halisi zote zinafanya kazi (search, filters, actions, pagination).
// ═══════════════════════════════════════════════════════════════════════════

class AdminUsersV2Page extends StatefulWidget {
  const AdminUsersV2Page({super.key});
  @override
  State<AdminUsersV2Page> createState() => _AdminUsersV2PageState();
}

class _AdminUsersV2PageState extends State<AdminUsersV2Page> {
  bool _loading = true;
  String? _error;
  List<dynamic> _users = [];
  int _total = 0;
  bool _live = false;

  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _msgTimer;
  String? _message;
  VoidCallback? _undoFn;

  String _category = '';
  String? _status;
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

  static const int _pageSize = 4; // users 4 tu kwa screen
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

  // ── DATA ────────────────────────────────────────────────────────────────

  Future<void> _loadRefs() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      setState(
          () => _regions = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []));
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
      final r =
          await ApiService().adminUsers(params: _queryParams, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final map = raw is Map ? raw : {};
      final list = (map['users'] ??
          (raw is List ? raw : map['data'] ?? map['results'] ?? [])) as List;
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

  Future<void> _fetchPage(int page) async {
    if (page < 0) return;
    setState(() => _loading = true);
    final old = _page;
    _page = page;
    try {
      final r =
          await ApiService().adminUsers(params: _queryParams, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final map = raw is Map ? raw : {};
      final list = (map['users'] ??
          (raw is List ? raw : map['data'] ?? map['results'] ?? [])) as List;
      setState(() {
        _users = list;
        _total = (map['total'] as num?)?.toInt() ?? _total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _page = old;
        _loading = false;
      });
      _showMsg('Imeshindikana kupakia ukurasa. Jaribu tena.');
    }
  }

  // ── FILTERS ─────────────────────────────────────────────────────────────

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

  // ── HELPERS ─────────────────────────────────────────────────────────────

  String _uid(dynamic u) =>
      (u as Map)['user_id']?.toString() ?? u['_id']?.toString() ?? '';

  static UserDetails _toUserDetails(Map<String, dynamic> u) {
    final station = (u['current_station'] as Map?) ?? {};
    final dests = ((u['desired_destinations'] ?? u['destinations']) as List?) ?? [];
    final subjects = (u['subjects'] as List?) ?? [];
    final createdRaw = u['created_at']?.toString() ?? '';
    DateTime created;
    try {
      created = DateTime.parse(createdRaw).toLocal();
    } catch (_) {
      created = DateTime.now();
    }
    return UserDetails(
      name: '${u['full_name'] ?? ''}',
      idara: '${u['category'] ?? u['department'] ?? ''}',
      kada: '${u['cadre_display'] ?? u['cadre_code'] ?? u['designation'] ?? ''}',
      employer: u['employer']?.toString(),
      masomo: subjects.map((s) {
        if (s is Map) return '${s['code'] ?? s['name'] ?? s}';
        return '$s';
      }).toList(),
      phone: '${u['phone_primary'] ?? ''}',
      whatsapp: u['phone_alt']?.toString() ?? u['phone_whatsapp']?.toString(),
      mkoa: station['region_name']?.toString(),
      wilaya: station['district_name']?.toString(),
      kituo: station['facility_name']?.toString(),
      destinations: dests.map<(String, String)>((d) {
        if (d is Map) {
          return (
            '${d['district_name'] ?? d['district'] ?? ''}',
            '${d['region_name'] ?? d['region'] ?? ''}',
          );
        }
        return ('', '$d');
      }).toList(),
      active: '${u['status'] ?? 'active'}'.toLowerCase() != 'disabled',
      paid: u['is_paid'] as bool? ?? u['is_verified'] as bool? ?? false,
      verified: u['is_verified'] as bool? ?? false,
      hasPassword: u['has_password'] as bool? ?? false,
      contactAllowed: u['contact_enabled'] as bool? ?? false,
      role: u['is_admin'] as bool? ?? false ? 'Admin' : 'Mtumiaji',
      createdAt: created,
      seenBy: (u['seen_by_count'] ?? u['seen_by'] ?? 0) as int? ?? 0,
      online: u['is_online'] as bool? ?? false,
    );
  }

  String _deptName(String code) {
    for (final d in _departments) {
      if ('${d['code']}' == code) {
        return '${d['display_name'] ?? d['name'] ?? code}';
      }
    }
    if (code == 'health') return 'Afya';
    if (code == 'education') return 'Elimu';
    if (code == 'service') return 'Utumishi';
    return code;
  }

  String _relativeTime(Map u) {
    try {
      final raw = u['created_at']?.toString() ?? '';
      if (raw.isEmpty) return '';
      final dt = DateTime.parse(raw).toLocal();
      final d = DateTime.now().difference(dt);
      if (d.inMinutes < 1) return 'Sasa hivi';
      if (d.inMinutes < 60) return 'Dakika ${d.inMinutes} zilizopita';
      if (d.inHours < 24) return 'Saa ${d.inHours} zilizopita';
      if (d.inDays == 1) return 'Jana';
      if (d.inDays < 7) return 'Siku ${d.inDays} zilizopita';
      final weeks = (d.inDays / 7).floor();
      if (weeks < 4) return weeks == 1 ? 'Wiki 1 iliyopita' : 'Wiki $weeks zilizopita';
      final months = (d.inDays / 30).floor();
      return months <= 1 ? 'Mwezi 1 uliopita' : 'Miezi $months iliyopita';
    } catch (_) {
      return '';
    }
  }

  // ── ACTIONS ─────────────────────────────────────────────────────────────

  Future<void> _deleteUser(String id, String name, String phone) async {
    if (!await showDeleteUserDialog(context, name: name)) return;
    try {
      await ApiService().adminDeleteUser(id);
      if (!mounted) return;
      final removed = _users.where((u) => _uid(u) == id).toList();
      setState(() {
        _users.removeWhere((u) => _uid(u) == id);
        _total = (_total - 1).clamp(0, 1 << 30).toInt();
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
          await ApiService().adminUpdateUser(
              _uid(user), {'status': active ? 'active' : 'disabled'});
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
        final usr = Map<String, dynamic>.from(asMap(user));
        await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (detailCtx) => UserDetailsPage(
            user: _toUserDetails(usr),
            onEdit: () {
              Navigator.of(detailCtx).push<bool>(MaterialPageRoute(
                builder: (_) =>
                    V2UserFormScreen(existing: usr, regions: _regions),
              )).then((saved) {
                if (saved == true && mounted) {
                  if (detailCtx.mounted) Navigator.of(detailCtx).pop();
                  _load();
                }
              });
            },
            onDelete: () async {
              if (detailCtx.mounted) Navigator.of(detailCtx).pop();
              await _deleteUser(_uid(usr), '${usr['full_name'] ?? ''}',
                  '${usr['phone_primary'] ?? ''}');
            },
            onToggleLock: () => _toggleSuspend(usr),
          ),
        ));
        break;
      case V2Action.hariri:
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) =>
              V2UserFormScreen(existing: asMap(user), regions: _regions),
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

  // ── ADD OPTIONS (+) ─────────────────────────────────────────────────────

  Future<void> _openAddOptions() async {
    final opt = await showV2AddOptionsSheet(context);
    if (opt == null || !mounted) return;
    switch (opt) {
      case V2AddOption.mtumiajiMpya:
        await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => NewUserPage(onSave: (data) async { /* tuma kwenye API */ }),
        ));
        _load();
        break;
      case V2AddOption.ongezaAdmin:
        await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => AddAdminPage(onSave: (d) async { /* d.name, d.email, d.phone, d.password */ }),
        ));
        _load();
        break;
      case V2AddOption.importWatumiaji:
        await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => ImportUsersPage(
            onTemplateReady: (bytes, jina) async { /* hifadhi au shiriki kiolezo */ },
            onImport: (idara, safu) async { /* tuma kwenye API */ },
          ),
        ));
        _load();
        break;
    }
  }

  // ── FILTERS SHEET ───────────────────────────────────────────────────────

  Future<void> _openFilters() async {
    final mikoa = _regions
        .map((r) => '${r['name'] ?? r['region_name'] ?? ''}')
        .where((s) => s.isNotEmpty)
        .toList();

    // Geuza category code -> UserFilter idara key
    String? _toIdaraKey(String cat) => switch (cat.toLowerCase()) {
          'health' => 'afya',
          'education' => 'elimu',
          'agriculture' => 'kilimo',
          'service' || 'public' => 'umma',
          _ => cat.isEmpty ? null : cat,
        };
    String _fromIdaraKey(String? key) => switch (key) {
          'afya' => 'health',
          'elimu' => 'education',
          'kilimo' => 'agriculture',
          'umma' => 'service',
          _ => key ?? '',
        };

    final initial = UserFilter(
      idara: _toIdaraKey(_category),
      mkoa: _regionName,
      wilaya: _districtName,
      kituo: _subjectName ?? _facilityName,
    );

    await showUserFilterSheet(
      context,
      initial: initial,
      mikoa: mikoa,
      wilaya: const {}, // wilaya zinapakiwa API — zinapanuliwa baadaye
      vituo: const {},
      masomo: const [],
      onChanged: (f) {
        // Mapper: jina la mkoa -> region object
        final region = _regions.firstWhere(
          (r) => '${r['name'] ?? r['region_name'] ?? ''}' == f.mkoa,
          orElse: () => <String, dynamic>{},
        );
        final rId = region['id'] != null ? int.tryParse('${region['id']}') : null;

        setState(() {
          _category = _fromIdaraKey(f.idara);
          _regionId = rId;
          _regionName = f.mkoa;
          if (f.mkoa == null) {
            _districtId = null;
            _districtName = null;
            _facilityId = null;
            _facilityName = null;
            _subjectCode = null;
            _subjectName = null;
          }
        });
        _page = 0;
        _load();
      },
    );
  }

  void _applySheetFilters() {
    _page = 0;
    _load();
  }

  // ── TRASH SHEET ─────────────────────────────────────────────────────────

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
                      color: v2Border,
                      borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 12),
          const Text('Zilizofutwa (kipindi hii)',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                    leading: Icon(PhosphorIcons.user(),
                        size: 18, color: v2TextMuted),
                    title:
                        Text(v2TitleCase('${t['full_name'] ?? ''}'),
                            style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${t['phone_primary'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11.5, color: v2TextMuted)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Stack(
          children: [
            _loading && _users.isEmpty
                ? _buildSkeleton()
                : RefreshIndicator(
                    color: v2Accent,
                    onRefresh: _load,
                    child: _buildScrollBody(),
                  ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              right: 16,
              child: FloatingActionButton(
                onPressed: _openAddOptions,
                backgroundColor: v2Accent,
                shape: const CircleBorder(),
                elevation: 4,
                child: Icon(PhosphorIcons.plus(), color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollBody() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        // ── Stats card ──
        _statsCard(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Message bar (na Tendua) ──
              if (_message != null) ...[
                _messageBar(),
                const SizedBox(height: 10),
              ],
              // ── Search + funnel ──
              _searchRow(),
              const SizedBox(height: 14),

              // ── Error / empty / timeline ──
              if (_error != null)
                _errorBox()
              else if (!_loading && _users.isEmpty)
                _emptyBox()
              else
                _buildTimeline(),

              const SizedBox(height: 14),
              // ── Ukurasa N / M ──
              _paginationRow(),
            ],
          ),
        ),
      ],
    );
  }

  // ── STATS CARD ──
  Widget _statsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: v2Border, width: 0.8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v2FmtNum(_total),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: v2TextPrimary,
                    height: 1.0)),
            const SizedBox(height: 4),
            const Text('Watumiaji Wote',
                style: TextStyle(
                    fontSize: 12.5,
                    color: v2TextSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Row(children: [
              _livePill(),
              const SizedBox(width: 10),
              InkWell(
                onTap: _trash.isEmpty ? null : _showTrashSheet,
                borderRadius: BorderRadius.circular(8),
                child: Badge(
                  label: Text('${_trash.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9)),
                  isLabelVisible: _trash.isNotEmpty,
                  backgroundColor: v2Danger,
                  child: Icon(PhosphorIcons.trash(),
                      size: 17,
                      color: _trash.isEmpty ? v2TextMuted : v2Danger),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: v2AccentBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
              size: 28, color: v2Accent),
        ),
      ]),
    );
  }

  Widget _livePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _live ? v2SuccessBg : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _live ? v2Success : v2TextMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(_live ? 'Live' : 'Offline',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _live ? v2Success : v2TextMuted)),
      ]),
    );
  }

  // ── MESSAGE BAR ──
  Widget _messageBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(
            child: Text(_message!,
                style: const TextStyle(
                    fontSize: 12.5, color: v2TextPrimary))),
        if (_undoFn != null)
          TextButton(
            onPressed: () {
              _msgTimer?.cancel();
              setState(() => _message = null);
              _undoFn!();
            },
            child: const Text('Tendua',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
      ]),
    );
  }

  // ── SEARCH ROW ──
  Widget _searchRow() {
    return Row(children: [
      Expanded(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: v2Border),
          ),
          child: TextField(
            controller: _search,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tafuta jina, simu, kada...',
              hintStyle: const TextStyle(
                  fontSize: 13, color: v2TextMuted),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(PhosphorIcons.magnifyingGlass(),
                    size: 16, color: v2TextMuted),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 38, minHeight: 0),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      InkWell(
        onTap: _openFilters,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: v2Accent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(children: [
            Center(
                child: Icon(PhosphorIcons.funnel(),
                    size: 16, color: Colors.white)),
            if (_activeFilterCount > 0)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                      color: v2Danger, shape: BoxShape.circle),
                  child: Center(
                      child: Text('$_activeFilterCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8.5))),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  // ── DEPT ICON ──
  IconData _deptIcon(String code) {
    if (code == 'health') return PhosphorIcons.heartbeat();
    if (code == 'education') return PhosphorIcons.graduationCap();
    return PhosphorIcons.briefcase();
  }

  IconData _userDeptIcon(Map user) {
    final cat = '${user['category'] ?? ''}';
    final cadre = '${user['cadre_display'] ?? user['cadre_code'] ?? ''}'.toLowerCase();
    if (cat == 'health') return PhosphorIcons.heartbeat();
    if (cat == 'education') {
      if (cadre.contains('secondary') || cadre.contains('sekondari') || cadre.contains('sec'))
        return PhosphorIcons.graduationCap();
      return PhosphorIcons.bookOpen();
    }
    if (cat == 'service') return PhosphorIcons.buildings();
    return PhosphorIcons.briefcase();
  }

  // ── CARDS ──
  Widget _buildTimeline() {
    return Column(
      children: [
        for (int i = 0; i < _users.length; i++)
          V2UserCard(
            user: asMap(_users[i]),
            timeText: _relativeTime(asMap(_users[i])),
            isNewest: _page == 0 && i == 0,
            isLast: i == _users.length - 1,
            deptName: _deptName('${asMap(_users[i])['category'] ?? ''}'),
            deptIcon: _userDeptIcon(asMap(_users[i])),
            onDotsTap: () => _onDotsTap(asMap(_users[i])),
          ),
      ],
    );
  }

  // ── ERROR / EMPTY ──
  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(PhosphorIcons.cloudSlash(), size: 40, color: v2TextMuted),
        const SizedBox(height: 10),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: v2TextMuted)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _load,
          icon: Icon(PhosphorIcons.arrowClockwise(), size: 15),
          label: const Text('Jaribu tena'),
          style: ElevatedButton.styleFrom(
              backgroundColor: v2Accent, foregroundColor: Colors.white),
        ),
      ]),
    );
  }

  Widget _emptyBox() {
    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        Icon(PhosphorIcons.userFocus(), size: 44, color: v2TextMuted),
        const SizedBox(height: 10),
        const Text('Hakuna watumiaji wanaolingana',
            style: TextStyle(fontSize: 13.5, color: v2TextSecondary)),
        if (_activeFilterCount > 0) ...[
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _clearAllFilters,
              child: const Text('Ondoa vichujio')),
        ],
      ]),
    );
  }

  // ── PAGINATION ──
  Widget _paginationRow() {
    final totalPages =
        ((_total / _pageSize).ceil()).clamp(1, 999999).toInt();
    final current = _page + 1;
    final canPrev = _page > 0 && !_loading;
    final canNext = _hasNext && !_loading;

    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: v2Border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Iliyopita
          _pageBtn(
            label: 'Iliyopita',
            icon: PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            iconLeft: true,
            filled: false,
            enabled: canPrev,
            onTap: () => _fetchPage(_page - 1),
          ),
          // Ukurasa N / M
          Text(
            _loading ? '…' : '$current / $totalPages',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: v2TextSecondary),
          ),
          // Inayofuata
          _pageBtn(
            label: 'Inayofuata',
            icon: PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
            iconLeft: false,
            filled: true,
            enabled: canNext,
            onTap: () => _fetchPage(_page + 1),
          ),
        ],
      ),
    );
  }

  Widget _pageBtn({
    required String label,
    required IconData icon,
    required bool iconLeft,
    required bool filled,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final fgEnabled = filled ? Colors.white : v2Accent;
    final fg = enabled ? fgEnabled : v2TextMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? v2Accent : v2Border)
              : Colors.transparent,
          border: filled ? null : Border.all(color: enabled ? v2Accent : v2Border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (iconLeft) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg)),
          if (!iconLeft) ...[
            const SizedBox(width: 5),
            Icon(icon, size: 13, color: fg),
          ],
        ]),
      ),
    );
  }

  // ── SKELETON ──
  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        Container(
          height: 108,
          decoration: BoxDecoration(
            color: v2Border.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                      color: v2Border.withValues(alpha: .5),
                      borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 16),
                for (int i = 0; i < _pageSize; i++) const V2SkeletonCard(),
              ]),
        ),
      ],
    );
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
  bool _loadingFacilities = false;

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
      setState(() =>
          _districts = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _loadFacilities() async {
    if (_districtId == null) return;
    if (mounted) setState(() => _loadingFacilities = true);
    try {
      final cat = _category.isEmpty ? 'health' : _category;
      final r =
          await ApiService().getFacilities(_districtId!, category: cat);
      if (!mounted) return;
      final raw = r.data;
      setState(() {
        _facilities =
            raw is List ? raw : (raw['facilities'] ?? raw['data'] ?? []);
        _loadingFacilities = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFacilities = false);
    }
  }

  Future<void> _loadSubjects() async {
    if (_category != 'education') return;
    try {
      final r = await ApiService().getSubjects(level: 'Primary');
      if (!mounted) return;
      final raw = r.data;
      setState(() =>
          _subjects = raw is List ? raw : (raw['subjects'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _pickCategory() async {
    IconData _dIcon(String code) {
      if (code.isEmpty) return PhosphorIcons.squaresFour();
      if (code == 'health') return PhosphorIcons.heartbeat();
      if (code == 'education') return PhosphorIcons.bookOpen();
      if (code == 'service') return PhosphorIcons.buildings();
      return PhosphorIcons.briefcase();
    }
    Color _dBg(String code) {
      if (code.isEmpty) return v2SurfaceMuted;
      if (code == 'health') return const Color(0xFFFFF1F2);
      if (code == 'education') return v2AccentBg;
      if (code == 'service') return const Color(0xFFF0FDF4);
      return v2SurfaceMuted;
    }
    Color _dFg(String code) {
      if (code.isEmpty) return v2TextSecondary;
      if (code == 'health') return const Color(0xFFDC2626);
      if (code == 'education') return v2Accent;
      if (code == 'service') return const Color(0xFF16A34A);
      return v2TextSecondary;
    }
    final items = [
      (value: '', label: 'Idara Zote', icon: _dIcon(''), iconBg: _dBg(''), iconFg: _dFg('')),
      for (final d in widget.parent._departments)
        (
          value: '${d['code']}',
          label: '${d['display_name'] ?? d['name'] ?? d['code']}',
          icon: _dIcon('${d['code']}'),
          iconBg: _dBg('${d['code']}'),
          iconFg: _dFg('${d['code']}'),
        ),
    ];
    final picked = await showV2IconPicker(context,
        title: 'Chagua Idara', items: items, selected: _category.isEmpty ? null : _category);
    if (picked == null) return;
    setState(() {
      _category = picked;
      _subjects = [];
      _facilityId = null;
      _facilityName = null;
      _facilities = [];
    });
    if (picked == 'education') {
      _loadSubjects();
    }
    if (_districtId != null) {
      _loadFacilities();
    }
  }

  Future<void> _pickRegion() async {
    final picked =
        await Navigator.of(context).push<({String? id, String? name})>(
      MaterialPageRoute(
        builder: (_) => V2PickerScreen(
          title: 'Chagua Mkoa',
          icon: PhosphorIcons.mapPin(),
          allLabel: 'Mikoa yote',
          options: [
            for (final r in widget.parent._regions)
              (
                id: '${r['id'] ?? r['region_id'] ?? ''}',
                name: '${r['name'] ?? r['region_name'] ?? ''}',
                subtitle: null,
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
    final picked =
        await Navigator.of(context).push<({String? id, String? name})>(
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
                name: '${d['name'] ?? d['district_name'] ?? ''}',
                subtitle: null,
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
    final facIcon = _category == 'health'
        ? PhosphorIcons.heartbeat()
        : _category == 'education'
            ? PhosphorIcons.graduationCap()
            : PhosphorIcons.buildings();
    final picked =
        await Navigator.of(context).push<({String? id, String? name})>(
      MaterialPageRoute(
        builder: (_) => V2PickerScreen(
          title: 'Chagua Kituo',
          subtitle: 'Ndani ya ${_districtName ?? ''}',
          icon: facIcon,
          allLabel: 'Vituo vyote',
          options: [
            for (final f in _facilities)
              (
                id: '${f['id'] ?? f['code'] ?? ''}',
                name: '${f['name'] ?? f['facility_name'] ?? ''}',
                subtitle: f['type'] as String?,
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
    final picked =
        await Navigator.of(context).push<({String? id, String? name})>(
      MaterialPageRoute(
        builder: (_) => V2PickerScreen(
          title: 'Chagua Somo',
          icon: PhosphorIcons.bookOpen(),
          allLabel: 'Masomo yote',
          options: [
            for (final s in _subjects)
              (
                id: '${s['code'] ?? s['subject_code'] ?? ''}',
                name: '${s['name'] ?? s['subject_name'] ?? ''}',
                subtitle: null,
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
                  color: active ? v2AccentBg : Colors.white,
                  border: Border.all(
                      color: active ? v2Accent : const Color(0xFFD1D9E6),
                      width: active ? 1.5 : 1),
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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child:
            Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(PhosphorIcons.funnel(),
                  size: 17, color: v2TextSecondary),
              const SizedBox(width: 10),
              const Text('Vichujio',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
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
                  Icon(PhosphorIcons.arrowClockwise(),
                      size: 13, color: v2Accent),
                  const SizedBox(width: 4),
                  const Text('Futa vyote',
                      style:
                          TextStyle(fontSize: 12, color: v2Accent)),
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
                      enabled: _regionId != null,
                      active: _districtId != null),
                  const SizedBox(height: 14),
                  const Text('KITUO / MASOMO',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMuted)),
                  const SizedBox(height: 8),
                  if (_category == 'education')
                    sel(PhosphorIcons.bookOpen(),
                        _subjectName ?? 'Masomo yote', _pickSubject,
                        active: _subjectCode != null),
                  if (_category == 'education') const SizedBox(height: 8),
                  if (_category != 'education' || _districtId != null)
                    sel(
                        _category == 'health'
                            ? PhosphorIcons.heartbeat()
                            : _category == 'education'
                                ? PhosphorIcons.graduationCap()
                                : PhosphorIcons.buildings(),
                        _loadingFacilities
                            ? 'Inapakia vituo...'
                            : (_facilityName ?? 'Vituo vyote'),
                        _pickFacility,
                        enabled: _districtId != null && !_loadingFacilities,
                        active: _facilityId != null),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: v2Border),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
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
                  child: Icon(PhosphorIcons.x(),
                      size: 17, color: v2TextSecondary),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  p.setState(() {
                    p._category = _category;
                    p._regionId = _regionId;
                    p._regionName = _regionName;
                    p._districtId = _districtId;
                    p._districtName = _districtName;
                    p._facilityId = _facilityId;
                    p._facilityName = _facilityName;
                    p._subjectCode = _subjectCode;
                    p._subjectName = _subjectName;
                  });
                  p._applySheetFilters();
                  Navigator.of(context).pop();
                },
                icon: Icon(PhosphorIcons.check(), size: 15),
                label: const Text('Tumia'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: v2Accent,
                    foregroundColor: Colors.white),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
