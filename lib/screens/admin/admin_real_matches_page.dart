import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey600 = Color(0xFF4B5563);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

// ── Cadre labels (kama web) ────────────────────────────────────────────────
const _kCadreLabels = <String, String>{
  'TEACHER_PRIMARY': 'Mwalimu wa Msingi',
  'TEACHER_SECONDARY': 'Mwalimu wa Sekondari',
  'TEACHER_SPECIAL': 'Mwalimu wa Pekee',
  'MD': 'Daktari (MD)',
  'CO': 'Afisa wa Afya (CO)',
  'ACO': 'Msaidizi wa Afisa wa Afya',
  'CA': 'Msaidizi wa Kliniki',
  'AMO': 'Msaidizi wa Daktari',
  'NO': 'Afisa wa Ugojaji (NO)',
  'RN': 'Muuguzi Aliyesajiliwa (RN)',
  'EN': 'Muuguzi Aliyeandikwa (EN)',
  'ANO': 'Msaidizi wa Ugojaji (ANO)',
  'HA': 'Msaidizi wa Afya (HA)',
  'MA': 'Msaidizi wa Matibabu (MA)',
  'LAB_TECH_1': 'Teknolojia ya Maabara I',
  'LAB_TECH_2': 'Teknolojia ya Maabara II',
  'LAB_SCI_2': 'Wanasayansi wa Maabara II',
  'LAB_ASST': 'Msaidizi wa Maabara',
  'SR_LAB_ASST': 'Msaidizi Mkuu wa Maabara',
  'MALT': 'Teknolojia ya Maabara ya Matibabu',
  'PHARM_2': 'Daktari wa Pharmacy II',
};

String _cadreLabel(String code) => _kCadreLabels[code] ?? code;

String _catLabel(String cat) {
  if (cat == 'education') return 'Elimu';
  if (cat == 'health') return 'Afya';
  return cat;
}

// ── Score badge ────────────────────────────────────────────────────────────
_ScoreBadgeData _scoreBadge(double score) {
  if (score >= 1.0) return _ScoreBadgeData('SAHIHI', _kGreen, _kGreenBg);
  if (score >= 0.85) return _ScoreBadgeData('NZURI', _kBlue, _kBlueBg);
  return _ScoreBadgeData('POA', _kAmber, _kAmberBg);
}

class _ScoreBadgeData {
  final String label;
  final Color fg, bg;
  const _ScoreBadgeData(this.label, this.fg, this.bg);
}

// ── Cadre lists for filter ─────────────────────────────────────────────────
const _kEducationCadres = [
  ('TEACHER_PRIMARY', 'Mwalimu wa Msingi'),
  ('TEACHER_SECONDARY', 'Mwalimu wa Sekondari'),
  ('TEACHER_SPECIAL', 'Mwalimu wa Pekee'),
];
const _kHealthCadres = [
  ('MD', 'Daktari (MD)'),
  ('CO', 'Afisa wa Afya (CO)'),
  ('ACO', 'Msaidizi wa Afisa wa Afya'),
  ('CA', 'Msaidizi wa Kliniki'),
  ('AMO', 'Msaidizi wa Daktari'),
  ('NO', 'Afisa wa Ugojaji (NO)'),
  ('RN', 'Muuguzi Aliyesajiliwa (RN)'),
  ('EN', 'Muuguzi Aliyeandikwa (EN)'),
  ('ANO', 'Msaidizi wa Ugojaji (ANO)'),
  ('HA', 'Msaidizi wa Afya (HA)'),
  ('MA', 'Msaidizi wa Matibabu (MA)'),
  ('LAB_TECH_1', 'Teknolojia ya Maabara I'),
  ('LAB_TECH_2', 'Teknolojia ya Maabara II'),
  ('LAB_ASST', 'Msaidizi wa Maabara'),
  ('PHARM_2', 'Daktari wa Pharmacy II'),
];

List<(String, String)> _cadreOptions(String cat) {
  if (cat == 'education') return _kEducationCadres;
  if (cat == 'health') return _kHealthCadres;
  return [..._kEducationCadres, ..._kHealthCadres];
}

