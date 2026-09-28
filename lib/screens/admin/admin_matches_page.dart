// ============================================================================
// WALIOPATA WENZAO — watumiaji waliounganishwa na wenzao (matches)
// ----------------------------------------------------------------------------
// DESIGN (imefanana na reference images — rangi na vipimo halisi):
//  - Background NYEUPE; kadi nyeupe radius 20 + border laini
//  - Avatar mint (0xFFBFEBDD) + text ya kijani-kivu (0xFF0B5D4B)
//  - Badge: Amelipa (CBEBC8/0B6B1F) · Hajalipa (FADADD/B3261E)
//  - Panel ya cream (F7F6F1): ⭘ Anatoka → ● Anataka kuja + pills (D3E3FB/1A4E9E)
//  - Kitufe cha simu: bluu 52px radius 16 + phone_in_talk
//  - Sheets: chaguliwe tile bluu (BFD9F9) + container NYEUPE 44px; nyingine
//    container 36px + icon ya giza; search ya cream; icons maalum kila item
// Data halisi: GET /admin/users/with-matches (+ regions/departments/cadres)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';

// ── Rangi (kama reference images) ───────────────────────────────────────────
class _P {
  static const ink = Color(0xFF142033);
  static const inkSoft = Color(0xFF5B6779);
  static const inkFaint = Color(0xFF93A0B3);
  static const line = Color(0xFFE6E0D2);
  static const lineStrong = Color(0xFFCFC8B8);
  static const panelTint = Color(0xFFF6F5F1);
  static const cream = Color(0xFFF7F6F1); // panel ya Anatoka/Anataka

  // Avatar ya mint (kama picha)
  static const avatarBg = Color(0xFFBFEBDD);
  static const avatarText = Color(0xFF0B5D4B);

  static const blue = Color(0xFF1C64D1);
  static const blueTile = Color(0xFFBFD9F9); // tile/chip iliyochaguliwa
  static const pillBg = Color(0xFFD3E3FB); // pills za mikoa
  static const pillText = Color(0xFF1A4E9E);

  // Badges (kama picha)
  static const greenBg = Color(0xFFCBEBC8);
  static const greenText = Color(0xFF0B6B1F);
  static const redBg = Color(0xFFFADADD);
  static const redText = Color(0xFFB3261E);
  static const green = Color(0xFF15803D); // Live dot
}

const _kPs = 10; // kadi kwa kurasa (kadi ni ndefu)

// ── Helpers ─────────────────────────────────────────────────────────────────
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

/// Icon maalum kwa kila idara/kada (kama reference images).
IconData _itemIcon(String label, {IconData fallback = Icons.badge_outlined}) {
  final l = label.toLowerCase();
  if (l.contains('mazingira')) return Icons.eco_outlined; // leaf
  if (l.contains('ustawi') || l.contains('jamii')) {
    return Icons.volunteer_activism_outlined; // moyo mkononi
  }
  if (l.contains('nursing') || l.contains('mwuguzi')) {
    return Icons.health_and_safety_outlined; // shield+cross (ANO)
  }
  if (l.contains('medical officer')) {
    return Icons.medical_services_outlined; // briefcase+cross
  }
  if (l.contains('clinical')) return Icons.monitor_heart_outlined;
  if (l.contains('mwalimu') || l.contains('elimu') || l.contains('mwanafunzi')) {
    return Icons.school_outlined; // graduation cap
  }
  if (l.contains('kilimo') || l.contains('ufugaji') || l.contains('mifugo')) {
    return Icons.eco_outlined;
  }
  if (l.contains('watumishi')) return Icons.business_center_outlined;
  if (l.contains('ujenzi') || l.contains('uchukuzi')) {
    return Icons.engineering_outlined;
  }
  if (l.contains('afya')) return Icons.monitor_heart_outlined;
  return fallback;
}

// ═══ Models ═════════════════════════════════════════════════════════════════
class _FilterItem {
  final String value;
  final String label;
  final IconData icon;
  const _FilterItem(this.value, this.label, this.icon);
}

