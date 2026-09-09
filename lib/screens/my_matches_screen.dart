import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

// ── Brand colors (same as web globals.css) ────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kBlue200   = Color(0xFFBFDBFE);
const _kBlue700   = Color(0xFF1D4ED8);
const _kGrey900   = Color(0xFF111827);
const _kGrey700   = Color(0xFF374151);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey50    = Color(0xFFF9FAFB);
const _kGreen50   = Color(0xFFF0FDF4);
const _kGreen300  = Color(0xFF86EFAC);
const _kGreen600  = Color(0xFF16A34A);
const _kGreen700  = Color(0xFF15803D);

const _kYellow50  = Color(0xFFFEFCE8);
const _kYellow300 = Color(0xFFFDE047);
const _kYellow700 = Color(0xFFA16207);


BoxDecoration _card() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _kGrey200),
  boxShadow: const [BoxShadow(
    color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
);

// ── Score badge config ────────────────────────────────────────────────────────
Map<String, dynamic> _scoreBadge(double score) {
  if (score >= 1.0) return {'label': 'SAHIHI', 'bg': _kGreen50, 'fg': _kGreen700, 'border': _kGreen300};
  if (score >= 0.85) return {'label': 'NZURI',  'bg': _kBlue50,  'fg': _kBlue700,  'border': _kBlue200};
  return                     {'label': 'POA',    'bg': _kYellow50,'fg': _kYellow700,'border': _kYellow300};
}

String _initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

String _relDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1)  return 'Sasa hivi';
    if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes} iliyopita';
    if (diff.inHours < 24)   return 'masaa ${diff.inHours} iliyopita';
    if (diff.inDays < 7)     return 'siku ${diff.inDays} iliyopita';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  } catch (_) { return ''; }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});
  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  Timer? _wsTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // Refresh on WS match events
    WebSocketService().onAny((_) {
      _wsTimer?.cancel();
      _wsTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _wsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kGrey50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kGrey900,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mechi Zangu',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kGrey900)),
            Text('Watu wanaofanana nawe', style: TextStyle(fontSize: 11, color: _kGrey500)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: _kBlue,
              unselectedLabelColor: _kGrey500,
              indicatorColor: _kBlue,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: 'Waliopata Wenzao'),
                Tab(text: 'Match za Kweli'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _MyMatchesTab(),
          _RealMatchesTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 1: Waliopata Wenzao  (/matches/me)
// ══════════════════════════════════════════════════════════════════════════════
class _MyMatchesTab extends StatefulWidget {
  const _MyMatchesTab();
  @override
  State<_MyMatchesTab> createState() => _MyMatchesTabState();
}

class _MyMatchesTabState extends State<_MyMatchesTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res  = await ApiService().get('/matches/me');
      final data = res.data as Map<String, dynamic>;
      setState(() { _matches = data['matches'] ?? []; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: SizedBox(width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)));
    }
    if (_error != null) {
      return _ErrorState(onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load, color: _kBlue,
      child: _matches.isEmpty
          ? _EmptyState(
              icon: Icons.swap_horiz_outlined,
              title: 'Bado Huna Mechi',
              subtitle: 'Mtu anapolingana na chaguo lako ataonekana hapa')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
              itemCount: _matches.length,
              itemBuilder: (_, i) => _MyMatchCard(match: _matches[i])),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class _MyMatchCard extends StatelessWidget {
  final dynamic match;
  const _MyMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final a     = (match['user_a'] as Map?) ?? {};
    final b     = (match['user_b'] as Map?) ?? {};
    final score = (match['score'] ?? 0.0) as num;
    final badge = _scoreBadge(score.toDouble());
    final date  = _relDate(match['matched_at']?.toString());
    final subs  = (match['common_subjects'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badge['bg'] as Color,
                border: Border.all(color: badge['border'] as Color),
                borderRadius: BorderRadius.circular(999)),
              child: Text(badge['label'] as String,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: badge['fg'] as Color, letterSpacing: 0.5)),
            ),
            const Spacer(),
            if (date.isNotEmpty)
              Text(date, style: const TextStyle(fontSize: 10, color: _kGrey400)),
          ]),
        ),

        // ── Users: A ↔ B ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _UserPill(user: a)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kBlue50, shape: BoxShape.circle,
                  border: Border.all(color: _kBlue200)),
                child: const Icon(Icons.swap_horiz, size: 14, color: _kBlue)),
            ),
            Expanded(child: _UserPill(user: b)),
          ]),
        ),

        // ── Common subjects ───────────────────────────────────────────────
        if (subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Masomo ya Pamoja',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: _kGrey400, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4,
                children: subs.take(6).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBlue50, borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _kBlue200)),
                  child: Text('$s',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: _kBlue700)),
                )).toList()),
            ]),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 2: Match za Kweli  (/matches/true)
