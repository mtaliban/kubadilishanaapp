import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/admin_badge_service.dart';
import '../../services/api_service.dart';
import '../../services/cached_repository.dart';
import '../../services/websocket_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/skeletons.dart';
import 'admin_delete_user_dialog.dart';
import 'admin_filter_users_sheet.dart';
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
  List<dynamic> _users = [];
  int _total = 0;

  /// Jumla ya KWELI kutoka API ('total' ya /admin/users) — inaonekana MARA
  /// MOJA ukurasa ukiwa unafunguka. Full-sync ya nyuma (pages 200-kwa-200)
  /// inajaza orodha tu — namba HAISOMI/KUCOUNT (200→600→1600) tena.
  int? _apiTotal;
  bool _live = false;

  /// Orodha KAMILI ya watumiaji (FULL-SYNC kutoka diski) — pagination
  /// inakuwa slice ya ndani ya hii (SCREEN >>> CACHE >>> BASI).
  List<dynamic> _all = [];

  /// OFFLINE-FIRST: orodha ya mwisho ya watumiaji, kutoka kwenye diski.
  /// Nani anaonekana kwenye _users — bila API _errorNun alozList
  /// aka data diski ipo, orodha inaonekana mara moja.
  static const String _kUsersKey = 'page:admin/users';

  final _search = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;
  Timer? _msgTimer;

  // ── LIVE: orodha inajisasisha wakati watumiaji wanaingia/kuondoka ──
  // (user.registered = mpya, user.updated_by_admin = edit ya admin mwenenzako,
  //  user.removed = umefutwa — list inapakia upya bila refresh mwenyewe)
  void _onWsUsers(Map<String, dynamic> payload) {
    final type = (payload['event'] ?? payload['type'])?.toString() ?? '';
    if (type == 'user.registered' ||
        type == 'user.updated_by_admin' ||
        type == 'user.removed' ||
        type == 'data.changed') {
      if (mounted) _load();
    }
  }
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
  bool _pageLoading = false; // pagination ya kimya (spinner ndogo tu)
  bool get _hasNext => (_page + 1) * _pageSize < _total;

  @override
  void initState() {
    super.initState();
    // DISKI PAPO HAPO — watumiaji wa diski KWA FRAME YA KWANZA (hakuna
    // spring); refresh ya mtandaoni iko nyuma ya pazia.
    CachedRepository().hydrate(_kUsersKey, _applyUsers);
    _load();
    _loadRefs();
    _search.addListener(_onSearch);
    WebSocketService().on('user.registered', _onWsUsers);
    WebSocketService().on('user.updated_by_admin', _onWsUsers);
    WebSocketService().on('user.removed', _onWsUsers);
    WebSocketService().on('data.changed', _onWsUsers);
    // FIX: mtumiaji mpya hana fanout raw kwa ADMIN — backend inamtumea tu
    // 'notification' (type=user.registered). Bila hii, list ya Users page
    // ilinyamaza mpaka event nyingine (edit ya admin mwenenzako) au refresh.
    // _onWsUsers inasoma payload['type'] — inafitana na types zote hapa.
    WebSocketService().on('notification', _onWsUsers);
  }

  @override
  void dispose() {
    WebSocketService().off('user.registered', _onWsUsers);
    WebSocketService().off('user.updated_by_admin', _onWsUsers);
    WebSocketService().off('user.removed', _onWsUsers);
    WebSocketService().off('data.changed', _onWsUsers);
    WebSocketService().off('notification', _onWsUsers);
    _debounce?.cancel();
    _msgTimer?.cancel();
    _liveTimer?.cancel();
    _scrollCtrl.dispose();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() {
    if (mounted) setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      // Search inaf improvedia NDANI ya cache — hakuna mtandao, hakuna loading.
      _page = 0;
      _applyPage();
    });
  }

  Timer? _liveTimer;

  void _flashLive() {
    setState(() => _live = true);
    _liveTimer?.cancel();
    _liveTimer = Timer(const Duration(seconds: 8), () {
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

  /// Diski/API → watumiaji (SYNC: frame ya kwanza, hakuna spring).
  /// Data kamili inaingia _all; slice ya ukurasa inatolewa na _applyPage().
  void _applyUsers(dynamic data) {
    final map = data is Map ? data : const {};
    final list = (map['users'] ??
            (data is List ? data : map['data'] ?? map['results'] ?? const []))
        as List;
    setState(() {
      _all = List<dynamic>.from(list);
      // DISKI: jumla ya KWELI iliyohifadhiwa (total) — inaonekana kwenye
      // frame ya KWANZA, kabla ya API kufungua.
      final t = map['total'];
      if (t is num) {
        final tv = t.toInt();
        if (tv > 0 && tv >= _all.length) _apiTotal = tv;
      }
      _loading = false;
    });
    _applyPage();
  }

  // ── SCREEN >>> CACHE >>> BASI — PAGES ZOTE KWA DISKI ─────────────────────
  // FULL-SYNC inapakia watumiaji WOTE (limit 200, skip loop) kwenye diski
  // MOJO. Pagination inakuwa slice YA NDANI ya orodha hii:
  //   • Kila ukurasa unachapu (frame moja) — hakuna mtandao, hakuna spinner.
  //   • Ukizima data — pages ZOTE 1..N zinaonekana (zilizohifadhiwa).
  //   • Vichujio + search — vinafanyika NDANI ya cache (hakuna API).

  /// Vichujio vyote vinafanywa NDANI ya cache — hakuna mtandao kabisa.
  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty &&
        _category.isEmpty &&
        _status == null &&
        _regionId == null &&
        _districtId == null &&
        _facilityId == null &&
        _subjectCode == null) {
      return _all;
    }

    return _all.where((u) {
      final m = u is Map ? u : <dynamic, dynamic>{};
      if (q.isNotEmpty) {
        final hay = '${m['full_name'] ?? ''} ${m['phone_primary'] ?? ''} '
                '${m['cadre_display'] ?? m['cadre_code'] ?? ''}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (_category.isNotEmpty && '${m['category'] ?? ''}' != _category) {
        return false;
      }
      if (_status != null &&
          '${m['status'] ?? 'active'}'.toLowerCase() !=
              _status!.toLowerCase()) {
        return false;
      }
      final st = (m['current_station'] as Map?) ?? const {};
      if (_regionId != null && '${st['region_id'] ?? ''}' != '$_regionId') {
        return false;
      }
      if (_districtId != null &&
          '${st['district_id'] ?? ''}' != '$_districtId') {
        return false;
      }
      if (_facilityId != null &&
          '${st['facility_id'] ?? ''}' != '$_facilityId') {
        return false;
      }
      if (_subjectCode != null) {
        final subs = (m['subjects'] as List?) ?? const [];
        final ok = subs.any((s) => s is Map
            ? '${s['code'] ?? s['subject_code'] ?? s['name'] ?? ''}' ==
                _subjectCode
            : '$s' == _subjectCode);
        if (!ok) return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// Namba ya stats card: jumla ya KWELI (API ya ukurasa wa kwanza ama diski)
  /// pale vichujio havipo — thamani moja, hakuna kuhesabu kutoka 0. Vichujio
  /// vikipita, tunarudisha idadi ya orodha iliyochujwa (kama mwanzo).
  int get _displayTotal {
    final hasFilters = _search.text.trim().isNotEmpty ||
        _category.isNotEmpty ||
        _status != null ||
        _regionId != null ||
        _districtId != null ||
        _facilityId != null ||
        _subjectCode != null;
    return (!hasFilters && _apiTotal != null) ? _apiTotal! : _total;
  }

  /// Ukurasa wa sasa = slice YA NDANI ya orodha kamili (SCREEN >> CACHE).
  void _applyPage() {
    if (!mounted) return;
    final filtered = _filtered;
    final total = filtered.length;
    final maxPage = total == 0 ? 0 : (total - 1) ~/ _pageSize;
    final page = _page.clamp(0, maxPage);
    final start = page * _pageSize;
    setState(() {
      if (page != _page) _page = page;
      _total = total;
      _users = start >= total
          ? <dynamic>[]
          : filtered.sublist(start, (start + _pageSize).clamp(0, total));
      _loading = false;
      _pageLoading = false;
    });
  }

  Future<void> _load() async {
    // FULL-SYNC: pages ZOTE (limit 200 mfululizo) → DISKI → SCREEN.
    // Skrini haitenzi kamwe: kila kitu kinaonyeshwa kutoka cache (hydrate,
    // onProgress, write) — SCREEN >>> CACHE >>> BASI. Ikishindikana
    // (offline) skrini HAKIBADILIKI: data ya diski inabaki kama ilivyo.
    await CachedRepository().syncAll(
      _kUsersKey,
      fetchPage: (limit, skip) async {
        final res = await ApiService()
            .adminUsers(params: {'limit': limit, 'skip': skip}, useCache: false);
        // Jumla ya KWELI inajulikana kutoka ukurasa wa KWANZA ('total') —
        // pima & onyesha PAPO HAPO; sehemu zilizobaki (200→1600) ni
        // mtandao nyuma ya pazia tu, namba haabadiliki tena.
        if (skip == 0 && mounted && res.data is Map) {
          final t = (res.data as Map)['total'];
          final tv = t is num ? t.toInt() : null;
          if (tv != null && tv > 0 && tv != _apiTotal) {
            setState(() => _apiTotal = tv);
          }
        }
        return res.data;
      },
      pack: (all) => {'users': all, 'total': all.length},
      onProgress: (soFar) {
        if (!mounted) return;
        setState(() => _all = List<dynamic>.from(soFar));
        _applyPage();
      },
    );
    if (!mounted) return;
    final fresh = CachedRepository().readOrNull<dynamic>(_kUsersKey);
    if (fresh != null) _applyUsers(fresh);
  }

  void _fetchPage(int page) {
    if (page < 0) return;
    // SCREEN >>> CACHE >>> BASI: ukurasa unatoka slice ya ndani ya orodha
    // iliyohifadhiwa diski — PAPO HAPO (frame moja), hakuna mtandao,
    // hakuna spinner, inafanya kazi hata kizima data.
    if (page == _page) return;
    _page = page;
    _applyPage();
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
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
    // Vichujio vinafanywa NDANI ya orodha kamili — PAPO HAPO, hakuna mtandao.
    _applyPage();
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
        if (_apiTotal != null) {
          _apiTotal = (_apiTotal! - 1).clamp(0, 1 << 30).toInt();
        }
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
        // Mtumiaji mpya — form kamili ya V2 (V2UserFormScreen) inayotuma
        // API halisi (adminCreateUser). Kurasa za zamani zilikuwa na
        // onSave tupu — data haikuwahi kufika server.
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => V2UserFormScreen(regions: _regions),
        ));
        if (saved == true) {
          _showMsg('Mtumiaji ameongezwa');
          AdminBadgeService().refresh();
        }
        _load();
        break;
      case V2AddOption.ongezaAdmin:
        // Admin mpya — V2AddAdminScreen inatumia adminCreateUser(is_admin:true)
        // na email inahitajika (backend inahitaji email kwa admin).
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => const V2AddAdminScreen(),
        ));
        if (saved == true) {
          _showMsg('Admin ameongezwa');
          _load();
        }
        break;
      case V2AddOption.importWatumiaji:
        // Import ya Excel — V2ImportScreen inatumia adminImportUsersFile
        // (upload halisi kwa /admin/users/import).
        final imported = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => V2ImportScreen(departments: _departments),
        ));
        if (imported == true) {
          _showMsg('Watumiwa wameagizwa');
          _load();
        }
        break;
    }
  }

  // ── FILTERS SHEET ───────────────────────────────────────────────────────

  // Wilaya za kila mkoa — zinapakiwa kutoka API /locations/regions/{id}/districts
  // mtumiaji akichagua mkoa (zimetunzwa hapa ili sheet kazi zitumie).
  final Map<String, List<String>> _wilayaCache = {};

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
      // Wilaya zinapakiwa KWA API mkoa ukiuchagua (getDistricts) —
      // hakuna tena orodha tupu ya wilaya.
      wilaya: _wilayaCache,
      onWilayaLoad: _loadWilayaFor,
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
        // Vichujio vinafanywa NDANI ya orodha kamili — PAPO HAPO (hakuna mtandao).
        _page = 0;
        _applyPage();
      },
    );
  }

  /// Pakia wilaya za mkoa (jina) kutoka API — hurudisha orodha ya majina.
  /// Matokeo yanatunzwa kwenye _wilayaCache ili sheet kazi nayo iyatumie.
  Future<List<String>> _loadWilayaFor(String? mkoaName) async {
    if (mkoaName == null) return const [];
    if (_wilayaCache[mkoaName] != null) return _wilayaCache[mkoaName]!;
    final region = _regions.firstWhere(
      (r) => '${r['name'] ?? r['region_name'] ?? ''}' == mkoaName,
      orElse: () => <String, dynamic>{},
    );
    final rId = region['id'] != null ? int.tryParse('${region['id']}') : null;
    if (rId == null) return const [];
    try {
      final r = await ApiService().getDistricts(rId);
      final raw = r.data;
      final list = (raw is List
              ? raw
              : (raw['districts'] ?? raw['data'] ?? []) as List)
          .map((d) => '${d['name'] ?? d['district_name'] ?? ''}')
          .where((s) => s.isNotEmpty)
          .toList();
      _wilayaCache[mkoaName] = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  void _applySheetFilters() {
    // Vichujio vinafanywa NDANI ya orodha kamili — PAPO HAPO (cache ndiyo screen).
    _page = 0;
    _applyPage();
  }

  // ── TRASH SHEET ─────────────────────────────────────────────────────────

  void _showTrashSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: v2SurfaceOf(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 14),
          Center(
              child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                      color: v2BorderOf(context),
                      borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 12),
          const Text('Zilizofutwa (kipindi hii)',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Text(
              'Zimefutwa kweli kwenye server — kurejesha hakipatikani.',
              style: TextStyle(fontSize: 11.5, color: v2TextMutedOf(context)),
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
                    leading: Icon(TablerIcons.user,
                        size: 18, color: v2TextMutedOf(context)),
                    title:
                        Text(v2TitleCase('${t['full_name'] ?? ''}'),
                            style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${t['phone_primary'] ?? ''}',
                        style: TextStyle(
                            fontSize: 11.5, color: v2TextMutedOf(context))),
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
      backgroundColor: v2SurfaceOf(context),
      body: SafeArea(
        child: Stack(
          children: [
            _loading && _users.isEmpty
                ? _buildSkeleton()
                : RefreshIndicator(
                    color: v2AccentOf(context),
                    onRefresh: _load,
                    child: _buildScrollBody(),
                  ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              right: 16,
              child: FloatingActionButton(
                onPressed: _openAddOptions,
                backgroundColor: v2AccentOf(context),
                shape: const CircleBorder(),
                elevation: 4,
                child: Icon(TablerIcons.plus, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollBody() {
    return ListView(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        // ── Stats card ──
        _statsCard(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: v2SurfaceOf(context),
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

              // ── Data haijapakuliwa / empty / timeline ──
              if (!_loading && _users.isEmpty &&
                  CachedRepository().readOrNull<dynamic>(_kUsersKey) == null)
                const WatumiajiSkeleton()
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
        color: v2SurfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: v2BorderOf(context), width: 0.8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v2FmtNum(_displayTotal),
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: v2TextPrimaryOf(context),
                    height: 1.0)),
            const SizedBox(height: 4),
            Text('Watumiaji Wote',
                style: TextStyle(
                    fontSize: 12.5,
                    color: v2TextSecondaryOf(context),
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
                      style: TextStyle(
                          color: Colors.white, fontSize: 9)),
                  isLabelVisible: _trash.isNotEmpty,
                  backgroundColor: v2DangerOf(context),
                  child: Icon(PhosphorIcons.trash(),
                      size: 22,
                      color: _trash.isEmpty ? v2TextMutedOf(context) : v2DangerOf(context)),
                ),
              ),
            ]),
          ]),
        ),
        SizedBox(width: 12),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: v2AccentBgOf(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.fill),
              size: 28, color: v2AccentOf(context)),
        ),
      ]),
    );
  }

  Widget _livePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _live ? v2SuccessBgOf(context) : v2SurfaceMutedOf(context),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _live ? v2SuccessOf(context) : v2TextMutedOf(context),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 5),
        Text(_live ? 'Live' : 'Offline',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _live ? v2SuccessOf(context) : v2TextMutedOf(context))),
      ]),
    );
  }

  // ── MESSAGE BAR ──
  Widget _messageBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
          color: v2SurfaceOf(context), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(
            child: Text(_message!,
                style: TextStyle(
                    fontSize: 12.5, color: v2TextPrimaryOf(context)))),
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
            color: v2SurfaceOf(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: v2BorderOf(context)),
          ),
          child: TextField(
            controller: _search,
            style: TextStyle(fontSize: 13, color: v2TextPrimaryOf(context)),
            decoration: InputDecoration(
              hintText: 'Tafuta jina, simu, kada...',
              hintStyle: TextStyle(
                  fontSize: 13, color: v2TextMutedOf(context)),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(PhosphorIcons.magnifyingGlass(),
                    size: 16, color: v2TextMutedOf(context)),
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
            color: v2AccentOf(context),
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
                  decoration: BoxDecoration(
                      color: v2DangerOf(context), shape: BoxShape.circle),
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

  // ── ERROR ──
  // (imetolewa — offline-first: data ya diski haibadiliki; ikiongeza online
  // refresh inapita. Hii imebaki kama utafutaji wa internal, si skrini.)

  Widget _emptyBox() {
    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        Icon(PhosphorIcons.userFocus(), size: 44, color: v2TextMutedOf(context)),
        const SizedBox(height: 10),
        Text('Hakuna watumiaji wanaolingana',
            style: TextStyle(fontSize: 13.5, color: v2TextSecondaryOf(context))),
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
    final canPrev = _page > 0 && !_pageLoading;
    final canNext = _hasNext && !_pageLoading;

    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: v2BorderOf(context), width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Iliyopita — Flexible+FittedBox: haikiuki kwenye simu ndogo/font kubwa
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _pageBtn(
                label: 'Iliyopita',
                icon: PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                iconLeft: true,
                filled: false,
                enabled: canPrev,
                onTap: () => _fetchPage(_page - 1),
              ),
            ),
          ),
          // Ukurasa N / M
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _loading ? '…' : '$current / $totalPages',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: v2TextSecondaryOf(context)),
              ),
            ),
          ),
          // Inayofuata
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _pageBtn(
                label: 'Inayofuata',
                icon: PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                iconLeft: false,
                filled: true,
                enabled: canNext,
                onTap: () => _fetchPage(_page + 1),
              ),
            ),
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
    final fgEnabled = filled ? Colors.white : v2AccentOf(context);
    final fg = enabled ? fgEnabled : v2TextMutedOf(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? v2AccentOf(context) : v2BorderOf(context))
              : Colors.transparent,
          border: filled ? null : Border.all(color: enabled ? v2AccentOf(context) : v2BorderOf(context)),
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
  // Skeleton ya Watumiaji = UTAMBO ULEULE wa ukurasa halisi (muundo na pimo):
  // stats card (namba + 'Watumiaji Wote' + pill/duara 58×58), search + funnel,
  // kadi za timeline (dot + jina/kada + muda + pill), na row ya kurasa.
  // Bone/SkeletonScope = kung'aa + ku-move kama upepo (shimmer) kama skeletons
  // zingine zote za app.
  Widget _buildSkeleton() {
    Widget cardBone({EdgeInsets? padding, required Widget child}) => Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: v2SurfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: v2BorderOf(context), width: 0.8),
          ),
          child: child,
        );

    // Kadi ya mstari wa timeline (dot + jina/kada + muda + pill ya hali).
    Widget rowCard() => cardBone(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Bone.circle(34),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(widthFactor: 0.55, height: 15),
                  SizedBox(height: 6),
                  Bone(widthFactor: 0.36, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Bone(width: 52, height: 10),
                SizedBox(height: 6),
                Bone(width: 62, height: 22, radius: 11),
              ],
            ),
          ]),
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        SkeletonScope(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats card — namba kubwa, lebo, pill + duara 58×58 ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: v2SurfaceOf(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: v2BorderOf(context), width: 0.8),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Bone(width: 96, height: 34, radius: 10),
                        const SizedBox(height: 6),
                        const Bone(width: 112, height: 13),
                        const SizedBox(height: 12),
                        Row(children: const [
                          Bone(width: 64, height: 24, radius: 12),
                          SizedBox(width: 10),
                          Bone(width: 34, height: 22, radius: 8),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Bone(width: 58, height: 58, radius: 16),
                ]),
              ),
              const SizedBox(height: 10),
              // ── Search + funnel ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: v2SurfaceOf(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: Bone(height: 40, radius: 8)),
                      const SizedBox(width: 8),
                      const Bone(width: 40, height: 40, radius: 8),
                    ]),
                    const SizedBox(height: 14),
                    for (var i = 0; i < _pageSize; i++) ...[
                      rowCard(),
                      const SizedBox(height: 2),
                    ],
                    const SizedBox(height: 10),
                    // ── Ukurasa N / M ──
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: v2BorderOf(context), width: 0.5)),
                      ),
                      child: Row(children: [
                        // Flexible+FittedBox: haikiuki kwenye simu ndogo 320
                        // (kama row halisi ya kurasa).
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Bone(width: 104, height: 38, radius: 19),
                          ),
                        ),
                        const Spacer(),
                        const Bone(width: 44, height: 13),
                        const Spacer(),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Bone(width: 118, height: 38, radius: 19),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      if (code.isEmpty) return v2SurfaceMutedOf(context);
      if (code == 'health') {
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3A1D1B)
            : const Color(0xFFFFF1F2);
      }
      if (code == 'education') return v2AccentBgOf(context);
      if (code == 'service') {
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF14532D)
            : const Color(0xFFF0FDF4);
      }
      return v2SurfaceMutedOf(context);
    }
    Color _dFg(String code) {
      if (code.isEmpty) return v2TextSecondaryOf(context);
      if (code == 'health') {
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFF87171)
            : const Color(0xFFDC2626);
      }
      if (code == 'education') return v2AccentOf(context);
      if (code == 'service') {
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF86EFAC)
            : const Color(0xFF16A34A);
      }
      return v2TextSecondaryOf(context);
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
                  color: active ? v2AccentBgOf(context) : v2SurfaceOf(context),
                  border: Border.all(
                      color: active
                          ? v2AccentOf(context)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? v2BorderOf(context)
                              : const Color(0xFFD1D9E6)),
                      width: active ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(icon,
                    size: 16, color: active ? v2AccentOf(context) : v2TextSecondaryOf(context)),
                SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            color: active ? v2AccentOf(context) : v2TextPrimaryOf(context)))),
                Icon(PhosphorIcons.caretDown(),
                    size: 14, color: v2TextMutedOf(context)),
              ]),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: v2SurfaceOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                  size: 17, color: v2TextSecondaryOf(context)),
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
                      size: 13, color: v2AccentOf(context)),
                  const SizedBox(width: 4),
                  Text('Futa vyote',
                      style:
                          TextStyle(fontSize: 12, color: v2AccentOf(context))),
                ]),
              ),
            ]),
          ),
          Divider(height: 1, color: v2BorderOf(context)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IDARA',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMutedOf(context))),
                  const SizedBox(height: 8),
                  sel(PhosphorIcons.squaresFour(),
                      _category.isEmpty
                          ? 'Idara zote'
                          : p._deptName(_category),
                      _pickCategory,
                      active: _category.isNotEmpty),
                  const SizedBox(height: 14),
                  Text('MKOA',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMutedOf(context))),
                  const SizedBox(height: 8),
                  sel(PhosphorIcons.mapPin(), _regionName ?? 'Mikoa yote',
                      _pickRegion,
                      active: _regionId != null),
                  const SizedBox(height: 14),
                  Text('WILAYA',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMutedOf(context))),
                  const SizedBox(height: 8),
                  sel(PhosphorIcons.city(), _districtName ?? 'Wilaya zote',
                      _pickDistrict,
                      enabled: _regionId != null,
                      active: _districtId != null),
                  const SizedBox(height: 14),
                  Text('KITUO / MASOMO',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: v2TextMutedOf(context))),
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
                  SizedBox(height: 6),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: v2BorderOf(context)),
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
                      border: Border.all(color: v2BorderOf(context)),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(PhosphorIcons.x(),
                      size: 17, color: v2TextSecondaryOf(context)),
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
                label: Text('Tumia'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: v2AccentOf(context),
                    foregroundColor: Colors.white),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
