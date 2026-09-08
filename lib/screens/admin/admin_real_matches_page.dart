import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ──────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E40AF);
const _kBlue50   = Color(0xFFEFF6FF);
const _kBlueLt   = Color(0xFFDBEAFE);
const _kGrey50   = Color(0xFFF9FAFB);
const _kGrey100  = Color(0xFFF3F4F6);
const _kGrey200  = Color(0xFFE5E7EB);
const _kGrey400  = Color(0xFF9CA3AF);
const _kGrey500  = Color(0xFF6B7280);
const _kGrey700  = Color(0xFF374151);
const _kGrey900  = Color(0xFF111827);
const _kGreen    = Color(0xFF22C55E);
const _kGreen50  = Color(0xFFF0FDF4);
const _kGreen100 = Color(0xFFDCFCE7);
const _kGreen200 = Color(0xFFBBF7D0);
const _kGreen600 = Color(0xFF16A34A);
const _kGreen700 = Color(0xFF15803D);
const _kYellow50 = Color(0xFFFEF9C3);
const _kYellow300 = Color(0xFFFDE047);
const _kYellow600 = Color(0xFFCA8A04);

// ── Cadre options ──────────────────────────────────────────────────
const _kEducationCadres = [
  {'code': 'TEACHER_PRIMARY',   'label': 'Mwalimu wa Msingi'},
  {'code': 'TEACHER_SECONDARY', 'label': 'Mwalimu wa Sekondari'},
  {'code': 'TEACHER_SPECIAL',   'label': 'Mwalimu wa Elimu ya Pekee'},
];

const _kHealthCadres = [
  {'code': 'MD',          'label': 'Daktari (MD)'},
  {'code': 'CO',          'label': 'Afisa wa Afya (CO)'},
  {'code': 'ACO',         'label': 'Msaidizi wa Afisa wa Afya'},
  {'code': 'CA',          'label': 'Msaidizi wa Kliniki'},
  {'code': 'AMO',         'label': 'Msaidizi wa Daktari'},
  {'code': 'NO',          'label': 'Afisa wa Ugojaji (NO)'},
  {'code': 'RN',          'label': 'Muuguzi Aliyesajiliwa (RN)'},
  {'code': 'EN',          'label': 'Muuguzi Aliyeandikwa (EN)'},
  {'code': 'ANO',         'label': 'Msaidizi wa Ugojaji (ANO)'},
  {'code': 'HA',          'label': 'Msaidizi wa Afya (HA)'},
  {'code': 'MA',          'label': 'Msaidizi wa Matibabu (MA)'},
  {'code': 'LAB_TECH_1',  'label': 'Teknolojia ya Maabara I'},
  {'code': 'LAB_TECH_2',  'label': 'Teknolojia ya Maabara II'},
  {'code': 'LAB_SCI_2',   'label': 'Wanasayansi wa Maabara II'},
  {'code': 'LAB_ASST',    'label': 'Msaidizi wa Maabara'},
  {'code': 'SR_LAB_ASST', 'label': 'Msaidizi Mkuu wa Maabara'},
  {'code': 'MALT',        'label': 'Teknolojia ya Maabara ya Matibabu'},
  {'code': 'PHARM_2',     'label': 'Daktari wa Pharmacy II'},
];

List<Map<String, String>> _getCadreOptions(String category) {
  if (category == 'education') return List.from(_kEducationCadres);
  if (category == 'health')    return List.from(_kHealthCadres);
  return [..._kEducationCadres, ..._kHealthCadres];
}

String _cadreLabel(String? code) {
  if (code == null || code.isEmpty) return '—';
  for (final c in [..._kEducationCadres, ..._kHealthCadres]) {
    if (c['code'] == code) return c['label']!;
  }
  return code;
}

String _categoryLabel(String cat) {
  if (cat == 'education') return 'Elimu';
  if (cat == 'health')    return 'Afya';
  return cat.isEmpty ? '—' : cat;
}

const _kPageSize = 20;