// ══════════════════════════════════════════════════════════════════════════════
class _RealMatchesTab extends StatefulWidget {
  const _RealMatchesTab();
  @override
  State<_RealMatchesTab> createState() => _RealMatchesTabState();
}

class _RealMatchesTabState extends State<_RealMatchesTab>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _matches = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String _subQ = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res  = await ApiService().get('/matches/true');
      final data = res.data as Map<String, dynamic>;
      setState(() { _matches = data['matches'] ?? []; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<dynamic> get _filtered {
    return _matches.where((m) {
      final a  = (m['user_a'] as Map?) ?? {};
      final b  = (m['user_b'] as Map?) ?? {};
      if (_q.isNotEmpty) {
        final ql = _q.toLowerCase();
        final names = '${a['full_name'] ?? ''} ${b['full_name'] ?? ''}'.toLowerCase();
        final phones = '${a['phone_primary'] ?? ''} ${b['phone_primary'] ?? ''}';
        final regions = '${a['region_name'] ?? ''} ${b['region_name'] ?? ''}'.toLowerCase();
        if (!names.contains(ql) && !phones.contains(_q) && !regions.contains(ql)) return false;
      }
      if (_subQ.isNotEmpty) {
        final subs = (m['common_subjects'] as List?) ?? [];
        if (!subs.any((s) => '$s'.toUpperCase().contains(_subQ.toUpperCase()))) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filtered;

    if (_loading) {
      return const Center(child: SizedBox(width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)));
    }
    if (_error != null) return _ErrorState(onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load, color: _kBlue,
      child: CustomScrollView(
        slivers: [
          // ── Search bar ────────────────────────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(children: [
              // Search
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white, border: Border.all(color: _kGrey200),
                  borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tafuta kwa jina, simu, au mkoa...',
                    hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    prefixIcon: const Icon(Icons.search, size: 16, color: _kGrey400),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    suffixIcon: _q.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 14, color: _kGrey400),
                            onPressed: () => setState(() => _q = ''))
                        : null),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white, border: Border.all(color: _kGrey200),
                    borderRadius: BorderRadius.circular(10)),
                  child: TextField(
                    onChanged: (v) => setState(() => _subQ = v),
                    style: const TextStyle(fontSize: 12),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Somo (mfano MATH)',
                      hintStyle: TextStyle(fontSize: 12, color: _kGrey400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: Icon(Icons.school_outlined, size: 15, color: _kGrey400),
                      prefixIconConstraints: BoxConstraints(minWidth: 32, minHeight: 32)),
                  ),
                )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kGrey50, border: Border.all(color: _kGrey200),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text('${filtered.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kGrey700)),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          )),
          // ── List ─────────────────────────────────────────────────────
          filtered.isEmpty
              ? SliverFillRemaining(child: _EmptyState(
                  icon: Icons.people_outline,
                  title: 'Hakuna Match za Kweli',
                  subtitle: _q.isNotEmpty || _subQ.isNotEmpty
                      ? 'Jaribu kubadilisha vichujio'
                      : 'Match za kweli zitaonekana hapa'))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, i == filtered.length - 1 ? 80 : 10),
                      child: _RealMatchCard(match: filtered[i])),
                    childCount: filtered.length)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class _RealMatchCard extends StatelessWidget {
  final dynamic match;
  const _RealMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final a     = (match['user_a'] as Map?) ?? {};
    final b     = (match['user_b'] as Map?) ?? {};
    final score = (match['score'] ?? 0.0) as num;
    final badge = _scoreBadge(score.toDouble());
    final cadre = (match['cadre_display'] ?? match['cadre'] ?? '').toString();
    final subs  = (match['common_subjects'] as List?) ?? [];
    final date  = _relDate(match['matched_at']?.toString() ?? match['created_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Top badge row ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badge['bg'] as Color,
                border: Border.all(color: badge['border'] as Color),
                borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 10, color: badge['fg'] as Color),
                const SizedBox(width: 3),
                Text(badge['label'] as String,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: badge['fg'] as Color, letterSpacing: 0.5)),
              ]),
            ),
            const SizedBox(width: 6),
            if (cadre.isNotEmpty)
              Expanded(child: Text(cadre,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue),
                overflow: TextOverflow.ellipsis)),
            if (date.isNotEmpty)
              Text(date, style: const TextStyle(fontSize: 10, color: _kGrey400)),
          ]),
        ),

        // ── Users: A ↔ B ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _UserPill(user: a)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kGreen50, shape: BoxShape.circle,
                  border: Border.all(color: _kGreen300)),
                child: const Icon(Icons.compare_arrows_rounded, size: 14, color: _kGreen600)),
            ),
            Expanded(child: _UserPill(user: b)),
          ]),
        ),

        // ── Common subjects ────────────────────────────────────────────
        if (subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.book_outlined, size: 11, color: _kGrey400),
                SizedBox(width: 4),
                Text('Masomo ya Pamoja',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: _kGrey400, letterSpacing: 0.4)),
              ]),
              const SizedBox(height: 5),
              Wrap(spacing: 4, runSpacing: 4,
                children: subs.take(8).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kGreen50, borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _kGreen300)),
                  child: Text('$s',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: _kGreen700)),
                )).toList()),
            ])),
        if (subs.isEmpty) const SizedBox(height: 14),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED: User pill card