// ── Page ───────────────────────────────────────────────────────────────────
class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});
  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  String _category = '';
  String _cadreCode = '';
  String _q = '';
  String _subjectQ = '';
  Timer? _debounce;

  final _searchCtrl = TextEditingController();
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
      });
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminRealMatches(
        category: _category.isEmpty ? null : _category,
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

  List<dynamic> get _filtered {
    final ql = _q.toLowerCase();
    return _items.where((item) {
      final m = item as Map<String, dynamic>;
      final a = m['user_a'] as Map? ?? {};
      final b = m['user_b'] as Map? ?? {};
      if (ql.isNotEmpty) {
        final match = ('${a['full_name'] ?? ''}').toLowerCase().contains(ql) ||
            ('${b['full_name'] ?? ''}').toLowerCase().contains(ql) ||
            ('${a['phone_primary'] ?? ''}').contains(_q) ||
            ('${b['phone_primary'] ?? ''}').contains(_q) ||
            _cadreLabel('${a['cadre_code'] ?? ''}').toLowerCase().contains(ql) ||
            ('${a['current_region'] ?? ''}').toLowerCase().contains(ql) ||
            ('${b['current_region'] ?? ''}').toLowerCase().contains(ql);
        if (!match) return false;
      }
      if (_subjectQ.isNotEmpty) {
        final common = (m['common_subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final aSubs = (a['subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final bSubs = (b['subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final all = [...common, ...aSubs, ...bSubs];
        if (!all.any((s) => s.contains(_subjectQ))) return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() { _category = ''; _cadreCode = ''; _q = ''; _subjectQ = ''; });
    _searchCtrl.clear();
    _subjectCtrl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final hasFilter = _category.isNotEmpty || _cadreCode.isNotEmpty || _q.isNotEmpty || _subjectQ.isNotEmpty;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _kGreenBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.swap_horiz_rounded, color: _kGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Match za Kweli',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                  Text(
                    _loading ? 'Inapakia...' : '${filtered.length} ${filtered.length == 1 ? 'match' : 'matches'} zilizopatikana',
                    style: const TextStyle(fontSize: 12, color: _kGrey500),
                  ),
                ])),
                if (hasFilter)
                  GestureDetector(
                    onTap: _resetFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kRedBg, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close_rounded, size: 12, color: _kRed),
                        SizedBox(width: 4),
                        Text('Futa', style: TextStyle(fontSize: 11, color: _kRed, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
            ),

            // ── Filters ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(children: [
                // Row 1: Idara + Kada
                Row(children: [
                  Expanded(child: _FilterDrop(
                    hint: 'Idara Zote',
                    value: _category.isEmpty ? null : _catLabel(_category),
                    onTap: () => _showPicker(
                      title: 'Chagua Idara',
                      items: [('', 'Idara Zote'), ('education', 'Elimu'), ('health', 'Afya')],
                      current: _category,
                      onPick: (v) {
                        setState(() { _category = v; _cadreCode = ''; });
                        _load();
                      },
                    ),
                    active: _category.isNotEmpty,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _FilterDrop(
                    hint: 'Kada Zote',
                    value: _cadreCode.isEmpty ? null : _cadreLabel(_cadreCode),
                    onTap: () => _showPicker(
                      title: 'Chagua Kada',
                      items: [('', 'Kada Zote'), ..._cadreOptions(_category)],
                      current: _cadreCode,
                      onPick: (v) { setState(() => _cadreCode = v); _load(); },
                    ),
                    active: _cadreCode.isNotEmpty,
                  )),
                ]),
                const SizedBox(height: 8),
                // Row 2: Search + Subject
                Row(children: [
                  Expanded(child: _SearchField(ctrl: _searchCtrl, hint: 'Tafuta jina, namba, mkoa...')),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: _SearchField(ctrl: _subjectCtrl, hint: 'Somo (MATH)'),
                  ),
                ]),
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
                  style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
                ),
              ])))
            else if (filtered.isEmpty)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(28)),
                  child: const Icon(Icons.swap_horiz_rounded, color: _kGrey400, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('Hakuna match iliyopatikana',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
                const SizedBox(height: 4),
                const Text('Watumiaji wataonekana wanapochagua destinations',
                    style: TextStyle(fontSize: 12, color: _kGrey500), textAlign: TextAlign.center),
              ])))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: _kGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final m = filtered[i] as Map<String, dynamic>;
                      return _MatchCard(match: m);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPicker({
    required String title,
    required List<(String, String)> items,
    required String current,
    required void Function(String) onPick,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _kGrey200, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kGrey900)),
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
                        fontWeight: current == code ? FontWeight.w600 : FontWeight.w400,
                        color: current == code ? _kBlue : _kGrey900,
                      ))),
                      if (current == code) const Icon(Icons.check_rounded, color: _kBlue, size: 16),
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

