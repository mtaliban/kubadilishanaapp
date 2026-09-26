// ============================================================================
// MATCH ZA KWELI — matches halisi kati ya watumiaji (score, masomo yanayofanana)
// Design (kama pages nyingine za admin):
//  - Header yenye icon badge + Live badge + hesabu ya matches
//  - Filter chips (Idara / Kada / Somo) → picker sheets zenye search
//  - Idara na Kada ni DYNAMIC kutoka DB (getDepartments/getCadres) — hakuna
//    hardcoded Elimu/Afya tu; idara mpya inaonekana yenyewe
//  - Kadi: score badge (SAHIHI/NZURI/POA), masomo yanayofanana, watumiaji
//    WAWILI (A ↓ B) na badge ya malipo, Kutoka/Anataka, masomo, simu (tel:)
//  - Pagination yenye dirisha la kurasa 5 + scroll-to-top
// Data halisi: GET /admin/real-matches
// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';

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
const _kGreen200= Color(0xFFBBF7D0);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kAmber   = Color(0xFFA16207);
const _kAmberBg = Color(0xFFFEF9C3);
const _kAmberBd = Color(0xFFFDE047);

const _kPs = 20; // matches kwa kurasa

String _titleCase(String s) => s
    .trim()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

// ── Score badge (kama web) ──────────────────────────────────────────────────
class _ScoreBadge {
  final String label;
  final Color fg, bg, border;
  const _ScoreBadge(this.label, this.fg, this.bg, this.border);
}

_ScoreBadge _scoreBadge(double score) {
  if (score >= 1.0) {
    return const _ScoreBadge('SAHIHI', _kGreen, _kGreenBg, Color(0xFF86EFAC));
  }
  if (score >= 0.85) {
    return const _ScoreBadge('NZURI', _kBlue700, _kBlue100, Color(0xFF93C5FD));
  }
  return const _ScoreBadge('POA', _kAmber, _kAmberBg, _kAmberBd);
}

