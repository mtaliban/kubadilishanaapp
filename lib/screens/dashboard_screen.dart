import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/safe_cast.dart';
import '../services/websocket_service.dart';
import '../widgets/app_shell.dart';
import 'user_dashboard_view.dart';

const _kFreshMs = 30; // dakika — MPYA badge

/// Tambua kama jina ni default/placeholder (mfano 'CO — 5', 'Mwana Afya 3') — kama web isDefaultName.
bool isDefaultName(String name) {
  final n = name.trim().toLowerCase();
  if (RegExp(r'\d+$').hasMatch(n)) {
    final base = n.replaceAll(RegExp(r'\d+$'), '').trim();
    const prefixes = ['mwana afya', 'mwanafunzi', 'mwuguzi', 'mwalimu', 'mganga', 'mpgasii', 'mlinzii', 'mhudumu', 'mtumishi', 'afya mwananchi', 'afya ya jamii'];
    for (final p in prefixes) { if (base.startsWith(p) || base == p) return true; }
  }
  if (RegExp(r'^[a-z]+\s*[-—–]\s*\d+$').hasMatch(n)) return true;
  return false;
}

bool _isFresh(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return false;
  try {
    return DateTime.now().difference(DateTime.parse(isoDate).toLocal()).inMinutes < _kFreshMs;
  } catch (_) { return false; }
}

