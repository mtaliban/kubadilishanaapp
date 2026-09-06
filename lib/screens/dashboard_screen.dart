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

String _initials(String name) {
  final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return 'M';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

String _timeAgo(String? isoDate) {
  if (isoDate == null) return '';
  try {
    final d = DateTime.parse(isoDate).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Sasa hivi';
    if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes}';
    if (diff.inHours < 24) return 'saa ${diff.inHours}';
    return 'siku ${diff.inDays}';
  } catch (_) {
    return '';
  }
}

bool _isNew(String? isoDate) {
  if (isoDate == null) return false;
  try {
    final d = DateTime.parse(isoDate).toLocal();
    return DateTime.now().difference(d).inMinutes < 30;
  } catch (_) {
    return false;
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _candidates = [];
  List<dynamic> _trueMatches = [];
  bool _loading = true;
  bool _showTrueMatches = false;
  int _currentIndex = 0;
  int _page = 1;
  static const _pageSize = 5;

  // Announcements
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
    setState(() => _loading = true);
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
      if (mounted) {
        setState(() {
          _candidates = data['candidates'] ?? [];
          _page = 1;
          _loading = false;
        });
      }
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
      if (mounted) {
        setState(() => _announcements = data['announcements'] ?? data['items'] ?? []);
      }
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

  List<dynamic> get _pagedCandidates {
    final start = (_page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _candidates.length);
    return _candidates.sublist(start.clamp(0, _candidates.length), end);
  }

  int get _totalPages => (_candidates.length / _pageSize).ceil().clamp(1, 9999);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final station = user?.currentStation ?? {};
    final initial = _initials(user?.fullName ?? 'M');
    final isPaid = auth.isVerified || (user?.contactEnabled ?? false);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              child: Row(children: [
                const Text('Kubadilishana',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.pushNamed(context, '/notifications')),
                IconButton(icon: const Icon(Icons.people_alt_outlined),
                    onPressed: () => Navigator.pushNamed(context, '/my-matches')),
                IconButton(icon: const Icon(Icons.menu),
                    onPressed: () => _showMenu(context)),
              ]),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.wait([_loadBoard(), _loadTrueMatches()]),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Announcements
                      if (_announcements.isNotEmpty)
                        _AnnouncementBanner(
                          announcements: _announcements,
                          onDismiss: (id) async {
                            await ApiService().dismissAnnouncement(id);
                            setState(() => _announcements.removeWhere(
                                (a) => '${a['announcement_id'] ?? a['_id']}' == id));
                          },
                        ),

                      const SizedBox(height: 10),

                      // ── HERO CARD ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        ),
                        child: Row(children: [
                          // Avatar
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryLight,
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Center(child: Text(initial,
                                style: const TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 16, color: AppColors.primary))),
                          ),
                          const SizedBox(width: 12),
                          // Name + cadre + location
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Karibu, ${user?.fullName ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (auth.isAdmin)
                                    _badge('Admin', AppColors.primary)
                                  else if ((user?.category ?? '').isNotEmpty)
                                    _badge(user!.category == 'health' ? 'Afya' : 'Elimu', AppColors.primary),
                                  if (!auth.isAdmin && (user?.cadreDisplay ?? '').isNotEmpty)
                                    Text('· ${user!.cadreDisplay}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  if ((station['region_name'] ?? '').isNotEmpty)
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.location_on, size: 10, color: AppColors.primary),
                                      Text(
                                        [station['district_name'], station['region_name']]
                                            .where((v) => v != null && v.toString().isNotEmpty)
                                            .join(', '),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ]),
                                ],
                              ),
                            ],
                          )),
                          // Payment status + admin phone
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (!auth.isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(isPaid ? 'AMELIIPIA' : 'HAJALIPIA',
                                    style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.bold,
                                      color: isPaid ? Colors.green.shade700 : Colors.red.shade700,
                                    )),
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

                      const SizedBox(height: 12),

                      // ── TRUE MATCHES ──────────────────────────────────
                      if (_trueMatches.isNotEmpty)
                        _TrueMatchesSection(
                          matches: _trueMatches,
                          expanded: _showTrueMatches,
                          onToggle: () => setState(() => _showTrueMatches = !_showTrueMatches),
                          isPaid: isPaid,
                        ),

                      if (_trueMatches.isNotEmpty) const SizedBox(height: 10),

                      // ── FILTERS ───────────────────────────────────────
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
                          if (v != null && v != '__all__') {
                            _loadDistricts(int.tryParse(v) ?? 0);
                          }
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
                      ),

                      const SizedBox(height: 10),

                      // ── BOARD ─────────────────────────────────────────
                      if (_loading)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ))
                      else if (_candidates.isEmpty)
                        _EmptyBoard(isPaid: isPaid)
                      else ...[
                        // Stats
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            _chip('${_candidates.length} watu', Icons.people, AppColors.primary),
                            const SizedBox(width: 6),
                            _chip('${_candidates.where((c) => c['online'] == true).length} wanaoendesha sasa', Icons.circle, Colors.green),
                          ]),
                        ),
                        ..._pagedCandidates.map((c) => _BoardCard(
                          card: c,
                          isPaid: isPaid,
                          onContact: (type) => _onContact(c, type),
                        )),
                        // Pagination
                        if (_totalPages > 1)
                          _Pagination(page: _page, total: _totalPages,
                            onPrev: _page > 1 ? () => setState(() => _page--) : null,
                            onNext: _page < _totalPages ? () => setState(() => _page++) : null,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // WhatsApp floating button
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Changia TZS 5,000 upate namba'),
        action: SnackBarAction(label: 'Changia →', onPressed: () => Navigator.pushNamed(context, '/donate')),
      ));
      return;
    }
    if (phone.isEmpty) return;

    try {
      await ApiService().logContact(card['user_id'] ?? '', type);
    } catch (_) {}

    Uri uri;
    if (type == 'call') uri = Uri.parse('tel:$phone');
    else if (type == 'sms') uri = Uri.parse('sms:$phone');
    else uri = Uri.parse('https://wa.me/$phoneAlt');

    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.settings), title: const Text('Mipangilio'),
            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/settings'); }),
          ListTile(leading: const Icon(Icons.announcement), title: const Text('Matangazo'),
            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/announcements'); }),
          ListTile(leading: const Icon(Icons.history), title: const Text('Simu Zangu'),
            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/call-history'); }),
          ListTile(leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Toka', style: TextStyle(color: AppColors.error)),
            onTap: () { Navigator.pop(context); context.read<AuthProvider>().logout(); Navigator.pushReplacementNamed(context, '/login'); }),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );

  Widget _chip(String text, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── True Matches Section ──────────────────────────────────────────────────────
class _TrueMatchesSection extends StatelessWidget {
  final List<dynamic> matches;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isPaid;
  const _TrueMatchesSection({required this.matches, required this.expanded, required this.onToggle, required this.isPaid});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
              const SizedBox(width: 8),
              Text('Match za Kweli (${matches.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              const Spacer(),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.green),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1),
          ...matches.take(5).map((m) => _TrueMatchCard(match: m, isPaid: isPaid)),
        ],
      ]),
    );
  }
}

