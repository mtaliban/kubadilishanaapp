import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kRed     = Color(0xFFDC2626);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});
  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _categoryFilter = '';
  List<dynamic> _departments = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadDepartments();
    _searchCtrl.addListener(_applyFilter);
  }

  /// Idara zinapakiwa DYNAMIC — idara mpya aliyoongeza admin inaonekana
  /// kwenye chips papo hapo (kabla ilikuwa hardcoded Afya/Elimu pekee).
  Future<void> _loadDepartments() async {
    try {
      final r = await ApiService().getDepartments();
      if (!mounted) return;
      final raw = r.data;
      setState(() => _departments = raw is List ? raw : (raw['departments'] ?? raw['data'] ?? []));
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminRealMatches();
      if (!mounted) return;
      final data = res.data;
      setState(() {
        // Backend inarudisha {total, matches: [...]} — 'results' haipo,
        // ndiyo sababu page ilikuwa tupu kila mara.
        _items = data is List ? data : ((data['matches'] ?? data['results']) as List? ?? []);
        _filtered = List.from(_items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _items.where((item) {
        final m = item as Map<String, dynamic>;
        final a = m['user_a'] as Map<String, dynamic>? ?? {};
        final b = m['user_b'] as Map<String, dynamic>? ?? {};
        final nameA = (a['full_name'] as String? ?? '').toLowerCase();
        final nameB = (b['full_name'] as String? ?? '').toLowerCase();
        final catA = (a['category'] as String? ?? '').toLowerCase();
        final matchQ = q.isEmpty || nameA.contains(q) || nameB.contains(q);
        final matchCat = _categoryFilter.isEmpty || catA == _categoryFilter.toLowerCase();
        return matchQ && matchCat;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.swap_horiz, color: _kBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Match za Kweli',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                    Text('Watu wanaotaka kubadilishana',
                        style: TextStyle(fontSize: 12, color: _kGrey500)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tafuta kwa jina...',
                prefixIcon: const Icon(Icons.search, color: _kGrey500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(label: 'Zote', selected: _categoryFilter.isEmpty,
                    onTap: () { setState(() { _categoryFilter = ''; }); _applyFilter(); }),
                for (final d in _departments) ...[
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '${d['name'] ?? d['code']}',
                    selected: _categoryFilter == '${d['code']}',
                    onTap: () {
                      setState(() => _categoryFilter = '${d['code']}');
                      _applyFilter();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _kGrey200),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: _kRed, size: 48),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Jaribu tena'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz, color: _kGrey500, size: 48),
                    const SizedBox(height: 12),
                    Text('Hakuna match za kweli', style: TextStyle(color: _kGrey500)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final match = _filtered[i] as Map<String, dynamic>;
                    final userA = match['user_a'] as Map<String, dynamic>? ?? {};
                    final userB = match['user_b'] as Map<String, dynamic>? ?? {};
                    return _RealMatchCard(userA: userA, userB: userB);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RealMatchCard extends StatelessWidget {
  final Map<String, dynamic> userA;
  final Map<String, dynamic> userB;
  const _RealMatchCard({required this.userA, required this.userB});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGreen, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _UserSide(user: userA)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Icon(Icons.swap_horiz, color: _kGreen, size: 28),
              ),
              Expanded(child: _UserSide(user: userB)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kGreenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: _kGreen, size: 14),
                const SizedBox(width: 6),
                Text('Inafanana kikamilifu',
                    style: TextStyle(fontSize: 12, color: _kGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSide extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserSide({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? '';
    final phone = user['phone_primary'] as String? ?? user['phone'] as String? ?? '';
    final region = user['current_region'] as String? ?? '';
    final category = user['category'] as String? ?? '';
    final cadre = user['cadre_display'] as String? ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final isHealth = category.toLowerCase() == 'health' || category.toLowerCase() == 'afya';
    final catColor = isHealth ? _kRed : _kGreen;
    final catBg = isHealth ? const Color(0xFFFEE2E2) : _kGreenBg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _kBlueBg,
          child: Text(initials,
              style: TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(height: 6),
        Text(name,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kGrey900),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        if (category.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(4)),
            child: Text(
                category == 'health'
                    ? 'Afya'
                    : category == 'education'
                        ? 'Elimu'
                        : category,
                style: TextStyle(fontSize: 9, color: catColor, fontWeight: FontWeight.w600)),
          ),
        ],
        if (cadre.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(cadre, style: TextStyle(fontSize: 10, color: _kGrey500),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        if (region.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined, size: 10, color: _kGrey500),
              Flexible(
                child: Text(region,
                    style: TextStyle(fontSize: 10, color: _kGrey500),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 6),
          // Namba ionekane WAZI (kama web) — sio kufichwa nyuma ya icon.
          SelectableText(
            phone,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: _kBlue, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ContactBtn(icon: Icons.phone_outlined, color: _kBlue,
                  onTap: () => _open(context, Uri.parse('tel:$phone'), phone)),
              const SizedBox(width: 4),
              _ContactBtn(icon: Icons.chat_outlined, color: _kGreen,
                  onTap: () => _open(
                        context,
                        Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '255')}'),
                        phone,
                      )),
            ],
          ),
        ],
      ],
    );
  }
}

/// Vitufe vya mawasiliano vilikuwa vikifanya copy pekee — mtumiaji
/// alibofya na hakuna kilichotokea. Sasa vinafungua app halisi ya simu.
Future<void> _open(BuildContext context, Uri uri, String phone) async {
  await Clipboard.setData(ClipboardData(text: phone));
  if (!context.mounted) return;
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Namba imenakiliwa'), backgroundColor: _kBlue),
    );
  }
}

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ContactBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kBlueBg : Colors.white,
          border: Border.all(color: selected ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? _kBlue : _kGrey700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
