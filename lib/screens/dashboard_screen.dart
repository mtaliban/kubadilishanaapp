import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/select_sheet.dart';

// WhatsApp SVG paths (white = FAB, dark = small contact button)
const _kWaSvg = '''<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="white" d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.52.149-.174.198-.298.297-.497.1-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>''';

const _kAdminPhone = '0763795801';
const _kWaGroup = 'https://chat.whatsapp.com/Gm43LFnroiZLV9wynX3FpP';
const _kFreshMs = 30; // dakika — MPYA badge

String _initials(String name) {
  final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return 'M';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

String _timeAgo(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';
  try {
    final d = DateTime.parse(isoDate).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Sasa hivi';
    if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes}';
    if (diff.inHours < 24) return 'saa ${diff.inHours}';
    return 'siku ${diff.inDays}';
  } catch (_) { return ''; }
}

bool _isFresh(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return false;
  try {
    return DateTime.now().difference(DateTime.parse(isoDate).toLocal()).inMinutes < _kFreshMs;
  } catch (_) { return false; }
}

String _fullDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '';
  try {
    final d = DateTime.parse(isoDate).toLocal();
    const months = ['Jan','Feb','Mac','Apr','Mei','Jun','Jul','Ago','Sep','Okt','Nov','Des'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) { return ''; }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _candidates = [];
  List<dynamic> _trueMatches = [];
  int _boardTotal = 0;
  bool _loading = true;
  bool _showTrueMatches = true;
  int _page = 1;
  static const _pageSize = 5;

  List<dynamic> _announcements = [];

  // Filters
  List<dynamic> _regions = [];
  List<dynamic> _districts = [];
  List<dynamic> _facilities = [];
  List<dynamic> _cadres = [];
  String _regionSel = '__all__';
  int? _districtId;
  String? _facilityId;
  String _cadreCode = '';
  String _subjectFilter = 'off';
  String _subjectQ = '';

  final _subjectQCtrl = TextEditingController();

  // Toast ndani ya card (local — siyo global WS toast ambayo iko AppShell)
  String? _toastUserId;
  String? _toastMsg;
  Timer? _toastTimer;

  // Global toast (juu ya screen) — kwa payment/contact_toggled notifications
  String? _globalToast;
  Timer? _globalToastTimer;

  @override
  void dispose() {
    _subjectQCtrl.dispose();
    _toastTimer?.cancel();
    _globalToastTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInit();
    _setupRealtime();
  }

  Future<void> _loadInit() async {
    await Future.wait([
      _loadBoard(),
      _loadTrueMatches(),
      _loadAnnouncements(),
      _loadRegions(),
      _loadCadres(),
    ]);
  }


  Future<void> _loadBoard() async {
    if (mounted) setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'scope': 'incoming', 'limit': 100};
      if (_regionSel != '__all__' && _regionSel.isNotEmpty) {
        params['region_ids'] = _regionSel;
      }
      if (_districtId != null) params['district_id'] = _districtId;
      if (_facilityId != null) params['facility_id'] = _facilityId;
      if (_cadreCode.isNotEmpty) params['cadre_code'] = _cadreCode;
      if (_subjectFilter != 'off') params['subject_filter'] = _subjectFilter;
      if (_subjectQ.trim().isNotEmpty) params['subject_q'] = _subjectQ.trim();

      final res = await ApiService().get('/matches/board', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _candidates = data['candidates'] ?? [];
          _boardTotal = data['total'] ?? _candidates.length;
          _page = 1;
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
      final data = res.data as Map<String, dynamic>;
      if (mounted) setState(() => _trueMatches = data['matches'] ?? []);
    } catch (_) {}
  }

  Future<void> _loadAnnouncements() async {
    try {
      final res = await ApiService().getAnnouncements();
      final data = res.data as Map<String, dynamic>;
      if (mounted) setState(() => _announcements = data['announcements'] ?? data['items'] ?? []);
    } catch (_) {}
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      if (mounted) setState(() => _regions = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _loadCadres() async {
    try {
      final auth = context.read<AuthProvider>();
      final cat = auth.user?.category;
      final res = await ApiService().getCadres(category: auth.isAdmin ? null : cat);
      if (mounted) setState(() => _cadres = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _loadDistricts(int regionId) async {
    try {
      final res = await ApiService().getDistricts(regionId);
      if (mounted) setState(() => _districts = res.data as List? ?? []);
    } catch (_) {}
  }

  Future<void> _loadFacilities(int districtId) async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await ApiService().getFacilities(districtId,
          category: auth.user?.category ?? 'health');
      if (mounted) setState(() => _facilities = res.data as List? ?? []);
    } catch (_) {}
  }

  void _setupRealtime() {
    final ws = WebSocketService();
    ws.on('match.found', (_) { _loadBoard(); _loadTrueMatches(); });
    ws.on('user.registered', (_) { _loadBoard(); _loadTrueMatches(); });
    ws.on('user.changed', (_) => _loadBoard());
    ws.on('user.removed', (_) => _loadBoard());
    ws.on('user.profile_updated', (_) { _loadBoard(); _loadTrueMatches(); });
    ws.on('contact.toggled', (payload) {
      context.read<AuthProvider>().refreshUser().then((_) {
        if (!mounted) return;
        final enabled = payload['contact_enabled'] == true;
        if (enabled) {
          _showGlobalToast('✅ Admin amefungua namba — sasa unaweza kuwasiliana!');
        }
      });
      _loadBoard();
    });
    ws.on('announcement', (_) => _loadAnnouncements());
    ws.on('announcement.new', (_) => _loadAnnouncements());
    ws.on('notification', (payload) {
      final type = (payload['type'] as String?) ?? '';
      // Badge bump — AppShell BadgeService inashughulikia global badges
      BadgeService().bump(type);
    });
  }

  void _clearFilters() {
    _subjectQCtrl.clear();
    setState(() {
      _regionSel = '__all__';
      _districtId = null;
      _facilityId = null;
      _cadreCode = '';
      _subjectFilter = 'off';
      _subjectQ = '';
      _districts = [];
      _facilities = [];
    });
    _loadBoard();
  }

  void _showCardToast(String msg, String uid) {
    // Cancel previous timer, clear first (re-animation trick kama web), then set
    _toastTimer?.cancel();
    setState(() { _toastMsg = null; _toastUserId = null; });
    Future.microtask(() {
      if (!mounted) return;
      setState(() { _toastMsg = msg; _toastUserId = uid; });
      _toastTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() { _toastMsg = null; _toastUserId = null; });
      });
    });
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

  List<dynamic> get _pagedCandidates {
    final start = (_page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _candidates.length);
    return _candidates.sublist(start.clamp(0, _candidates.length), end);
  }

  int get _totalPages => (_candidates.length / _pageSize).ceil().clamp(1, 9999);

  // Grid responsive kama web: minmax(165px,1fr) — cols inabadilika na ukubwa wa skrini
  List<Widget> _buildGrid(List<dynamic> cards, bool isPaid, List<String> mySubjects,
      String myRegionName, AuthUser? user, {int cols = 1}) {
    final myUserId = user?.userId ?? '';
    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += cols) {
      final slice = cards.sublist(i, (i + cols).clamp(0, cards.length));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              if (j < slice.length)
                Expanded(child: _BoardCard(
                  card: slice[j], isPaid: isPaid, mySubjects: mySubjects, myRegionName: myRegionName,
                  myName: user?.fullName ?? '', myCadre: user?.cadreDisplay ?? user?.cadreCode ?? '',
                  myStation: myRegionName, myUserId: myUserId,
                  toast: _toastUserId == (slice[j]['user_id'] ?? '') ? _toastMsg : null,
                  onContact: (type) => _onContact(slice[j], type, user),
                  onToast: (msg) => _showCardToast(msg, slice[j]['user_id'] ?? ''),
                ))
              else
                const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ));
      rows.add(const SizedBox(height: 10));
    }
    return rows;
  }

  // Hesabu ya wapya (ndani ya dakika 30)
  int get _freshCount => _candidates.where((c) => _isFresh(c['created_at'] ?? c['joined_at'])).length;
  int get _onlineCount => _candidates.where((c) => c['online'] == true).length;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final station = user?.currentStation ?? {};
    final initial = _initials(user?.fullName ?? 'M');
    final isPaid = auth.isVerified || (user?.contactEnabled ?? false);
    final mySubjects = user?.subjects ?? [];
    final myRegionName = station['region_name'] as String? ?? '';
    final isEdu = auth.isAdmin || (user?.category != 'health');

    // Source region name kwa LIVE panel
    final regionName = _regionSel == '__all__'
        ? 'Mikoa Yote'
        : (_regions.firstWhere((r) => '${r['id']}' == _regionSel, orElse: () => null)?['name'] ?? 'Mikoa Yote');

    return AppShell(
      tabIndex: 0,
      child: Stack(children: [
        Positioned.fill(child: RefreshIndicator(
          onRefresh: () => Future.wait([_loadBoard(), _loadTrueMatches()]),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                  // ── MATANGAZO ──
                  if (_announcements.isNotEmpty)
                    _AnnouncementBanner(
                      announcements: _announcements,
                      onDismiss: (id) async {
                        await ApiService().dismissAnnouncement(id);
                        setState(() => _announcements.removeWhere(
                            (a) => '${a['announcement_id'] ?? a['_id']}' == id));
                      },
                    ),

                  if (_announcements.isNotEmpty) const SizedBox(height: 16),

                  // ── HERO CARD ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))], // shadow-soft
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEFF6FF), // brand-blue-50
                          border: Border.all(color: const Color(0xFFBFDBFE)), // brand-blue-200
                        ),
                        child: Center(child: Text(initial,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D4ED8)))), // brand-blue-700
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Karibu, ${user?.fullName ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Wrap(spacing: 2, runSpacing: 2, children: [
                          if (auth.isAdmin)
                            const Text('Admin',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary))
                          else if ((user?.category ?? '').isNotEmpty)
                            Text(user!.category == 'health' ? 'Afya' : 'Elimu',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          if (!auth.isAdmin && (user?.cadreDisplay ?? '').isNotEmpty)
                            Text('· ${user!.cadreDisplay}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                          if (myRegionName.isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.location_on, size: 10, color: Color(0xFF3B82F6)), // brand-blue-500
                              Text(
                                [station['district_name'], myRegionName]
                                    .where((v) => v != null && v.toString().isNotEmpty).join(', '),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ]),
                        ]),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (!auth.isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(999), // rounded-full
                            ),
                            child: Text(isPaid ? 'AMELIIPIA' : 'HAJALIPIA',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                    color: isPaid ? Colors.green.shade700 : Colors.red.shade700)),
                          ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(const ClipboardData(text: _kAdminPhone));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Namba imenakiliwa'), duration: Duration(seconds: 1)));
                          },
                          child: const Text(_kAdminPhone,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── LIVE PANEL — "Wanaohamia [Mkoa] wakitokea [Chanzo]" ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const _PulseDot(),
                        const SizedBox(width: 8),
                        Expanded(child: RichText(text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: ''),
                          children: [
                            TextSpan(text: 'Wanaohamia ', style: TextStyle(color: AppColors.primary)),
                            TextSpan(text: myRegionName.isNotEmpty ? myRegionName : 'Mkoa Wako',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
                            TextSpan(text: ' — wakitokea ', style: TextStyle(color: AppColors.primary)),
                            TextSpan(text: regionName,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
                          ],
                        ))),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        const SizedBox(width: 16),
                        // Total
                        _statChip('$_boardTotal', Icons.people, AppColors.primary),
                        const SizedBox(width: 6),
                        // Online
                        if (_onlineCount > 0) ...[
                          _statChip('$_onlineCount', Icons.circle, Colors.green),
                          const SizedBox(width: 6),
                        ],
                        // Wapya
                        if (_freshCount > 0)
                          _statChip('+$_freshCount', Icons.bolt, AppColors.primary),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── FILTERS ──
                  _FiltersBar(
                    regions: _regions,
                    districts: _districts,
                    facilities: _facilities,
                    cadres: _cadres,
                    regionSel: _regionSel,
                    districtId: _districtId,
                    facilityId: _facilityId,
                    cadreCode: _cadreCode,
                    isEdu: isEdu,
                    isAdmin: auth.isAdmin,
                    subjectFilter: _subjectFilter,
                    subjectQ: _subjectQ,
                    subjectQCtrl: _subjectQCtrl,
                    onRegionChanged: (v) {
                      setState(() {
                        _regionSel = v ?? '__all__';
                        _districtId = null; _facilityId = null;
                        _districts = []; _facilities = [];
                      });
                      if (v != null && v != '__all__') _loadDistricts(int.tryParse(v) ?? 0);
                      _loadBoard();
                    },
                    onDistrictChanged: (v) {
                      setState(() { _districtId = v; _facilityId = null; _facilities = []; });
                      if (v != null) _loadFacilities(v);
                      _loadBoard();
                    },
                    onFacilityChanged: (v) {
                      setState(() => _facilityId = v);
                      _loadBoard();
                    },
                    onCadreChanged: (v) {
                      setState(() => _cadreCode = v ?? '');
                      _loadBoard();
                    },
                    onSubjectFilterChanged: (v) {
                      setState(() => _subjectFilter = v);
                      _loadBoard();
                    },
                    onSubjectQChanged: (v) {
                      setState(() => _subjectQ = v);
                    },
                    onSubjectQSubmitted: (_) => _loadBoard(),
                    onClear: _clearFilters,
                    singleRegionSelected: _regionSel != '__all__',
                    districtSelected: _districtId != null,
                  ),

                  const SizedBox(height: 16),

                  // ── TRUE MATCHES — kama web: baada ya filters ──
                  if (_trueMatches.isNotEmpty) ...[
                    _TrueMatchesSection(
                      matches: _trueMatches,
                      expanded: _showTrueMatches,
                      onToggle: () => setState(() => _showTrueMatches = !_showTrueMatches),
                      isPaid: isPaid,
                      mySubjects: mySubjects,
                      myRegionName: myRegionName,
                      toastUserId: _toastUserId,
                      toastMsg: _toastMsg,
                      onToast: (msg, uid) => _showCardToast(msg, uid),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── BOARD ──
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  else if (_candidates.isEmpty)
                    _EmptyBoard(regionName: myRegionName)
                  else ...[
                    // Grid responsive: minmax(165px,1fr) — 1 col kwenye simu ndogo, 2+ kwenye kubwa
                    Builder(builder: (ctx) {
                      final contentW = MediaQuery.of(ctx).size.width - 32;
                      // 1 col on phone (<600px), 2 col on tablet — kama web sm:grid-cols-2
                      final cols = contentW >= 568 ? 2 : 1;
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildGrid(_pagedCandidates, isPaid, mySubjects, myRegionName, user, cols: cols));
                    }),
                    // Pagination
                    if (_totalPages > 1)
                      _Pagination(
                        page: _page, total: _totalPages,
                        onPrev: _page > 1 ? () => setState(() => _page--) : null,
                        onNext: _page < _totalPages ? () => setState(() => _page++) : null,
                      ),
                  ],
                ]),
          ),
        )),
        // WhatsApp Group FAB — web: fixed bottom-24 right-4 rounded-full w-11 h-11 bg-[#25D366]
        Positioned(
          right: 16, bottom: 44,
          child: Material(
            color: const Color(0xFF25D366),
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => launchUrl(Uri.parse(_kWaGroup), mode: LaunchMode.externalApplication),
              child: SizedBox(
                width: 44, height: 44,
                child: Center(child: SvgPicture.string(_kWaSvg, width: 24, height: 24)),
              ),
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

  void _onContact(dynamic card, String type, AuthUser? me) async {
    final phone = card['phone_primary'] ?? '';
    final phoneAlt = card['phone_alt'] ?? '';
    final name = card['full_name'] ?? '';
    final uid = card['user_id'] ?? '';
    final isPaid = context.read<AuthProvider>().isVerified ||
        (context.read<AuthProvider>().user?.contactEnabled ?? false);

    if (!isPaid) {
      _showCardToast('Changia TZS 5,000 upate namba', uid);
      return;
    }
    if (phone.isEmpty) return;

    if (type == 'call') { _showCardToast('Piga $name', uid); }
    else if (type == 'sms') { _showCardToast('SMS kwa $name', uid); }
    else { _showCardToast('WhatsApp kwa $name', uid); }

    try { await ApiService().logContact(uid, type); } catch (_) {}

    // Ujumbe wa kutambulishana kama web
    final theirSubjects = (card['subjects'] as List?)?.join(', ') ?? '';
    final theirRole = card['category'] == 'education' ? 'Elimu' : 'Afya';
    final myName = me?.fullName ?? '';
    final myCadre = me?.cadreDisplay ?? me?.cadreCode ?? '';
    final myRegion = (me?.currentStation ?? {})['region_name'] as String? ?? '';
    final introMsg = 'Habari $name, wewe ni $theirRole'
        '${theirSubjects.isNotEmpty ? ' wa masomo $theirSubjects' : ''}. '
        'Mimi ni $myName${myCadre.isNotEmpty ? ', $myCadre' : ''}'
        '${myRegion.isNotEmpty ? ', niko $myRegion' : ''}. '
        'Naomba kujadili kubadilishana vituo.';

    Uri uri;
    if (type == 'call') {
      uri = Uri.parse('tel:$phone');
    } else if (type == 'sms') {
      uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': introMsg});
    } else {
      final digits = phoneAlt.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '255');
      uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(introMsg)}');
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }


  Widget _statChip(String text, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    ]),
  );
}

