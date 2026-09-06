import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

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
  bool _showTrueMatches = true; // expanded by default kama web
  int _currentIndex = 0;
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

  // Toast ndani ya card
  String? _toastUserId;
  String? _toastMsg;

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

      final res = await ApiService().get('/matches/board', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      if (mounted) setState(() {
        _candidates = data['candidates'] ?? [];
        _boardTotal = data['total'] ?? _candidates.length;
        _page = 1;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    ws.on('contact.toggled', (_) => _loadBoard());
  }

  void _clearFilters() {
    setState(() {
      _regionSel = '__all__';
      _districtId = null;
      _facilityId = null;
      _cadreCode = '';
      _districts = [];
      _facilities = [];
    });
    _loadBoard();
  }

  void _showCardToast(String msg, String uid) {
    setState(() { _toastMsg = msg; _toastUserId = uid; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() { _toastMsg = null; _toastUserId = null; });
    });
  }

  List<dynamic> get _pagedCandidates {
    final start = (_page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _candidates.length);
    return _candidates.sublist(start.clamp(0, _candidates.length), end);
  }

  int get _totalPages => (_candidates.length / _pageSize).ceil().clamp(1, 9999);

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

    // Source region name kwa LIVE panel
    final regionName = _regionSel == '__all__'
        ? 'Mikoa Yote'
        : (_regions.firstWhere((r) => '${r['id']}' == _regionSel, orElse: () => null)?['name'] ?? 'Mikoa Yote');

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ── AppBar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(children: [
              const Text('Kubadilishana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.pushNamed(context, '/notifications')),
              IconButton(icon: const Icon(Icons.menu), onPressed: () => _showMenu(context)),
            ]),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => Future.wait([_loadBoard(), _loadTrueMatches()]),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
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

                  if (_announcements.isNotEmpty) const SizedBox(height: 10),

                  // ── HERO CARD ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight,
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Center(child: Text(initial,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Karibu, ${user?.fullName ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Wrap(spacing: 4, children: [
                          if (auth.isAdmin)
                            _badge('Admin', AppColors.primary)
                          else if ((user?.category ?? '').isNotEmpty)
                            _badge(user!.category == 'health' ? 'Afya' : 'Elimu', AppColors.primary),
                          if (!auth.isAdmin && (user?.cadreDisplay ?? '').isNotEmpty)
                            Text('· ${user!.cadreDisplay}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          if (myRegionName.isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.location_on, size: 10, color: AppColors.primary),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(isPaid ? 'AMELIIPIA' : 'HAJALIPIA',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
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
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 10),

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
                        Container(width: 8, height: 8,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(child: RichText(text: TextSpan(
                          style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: ''),
                          children: [
                            TextSpan('Wanaohamia ', style: TextStyle(color: AppColors.primary)),
                            TextSpan(myRegionName.isNotEmpty ? myRegionName : 'Mkoa Wako',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
                            TextSpan(' — wakitokea ', style: TextStyle(color: AppColors.primary)),
                            TextSpan(regionName,
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
                          _statChip('$_onlineCount online', Icons.circle, Colors.green),
                          const SizedBox(width: 6),
                        ],
                        // Wapya
                        if (_freshCount > 0)
                          _statChip('+$_freshCount wapya', Icons.bolt, AppColors.primary),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  // ── TRUE MATCHES ──
                  if (_trueMatches.isNotEmpty) ...[
                    _TrueMatchesSection(
                      matches: _trueMatches,
                      expanded: _showTrueMatches,
                      onToggle: () => setState(() => _showTrueMatches = !_showTrueMatches),
                      isPaid: isPaid,
                      mySubjects: mySubjects,
                      myRegionName: myRegionName,
                    ),
                    const SizedBox(height: 10),
                  ],

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
                    onClear: _clearFilters,
                    singleRegionSelected: _regionSel != '__all__',
                    districtSelected: _districtId != null,
                  ),

                  const SizedBox(height: 10),

                  // ── BOARD ──
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  else if (_candidates.isEmpty)
                    _EmptyBoard(isPaid: isPaid)
                  else ...[
                    ..._pagedCandidates.map((c) => _BoardCard(
                      card: c,
                      isPaid: isPaid,
                      mySubjects: mySubjects,
                      myRegionName: myRegionName,
                      myName: user?.fullName ?? '',
                      myCadre: user?.cadreDisplay ?? user?.cadreCode ?? '',
                      myStation: myRegionName,
                      toast: _toastUserId == (c['user_id'] ?? '') ? _toastMsg : null,
                      onContact: (type) => _onContact(c, type),
                      onToast: (msg) => _showCardToast(msg, c['user_id'] ?? ''),
                    )),
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
            ),
          ),
        ]),
      ),

      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: const Color(0xFF25D366),
        onPressed: () => launchUrl(Uri.parse(_kWaGroup), mode: LaunchMode.externalApplication),
        child: const Icon(Icons.chat, color: Colors.white),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          switch (i) {
            case 1: Navigator.pushNamed(context, '/donate').then((_) => setState(() => _currentIndex = 0)); break;
            case 2: Navigator.pushNamed(context, '/feedback').then((_) => setState(() => _currentIndex = 0)); break;
            case 3: Navigator.pushNamed(context, '/profile').then((_) => setState(() => _currentIndex = 0)); break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Nyumbani'),
          BottomNavigationBarItem(icon: Icon(Icons.payment_outlined), activeIcon: Icon(Icons.payment), label: 'Changia'),
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), activeIcon: Icon(Icons.message), label: 'Maoni'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Wasifu'),
        ],
      ),
    );
  }

  void _onContact(dynamic card, String type) async {
    final phone = card['phone_primary'] ?? '';
    final phoneAlt = card['phone_alt'] ?? '';
    final isPaid = context.read<AuthProvider>().isVerified ||
        (context.read<AuthProvider>().user?.contactEnabled ?? false);

    if (!isPaid) {
      _showCardToast('Changia TZS 5,000 upate namba', card['user_id'] ?? '');
      return;
    }
    if (phone.isEmpty) return;
    try { await ApiService().logContact(card['user_id'] ?? '', type); } catch (_) {}
    Uri uri;
    if (type == 'call') uri = Uri.parse('tel:$phone');
    else if (type == 'sms') uri = Uri.parse('sms:$phone');
    else {
      final digits = phoneAlt.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '255');
      uri = Uri.parse('https://wa.me/$digits');
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.logout, color: AppColors.error),
          title: const Text('Toka', style: TextStyle(color: AppColors.error)),
          onTap: () { Navigator.pop(context); context.read<AuthProvider>().logout(); Navigator.pushReplacementNamed(context, '/login'); }),
      ])),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );

  Widget _statChip(String text, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
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

  const _TrueMatchesSection({
    required this.matches, required this.expanded, required this.onToggle,
    required this.isPaid, required this.mySubjects, required this.myRegionName,
  });

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF10B981);
    const emeraldLight = Color(0xFFD1FAE5);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: emerald)),
              const Spacer(),
              Text(expanded ? 'Ficha' : 'Onyesha',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: emerald)),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1, color: Color(0xFFBBF7D0)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: matches.take(10).map((m) => _TrueMatchCard(
                match: m, isPaid: isPaid, mySubjects: mySubjects, myRegionName: myRegionName,
              )).toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

