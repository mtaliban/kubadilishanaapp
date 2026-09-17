import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

// ── Color tokens (exact Tailwind hex) ─────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);  // brand-blue
const _kBlueBg  = Color(0xFFEFF6FF);  // blue-50
const _kBlue700 = Color(0xFF1D4ED8);  // blue-700
const _kGreen   = Color(0xFF16A34A);  // green-600
const _kGreenBg = Color(0xFFDCFCE7);  // green-50
const _kGreen200 = Color(0xFFBBF7D0); // green-200
const _kGreen300 = Color(0xFF86EFAC); // green-300
const _kGreen700 = Color(0xFF15803D); // green-700
const _kYellow  = Color(0xFFF59E0B);  // yellow-500
const _kEmerald = Color(0xFF10B981);  // emerald-500
const _kRed400  = Color(0xFFF87171);  // red-400
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey600 = Color(0xFF4B5563);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey50  = Color(0xFFF9FAFB);

// ── Cadre labels (kama web CADRE_LABELS) ──────────────────────────────────
const _kCadreLabels = <String, String>{
  'TEACHER_PRIMARY':   'Mwalimu wa Msingi',
  'TEACHER_SECONDARY': 'Mwalimu wa Sekondari',
  'TEACHER_SPECIAL':   'Mwalimu wa Pekee',
  'MD':        'Daktari (MD)',
  'CO':        'Afisa wa Afya (CO)',
  'ACO':       'Msaidizi wa Afisa wa Afya',
  'CA':        'Msaidizi wa Kliniki',
  'AMO':       'Msaidizi wa Daktari',
  'NO':        'Afisa wa Ugojaji (NO)',
  'RN':        'Muuguzi Aliyesajiliwa (RN)',
  'EN':        'Muuguzi Aliyeandikwa (EN)',
  'ANO':       'Msaidizi wa Ugojaji (ANO)',
  'HA':        'Msaidizi wa Afya (HA)',
  'MA':        'Msaidizi wa Matibabu (MA)',
  'LAB_TECH_1':  'Teknolojia ya Maabara I',
  'LAB_TECH_2':  'Teknolojia ya Maabara II',
  'LAB_SCI_2':   'Wanasayansi wa Maabara II',
  'LAB_ASST':    'Msaidizi wa Maabara',
  'SR_LAB_ASST': 'Msaidizi Mkuu wa Maabara',
  'MALT':     'Teknolojia ya Maabara ya Matibabu',
  'PHARM_2':  'Daktari wa Pharmacy II',
};

String _cadreLabel(String code) => _kCadreLabels[code] ?? (code.isEmpty ? '—' : code);

String _catLabel(String cat) {
  if (cat == 'education') return 'Elimu';
  if (cat == 'health') return 'Afya';
  return cat.isEmpty ? '—' : cat;
}

// ── Score badge (kama web scoreBadge) ─────────────────────────────────────
// SAHIHI=green-100/700/300, NZURI=blue-100/700/300, POA=yellow-100/700/300
class _ScoreBadge {
  final String label;
  final Color fg, bg, border;
  const _ScoreBadge(this.label, this.fg, this.bg, this.border);
}

_ScoreBadge _scoreBadge(double score) {
  if (score >= 1.0) {
    return const _ScoreBadge('SAHIHI', Color(0xFF15803D), Color(0xFFDCFCE7), Color(0xFF86EFAC));
  }
  if (score >= 0.85) {
    return const _ScoreBadge('NZURI', Color(0xFF1D4ED8), Color(0xFFDBEAFE), Color(0xFF93C5FD));
  }
  return const _ScoreBadge('POA', Color(0xFFA16207), Color(0xFFFEF9C3), Color(0xFFFDE047));
}