// ── LIVE: True Matches Section ────────────────────────────────────────────────
class _TrueMatchesSection extends StatelessWidget {
  final List<dynamic> matches;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isPaid;
  final List<String> mySubjects;
  final String myRegionName;
  final String? toastUserId;
  final String? toastMsg;
  final void Function(String msg, String uid) onToast;

  const _TrueMatchesSection({
    required this.matches, required this.expanded, required this.onToggle,
    required this.isPaid, required this.mySubjects, required this.myRegionName,
    required this.onToast, this.toastUserId, this.toastMsg,
  });

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF10B981);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // emerald-50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 2), // emerald-200
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: emerald)),
              const SizedBox(width: 8),
              Text('Match za Kweli (${matches.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: emerald)),
              const Spacer(),
              Text(expanded ? 'Ficha' : 'Onyesha',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: emerald)),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1, color: Color(0xFFBBF7D0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: _TrueMatchGrid(
              matches: matches.take(10).toList(),
              isPaid: isPaid,
              mySubjects: mySubjects,
              myRegionName: myRegionName,
              toastUserId: toastUserId,
              toastMsg: toastMsg,
              onToast: onToast,
            ),
          ),
        ],
      ]),
    );
  }
}

// ── 2-column grid kama web: grid-cols-1 sm:grid-cols-2 gap-2.5 ─────────────
class _TrueMatchGrid extends StatelessWidget {
  final List<dynamic> matches;
  final bool isPaid;
  final List<String> mySubjects;
  final String myRegionName;
  final String? toastUserId;
  final String? toastMsg;
  final void Function(String msg, String uid) onToast;