class _TrueMatchCard extends StatelessWidget {
  final dynamic match;
  final bool isPaid;
  final List<String> mySubjects;
  final String myRegionName;

  const _TrueMatchCard({required this.match, required this.isPaid, required this.mySubjects, required this.myRegionName});

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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
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
                  Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

            // Location box
            if ((from['region_name'] ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
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

            // Buttons: Piga + WhatsApp
            Row(children: [
              if (phone.isNotEmpty)
                Expanded(child: _tmBtn(Icons.phone, 'Piga', () async {
                  if (!isPaid) return;
                  try { await ApiService().logContact(c['user_id'] ?? '', 'call'); } catch (_) {}
                  launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
                }, isPaid)),
              if (phone.isNotEmpty && phoneAlt.isNotEmpty) const SizedBox(width: 8),
              if (phoneAlt.isNotEmpty)
                Expanded(child: _tmBtn(Icons.chat, 'WhatsApp', () async {
                  if (!isPaid) return;
                  final digits = phoneAlt.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '255');
                  launchUrl(Uri.parse('https://wa.me/$digits'), mode: LaunchMode.externalApplication);
                }, isPaid)),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? const Color(0xFF6EE7B7) : AppColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: enabled ? const Color(0xFF10B981) : AppColors.textLight),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: enabled ? const Color(0xFF10B981) : AppColors.textLight)),
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
  final void Function(String?) onRegionChanged;
  final void Function(int?) onDistrictChanged;
  final void Function(String?) onFacilityChanged;
  final void Function(String?) onCadreChanged;
  final VoidCallback onClear;

