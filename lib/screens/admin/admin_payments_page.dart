import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────
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
const _kGrey300 = Color(0xFFD1D5DB);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey50  = Color(0xFFF9FAFB);
const _kHero1   = Color(0xFF0F3D73);
const _kHero2   = Color(0xFF1D6FBF);
const _kBlue2   = Color(0xFF378ADD);

const _kPageSize = 10;

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _fmtAmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Jan','Feb','Mac','Apr','Mei','Jun',
                    'Jul','Ago','Sep','Okt','Nov','Des'];
    final h = dt.hour.toString().padLeft(2,'0');
    final m = dt.minute.toString().padLeft(2,'0');
    return '${dt.day} ${months[dt.month-1]} ${dt.year}, $h:$m';
  } catch (_) { return iso; }
}

({Color color, Color bg, String label, IconData icon}) _statusStyle(String s) {
  switch (s) {
    case 'approved':
      return (color: _kGreen, bg: _kGreenBg,
              label: 'Imeidhinishwa',
              icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill));
    case 'rejected':
      return (color: _kRed, bg: _kRedBg,
              label: 'Imekataliwa',
              icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill));
    case 'verifying':
      return (color: _kBlue, bg: _kBlueBg,
              label: 'Inathibitishwa',
              icon: PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.fill));
    default:
      return (color: _kAmber, bg: _kAmberBg,
              label: 'Inasubiri',
              icon: PhosphorIcons.clock(PhosphorIconsStyle.fill));
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  String? _error;
  String _status = 'pending';
  int _page = 0;
  final Map<String, List<dynamic>> _cache = {};

  static const _tabs = [
    ('pending',  'Inasubiri',    _kAmber),
    ('approved', 'Imeidhinishwa', _kGreen),
    ('rejected', 'Imekataliwa',  _kRed),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus('pending');
  }

  Future<void> _loadStatus(String status) async {
    if (_cache.containsKey(status)) {
      setState(() { _status = status; _page = 0; });
      return;
    }
    setState(() { _loading = true; _error = null; _status = status; _page = 0; });
    try {
      final res = await ApiService().adminAllDonations(status: status);
      if (!mounted) return;
      final data = res.data;
      _cache[status] = data is List ? data : (data['results'] as List? ?? []);
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _approve(String orderId) async {
    try {
      await ApiService().adminApproveDonation(orderId);
      if (!mounted) return;
      _cache.remove('pending'); _cache.remove('approved');
      _showSnack('Imelipwa na kuidhinishwa!', _kGreen);
      await _loadStatus('pending');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _kRed);
    }
  }

  Future<void> _reject(String orderId) async {
    try {
      await ApiService().adminRejectDonation(orderId);
      if (!mounted) return;
      _cache.remove('pending'); _cache.remove('rejected');
      _showSnack('Ilikataliwa', _kAmber);
      await _loadStatus('pending');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _kRed);
    }
  }

  Future<void> _sendReply(String orderId, String msg) async {
    try {
      await ApiService().adminPaymentReply(orderId, msg);
      if (!mounted) return;
      _showSnack('Ujumbe umetumwa', _kGreen);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _kRed);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  int _count(String s) => _cache[s]?.length ?? 0;

  String _fmtTotal() {
    final list = _cache['approved'] ?? [];
    double total = 0;
    for (final item in list) {
      total += ((item as Map)['amount'] as num?)?.toDouble() ?? 0;
    }
    if (total >= 1000000) return 'TZS ${(total / 1000000).toStringAsFixed(1)}M';
    if (total >= 1000)    return 'TZS ${(total / 1000).toStringAsFixed(0)}K';
    return 'TZS ${total.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _cache[_status] ?? [];
    final totalPages = (items.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems = _loading || _error != null
        ? <dynamic>[]
        : items.skip(_page * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          _cache.remove(_status);
          await _loadStatus(_status);
        },
        color: _kBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // ── HERO ya gradient ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kHero1, _kHero2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(PhosphorIcons.wallet(PhosphorIconsStyle.fill),
                            color: Colors.white, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Malipo',
                              style: GoogleFonts.inter(
                                  fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                          Text('Simamia michango ya watumiaji',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text('LIVE',
                              style: GoogleFonts.inter(
                                  fontSize: 10.5, fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8, color: Colors.white)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // ── Stat cards ───────────────────────────────────────────
                    Row(children: [
                      Expanded(child: _StatCard(
                        icon: PhosphorIcons.trendUp(PhosphorIconsStyle.fill),
                        label: 'Jumla Iliyolipwa',
                        value: _fmtTotal(),
                        colors: const [_kGreen, Color(0xFF34D399)],
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        icon: PhosphorIcons.clock(PhosphorIconsStyle.fill),
                        label: 'Yanasubiri',
                        value: '${_count('pending')}',
                        colors: const [_kAmber, Color(0xFFFBBF24)],
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        icon: PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                        label: 'Kuonyesha',
                        value: '${items.length}',
                        colors: const [_kBlue, _kBlue2],
                      )),
                    ]),
                    const SizedBox(height: 16),

                    // ── Tab filter ───────────────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _tabs.map((t) {
                          final (slug, label, color) = t;
                          final active = _status == slug;
                          Color tabBg;
                          switch (slug) {
                            case 'approved': tabBg = _kGreenBg; break;
                            case 'rejected': tabBg = _kRedBg;   break;
                            default:         tabBg = _kAmberBg;
                          }
                          return GestureDetector(
                            onTap: () => _loadStatus(slug),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: active ? tabBg : Colors.white,
                                border: Border.all(
                                    color: active ? color : _kGrey200),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(label,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: active ? color : _kGrey500,
                                    )),
                                if (_count(slug) > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: active ? color : _kGrey200,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('${_count(slug)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: active ? Colors.white : _kGrey500,
                                        )),
                                  ),
                                ],
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: const BoxDecoration(
                          color: _kRedBg, shape: BoxShape.circle),
                      child: Icon(PhosphorIcons.wifiX(PhosphorIconsStyle.fill),
                          color: _kRed, size: 30),
                    ),
                    const SizedBox(height: 14),
                    Text('Imeshindikana kupakia',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: _kGrey700)),
                    const SizedBox(height: 6),
                    Text('Angalia muunganiko wako wa mtandao',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _kGrey400)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        _cache.remove(_status);
                        _loadStatus(_status);
                      },
                      icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
                      label: Text('Jaribu tena',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(
                          color: _kAmberBg, shape: BoxShape.circle),
                      child: Icon(PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                          color: _kAmber, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text('Hakuna malipo',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: _kGrey700)),
                    const SizedBox(height: 6),
                    Text(_status == 'pending'
                        ? 'Hakuna malipo yanayosubiri sasa hivi'
                        : _status == 'approved'
                            ? 'Hakuna malipo yaliyoidhinishwa'
                            : 'Hakuna malipo yaliyokataliwa',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _kGrey400)),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () {
                        _cache.remove(_status);
                        _loadStatus(_status);
                      },
                      icon: Icon(PhosphorIcons.arrowClockwise(), size: 14),
                      label: Text('Onyesha upya',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kBlue,
                        side: const BorderSide(color: _kBlue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _PaymentCard(
                      key: ValueKey(pageItems[i]['id'] ?? i),
                      item: pageItems[i] as Map<String, dynamic>,
                      status: _status,
                      onApprove: _approve,
                      onReject: _reject,
                      onReply: _sendReply,
                    ),
                    childCount: pageItems.length,
                  ),
                ),
              ),

            // ── Pagination ────────────────────────────────────────────────────
            if (!_loading && _error == null && totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  child: Center(
                    child: Wrap(spacing: 6, children: [
                      _PgBtn(
                        icon: PhosphorIcons.caretLeft(),
                        enabled: _page > 0,
                        onTap: _page > 0 ? () => setState(() => _page--) : null,
                      ),
                      ...List.generate(totalPages, (i) => _PgNum(
                        n: i + 1,
                        active: _page == i,
                        onTap: () => setState(() => _page = i),
                      )),
                      _PgBtn(
                        icon: PhosphorIcons.caretRight(),
                        enabled: _page < totalPages - 1,
                        onTap: _page < totalPages - 1
                            ? () => setState(() => _page++)
                            : null,
                      ),
                    ]),
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> colors;
  const _StatCard({
    required this.icon, required this.label,
    required this.value, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGrey200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors,
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w800, color: _kGrey900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(fontSize: 10.5, color: _kGrey400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String status;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;
  final Future<void> Function(String, String) onReply;

  const _PaymentCard({
    super.key,
    required this.item, required this.status,
    required this.onApprove, required this.onReject, required this.onReply,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _showSms  = false;
  bool _showChat = false;
  bool _approving = false;
  bool _rejecting = false;
  bool _sending   = false;
  final _replyCtrl = TextEditingController();

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final item      = widget.item;
    final orderId   = item['order_id']?.toString() ?? item['id']?.toString() ?? '';
    final amount    = (item['amount'] as num?)?.toInt() ?? 0;
    final name      = item['user_name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
    final phone     = item['phone'] as String? ?? item['phone_primary'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final smsText   = item['sms_text'] as String? ?? '';
    final messages  = (item['messages'] as List?) ?? [];
    final isPending = widget.status == 'pending' || widget.status == 'verifying';
    final ss        = _statusStyle(widget.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Top stripe: colored left border accent ─────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _kBlueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(PhosphorIcons.user(PhosphorIconsStyle.fill),
                    color: _kBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          fontSize: 14.5, fontWeight: FontWeight.w700,
                          color: _kGrey900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (phone.isNotEmpty)
                    Row(children: [
                      Icon(PhosphorIcons.phone(PhosphorIconsStyle.fill),
                          size: 11, color: _kGrey400),
                      const SizedBox(width: 4),
                      Text(phone,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _kGrey400)),
                    ]),
                ]),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ss.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ss.icon, size: 12, color: ss.color),
                  const SizedBox(width: 5),
                  Text(ss.label,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: ss.color)),
                ]),
              ),
            ],
          ),
        ),

        // Divider
        Container(height: 1, color: _kGrey100),

        // ── Amount section ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kiasi',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _kGrey400,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                    Text('TZS ',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _kGrey500)),
                    Text(_fmtAmt(amount),
                        style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: _kGrey900)),
                  ]),
                ]),
              ),
              if (orderId.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGrey50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kGrey200),
                  ),
                  child: Text(
                    orderId.length > 16
                        ? '${orderId.substring(0, 16)}…'
                        : orderId,
                    style: GoogleFonts.inter(
                        fontSize: 10.5, color: _kGrey500,
                        fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),

        // ── Date + meta ────────────────────────────────────────────────────
        if (createdAt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Icon(PhosphorIcons.calendarBlank(), size: 13, color: _kGrey400),
              const SizedBox(width: 5),
              Text(_fmtDate(createdAt),
                  style: GoogleFonts.inter(fontSize: 11.5, color: _kGrey400)),
            ]),
          ),

        // Divider
        Container(height: 1, color: _kGrey100),

        // ── Action buttons ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Approve / Reject row (pending only)
              if (isPending) ...[
                Row(children: [
                  Expanded(
                    child: _ActionBtn(
                      label: 'Idhinisha',
                      icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      bg: _kGreen,
                      loading: _approving,
                      onTap: () async {
                        setState(() => _approving = true);
                        await widget.onApprove(orderId);
                        if (mounted) setState(() => _approving = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Kataa',
                      icon: PhosphorIcons.xCircle(PhosphorIconsStyle.fill),
                      color: _kRed,
                      bg: _kRedBg,
                      loading: _rejecting,
                      onTap: () async {
                        setState(() => _rejecting = true);
                        await widget.onReject(orderId);
                        if (mounted) setState(() => _rejecting = false);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
              ],

              // Secondary action pills
              Row(children: [
                if (smsText.isNotEmpty)
                  _Pill(
                    icon: PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill),
                    label: _showSms ? 'Ficha SMS' : 'SMS',
                    active: _showSms,
                    onTap: () => setState(() => _showSms = !_showSms),
                  ),
                if (smsText.isNotEmpty) const SizedBox(width: 8),
                _Pill(
                  icon: PhosphorIcons.chatDots(PhosphorIconsStyle.fill),
                  label: messages.isNotEmpty
                      ? 'Mazungumzo (${messages.length})'
                      : 'Mazungumzo',
                  active: _showChat,
                  onTap: () => setState(() => _showChat = !_showChat),
                ),
              ]),

              // SMS content
              if (_showSms && smsText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kGrey50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kGrey200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(PhosphorIcons.deviceMobile(PhosphorIconsStyle.fill),
                          size: 13, color: _kGrey500),
                      const SizedBox(width: 6),
                      Text('Maelezo ya SMS',
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: _kGrey500, letterSpacing: 0.4)),
                    ]),
                    const SizedBox(height: 8),
                    Text(smsText,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: _kGrey700, height: 1.5)),
                  ]),
                ),
              ],

              // Chat section
              if (_showChat) ...[
                const SizedBox(height: 12),
                if (messages.isNotEmpty) ...[
                  ...messages.map((msg) {
                    final m = msg as Map<String, dynamic>;
                    final isAdmin = m['sender'] == 'admin';
                    return Align(
                      alignment:
                          isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.68,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin ? _kBlueBg : _kGrey100,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: Radius.circular(isAdmin ? 12 : 2),
                            bottomRight: Radius.circular(isAdmin ? 2 : 12),
                          ),
                        ),
                        child: Text(
                          m['message'] as String? ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isAdmin ? _kBlue : _kGrey700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Andika ujumbe...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13, color: _kGrey400),
                        filled: true,
                        fillColor: _kGrey50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kGrey200)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kGrey200)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _kBlue, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _sending
                          ? null
                          : () async {
                              final text = _replyCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() => _sending = true);
                              await widget.onReply(orderId, text);
                              if (mounted) {
                                _replyCtrl.clear();
                                setState(() => _sending = false);
                              }
                            },
                      child: SizedBox(
                        width: 44, height: 44,
                        child: Center(
                          child: _sending
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Icon(
                                  PhosphorIcons.paperPlaneTilt(
                                      PhosphorIconsStyle.fill),
                                  color: Colors.white,
                                  size: 18),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Action button (green Idhinisha / red Kataa) ──────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool loading;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label, required this.icon,
    required this.color, required this.bg,
    required this.onTap, this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (loading)
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2))
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ─── Secondary pill button ────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kBlueBg : _kGrey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kBlue : _kGrey200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13,
              color: active ? _kBlue : _kGrey500),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: active ? _kBlue : _kGrey500)),
        ]),
      ),
    );
  }
}

// ─── Pagination ───────────────────────────────────────────────────────────────

class _PgNum extends StatelessWidget {
  final int n; final bool active; final VoidCallback onTap;
  const _PgNum({required this.n, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text('$n',
            style: GoogleFonts.inter(
                fontSize: 12.5, fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kGrey500)),
      ),
    );
  }
}

class _PgBtn extends StatelessWidget {
  final IconData icon; final bool enabled; final VoidCallback? onTap;
  const _PgBtn({required this.icon, required this.enabled, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? _kGrey200 : _kGrey100),
        ),
        child: Icon(icon, size: 14, color: enabled ? _kGrey700 : _kGrey300),
      ),
    );
  }
}