  const _TrueMatchGrid({
    required this.matches, required this.isPaid,
    required this.mySubjects, required this.myRegionName,
    required this.onToast, this.toastUserId, this.toastMsg,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < matches.length; i += 2) {
      final a = matches[i];
      final b = i + 1 < matches.length ? matches[i + 1] : null;
      final uidA = (a['candidate'] ?? a)['user_id'] as String? ?? '';
      final uidB = b != null ? ((b['candidate'] ?? b)['user_id'] as String? ?? '') : '';
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _TrueMatchCard(
            match: a, isPaid: isPaid, mySubjects: mySubjects, myRegionName: myRegionName,
            toast: toastUserId == uidA ? toastMsg : null,
            onToast: onToast,
          )),
          const SizedBox(width: 10), // gap-2.5
          if (b != null)
            Expanded(child: _TrueMatchCard(
              match: b, isPaid: isPaid, mySubjects: mySubjects, myRegionName: myRegionName,
              toast: toastUserId == uidB ? toastMsg : null,
              onToast: onToast,
            ))
          else
            const Expanded(child: SizedBox()),
        ]),
      ));
      if (i + 2 < matches.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }
}

class _TrueMatchCard extends StatelessWidget {
  final dynamic match;
  final bool isPaid;
  final List<String> mySubjects;
  final String myRegionName;
  final String? toast;
  final void Function(String msg, String uid) onToast;