// ───────────────────────── Page ─────────────────────────
class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});

  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  final _searchCtrl  = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  // Reference data (dynamic kutoka DB)
  List<dynamic> _departments = [];
  List<Map<String, dynamic>> _cadres = [];

  // Filters
  String _category = ''; // department code ('' = zote)
  String _cadreCode = ''; // cadre code ('' = zote)
  String _q = '';
  String _subjectQ = '';
  int _page = 1;

  // ── Lookups (dynamic kutoka DB) ────────────────────────────────────────────
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
    return code.isEmpty ? '—' : code;
  }

  List<Map<String, dynamic>> get _cadreOptions {
    if (_category.isEmpty) return _cadres;
    return _cadres.where((c) => '${c['category'] ?? ''}' == _category).toList();
  }

  bool get _hasFilter =>
      _category.isNotEmpty || _cadreCode.isNotEmpty || _q.isNotEmpty || _subjectQ.isNotEmpty;

  // ── Client-side filter (kama web) ──────────────────────────────────────────
  List<dynamic> get _filtered {
    final ql = _q.toLowerCase();
    return _items.where((item) {
      final m = asMap(item);
      final a = m['user_a'] as Map? ?? {};
      final b = m['user_b'] as Map? ?? {};
      if (ql.isNotEmpty) {
        final ok = ('${a['full_name'] ?? ''}').toLowerCase().contains(ql) ||
            ('${b['full_name'] ?? ''}').toLowerCase().contains(ql) ||
            ('${a['phone_primary'] ?? ''}').contains(_q) ||
            ('${b['phone_primary'] ?? ''}').contains(_q) ||
            _cadreLabel('${a['cadre_code'] ?? ''}').toLowerCase().contains(ql) ||
            ('${a['current_region'] ?? ''}').toLowerCase().contains(ql) ||
            ('${b['current_region'] ?? ''}').toLowerCase().contains(ql);
        if (!ok) return false;
      }
      if (_subjectQ.isNotEmpty) {
        final common = (m['common_subjects'] as List?)
                ?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final aSubs = (a['subjects'] as List?)
                ?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final bSubs = (b['subjects'] as List?)
                ?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        if (![...common, ...aSubs, ...bSubs].any((s) => s.contains(_subjectQ))) return false;
      }
      return true;
    }).toList();
  }

  int get _totalPages => _filtered.isEmpty ? 1 : (_filtered.length / _kPs).ceil();
  int get _safePage => _page.clamp(1, _totalPages);
  List<dynamic> get _pageItems {
    final f = _filtered;
    final p = _safePage;
    return f.skip((p - 1) * _kPs).take(_kPs).toList();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
    _searchCtrl.addListener(_onSearch);
    _subjectCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _subjectCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _q = _searchCtrl.text;
        _subjectQ = _subjectCtrl.text.toUpperCase();
        _page = 1;
      });
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminRealMatches(
        category:  _category.isEmpty ? null : _category,
        cadreCode: _cadreCode.isEmpty ? null : _cadreCode,
        limit: 500,
      );
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _items = data is List ? data : ((data['matches'] ?? data['results']) as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadRefs() async {
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

  void _resetFilters() {
    setState(() {
      _category = ''; _cadreCode = ''; _page = 1;
    });
    _searchCtrl.clear();
    _subjectCtrl.clear();
    _load();
  }

  void _goToPage(int p) {
    setState(() => _page = p.clamp(1, _totalPages));
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ── Picker sheet (search + blue highlight, kama reference) ─────────────────
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
    final pageItems = _pageItems;
    final totalPages = _totalPages;
    final safePage = _safePage;

    // Options za pickers
    final deptOpts = <(String, String)>[
      ('', 'Idara Zote'),
      for (final d in _departments) ('${d['code']}', '${d['display_name'] ?? d['name'] ?? d['code']}'),
    ];
    final cadreOpts = <(String, String)>[
      ('', 'Kada Zote'),
      for (final c in _cadreOptions) ('${c['code']}', '${c['display_name'] ?? c['name'] ?? c['code']}'),
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
                    color: _kGreenBg, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.swap_horiz_rounded, color: _kGreen),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Match za Kweli',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kInk)),
              ),
              const _StatusChip(),
            ]),
            const SizedBox(height: 8),
            Text(
              _loading
                  ? 'Inapakia...'
                  : '${filtered.length} ${filtered.length == 1 ? 'match' : 'matches'} zilizopatikana',
              style: const TextStyle(fontSize: 15, color: _kMuted, height: 1.4),
            ),
            const SizedBox(height: 16),

            // ── Filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip(
                    Icons.apartment_rounded,
                    _category.isEmpty ? 'Idara zote' : _deptLabel(_category),
                    _category.isNotEmpty, () {
                  if (_departments.isEmpty) return;
                  _openPicker('Chagua Idara', deptOpts, _category, (v) {
                    setState(() {
                      _category = v;
                      _cadreCode = '';
                      _page = 1;
                    });
                    _load();
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
                    _load();
                  });
                }),
                const SizedBox(width: 8),
                if (_hasFilter)
                  _filterChip(Icons.close_rounded, 'Futa vichujio', false, _resetFilters),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Search fields ──
            _SearchField(
              ctrl: _searchCtrl,
              hint: 'Tafuta kwa jina, namba, kada au mkoa...',
              onClear: _searchCtrl.text.isEmpty
                  ? null
                  : () { _searchCtrl.clear(); },
            ),
            const SizedBox(height: 10),
            _SearchField(
              ctrl: _subjectCtrl,
              hint: 'Somo (mfano MATH)',
              onClear: _subjectCtrl.text.isEmpty
                  ? null
                  : () { _subjectCtrl.clear(); },
            ),
            const SizedBox(height: 14),

            if (!_loading && _error == null)
              Text(
                'Inaonyesha ${pageItems.length} kati ya ${filtered.length}',
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
              _EmptyState(onClear: _resetFilters)
            else ...[
              for (final m in pageItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MatchCard(
                    match: asMap(m),
                    deptLabel: _deptLabel,
                    cadreLabel: _cadreLabel,
                  ),
                ),
              _Pager(page: safePage, total: totalPages, onPage: _goToPage),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────
class _StatusChip extends StatelessWidget {
  const _StatusChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.auto_awesome_rounded, size: 14, color: _kGreen),
        SizedBox(width: 6),
        Text('Live',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kGreen)),
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
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: _kSoft, borderRadius: BorderRadius.circular(28)),
          child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFCBD5E1), size: 24),
        ),
        const SizedBox(height: 12),
        const Text('Hakuna match iliyopatikana',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Watumiaji wataonekana wanapojiunga na kuchagua destinations',
            style: TextStyle(color: _kMuted, fontSize: 15),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),
        TextButton(onPressed: onClear, child: const Text('Futa vichujio')),
      ]),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final VoidCallback? onClear;
  const _SearchField({required this.ctrl, required this.hint, this.onClear});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, color: _kMuted),
      suffixIcon: onClear == null
          ? null
          : IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClear),
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
  );
}

