import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Color tokens — exact Tailwind hex, kama web
// ─────────────────────────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);  // brand-blue
const _kBlue50  = Color(0xFFEFF6FF);  // blue-50
const _kBlue100 = Color(0xFFDBEAFE);  // blue-100
const _kBlue200 = Color(0xFFBFDBFE);  // blue-200
const _kBlue700 = Color(0xFF1D4ED8);  // blue-700
const _kGrey100 = Color(0xFFF3F4F6);  // grey-100
const _kGrey200 = Color(0xFFE5E7EB);  // grey-200
const _kGrey300 = Color(0xFFD1D5DB);  // grey-300
const _kGrey400 = Color(0xFF9CA3AF);  // grey-400
const _kGrey500 = Color(0xFF6B7280);  // grey-500
const _kGrey700 = Color(0xFF374151);  // grey-700
const _kGrey900 = Color(0xFF111827);  // grey-900
const _kEmerald = Color(0xFF10B981);  // emerald-500
const _kRed400  = Color(0xFFF87171);  // red-400
const _kGreen   = Color(0xFF22C55E);  // green-500

// Web `input` class → py-1.5 px-2.5 text-xs rounded-md border-grey-300
const _kInputPad    = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
const _kInputRadius = 6.0;
const _kInputFs     = 12.0;

// ─────────────────────────────────────────────────────────────────────────────
// Cadre lookup — mirrors EDUCATION_CADRES + HEALTH_CADRES kwenye web
// ─────────────────────────────────────────────────────────────────────────────
const _kCadres = <(String, String)>[
  ('TEACHER_PRIMARY',   'Mwalimu wa Msingi'),
  ('TEACHER_SECONDARY', 'Mwalimu wa Sekondari'),
  ('TEACHER_SPECIAL',   'Mwalimu wa Elimu ya Pekee'),
  ('MD',         'Daktari (MD)'),
  ('CO',         'Afisa wa Afya (CO)'),
  ('ACO',        'Msaidizi wa Afisa wa Afya'),
  ('CA',         'Msaidizi wa Kliniki'),
  ('AMO',        'Msaidizi wa Daktari'),
  ('NO',         'Afisa wa Ugojaji (NO)'),
  ('RN',         'Muuguzi Aliyesajiliwa (RN)'),
  ('EN',         'Muuguzi Aliyeandikwa (EN)'),
  ('ANO',        'Msaidizi wa Ugojaji (ANO)'),
  ('HA',         'Msaidizi wa Afya (HA)'),
  ('MA',         'Msaidizi wa Matibabu (MA)'),
  ('LAB_TECH_1', 'Teknolojia ya Maabara I'),
  ('LAB_TECH_2', 'Teknolojia ya Maabara II'),
  ('LAB_SCI_2',  'Wanasayansi wa Maabara II'),
  ('LAB_ASST',   'Msaidizi wa Maabara'),
  ('SR_LAB_ASST','Msaidizi Mkuu wa Maabara'),
  ('MALT',       'Teknolojia ya Maabara ya Matibabu'),
  ('PHARM_2',    'Daktari wa Pharmacy II'),
];

String _catLabel(String cat) {
  if (cat == 'education') return 'Elimu';
  if (cat == 'health') return 'Afya';
  return cat.isEmpty ? '—' : cat;
}

String _cadreLabel(String code) {
  for (final c in _kCadres) { if (c.$1 == code) return c.$2; }
  return code.isEmpty ? '—' : code;
}

