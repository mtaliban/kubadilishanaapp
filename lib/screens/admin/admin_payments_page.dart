import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';

const _kBlue     = Color(0xFF1E40AF);
const _kBlue50   = Color(0xFFEFF6FF);
const _kGrey900  = Color(0xFF111827);
const _kGrey700  = Color(0xFF374151);
const _kGrey600  = Color(0xFF4B5563);
const _kGrey500  = Color(0xFF6B7280);
const _kGrey400  = Color(0xFF9CA3AF);
const _kGrey200  = Color(0xFFE5E7EB);
const _kGrey100  = Color(0xFFF3F4F6);
const _kGrey50   = Color(0xFFF9FAFB);
const _kGreen50  = Color(0xFFF0FDF4);
const _kGreen600 = Color(0xFF16A34A);
const _kGreen700 = Color(0xFF15803D);
const _kRed      = Color(0xFFDC2626);
const _kRed50    = Color(0xFFFEF2F2);
const _kOrange   = Color(0xFFF97316);
const _kOrange50 = Color(0xFFFFF7ED);
const _kOrange700 = Color(0xFFC2410C);

const _kPageSize = 3;

String _fmtNum(num n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
  return n.toStringAsFixed(0);
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso.split('T').first;
  }
}

String _errDetail(Object e) {
  try {
    final d = (e as dynamic).response?.data?['detail'];
    return d is String ? d : 'Imeshindikana';
  } catch (_) {
    return 'Imeshindikana';
  }
}

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  List<dynamic> _payments = [];
  bool _loading = true;
  String _filter = 'verifying';

  num _totalApprovedTzs = 0;
  Map<String, dynamic> _counts = {};

  int _page = 1;
  int get _totalPages =>
      (_visiblePayments.length / _kPageSize).ceil().clamp(1, 9999);

  List<dynamic> get _visiblePayments => _payments;
  List<dynamic> get _pageItems {
    final start = (_page - 1) * _kPageSize;
    final end = (start + _kPageSize).clamp(0, _payments.length);
    if (start >= _payments.length) return [];
    return _payments.sublist(start, end);
  }

  // Flash banner
  ({bool ok, String msg})? _flash;

  // New payment WS popup
  Map<String, dynamic>? _newPayment;
  Timer? _newPaymentTimer;

  // Per-card expand state
  final Map<String, bool> _smsExpanded = {};
  final Map<String, bool> _chatExpanded = {};
  final Map<String, List<dynamic>> _chatMessages = {};
  final Map<String, TextEditingController> _chatCtrls = {};
  final Map<String, bool> _replying = {};
  final Map<String, bool> _approving = {};

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('notification', _onWs);
  }

  void _onWs(dynamic payload) {
    if (!mounted) return;
    if (payload['type'] == 'payment.submitted') {
      setState(() => _newPayment = payload as Map<String, dynamic>);
      _load();
      _newPaymentTimer?.cancel();
      _newPaymentTimer = Timer(const Duration(seconds: 8),
          () { if (mounted) setState(() => _newPayment = null); });
    }
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    _newPaymentTimer?.cancel();
    for (final c in _chatCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().adminAllDonations(status: _filter.isEmpty ? null : _filter);
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _payments = (data['payments'] ?? []) as List;
        _totalApprovedTzs = (data['total_approved_tzs'] ?? 0) as num;
        _counts = (data['counts'] as Map<String, dynamic>?) ?? {};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _setFilter(String f) {
    setState(() {
      _filter = f;
      _page = 1;
      _smsExpanded.clear();
      _chatExpanded.clear();
    });
    _load();
  }

  void _showFlash(String msg, {bool ok = true}) {
    setState(() => _flash = (ok: ok, msg: msg));
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  // ── Approve ────────────────────────────────────────────────────────────────

  Future<void> _approve(String orderId) async {
    setState(() => _approving[orderId] = true);
    try {
      await ApiService().adminApproveDonation(orderId);
      await _load();
      _showFlash('Malipo yamekubaliwa — $orderId');
    } catch (e) {
      _showFlash(_errDetail(e), ok: false);
    }
    if (mounted) setState(() => _approving.remove(orderId));
  }

  // ── Reject with reason dialog ──────────────────────────────────────────────

  Future<void> _reject(String orderId) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Sababu ya Kukataa',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kGrey900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Taja sababu ya kukataa malipo haya (hiari):',
              style: TextStyle(fontSize: 13, color: _kGrey600)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Mfano: SMS ya uongo, kiasi hakikubaliani...',
              hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kGrey200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kGrey200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ghairi', style: TextStyle(color: _kGrey500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Kataa'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason == null) return; // user cancelled

    setState(() => _approving[orderId] = true);
    try {
      await ApiService().adminRejectDonation(orderId, note: reason);
      await _load();
      _showFlash('Malipo yamekataliwa — $orderId');
    } catch (e) {
      _showFlash(_errDetail(e), ok: false);
    }
    if (mounted) setState(() => _approving.remove(orderId));
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> _loadChat(String orderId) async {
    try {
      final res = await ApiService().getPaymentMessages(orderId);
      final data = res.data;
      final msgs = data is Map
          ? (data['messages'] ?? data['items'] ?? []) as List
          : data is List ? data : [];
      if (mounted) setState(() => _chatMessages[orderId] = msgs);
    } catch (_) {}
  }

  Future<void> _sendReply(String orderId) async {
    final ctrl = _chatCtrls[orderId];
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Icon(Icons.credit_card_outlined,
                      size: 20, color: _kBlue)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Malipo',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _kGrey900)),
                    Text('Simamia michango ya watumiaji',
                        style: TextStyle(fontSize: 12, color: _kGrey500)),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 10),

        // Filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _filterTab('verifying',
                'Inasubiri (${_counts['verifying'] ?? 0})'),
            const SizedBox(width: 8),
            _filterTab('approved',
                'Imekubaliwa (${_counts['approved'] ?? 0})'),
            const SizedBox(width: 8),
            _filterTab('rejected',
                'Imekataliwa (${_counts['rejected'] ?? 0})'),
            const SizedBox(width: 8),
            _filterTab('', 'Zote'),
          ]),
        ),
        const SizedBox(height: 10),

        // Stats chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _statChip(
              icon: Icons.trending_up,
              iconColor: _kGreen600,
              value: 'TZS ${_fmtNum(_totalApprovedTzs)}',
              label: 'Jumla Iliyokubaliwa',
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.access_time_outlined,
              iconColor: _kOrange,
              value: '${_counts['verifying'] ?? 0}',
              label: 'Zinasubiri',
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.receipt_long_outlined,
              iconColor: _kBlue,
              value: '${_payments.length}',
              label: 'Katika Orodha',
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // Flash banner
        if (_flash != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _flash!.ok ? _kGreen50 : _kRed50,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: _flash!.ok
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFECACA)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    _flash!.ok
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    size: 13,
                    color: _flash!.ok ? _kGreen700 : _kRed),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(_flash!.msg,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _flash!.ok ? _kGreen700 : _kRed)),
                ),
              ]),
            ),
          ),

        // New payment notification
        if (_newPayment != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                    left: BorderSide(color: _kBlue, width: 4)),
              ),
              child: Row(children: [
                const Icon(Icons.credit_card_outlined,
                    size: 18, color: _kBlue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mchango mpya umefika!',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _kGrey900)),
                        Text('Angalia SMS chini na uthibitishe.',
                            style:
                                TextStyle(fontSize: 11, color: _kGrey600)),
                      ]),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _newPayment = null),
                  child: const Icon(Icons.close,
                      size: 16, color: _kGrey400),
                ),
              ]),
            ),
          ),

        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kBlue)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kBlue,
                  child: _payments.isEmpty
                      ? _emptyState()
                      : ListView(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          children: [
                            for (final p in _pageItems)
                              _paymentCard(
                                  p as Map<String, dynamic>),
                            if (_totalPages > 1) _paginationRow(),
                            const SizedBox(height: 64),
                          ],
                        ),
                ),
        ),
      ],
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 32, color: _kGrey400),
            const SizedBox(height: 10),
            Text(
              _filter == 'verifying'
                  ? 'Hakuna malipo yanayosubiri'
                  : 'Hakuna malipo',
              style: const TextStyle(fontSize: 13, color: _kGrey500),
            ),
          ],
        ),
      );

  Widget _filterTab(String filter, String label) {
    final active = _filter == filter;
    return GestureDetector(
      onTap: () => _setFilter(filter),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _kBlue : _kGrey100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kGrey700)),
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _kGrey900)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: _kGrey500)),
        ]),
      );

  Widget _paymentCard(Map<String, dynamic> p) {
    final status = p['status'] ?? 'verifying';
    final isPending = status == 'verifying';
    final orderId = (p['order_id'] ?? p['_id'] ?? '').toString();
    final name = p['user_name'] ?? p['full_name'] ?? '';
    final phone = p['phone'] ?? p['phone_primary'] ?? '';
    final amount = p['amount'] ?? 0;
    final smsText = (p['sms_text'] ?? '').toString();
    final note = (p['note'] ?? '').toString();
    final isSmsOpen = _smsExpanded[orderId] == true;
    final isChatOpen = _chatExpanded[orderId] == true;
    final isBusy = _approving[orderId] == true;
    final isExpired = p['expired'] == true;
    final hasMessages =
        (p['messages'] as List?)?.isNotEmpty == true;

    _chatCtrls.putIfAbsent(orderId, () => TextEditingController());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // ── Card body ──
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Amount + status badge
            Row(children: [
              Expanded(
                child: Text(
                  'TZS ${amount is num ? amount.toStringAsFixed(0) : amount}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _kGrey900),
                ),
              ),
              _statusBadge(status),
            ]),
            const SizedBox(height: 6),
            // Name
            Text(name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kGrey700)),
            // Phone
            Text(phone,
                style: const TextStyle(
                    fontSize: 12, color: _kBlue)),
            const SizedBox(height: 4),
            // Date + order_id row
            Row(children: [
              Expanded(
                child: Text(_fmtDate(p['created_at'] as String?),
                    style: const TextStyle(
                        fontSize: 11, color: _kGrey400)),
              ),
              if (orderId.isNotEmpty)
                Text(
                  orderId.length > 14
                      ? '…${orderId.substring(orderId.length - 14)}'
                      : orderId,
                  style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: _kGrey400),
                ),
            ]),
            // Expired tag
            if (isExpired && isPending) ...[
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.access_time,
                    size: 11, color: _kOrange),
                const SizedBox(width: 3),
                const Text('Imeisha muda',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kOrange)),
              ]),
            ],
            const SizedBox(height: 10),

            // Action buttons row
            Row(children: [
              // View SMS button
              if (smsText.isNotEmpty) ...[
                _pillBtn(
                  label: isSmsOpen ? 'Ficha SMS' : 'Ona SMS',
                  icon: isSmsOpen
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _kGrey600,
                  bg: _kGrey100,
                  border: _kGrey200,
                  busy: false,
                  onTap: () => setState(() =>
                      _smsExpanded[orderId] = !isSmsOpen),
                ),
                const SizedBox(width: 6),
              ],
              // Chat button (if rejected or has messages)
              if (status == 'rejected' || hasMessages) ...[
                _pillBtn(
                  label: isChatOpen ? 'Funga' : 'Mazungumzo',
                  icon: Icons.chat_bubble_outline,
                  color: _kBlue,
                  bg: _kBlue50,
                  border: _kBlue.withValues(alpha: 0.2),
                  busy: false,
                  onTap: () {
                    final next = !isChatOpen;
                    setState(() => _chatExpanded[orderId] = next);
                    if (next && _chatMessages[orderId] == null) {
                      _loadChat(orderId);
                    }
                  },
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              // Approve / Reject buttons
              if (isPending) ...[
                _pillBtn(
                  label: isBusy ? '...' : 'Thibitisha',
                  icon: Icons.check_circle_outline,
                  color: _kGreen700,
                  bg: _kGreen50,
                  border: const Color(0xFFBBF7D0),
                  busy: isBusy,
                  onTap: () => _approve(orderId),
                ),
                const SizedBox(width: 6),
                _pillBtn(
                  label: 'Kataa',
                  icon: Icons.cancel_outlined,
                  color: _kRed,
                  bg: _kRed50,
                  border: const Color(0xFFFECACA),
                  busy: isBusy,
                  onTap: () => _reject(orderId),
                ),
              ],
            ]),
          ]),
        ),

        // ── SMS expand ──
        if (isSmsOpen && smsText.isNotEmpty) ...[
          Container(height: 1, color: _kGrey200),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                const Icon(Icons.credit_card_outlined,
                    size: 11, color: _kGrey500),
                const SizedBox(width: 5),
                const Text('SMS YA MTOA MCHANGO',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kGrey500,
                        letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kGrey50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(smsText,
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: _kGrey700)),
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 12, color: _kRed),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text('Kumbuka: $note',
                        style: const TextStyle(
                            fontSize: 11, color: _kRed)),
                  ),
                ]),
              ],
            ]),
          ),
        ],

        // ── Chat expand ──
        if (isChatOpen) ...[
          Container(height: 1, color: _kGrey200),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 11, color: _kGrey500),
                const SizedBox(width: 5),
                const Text('MAZUNGUMZO NA MTOA MCHANGO',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _kGrey500,
                        letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 10),
              // Messages
              _buildChatMessages(orderId),
              const SizedBox(height: 8),
              // Reply input
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrls[orderId],
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Andika jibu...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: _kGrey400),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: _kGrey50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: _kGrey200)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: _kGrey200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: _kBlue, width: 1.5)),
                    ),
                    onSubmitted: (_) => _sendReply(orderId),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _replying[orderId] == true
                      ? null
                      : () => _sendReply(orderId),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _replying[orderId] == true
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.send_rounded,
                            size: 16, color: Colors.white),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildChatMessages(String orderId) {
    final msgs = _chatMessages[orderId];
    if (msgs == null) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kBlue))));
    }
    if (msgs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Hakuna mazungumzo bado.',
            style: TextStyle(fontSize: 11, color: _kGrey400),
            textAlign: TextAlign.center),
      );
    }
    return Column(
      children: msgs.map<Widget>((m) {
        final isAdmin = m['sender'] == 'admin';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Align(
            alignment:
                isAdmin ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isAdmin ? _kBlue : _kGrey100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${m['sender_name'] ?? ''}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isAdmin
                            ? Colors.white.withValues(alpha: 0.7)
                            : _kGrey500)),
                const SizedBox(height: 2),
                Text('${m['message'] ?? ''}',
                    style: TextStyle(
                        fontSize: 12,
                        color: isAdmin ? Colors.white : _kGrey700)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusBadge(String status) {
    Color fg, bg, border;
    String label;
    IconData icon;
    switch (status) {
      case 'approved':
        fg = _kGreen700;
        bg = _kGreen50;
        border = const Color(0xFFBBF7D0);
        label = 'Imekubaliwa';
        icon = Icons.check_circle_outline;
      case 'rejected':
        fg = _kRed;
        bg = _kRed50;
        border = const Color(0xFFFECACA);
        label = 'Imekataliwa';
        icon = Icons.cancel_outlined;
      default:
        fg = _kOrange700;
        bg = _kOrange50;
        border = const Color(0xFFFED7AA);
        label = 'Inasubiri';
        icon = Icons.access_time;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: fg),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg)),
      ]),
    );
  }

  Widget _pillBtn({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required bool busy,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: busy ? null : onTap,
        child: Opacity(
          opacity: busy ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ]),
          ),
        ),
      );

  Widget _paginationRow() {
    final canNext = _page < _totalPages;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Numbered page buttons
            for (int i = 1; i <= _totalPages; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _page = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: i == _page ? _kBlue : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: i == _page ? _kBlue : _kGrey200),
                    ),
                    child: Center(
                      child: Text('$i',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: i == _page
                                  ? Colors.white
                                  : _kGrey600)),
                    ),
                  ),
                ),
              ),
            // Next button
            GestureDetector(
              onTap: canNext
                  ? () => setState(() => _page++)
                  : null,
              child: Opacity(
                opacity: canNext ? 1.0 : 0.4,
                child: Container(
                  height: 32,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _kGrey200),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Endelea',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _kGrey600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 14, color: _kGrey600),
                      ]),
                ),
              ),
            ),
          ]),
    );
  }
}