// ── normPlace: "mbinga Dc" → "Mbinga DC", "dar ES salaam" → "Dar es Salaam" ───
String _normPlace(String v) => v.trim().split(RegExp(r'\s+')).map((w) {
      final l = w.toLowerCase();
      if (const {'dc', 'tc', 'mc', 'cc'}.contains(l)) return l.toUpperCase();
      if (l == 'es') return 'es';
      return w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _candidates = [];
  List<dynamic> _trueMatches = [];
  bool _loading = true;

  List<dynamic> _announcements = [];

  // ── Server-side filter (mikoa YOTE + wilaya za mkoa kwa API) ──
  List<String> _allRegions = const [];
  final Map<String, int> _regionIds = {};
  String? _filterRegion;
  List<String> _filterDistricts = const [];
  final Map<String, int> _districtIds = {};
  String? _filterDistrict;
  bool _loadingDistricts = false;

  // Global toast (juu ya screen) — kwa payment/contact_toggled notifications
  String? _globalToast;
  Timer? _globalToastTimer;

  // ── WS listeners zilizopewa jina — kwa kuzifuta kwenye dispose ─────────
  // (bila hii, kila ukifungua dashboard listeners mpya zinajongezwa —
  //  events zinakua, API calls zinajirudia, toasts zinatokea mara mbili)
  void _onMatchFound(Map<String, dynamic> _) { _loadBoard(); _loadTrueMatches(); }
  void _onUserRegistered(Map<String, dynamic> _) { _loadBoard(); _loadTrueMatches(); }
  void _onUserChanged(Map<String, dynamic> _) => _loadBoard();
  void _onUserRemoved(Map<String, dynamic> _) => _loadBoard();
  void _onUserProfileUpdated(Map<String, dynamic> _) { _loadBoard(); _loadTrueMatches(); }
  void _onContactToggled(Map<String, dynamic> payload) {
    context.read<AuthProvider>().refreshUser().then((_) {
      if (!mounted) return;
      final enabled = payload['contact_enabled'] == true;
      if (enabled) {
        _showGlobalToast('✅ Admin amefungua namba — sasa unaweza kuwasiliana!');
      }
    });
    _loadBoard();
  }
  void _onAnnouncement(Map<String, dynamic> _) => _loadAnnouncements();
  void _onWsNotification(Map<String, dynamic> payload) {
    final type = (payload['type'] as String?) ?? '';
    // Badge bump — AppShell BadgeService inashughulikia global badges
    BadgeService().bump(type);
  }

  @override
  void dispose() {
    final ws = WebSocketService();
    ws.off('match.found', _onMatchFound);
    ws.off('user.registered', _onUserRegistered);
    ws.off('user.changed', _onUserChanged);
    ws.off('user.removed', _onUserRemoved);
    ws.off('user.profile_updated', _onUserProfileUpdated);
    ws.off('contact.toggled', _onContactToggled);
    ws.off('announcement', _onAnnouncement);
    ws.off('announcement.new', _onAnnouncement);
    ws.off('notification', _onWsNotification);
    _globalToastTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInit();
    _loadRegions();
    _setupRealtime();
  }

  /// Mikoa YOTE ya Tanzania kutoka /locations/regions — kwa ajili ya
  /// kichujio cha dashibodi (chips). Bila hii chips zinaonyesha mikoa
  /// ya wenzio waliofanana tu.
  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw is Map ? raw['regions'] ?? raw['data'] : null) as List? ?? []);
      if (!mounted) return;
      final names = <String>[];
      final ids = <String, int>{};
      for (final r in list) {
        if (r is! Map) continue;
        final name = '${r['name'] ?? r['region_name'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final id = int.tryParse('${r['id'] ?? r['region_id'] ?? ''}');
        if (id == null) continue;
        names.add(name);
        ids[name] = id;
      }
      names.sort();
      setState(() {
        _allRegions = names;
        _regionIds.addAll(ids);
      });
    } catch (_) {
      // kimya — chips zitatumia mikoa ya peers (fallback ya ndani)
    }
  }

  /// Wilaya zote za mkoa — API /locations/regions/{id}/districts.
  Future<void> _onRegionTap(String? name) async {
    if (name == _filterRegion) return;
    setState(() {
      _filterRegion = name;
      _filterDistrict = null;
      _filterDistricts = const [];
    });
    if (name == null) return _loadBoard();
    final rid = _regionIds[name];
    if (rid == null) return _loadBoard();
    setState(() => _loadingDistricts = true);
    try {
      final res = await ApiService().getDistricts(rid);
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw is Map ? raw['districts'] ?? raw['data'] : null) as List? ?? []);
      if (!mounted) return;
      final names = <String>[];
      final dids = <String, int>{};
      for (final d in list) {
        if (d is! Map) continue;
        final n = '${d['name'] ?? d['district_name'] ?? ''}'.trim();
        if (n.isEmpty) continue;
        final id = int.tryParse('${d['id'] ?? d['district_id'] ?? ''}');
        if (id == null) continue;
        names.add(n);
        dids[n] = id;
      }
      names.sort();
      setState(() {
        _filterDistricts = names;
        _districtIds
          ..clear()
          ..addAll(dids);
        _loadingDistricts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDistricts = false);
    }
    _loadBoard();
  }

  void _onDistrictPick(String? name) {
    setState(() => _filterDistrict = name);
    _loadBoard();
  }

  Future<void> _loadInit() async {
    // Refresh user profile first to ensure currentStation is populated
    if (mounted) {
      await context.read<AuthProvider>().refreshUser();
    }
    await Future.wait([
      _loadBoard(),
      _loadTrueMatches(),
      _loadAnnouncements(),
    ]);
  }

  Future<void> _loadBoard() async {
    if (mounted) setState(() => _loading = true);
    try {
      // Vichujio vya server: mkoa/wilaya vinafanywa kwenye API
      // (source_region_id / district_id kwenye current_station ya kila mtu).
      final rid = _filterRegion == null ? null : _regionIds[_filterRegion];
      final did = _filterDistrict == null ? null : _districtIds[_filterDistrict];
      final res = await ApiService().get('/matches/board',
          queryParameters: {
            'scope': 'incoming',
            'limit': 100,
            if (rid != null) 'source_region_id': rid,
            if (did != null) 'district_id': did,
          });
      final data = asMap(res.data);
      if (mounted) {
        setState(() {
          // Sort: wapya (fresh) juu, kisha online, kama web sortFreshToTop
          final raw = data['candidates'] ?? [];
          _candidates = [...raw]..sort((a, b) {
            final fa = _isFresh(a['created_at'] ?? a['joined_at']);
            final fb = _isFresh(b['created_at'] ?? b['joined_at']);
            if (fa != fb) return fa ? -1 : 1;
            final oa = a['online'] == true, ob = b['online'] == true;
            if (oa != ob) return oa ? -1 : 1;
            return 0;
          });
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _loadTrueMatches() async {
    try {
      final res = await ApiService().getTrueMatches(limit: 30);
      final data = asMap(res.data);
      if (mounted) setState(() => _trueMatches = data['matches'] ?? []);
    } catch (_) {}
  }

  Future<void> _loadAnnouncements() async {
    try {
      final res = await ApiService().getAnnouncements();
      final data = asMap(res.data);
      if (mounted) setState(() => _announcements = data['announcements'] ?? data['items'] ?? []);
    } catch (_) {}
  }

  void _setupRealtime() {
    final ws = WebSocketService();
    ws.on('match.found', _onMatchFound);
    ws.on('user.registered', _onUserRegistered);
    ws.on('user.changed', _onUserChanged);
    ws.on('user.removed', _onUserRemoved);
    ws.on('user.profile_updated', _onUserProfileUpdated);
    ws.on('contact.toggled', _onContactToggled);
    ws.on('announcement', _onAnnouncement);
    ws.on('announcement.new', _onAnnouncement);
    ws.on('notification', _onWsNotification);
  }

  void _showGlobalToast(String msg) {
    _globalToastTimer?.cancel();
    if (mounted) {
      setState(() => _globalToast = msg);
      _globalToastTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _globalToast = null);
      });
    }
  }

  // ── Kuchanganya matangazo (dedup kama web: title+message key) ────────────
  List<dynamic> get _dedupedAnnouncements {
    final seen = <String, dynamic>{};
    for (final item in _announcements) {
      final key = '${item['title'] ?? ''}|${item['message'] ?? item['body'] ?? ''}';
      final existing = seen[key];
      if (existing == null) {
        seen[key] = item;
      } else {
        final a = DateTime.tryParse(item['created_at'] ?? '') ?? DateTime(0);
        final b = DateTime.tryParse(existing['created_at'] ?? '') ?? DateTime(0);
        if (a.isAfter(b)) seen[key] = item;
      }
    }
    return seen.values.toList();
  }

  // ── Mappers: data za API → models za UserDashboardView ──────────────────
  static String _yearsLabel(dynamic years) {
    if (years == null) return '';
    if (years == 3) return 'miaka 3 au zaidi';
    if (years == 1) return 'mwaka 1';
    return 'miaka $years';
  }

  static String _idaraOf(dynamic category) {
    final c = '${category ?? ''}'.trim().toLowerCase();
    if (c == 'education' || c == 'elimu') return 'elimu';
    if (c == 'health' || c == 'afya') return 'afya';
    return c;
  }

  Peer _mapPeer(dynamic card) {
    final station = asMap(card['current_station']);
    final dests = asList(card['desired_destinations']);
    final matching = card['matching_destination'];
    final activeDest = matching ?? (dests.isNotEmpty ? dests.first : null);
    final dest = activeDest is Map ? asMap(activeDest) : <String, dynamic>{};
    final createdAt =
        DateTime.tryParse('${card['created_at'] ?? card['joined_at'] ?? ''}') ??
            DateTime.now();
    final exp = _yearsLabel(card['years_of_service']);
    final phoneAlt = '${card['phone_alt'] ?? ''}';
    return Peer(
      name: '${card['full_name'] ?? 'Mtumiaji'}',
      idara: _idaraOf(card['category']),
      kada: '${card['cadre_display'] ?? card['cadre_code'] ?? ''}',
      createdAt: createdAt,
      fromMkoa: _normPlace('${station['region_name'] ?? ''}'),
      fromWilaya: _normPlace('${station['district_name'] ?? ''}'),
      fromKituo: (station['facility_name'] ?? station['name'])?.toString(),
      toWilaya: (dest['district_name'] ?? '').toString().isEmpty
          ? null
          : '${dest['district_name']}',
      subjects:
          asList(card['subjects']).map((s) => s.toString()).toList(),
      experience: exp.isEmpty ? null : exp,
      phone: '${card['phone_primary'] ?? ''}',
      whatsapp: phoneAlt.isEmpty ? null : phoneAlt,
    );
  }

  DashMe _mapMe(AuthUser? user, bool paid) {
    final station = user?.currentStation ?? {};
    return DashMe(
      name: user?.fullName ?? 'Mtumiaji',
      idara: _idaraOf(user?.category),
      kada: user?.cadreDisplay ?? user?.cadreCode ?? '',
      subjects: user?.subjects ?? const [],
      mkoa: _normPlace('${station['region_name'] ?? ''}'),
      wilaya: _normPlace('${station['district_name'] ?? ''}'),
      paid: paid,
      wantedRegions: user?.wantedRegions ?? const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isPaid = auth.isVerified ||
        (user?.contactEnabled ?? false) ||
        isDefaultName(user?.fullName ?? '');

    final me = _mapMe(user, isPaid);
    final peers = [
      ..._candidates.map(_mapPeer),
      ..._trueMatches.map(_mapPeer),
    ];

    // Matangazo — juu ya dashibodi (top ya UserDashboardView)
    final top = _dedupedAnnouncements
        .map((a) => DashboardAnnouncement(
              title: '${a['title'] ?? ''}',
              message: '${a['message'] ?? a['body'] ?? ''}',
              kind: announcementKindFrom('${a['kind'] ?? a['type'] ?? 'taarifa'}'),
              date: DateTime.tryParse('${a['created_at'] ?? ''}'),
              onClose: () async {
                final id = '${a['announcement_id'] ?? a['_id'] ?? ''}';
                if (id.isEmpty) return;
                try {
                  await ApiService().dismissAnnouncement(id);
                } catch (_) {}
                if (mounted) {
                  setState(() => _announcements.removeWhere(
                      (x) => '${x['announcement_id'] ?? x['_id'] ?? ''}' == id));
                }
              },
            ))
        .toList();

    return AppShell(
      tabIndex: 0,
      child: Stack(children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () => Future.wait([_loadBoard(), _loadTrueMatches()]),
            child: (_loading && _candidates.isEmpty)
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  )
                : UserDashboardView(
                    me: me,
                    peers: peers,
                    top: top,
                    allRegions: _allRegions,
                    activeRegion: _filterRegion,
                    activeRegionDistricts: _filterDistricts,
                    activeDistrict: _filterDistrict,
                    onRegionTap: _onRegionTap,
                    onDistrictPick: _onDistrictPick,
                    onChangia: () => Navigator.pushNamed(context, '/donate'),
                  ),
          ),
        ),
        // Global toast — payment/contact_toggled notification (iko juu ya screen)
        if (_globalToast != null)
          Positioned(
            top: 12, left: 16, right: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF), // brand-blue
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_globalToast!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () { _globalToastTimer?.cancel(); setState(() => _globalToast = null); },
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