// ══════════════════════════════════════════════════════════════════════════════
class _UserPill extends StatelessWidget {
  final Map<dynamic, dynamic> user;
  const _UserPill({required this.user});

  @override
  Widget build(BuildContext context) {
    final name   = (user['full_name'] ?? '').toString();
    final cadre  = (user['cadre_display'] ?? user['cadre_code'] ?? '').toString();
    final region = ((user['current_station'] as Map?)?['region_name'] ?? user['region_name'] ?? '').toString();
    final phone  = (user['phone_primary'] ?? '').toString();
    final online = user['online'] == true;
    final init   = _initials(name);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kGrey50, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGrey100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stack(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBlue50,
                border: Border.all(color: _kBlue200, width: 1.5)),
              child: Center(child: Text(init,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kBlue)))),
            if (online) Positioned(right: 0, bottom: 0,
              child: Container(width: 10, height: 10,
                decoration: BoxDecoration(
                  color: _kGreen600, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)))),
          ]),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kGrey900),
              overflow: TextOverflow.ellipsis, maxLines: 2),
            if (cadre.isNotEmpty)
              Text(cadre,
                style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
        if (region.isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 10, color: _kGrey400),
            const SizedBox(width: 3),
            Expanded(child: Text(region,
              style: const TextStyle(fontSize: 10, color: _kGrey500),
              overflow: TextOverflow.ellipsis)),
          ]),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // open dialer
            },
            child: Row(children: [
              const Icon(Icons.phone_outlined, size: 10, color: _kBlue),
              const SizedBox(width: 3),
              Expanded(child: Text(phone,
                style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED: Empty + Error states
// ══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: _kGrey400)),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kGrey700)),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(subtitle,
              style: const TextStyle(fontSize: 12, color: _kGrey400),
              textAlign: TextAlign.center)),
        ]),
      ),
    ]);
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
      const SizedBox(height: 12),
      const Text('Hitilafu ya kuunganisha', style: TextStyle(fontSize: 14, color: _kGrey700)),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Jaribu Tena'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    ]));
  }
}