  const _TrueMatchCard({
    required this.match, required this.isPaid, required this.mySubjects,
    required this.myRegionName, required this.onToast, this.toast,
  });

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF10B981);
    const emeraldBg = Color(0xFFD1FAE5);
    final c = match['candidate'] ?? match;
    final score = ((match['score'] ?? 0.0) * 100).round();
    final name = c['full_name'] ?? 'Mtumiaji';
    final initial = _initials(name);
    final from = c['current_station'] ?? {};
    final to = c['matching_destination'] ?? (c['desired_destinations'] as List?)?.firstOrNull;
    final subjects = (c['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];
    final anyMatch = subjects.any((s) => mySubjects.contains(s));
    final isEdu = c['category'] != 'health';
    final cadre = c['cadre_display'] ?? c['cadre_code'] ?? '';
    final years = c['years_of_service'];
    final targetPaid = c['is_verified'] == true || contactEnabled(c);
    final phone = c['phone_primary'] ?? '';
    final phoneAlt = c['phone_alt'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 2), // emerald-300
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header: avatar + name + score badge
            Row(children: [
              CircleAvatar(radius: 20, backgroundColor: emerald,
                  child: Text(initial, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis)),
                  if (targetPaid)
                    Container(margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: emeraldBg, borderRadius: BorderRadius.circular(10)),
                        child: const Text('✓ PAID', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: emerald))),
                ]),
                Row(children: [
                  Text(isEdu ? 'Elimu' : 'Afya',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: emerald)),
                  if (cadre.isNotEmpty) Text(' · $cadre',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ]),
              ])),
            ]),

            const SizedBox(height: 8),

            // Location box (px-2.5=10px, py-1.5=6px kama web)
            if ((from['region_name'] ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.location_on, size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text('Kutoka: ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Expanded(child: Text(
                      [from['district_name'], from['region_name'], from['facility_name']]
                          .where((v) => v != null && v.toString().isNotEmpty).join(', '),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                  if (to != null && (to['region_name'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.compare_arrows, size: 11, color: emerald),
                      const SizedBox(width: 3),
                      Text('Kuja: ', style: const TextStyle(fontSize: 11, color: emerald, fontWeight: FontWeight.w600)),
                      Expanded(child: Text(
                        [to['region_name'], to['district_name']]
                            .where((v) => v != null && v.toString().isNotEmpty).join(', '),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  ],
                ]),
              ),

            // Miaka ya kazi
            if (years != null) ...[
              const SizedBox(height: 6),
              Text('Miaka ya kazi: ${years == 3 ? "3+ (miaka 3 au zaidi)" : "$years ${years == 1 ? 'mwaka' : 'miaka'}"}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],

            // Masomo
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: [
                if (anyMatch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Text('✓ Match', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ...subjects.take(4).map((s) {
                  final matched = mySubjects.contains(s);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: matched ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$s${matched ? ' ✓' : ''}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                            color: matched ? Colors.white : Colors.grey.shade700)),
                  );
                }),
              ]),
            ],

            const SizedBox(height: 10),

            // Buttons: Piga + WhatsApp — kama web
            Row(children: [
              if (phone.isNotEmpty)
                Expanded(child: _tmBtn(Icons.phone, 'Piga', () async {
                  final uid = c['user_id'] as String? ?? '';
                  if (!isPaid) { onToast('Changia TZS 5,000 upate namba', uid); return; }
                  onToast('Piga $name', uid);
                  try { await ApiService().logContact(uid, 'call'); } catch (_) {}
                  launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
                }, isPaid)),
              // WhatsApp — onyesha tu kama amelipa (canContact) kama web
              if (phoneAlt.isNotEmpty && isPaid) ...[
                const SizedBox(width: 8),
                Expanded(child: _tmBtn(Icons.chat, 'WhatsApp', () async {
                  final uid = c['user_id'] as String? ?? '';
                  final firstName = name.split(' ').first;
                  final introMsg = 'Habari $firstName, nina furaha kukupata hapa. Nina hamu ya kubadilishana nafasi na wewe.';
                  final digits = phoneAlt.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '255');
                  launchUrl(Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(introMsg)}'),
                      mode: LaunchMode.externalApplication);
                  try { await ApiService().logContact(uid, 'whatsapp'); } catch (_) {}
                }, isPaid)),
              ],
            ]),

            const SizedBox(height: 8),

            // Score bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 4,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(emerald),
              ),
            ),

            // Toast — kama web (ndani ya card, chini ya score bar)
            if (toast != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/donate'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(toast!, style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Changia →', style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),

        // Score badge (absolute top right)
        Positioned(
          top: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: score >= 100 ? emerald : score >= 85 ? const Color(0xFF34D399) : const Color(0xFF6EE7B7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('🎯 $score%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: score >= 85 ? Colors.white : const Color(0xFF065F46))),
          ),
        ),
      ]),
    );
  }

  bool contactEnabled(dynamic c) => c['contact_enabled'] == true;

  Widget _tmBtn(IconData icon, String label, VoidCallback onTap, bool enabled) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), // px-2.5=10px py-1.5=6px kama web
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)), // border-grey-300
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 11, color: enabled ? const Color(0xFF111827) : const Color(0xFF9CA3AF)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF111827) : const Color(0xFF9CA3AF))),
      ]),
    ),
  );
}