List<(String, String)> _cadreOptions(String cat) {
  if (cat == 'education') return _kCadres.where((c) => c.$1.startsWith('TEACHER')).toList();
  if (cat == 'health') return _kCadres.where((c) => !c.$1.startsWith('TEACHER')).toList();
  return _kCadres.toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});

  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Filters
  String _category    = '';
  String _cadreCode   = '';
  String? _targetRegionName;
  String? _sourceRegionName;

  // Reference
  List<dynamic> _regions = [];

  // Pagination — PAGE_SIZE = 12 kama web
  int _page = 1;
  static const _ps = 12;

  @override
  void initState() {
    super.initState();
    _load();
    _loadRegions();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _applyFilter());
  }

  Future<void> _loadRegions() async {
    try {
      final r = await ApiService().getRegions();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _regions = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminUsersWithMatches(limit: 200);
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : ((data['users'] ?? data['results'] ?? []) as List);
      setState(() { _all = list; _loading = false; });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    final q     = _searchCtrl.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _page = 1;
      _filtered = _all.where((item) {
        final m = item as Map;
        if (_category.isNotEmpty && '${m['category'] ?? ''}' != _category) return false;
        if (_cadreCode.isNotEmpty && '${m['cadre_code'] ?? ''}' != _cadreCode) return false;
        if (_targetRegionName != null) {
          final dests = ((m['destinations'] as List?) ?? [])
              .map((d) => d is Map ? '${d['region_name'] ?? d['name'] ?? d}' : '$d')
              .map((s) => s.toLowerCase());
          if (!dests.contains(_targetRegionName!.toLowerCase())) return false;
        }
        if (_sourceRegionName != null) {
          final rn = '${m['region_name'] ?? ''.toLowerCase()}';
          if (rn.toLowerCase() != _sourceRegionName!.toLowerCase()) return false;
        }
        if (q.isEmpty) return true;
        final name  = '${m['full_name'] ?? ''}'.toLowerCase();
        final phone = '${m['phone_primary'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
        final cadre = '${m['cadre_display'] ?? m['cadre_code'] ?? ''}'.toLowerCase();
        final dist  = '${m['district_name'] ?? ''}'.toLowerCase();
        return name.contains(q) || cadre.contains(q) || dist.contains(q) ||
            (digits.isNotEmpty && phone.contains(digits));
      }).toList();
    });
  }

  // ── Pagination ──────────────────────────────────────────────────────────────
  int get _totalPages => _filtered.isEmpty ? 1 : (_filtered.length / _ps).ceil();
  int get _safe   => _page.clamp(1, _totalPages);
  List<dynamic> get _pageItems {
    final s = (_safe - 1) * _ps;
    return _filtered.sublist(s, (s + _ps).clamp(0, _filtered.length));
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _kBlue,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ─────────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),
              // ── Filters ────────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildFilters()),
              // ── Body ───────────────────────────────────────────────────────
              if (_loading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: _kBlue)))
              else if (_error != null)
                SliverFillRemaining(child: _buildError())
              else if (_filtered.isEmpty)
                SliverFillRemaining(child: _buildEmpty())
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList.separated(
                    itemCount: _pageItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) =>
                        _UserCard(user: _pageItems[i] as Map<String, dynamic>),
                  ),
                ),
                if (_totalPages > 1) SliverToBoxAdapter(child: _buildPagination()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  // Web: <h1 text-xl font-bold flex gap-2><ArrowLeftRight/>Wanaohamia Mkoa</h1>
  //      <p text-sm text-grey-500 mt-0.5>subtitle</p>
  Widget _buildHeader() {
    final count = _filtered.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.compare_arrows_rounded, size: 22, color: _kBlue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Waliopata Wenzao',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kGrey900)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(
          _loading
              ? 'Inapakia...'
              : '$count ${count == 1 ? 'mtu' : 'watu'} waliounganishwa',
          style: const TextStyle(fontSize: 14, color: _kGrey500),
        ),
      ]),
    );
  }

  // ── Filters ────────────────────────────────────────────────────────────────
  // Web: flex flex-col gap-2 → 4 selects + search (stacked kwenye mobile)
  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Mkoa wa Lengo
        _selBtn(
          _targetRegionName ?? '— Chagua Mkoa wa Lengo —',
          () => _openRegionPicker('Chagua Mkoa wa Lengo', (name) {
            setState(() { _targetRegionName = name; });
            _applyFilter();
          }, _targetRegionName, clearLabel: '— Mikoa yote —'),
          active: _targetRegionName != null,
        ),
        const SizedBox(height: 8),
        // Idara
        _selBtn(
          _category.isEmpty ? 'Idara Zote' : _catLabel(_category),
          () => _openFixedPicker('Chagua Idara', [
            ('', 'Idara Zote'),
            ('education', 'Elimu'),
            ('health', 'Afya'),
          ], _category, (v) {
            setState(() { _category = v; _cadreCode = ''; });
            _applyFilter();
          }),
          active: _category.isNotEmpty,
        ),
        const SizedBox(height: 8),
        // Kada
        _selBtn(
          _cadreCode.isEmpty ? 'Kada Zote' : _cadreLabel(_cadreCode),
          () {
            final opts = _cadreOptions(_category);
            _openFixedPicker('Chagua Kada', [('', 'Kada Zote'), ...opts], _cadreCode, (v) {
              setState(() => _cadreCode = v);
              _applyFilter();
            });
          },
          active: _cadreCode.isNotEmpty,
        ),
        const SizedBox(height: 8),
        // Mkoa wa Chanzo
        _selBtn(
          _sourceRegionName != null ? 'Kutoka: $_sourceRegionName' : 'Kutoka: Mikoa yote',
          () => _openRegionPicker('Kutoka Mkoa', (name) {
            setState(() => _sourceRegionName = name);
            _applyFilter();
          }, _sourceRegionName, clearLabel: 'Mikoa yote'),
          active: _sourceRegionName != null,
        ),
        const SizedBox(height: 8),
        // Search
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: _kInputFs, color: _kGrey900),
          decoration: InputDecoration(
            hintText: 'Tafuta kwa jina, namba ya simu, kada au wilaya...',
            hintStyle: const TextStyle(color: _kGrey400, fontSize: _kInputFs),
            prefixIcon: const Icon(Icons.search_rounded, size: 14, color: _kGrey400),
            isDense: true,
            contentPadding: _kInputPad,
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kInputRadius),
                borderSide: const BorderSide(color: _kGrey300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kInputRadius),
                borderSide: const BorderSide(color: _kGrey300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kInputRadius),
                borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          ),
        ),
      ]),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  // Web: card text-center py-10 + grey circle icon + texts
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kGrey100),
        ),
        child: Column(children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
            child: const Icon(Icons.compare_arrows_rounded, size: 24, color: _kGrey400),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Hakuna mtumiaji waliounganishwa kwa kichujio hiki',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Wataonekana watumiaji watakapounganishwa',
            style: TextStyle(fontSize: 12, color: _kGrey400),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.error),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kGrey500)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Jaribu tena'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue, foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }

  // ── Pagination ──────────────────────────────────────────────────────────────
  // Web: flex gap-3 ← Rudi | n/N | Endelea →
  Widget _buildPagination() {
    final cur = _safe;
    final tot = _totalPages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _pageBtn('← Rudi', cur <= 1 ? null : () => setState(() => _page = cur - 1)),
        const SizedBox(width: 12),
        Text('$cur / $tot',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kGrey500)),
        const SizedBox(width: 12),
        _pageBtn('Endelea →', cur >= tot ? null : () => setState(() => _page = cur + 1)),
      ]),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _selBtn(String label, VoidCallback onTap, {bool active = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: _kInputPad,
          decoration: BoxDecoration(
            color: active ? _kBlue50 : Colors.white,
            border: Border.all(
                color: active ? _kBlue : _kGrey300,
                width: active ? 1.5 : 1.0),
            borderRadius: BorderRadius.circular(_kInputRadius),
          ),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: _kInputFs,
                      color: active ? _kBlue : _kGrey900,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400),
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 15, color: active ? _kBlue : _kGrey500),
          ]),
        ),
      );

  Widget _pageBtn(String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _kGrey200),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
      ),
    ),
  );

  // ── Pickers ─────────────────────────────────────────────────────────────────
  void _openRegionPicker(String title, void Function(String?) onPick,
      String? current, {required String clearLabel}) {
    final items = <Map<String, String>>[
      {'id': '', 'name': clearLabel},
      for (final r in _regions)
        {'id': '${r['id'] ?? r['region_id'] ?? ''}',
         'name': '${r['name'] ?? r['region_name'] ?? ''}'},
    ];
    _openSheet(title, items, current ?? '', (v) {
      onPick(v.isEmpty ? null : items.firstWhere(
          (i) => i['id'] == v, orElse: () => {})['name']);
    });
  }

  void _openFixedPicker(String title, List<(String, String)> opts,
      String current, void Function(String) onPick) {
    _openSheet(
      title,
      opts.map((e) => {'id': e.$1, 'name': e.$2}).toList(),
      current,
      onPick,
    );
  }

  void _openSheet(String title, List<Map<String, String>> items,
      String current, void Function(String) onPick) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) {
          var filtered = List<Map<String, String>>.from(items);
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(children: [
              const SizedBox(height: 6),
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: _kGrey200,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(child: Text(title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                          color: _kGrey900))),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(width: 30, height: 30,
                        decoration: const BoxDecoration(color: _kGrey100,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16, color: _kGrey700)),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: ctrl,
                  onChanged: (q) {
                    final ql = q.toLowerCase();
                    ss(() => filtered = items
                        .where((i) => i['name']!.toLowerCase().contains(ql))
                        .toList());
                  },
                  decoration: InputDecoration(
                    hintText: 'Tafuta...',
                    hintStyle: const TextStyle(color: _kGrey400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 18),
                    fillColor: _kGrey100, filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: _kGrey200),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final sel  = item['id'] == current;
                    return InkWell(
                      onTap: () { Navigator.pop(ctx); onPick(item['id']!); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: sel ? _kBlue50 : Colors.transparent,
                          border: const Border(
                              bottom: BorderSide(color: _kGrey200)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(item['name']!,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: sel ? _kBlue : _kGrey900)),
                          ),
                          if (sel)
                            const Icon(Icons.check_rounded,
                                color: _kBlue, size: 18),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserCard — matches web UserCard exactly (mobile card)
// ─────────────────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name     = '${user['full_name'] ?? ''}';
    final phone    = '${user['phone_primary'] ?? ''}';
    final category = '${user['category'] ?? ''}';
    final cadreCode = '${user['cadre_code'] ?? ''}';
    final cadre    = '${user['cadre_display'] ?? _cadreLabel(cadreCode)}';
    final currReg  = '${user['region_name'] ?? user['current_region'] ?? ''}';
    final currDist = '${user['district_name'] ?? user['current_district'] ?? ''}';
    final dests    = ((user['destinations'] as List?) ?? [])
        .map((d) => d is Map
            ? '${d['region_name'] ?? d['name'] ?? d}'
            : '$d')
        .where((s) => s.isNotEmpty)
        .toList();
    final destText = dests.join(', ');
    final years    = user['years_of_service'] as num?;
    final subjects = ((user['subjects'] as List?) ?? [])
        .map((s) => s is Map ? '${s['name'] ?? s['code'] ?? s}' : '$s')
        .where((s) => s.isNotEmpty)
        .toList();
    final isPaid   = user['is_verified'] == true;
    final online   = user['online'] == true;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2)
            .map((w) => w[0]).join().toUpperCase();

    return Container(
      // rounded-xl bg-white border border-grey-200 shadow-sm
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16), // p-4
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Row 1: Avatar + jina + paid badge ────────────────────
          // Web: flex items-center gap-3
          Row(children: [
            Stack(children: [
              // w-10 h-10 rounded-full bg-blue-50 border-blue-200 text-sm font-bold text-blue-700
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kBlue50,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBlue200),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kBlue700)),
              ),
              // Online dot: absolute bottom-0 right-0 w-2.5 h-2.5 bg-green-500 border-2-white
              if (online)
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 12), // gap-3
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Name + paid badge: flex items-center gap-1.5 (name truncates, badge fixed)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? '(bila jina)' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kGrey900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // text-[9px] font-bold text-white bg-emerald-500/red-400 px-1.5 py-0.5 rounded-full
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPaid ? _kEmerald : _kRed400,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        isPaid ? '✓ PAID' : '✗ HAJALIPIA',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2), // mt-0.5
                // text-xs text-grey-500: category (blue semibold) · cadre
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: _catLabel(category),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kBlue),
                    ),
                    if (cadre.trim().isNotEmpty) ...[
                      const TextSpan(
                          text: ' · ',
                          style: TextStyle(fontSize: 12, color: _kGrey500)),
                      TextSpan(
                          text: cadre,
                          style: const TextStyle(
                              fontSize: 12, color: _kGrey500)),
                    ],
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ]),

          const SizedBox(height: 12), // gap-3

          // ── Kutoka → Kuja ─────────────────────────────────────────
          // Web: bg-blue-50 border-blue-100 rounded-xl px-2.5(10) py-2(8) text-xs space-y-1.5(6)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kBlue50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBlue100),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // MapPin(10) grey-400 | "Kutoka: " grey-700 bold-grey-900
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 10, color: _kGrey400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Kutoka: ',
                          style: TextStyle(fontSize: 12, color: _kGrey700)),
                      TextSpan(
                          text: [
                            if (currReg.isNotEmpty) currReg,
                            if (currDist.isNotEmpty) currDist,
                          ].join(', '),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kGrey900)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              if (destText.isNotEmpty) ...[
                const SizedBox(height: 6), // space-y-1.5
                // ArrowLeftRight(10) blue | "Anataka Kuja: " bold-blue
                Row(children: [
                  const Icon(Icons.compare_arrows_rounded, size: 10, color: _kBlue),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(
                            text: 'Anataka Kuja: ',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kBlue)),
                        TextSpan(
                            text: destText,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kBlue)),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ]),
          ),

          // ── Miaka ya kazi ─────────────────────────────────────────
          // Web: text-[11px] text-grey-500 font-medium
          if (years != null) ...[
            const SizedBox(height: 12),
            Text(
              'Miaka ya kazi: ${years == 3 ? "3+ (miaka 3 au zaidi)" : "${years.toInt()} ${years == 1 ? 'mwaka' : 'miaka'}"}',
              style: const TextStyle(
                  fontSize: 11,
                  color: _kGrey500,
                  fontWeight: FontWeight.w500),
            ),
          ],

          // ── Masomo ───────────────────────────────────────────────
          // Web: flex flex-wrap gap-1.5 | badge: px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 text-[11px] font-semibold border-blue/10
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              ...subjects.take(5).map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kBlue50,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: _kBlue.withValues(alpha: 0.1)),
                ),
                child: Text(s,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kBlue700)),
              )),
              if (subjects.length > 5)
                Text('+${subjects.length - 5}',
                    style: const TextStyle(
                        fontSize: 12, color: _kGrey400)),
            ]),
          ],

          // ── Simu ─────────────────────────────────────────────────
          // Web: inline-flex gap-1.5 px-3 py-2 rounded-xl bg-white border-grey-200 text-xs font-semibold text-grey-900 w-full justify-center
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                try {
                  await launchUrl(Uri.parse('tel:$phone'),
                      mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _kGrey200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.phone_outlined, size: 12, color: _kGrey900),
                  const SizedBox(width: 6),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kGrey900)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
