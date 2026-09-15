import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ──────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey50  = Color(0xFFF9FAFB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey700 = Color(0xFF374151);
const _kGrey900 = Color(0xFF111827);
const _kGreen   = Color(0xFF22C55E);
const _kEmerald = Color(0xFF10B981);
const _kRed400  = Color(0xFFF87171);

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

String _cadreLabel(String code) {
  for (final c in [..._kEducationCadres, ..._kHealthCadres]) {
    if (c['code'] == code) return c['label']!;
  }
  return code.isEmpty ? '—' : code;
}

String _categoryLabel(String cat) {
  if (cat == 'education') return 'Elimu';
  if (cat == 'health')    return 'Afya';
  return cat.isEmpty ? '—' : cat;
}

const _kPageSize = 12;

// ── Page ───────────────────────────────────────────────────────────
class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});
  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  List<dynamic> _users   = [];
  List<dynamic> _regions = [];
  bool          _loading = false;

  int?   _regionId;      // target region
  String _category  = '';
  String _cadreCode = '';
  int?   _sourceRegion;  // client-side kutoka filter
  String _q         = '';
  int    _page      = 1;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API calls ──────────────────────────────────────────────────
  Future<void> _loadRegions() async {
    try {
      final res  = await ApiService().getRegions();
      final data = res.data;
      List<dynamic> list = [];
      if (data is Map) {
        list = (data['regions'] ?? data['data'] ?? []) as List<dynamic>;
      } else if (data is List) {
        list = data;
      }
      if (mounted) setState(() => _regions = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_regionId == null) {
      setState(() { _users = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{
        'region_id': _regionId,
        'limit':     '500',
        if (_category.isNotEmpty)  'category':   _category,
        if (_cadreCode.isNotEmpty) 'cadre_code': _cadreCode,
      };
      final res  = await ApiService().get('/admin/incoming', queryParameters: params);
      final data = res.data;
      List<dynamic> users = [];
      if (data is Map) {
        users = (data['users'] ?? data['data'] ?? []) as List<dynamic>;
      } else if (data is List) {
        users = data;
      }
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _users = []; _loading = false; });
    }
  }

  // ── Client-side filter + sort ──────────────────────────────────
  List<dynamic> get _filtered {
    var list = _users.where((u) {
      // Kutoka filter
      if (_sourceRegion != null) {
        final r = _regions.firstWhere(
          (r) => r['id'] == _sourceRegion,
          orElse: () => null,
        );
        final rName = r?['name'] as String?;
        if (rName != null && u['current_region'] != rName) return false;
      }
      // Cadre client-side (belt-and-suspenders; server also filters)
      if (_cadreCode.isNotEmpty && u['cadre_code'] != _cadreCode) return false;
      // Search
      if (_q.isNotEmpty) {
        final ql = _q.toLowerCase();
        final name    = (u['full_name']        ?? '').toString().toLowerCase();
        final phone   = (u['phone_primary']    ?? '').toString();
        final cadre   = (u['cadre_code']       ?? '').toString().toLowerCase();
        final district= (u['current_district'] ?? '').toString().toLowerCase();
        if (!name.contains(ql) &&
            !phone.contains(_q) &&
            !cadre.contains(ql) &&
            !district.contains(ql)) { return false; }
      }
      return true;
    }).toList();

    // Sort newest first
    list.sort((a, b) {
      final ta = a['created_at'] != null
          ? DateTime.tryParse(a['created_at'].toString())?.millisecondsSinceEpoch ?? 0
          : 0;
      final tb = b['created_at'] != null
          ? DateTime.tryParse(b['created_at'].toString())?.millisecondsSinceEpoch ?? 0
          : 0;
      return tb.compareTo(ta);
    });
    return list;
  }

  String get _targetRegionName {
    if (_regionId == null) return '';
    final r = _regions.firstWhere(
      (r) => r['id'] == _regionId,
      orElse: () => null,
    );
    return (r?['name'] ?? '') as String;
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered    = _filtered;
    final totalPages  = (filtered.length / _kPageSize).ceil().clamp(1, 99999);
    final safePage    = _page.clamp(1, totalPages);
    final start       = (safePage - 1) * _kPageSize;
    final pageItems   = filtered.skip(start).take(_kPageSize).toList();
    final regionName  = _targetRegionName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kBlue50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.hub_rounded, size: 20, color: _kBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wanaohamia Mkoa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _kGrey900,
                      ),
                    ),
                    Text(
                      _regionId != null
                          ? '${filtered.length} ${filtered.length == 1 ? 'mtu' : 'watu'} wanataka kuhamia $regionName'
                          : 'Chagua mkoa kuona watu wanaohamia',
                      style: const TextStyle(fontSize: 12, color: _kGrey500),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kGrey50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGrey200),
                  ),
                  child: const Center(child: Icon(Icons.refresh_rounded, size: 18, color: _kGrey700)),
                ),
              ),
            ],
          ),
        ),

        // ── Filters ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            children: [
              // Target region
              _filterField<int?>(
                title: 'Chagua Mkoa wa Lengo',
                value: _regionId,
                opts: [
                  (null, '— Mkoa Wote —'),
                  ..._regions.map((r) => (r['id'] as int, r['name'] as String)),
                ],
                onChanged: (v) { setState(() { _regionId = v; _page = 1; }); _load(); },
              ),
              const SizedBox(height: 8),
              // Category
              _filterField<String>(
                title: 'Idara Zote',
                value: _category,
                opts: const [
                  ('', 'Idara Zote'),
                  ('education', 'Elimu'),
                  ('health', 'Afya'),
                ],
                onChanged: (v) {
                  setState(() { _category = v; _cadreCode = ''; _page = 1; });
                  _load();
                },
              ),
              const SizedBox(height: 8),
              // Cadre
              _filterField<String>(
                title: 'Kada Zote',
                value: _cadreCode,
                opts: [
                  ('', 'Kada Zote'),
                  ..._getCadreOptions(_category).map((c) => (c['code']!, c['label']!)),
                ],
                onChanged: (v) { setState(() { _cadreCode = v; _page = 1; }); _load(); },
              ),
              const SizedBox(height: 8),
              // Source region (client-side)
              _filterField<int?>(
                title: 'Kutoka: Mikoa yote',
                value: _sourceRegion,
                opts: [
                  (null, 'Kutoka: Mikoa yote'),
                  ..._regions.map((r) => (r['id'] as int, 'Kutoka: ${r['name']}')),
                ],
                onChanged: (v) => setState(() { _sourceRegion = v; _page = 1; }),
              ),
              const SizedBox(height: 8),
              // Search
              SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() { _q = v; _page = 1; }),
                  decoration: InputDecoration(
                    hintText: 'Tafuta kwa jina, namba ya simu, kada au wilaya...',
                    hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
                    prefixIcon: const Icon(Icons.search, size: 18, color: _kGrey400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kGrey200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kGrey200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBlue, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Results ───────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : _regionId == null
                  ? _emptyState(
                      title: 'Chagua mkoa wa lengo kuona watu wanaohamia',
                      subtitle: 'Mtu yeyote wa Tanzania anayetaka kuja mkoa huu ataonekana hapa',
                    )
                  : filtered.isEmpty
                      ? _emptyState(
                          title: 'Hakuna mtu anayetaka kuhamia $regionName${_cadreCode.isNotEmpty ? ' wa kada hii' : ''}',
                          subtitle: 'Wataonekana mtu anapojiunga na kuchagua mkoa huu kama lengo',
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _load,
                                // grid-cols-1 sm:grid-cols-2 kama web
                                child: LayoutBuilder(builder: (ctx, constraints) {
                                  final cols = constraints.maxWidth >= 500 ? 2 : 1;
                                  return GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cols,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: cols == 2 ? 0.72 : 1.1,
                                    ),
                                    itemCount: pageItems.length,
                                    itemBuilder: (ctx, i) => _UserCard(
                                      user: pageItems[i] as Map<String, dynamic>,
                                      destRegion: regionName,
                                    ),
                                  );
                                }),
                              ),
                            ),
                            // Pagination
                            if (totalPages > 1)
                              _buildPagination(safePage, totalPages),
                          ],
                        ),
        ),
      ],
    );
  }

  // ── Filter field + bottom-sheet picker ───────────────────────
  Widget _filterField<T>({
    required String title,
    required T value,
    required List<(T, String)> opts,
    required void Function(T) onChanged,
  }) {
    final label = opts.where((o) => o.$1 == value).firstOrNull?.$2;
    final isDefault = opts.isNotEmpty && opts.first.$1 == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showFilterPicker<T>(title: title, opts: opts, selected: value, onChanged: onChanged),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(child: Text(
            label ?? title,
            style: TextStyle(fontSize: 13, color: isDefault ? _kGrey400 : _kGrey900),
            overflow: TextOverflow.ellipsis,
          )),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _kGrey400),
        ]),
      ),
    );
  }

  void _showFilterPicker<T>({
    required String title,
    required List<(T, String)> opts,
    required T selected,
    required void Function(T) onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                Expanded(child: Text(title, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kGrey900,
                ))),
                GestureDetector(
                  onTap: () => Navigator.pop(sheetCtx),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 16, color: _kGrey500),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, color: _kGrey100),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: opts.length,
                itemBuilder: (_, i) {
                  final (val, lbl) = opts[i];
                  final isSel = val == selected;
                  return ListTile(
                    title: Text(lbl, style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                      color: isSel ? _kBlue : _kGrey900,
                    )),
                    tileColor: isSel ? _kBlue50 : Colors.transparent,
                    trailing: isSel ? const Icon(Icons.check_rounded, size: 18, color: _kBlue) : null,
                    onTap: () { onChanged(val); Navigator.pop(sheetCtx); },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────
  Widget _emptyState({required String title, required String subtitle}) {
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
                decoration: BoxDecoration(
                  color: _kGrey100,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(
                  child: Icon(Icons.swap_horiz, size: 24, color: _kGrey400),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _kGrey700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _kGrey400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pagination ────────────────────────────────────────────────
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

// ── UserCard ───────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String destRegion;

  const _UserCard({required this.user, required this.destRegion});

  @override
  Widget build(BuildContext context) {
    final u        = user;
    final name     = (u['full_name'] ?? '') as String;
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
    final isOnline     = u['online']      == true;
    final isVerified   = u['is_verified'] == true;
    final category     = (u['category']         ?? '') as String;
    final cadreCode    = (u['cadre_code']        ?? '') as String;
    final currentReg   = (u['current_region']    ?? '') as String;
    final currentDist  = (u['current_district']  ?? '') as String;
    final destDistrict = (u['destination_district'] ?? '') as String;
    final phone        = (u['phone_primary']     ?? '') as String;
    final years        = u['years_of_service'];
    final subjects     = (u['subjects'] as List?)?.cast<String>() ?? <String>[];

    final isEdu = category == 'education';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGrey200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name ──────────────────────────────────────
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isEdu ? const Color(0xFFBBF7D0) : const Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: TextStyle(
                        color: isEdu ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _kGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _kGrey900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified ? _kEmerald : _kRed400,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isVerified ? '✓ PAID' : '✗ HAJALIPIA',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _categoryLabel(category),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kBlue,
                            ),
                          ),
                          const TextSpan(
                            text: ' · ',
                            style: TextStyle(fontSize: 12, color: _kGrey400),
                          ),
                          TextSpan(
                            text: _cadreLabel(cadreCode),
                            style: const TextStyle(fontSize: 12, color: _kGrey500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Kutoka → Kuja ──────────────────────────────────────
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.location_on, size: 13, color: Color(0xFFEF4444)),
            const SizedBox(width: 5),
            const Text('Kutoka: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            Expanded(child: Text(
              currentReg + (currentDist.isNotEmpty ? ', $currentDist' : ''),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.gps_fixed, size: 13, color: Color(0xFF1E40AF)),
            const SizedBox(width: 5),
            const Text('Kuja: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            Expanded(child: Text(
              destRegion + (destDistrict.isNotEmpty ? ', $destDistrict' : ''),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
              overflow: TextOverflow.ellipsis,
            )),
          ]),

          // ── Years of service ───────────────────────────────────
          if (years != null) ...[
            const SizedBox(height: 8),
            Text(
              years == 3
                  ? 'Miaka ya kazi: 3+ (miaka 3 au zaidi)'
                  : 'Miaka ya kazi: $years ${years == 1 ? 'mwaka' : 'miaka'}',
              style: const TextStyle(fontSize: 11, color: _kGrey500),
            ),
          ],

          // ── Subjects ───────────────────────────────────────────
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...subjects.take(5).map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kBlue50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ),
                ),
                if (subjects.length > 5)
                  Text(
                    '+${subjects.length - 5}',
                    style: const TextStyle(fontSize: 11, color: _kGrey400),
                  ),
              ],
            ),
          ],

          // ── Phone ──────────────────────────────────────────────
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _kGrey200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, size: 13, color: _kGrey700),
                  const SizedBox(width: 6),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kGrey900,
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