// ── Page ───────────────────────────────────────────────────────────
class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});
  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  List<dynamic> _matches  = [];
  bool   _loading         = true;
  String _category        = '';
  String _cadreCode       = '';
  String _q               = '';
  String _subjectQ        = '';
  int    _page            = 1;

  final _qCtrl       = TextEditingController();
  final _subjectCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await ApiService().adminRealMatches(
        category:  _category.isNotEmpty  ? _category  : null,
        cadreCode: _cadreCode.isNotEmpty ? _cadreCode : null,
        limit: 500,
      );
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _matches = (data['matches'] ?? []) as List<dynamic>;
          _page    = 1;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    final ql  = _q.trim().toLowerCase();
    final sql = _subjectQ.trim().toUpperCase();

    return _matches.where((m) {
      final a = (m['user_a'] as Map<String, dynamic>?) ?? {};
      final b = (m['user_b'] as Map<String, dynamic>?) ?? {};

      if (ql.isNotEmpty) {
        bool hit = false;
        for (final p in [a, b]) {
          final name   = (p['full_name']      ?? '').toString().toLowerCase();
          final phone  = (p['phone_primary']  ?? '').toString();
          final cadre  = _cadreLabel(p['cadre_code'] as String?).toLowerCase();
          final region = (p['current_region'] ?? '').toString().toLowerCase();
          if (name.contains(ql) || phone.contains(ql) ||
              cadre.contains(ql) || region.contains(ql)) {
            hit = true;
            break;
          }
        }
        if (!hit) return false;
      }

      if (sql.isNotEmpty) {
        final common  = (m['common_subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final aSubs   = (a['subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final bSubs   = (b['subjects'] as List?)?.map((s) => s.toString().toUpperCase()).toList() ?? [];
        final allSubs = {...common, ...aSubs, ...bSubs};
        if (!allSubs.any((s) => s.contains(sql))) return false;
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilter =>
      _category.isNotEmpty || _cadreCode.isNotEmpty ||
      _q.isNotEmpty || _subjectQ.isNotEmpty;

  void _clearFilters() {
    _qCtrl.clear();
    _subjectCtrl.clear();
    setState(() {
      _category  = '';
      _cadreCode = '';
      _q         = '';
      _subjectQ  = '';
      _page      = 1;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered   = _filtered;
    final totalPages = (filtered.length / _kPageSize).ceil().clamp(1, 99999);
    final safePage   = _page.clamp(1, totalPages);
    final start      = (safePage - 1) * _kPageSize;
    final end        = (start + _kPageSize).clamp(0, filtered.length);
    final pageItems  = filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz, size: 20, color: _kGreen600),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Match za Kweli',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _kGrey900,
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'match' : 'matches'}',
                    style: const TextStyle(fontSize: 12, color: _kGrey500),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Watu wawili wanaoweza kubadilishana vikazi vya serikali',
                style: TextStyle(fontSize: 12, color: _kGrey500),
              ),
            ],
          ),
        ),

        // ── Filters ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<String>(
                      value: _category,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Idara Zote')),
                        DropdownMenuItem(value: 'education', child: Text('Elimu')),
                        DropdownMenuItem(value: 'health',    child: Text('Afya')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _category  = v ?? '';
                          _cadreCode = '';
                          _page      = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDropdown<String>(
                      value: _cadreCode,
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Kada Zote')),
                        ..._getCadreOptions(_category).map((c) => DropdownMenuItem(
                          value: c['code'],
                          child: Text(c['label']!, overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (v) {
                        setState(() { _cadreCode = v ?? ''; _page = 1; });
                        _load();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _searchField(
                      controller: _qCtrl,
                      hint: 'Tafuta kwa jina, namba, kada au mkoa...',
                      icon: Icons.search,
                      onChanged: (v) => setState(() { _q = v; _page = 1; }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 128,
                    child: _searchField(
                      controller: _subjectCtrl,
                      hint: 'Somo (mfano MATH)',
                      icon: Icons.book_outlined,
                      onChanged: (v) => setState(() { _subjectQ = v; _page = 1; }),
                    ),
                  ),
                  if (_hasActiveFilter) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
                            SizedBox(width: 4),
                            Text(
                              'Futa',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ── Content ───────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : filtered.isEmpty
                  ? _emptyState()
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                              itemCount: pageItems.length,
                              itemBuilder: (_, i) => _MatchCard(
                                match: pageItems[i] as Map<String, dynamic>,
                              ),
                            ),
                          ),
                        ),
                        if (totalPages > 1)
                          _buildPagination(safePage, totalPages),
                      ],
                    ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: _kGrey400),
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
          prefixIcon: Icon(icon, size: 16, color: _kGrey400),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGrey200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGrey200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kGrey200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                child: const Icon(Icons.swap_horiz, size: 24, color: _kGrey400),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hakuna match za kweli zilizopatikana',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _kGrey700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Jaribu kubadilisha filters au kusubiri watu zaidi wajiungu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _kGrey400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int safePage, int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageBtn(
            label: '← Rudi',
            enabled: safePage > 1,
            onTap: () => setState(() => _page = safePage - 1),
          ),
          const SizedBox(width: 12),
          Text(
            '$safePage / $totalPages',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _kGrey500,
            ),
          ),
          const SizedBox(width: 12),
          _pageBtn(
            label: 'Endelea →',
            enabled: safePage < totalPages,
            onTap: () => setState(() => _page = safePage + 1),
          ),
        ],
      ),
    );
  }

  Widget _pageBtn({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? _kGrey700 : _kGrey400,
          ),
        ),
      ),
    );
  }
}

