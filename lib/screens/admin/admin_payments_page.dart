// MALIPO — uthibitisho wa michango (esstranfer.com style)
// ─────────────────────────────────────────────────────────────────────────────
// DATA ILIKUWA HAITOKI KWA SABABU MBILI (zimerekebishwa):
//   1. Backend GET /payments/admin/all inarudisha {"payments": [...],
//      "counts": {...}, "total_approved_tzs": N} — app ilikuwa inasoma
//      data['results'] isiyoipo → orodha ilibaki tupu kabisa.
//   2. Status za backend ni "verifying"/"approved"/"rejected" — app ilikuwa
//      inauliza "pending" isiyoipo → hata data ingekuwa, tab ya kwanza tupu.
// Sasa: data moja inapakiwa mara moja (payments + counts + jumla), kichujio
// cha hali kinafanyika upande wa app, na design ni ya esstranfer.com
// (background nyeupe, kadi grey, namba bluu/chungwa).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _cBlue     = Color(0xFF1959D6);
const _cBlueBg   = Color(0xFFEAF1FF);
const _cBg       = Colors.white;
const _cCardBg   = Color(0xFFF7F8FA);
const _cBorder   = Color(0xFFECEEF1);
const _cTextDark = Color(0xFF16181D);
const _cTextGrey = Color(0xFF6B7280);
const _cFaint    = Color(0xFF9CA3AF);
const _cGreen    = Color(0xFF15803D);
const _cGreenBg  = Color(0xFFDCFCE7);
const _cRed      = Color(0xFFDC2626);
const _cRedBg    = Color(0xFFFEE2E2);
const _cAmber    = Color(0xFFB45309);
const _cAmberBg  = Color(0xFFFEF3C7);
const _cLiveGreen = Color(0xFF16A34A);