class _TrueMatchCard extends StatelessWidget {
  final dynamic match;
  final bool isPaid;
  const _TrueMatchCard({required this.match, required this.isPaid});

  @override
  Widget build(BuildContext context) {
    final c = match['candidate'] ?? match;
    final score = ((match['score'] ?? 0.0) * 100).round();
    final name = c['full_name'] ?? 'Mtumiaji';
    final initial = _initials(name);
    final scoreColor = score >= 100 ? Colors.green.shade600 : score >= 85 ? Colors.green.shade500 : Colors.green.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: Colors.green.shade50,
          child: Text(initial, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scoreColor))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(c['cadre_display'] ?? c['cadre_code'] ?? '',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('🎯 $score%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scoreColor)),
        ),
      ]),
    );
  }
}

// ── Filters Bar ───────────────────────────────────────────────────────────────
class _FiltersBar extends StatelessWidget {
  final List<dynamic> regions, districts, facilities, cadres;
  final String regionSel, cadreCode;
  final int? districtId;
  final String? facilityId;
  final void Function(String?) onRegionChanged;
  final void Function(int?) onDistrictChanged;
  final void Function(String?) onFacilityChanged;
  final void Function(String?) onCadreChanged;
  final VoidCallback onClear;

  const _FiltersBar({
    required this.regions, required this.districts, required this.facilities, required this.cadres,
    required this.regionSel, required this.districtId, required this.facilityId, required this.cadreCode,
    required this.onRegionChanged, required this.onDistrictChanged,
    required this.onFacilityChanged, required this.onCadreChanged, required this.onClear,
  });

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
  );

  @override
  Widget build(BuildContext context) {
    final hasFilter = regionSel != '__all__' || districtId != null || facilityId != null || cadreCode.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.tune, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('Vichujio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Spacer(),
            if (hasFilter)
              GestureDetector(
                onTap: onClear,
                child: const Text('Futa vichujio', style: TextStyle(fontSize: 11, color: AppColors.error)),
              ),
          ]),
          const SizedBox(height: 8),

          // Region
          DropdownButtonFormField<String>(
            value: regionSel,
            decoration: _dec('Mkoa wote'),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: '__all__', child: Text('Mikoa Yote')),
              ...regions.map((r) => DropdownMenuItem(value: '${r['id']}', child: Text('${r['name']}'))),
            ],
            onChanged: onRegionChanged,
          ),

          if (districts.isNotEmpty) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              value: districtId,
              decoration: _dec('Wilaya yote'),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('Wilaya Yote')),
                ...districts.map((d) => DropdownMenuItem(value: d['id'] as int, child: Text('${d['name']}'))),
              ],
              onChanged: onDistrictChanged,
            ),
          ],

          if (facilities.isNotEmpty) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              value: facilityId,
              decoration: _dec('Kituo chote'),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('Vituo Vyote')),
                ...facilities.map((f) => DropdownMenuItem(
                  value: '${f['id'] ?? f['code']}',
                  child: Text('${f['name']}', overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: onFacilityChanged,
            ),
          ],

          if (cadres.isNotEmpty) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: cadreCode.isEmpty ? '' : cadreCode,
              decoration: _dec('Kada yote'),
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
        ],
      ),
    );
  }
}