  const _FiltersBar({
    required this.regions, required this.districts, required this.facilities, required this.cadres,
    required this.regionSel, required this.districtId, required this.facilityId, required this.cadreCode,
    required this.singleRegionSelected, required this.districtSelected,
    required this.onRegionChanged, required this.onDistrictChanged,
    required this.onFacilityChanged, required this.onCadreChanged, required this.onClear,
  });

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border.withOpacity(0.4))),
  );

  @override
  Widget build(BuildContext context) {
    final hasFilter = regionSel != '__all__' || districtId != null || facilityId != null || cadreCode.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Chanzo Mkoa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const Spacer(),
          if (hasFilter)
            GestureDetector(
              onTap: onClear,
              child: const Text('Futa vichujio', style: TextStyle(fontSize: 11, color: AppColors.error)),
            ),
        ]),
        const SizedBox(height: 6),

        // Mkoa
        DropdownButtonFormField<String>(
          value: regionSel,
          decoration: _dec('Mikoa Yote'),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: '__all__', child: Text('Mikoa Yote')),
            ...regions.map((r) => DropdownMenuItem(value: '${r['id']}', child: Text('${r['name']}'))),
          ],
          onChanged: onRegionChanged,
        ),

        const SizedBox(height: 6),

        // Wilaya — always visible, disabled unless mkoa mmoja
        DropdownButtonFormField<int?>(
          value: districtId,
          decoration: _dec(singleRegionSelected ? 'Wilaya Yote' : 'Chagua mkoa kwanza'),
          style: TextStyle(fontSize: 12, color: singleRegionSelected ? Colors.black87 : Colors.grey),
          isExpanded: true,
          items: [
            DropdownMenuItem(value: null, child: Text(singleRegionSelected ? 'Wilaya Yote' : 'Chagua mkoa kwanza')),
            ...districts.map((d) => DropdownMenuItem(value: d['id'] as int, child: Text('${d['name']}'))),
          ],
          onChanged: singleRegionSelected ? onDistrictChanged : null,
        ),

        const SizedBox(height: 6),

        // Kituo — always visible, disabled unless wilaya imechaguliwa
        DropdownButtonFormField<String?>(
          value: facilityId,
          decoration: _dec(districtSelected ? 'Vituo Vyote' : 'Chagua wilaya kwanza'),
          style: TextStyle(fontSize: 12, color: districtSelected ? Colors.black87 : Colors.grey),
          isExpanded: true,
          items: [
            DropdownMenuItem(value: null, child: Text(districtSelected ? 'Vituo Vyote' : 'Chagua wilaya kwanza')),
            ...facilities.map((f) => DropdownMenuItem(
              value: '${f['id'] ?? f['code']}',
              child: Text('${f['name']}', overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: districtSelected ? onFacilityChanged : null,
        ),

        if (cadres.isNotEmpty) ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: cadreCode.isEmpty ? '' : cadreCode,
            decoration: _dec('Kada Zote'),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: '', child: Text('Kada Zote')),
              ...cadres.map((c) => DropdownMenuItem(
                value: '${c['code']}',
                child: Text('${c['display_name'] ?? c['code']}', overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: onCadreChanged,
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
  final String myRegionName, myName, myCadre, myStation;
  final String? toast;
  final void Function(String type) onContact;
  final void Function(String msg) onToast;

  const _BoardCard({
    required this.card, required this.isPaid, required this.mySubjects,
    required this.myRegionName, required this.myName, required this.myCadre,
    required this.myStation, this.toast,
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

    // Destination inayokuja mkoa wako
    final activeDest = matchingDest ?? (dests.isNotEmpty ? dests[0] : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fresh ? AppColors.primary.withOpacity(0.5)
              : online ? Colors.green.shade300
              : AppColors.border,
          width: fresh ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Row 1: Avatar + info
          Row(children: [
            Stack(children: [
              CircleAvatar(radius: 20, backgroundColor: AppColors.primaryLight,
                  child: Text(initial, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary))),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis)),
                if (fresh)
                  Container(margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Text('MPYA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                if (online && !fresh)
                  Padding(padding: const EdgeInsets.only(left: 4),
                    child: Text('● online', style: TextStyle(fontSize: 9, color: Colors.green.shade600, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                if (category.isNotEmpty)
                  Text(isEdu ? 'Elimu' : 'Afya',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                if (cadre.isNotEmpty)
                  Expanded(child: Text(' · $cadre',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis)),
              ]),
            ])),
          ]),

          const SizedBox(height: 8),

          // Location box (gray bg kama web)
          if ((station['region_name'] ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.location_on, size: 11, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text('Kutoka: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Expanded(child: Text(
                    [station['district_name'], station['region_name']]
                        .where((v) => v != null && v.toString().isNotEmpty).join(', '),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
                if (activeDest != null && (activeDest['region_name'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.flag, size: 11, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text('Kwenda: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Expanded(child: Text(
                      [activeDest['region_name'], activeDest['district_name']]
                          .where((v) => v != null && v.toString().isNotEmpty).join(', '),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ],
                if (myRegionName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  RichText(text: TextSpan(
                    style: const TextStyle(fontSize: 11, fontFamily: ''),
                    children: [
                      TextSpan('↓ Anakwenda ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      TextSpan(myRegionName, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
                    ],
                  )),
                ],
              ]),
            ),

          // Miaka ya kazi
          if (years != null) ...[
            const SizedBox(height: 6),
            Text('Miaka ya kazi: ${years == 3 ? "3+ (miaka 3 au zaidi)" : "$years ${years == 1 ? 'mwaka' : 'miaka'}"}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],

          // Masomo (kwa walimu)
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              if (anySubjectMatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Text('✓ Masomo yanafanana', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ...subjects.take(4).map((s) {
                final matched = mySubjects.contains(s);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: matched ? AppColors.primaryLight : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$s${matched ? ' ✓' : ''}',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                          color: matched ? AppColors.primary : Colors.grey.shade700)),
                );
              }),
            ]),
          ],

          // Muda
          if (ago.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(fresh ? Icons.bolt : Icons.access_time, size: 11,
                  color: fresh ? AppColors.primary : AppColors.textLight),
              const SizedBox(width: 3),
              Text(fresh ? 'MPYA · $ago iliyopita' : '$ago iliyopita',
                  style: TextStyle(fontSize: 10,
                      color: fresh ? AppColors.primary : AppColors.textLight,
                      fontWeight: fresh ? FontWeight.bold : FontWeight.normal)),
            ]),
            if (fullDate.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2),
                  child: Text(fullDate, style: const TextStyle(fontSize: 9, color: AppColors.textLight))),
          ],

          const SizedBox(height: 10),

          // Buttons: Piga / SMS / WA
          Row(children: [
            Expanded(child: _contactBtn(Icons.phone, 'Piga', Colors.green,
                phoneOk ? () => onContact('call') : null)),
            const SizedBox(width: 6),
            Expanded(child: _contactBtn(Icons.sms, 'SMS', AppColors.primary,
                phoneOk ? () => onContact('sms') : null)),
            if (altOk) ...[
              const SizedBox(width: 6),
              Expanded(child: _contactBtn(Icons.chat, 'WA', const Color(0xFF25D366),
                  () => onContact('whatsapp'))),
            ],
          ]),

          // Toast ndani ya card (kama web)
          if (toast != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/donate'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(children: [
                  Expanded(child: Text(toast!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Changia →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _contactBtn(IconData icon, String label, Color color, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onTap != null ? color.withOpacity(0.4) : AppColors.border),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: onTap != null ? color : AppColors.textLight),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: onTap != null ? color : AppColors.textLight)),
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
  final bool isPaid;
  const _EmptyBoard({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade100, border: Border.all(color: AppColors.border)),
          child: const Icon(Icons.people_outline, size: 28, color: AppColors.textLight),
        ),
        const SizedBox(height: 16),
        Text(isPaid ? 'Hakuna watu kwa sasa' : 'Changia TZS 5,000 kuona namba za watu',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        if (!isPaid) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/donate'),
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Changia Sasa'),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ]),
    ));
  }
}

// ── Announcement Banner ───────────────────────────────────────────────────────
class _AnnouncementBanner extends StatefulWidget {
  final List<dynamic> announcements;
  final void Function(String id) onDismiss;
  const _AnnouncementBanner({required this.announcements, required this.onDismiss});
  @override
  State<_AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<_AnnouncementBanner> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.announcements.isEmpty) return const SizedBox.shrink();
    if (_idx >= widget.announcements.length) _idx = 0;
    final a = widget.announcements[_idx] as Map<String, dynamic>;
    final id = '${a['announcement_id'] ?? a['_id'] ?? ''}';
    final title = '${a['title'] ?? ''}';
    final message = '${a['message'] ?? a['body'] ?? ''}';
    final total = widget.announcements.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.campaign, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(message, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (total > 1)
            Row(children: [
              TextButton(onPressed: _idx > 0 ? () => setState(() => _idx--) : null,
                  child: const Text('← Iliyopita', style: TextStyle(fontSize: 10))),
              TextButton(onPressed: _idx < total - 1 ? () => setState(() => _idx++) : null,
                  child: const Text('Inayofuata →', style: TextStyle(fontSize: 10))),
            ]),
        ])),
        IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.textLight),
          onPressed: () { if (id.isNotEmpty) widget.onDismiss(id); },
          constraints: const BoxConstraints(), padding: const EdgeInsets.all(6)),
      ]),
    );
  }
}