class _FilterSpec {
  final String defaultLabel;
  final String prefix;
  final IconData icon;
  final String sheetTitle;
  final String allLabel;
  final IconData allIcon;
  final List<_FilterItem> items;
  const _FilterSpec({
    required this.defaultLabel,
    required this.icon,
    required this.sheetTitle,
    required this.allLabel,
    required this.allIcon,
    required this.items,
    this.prefix = '',
  });
}

enum _WenzaoFilter { lengo, idara, kada, chanzo }

// ═══ Page ═══════════════════════════════════════════════════════════════════
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

  // Filters — per spec (null = "yote")
  final Map<_WenzaoFilter, String?> _selected = {
    for (final f in _WenzaoFilter.values) f: null,
  };
  String _query = '';

  int _page = 1;

  // ── Lookups (dynamic kutoka DB) ────────────────────────────────────────────
  String _deptLabel(String code) {
    for (final d in _departments) {
      if ('${d['code']}' == code) return '${d['display_name'] ?? d['name'] ?? code}';
    }
    switch (code) {
      case 'education':
        return 'Elimu';
      case 'health':
        return 'Afya';
      case 'kilimo':
        return 'Kilimo na Ufugaji';
      case 'watumishi_wa_umma':
        return 'Watumishi wa Umma';
      default:
        return code.isEmpty ? '—' : _titleCase(code);
    }
  }

  String _cadreLabel(String code) {
    for (final c in _cadres) {
      if ('${c['code']}' == code) return '${c['display_name'] ?? c['name'] ?? code}';
    }
    return code.isEmpty ? '—' : code;
  }

  List<Map<String, dynamic>> get _cadreOptions {
    if ((_selected[_WenzaoFilter.idara] ?? '').isEmpty) return _cadres;
    return _cadres
        .where((c) => '${c['category'] ?? ''}' == _selected[_WenzaoFilter.idara])
        .toList();
  }

  // ── Specs za filters (items dynamic) ───────────────────────────────────────
  _FilterSpec _spec(_WenzaoFilter f) {
    switch (f) {
      case _WenzaoFilter.lengo:
        return _FilterSpec(
          defaultLabel: 'Mkoa wa Lengo',
          icon: Icons.map_outlined,
          sheetTitle: 'Chagua Mkoa wa Lengo',
          allLabel: 'Mikoa yote',
          allIcon: Icons.map_outlined,
          items: [
            for (final r in _regions)
              _FilterItem('${r['name'] ?? r['region_name'] ?? ''}',
                  '${r['name'] ?? r['region_name'] ?? ''}', Icons.location_on_outlined),
          ],
        );
      case _WenzaoFilter.idara:
        return _FilterSpec(
          defaultLabel: 'Idara zote',
          icon: Icons.apartment_outlined,
          sheetTitle: 'Chagua Idara',
          allLabel: 'Idara zote',
          allIcon: Icons.grid_view_rounded,
          items: [
            for (final d in _departments)
              _FilterItem(
                  '${d['code']}',
                  '${d['display_name'] ?? d['name'] ?? d['code']}',
                  _itemIcon('${d['display_name'] ?? d['name'] ?? d['code']}',
                      fallback: Icons.apartment_outlined)),
          ],
        );
      case _WenzaoFilter.kada:
        return _FilterSpec(
          defaultLabel: 'Kada zote',
          icon: Icons.badge_outlined,
          sheetTitle: 'Chagua Kada',
          allLabel: 'Kada zote',
          allIcon: Icons.grid_view_rounded,
          items: [
            for (final c in _cadreOptions)
              _FilterItem(
                  '${c['code']}',
                  '${c['display_name'] ?? c['name'] ?? c['code']}',
                  _itemIcon('${c['display_name'] ?? c['name'] ?? c['code']}')),
          ],
        );
      case _WenzaoFilter.chanzo:
        return _FilterSpec(
          defaultLabel: 'Kutoka: yote',
          prefix: 'Kutoka: ',
          icon: Icons.exit_to_app_rounded,
          sheetTitle: 'Chagua Mkoa wa Chanzo',
          allLabel: 'Mikoa yote',
          allIcon: Icons.map_outlined,
          items: [
            for (final r in _regions)
              _FilterItem('${r['name'] ?? r['region_name'] ?? ''}',
                  '${r['name'] ?? r['region_name'] ?? ''}', Icons.location_on_outlined),
          ],
        );
    }
  }

  // ── Filtering (client-side) ────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'[^0-9+]'), '');
    final lengo = _selected[_WenzaoFilter.lengo];
    final idara = _selected[_WenzaoFilter.idara];
    final kada = _selected[_WenzaoFilter.kada];
    final chanzo = _selected[_WenzaoFilter.chanzo];
    return _all.where((m) {
      if (idara != null && '${m['category'] ?? ''}' != idara) return false;
      if (kada != null && '${m['cadre_code'] ?? ''}' != kada) return false;
      if (lengo != null) {
        final dests = ((m['destinations'] as List?) ?? [])
            .map((d) =>
                (d is Map ? '${d['region_name'] ?? d['name'] ?? d}' : '$d').toLowerCase())
            .toList();
        if (!dests.contains(lengo.toLowerCase())) return false;
      }
      if (chanzo != null) {
        final rn = '${m['region_name'] ?? m['current_region'] ?? ''}';
        if (rn.toLowerCase() != chanzo.toLowerCase()) return false;
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
  int get _safePage => _page.clamp(1, _totalPages);
  List<Map<String, dynamic>> get _pageItems {
    final s = (_safePage - 1) * _kPs;
    return _filtered.sublist(s, (s + _kPs).clamp(0, _filtered.length));
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
    _loadRefs();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text;
        _page = 1;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      setState(() {
        _loading = false;
        _error = e.toString();
      });
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
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  bool get _hasFilter => _selected.values.any((v) => v != null) || _query.isNotEmpty;

  void _resetFilters() {
    setState(() {
      for (final f in _WenzaoFilter.values) {
        _selected[f] = null;
      }
      _page = 1;
    });
    _searchCtrl.clear();
  }

  // ── Sheet ya kuchagua ──────────────────────────────────────────────────────
  Future<void> _openFilter(_WenzaoFilter f) async {
    final spec = _spec(f);
    final pick = await showModalBottomSheet<_Pick>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(spec: spec, current: _selected[f]),
    );
    // pick != null hata kwa "yote" (value ni null) — kufunga bila kuchaguwa
    // (pick == null) halifuti uteuzi uliokuwepo.
    if (pick != null) {
      setState(() {
        _selected[f] = pick.value;
        if (f == _WenzaoFilter.idara) _selected[_WenzaoFilter.kada] = null;
        _page = 1;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _P.blue,
        backgroundColor: Colors.white,
        child: ListView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildFilterChips(),
            const SizedBox(height: 12),
            _buildSearch(),
            const SizedBox(height: 12),
            if (!_loading && _error == null)
              Text(
                'Inaonyesha ${_pageItems.length} kati ya ${filtered.length}',
                style: const TextStyle(fontSize: 13, color: _P.inkSoft),
              ),
            const SizedBox(height: 10),
            // ── Body ──
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: _P.blue)),
              )
            else if (_error != null)
              _ErrorState(onRetry: _load)
            else if (filtered.isEmpty)
              _EmptyState(onClear: _hasFilter ? _resetFilters : null)
            else ...[
              for (final m in _pageItems) ...[
                _WenzaoCard(user: m, deptLabel: _deptLabel, cadreLabel: _cadreLabel),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 4),
              _Pagination(
                current: _safePage,
                total: _totalPages,
                onChanged: _goToPage,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _P.greenBg,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.swap_horiz_rounded, size: 27, color: _P.greenText),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Waliopata Wenzao',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _P.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _loading
                    ? 'Inapakia…'
                    : '${_filtered.length} watu waliounganishwa na wenzao',
                style: const TextStyle(fontSize: 13, color: _P.inkSoft),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: _P.greenBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: _P.greenText),
              SizedBox(width: 5),
              Text(
                'Live',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _P.greenText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _WenzaoFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _WenzaoFilter.values[i];
          final spec = _spec(f);
          final value = _selected[f];
          return _FilterChip(
            icon: spec.icon,
            label: value == null ? spec.defaultLabel : '${spec.prefix}$value',
            active: value != null,
            onTap: () => _openFilter(f),
          );
        },
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(fontSize: 15, color: _P.ink),
      decoration: InputDecoration(
        hintText: 'Tafuta kwa jina, namba, kada au wilaya',
        hintStyle: const TextStyle(fontSize: 14, color: _P.inkFaint),
        prefixIcon: const Icon(Icons.search_rounded, size: 22, color: _P.inkFaint),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: _P.inkSoft),
                onPressed: _searchCtrl.clear,
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: _P.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: _P.blue, width: 1.2),
        ),
      ),
    );
  }
}