// ── Board Card ────────────────────────────────────────────────────────────────
class _BoardCard extends StatelessWidget {
  final dynamic card;
  final bool isPaid;
  final void Function(String type) onContact;

  const _BoardCard({required this.card, required this.isPaid, required this.onContact});

  @override
  Widget build(BuildContext context) {
    final name = card['full_name'] ?? 'Mtumiaji';
    final cadre = card['cadre_display'] ?? card['cadre_code'] ?? '';
    final category = card['category'] ?? '';
    final station = card['current_station'] ?? {};
    final dests = (card['desired_destinations'] as List?)?.take(2).toList() ?? [];
    final online = card['online'] == true;
    final isNew = _isNew(card['created_at'] ?? card['joined_at']);
    final phoneOk = (card['phone_primary'] ?? '').isNotEmpty;
    final altOk = (card['phone_alt'] ?? '').isNotEmpty;
    final initial = _initials(name);
    final ago = _timeAgo(card['created_at'] ?? card['joined_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isNew ? AppColors.primary.withOpacity(0.3) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Row 1: Avatar + name + cadre + badges
          Row(children: [
            Stack(children: [
              CircleAvatar(radius: 22, backgroundColor: AppColors.primaryLight,
                child: Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary))),
              if (online)
                Positioned(right: 0, bottom: 0,
                  child: Container(width: 10, height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.green,
                      border: Border.all(color: Colors.white, width: 1.5)))),
            ]),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis)),
                if (isNew)
                  Container(margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                    child: const Text('MPYA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary))),
              ]),
              const SizedBox(height: 2),
              Wrap(spacing: 4, children: [
                if (category.isNotEmpty)
                  Text(category == 'health' ? 'Afya' : 'Elimu',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                if (cadre.isNotEmpty)
                  Text('· $cadre', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis),
              ]),
            ])),
          ]),

          const SizedBox(height: 8),

          // Location: Kutoka
          if ((station['region_name'] ?? '').isNotEmpty)
            _locRow(Icons.location_on, 'Kutoka',
                [station['district_name'], station['region_name']].where((v) => v != null && v.toString().isNotEmpty).join(', ')),

          // Destinations: Kwenda
          for (final d in dests)
            if ((d['region_name'] ?? '').isNotEmpty)
              _locRow(Icons.flag, 'Kwenda',
                  [d['district_name'], d['region_name']].where((v) => v != null && v.toString().isNotEmpty).join(', ')),

          // Timestamp
          if (ago.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(isNew ? Icons.bolt : Icons.access_time, size: 11, color: isNew ? AppColors.primary : AppColors.textLight),
                const SizedBox(width: 4),
                Text(isNew ? 'MPYA · $ago iliyopita' : '$ago iliyopita',
                    style: TextStyle(fontSize: 10, color: isNew ? AppColors.primary : AppColors.textLight,
                        fontWeight: isNew ? FontWeight.bold : FontWeight.normal)),
              ])),

          const SizedBox(height: 10),

          // Contact buttons
          Row(children: [
            _contactBtn(Icons.phone, 'Piga', Colors.green, () => onContact('call')),
            const SizedBox(width: 6),
            _contactBtn(Icons.sms, 'SMS', AppColors.primary, () => onContact('sms')),
            if (altOk) ...[
              const SizedBox(width: 6),
              _contactBtn(Icons.chat, 'WA', const Color(0xFF25D366), () => onContact('whatsapp')),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _locRow(IconData icon, String label, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Icon(icon, size: 11, color: AppColors.textLight),
      const SizedBox(width: 4),
      Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _contactBtn(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 6),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
        OutlinedButton(onPressed: onPrev, child: const Text('← Iliyopita', style: TextStyle(fontSize: 12))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$page / $total', style: const TextStyle(fontWeight: FontWeight.bold))),
        OutlinedButton(onPressed: onNext, child: const Text('Inayofuata →', style: TextStyle(fontSize: 12))),
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
        Icon(Icons.people_outline, size: 64, color: AppColors.textLight),
        const SizedBox(height: 16),
        Text(isPaid ? 'Hakuna watu kwa sasa' : 'Changia TZS 5,000 kuona namba',
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary), textAlign: TextAlign.center),
        if (!isPaid) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/donate'),
            icon: const Icon(Icons.payment), label: const Text('Changia Sasa'),
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
          Text(message, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
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