// ── Filters Bar ───────────────────────────────────────────────────────────────
class _FiltersBar extends StatelessWidget {
  final List<dynamic> regions, districts, facilities, cadres;
  final String regionSel, cadreCode;
  final int? districtId;
  final String? facilityId;
  final bool singleRegionSelected, districtSelected;
  final bool isEdu, isAdmin;
  final String subjectFilter, subjectQ;
  final TextEditingController subjectQCtrl;
  final void Function(String?) onRegionChanged;
  final void Function(int?) onDistrictChanged;
  final void Function(String?) onFacilityChanged;
  final void Function(String?) onCadreChanged;
  final void Function(String) onSubjectFilterChanged;
  final void Function(String) onSubjectQChanged;
  final void Function(String) onSubjectQSubmitted;
  final VoidCallback onClear;

  const _FiltersBar({
    required this.regions, required this.districts, required this.facilities, required this.cadres,
    required this.regionSel, required this.districtId, required this.facilityId, required this.cadreCode,
    required this.isEdu, required this.isAdmin,
    required this.subjectFilter, required this.subjectQ, required this.subjectQCtrl,
    required this.singleRegionSelected, required this.districtSelected,
    required this.onRegionChanged, required this.onDistrictChanged,
    required this.onFacilityChanged, required this.onCadreChanged,
    required this.onSubjectFilterChanged, required this.onSubjectQChanged,
    required this.onSubjectQSubmitted, required this.onClear,
  });

  static InputDecoration _searchDec(String hint) => InputDecoration(
    hintText: hint, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    filled: true, fillColor: const Color(0xFFF9FAFB),
    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
  );

  @override
  Widget build(BuildContext context) {
    final showCadre = (!isEdu || isAdmin) && cadres.isNotEmpty;
    final hasFilter = regionSel != '__all__' || districtId != null || facilityId != null ||
        cadreCode.isNotEmpty || subjectFilter != 'off' || subjectQ.isNotEmpty;

    // Labels za thamani zilizochaguliwa
    final regionLabel = regionSel == '__all__' ? null
        : regions.cast<dynamic>().firstWhere((r) => '${r['id']}' == regionSel, orElse: () => null)?['name'] as String?;
    final districtLabel = districtId == null ? null
        : districts.cast<dynamic>().firstWhere((d) => d['id'] == districtId, orElse: () => null)?['name'] as String?;
    final facilityLabel = facilityId == null ? null
        : facilities.cast<dynamic>().firstWhere((f) => '${f['id'] ?? f['code']}' == facilityId, orElse: () => null)?['name'] as String?;
    final cadreLabel = cadreCode.isEmpty ? null
        : cadres.cast<dynamic>().firstWhere((c) => '${c['code']}' == cadreCode, orElse: () => null)?['display_name'] as String? ?? cadreCode;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header: title + clear ──
        Row(children: [
          const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text('Vichujio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const Spacer(),
          if (hasFilter)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Futa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
              ),
            ),
        ]),