// ── Cadre options (kama web getCadreOptions) ───────────────────────────────
const _kEdCadres = [
  ('TEACHER_PRIMARY',   'Mwalimu wa Msingi'),
  ('TEACHER_SECONDARY', 'Mwalimu wa Sekondari'),
  ('TEACHER_SPECIAL',   'Mwalimu wa Pekee'),
];
const _kHealthCadres = [
  ('MD',  'Daktari (MD)'),
  ('CO',  'Afisa wa Afya (CO)'),
  ('ACO', 'Msaidizi wa Afisa wa Afya'),
  ('CA',  'Msaidizi wa Kliniki'),
  ('AMO', 'Msaidizi wa Daktari'),
  ('NO',  'Afisa wa Ugojaji (NO)'),
  ('RN',  'Muuguzi Aliyesajiliwa (RN)'),
  ('EN',  'Muuguzi Aliyeandikwa (EN)'),
  ('ANO', 'Msaidizi wa Ugojaji (ANO)'),
  ('HA',  'Msaidizi wa Afya (HA)'),
  ('MA',  'Msaidizi wa Matibabu (MA)'),
  ('LAB_TECH_1',  'Teknolojia ya Maabara I'),
  ('LAB_TECH_2',  'Teknolojia ya Maabara II'),
  ('LAB_SCI_2',   'Wanasayansi wa Maabara II'),
  ('LAB_ASST',    'Msaidizi wa Maabara'),
  ('SR_LAB_ASST', 'Msaidizi Mkuu wa Maabara'),
  ('MALT',    'Teknolojia ya Maabara ya Matibabu'),
  ('PHARM_2', 'Daktari wa Pharmacy II'),
];

List<(String, String)> _cadreOptions(String cat) {
  if (cat == 'education') return _kEdCadres;
  if (cat == 'health') return _kHealthCadres;
  return [..._kEdCadres, ..._kHealthCadres];
}

// ── Page ───────────────────────────────────────────────────────────────────
class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});
  @override
  State<AdminRealMatchesPage> createState() => _State();
}

class _State extends State<AdminRealMatchesPage> {
  static const _ps = 20; // PAGE_SIZE = 20 (kama web)

  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  String _category = '';
  String _cadreCode = '';
  String _q = '';
  String _subjectQ = '';
  int _page = 1;
  Timer? _debounce;

  final _searchCtrl  = TextEditingController();
  final _subjectCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
    _subjectCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _subjectCtrl.dispose();
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

