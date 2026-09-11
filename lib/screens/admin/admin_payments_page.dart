import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E40AF);
const _kBlue50   = Color(0xFFEFF6FF);
const _kBlue200  = Color(0xFFBFDBFE);
const _kGrey50   = Color(0xFFF9FAFB);
const _kGrey100  = Color(0xFFF3F4F6);
const _kGrey200  = Color(0xFFE5E7EB);
const _kGrey300  = Color(0xFFD1D5DB);
const _kGrey400  = Color(0xFF9CA3AF);
const _kGrey500  = Color(0xFF6B7280);
const _kGrey700  = Color(0xFF374151);
const _kGrey900  = Color(0xFF111827);
const _kGreen50  = Color(0xFFF0FDF4);
const _kGreen200 = Color(0xFFBBF7D0);
const _kGreenDk  = Color(0xFF16A34A);
const _kGreen700 = Color(0xFF15803D);
const _kRed      = Color(0xFFDC2626);
const _kRed50    = Color(0xFFFEF2F2);
const _kRed200   = Color(0xFFFECACA);
const _kAmber50  = Color(0xFFFFFBEB);
const _kAmber200 = Color(0xFFFDE68A);
const _kAmber700 = Color(0xFFB45309);
const _kOrange   = Color(0xFFF97316);
const _kOrange700 = Color(0xFFC2410C);

const _kPageSize = 8;

// ── Helpers ────────────────────────────────────────────────────────────────
String _fmtNum(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
  return n.toStringAsFixed(0);
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  '
           '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  } catch (_) { return iso.split('T').first; }
}

String _errDetail(Object e) {
  try {
    final d = (e as dynamic).response?.data?['detail'];
    return d is String ? d : 'Imeshindikana';
  } catch (_) { return 'Imeshindikana'; }
}

Color _avatarColor(String name) {
  const colors = [Color(0xFF1E40AF), Color(0xFF6D28D9), Color(0xFF065F46),
                  Color(0xFF92400E), Color(0xFF991B1B), Color(0xFF0E7490)];
  return name.isEmpty ? colors[0] : colors[name.codeUnitAt(0) % colors.length];
}

