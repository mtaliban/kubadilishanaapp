// ============================================================================
// WALIOPATA WENZAO — watumiaji waliounganishwa na wenzao (matches)
// Design (kama reference pages zingine):
//  - Header yenye icon badge + Live badge + hesabu
//  - Filter chips (Mkoa wa Lengo / Idara / Kada / Kutoka) → picker sheets
//    zenye search + blue highlight (kama reference)
//  - Idara na Kada ni DYNAMIC kutoka DB (getDepartments/getCadres) — hakuna
//    hardcoded Elimu/Afya tu; idara mpya (mf. Kilimo na Ufugaji) inaonekana
//  - Kadi: avatar + dot ya online, jina (title case, linashuka mstari),
//    badge ya malipo, Kutoka → Anataka Kuja, miaka ya kazi, masomo, simu
//  - Pagination yenye dirisha la kurasa 5 + scroll-to-top
// Data halisi: GET /admin/users/with-matches
// ============================================================================
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

const _kPrimary = Color(0xFF1E40AF);
const _kBg      = Color(0xFFF8FAFC);
const _kInk     = Color(0xFF0F172A);
const _kMuted   = Color(0xFF64748B);
const _kLine    = Color(0xFFE2E8F0);
const _kSoft    = Color(0xFFF1F5F9);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kBlue100 = Color(0xFFDBEAFE);
const _kBlue700 = Color(0xFF1D4ED8);
const _kGreen   = Color(0xFF15803D);
const _kGreenBg = Color(0xFFDCFCE7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);

const _kPs = 10; // kadi kwa kurasa (kadi ni ndefu)