  // Client-side filter (kama web)
  List<dynamic> get _filtered {
    final ql = _q.toLowerCase();
    return _items.where((item) {
      final m = item as Map<String, dynamic>;
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
        final common = (m['common_subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final aSubs  = (a['subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final bSubs  = (b['subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        if (![...common, ...aSubs, ...bSubs].any((s) => s.contains(_subjectQ))) return false;
      }
      return true;
    }).toList();
  }

  int get _totalPages {
    final f = _filtered;
    return f.isEmpty ? 1 : (f.length / _ps).ceil();
  }

  int get _safePage => _page.clamp(1, _totalPages);

  List<dynamic> get _pageItems {
    final f = _filtered;
    final p = _safePage;
    return f.skip((p - 1) * _ps).take(_ps).toList();
  }

  bool get _hasFilter =>
      _category.isNotEmpty || _cadreCode.isNotEmpty || _q.isNotEmpty || _subjectQ.isNotEmpty;

  void _resetFilters() {
    setState(() { _category = ''; _cadreCode = ''; _q = ''; _subjectQ = ''; _page = 1; });
    _searchCtrl.clear();
    _subjectCtrl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageItems = _pageItems;
    final totalPages = _totalPages;
    final safePage = _safePage;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header (kama web: flex items-center gap-2 + subtitle p) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // h1: ArrowLeftRight icon inline + "Match za Kweli"
                Row(children: [
                  const Icon(Icons.swap_horiz_rounded, size: 22, color: _kGreen),
                  const SizedBox(width: 8),   // gap-2
                  const Text('Match za Kweli',
                      style: TextStyle(
                        fontSize: 20,           // text-xl
                        fontWeight: FontWeight.w700,  // font-bold
                        height: 10 / 7,         // line-height: 20/20 → Tailwind default
                        color: _kGrey900,
                      )),
                ]),
                const SizedBox(height: 2),    // mt-0.5
                // Subtitle p text-sm text-brand-grey-500
                Text(
                  _loading
                      ? 'Inapakia...'
                      : '${filtered.length} ${filtered.length == 1 ? 'match' : 'matches'} zilizopatikana',
                  style: const TextStyle(
                    fontSize: 14,              // text-sm
                    height: 10 / 7,
                    color: _kGrey500,
                  ),
                ),
              ]),
            ),

            // ── Filters (flex-col kama web mobile) ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(children: [
                // 1. Idara select (full width)
                _FilterDrop(
                  hint: 'Idara Zote',
                  value: _category.isEmpty ? null : _catLabel(_category),
                  active: _category.isNotEmpty,
                  onTap: () => _showPicker(
                    title: 'Chagua Idara',
                    items: [('', 'Idara Zote'), ('education', 'Elimu'), ('health', 'Afya')],
                    current: _category,
                    onPick: (v) {
                      setState(() { _category = v; _cadreCode = ''; _page = 1; });
                      _load();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 2. Kada select (full width)
                _FilterDrop(
                  hint: 'Kada Zote',
                  value: _cadreCode.isEmpty ? null : _cadreLabel(_cadreCode),
                  active: _cadreCode.isNotEmpty,
                  onTap: () => _showPicker(
                    title: 'Chagua Kada',
                    items: [('', 'Kada Zote'), ..._cadreOptions(_category)],
                    current: _cadreCode,
                    onPick: (v) { setState(() { _cadreCode = v; _page = 1; }); _load(); },
                  ),
                ),
                const SizedBox(height: 8),
                // 3. Search input (full width, flex-1)
                _SearchField(
                  ctrl: _searchCtrl,
                  hint: 'Tafuta kwa jina, namba, kada au mkoa...',
                ),
                const SizedBox(height: 8),
                // 4. Subject input (full width)
                _SearchField(
                  ctrl: _subjectCtrl,
                  hint: 'Somo (mfano MATH)',
                ),
                // 5. Futa (full width, kama web — inaonekana mwisho wa filters)
                if (_hasFilter) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _resetFilters,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: _kGrey200),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded, size: 14, color: _kGrey700),
                          SizedBox(width: 4),
                          Text('Futa', style: TextStyle(
                            fontSize: 12,
                            height: 4 / 3,
                            color: _kGrey700,
                            fontWeight: FontWeight.w600,
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ]),
            ),

            const Divider(height: 1, color: _kGrey200),

            // ── Content ──────────────────────────────────────────────────
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: _kGreen)))
            else if (_error != null)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, color: _kGrey400, size: 48),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Jaribu tena'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue, foregroundColor: Colors.white),
                ),
              ])))
            else if (filtered.isEmpty)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(28)),
                  child: const Icon(Icons.swap_horiz_rounded, color: _kGrey400, size: 24),
                ),
                const SizedBox(height: 12),
                const Text('Hakuna match iliyopatikana',
                    style: TextStyle(fontSize: 14, height: 10 / 7, fontWeight: FontWeight.w600, color: _kGrey700)),
                const SizedBox(height: 4),
                const Text('Watumiaji wataonekana wanapojiunga na kuchagua destinations',
                    style: TextStyle(fontSize: 12, height: 4 / 3, color: _kGrey400),
                    textAlign: TextAlign.center),
              ])))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: _kGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),      // p-4 (kama web)
                    itemCount: pageItems.length + (totalPages > 1 ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12), // space-y-3
                    itemBuilder: (ctx, i) {
                      if (i < pageItems.length) {
                        return _MatchCard(match: pageItems[i] as Map<String, dynamic>);
                      }
                      // Pagination row — kama web (← Rudi | safePage/totalPages | Endelea →)
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _pageBtn('← Rudi', safePage <= 1 ? null : () => setState(() => _page = safePage - 1)),
                          const SizedBox(width: 12),
                          Text('$safePage / $totalPages',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 10 / 7,
                                fontWeight: FontWeight.w700,
                                color: _kGrey500,
                              )),
                          const SizedBox(width: 12),
                          _pageBtn('Endelea →', safePage >= totalPages ? null : () => setState(() => _page = safePage + 1)),
                        ]),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Pagination button — kama web: min-w-[44] min-h-[44] px-3 rounded-xl border text-sm font-semibold
  Widget _pageBtn(String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: onTap != null ? _kGrey200 : _kGrey100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 14,
            height: 10 / 7,
            fontWeight: FontWeight.w600,
            color: onTap != null ? _kGrey700 : _kGrey400,
          )),
    ),
  );

  // ── Picker bottom sheet ────────────────────────────────────────────────
  void _showPicker({
    required String title,
    required List<(String, String)> items,
    required String current,
    required void Function(String) onPick,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          const SizedBox(height: 8),
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _kGrey900)),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _kGrey200),
          Expanded(
            child: ListView(children: [
              for (final (code, label) in items)
                InkWell(
                  onTap: () { Navigator.pop(context); onPick(code); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: current == code ? _kBlueBg : Colors.transparent,
                      border: const Border(bottom: BorderSide(color: _kGrey200)),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(label, style: TextStyle(
                        fontSize: 14,
                        height: 10 / 7,
                        fontWeight: current == code ? FontWeight.w600 : FontWeight.w400,
                        color: current == code ? _kBlue : _kGrey900,
                      ))),
                      if (current == code)
                        const Icon(Icons.check_rounded, color: _kBlue, size: 16),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══ MatchCard ═════════════════════════════════════════════════════════════
// Web: rounded-xl(12) bg-white border-grey-200 p-4(16) shadow-sm
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final a = match['user_a'] as Map<String, dynamic>? ?? {};
    final b = match['user_b'] as Map<String, dynamic>? ?? {};
    final score = (match['score'] as num?)?.toDouble() ?? 0.0;
    final sb  = _scoreBadge(score);
    final cat   = match['category'] as String? ?? a['category'] as String? ?? '';
    final cadre = match['cadre_code'] as String? ?? a['cadre_code'] as String? ?? '';
    final commonSubs = (match['common_subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12), // rounded-xl
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16), // p-4
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: score badge + category/cadre + star ───────────────
        // Web: flex items-center justify-between mb-3
        Row(children: [
          // Score badge: px-2 py-0.5 rounded-full text-[10px] font-bold border
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // px-2 py-0.5
            decoration: BoxDecoration(
              color: sb.bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: sb.border),
            ),
            child: Text(
              '${sb.label} (${(score * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                fontWeight: FontWeight.w700, // font-bold
                color: sb.fg,
              ),
            ),
          ),
          const SizedBox(width: 8), // gap-2
          // Category/cadre: text-xs text-brand-grey-500
          Expanded(child: Text(
            [if (cat.isNotEmpty) _catLabel(cat), if (cadre.isNotEmpty) _cadreLabel(cadre)]
                .where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(
              fontSize: 12, // text-xs
              height: 4 / 3,
              color: _kGrey500,
            ),
            overflow: TextOverflow.ellipsis,
          )),
          const Icon(Icons.star_rounded, size: 14, color: _kYellow), // Star yellow-500
        ]),
        const SizedBox(height: 12), // mb-3

        // ── Common subjects (mb-3 p-2 rounded-lg bg-green-50 border-green-200) ──
        if (commonSubs.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(8), // p-2
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.circular(8), // rounded-lg
              border: Border.all(color: _kGreen200),
            ),
            child: Wrap(spacing: 4, runSpacing: 4, children: [ // gap-1
              const Text('Masomo Yanayofanana:',
                  style: TextStyle(
                    fontSize: 10, // text-[10px]
                    height: 1.5,
                    fontWeight: FontWeight.w700, // font-bold
                    color: _kGreen700,
                  )),
              for (final s in commonSubs)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // px-1.5 py-0.5
                  decoration: BoxDecoration(
                    color: _kGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$s ✓', style: const TextStyle(
                    fontSize: 9, // text-[9px]
                    height: 1.5,
                    fontWeight: FontWeight.w700, // font-bold
                    color: Colors.white,
                  )),
                ),
            ]),
          ),
          const SizedBox(height: 12), // mb-3
        ],

        // ── User A ────────────────────────────────────────────────────
        _UserHalf(user: a),
        const SizedBox(height: 12), // gap-3

        // ── Mobile separator (flex sm:hidden) ─────────────────────────
        Row(children: [
          Expanded(child: Container(height: 1, color: _kGreen200)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kGreen300),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_horiz_rounded, size: 13, color: _kGreen),
              SizedBox(width: 6),
              Text('KUBADILISHANA',
                  style: TextStyle(
                    fontSize: 10, // text-[10px]
                    height: 1.5,
                    fontWeight: FontWeight.w700, // font-bold
                    color: _kGreen700,
                    letterSpacing: 0.5,
                  )),
            ]),
          ),
          Expanded(child: Container(height: 1, color: _kGreen200)),
        ]),
        const SizedBox(height: 12), // gap-3

        // ── User B ────────────────────────────────────────────────────
        _UserHalf(user: b),
      ]),
    );
  }
}