// ── Page ───────────────────────────────────────────────────────────────────
class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  List<dynamic> _payments        = [];
  bool          _loading         = true;
  bool          _live            = false;
  String        _filter          = 'verifying';
  num           _totalApprovedTzs = 0;
  Map<String, dynamic> _counts  = {};
  int           _page            = 1;

  int get _totalPages =>
      (_payments.length / _kPageSize).ceil().clamp(1, 9999);
  List<dynamic> get _pageItems {
    final s = (_page - 1) * _kPageSize;
    return _payments.skip(s).take(_kPageSize).toList();
  }

  ({bool ok, String msg})? _flash;
  Map<String, dynamic>? _newPayment;
  Timer? _newPaymentTimer;

  final Map<String, bool>                _smsOpen   = {};
  final Map<String, bool>                _chatOpen  = {};
  final Map<String, List<dynamic>>       _chatMsgs  = {};
  final Map<String, TextEditingController> _chatCtrl = {};
  final Map<String, bool>                _replying  = {};
  final Map<String, bool>                _approving = {};

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('notification', _onWs);
  }

  void _onWs(dynamic p) {
    if (!mounted) return;
    if (p['type'] == 'payment.submitted') {
      setState(() { _newPayment = p as Map<String, dynamic>; _live = true; });
      _load();
      _newPaymentTimer?.cancel();
      _newPaymentTimer = Timer(const Duration(seconds: 8),
          () { if (mounted) setState(() { _newPayment = null; _live = false; }); });
    }
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    _newPaymentTimer?.cancel();
    for (final c in _chatCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res  = await ApiService().adminAllDonations(status: _filter.isEmpty ? null : _filter);
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _payments          = (data['payments'] ?? []) as List;
        _totalApprovedTzs  = (data['total_approved_tzs'] ?? 0) as num;
        _counts            = (data['counts'] as Map<String, dynamic>?) ?? {};
        _loading           = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(String f) {
    setState(() { _filter = f; _page = 1; _smsOpen.clear(); _chatOpen.clear(); });
    _load();
  }

  void _showFlash(String msg, {bool ok = true}) {
    setState(() => _flash = (ok: ok, msg: msg));
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _approve(String orderId) async {
    setState(() => _approving[orderId] = true);
    try {
      await ApiService().adminApproveDonation(orderId);
      await _load();
      _showFlash('Malipo yameidhinishwa ✓');
    } catch (e) {
      _showFlash(_errDetail(e), ok: false);
    }
    if (mounted) setState(() => _approving.remove(orderId));
  }

  Future<void> _reject(String orderId) async {
    final ctrl = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 32, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: _kGrey300, borderRadius: BorderRadius.circular(2))),
            Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: _kRed50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.cancel_outlined, color: _kRed, size: 20)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kataa Malipo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kGrey900)),
                Text('Taja sababu (hiari)', style: TextStyle(fontSize: 11, color: _kGrey400)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close_rounded, size: 15, color: _kGrey500)),
              ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: _kGrey900),
              decoration: InputDecoration(
                hintText: 'Mfano: SMS ya uongo, kiasi hakikubaliani...',
                hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
                filled: true, fillColor: _kGrey50,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kRed, width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kGrey200), foregroundColor: _kGrey700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Ghairi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: _kRed,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Kataa Malipo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )),
            ]),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    if (reason == null) return;

    setState(() => _approving[orderId] = true);
    try {
      await ApiService().adminRejectDonation(orderId, note: reason);
      await _load();
      _showFlash('Malipo yamekataliwa');
    } catch (e) {
      _showFlash(_errDetail(e), ok: false);
    }
    if (mounted) setState(() => _approving.remove(orderId));
  }

  Future<void> _loadChat(String orderId) async {
    try {
      final res  = await ApiService().getPaymentMessages(orderId);
      final data = res.data;
      final msgs = data is Map
          ? (data['messages'] ?? data['items'] ?? []) as List
          : data is List ? data : [];
      if (mounted) setState(() => _chatMsgs[orderId] = msgs);
    } catch (_) {}
  }

  Future<void> _sendReply(String orderId) async {
    final ctrl = _chatCtrl[orderId];
    if (ctrl == null) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _replying[orderId] = true);
    try {
      await ApiService().adminPaymentReply(orderId, text);
      ctrl.clear();
      await _loadChat(orderId);
      _showFlash('Jibu limetumwa');
    } catch (e) {
      _showFlash(_errDetail(e), ok: false);
    }
    if (mounted) setState(() => _replying.remove(orderId));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pending  = (_counts['verifying'] ?? 0) as int;
    final approved = (_counts['approved']  ?? 0) as int;
    final rejected = (_counts['rejected']  ?? 0) as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Header ────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(color: _kBlue50, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: _kBlue)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Malipo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kGrey900)),
                if (_live) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _kGreen50, borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kGreen200)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 6, color: _kGreenDk),
                      SizedBox(width: 4),
                      Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kGreenDk)),
                    ]),
                  ),
                ],
              ]),
              const Text('Simamia michango ya watumiaji',
                style: TextStyle(fontSize: 11, color: _kGrey400)),
            ])),
          ]),
        ),
        const Divider(height: 1, color: _kGrey100),

        // ── Stat cards row ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            _StatCard(
              label: 'Imeidhinishwa',
              value: 'TZS ${_fmtNum(_totalApprovedTzs)}',
              icon: Icons.trending_up_rounded,
              color: _kGreenDk,
              bg: _kGreen50,
            ),
            const SizedBox(width: 6),
            _StatCard(
              label: 'Zinasubiri',
              value: '$pending',
              icon: Icons.hourglass_top_rounded,
              color: _kAmber700,
              bg: _kAmber50,
            ),
            const SizedBox(width: 6),
            _StatCard(
              label: 'Zimekataliwa',
              value: '$rejected',
              icon: Icons.cancel_outlined,
              color: _kRed,
              bg: _kRed50,
            ),
          ]),
        ),

        // ── Filter chips ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChip(label: 'Inasubiri ($pending)', value: 'verifying', current: _filter, onTap: _setFilter,
                activeColor: _kAmber700, activeBg: _kAmber50),
              const SizedBox(width: 6),
              _FilterChip(label: 'Imeidhinishwa ($approved)', value: 'approved', current: _filter, onTap: _setFilter,
                activeColor: _kGreenDk, activeBg: _kGreen50),
              const SizedBox(width: 6),
              _FilterChip(label: 'Imekataliwa ($rejected)', value: 'rejected', current: _filter, onTap: _setFilter,
                activeColor: _kRed, activeBg: _kRed50),
              const SizedBox(width: 6),
              _FilterChip(label: 'Zote', value: '', current: _filter, onTap: _setFilter,
                activeColor: _kBlue, activeBg: _kBlue50),
            ]),
          ),
        ),

        // ── New payment notification ───────────────────────────────────────
        if (_newPayment != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: _kBlue50, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue200),
              ),
              child: Row(children: [
                const Icon(Icons.notification_important_outlined, size: 16, color: _kBlue),
                const SizedBox(width: 8),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mchango mpya umefika!',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kBlue)),
                  Text('Angalia SMS hapa chini na uthibitishe.',
                    style: TextStyle(fontSize: 11, color: _kGrey500)),
                ])),
                GestureDetector(
                  onTap: () => setState(() => _newPayment = null),
                  child: const Icon(Icons.close_rounded, size: 15, color: _kGrey400)),
              ]),
            ),
          ),

        // ── Flash banner ──────────────────────────────────────────────────
        if (_flash != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _flash!.ok ? _kGreen50 : _kRed50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _flash!.ok ? _kGreen200 : _kRed200),
              ),
              child: Row(children: [
                Icon(_flash!.ok ? Icons.check_circle_outline : Icons.error_outline,
                  size: 14, color: _flash!.ok ? _kGreenDk : _kRed),
                const SizedBox(width: 7),
                Expanded(child: Text(_flash!.msg,
                  style: TextStyle(fontSize: 12, color: _flash!.ok ? _kGreenDk : _kRed))),
              ]),
            ),
          ),

        // ── Count ─────────────────────────────────────────────────────────
        if (!_loading && _payments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('${_pageItems.length} / ${_payments.length} malipo',
              style: const TextStyle(fontSize: 11, color: _kGrey400)),
          ),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
            ? const Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
            : RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: _payments.isEmpty
                  ? _empty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      children: [
                        ..._pageItems.map((p) => _PayCard(
                          key: ValueKey((p as Map)['order_id'] ?? p['_id']),
                          p: Map<String, dynamic>.from(p),
                          isApproving: _approving[(p['order_id'] ?? p['_id'])?.toString()] == true,
                          isReplying:  _replying[(p['order_id'] ?? p['_id'])?.toString()] == true,
                          smsOpen:  _smsOpen[(p['order_id'] ?? p['_id'])?.toString()] == true,
                          chatOpen: _chatOpen[(p['order_id'] ?? p['_id'])?.toString()] == true,
                          chatMsgs: _chatMsgs[(p['order_id'] ?? p['_id'])?.toString()],
                          chatCtrl: _chatCtrl.putIfAbsent(
                            (p['order_id'] ?? p['_id'])?.toString() ?? '',
                            () => TextEditingController()),
                          onApprove: () => _approve((p['order_id'] ?? p['_id'])?.toString() ?? ''),
                          onReject:  () => _reject((p['order_id'] ?? p['_id'])?.toString() ?? ''),
                          onToggleSms: () {
                            final id = (p['order_id'] ?? p['_id'])?.toString() ?? '';
                            setState(() => _smsOpen[id] = !(_smsOpen[id] == true));
                          },
                          onToggleChat: () {
                            final id = (p['order_id'] ?? p['_id'])?.toString() ?? '';
                            final next = !(_chatOpen[id] == true);
                            setState(() => _chatOpen[id] = next);
                            if (next && _chatMsgs[id] == null) _loadChat(id);
                          },
                          onSendReply: () => _sendReply(
                            (p['order_id'] ?? p['_id'])?.toString() ?? ''),
                        )),
                        if (_totalPages > 1) _Pagination(
                          page: _page, totalPages: _totalPages,
                          onPage: (p) => setState(() => _page = p)),
                        const SizedBox(height: 64),
                      ],
                    ),
              ),
        ),
      ],
    );
  }

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 56, height: 56,
      decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(28)),
      child: const Icon(Icons.receipt_long_outlined, size: 28, color: _kGrey400)),
    const SizedBox(height: 10),
    Text(_filter == 'verifying' ? 'Hakuna malipo yanayosubiri' : 'Hakuna malipo',
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey500)),
    const SizedBox(height: 3),
    const Text('Malipo mapya yataonekana hapa',
      style: TextStyle(fontSize: 11, color: _kGrey400)),
  ]));
}

