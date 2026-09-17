import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);

class AdminDashboardPage extends StatefulWidget {
  /// Ruhusu AdminShell kumpa dashboard uwezo wa kubadilisha tab (index).
  final void Function(int index)? onNavigate;
  const AdminDashboardPage({super.key, this.onNavigate});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

/// Kadi moja ya "kurasa za admin" — ikibofywa inapeleka page husika.
class _AdminPageEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final int index;
  final Color color;
  final Color bg;
  const _AdminPageEntry(this.icon, this.label, this.subtitle, this.index, this.color, this.bg);
}

const _kPurple = Color(0xFF7C3AED);
const _kTeal   = Color(0xFF0D9488);

/// Kurasa zote za admin panel — dashboard inaonyesha hizi moja kwa moja
/// (kama web admin page: mtumiaji hahitaji kufungua drawer kufika page).
const List<_AdminPageEntry> _kAdminPages = [
  _AdminPageEntry(Icons.group_outlined, 'Watumiaji', 'Usajili, hali ya malipo', 1, _kBlue, _kBlueBg),
  _AdminPageEntry(Icons.person_search_outlined, 'Waliopata wenzao', 'Waliounganishwa na wenzao', 2, _kPurple, Color(0xFFF3E8FF)),
  _AdminPageEntry(Icons.swap_horiz_rounded, 'Match za kweli', 'Waliounganishwa kweli', 3, _kTeal, Color(0xFFCCFBF1)),
  _AdminPageEntry(Icons.bar_chart_outlined, 'Data', 'Mikoa, idara, kada, vituo', 4, _kBlue, _kBlueBg),
  _AdminPageEntry(Icons.notifications_none_rounded, 'Matangazo', 'Tuma taarifa kwa wote', 5, _kAmber, _kAmberBg),
  _AdminPageEntry(Icons.payments_outlined, 'Malipo', 'Thibitisha michango', 6, _kGreen, _kGreenBg),
  _AdminPageEntry(Icons.phone_in_talk_outlined, 'Waliopigiana', 'Historia ya simu', 7, _kBlue, _kBlueBg),
  _AdminPageEntry(Icons.assignment_outlined, 'Maoni', 'Malamiko na maoni', 8, _kAmber, _kAmberBg),
  _AdminPageEntry(Icons.assessment_outlined, 'Statistiki', 'Takwimu kwa mkoa na wilaya', 9, _kPurple, Color(0xFFF3E8FF)),
  _AdminPageEntry(Icons.monitor_heart_outlined, 'Ufuatiliaji', 'Hali ya mfumo', 10, _kTeal, Color(0xFFCCFBF1)),
  _AdminPageEntry(Icons.lock_reset_rounded, 'Kuweka upya nenosiri', 'Maombi ya wanachama', 11, _kRed, _kRedBg),
];

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<dynamic> _recent = [];
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminStats();
      if (!mounted) return;
      setState(() {
        _stats = (res.data as Map<String, dynamic>? ?? {});
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
    // Watumiaji wapya — jina + NAMBA (kama kwenye Match za Kweli, moja kwa moja).
    try {
      final r = await ApiService().adminUsers(params: {'limit': 8}, useCache: false);
      if (!mounted) return;
      final raw = r.data;
      final list = raw is List ? raw : (raw['users'] ?? raw['data'] ?? []) as List;
      setState(() => _recent = list);
    } catch (_) {}
    // Matukio ya hivi karibuni (kama web's RecentActivity)
    try {
      final r = await ApiService().adminEvents(limit: 6);
      if (!mounted) return;
      final d = r.data as Map? ?? {};
      setState(() => _events = (d['events'] as List?) ?? []);
    } catch (_) {}
  }

  Future<void> _dial(String phone) async {
    try {
      final ok = await launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack('Namba imenakiliwa');
    } catch (_) {
      if (mounted) _snack('Namba imenakiliwa');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _kBlue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = _stats['totals'] as Map<String, dynamic>? ?? {};
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: CustomScrollView(
          slivers: [
            // Header — web: flex items-center justify-between, h1 text-2xl font-bold + p text-sm + Live badge
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Panel',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _kGrey900)),
                          SizedBox(height: 4),
                          Text('Muhtasari wa mfumo',
                              style: TextStyle(fontSize: 14, color: _kGrey500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live badge — inline-flex items-center gap-1.5 text-[11px] font-bold px-2.5 py-1 rounded-full border
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: _kGrey200),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        // w-2 h-2 rounded-full bg-brand-grey-300
                        SizedBox(width: 8, height: 8,
                          child: DecoratedBox(decoration: BoxDecoration(
                            color: Color(0xFFD1D5DB), shape: BoxShape.circle))),
                        SizedBox(width: 6),
                        Text('Live',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey500)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _kRed, size: 48),
                      const SizedBox(height: 12),
                      Text('Kosa la kupakia data', style: TextStyle(color: _kGrey500)),
                      const SizedBox(height: 16),
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
            // 3 Big totals — web: grid grid-cols-2 md:grid-cols-3 gap-3
            // Big component: card (white bg, border, shadow), text-3xl font-bold colored, text-xs grey label, text-[10px] sub
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(children: [
                    Expanded(child: _BigCard(
                      value: '${totals['users'] ?? 0}',
                      label: 'Watumiaji',
                      color: _kBlue,
                      sub: '+${totals['users_active_7d'] ?? 0} wiki 7',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _BigCard(
                      value: '${totals['users_verified'] ?? 0}',
                      label: 'Wanaolipa',
                      color: _kAmber,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _BigCard(
                      value: '—',
                      label: 'Mikoa',
                      color: _kGreen,
                    )),
                  ]),
                ),
              ),
            // ── Matukio ya Hivi Karibuni ─────────────────────────────────
            if (!_loading && _error == null && _events.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kGrey200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.notifications_rounded, size: 15, color: _kGrey900),
                        const SizedBox(width: 6),
                        const Text('Matukio ya Hivi Karibuni',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900)),
                      ]),
                      const SizedBox(height: 10),
                      ..._events.take(6).map((e) {
                        final m = e as Map<String, dynamic>;
                        final type = m['event_type'] as String? ?? '';
                        final time = m['occurred_at'] as String? ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: _kGrey200, width: 0.5))),
                          child: Row(children: [
                            _eventIcon(type),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_eventTitle(type),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _kGrey700),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 6),
                            Text(_fmtTime(time),
                                style: const TextStyle(fontSize: 10, color: _kGrey400)),
                          ]),
                        );
                      }),
                    ]),
                  ),
                ),
              ),

            // ── KURASA ZA ADMIN ──────────────────────────────────────
            // Pages zote za panel ziko hapa moja kwa moja — hakuna
            // kufungua drawer kwanza. Kila kadi inabofya → inapeleka page.
            if (!_loading && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.grid_view_rounded, size: 16, color: _kBlue),
                        const SizedBox(width: 6),
                        Text('Kurasa za Admin',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                      ]),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _kAdminPages.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.35,
                        ),
                        itemBuilder: (ctx, i) {
                          final p = _kAdminPages[i];
                          return GestureDetector(
                            onTap: widget.onNavigate == null
                                ? null
                                : () => widget.onNavigate!(p.index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kGrey200),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: p.bg,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(p.icon, size: 17, color: p.color),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(p.label,
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey900),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(p.subtitle,
                                          style: const TextStyle(fontSize: 9.5, color: _kGrey500),
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF9CA3AF)),
                              ]),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Watumiaji wapya + NAMBA zao — admin anaona mara moja bila
            // kubofya kitu chochote (kama Match za Kweli / Maoni).
            if (!_loading && _recent.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.person_add_alt_1_outlined, size: 16, color: _kBlue),
                        const SizedBox(width: 6),
                        Text('Watumiaji wapya',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                      ]),
                      const SizedBox(height: 8),
                      ..._recent.map(_recentRow),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recentRow(dynamic u) {
    final m = u as Map<String, dynamic>;
    final name = (m['full_name'] ?? '') as String;
    final phone = (m['phone_primary'] ?? m['phone'] ?? '') as String;
    final cadre = (m['cadre_display'] ?? m['cadre_code'] ?? '') as String;
    final station = (m['current_station'] as Map?) ?? {};
    final region = (station['region_name'] ?? station['region'] ?? '') as String;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final paid = (m['is_verified'] as bool?) ?? (m['is_paid'] as bool?) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _kBlueBg,
          child: Text(initial,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kBlue)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900),
                overflow: TextOverflow.ellipsis),
            if (phone.isNotEmpty)
              Text(phone, style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w600)),
            if (cadre.isNotEmpty || region.isNotEmpty)
              Text([cadre, region].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 10, color: _kGrey500),
                  overflow: TextOverflow.ellipsis),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(paid ? '✓' : '✗',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: paid ? const Color(0xFF16A34A) : const Color(0xFFDC2626))),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: phone.isEmpty ? null : () => _dial(phone),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: _kGrey200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.phone_outlined,
                size: 15, color: phone.isEmpty ? _kGrey200 : _kBlue),
          ),
        ),
      ]),
    );
  }

  static Widget _eventIcon(String type) {
    const s = 14.0;
    if (type == 'user.registered') {
      return const Icon(Icons.person_add_rounded, size: s, color: Color(0xFF3B82F6));
    }
    if (type.startsWith('payment.')) {
      return const Icon(Icons.payments_rounded, size: s, color: Color(0xFF16A34A));
    }
    if (type.startsWith('feedback.')) {
      return const Icon(Icons.assignment_rounded, size: s, color: Color(0xFFF97316));
    }
    if (type.startsWith('password_reset.')) {
      return const Icon(Icons.lock_reset_rounded, size: s, color: Color(0xFF7C3AED));
    }
    if (type.startsWith('match.')) {
      return const Icon(Icons.favorite_rounded, size: s, color: Color(0xFF16A34A));
    }
    if (type == 'data.changed' || type.startsWith('data.')) {
      return const Icon(Icons.bolt_rounded, size: s, color: Color(0xFFF59E0B));
    }
    return const Icon(Icons.notifications_rounded, size: s, color: Color(0xFF9CA3AF));
  }

  static String _eventTitle(String type) {
    switch (type) {
      case 'user.registered': return 'Mtumiaji mpya amejiunga';
      case 'payment.submitted': return 'Malipo yamewasilishwa';
      case 'payment.approved': return 'Malipo yamekubaliwa';
      case 'payment.rejected': return 'Malipo yamekataliwa';
      case 'feedback.new': return 'Maoni mapya';
      case 'feedback.replied': return 'Maoni yamejibiwa';
      case 'match.found': return 'Match mpya imepatikana';
      case 'data.changed': return 'Data imebadilishwa';
      case 'password_reset.requested': return 'Ombi la kubadilisha nenosiri';
      default: return type.replaceAll('.', ' ').replaceAll('_', ' ');
    }
  }

  static String _fmtTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

/// Big card — kama web `Big` component:
/// card class (white bg, border, shadow), text-3xl (30px) font-bold colored value,
/// text-xs (12px) text-grey-500 label, text-[10px] text-grey-400 sub.
class _BigCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final String? sub;

  const _BigCard({
    required this.value,
    required this.label,
    required this.color,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGrey200),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // text-3xl font-bold
        Text(value,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        // text-xs text-grey-500
        Text(label,
            style: const TextStyle(fontSize: 12, color: _kGrey500)),
        if (sub != null) ...[
          const SizedBox(height: 2),
          // text-[10px] text-grey-400
          Text(sub!,
              style: const TextStyle(fontSize: 10, color: _kGrey400)),
        ],
      ]),
    );
  }
}