// ═══ UserHalf ══════════════════════════════════════════════════════════════
// Web: rounded-lg(8) bg-brand-grey-50 border-grey-200 p-3(12) space-y-2(8)
class _UserHalf extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserHalf({required this.user});

  @override
  Widget build(BuildContext context) {
    final name    = user['full_name'] as String? ?? '';
    final phone   = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final cadre   = user['cadre_display'] as String? ?? user['cadre_name'] as String? ?? user['cadre_code'] as String? ?? '';
    final isPaid  = (user['is_verified'] as bool?) ?? false;
    final station = user['current_station'] as Map? ?? {};
    final region  = user['current_region'] as String? ?? station['region_name'] as String? ?? '';
    final district = user['current_district'] as String? ?? station['district_name'] as String? ?? '';
    final dests   = ((user['desired_destinations'] ?? user['destinations']) as List?)
            ?.map((d) => d is Map ? (d['region_name'] ?? d['region'] ?? d.toString()) : d.toString())
            .toList() ?? [];
    final subjects = (user['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    final fromText = [region, district].where((s) => s.isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(12), // p-3
      decoration: BoxDecoration(
        color: _kGrey50,                 // bg-brand-grey-50
        borderRadius: BorderRadius.circular(8), // rounded-lg
        border: Border.all(color: _kGrey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Name + Avatar (flex items-center gap-2) ──────────────────
        Row(children: [
          // w-9 h-9 rounded-full bg-brand-blue
          CircleAvatar(
            radius: 18, // w-9 h-9 = 36px
            backgroundColor: _kBlue,
            child: Text(initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,  // font-bold
                  fontSize: 12,                 // text-xs
                  height: 4 / 3,
                )),
          ),
          const SizedBox(width: 8), // gap-2
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Name row: flex items-center gap-1 flex-wrap
              Row(children: [
                Expanded(child: Text(name,
                    style: const TextStyle(
                      fontSize: 14,           // text-sm
                      height: 10 / 7,
                      fontWeight: FontWeight.w700, // font-bold
                      color: _kGrey900,
                    ),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4), // gap-1
                // Paid badge: text-[9px] font-bold text-white px-1.5 py-0.5 rounded-full
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // px-1.5 py-0.5
                  decoration: BoxDecoration(
                    color: isPaid ? _kEmerald : _kRed400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(isPaid ? '✓ PAID' : '✗',
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1.5,
                        fontWeight: FontWeight.w700, // font-bold
                        color: Colors.white,
                      )),
                ),
              ]),
              // Cadre: text-[11px] text-brand-grey-500
              if (cadre.isNotEmpty)
                Text(cadre,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: _kGrey500,
                    ),
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: 8), // space-y-2

        // ── Location box (text-xs bg-white rounded-md px-2.5 py-2 border-grey-100) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // px-2.5 py-2
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6), // rounded-md
            border: Border.all(color: _kGrey100),   // border-brand-grey-100
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Kutoka row: MapPin(10) + text
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 10, color: _kGrey400), // MapPin size=10
              const SizedBox(width: 4),
              Expanded(child: RichText(text: TextSpan(
                style: const TextStyle(fontSize: 12, height: 4 / 3, color: _kGrey600), // text-xs
                children: [
                  const TextSpan(text: 'Kutoka: '),
                  TextSpan(
                    text: fromText.isEmpty ? '—' : fromText,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _kGrey900),
                  ),
                ],
              ))),
            ]),
            if (dests.isNotEmpty) ...[
              const SizedBox(height: 4), // space-y-1
              // Anataka row: ArrowLeftRight(10) + text-brand-blue font-semibold
              Row(children: [
                const Icon(Icons.swap_horiz_rounded, size: 10, color: _kBlue),
                const SizedBox(width: 4),
                Expanded(child: RichText(text: TextSpan(
                  style: const TextStyle(
                    fontSize: 12, height: 4 / 3, color: _kBlue, fontWeight: FontWeight.w600),
                  children: [
                    const TextSpan(text: 'Anataka: '),
                    TextSpan(
                      text: dests.join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ))),
              ]),
            ],
          ]),
        ),

        // ── Subjects (flex flex-wrap gap-1) ─────────────────────────
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 8), // space-y-2
          Wrap(spacing: 4, runSpacing: 4, children: [ // gap-1
            for (final s in subjects)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // px-1.5 py-0.5
                decoration: BoxDecoration(
                  color: _kBlueBg,                               // bg-brand-blue-50
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kBlue.withValues(alpha: 0.1)), // border-brand-blue/10
                ),
                child: Text(s, style: const TextStyle(
                  fontSize: 9,                                   // text-[9px]
                  height: 1.5,
                  fontWeight: FontWeight.w700,                   // font-bold
                  color: _kBlue700,                              // text-brand-blue-700
                )),
              ),
          ]),
        ],

        // ── Phone button (w-full inline-flex justify-center px-2 py-1.5 rounded-lg border) ──
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 8), // space-y-2
          GestureDetector(
            onTap: () async {
              try {
                await launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // px-2 py-1.5
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8), // rounded-lg
                border: Border.all(color: _kGrey200),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone_outlined, size: 10, color: _kGrey900), // Phone size=10
                const SizedBox(width: 6), // gap-1.5
                Text(phone, style: const TextStyle(
                  fontSize: 11,                // text-[11px]
                  height: 1.5,
                  fontWeight: FontWeight.w600, // font-semibold
                  color: _kGrey900,
                )),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ═══ Filter dropdown button ════════════════════════════════════════════════
// Web: <select className="input ..."> — full width on mobile
class _FilterDrop extends StatelessWidget {
  final String hint;
  final String? value;
  final bool active;
  final VoidCallback onTap;
  const _FilterDrop({required this.hint, this.value, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // input class: py-1.5 px-2.5
      decoration: BoxDecoration(
        color: active ? _kBlueBg : Colors.white,
        border: Border.all(color: active ? _kBlue : _kGrey200, width: active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(6), // rounded-md (input class)
      ),
      child: Row(children: [
        Expanded(child: Text(value ?? hint,
            style: TextStyle(
              fontSize: 12,
              height: 4 / 3,
              color: active ? _kBlue : _kGrey700,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis)),
        Icon(Icons.keyboard_arrow_down_rounded, size: 16,
            color: active ? _kBlue : _kGrey500),
      ]),
    ),
  );
}

// ═══ Search input field ════════════════════════════════════════════════════
// Web: <input className="input pl-9 w-full"> with Search icon absolute
class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _SearchField({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(fontSize: 12, height: 4 / 3),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kGrey400, fontSize: 12, height: 4 / 3),
      prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 14), // Search size=14
      fillColor: Colors.white, filled: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6), // py-1.5
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), // rounded-md
          borderSide: const BorderSide(color: _kGrey200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kGrey200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _kBlue, width: 1.5)),
    ),
  );
}