// ── Stat card ──────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color, height: 1)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.75), fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ── Filter chip ────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  final Color activeColor, activeBg;
  const _FilterChip({required this.label, required this.value, required this.current,
    required this.onTap, required this.activeColor, required this.activeBg});

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? activeColor.withValues(alpha: 0.5) : _kGrey200),
        ),
        child: Center(child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: active ? activeColor : _kGrey500))),
      ),
    );
  }
}

// ── Pagination ─────────────────────────────────────────────────────────────
class _Pagination extends StatelessWidget {
  final int page, totalPages;
  final void Function(int) onPage;
  const _Pagination({required this.page, required this.totalPages, required this.onPage});

  @override
  Widget build(BuildContext context) {
    final w = <Widget>[];
    w.add(_nav(Icons.chevron_left_rounded, page > 1 ? () => onPage(page - 1) : null));
    w.add(const SizedBox(width: 4));

    final show = <int>{1, totalPages, page};
    if (totalPages <= 7) {
      for (int i = 1; i <= totalPages; i++) show.add(i);
    } else {
      for (int i = page - 1; i <= page + 1; i++) {
        if (i >= 1 && i <= totalPages) show.add(i);
      }
    }
    final sorted = show.toList()..sort();
    for (int idx = 0; idx < sorted.length; idx++) {
      if (idx > 0) {
        if (sorted[idx] - sorted[idx - 1] > 1) {
          w.add(const SizedBox(width: 4));
          w.add(const SizedBox(width: 28, height: 28,
            child: Center(child: Text('…', style: TextStyle(fontSize: 13, color: _kGrey400)))));
        }
        w.add(const SizedBox(width: 4));
      }
      final n = sorted[idx];
      final active = n == page;
      w.add(GestureDetector(
        onTap: active ? null : () => onPage(n),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: active ? _kBlue : Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: active ? _kBlue : _kGrey200),
          ),
          child: Center(child: Text('$n',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? Colors.white : _kGrey700))),
        ),
      ));
    }
    w.add(const SizedBox(width: 4));
    w.add(_nav(Icons.chevron_right_rounded, page < totalPages ? () => onPage(page + 1) : null));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: w),
    );
  }

  Widget _nav(IconData icon, VoidCallback? cb) => GestureDetector(
    onTap: cb,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _kGrey200)),
      child: Icon(icon, size: 15, color: cb != null ? _kGrey700 : _kGrey300),
    ),
  );
}

