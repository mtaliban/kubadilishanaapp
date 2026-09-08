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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, size: 22, color: _kBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wanaohamia Mkoa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _kGrey900,
                      ),
                    ),
                    const SizedBox(height: 1),
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
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.refresh, size: 20, color: _kGrey500),
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
              _buildDropdown<int?>(
                value: _regionId,
                hint: '— Chagua Mkoa wa Lengo —',
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Chagua Mkoa wa Lengo —')),
                  ..._regions.map((r) => DropdownMenuItem(
                    value: r['id'] as int,
                    child: Text(r['name'] as String),
                  )),
                ],
                onChanged: (v) {
                  setState(() { _regionId = v; _page = 1; });
                  _load();
                },
              ),
              const SizedBox(height: 8),
              // Category
              _buildDropdown<String>(
                value: _category,
                hint: 'Idara Zote',
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
              const SizedBox(height: 8),
              // Cadre
              _buildDropdown<String>(
                value: _cadreCode,
                hint: 'Kada Zote',
                items: [
                  const DropdownMenuItem(value: '', child: Text('Kada Zote')),
                  ..._getCadreOptions(_category).map((c) => DropdownMenuItem(
                    value: c['code'],
                    child: Text(c['label']!),
                  )),
                ],
                onChanged: (v) {
                  setState(() { _cadreCode = v ?? ''; _page = 1; });
                  _load();
                },
              ),
              const SizedBox(height: 8),
              // Source region (client-side)
              _buildDropdown<int?>(
                value: _sourceRegion,
                hint: 'Kutoka: Mikoa yote',
                items: [
                  const DropdownMenuItem(value: null, child: Text('Kutoka: Mikoa yote')),
                  ..._regions.map((r) => DropdownMenuItem(
                    value: r['id'] as int,
                    child: Text('Kutoka: ${r['name']}'),
                  )),
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
                    fillColor: Colors.white,
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
                      borderSide: const BorderSide(color: _kBlue),
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
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                                  itemCount: pageItems.length,
                                  itemBuilder: (ctx, i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _UserCard(
                                      user: pageItems[i] as Map<String, dynamic>,
                                      destRegion: regionName,
                                    ),
                                  ),
                                ),
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

  // ── Dropdown builder ──────────────────────────────────────────
  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kGrey400),
        style: const TextStyle(fontSize: 13, color: _kGrey900),
        items: items,
        onChanged: onChanged,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
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
                    decoration: const BoxDecoration(
                      color: _kBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kGrey50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 11, color: _kGrey500),
                    const SizedBox(width: 3),
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: _kGrey500),
                          children: [
                            const TextSpan(text: 'Kutoka: '),
                            TextSpan(
                              text: currentReg +
                                  (currentDist.isNotEmpty ? ', $currentDist' : ''),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _kGrey700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 11, color: _kBlue),
                    const SizedBox(width: 3),
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: _kBlue),
                          children: [
                            const TextSpan(
                              text: 'Kuja: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: destRegion +
                                  (destDistrict.isNotEmpty ? ', $destDistrict' : ''),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

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