// ── Match card ─────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final a = match['user_a'] as Map<String, dynamic>? ?? {};
    final b = match['user_b'] as Map<String, dynamic>? ?? {};
    final score = (match['score'] as num?)?.toDouble() ?? 0.0;
    final sb = _scoreBadge(score);
    final cat = match['category'] as String? ?? a['category'] as String? ?? '';
    final cadre = match['cadre_code'] as String? ?? a['cadre_code'] as String? ?? '';
    final commonSubs = (match['common_subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: score badge + category/cadre + star ──────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sb.bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sb.fg.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${sb.label} (${(score * 100).toStringAsFixed(0)}%)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sb.fg),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              [if (cat.isNotEmpty) _catLabel(cat), if (cadre.isNotEmpty) _cadreLabel(cadre)]
                  .where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 11, color: _kGrey500),
              overflow: TextOverflow.ellipsis,
            )),
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
          ]),
        ),

        // ── Common subjects ──────────────────────────────────────────
        if (commonSubs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _kGreenBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
              ),
              child: Wrap(spacing: 5, runSpacing: 4, children: [
                const Text('Masomo Yanayofanana:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kGreen)),
                for (final s in commonSubs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(20)),
                    child: Text('$s ✓', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
              ]),
            ),
          ),
        ],

        // ── User A ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: _UserHalf(user: a),
        ),

        // ── Separator: Kubadilishana ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(child: Container(height: 1, color: const Color(0xFFBBF7D0))),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _kGreenBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz_rounded, size: 13, color: _kGreen),
                SizedBox(width: 4),
                Text('KUBADILISHANA',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kGreen, letterSpacing: 0.5)),
              ]),
            ),
            Expanded(child: Container(height: 1, color: const Color(0xFFBBF7D0))),
          ]),
        ),

        // ── User B ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _UserHalf(user: b),
        ),
      ]),
    );
  }
}

// ── User half (stacked — kama web mobile) ─────────────────────────────────
class _UserHalf extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserHalf({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ?? user['cadre_name'] as String? ?? user['cadre_code'] as String? ?? '';
    final isPaid = (user['is_verified'] as bool?) ?? false;
    final station = user['current_station'] as Map? ?? {};
    final region = user['current_region'] as String? ?? station['region_name'] as String? ?? '';
    final district = user['current_district'] as String? ?? station['district_name'] as String? ?? '';
    final dests = ((user['desired_destinations'] ?? user['destinations']) as List?)
            ?.map((d) => d is Map ? (d['region_name'] ?? d['region'] ?? d.toString()) : d.toString())
            .toList() ??
        [];
    final subjects = (user['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];

    final initials = name.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: _kGrey100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGrey200),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar + Name + paid badge
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _kBlue,
            child: Text(initials.isEmpty ? '?' : initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFF10B981) : _kRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(isPaid ? '✓ PAID' : '✗',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
            if (cadre.isNotEmpty)
              Text(cadre, style: const TextStyle(fontSize: 11, color: _kGrey500), overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 8),

        // Location box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kGrey200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 11, color: _kGrey400),
              const SizedBox(width: 4),
              Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontSize: 11, color: _kGrey600), children: [
                const TextSpan(text: 'Kutoka: '),
                TextSpan(text: [region, district].where((s) => s.isNotEmpty).join(', ').isNotEmpty
                    ? [region, district].where((s) => s.isNotEmpty).join(', ')
                    : '—',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _kGrey900)),
              ]))),
            ]),
            if (dests.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.swap_horiz_rounded, size: 11, color: _kBlue),
                const SizedBox(width: 4),
                Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontSize: 11, color: _kGrey600), children: [
                  const TextSpan(text: 'Anataka: '),
                  TextSpan(text: dests.join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: _kBlue)),
                ]))),
              ]),
            ],
          ]),
        ),

        // Subjects
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final s in subjects)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _kBlue.withValues(alpha: 0.2))),
                child: Text(s, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kBlue)),
              ),
          ]),
        ],

        // Phone button
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              try { await launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication); } catch (_) {}
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kGrey200),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone_outlined, size: 12, color: _kGrey700),
                const SizedBox(width: 6),
                Text(phone, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey900)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Filter dropdown button ─────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: active ? _kBlueBg : Colors.white,
        border: Border.all(color: active ? _kBlue : _kGrey200, width: active ? 1.5 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(child: Text(value ?? hint,
            style: TextStyle(fontSize: 12, color: active ? _kBlue : _kGrey700,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400),
            overflow: TextOverflow.ellipsis)),
        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: active ? _kBlue : _kGrey500),
      ]),
    ),
  );
}

// ── Search field ───────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  const _SearchField({required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kGrey400, fontSize: 12),
      prefixIcon: const Icon(Icons.search_rounded, color: _kGrey400, size: 17),
      fillColor: Colors.white, filled: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
    ),
  );
}
