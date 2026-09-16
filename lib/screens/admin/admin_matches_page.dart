/// Waliopata Wenzao — watumiaji waliounganishwa na wenzao (matches).
///
/// Data inatoka `/admin/users/with-matches` (backend): kila mtumiaji ana
/// `match_count` na orodha ya `matched_users` (jina, kada, mkoa, simu).
/// Hivyo admin anaona NAMBA na mwenzi wake moja kwa moja — siyo kadi tupu.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

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
  String _category = '';
  List<dynamic> _departments = [];
  String? _openId; // mtumiaji aliyeachiliwa orodha ya wenzake

  @override
  void initState() {
    super.initState();
    _load();
    _loadDepartments();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final r = await ApiService().getDepartments();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _departments = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminUsersWithMatches(limit: 200);
      if (!mounted) return;
      final data = res.data;
      final list = data is List ? data : ((data['users'] ?? data['results'] ?? []) as List);
      setState(() {
        _all = list;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _filtered = _all.where((item) {
        final m = item as Map;
        final cat = '${m['category'] ?? ''}';
        if (_category.isNotEmpty && cat != _category) return false;
        if (q.isEmpty) return true;
        final name = '${m['full_name'] ?? ''}'.toLowerCase();
        final phone = '${m['phone_primary'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
        final phone2 = '${m['phone_alt'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
        final cadre = '${m['cadre_display'] ?? m['cadre_code'] ?? ''}'.toLowerCase();
        final region = '${m['region_name'] ?? ''}'.toLowerCase();
        final district = '${m['district_name'] ?? ''}'.toLowerCase();
        final partners = ((m['matched_users'] as List?) ?? [])
            .map((p) => '${(p as Map)['full_name'] ?? ''}'.toLowerCase())
            .join(' ');
        return name.contains(q) ||
            cadre.contains(q) ||
            region.contains(q) ||
            district.contains(q) ||
            partners.contains(q) ||
            (digits.isNotEmpty && (phone.contains(digits) || phone2.contains(digits)));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: [
        _header(),
        _searchBar(),
        if (_departments.isNotEmpty) _chips(),
        const Divider(height: 1, color: AppColors.borderLight),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person_search_outlined, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Waliopata Wenzao',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(
              _loading
                  ? 'Inapakia...'
                  : '${_filtered.length} watumiaji waliounganishwa'
                      '${_filtered.length != _all.length ? ' kati ya ${_all.length}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ]),
        ),
        GestureDetector(
          onTap: _load,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.grey200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, size: 19, color: AppColors.primary),
          ),
        ),
      ]),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Tafuta kwa jina, simu, kada, mkoa au mwenzi...',
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textLight),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: () { _searchCtrl.clear(); _applyFilter(); },
                  child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textLight),
                ),
        ),
      ),
    );
  }

  Widget _chips() {
    final items = <({String code, String name})>[
      (code: '', name: 'Zote'),
      for (final d in _departments)
        (code: '${d['code']}', name: '${d['name'] ?? d['code']}'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          final selected = _category == it.code;
          return GestureDetector(
            onTap: () {
              setState(() => _category = it.code);
              _applyFilter();
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.blue50 : Colors.white,
                border: Border.all(color: selected ? AppColors.primary : AppColors.grey200),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(it.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.error),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Jaribu tena'),
            ),
          ]),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(children: [
          const SizedBox(height: 80),
          const Icon(Icons.person_search_outlined, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _all.isEmpty
                  ? 'Hakuna mtumiaji aliyepata mwenzi bado'
                  : 'Hakuna aliye patikana kwa kichujio hiki',
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final u = (_filtered[i] as Map).cast<String, dynamic>();
          final id = '${u['_id'] ?? u['user_id'] ?? i}';
          return _UserMatchesCard(
            user: u,
            expanded: _openId == id,
            onToggle: () => setState(() => _openId = _openId == id ? null : id),
          );
        },
      ),
    );
  }
}

class _UserMatchesCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool expanded;
  final VoidCallback onToggle;

  const _UserMatchesCard({
    required this.user,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = '${user['full_name'] ?? ''}';
    final phone = '${user['phone_primary'] ?? ''}';
    final category = '${user['category'] ?? ''}';
    final cadre = '${user['cadre_display'] ?? user['cadre_code'] ?? ''}';
    final region = '${user['region_name'] ?? ''}';
    final district = '${user['district_name'] ?? ''}';
    final destinations = ((user['destinations'] as List?) ?? []).map((d) => '$d').toList();
    final partners = ((user['matched_users'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final count = (user['match_count'] as num?)?.toInt() ?? partners.length;
    final paid = user['is_verified'] == true || user['contact_enabled'] == true;
    final online = user['online'] == true;
    final status = '${user['status'] ?? ''}';
    final disabled = status == 'disabled' || status == 'suspended';
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(children: [
        InkWell(
          onTap: count > 0 ? onToggle : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Stack(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.blue50,
                    child: Text(initials,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  if (online)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          name.isEmpty ? '(bila jina)' : name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: disabled ? AppColors.textLight : AppColors.textPrimary,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(paid ? '✓ AMELIPA' : '✗ HAJALIPIA',
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: paid ? AppColors.success : AppColors.error)),
                      ),
                      if (disabled) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.grey100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('IMESITISHWA',
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      [
                        category == 'health'
                            ? 'Afya'
                            : category == 'education'
                                ? 'Elimu'
                                : category,
                        cadre,
                      ].where((s) => s.trim().isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
                if (count > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.blue200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.people_alt_outlined, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('$count',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: AppColors.textLight),
                ],
              ]),
              const SizedBox(height: 10),
              // Kutoka → Anataka
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue100),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Kutoka: ${[region, district].where((s) => s.isNotEmpty).join(', ')}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  if (destinations.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.my_location_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Anataka: ${destinations.join(', ')}',
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        ),

        // ── Wenzake (matched users) ──
        if (expanded && partners.isNotEmpty) ...[
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Text('WENZAKE (${partners.length})',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6)),
              ]),
              const SizedBox(height: 8),
              for (final p in partners) _partnerRow(context, p),
            ]),
          ),
        ],

        // ── Piga simu ──
        if (phone.isNotEmpty) ...[
          const Divider(height: 1, color: AppColors.borderLight),
          InkWell(
            onTap: () => _call(context, phone),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone_outlined, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(phone,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _partnerRow(BuildContext context, Map<String, dynamic> p) {
    final name = '${p['full_name'] ?? ''}';
    final phone = '${p['phone_primary'] ?? ''}';
    final cadre = '${p['cadre_display'] ?? ''}';
    final region = '${p['region_name'] ?? ''}';
    final score = (p['score'] as num?)?.toDouble() ?? 0;
    final pct = (score * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(children: [
        const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textLight),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? '(bila jina)' : name,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              [cadre, region, if (phone.isNotEmpty) phone].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        if (score > 0)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: score >= 1.0
                  ? const Color(0xFFDCFCE7)
                  : score >= 0.85
                      ? AppColors.blue50
                      : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$pct%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: score >= 1.0
                      ? AppColors.success
                      : score >= 0.85
                          ? AppColors.primary
                          : const Color(0xFFD97706),
                )),
          ),
        if (phone.isNotEmpty)
          GestureDetector(
            onTap: () => _call(context, phone),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.grey200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
            ),
          ),
      ]),
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Namba $phone imenakiliwa'), backgroundColor: AppColors.primary),
      );
    }
  }
}