// ═══ MatchCard ═════════════════════════════════════════════════════════════
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final String Function(String) deptLabel;
  final String Function(String) cadreLabel;
  const _MatchCard({
    required this.match,
    required this.deptLabel,
    required this.cadreLabel,
  });

  @override
  Widget build(BuildContext context) {
    final a = asMap(match['user_a']);
    final b = asMap(match['user_b']);
    final score = (match['score'] as num?)?.toDouble() ?? 0.0;
    final sb = _scoreBadge(score);
    final cat = match['category'] as String? ?? a['category'] as String? ?? '';
    final cadre = match['cadre_code'] as String? ?? a['cadre_code'] as String? ?? '';
    final commonSubs =
        (match['common_subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kLine),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: score badge + category/cadre ──
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: sb.bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: sb.border),
            ),
            child: Text('${sb.label} ${(score * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: sb.fg)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [if (cat.isNotEmpty) deptLabel(cat), if (cadre.isNotEmpty) cadreLabel(cadre)]
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(fontSize: 12, color: _kMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: 12),

        // ── Masomo yanayofanana ──
        if (commonSubs.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kGreen200),
            ),
            child: Wrap(
                spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Masomo Yanayofanana:',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: _kGreen)),
                  for (final s in commonSubs)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$s ✓',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── User A ──
        _UserHalf(user: a, cadreLabel: cadreLabel),
        // ── Separator: KUBADILISHANA ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Container(height: 1, color: _kGreen200)),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _kGreenBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Color(0xFF86EFAC)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz_rounded, size: 13, color: _kGreen),
                SizedBox(width: 6),
                Text('KUBADILISHANA',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _kGreen,
                        letterSpacing: 0.5)),
              ]),
            ),
            Expanded(child: Container(height: 1, color: _kGreen200)),
          ]),
        ),
        // ── User B ──
        _UserHalf(user: b, cadreLabel: cadreLabel),
      ]),
    );
  }
}

// ═══ UserHalf ══════════════════════════════════════════════════════════════
class _UserHalf extends StatelessWidget {
  final Map<String, dynamic> user;
  final String Function(String) cadreLabel;
  const _UserHalf({required this.user, required this.cadreLabel});

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final cadreCode = user['cadre_code'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ??
        user['cadre_name'] as String? ??
        (cadreCode.isEmpty ? '' : cadreLabel(cadreCode));
    final isPaid = (user['is_verified'] as bool?) ?? false;
    final station = user['current_station'] as Map? ?? {};
    final region = user['current_region'] as String? ??
        station['region_name'] as String? ?? '';
    final district = user['current_district'] as String? ??
        station['district_name'] as String? ?? '';
    final dests = ((user['desired_destinations'] ?? user['destinations']) as List?)
            ?.map((d) =>
                d is Map ? '${d['region_name'] ?? d['region'] ?? d}' : '$d')
            .toList() ?? [];
    final subjects =
        (user['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    final fromText = [region, district].where((s) => s.isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Avatar + jina + badge ya malipo ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _kBlueBg,
            child: Text(_initials(name),
                style: const TextStyle(
                    color: _kPrimary, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6, runSpacing: 4, children: [
                Text(name.isEmpty ? '(bila jina)' : _titleCase(name),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                        height: 1.25)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? _kGreenBg : _kRedBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(isPaid ? '✓ Amelipa' : '✗ Hajalipa',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? _kGreen : _kRed)),
                ),
              ]),
              if (cadre.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(cadre,
                    style: const TextStyle(fontSize: 12, color: _kMuted)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 10),

        // ── Kutoka / Anataka ──
        if (fromText.isNotEmpty || dests.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kLine),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (fromText.isNotEmpty)
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: _kMuted),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(
                            text: 'Kutoka: ',
                            style: TextStyle(fontSize: 12, color: _kMuted)),
                        TextSpan(
                            text: fromText,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kInk)),
                      ]),
                    ),
                  ),
                ]),
              if (dests.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.swap_horiz_rounded, size: 13, color: _kPrimary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(
                            text: 'Anataka: ',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kPrimary)),
                        TextSpan(
                            text: dests.join(', '),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kPrimary)),
                      ]),
                    ),
                  ),
                ]),
              ],
            ]),
          ),

        // ── Masomo ──
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 5, runSpacing: 5, children: [
            ...subjects.take(6).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBlueBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(s,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kBlue700)),
                )),
            if (subjects.length > 6)
              Text('+${subjects.length - 6}',
                  style: const TextStyle(fontSize: 11, color: _kMuted)),
          ]),
        ],

        // ── Simu ──
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              try {
                await launchUrl(Uri.parse('tel:$phone'),
                    mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _kSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone_rounded, size: 14, color: _kPrimary),
                const SizedBox(width: 7),
                Text(phone,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
