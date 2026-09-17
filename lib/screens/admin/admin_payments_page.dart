import 'package:flutter/material.dart';
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
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey50  = Color(0xFFF9FAFB);

const _kPageSize = 10;

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

  static const _statuses = ['pending', 'approved', 'rejected'];
  static const _labels   = ['Inasubiri', 'Imeidhinishwa', 'Imekataliwa'];

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
      _cache.remove('pending');
      _cache.remove('approved');
      await _loadStatus('pending');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _reject(String orderId) async {
    try {
      await ApiService().adminRejectDonation(orderId);
      if (!mounted) return;
      _cache.remove('pending');
      _cache.remove('rejected');
      await _loadStatus('pending');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _sendReply(String orderId, String msg) async {
    try {
      await ApiService().adminPaymentReply(orderId, msg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ujumbe umetumwa'), backgroundColor: _kGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  int _count(String s) => _cache[s]?.length ?? 0;

  String _fmtTotal() {
    final list = _cache['approved'] ?? [];
    double total = 0;
    for (final item in list) {
      total += ((item as Map)['amount'] as num?)?.toDouble() ?? 0;
    }
    if (total >= 1000000) return '${(total / 1000000).toStringAsFixed(1)}M';
    if (total >= 1000) return '${(total / 1000).toStringAsFixed(0)}K';
    return total.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final items = _cache[_status] ?? [];
    final totalPages = (items.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems = _loading || _error != null
        ? <dynamic>[]
        : items.skip(_page * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          _cache.remove(_status);
          await _loadStatus(_status);
        },
        color: _kBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.credit_card_outlined, color: _kBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Malipo',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                            Text('Simamia michango ya watumiaji',
                                style: TextStyle(fontSize: 12, color: _kGrey500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Compact stat pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _StatPill(
                          icon: Icons.trending_up,
                          text: 'TZS ${_fmtTotal()}',
                          color: _kGreen,
                          border: const Color(0xFFBBF7D0),
                          bg: _kGreenBg,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Icons.access_time,
                          text: '${_count('pending')} Inasubiri',
                          color: _kAmber,
                          border: const Color(0xFFFDE68A),
                          bg: _kAmberBg,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Icons.receipt_long_outlined,
                          text: '${items.length} Kuonyesha',
                          color: _kBlue,
                          border: const Color(0xFFBFDBFE),
                          bg: _kBlueBg,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(3, (i) {
                        final s = _statuses[i];
                        final active = _status == s;
                        Color c;
                        Color bg;
                        switch (i) {
                          case 1:  c = _kGreen; bg = _kGreenBg; break;
                          case 2:  c = _kRed;   bg = _kRedBg;   break;
                          default: c = _kAmber; bg = _kAmberBg;
                        }
                        return GestureDetector(
                          onTap: () => _loadStatus(s),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: active ? bg : Colors.white,
                              border: Border.all(color: active ? c : _kGrey200),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _labels[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: active ? c : _kGrey700,
                                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                if (_count(s) > 0) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: active ? c : _kGrey200,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_count(s)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: active ? Colors.white : _kGrey500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: _kGrey200),
                ],
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _kRed, size: 48),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () { _cache.remove(_status); _loadStatus(_status); },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Jaribu tena'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(color: _kAmberBg, shape: BoxShape.circle),
                        child: const Icon(Icons.receipt_long_outlined, color: _kAmber, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text('Hakuna malipo', style: TextStyle(color: _kGrey500, fontSize: 14)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () { _cache.remove(_status); _loadStatus(_status); },
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Onyesha upya'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kBlue,
                          side: const BorderSide(color: _kBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
            // Pagination
            if (!_loading && _error == null && totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PageBtn(
                        icon: Icons.chevron_left,
                        onTap: _page > 0 ? () => setState(() => _page--) : null,
                      ),
                      for (int p = 0; p < totalPages; p++)
                        _PageNum(
                          n: p + 1,
                          active: _page == p,
                          onTap: () => setState(() => _page = p),
                        ),
                      _PageBtn(
                        icon: Icons.chevron_right,
                        onTap: _page < totalPages - 1 ? () => setState(() => _page++) : null,
                      ),
                    ],
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String status;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;
  final Future<void> Function(String, String) onReply;

  const _PaymentCard({
    super.key,
    required this.item,
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onReply,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _showSms   = false;
  bool _showChat  = false;
  final _replyCtrl = TextEditingController();
  bool _sending   = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':  return _kGreen;
      case 'rejected':  return _kRed;
      case 'verifying': return _kBlue;
      default:          return _kAmber;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'approved':  return _kGreenBg;
      case 'rejected':  return _kRedBg;
      case 'verifying': return _kBlueBg;
      default:          return _kAmberBg;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved':  return 'Imeidhinishwa';
      case 'rejected':  return 'Imekataliwa';
      case 'verifying': return 'Inathibitishwa';
      default:          return 'Inasubiri';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item     = widget.item;
    final orderId  = item['order_id']?.toString() ?? item['id']?.toString() ?? '';
    final amount   = (item['amount'] as num?)?.toInt() ?? 0;
    final name     = item['user_name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
    final phone    = item['phone'] as String? ?? item['phone_primary'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final smsText  = item['sms_text'] as String? ?? '';
    final messages = (item['messages'] as List?) ?? [];
    final sc       = _statusColor(widget.status);
    final sb       = _statusBg(widget.status);
    final isPending = widget.status == 'pending' || widget.status == 'verifying';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: name + phone | status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                    if (phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 11, color: _kBlue),
                            const SizedBox(width: 3),
                            Text(phone,
                                style: const TextStyle(fontSize: 12, color: _kBlue)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(widget.status),
                    style: TextStyle(
                        fontSize: 11, color: sc, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Amount box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kGrey50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TZS ${_fmt(amount)}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, color: _kGrey900)),
                if (orderId.isNotEmpty)
                  Text(
                    orderId,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kGrey400,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 11, color: _kGrey500),
                const SizedBox(width: 4),
                Text(createdAt,
                    style: const TextStyle(fontSize: 11, color: _kGrey500)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Action pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (widget.status == 'rejected' || messages.isNotEmpty)
                _ActionPill(
                  icon: Icons.chat_bubble_outline,
                  label: 'Ujumbe${messages.isNotEmpty ? ' (${messages.length})' : ''}',
                  color: _kBlue,
                  bg: _kBlueBg,
                  onTap: () => setState(() => _showChat = !_showChat),
                ),
              if (smsText.isNotEmpty || true)
                _ActionPill(
                  icon: Icons.sms_outlined,
                  label: _showSms ? 'Ficha SMS' : 'Angalia SMS',
                  color: _kGrey700,
                  bg: _kGrey100,
                  onTap: () => setState(() => _showSms = !_showSms),
                ),
              if (isPending) ...[
                _ActionPill(
                  icon: Icons.check,
                  label: 'Idhinisha',
                  color: _kGreen,
                  bg: _kGreenBg,
                  onTap: () => widget.onApprove(orderId),
                ),
                _ActionPill(
                  icon: Icons.close,
                  label: 'Kataa',
                  color: _kRed,
                  bg: _kRedBg,
                  onTap: () => widget.onReject(orderId),
                ),
              ],
            ],
          ),
          // SMS expanded
          if (_showSms) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kGrey50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGrey200),
              ),
              child: Text(
                smsText.isNotEmpty ? smsText : 'Hakuna data ya SMS',
                style: const TextStyle(fontSize: 12, color: _kGrey700, height: 1.4),
              ),
            ),
          ],
          // Chat expanded
          if (_showChat) ...[
            const SizedBox(height: 10),
            if (messages.isNotEmpty)
              ...messages.map((msg) {
                final m = msg as Map<String, dynamic>;
                final isAdmin = m['sender'] == 'admin';
                return Align(
                  alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: isAdmin ? _kBlueBg : _kGrey100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      m['message'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: isAdmin ? _kBlue : _kGrey700,
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Andika ujumbe...',
                      hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : () async {
                    final text = _replyCtrl.text.trim();
                    if (text.isEmpty) return;
                    setState(() => _sending = true);
                    await widget.onReply(orderId, text);
                    if (mounted) {
                      _replyCtrl.clear();
                      setState(() => _sending = false);
                    }
                  },
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ActionPill({
    required this.icon, required this.label,
    required this.color, required this.bg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color border;
  final Color bg;
  const _StatPill({
    required this.icon, required this.text,
    required this.color, required this.border, required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PageNum extends StatelessWidget {
  final int n;
  final bool active;
  final VoidCallback onTap;
  const _PageNum({required this.n, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          border: Border.all(color: active ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text('$n',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kGrey700,
              )),
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PageBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: onTap != null ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: onTap != null ? _kBlue : _kGrey200),
      ),
    );
  }
}