        const SizedBox(height: 10),
        const Text('Mkoa (Wanakotoka)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 5),

        // Mkoa — bottom sheet picker
        SelectField(
          hint: 'Mikoa Yote',
          value: regionLabel,
          onTap: () async {
            final items = [
              (value: '__all__', label: 'Mikoa Yote', subtitle: null),
              ...regions.map((r) => (value: '${r['id']}', label: '${r['name']}', subtitle: null)),
            ];
            final result = await showSelectSheet<String>(
              context, title: 'Chagua Mkoa', items: items, selected: regionSel, searchable: true,
            );
            if (result != null) onRegionChanged(result);
          },
        ),

        const SizedBox(height: 8),
        Text('Wilaya / Halmashauri',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: singleRegionSelected ? const Color(0xFF374151) : const Color(0xFFD1D5DB))),
        const SizedBox(height: 5),

        // Wilaya — disabled unless mkoa mmoja
        SelectField(
          hint: singleRegionSelected ? 'Wilaya Zote' : 'Chagua Mkoa kwanza',
          value: districtLabel,
          disabled: !singleRegionSelected,
          onTap: !singleRegionSelected ? null : () async {
            final items = [
              (value: null as int?, label: 'Wilaya Zote', subtitle: null),
              ...districts.map((d) => (value: d['id'] as int?, label: '${d['name']}', subtitle: null)),
            ];
            final result = await showSelectSheet<int?>(
              context, title: 'Chagua Wilaya', items: items, selected: districtId, searchable: true,
            );
            if (result != null || result == null) onDistrictChanged(result);
          },
        ),

        const SizedBox(height: 8),
        Text('Kituo / Hospitali',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: districtSelected ? const Color(0xFF374151) : const Color(0xFFD1D5DB))),
        const SizedBox(height: 5),

        // Kituo — disabled unless wilaya
        SelectField(
          hint: districtSelected ? 'Vituo Vyote' : 'Chagua Wilaya kwanza',
          value: facilityLabel,
          disabled: !districtSelected,
          onTap: !districtSelected ? null : () async {
            final items = [
              (value: null as String?, label: 'Vituo Vyote', subtitle: null),
              ...facilities.map((f) => (
                value: '${f['id'] ?? f['code']}' as String?,
                label: '${f['name']}',
                subtitle: null,
              )),
            ];
            final result = await showSelectSheet<String?>(
              context, title: 'Chagua Kituo', items: items, selected: facilityId, searchable: true,
            );
            if (result != null || result == null) onFacilityChanged(result);
          },
        ),

        // Active location label
        if (regionLabel != null || districtLabel != null || facilityLabel != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
            const SizedBox(width: 3),
            Expanded(child: Text(
              facilityLabel ?? districtLabel ?? regionLabel ?? '',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        ],

        // ── Subject filter chips (edu + admin) ──
        if (isEdu) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text('Masomo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final entry in [
              ('off', 'Wote'),
              ('all', 'Yote mawili'),
              ('any', 'Somo moja'),
              ('none', 'Wasio match'),
            ])
              GestureDetector(
                onTap: () => onSubjectFilterChanged(entry.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: subjectFilter == entry.$1 ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: subjectFilter == entry.$1 ? AppColors.primary : const Color(0xFFD1D5DB),
                    ),
                    boxShadow: subjectFilter == entry.$1
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 4)]
                        : [],
                  ),
                  child: Text(entry.$2, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: subjectFilter == entry.$1 ? Colors.white : const Color(0xFF4B5563),
                  )),
                ),
              ),
          ]),
          if (subjectFilter != 'off') ...[
            const SizedBox(height: 8),
            TextField(
              controller: subjectQCtrl,
              decoration: _searchDec('Tafuta masomo (MATH, KISWAHILI...)').copyWith(
                suffixIcon: subjectQ.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 14, color: Color(0xFF9CA3AF)),
                        onPressed: () { subjectQCtrl.clear(); onSubjectQChanged(''); onSubjectQSubmitted(''); })
                    : null,
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: onSubjectQChanged,
              onSubmitted: onSubjectQSubmitted,
              textInputAction: TextInputAction.search,
            ),
          ],
        ],

        // ── Kada (health + admin) ──
        if (showCadre) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text('Idara / Kada', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 6),
          SelectField(
            hint: 'Idara Zote',
            value: cadreLabel,
            onTap: () async {
              final items = [
                (value: '' as String?, label: 'Idara Zote', subtitle: null),
                ...cadres.map((c) => (
                  value: '${c['code']}' as String?,
                  label: '${c['display_name'] ?? c['code']}',
                  subtitle: null,
                )),
              ];
              final result = await showSelectSheet<String?>(
                context, title: 'Chagua Idara / Kada', items: items, selected: cadreCode.isEmpty ? '' : cadreCode, searchable: true,
              );
              if (result != null || result == null) onCadreChanged(result);
            },
          ),
        ],
      ]),
    );
  }
}

// ── Board Card ────────────────────────────────────────────────────────────────
class _BoardCard extends StatelessWidget {
  final dynamic card;
  final bool isPaid;
  final List<String> mySubjects;
  final String myRegionName, myName, myCadre, myStation, myUserId;
  final String? toast;
  final void Function(String type) onContact;
  final void Function(String msg) onToast;

  const _BoardCard({
    required this.card, required this.isPaid, required this.mySubjects,
    required this.myRegionName, required this.myName, required this.myCadre,
    required this.myStation, required this.myUserId, this.toast,
    required this.onContact, required this.onToast,
  });