// ── Match card ─────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final m           = match;
    final score       = (m['score'] as num?)?.toDouble() ?? 0.0;
    final scorePct    = (score * 100).round();
    final userA       = (m['user_a'] as Map<String, dynamic>?) ?? {};
    final userB       = (m['user_b'] as Map<String, dynamic>?) ?? {};
    final category    = (userA['category'] ?? userB['category'] ?? m['category'] ?? '') as String;
    final cadreDisp   = (m['cadre_display'] ?? userA['cadre_display'] ?? userA['cadre_code'] ?? '') as String;
    final commonSubjs = (m['common_subjects'] as List?)?.map((s) => s.toString()).toList() ?? <String>[];

    final headerLabel = [
      if (category.isNotEmpty) _categoryLabel(category),
      if (cadreDisp.isNotEmpty) cadreDisp,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: score badge + category·cadre + Star ────────
          Row(
            children: [
              _ScoreBadge(score: score, pct: scorePct),
              const SizedBox(width: 8),
              if (headerLabel.isNotEmpty)
                Expanded(
                  child: Text(
                    headerLabel,
                    style: const TextStyle(fontSize: 12, color: _kGrey500),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
            ],
          ),

          // ── Common subjects ─────────────────────────────────────
          if (commonSubjs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _kGreen50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kGreen200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masomo Yanayofanana:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _kGreen700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: commonSubjs.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kGreen100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _kGreen200),
                      ),
                      child: Text(
                        '✓ $s',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _kGreen700,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Two user halves side by side (matches website grid) ─
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _UserHalf(user: userA)),
              const SizedBox(width: 8),
              Expanded(child: _UserHalf(user: userB)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Score badge (rounded-full pill) ────────────────────────────────
class _ScoreBadge extends StatelessWidget {
  final double score;
  final int    pct;
  const _ScoreBadge({required this.score, required this.pct});

  @override
  Widget build(BuildContext context) {
    late Color bg, fg, border;
    late String label;

    if (score >= 1.0) {
      bg = _kGreen100; fg = _kGreen700; border = _kGreen200;
      label = 'SAHIHI';
    } else if (score >= 0.85) {
      bg = _kBlueLt; fg = _kBlue; border = const Color(0xFF93C5FD);
      label = 'NZURI';
    } else {
      bg = _kYellow50; fg = _kYellow600; border = _kYellow300;
      label = 'POA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            '$label ($pct%)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }
}

// ── User half (compact side-by-side card) ──────────────────────────
class _UserHalf extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserHalf({required this.user});

  @override
  Widget build(BuildContext context) {
    final p        = user;
    final name     = (p['full_name']        ?? '') as String;
    final cadre    = (p['cadre_display'] ?? p['cadre_code'] ?? '') as String;
    final region   = (p['current_region']   ?? '') as String;
    final district = (p['current_district'] ?? '') as String;
    final phone    = (p['phone_primary']    ?? '') as String;
    final online   = p['online']      == true;
    final verified = p['is_verified'] == true;

    // Parse destinations (handle both List<Map> and List<String>)
    final rawDests = p['desired_destinations'];
    final dests = <String>[];
    if (rawDests is List) {
      for (final d in rawDests) {
        if (d is Map) {
          final rn = (d['region_name'] ?? d['region'] ?? '').toString();
          if (rn.isNotEmpty) dests.add(rn);
        } else {
          final s = d.toString();
          if (s.isNotEmpty) dests.add(s);
        }
      }
    }

    final subjects = (p['subjects'] as List?)
        ?.map((s) => s.toString())
        .take(3)
        .toList() ?? <String>[];

    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').where((w) => w.isNotEmpty).take(2)
            .map((w) => w[0].toUpperCase()).join()
        : '?';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kGrey50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name + verified ───────────────────────────
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: _kBlue, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (online)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _kGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kGrey900,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.check_circle, size: 11, color: _kGreen600),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // cadre
          if (cadre.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              cadre,
              style: const TextStyle(fontSize: 10, color: _kGrey500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],

          const SizedBox(height: 4),

          // Kutoka
          if (region.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 10, color: _kGrey500),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'Kutoka: ${[region, district].where((s) => s.isNotEmpty).join(', ')}',
                    style: const TextStyle(fontSize: 10, color: _kGrey500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),

          // Anataka
          if (dests.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.swap_horiz, size: 10, color: _kGrey500),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    'Anataka: ${dests.join(', ')}',
                    style: const TextStyle(fontSize: 10, color: _kGrey500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],

          // Subjects (max 3 for compact layout)
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: subjects.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _kBlue50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kBlueLt),
                ),
                child: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _kBlue,
                  ),
                ),
              )).toList(),
            ),
          ],

          // Phone full-width
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kGrey200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_outlined, size: 10, color: _kGrey500),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _kGrey700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