// ── Payment card (stateful for local toggles) ──────────────────────────────
class _PayCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final bool isApproving, isReplying, smsOpen, chatOpen;
  final List<dynamic>? chatMsgs;
  final TextEditingController chatCtrl;
  final VoidCallback onApprove, onReject, onToggleSms, onToggleChat, onSendReply;

  const _PayCard({
    super.key,
    required this.p,
    required this.isApproving,
    required this.isReplying,
    required this.smsOpen,
    required this.chatOpen,
    required this.chatMsgs,
    required this.chatCtrl,
    required this.onApprove,
    required this.onReject,
    required this.onToggleSms,
    required this.onToggleChat,
    required this.onSendReply,
  });

  Color _stripeColor(String status) {
    switch (status) {
      case 'approved': return _kGreenDk;
      case 'rejected': return _kRed;
      default:         return _kAmber700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status     = (p['status'] ?? 'verifying').toString();
    final isPending  = status == 'verifying';
    final orderId    = (p['order_id'] ?? p['_id'] ?? '').toString();
    final name       = (p['user_name'] ?? p['full_name'] ?? '').toString();
    final phone      = (p['phone'] ?? p['phone_primary'] ?? '').toString();
    final amount     = p['amount'] ?? 0;
    final method     = (p['payment_method'] ?? p['method'] ?? '').toString();
    final smsText    = (p['sms_text'] ?? '').toString();
    final note       = (p['note'] ?? '').toString();
    final isExpired  = p['expired'] == true;
    final hasMessages = (p['messages'] as List?)?.isNotEmpty == true;
    final initial    = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarBg   = _stripeColor(status) == _kGreenDk
        ? const Color(0xFF065F46) : _avatarColor(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Left stripe
            Container(width: 4, color: _stripeColor(status)),

            // Body
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Top: amount + status + method ─────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'TZS ${amount is num ? amount.toStringAsFixed(0) : amount}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: _kGrey900, letterSpacing: -0.5),
                      ),
                      if (method.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _MethodBadge(method: method),
                      ],
                    ])),
                    _StatusBadge(status: status),
                  ]),
                ),

                // ── User info ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
                      child: Center(child: Text(initial,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.isNotEmpty ? name : 'Mtumiaji',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900),
                        overflow: TextOverflow.ellipsis),
                      if (phone.isNotEmpty)
                        Text(phone, style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w500)),
                    ])),
                  ]),
                ),

                // ── Date + order ID ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: _kGrey400),
                    const SizedBox(width: 4),
                    Expanded(child: Text(_fmtDate(p['created_at'] as String?),
                      style: const TextStyle(fontSize: 10, color: _kGrey400))),
                    if (orderId.isNotEmpty)
                      Text(
                        orderId.length > 10 ? '#…${orderId.substring(orderId.length - 10)}' : '#$orderId',
                        style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: _kGrey300)),
                  ]),
                ),

                // Expired tag
                if (isExpired && isPending)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: _kOrange),
                      const SizedBox(width: 4),
                      const Text('Imeisha muda',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kOrange)),
                    ]),
                  ),

                const SizedBox(height: 10),
                Container(height: 1, color: _kGrey100),

                // ── Actions ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(children: [
                    if (isPending) ...[
                      Row(children: [
                        Expanded(child: _ActionBtn(
                          label: isApproving ? 'Inafanya...' : 'Idhinisha',
                          icon: Icons.check_circle_rounded,
                          color: Colors.white, bg: _kGreenDk,
                          busy: isApproving, onTap: onApprove,
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _ActionBtn(
                          label: 'Kataa',
                          icon: Icons.cancel_rounded,
                          color: Colors.white, bg: _kRed,
                          busy: isApproving, onTap: onReject,
                        )),
                      ]),
                      const SizedBox(height: 7),
                    ],
                    Row(children: [
                      if (smsText.isNotEmpty) ...[
                        _SecBtn(
                          label: smsOpen ? 'Ficha SMS' : 'SMS',
                          icon: smsOpen ? Icons.visibility_off_outlined : Icons.sms_outlined,
                          color: _kBlue, onTap: onToggleSms,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (status == 'rejected' || hasMessages)
                        _SecBtn(
                          label: chatOpen ? 'Funga' : 'Mazungumzo',
                          icon: chatOpen ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                          color: _kBlue, onTap: onToggleChat,
                        ),
                    ]),
                  ]),
                ),

                // ── SMS expand ────────────────────────────────────────────
                if (smsOpen && smsText.isNotEmpty) ...[
                  Container(height: 1, color: _kGrey100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.sms_outlined, size: 11, color: _kGrey400),
                        SizedBox(width: 5),
                        Text('SMS YA MTOA MCHANGO',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                            color: _kGrey400, letterSpacing: 0.8)),
                      ]),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kGrey50, borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kGrey200)),
                        child: Text(smsText,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: _kGrey700)),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, size: 12, color: _kRed),
                          const SizedBox(width: 4),
                          Flexible(child: Text('Kumbuka: $note',
                            style: const TextStyle(fontSize: 11, color: _kRed))),
                        ]),
                      ],
                    ]),
                  ),
                ],

                // ── Chat expand ───────────────────────────────────────────
                if (chatOpen) ...[
                  Container(height: 1, color: _kGrey100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(children: [
                      const Align(alignment: Alignment.centerLeft,
                        child: Row(children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 11, color: _kGrey400),
                          SizedBox(width: 5),
                          Text('MAZUNGUMZO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                            color: _kGrey400, letterSpacing: 0.8)),
                        ])),
                      const SizedBox(height: 8),
                      _ChatMessages(msgs: chatMsgs),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(
                          child: TextField(
                            controller: chatCtrl,
                            minLines: 1, maxLines: 3,
                            style: const TextStyle(fontSize: 12, color: _kGrey900),
                            decoration: InputDecoration(
                              hintText: 'Andika jibu...',
                              hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
                              filled: true, fillColor: _kGrey50,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _kGrey200)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _kGrey200)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                            ),
                            onSubmitted: (_) => onSendReply(),
                          ),
                        ),
                        const SizedBox(width: 7),
                        GestureDetector(
                          onTap: isReplying ? null : onSendReply,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isReplying ? _kBlue.withValues(alpha: 0.5) : _kBlue,
                              borderRadius: BorderRadius.circular(8)),
                            child: isReplying
                              ? const Center(child: SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                              : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color fg, bg, border;
    String label;
    IconData icon;
    switch (status) {
      case 'approved':
        fg = _kGreen700; bg = _kGreen50; border = _kGreen200;
        label = 'Imeidhinishwa'; icon = Icons.check_circle_outline_rounded;
      case 'rejected':
        fg = _kRed; bg = _kRed50; border = _kRed200;
        label = 'Imekataliwa'; icon = Icons.cancel_outlined;
      default:
        fg = _kAmber700; bg = _kAmber50; border = _kAmber200;
        label = 'Inasubiri'; icon = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

// ── Method badge ───────────────────────────────────────────────────────────
class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _kGrey200)),
    child: Text(method.toUpperCase(),
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
        color: _kGrey500, letterSpacing: 0.5)),
  );
}