// ═══ Error / Empty states ═══════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: _P.inkFaint),
          const SizedBox(height: 12),
          const Text('Imeshindikana kupakia',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _P.ink)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Jaribu tena',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: _P.blue,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onClear;
  const _EmptyState({this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: _P.panelTint, borderRadius: BorderRadius.circular(26)),
            child: const Icon(Icons.search_off_rounded,
                color: _P.inkFaint, size: 24),
          ),
          const SizedBox(height: 12),
          const Text('Hakuna matokeo yanayolingana',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _P.ink)),
          const SizedBox(height: 4),
          const Text(
            'Watumiaji wataonekana wanapojiunga na kuchagua destinations',
            style: TextStyle(color: _P.inkSoft, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (onClear != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onClear,
              child: const Text('Futa vichujio',
                  style: TextStyle(color: _P.blue, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══ Kichujio (chip) ════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _P.blueTile : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: active ? Colors.transparent : _P.line),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: _P.pillText),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active ? _P.pillText : _P.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _P.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══ Karatasi ya kuchagua (bottom sheet — kama reference) ═══════════════════
class _Pick {
  final String? value; // null = "yote"
  const _Pick(this.value);
}

class _FilterSheet extends StatefulWidget {
  final _FilterSpec spec;
  final String? current;
  const _FilterSheet({required this.spec, required this.current});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final items = spec.items
        .where((e) => _q.isEmpty || e.label.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      spec.sheetTitle,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _P.ink,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, size: 24, color: _P.ink),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(fontSize: 15.5, color: _P.ink),
                decoration: InputDecoration(
                  hintText: 'Tafuta…',
                  hintStyle: const TextStyle(fontSize: 15, color: _P.inkFaint),
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 22, color: _P.inkFaint),
                  filled: true,
                  fillColor: _P.cream,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                children: [
                  _OptionTile(
                    label: spec.allLabel,
                    icon: spec.allIcon,
                    selected: widget.current == null,
                    onTap: () => Navigator.of(context).pop(const _Pick(null)),
                  ),
                  const SizedBox(height: 10),
                  for (final it in items) ...[
                    _OptionTile(
                      label: it.label,
                      icon: it.icon,
                      selected: widget.current == it.value,
                      onTap: () => Navigator.of(context).pop(_Pick(it.value)),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kama reference: tile iliyochaguliwa = bluu + container NYEUPE kubwa;
    // zisizochaguliwa = container ndogo ya cream + icon ya giza.
    return Material(
      color: selected ? _P.blueTile : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: selected ? 44 : 38,
                height: selected ? 44 : 38,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : _P.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: selected ? 22 : 19,
                    color: selected ? _P.blue : const Color(0xFF3D4A5C)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.5,
                    height: 1.3,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? _P.blue : _P.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, size: 22, color: _P.blue),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══ Kadi ya mtu (kama reference) ═══════════════════════════════════════════
class _WenzaoCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String Function(String) deptLabel;
  final String Function(String) cadreLabel;
  const _WenzaoCard({
    required this.user,
    required this.deptLabel,
    required this.cadreLabel,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final cat = user['category'] as String? ?? '';
    final cadreCode = user['cadre_code'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ??
        (cadreCode.isEmpty ? '' : cadreLabel(cadreCode));
    final paid = (user['is_verified'] as bool?) ?? false;
    final region = user['region_name'] as String? ??
        user['current_region'] as String? ??
        (asMap(user['current_station'])['region_name'] as String? ?? '');
    final district = user['district_name'] as String? ??
        (asMap(user['current_station'])['district_name'] as String? ?? '');
    final dests = ((user['destinations'] as List?) ?? [])
        .map((d) => d is Map ? '${d['region_name'] ?? d['name'] ?? d}' : '$d')
        .where((s) => s.isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: const [
          BoxShadow(color: Color(0x0A142033), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _P.avatarBg,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: _P.avatarText,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '(bila jina)' : _titleCase(name),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: _P.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [if (cat.isNotEmpty) deptLabel(cat), if (cadre.isNotEmpty) cadre]
                          .join(' · '),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: _P.inkSoft,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PaidBadge(paid: paid),
            ],
          ),
          const SizedBox(height: 14),

          // ---- Njia ya safari (panel ya cream) ----
          if (region.isNotEmpty || district.isNotEmpty || dests.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _P.cream,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 14,
                          child: Column(
                            children: [
                              const SizedBox(height: 3),
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF6B7280), width: 2),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 1.5,
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  color: const Color(0xFFC9CDD4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Anatoka',
                                    style: TextStyle(
                                        fontSize: 13.5, color: _P.inkSoft)),
                                const SizedBox(height: 2),
                                Text(
                                  [region, district]
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: _P.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 11,
                              height: 11,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _P.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Anataka kuja',
                                style: TextStyle(
                                    fontSize: 13.5, color: _P.inkSoft)),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final r in dests.take(4))
                                  _RegionPill(text: r),
                                if (dests.length > 4)
                                  _RegionPill(text: '+${dests.length - 4}',
                                      muted: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // ---- Simu ----
          if (phone.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 21, color: _P.ink),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w600,
                      color: _P.ink,
                    ),
                  ),
                ),
                Material(
                  color: _P.blue,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      try {
                        await launchUrl(Uri.parse('tel:$phone'),
                            mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.phone_in_talk_rounded,
                          size: 25, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  final bool paid;
  const _PaidBadge({required this.paid});

  @override
  Widget build(BuildContext context) {
    final fg = paid ? _P.greenText : _P.redText;
    final bg = paid ? _P.greenBg : _P.redBg;
    return Container(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            paid ? 'Amelipa' : 'Hajalipa',
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

class _RegionPill extends StatelessWidget {
  final String text;
  final bool muted;
  const _RegionPill({required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: muted ? Colors.white : _P.pillBg,
        borderRadius: BorderRadius.circular(999),
        border: muted ? Border.all(color: _P.line) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: muted ? _P.inkSoft : _P.pillText,
        ),
      ),
    );
  }
}

// ═══ Kurasa (pagination) ════════════════════════════════════════════════════
class _Pagination extends StatelessWidget {
  final int current;
  final int total;
  final ValueChanged<int> onChanged;

  const _Pagination({
    required this.current,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final start = (current - 2).clamp(1, (total - 4).clamp(1, total));
    final end = (start + 4).clamp(1, total);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circle(
          child: const Icon(Icons.chevron_left_rounded, size: 20),
          enabled: current > 1,
          onTap: () => onChanged(current - 1),
        ),
        for (var i = start; i <= end; i++)
          _circle(
            active: i == current,
            child: Text(
              '$i',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: i == current ? Colors.white : _P.inkSoft,
              ),
            ),
            onTap: () => onChanged(i),
          ),
        _circle(
          child: const Icon(Icons.chevron_right_rounded, size: 20),
          enabled: current < total,
          onTap: () => onChanged(current + 1),
        ),
      ],
    );
  }

  Widget _circle({
    required Widget child,
    required VoidCallback onTap,
    bool active = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: active ? _P.blue : Colors.white,
        shape: CircleBorder(
          side: BorderSide(color: active ? Colors.transparent : _P.line),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 34,
            height: 34,
            child: IconTheme(
              data: IconThemeData(color: enabled ? _P.inkSoft : _P.inkFaint),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