const _kPageSize = 10;

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDate(dynamic iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse('$iso').toLocal();
    return '${_two(d.day)}/${_two(d.month)}/${d.year}, ${_two(d.hour)}:${_two(d.minute)}';
  } catch (_) {
    return '';
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _counts = {};
  int _totalApprovedTzs = 0;

  String _status = 'verifying'; // backend: verifying | approved | rejected
  int _page = 0;
  final Set<String> _smsOpen = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ── DATA: /payments/admin/all → {payments, counts, total_approved_tzs} ────
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminAllDonations();
      if (!mounted) return;
      final d = res.data;
      final map = d is Map ? d : <String, dynamic>{};
      final list = (d is List ? d : (map['payments'] ?? map['results'] ?? [])) as List;
      final c = map['counts'];
      setState(() {
        _payments = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _counts = c is Map ? c.cast<String, dynamic>() : {};
        _totalApprovedTzs = (map['total_approved_tzs'] as num?)?.toInt() ?? 0;
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _payments.where((p) => '${p['status'] ?? ''}' == _status).toList();

  int get _totalPages => _filtered.isEmpty ? 1 : (_filtered.length / _kPageSize).ceil();
  int get _safePage => _page.clamp(0, _totalPages - 1);

  void _goToPage(int p) {
    setState(() => _page = p.clamp(0, _totalPages - 1));
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ── Vitendo (dialog ya uthibitisho kwa pesa) ───────────────────────────────
  Future<bool> _ask({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(body, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: danger ? _cRed : _cBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _approve(Map<String, dynamic> p) async {
    final ok = await _ask(
      title: 'Thibitisha malipo?',
      body: 'Hakikisha pesa imefika kwenye simu yako kabla ya kuthibitisha. '
          'Ukithibitisha, mtumiaji ataweza kuona namba za wenzake.',
      action: 'Thibitisha',
    );
    if (!ok) return;
    try {
      await ApiService().adminApproveDonation('${p['order_id']}');
      if (!mounted) return;
      _showSnack('Malipo yamethibitishwa ✓', _cGreen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _cRed);
    }
  }

  Future<void> _reject(Map<String, dynamic> p) async {
    final ok = await _ask(
      title: 'Kataa malipo?',
      body: 'Mchangiaji ataarifiwa kuwa malipo yake yamekataliwa.',
      action: 'Kataa',
      danger: true,
    );
    if (!ok) return;
    try {
      await ApiService().adminRejectDonation('${p['order_id']}');
      if (!mounted) return;
      _showSnack('Malipo yamekataliwa', _cAmber);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _cRed);
    }
  }

  Future<void> _sendReply(String orderId, String msg) async {
    try {
      await ApiService().adminPaymentReply(orderId, msg);
      if (!mounted) return;
      _showSnack('Ujumbe umetumwa ✓', _cGreen);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _cRed);
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$what imenakiliwa', _cTextDark);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageItems = filtered.skip(_safePage * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: _cBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _cBlue,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            // ── Title + LIVE ──
            Row(children: [
              const Expanded(
                child: Text('Malipo',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800, color: _cTextDark)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8, color: _cLiveGreen),
                  SizedBox(width: 6),
                  Text('Live',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _cGreen)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Thibitisha michango ya watumiaji (TigoPesa, M-Pesa, Airtel...)',
                style: TextStyle(fontSize: 14, color: _cTextGrey)),
            const SizedBox(height: 16),

            // ── Jumla iliyothibitishwa (kadi kuu ya grey) ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cCardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: _cBlueBg, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.trending_up_rounded, color: _cBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TZS ${_fmt(_totalApprovedTzs)}',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800, color: _cBlue)),
                    const Text('Jumla ya michango iliyothibitishwa',
                        style: TextStyle(fontSize: 12.5, color: _cTextGrey)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Counts: Inasubiri / Imeidhinishwa / Imekataliwa ──
            Row(children: [
              Expanded(child: _miniStat('Inasubiri', _countOf('verifying'), _cAmber, _cAmberBg,
                  Icons.hourglass_top_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _miniStat('Imeidhinishwa', _countOf('approved'), _cGreen, _cGreenBg,
                  Icons.check_circle_outline_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _miniStat('Imekataliwa', _countOf('rejected'), _cRed, _cRedBg,
                  Icons.cancel_outlined)),
            ]),
            const SizedBox(height: 16),

            // ── Filter chips ──
            Wrap(spacing: 8, runSpacing: 8, children: [
              _statusChip('verifying', 'Inasubiri', Icons.hourglass_top_rounded, _cAmber),
              _statusChip('approved', 'Imeidhinishwa', Icons.check_circle_outline_rounded, _cGreen),
              _statusChip('rejected', 'Imekataliwa', Icons.cancel_outlined, _cRed),
            ]),
            const SizedBox(height: 14),

            Text('Inaonyesha ${pageItems.length} kati ya ${filtered.length}',
                style: const TextStyle(fontSize: 13, color: _cTextGrey)),
            const SizedBox(height: 10),

            // ── Body ──
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: _cBlue)),
              )
            else if (_error != null)
              _errorCard()
            else if (filtered.isEmpty)
              _emptyCard()
            else ...[
              for (final p in pageItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PaymentCard(
                    p: p,
                    smsOpen: _smsOpen.contains('${p['order_id']}'),
                    onToggleSms: () => setState(() {
                      final id = '${p['order_id']}';
                      _smsOpen.contains(id) ? _smsOpen.remove(id) : _smsOpen.add(id);
                    }),
                    onCopy: _copy,
                    onApprove: () => _approve(p),
                    onReject: () => _reject(p),
                    onChat: () => _openChat(p),
                  ),
                ),
              _pager(),
            ],
          ],
        ),
      ),
    );
  }

  int _countOf(String s) => (_counts[s] as num?)?.toInt() ?? 0;

  Widget _miniStat(String label, int n, Color fg, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cCardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: fg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _cTextDark)),
            Text(label,
                style: const TextStyle(fontSize: 11.5, color: _cTextGrey),
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ]),
        ),
      ]),
    );
  }

  Widget _statusChip(String slug, String label, IconData icon, Color color) {
    final active = _status == slug;
    final count = _countOf(slug);
    return GestureDetector(
      onTap: () => setState(() { _status = slug; _page = 0; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color : _cBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : _cBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : color),
          const SizedBox(width: 6),
          Text('$label ($count)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : _cTextDark)),
        ]),
      ),
    );
  }

  Widget _pager() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    final p = _safePage;
    final total = _totalPages;
    final start = (p - 2).clamp(0, (total - 5).clamp(0, 1 << 31));
    final end = (start + 5).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.outlined(
          onPressed: p > 0 ? () => _goToPage(p - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (var i = start; i < end; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _goToPage(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == p ? _cBlue : _cBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: i == p ? _cBlue : _cBorder),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: i == p ? Colors.white : _cTextDark)),
              ),
            ),
          ),
        IconButton.outlined(
          onPressed: p < total - 1 ? () => _goToPage(p + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: _cBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
      ),
      child: Column(children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: _cFaint),
        const SizedBox(height: 12),
        const Text('Imeshindikana kupakia malipo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _cTextDark)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Jaribu tena', style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(backgroundColor: _cBlue),
        ),
      ]),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: BoxDecoration(
        color: _cBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
      ),
      child: Column(children: [
        const Icon(Icons.payments_outlined, size: 40, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        Text(
          _status == 'verifying'
              ? 'Hakuna malipo yanayosubiri uthibitisho wako kwa sasa.'
              : 'Hakuna malipo katika hali hii kwa sasa.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _cTextGrey, fontSize: 14.5),
        ),
      ]),
    );
  }

  // ── Chat na mchangiaji (bottom sheet) ──────────────────────────────────────
  void _openChat(Map<String, dynamic> p) {
    final orderId = '${p['order_id']}';
    final msgs = ((p['messages'] as List?) ?? [])
        .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(children: [
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Ongea na mchangiaji',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _cTextGrey, letterSpacing: .4)),
                  Text('${p['user_name'] ?? '—'}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: _cTextDark)),
                ]),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const Divider(height: 1, color: _cBorder),
            Expanded(
              child: msgs.isEmpty
                  ? const Center(
                      child: Text('Hakuna ujumbe bado. Andika ujumbe wa kwanza.',
                          style: TextStyle(color: _cTextGrey)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final fromAdmin =
                            '${m['from'] ?? m['sender'] ?? ''}'.contains('admin');
                        return Align(
                          alignment: fromAdmin
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(ctx).size.width * .75),
                            decoration: BoxDecoration(
                              color: fromAdmin ? _cBlue : _cCardBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text('${m['text'] ?? m['message'] ?? ''}',
                                style: TextStyle(
                                    color: fromAdmin ? Colors.white : _cTextDark,
                                    height: 1.4)),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      Navigator.pop(ctx);
                      await _sendReply(orderId, text);
                    },
                    decoration: InputDecoration(
                      hintText: 'Andika jibu kwa mchangiaji...',
                      filled: true,
                      fillColor: _cCardBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _cBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _cBorder)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    await _sendReply(orderId, text);
                  },
                  style: IconButton.styleFrom(backgroundColor: _cBlue),
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══ PAYMENT CARD ════════════════════════════════════════════════════════════
class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final bool smsOpen;
  final VoidCallback onToggleSms;
  final void Function(String text, String what) onCopy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onChat;

  const _PaymentCard({
    required this.p,
    required this.smsOpen,
    required this.onToggleSms,
    required this.onCopy,
    required this.onApprove,
    required this.onReject,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final name = '${p['user_name'] ?? ''}';
    final phone = '${p['phone'] ?? ''}';
    final amount = (p['amount'] as num?)?.toInt() ?? 0;
    final status = '${p['status'] ?? ''}';
    final sms = '${p['sms_text'] ?? ''}';
    final note = '${p['note'] ?? ''}';
    final expired = p['expired'] == true;
    final orderId = '${p['order_id'] ?? ''}';

    final (stLabel, stFg, stBg) = switch (status) {
      'approved'  => ('Imeidhinishwa', _cGreen, _cGreenBg),
      'rejected'  => ('Imekataliwa', _cRed, _cRedBg),
      _           => (expired ? 'Muda umeisha' : 'Inasubiri', _cAmber, _cAmberBg),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0A16181D), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Avatar + jina + status ──
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _cBlueBg,
            child: Text(_initials(name),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: _cBlue, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? '(bila jina)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _cTextDark)),
              const SizedBox(height: 2),
              if (phone.isNotEmpty)
                Text(phone,
                    style: const TextStyle(
                        fontSize: 12.5, color: _cBlue, fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: stBg, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(status == 'approved'
                      ? Icons.check_circle_outline_rounded
                      : status == 'rejected'
                          ? Icons.cancel_outlined
                          : Icons.hourglass_top_rounded,
                  size: 12, color: stFg),
              const SizedBox(width: 4),
              Text(stLabel,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: stFg)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Kiasi + order id ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _cCardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Text('TZS ${_fmt(amount)}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _cTextDark)),
            const Spacer(),
            GestureDetector(
              onTap: () => onCopy(orderId, 'Order ID'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(orderId.length > 10 ? '${orderId.substring(0, 10)}…' : orderId,
                    style: const TextStyle(
                        fontSize: 11.5, color: _cTextGrey, fontFamily: 'monospace')),
                const SizedBox(width: 5),
                const Icon(Icons.copy_rounded, size: 13, color: _cTextGrey),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Tarehe + simu ──
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 15, color: _cTextGrey),
          const SizedBox(width: 5),
          Text(_fmtDate(p['created_at']),
              style: const TextStyle(fontSize: 12.5, color: _cTextGrey)),
          if (phone.isNotEmpty) ...[
            const SizedBox(width: 14),
            const Icon(Icons.phone_outlined, size: 14, color: _cTextGrey),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => onCopy(phone, 'Namba'),
              child: Text(phone,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: _cTextDark)),
            ),
          ],
        ]),

        // ── SMS ya mchangiaji (expandable) ──
        if (sms.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onToggleSms,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _cCardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(smsOpen ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 15, color: _cTextGrey),
                const SizedBox(width: 7),
                Text(smsOpen ? 'Ficha SMS' : 'Ona SMS ya mchangiaji',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: _cTextDark)),
                const Spacer(),
                Icon(smsOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 17, color: _cTextGrey),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: smsOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cCardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _cBorder),
                      ),
                      child: SelectableText(sms,
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.55,
                              color: _cTextDark, fontFamily: 'monospace')),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],

        // ── Note ya mfumo ──
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: _cAmber),
            const SizedBox(width: 6),
            Expanded(
              child: Text(note,
                  style: const TextStyle(fontSize: 12.5, color: _cAmber)),
            ),
          ]),
        ],

        // ── Vitendo ──
        const SizedBox(height: 12),
        if (status == 'verifying') ...[
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Thibitisha',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: _cGreen,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Kataa',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cRed,
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: _cBlue),
            label: const Text('Ongea na mchangiaji',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _cBlue)),
            style: OutlinedButton.styleFrom(
              backgroundColor: _cBlueBg,
              side: BorderSide.none,
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }
}