  @override
  Widget build(BuildContext context) {
    final name = card['full_name'] ?? 'Mtumiaji';
    final cadre = card['cadre_display'] ?? card['cadre_code'] ?? '';
    final category = card['category'] ?? '';
    final station = card['current_station'] ?? {};
    final matchingDest = card['matching_destination'];
    final dests = (card['desired_destinations'] as List?)?.take(2).toList() ?? [];
    final online = card['online'] == true;
    final fresh = _isFresh(card['created_at'] ?? card['joined_at']);
    final phoneOk = (card['phone_primary'] ?? '').isNotEmpty;
    final altOk = (card['phone_alt'] ?? '').isNotEmpty;
    final initial = _initials(name);
    final ago = _timeAgo(card['created_at'] ?? card['joined_at']);
    final fullDate = _fullDate(card['created_at'] ?? card['joined_at']);
    final subjects = (card['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];
    final anySubjectMatch = subjects.any((s) => mySubjects.contains(s));
    final years = card['years_of_service'];
    final isEdu = category != 'health';
    final isMe = myUserId.isNotEmpty && (card['user_id'] ?? '') == myUserId;
    final targetPaid = card['is_verified'] == true || card['contact_enabled'] == true;

    // Destination inayokuja mkoa wako
    final activeDest = matchingDest ?? (dests.isNotEmpty ? dests[0] : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fresh ? AppColors.primary
              : online ? Colors.green.shade300
              : AppColors.border,
        ),
        boxShadow: fresh
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 0, spreadRadius: 2)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.max, children: [

          // Row 1: Avatar + info
          Row(children: [
            Stack(children: [
              CircleAvatar(radius: 18, backgroundColor: const Color(0xFFEFF6FF), // brand-blue-50
                  child: Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)))), // brand-blue-700
              if (online)
                Positioned(right: 0, bottom: 0,
                  child: Container(width: 9, height: 9,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green,
                        border: Border.all(color: Colors.white, width: 1.5)))),
            ]),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis)),
                if (fresh)
                  Padding(padding: const EdgeInsets.only(left: 4),
                    child: _PulseBadge(label: 'Mpya', bg: AppColors.primary, textColor: Colors.white)),
                if (online && !fresh)
                  Padding(padding: const EdgeInsets.only(left: 4),
                    child: Text('● Live', style: TextStyle(fontSize: 9, color: Colors.green.shade600, fontWeight: FontWeight.bold))),
                // isMe: PAID/HAJALIPIA badge — kama web (kwa mtumiaji mwenyewe tu)
                if (isMe)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: targetPaid ? const Color(0xFF10B981) : const Color(0xFFF87171),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      targetPaid ? '✓ PAID' : '✗ HAJALIPIA',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
              ]),
              const SizedBox(height: 2),
              Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (category.isNotEmpty)
                  Text(isEdu ? 'Elimu' : 'Afya',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                if (cadre.isNotEmpty)
                  Text(cadre,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                // Health cadre code badge — kama web: bg-emerald-500 text-white rounded-full
                if (!isEdu && card['cadre_code'] != null && (card['cadre_code'] as String).isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981), // emerald-500
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(card['cadre_code'] as String,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
              ]),
            ])),
          ]),

          const SizedBox(height: 8),

          // Location box — web: bg-brand-blue-50 rounded-xl px-2.5 py-2 border-brand-blue-100
          if ((station['region_name'] ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // brand-blue-50
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDBEAFE)), // brand-blue-100
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.location_on, size: 11, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 3),
                  const Text('Kutoka: ', style: TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontWeight: FontWeight.w500)),
                  Expanded(child: Text(
                    [station['region_name'], station['district_name']]
                        .where((v) => v != null && v.toString().isNotEmpty).join(', '),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
                if (activeDest != null && (activeDest['region_name'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.near_me, size: 11, color: Color(0xFF1E40AF)),
                    const SizedBox(width: 3),
                    const Text('Kwenda: ', style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                    Expanded(child: Text(
                      [activeDest['region_name'], activeDest['district_name']]
                          .where((v) => v != null && v.toString().isNotEmpty).join(', '),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ],
                if (myRegionName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFDBEAFE)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Text('↓ Anakuja: ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    Expanded(child: Text(myRegionName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1F2937)),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ]),
            ),

          // Miaka ya kazi
          if (years != null) ...[
            const SizedBox(height: 8), // gap-2 = 8px
            Text('Miaka ya kazi: ${years == 3 ? "3+ (miaka 3 au zaidi)" : "$years ${years == 1 ? 'mwaka' : 'miaka'}"}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ],

          // Masomo (kwa walimu) — web: label "Masomo:" full-width juu, kisha chips
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Masomo:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            const SizedBox(height: 4),
            Wrap(spacing: 4, runSpacing: 4, children: [
              ...subjects.take(4).map((s) {
                final matched = mySubjects.contains(s);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: matched ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: matched ? AppColors.primary : const Color(0xFFD1D5DB)),
                  ),
                  child: Text('$s${matched ? ' ✓' : ''}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: matched ? Colors.white : const Color(0xFF374151))),
                );
              }),
              // Match badge — kama web: bg-blue-50 text-blue-700 border-blue/20
              if (anySubjectMatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // brand-blue-50
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.2)),
                  ),
                  child: const Text('✓ Masomo yanalingana',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
                ),
            ]),
          ],

          // Muda
          if (ago.isNotEmpty) ...[
            const SizedBox(height: 8), // gap-2 = 8px
            Row(children: [
              Icon(fresh ? Icons.bolt : Icons.access_time, size: 11,
                  color: fresh ? AppColors.primary : const Color(0xFF9CA3AF)),
              const SizedBox(width: 3),
              Expanded(child: Text(fresh ? 'Mpya · $ago' : ago,
                  style: TextStyle(fontSize: 11,
                      color: fresh ? AppColors.primary : const Color(0xFF9CA3AF),
                      fontWeight: fresh ? FontWeight.bold : FontWeight.w500))),
            ]),
            if (fullDate.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2),
                  child: Text(fullDate, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)))),
          ],

          // mt-auto pt-1 kama web — Spacer inasogeza buttons chini, pt-1=4px
          const Spacer(),
          const SizedBox(height: 4),

          // Buttons: Piga / SMS / WA — wote grey-900 kama web
          Row(children: [
            Expanded(child: _contactBtn(Icons.phone, 'Piga',
                phoneOk ? () => onContact('call') : null)),
            const SizedBox(width: 6), // gap-1.5 = 6px
            Expanded(child: _contactBtn(Icons.chat_bubble_outline, 'SMS',
                phoneOk ? () => onContact('sms') : null)),
            if (altOk) ...[
              const SizedBox(width: 6), // gap-1.5 = 6px
              Expanded(child: _contactBtnWa(() => onContact('whatsapp'))),
            ],
          ]),

          // Toast ndani ya card (kama web DashboardBoard.tsx)
          if (toast != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/donate'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // px-3=12 py-2.5=10
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // bg-brand-blue-50
                  borderRadius: BorderRadius.circular(8), // rounded-lg=8
                  border: Border.all(color: const Color(0xFF1E40AF).withValues(alpha: 0.2)), // border-brand-blue/20
                ),
                child: Row(children: [
                  Expanded(child: Text(toast!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)))), // text-[12px] font-semibold text-brand-blue-800
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2=8 py-0.5=2
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.1), // bg-brand-blue/10
                      borderRadius: BorderRadius.circular(6), // rounded-md=6
                    ),
                    child: const Text('Changia →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))), // text-sm=14 font-bold text-brand-blue
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // Buttons ndogo kama web: py-1.5=6px, px-1.5=6px, text-[10px], icon 12px
  // web: bg-white border-grey-300 text-grey-900 — wote rangi sawa
  Widget _contactBtn(IconData icon, String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6), // py-1.5 px-1.5
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)), // border-grey-300
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 12, color: onTap != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF)), // grey-900 / grey-400
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: onTap != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF))), // grey-900 / grey-400
      ]),
    ),
  );

  Widget _contactBtnWa(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366), // WhatsApp green — kama web
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SvgPicture.string(_kWaSvg, width: 12, height: 12), // white SVG on green bg
        const SizedBox(width: 3),
        const Text('WhatsApp', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    ),
  );
}