String _titleCase(String s) => s
    .trim()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _prettyRole(String r) {
  if (r.isEmpty || !r.contains('_')) return r;
  final s = r.replaceAll('_', ' ').toLowerCase();
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

String _yearsText(num? y) {
  if (y == null) return '';
  if (y >= 3) return '3+ miaka ya kazi';
  return y == 1 ? 'Mwaka 1 wa kazi' : 'Miaka ${y.toInt()} ya kazi';
}

// ───────────────────────── Page ─────────────────────────
class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});

  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _all = [];

  // Reference data (dynamic kutoka DB)
  List<dynamic> _regions = [];
  List<dynamic> _departments = [];
  List<Map<String, dynamic>> _cadres = [];

  // Filters
  String? _targetRegionName;
  String? _sourceRegionName;
  String _category = ''; // department code ('' = zote)
  String _cadreCode = ''; // cadre code ('' = zote)
  String _query = '';

  int _page = 1;

  // ── Lookups ────────────────────────────────────────────────────────────────
  String _deptLabel(String code) {
    for (final d in _departments) {
      if ('${d['code']}' == code) return '${d['display_name'] ?? d['name'] ?? code}';
    }
    switch (code) {
      case 'education':         return 'Elimu';
      case 'health':            return 'Afya';
      case 'kilimo':            return 'Kilimo na Ufugaji';
      case 'watumishi_wa_umma': return 'Watumishi wa Umma';
      default:                  return code.isEmpty ? '—' : _titleCase(code);
    }
  }

  String _cadreLabel(String code) {
    for (final c in _cadres) {
      if ('${c['code']}' == code) return '${c['display_name'] ?? c['name'] ?? code}';
    }
    return code.isEmpty ? '—' : _prettyRole(code);
  }

  List<Map<String, dynamic>> get _cadreOptions {
    if (_category.isEmpty) return _cadres;
    return _cadres.where((c) => '${c['category'] ?? ''}' == _category).toList();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'[^0-9+]'), '');
    return _all.where((m) {
      if (_category.isNotEmpty && '${m['category'] ?? ''}' != _category) return false;
      if (_cadreCode.isNotEmpty && '${m['cadre_code'] ?? ''}' != _cadreCode) return false;
      if (_targetRegionName != null) {
        final dests = ((m['destinations'] as List?) ?? [])
            .map((d) => d is Map ? '${d['region_name'] ?? d['name'] ?? d}' : '$d')
            .map((s) => s.toLowerCase());
        if (!dests.contains(_targetRegionName!.toLowerCase())) return false;
      }
      if (_sourceRegionName != null) {
        final rn = '${m['region_name'] ?? m['current_region'] ?? ''}';
        if (rn.toLowerCase() != _sourceRegionName!.toLowerCase()) return false;
      }
      if (q.isEmpty) return true;
      final name = '${m['full_name'] ?? ''}'.toLowerCase();
      final phone = '${m['phone_primary'] ?? ''}'.replaceAll(RegExp(r'[^0-9+]'), '');
      final cadre = '${m['cadre_display'] ?? m['cadre_code'] ?? ''}'.toLowerCase();
      final dist = '${m['district_name'] ?? ''}'.toLowerCase();
      return name.contains(q) ||
          cadre.contains(q) ||
          dist.contains(q) ||
          (digits.isNotEmpty && phone.contains(digits));
    }).toList();
  }

  int get _totalPages => _filtered.isEmpty ? 1 : (_filtered.length / _kPs).ceil();
  int get _safe => _page.clamp(1, _totalPages);
  List<Map<String, dynamic>> get _pageItems {
    final s = (_safe - 1) * _kPs;
    return _filtered.sublist(s, (s + _kPs).clamp(0, _filtered.length));
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminUsersWithMatches(limit: 200);
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : ((data['users'] ?? data['results'] ?? []) as List);
      setState(() {
        _all = list.whereType<Map<String, dynamic>>().toList();
        _loading = false;
        _page = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadRefs() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _regions = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []));
    } catch (_) {}
    try {
      final r = await ApiService().getDepartments();
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []);
      setState(() => _departments = list
          .where((d) => '${d['is_active'] ?? d['active'] ?? true}' != 'false')
          .toList());
    } catch (_) {}
    try {
      final r = await ApiService().getCadres();
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List ? raw : (raw['cadres'] ?? raw['data'] ?? []);
      setState(() => _cadres = list.whereType<Map<String, dynamic>>().toList());
    } catch (_) {}
  }

  void _goToPage(int p) {
    setState(() => _page = p.clamp(1, _totalPages));
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ── Pickers (sheets zenye search, kama reference) ──────────────────────────
  void _openPicker(
    String title,
    List<(String, String)> options,
    String current,
    void Function(String) onPick,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) {
        final ctrl = TextEditingController();
        var filtered = List<(String, String)>.from(options);
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => StatefulBuilder(
            builder: (ctx, ss) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, color: _kInk)),
                  IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
                TextField(
                  controller: ctrl,
                  onChanged: (q) => ss(() {
                    final ql = q.toLowerCase();
                    filtered = options.where((o) => o.$2.toLowerCase().contains(ql)).toList();
                  }),
                  decoration: InputDecoration(
                    hintText: 'Tafuta...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: _kBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      for (final o in filtered)
                        _pickerTile(o.$2, current == o.$1, () {
                          Navigator.pop(ctx);
                          onPick(o.$1);
                        }),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _pickerTile(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F1FB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: const Color(0xFF378ADD)) : null,
        ),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? _kPrimary : _kInk)),
          ),
          if (selected) const Icon(Icons.check_rounded, color: _kPrimary, size: 18),
        ]),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _filterChip(IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kPrimary : _kLine),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? Colors.white : _kMuted),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _kInk)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: active ? Colors.white : _kMuted),
        ]),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    // Options za pickers
    final deptOpts = <(String, String)>[
      ('', 'Idara Zote'),
      for (final d in _departments) ('${d['code']}', '${d['display_name'] ?? d['name'] ?? d['code']}'),
    ];
    final cadreOpts = <(String, String)>[
      ('', 'Kada Zote'),
      for (final c in _cadreOptions) ('${c['code']}', '${c['display_name'] ?? c['name'] ?? c['code']}'),
    ];
    final targetOpts = <(String, String)>[
      ('', 'Mikoa yote'),
      for (final r in _regions) ('${r['name'] ?? r['region_name'] ?? ''}', '${r['name'] ?? r['region_name'] ?? ''}'),
    ];
    final sourceOpts = <(String, String)>[
      ('', 'Mikoa yote'),
      for (final r in _regions) ('${r['name'] ?? r['region_name'] ?? ''}', '${r['name'] ?? r['region_name'] ?? ''}'),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kPrimary,
        child: ListView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            // ── Header ──
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.compare_arrows_rounded, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Waliopata Wenzao',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kInk)),
              ),
              const _StatusChip(online: true),
            ]),
            const SizedBox(height: 8),
            Text(
              _loading
                  ? 'Inapakia...'
                  : '${filtered.length} ${filtered.length == 1 ? 'mtu' : 'watu'} waliounganishwa na wenzao',
              style: const TextStyle(fontSize: 15, color: _kMuted, height: 1.4),
            ),
            const SizedBox(height: 16),

            // ── Filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip(
                    Icons.map_rounded,
                    _targetRegionName ?? 'Mkoa wa Lengo',
                    _targetRegionName != null,
                    () => _openPicker('Chagua Mkoa wa Lengo', targetOpts,
                            _targetRegionName ?? '', (v) {
                          setState(() => _targetRegionName = v.isEmpty ? null : v);
                        })),
                const SizedBox(width: 8),
                _filterChip(
                    Icons.apartment_rounded,
                    _category.isEmpty ? 'Idara zote' : _deptLabel(_category),
                    _category.isNotEmpty, () {
                  if (_departments.isEmpty) return;
                  _openPicker('Chagua Idara', deptOpts, _category, (v) {
                    setState(() {
                      _category = v;
                      _cadreCode = '';
                    });
                  });
                }),
                const SizedBox(width: 8),
                _filterChip(
                    Icons.badge_rounded,
                    _cadreCode.isEmpty ? 'Kada zote' : _cadreLabel(_cadreCode),
                    _cadreCode.isNotEmpty, () {
                  if (_cadres.isEmpty) return;
                  _openPicker('Chagua Kada', cadreOpts, _cadreCode, (v) {
                    setState(() => _cadreCode = v);
                  });
                }),
                const SizedBox(width: 8),
                _filterChip(
                    Icons.logout_rounded,
                    _sourceRegionName != null ? 'Kutoka: $_sourceRegionName' : 'Kutoka: yote',
                    _sourceRegionName != null,
                    () => _openPicker('Chagua Mkoa wa Chanzo', sourceOpts,
                            _sourceRegionName ?? '', (v) {
                          setState(() => _sourceRegionName = v.isEmpty ? null : v);
                        })),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Search ──
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() {
                _query = v;
                _page = 1;
              }),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Tafuta kwa jina, namba, kada au wilaya',
                prefixIcon: const Icon(Icons.search_rounded, color: _kMuted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Futa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                          _page = 1;
                        }),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kLine)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kLine)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kPrimary, width: 1.6)),
              ),
            ),
            const SizedBox(height: 14),

            if (!_loading && _error == null)
              Text(
                'Inaonyesha ${_pageItems.length} kati ya ${filtered.length}',
                style: const TextStyle(fontSize: 13, color: _kMuted),
              ),
            const SizedBox(height: 10),

            // ── Body ──
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: _kPrimary)),
              )
            else if (_error != null)
              _ErrorState(onRetry: _load)
            else if (filtered.isEmpty)
              _EmptyState(onClear: () {
                setState(() {
                  _searchCtrl.clear();
                  _query = '';
                  _category = '';
                  _cadreCode = '';
                  _targetRegionName = null;
                  _sourceRegionName = null;
                  _page = 1;
                });
              })
            else ...[
              for (final u in _pageItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MatchCard(
                    user: u,
                    deptLabel: _deptLabel,
                    cadreLabel: _cadreLabel,
                  ),
                ),
              _Pager(page: _safe, total: _totalPages, onPage: _goToPage),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────
class _StatusChip extends StatelessWidget {
  final bool online;
  const _StatusChip({required this.online});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: online ? _kGreenBg : _kSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 6),
        Text(online ? 'Live' : 'Offline',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: online ? const Color(0xFF166534) : _kMuted)),
      ]),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int total;
  final ValueChanged<int> onPage;
  const _Pager({required this.page, required this.total, required this.onPage});

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final start = (page - 2).clamp(0, (total - 5).clamp(0, 1 << 31));
    final end = (start + 5).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.outlined(
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (var i = start; i < end; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onPage(i + 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i + 1 == page ? _kPrimary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: i + 1 == page ? _kPrimary : _kLine),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: i + 1 == page ? Colors.white : _kInk)),
              ),
            ),
          ),
        IconButton.outlined(
          onPressed: page < total ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kLine),
      ),
      child: Column(children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        const Text('Imeshindikana kupakia',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Jaribu tena', style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: _kPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kLine),
      ),
      child: Column(children: [
        const Icon(Icons.compare_arrows_rounded, size: 40, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        const Text('Hakuna waliounganishwa',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Badilisha vichujio au jaribu tena baadaye.',
            style: TextStyle(color: _kMuted, fontSize: 15)),
        const SizedBox(height: 14),
        TextButton(onPressed: onClear, child: const Text('Futa vichujio')),
      ]),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String Function(String) deptLabel;
  final String Function(String) cadreLabel;
  const _MatchCard({required this.user, required this.deptLabel, required this.cadreLabel});

  @override
  Widget build(BuildContext context) {
    final name = '${user['full_name'] ?? ''}';
    final phone = '${user['phone_primary'] ?? ''}';
    final category = '${user['category'] ?? ''}';
    final cadreCode = '${user['cadre_code'] ?? ''}';
    final cadre = cadreCode.isEmpty
        ? ''
        : (user['cadre_display'] as String? ?? cadreLabel(cadreCode));
    final currReg = '${user['region_name'] ?? user['current_region'] ?? ''}';
    final currDist = '${user['district_name'] ?? user['current_district'] ?? ''}';
    final dests = ((user['destinations'] as List?) ?? [])
        .map((d) => d is Map ? '${d['region_name'] ?? d['name'] ?? d}' : '$d')
        .where((s) => s.isNotEmpty)
        .toList();
    final years = user['years_of_service'] as num?;
    final subjects = ((user['subjects'] as List?) ?? [])
        .map((s) => s is Map ? '${s['name'] ?? s['code'] ?? s}' : '$s')
        .where((s) => s.isNotEmpty)
        .toList();
    final isPaid = user['is_verified'] == true;
    final online = user['online'] == true;

    final sub = [
      if (category.isNotEmpty) deptLabel(category),
      if (cadre.isNotEmpty) cadre,
    ].join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: phone.isEmpty
            ? null
            : () async {
                try {
                  await launchUrl(Uri.parse('tel:$phone'),
                      mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kLine),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Avatar + jina + badge ya malipo ──
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _kBlueBg,
                  child: Text(_initials(name),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: _kPrimary)),
                ),
                if (online)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
                    Text(name.isEmpty ? '(bila jina)' : _titleCase(name),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                            height: 1.25)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid ? _kGreenBg : _kRedBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPaid ? '✓ Amelipa' : '✗ Hajalipa',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isPaid ? _kGreen : _kRed),
                      ),
                    ),
                  ]),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 13, color: _kMuted, height: 1.3)),
                  ],
                ]),
              ),
            ]),

            // ── Kutoka / Anataka Kuja ──
            if (currReg.isNotEmpty || currDist.isNotEmpty || dests.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kBlueBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBlue100),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (currReg.isNotEmpty || currDist.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: _kMuted),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            const TextSpan(
                                text: 'Kutoka: ',
                                style: TextStyle(
                                    fontSize: 13, color: _kMuted)),
                            TextSpan(
                                text: [currReg, currDist]
                                    .where((s) => s.isNotEmpty)
                                    .join(', '),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kInk)),
                          ]),
                        ),
                      ),
                    ]),
                  if (dests.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.compare_arrows_rounded, size: 15, color: _kPrimary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            const TextSpan(
                                text: 'Anataka Kuja: ',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary)),
                            TextSpan(
                                text: dests.join(', '),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary)),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            ],

            // ── Miaka ya kazi ──
            if (years != null) ...[
              const SizedBox(height: 10),
              Text(_yearsText(years),
                  style: const TextStyle(
                      fontSize: 13,
                      color: _kMuted,
                      fontWeight: FontWeight.w500)),
            ],

            // ── Masomo ──
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ...subjects.take(5).map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kBlueBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kBlue700)),
                    )),
                if (subjects.length > 5)
                  Text('+${subjects.length - 5}',
                      style: const TextStyle(fontSize: 12, color: _kMuted)),
              ]),
            ],

            // ── Simu ──
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _kSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.phone_rounded, size: 16, color: _kPrimary),
                  const SizedBox(width: 8),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