// ── Action button (Idhinisha / Kataa) ──────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bg;
  final bool busy;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color,
    required this.bg, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: busy ? null : onTap,
    child: Opacity(
      opacity: busy ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    ),
  );
}

// ── Secondary button (SMS / Mazungumzo) ───────────────────────────────────
class _SecBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SecBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    ),
  );
}

// ── Chat messages ──────────────────────────────────────────────────────────
class _ChatMessages extends StatelessWidget {
  final List<dynamic>? msgs;
  const _ChatMessages({required this.msgs});

  @override
  Widget build(BuildContext context) {
    if (msgs == null) return const Center(child: Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))));
    if (msgs!.isEmpty) return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text('Hakuna mazungumzo bado.',
        style: TextStyle(fontSize: 11, color: _kGrey400), textAlign: TextAlign.center));
    return Column(children: msgs!.map<Widget>((m) {
      final isAdmin = m['sender'] == 'admin';
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isAdmin ? _kBlue : _kGrey100,
              borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['sender_name'] ?? ''}', style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: isAdmin ? Colors.white.withValues(alpha: 0.65) : _kGrey500)),
              const SizedBox(height: 2),
              Text('${m['message'] ?? ''}', style: TextStyle(
                fontSize: 12, color: isAdmin ? Colors.white : _kGrey700)),
            ]),
          ),
        ),
      );
    }).toList());
  }
}