// ── Pagination ────────────────────────────────────────────────────────────────
class _Pagination extends StatelessWidget {
  final int page, total;
  final VoidCallback? onPrev, onNext;
  const _Pagination({required this.page, required this.total, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(onPressed: onPrev,
            style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('← Iliyopita', style: TextStyle(fontSize: 12))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$page / $total', style: const TextStyle(fontWeight: FontWeight.bold))),
        OutlinedButton(onPressed: onNext,
            style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Inayofuata →', style: TextStyle(fontSize: 12))),
      ]),
    );
  }
}

// ── Empty Board ───────────────────────────────────────────────────────────────
class _EmptyBoard extends StatelessWidget {
  final String regionName;
  const _EmptyBoard({required this.regionName});

  @override
  Widget build(BuildContext context) {
    final title = regionName.isNotEmpty
        ? 'Hakuna mtu wa mkoa mwingine kuja $regionName.'
        : 'Hakuna mtu anaokuja mkoa wako.';
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF3F4F6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Icon(Icons.people_outline, size: 28, color: AppColors.textLight),
        ),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('Jisajili na uchague mkoa wako ili uanze.',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
            textAlign: TextAlign.center),
      ]),
    ));
  }
}

// ── Announcement Banner — matches web AnnouncementBanner.tsx exactly ─────────
// Web: rounded-lg border-grey-200 bg-white px-4 py-3 flex items-start gap-3
// Shows 1 announcement (most recent unique). WS-driven refresh via parent.
class _AnnouncementBanner extends StatelessWidget {
  final List<dynamic> announcements;
  final void Function(String id) onDismiss;
  const _AnnouncementBanner({required this.announcements, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) return const SizedBox.shrink();

    // Deduplicate kama web: title+message key, keep most recent
    final seen = <String, dynamic>{};
    for (final item in announcements) {
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
    final current = seen.values.isNotEmpty ? seen.values.first : null;
    if (current == null) return const SizedBox.shrink();

    final id = '${current['announcement_id'] ?? current['_id'] ?? ''}';
    final title = '${current['title'] ?? ''}';
    final message = '${current['message'] ?? current['body'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // rounded-lg
        border: Border.all(color: const Color(0xFFE5E7EB)), // border-grey-200
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Megaphone icon — grey-400, mt-0.5 kama web
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.campaign_outlined, size: 16, color: Color(0xFF9CA3AF)), // grey-400
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title: font-bold text-brand-blue text-[13px] — brand-blue = #1E40AF
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
          const SizedBox(height: 4),
          // Message: text-brand-grey-900 text-[12px] leading-relaxed line-clamp-3
          Text(message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF111827), height: 1.5),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        // Close button: w-8 h-8 rounded-lg border border-grey-200 text-× font-bold
        GestureDetector(
          onTap: () { if (id.isNotEmpty) onDismiss(id); },
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(
              child: Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF))),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Pulsing green dot — kama web `animate-pulse` ──────────────────────────────
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
    ),
  );
}

// ── Pulsing "Mpya" badge — kama web `animate-[newPulse_1s_ease-in-out_infinite]` ──
class _PulseBadge extends StatefulWidget {
  final String label;
  final Color bg;
  final Color textColor;
  const _PulseBadge({required this.label, required this.bg, required this.textColor});
  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(10)),
      child: Text(widget.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor)),
    ),
  );
}
