import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  String? _error;
  int _tabIndex = 0; // 0=pending 1=approved 2=rejected
  final Map<String, List<dynamic>> _cache = {};

  static const _statuses = ['pending', 'approved', 'rejected'];
  static const _labels = ['Inasubiri', 'Imeidhinishwa', 'Imekataliwa'];

  @override
  void initState() {
    super.initState();
    _loadTab('pending');
  }

  Future<void> _loadTab(String status) async {
    if (_cache.containsKey(status)) {
      setState(() {});
      return;
    }
    setState(() { _loading = true; _error = null; });
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

  void _switchTab(int i) {
    setState(() { _tabIndex = i; });
    _loadTab(_statuses[i]);
  }

  int _count(String status) => _cache[status]?.length ?? 0;

  double _totalApproved() {
    final list = _cache['approved'] ?? [];
    double total = 0;
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final amount = (m['amount'] as num?)?.toDouble() ?? 0;
      total += amount;
    }
    return total;
  }

  Future<void> _approve(String orderId) async {
    try {
      await ApiService().adminApproveDonation(orderId);
      if (!mounted) return;
      _cache.remove('pending');
      _cache.remove('approved');
      await _loadTab('pending');
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
      await _loadTab('pending');
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

  @override
  Widget build(BuildContext context) {
    final currentStatus = _statuses[_tabIndex];
    final items = _cache[currentStatus] ?? [];
    final total = _totalApproved();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_outlined, color: _kBlue, size: 22),
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
          // Stat cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _StatCard(
                  icon: Icons.arrow_upward,
                  value: total >= 1000 ? '${(total / 1000).toStringAsFixed(0)}K' : '${total.toInt()}',
                  label: 'Imeidhinishwa',
                  color: _kGreen,
                  bgColor: _kGreenBg,
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  icon: Icons.hourglass_empty,
                  value: '${_count('pending')}',
                  label: 'Zinasubiri',
                  color: _kAmber,
                  bgColor: _kAmberBg,
                )),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  icon: Icons.cancel_outlined,
                  value: '${_count('rejected')}',
                  label: 'Zimekataliwa',
                  color: _kRed,
                  bgColor: _kRedBg,
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Tab pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(3, (i) {
                final status = _statuses[i];
                final cnt = _count(status);
                final active = _tabIndex == i;
                Color activeColor;
                Color activeBg;
                switch (i) {
                  case 1: activeColor = _kGreen; activeBg = _kGreenBg; break;
                  case 2: activeColor = _kRed; activeBg = _kRedBg; break;
                  default: activeColor = _kAmber; activeBg = _kAmberBg;
                }
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _switchTab(i),
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? activeBg : Colors.white,
                        border: Border.all(color: active ? activeColor : _kGrey200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text('$cnt',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold,
                                color: active ? activeColor : _kGrey700,
                              )),
                          Text(_labels[i],
                              style: TextStyle(
                                fontSize: 10,
                                color: active ? activeColor : _kGrey500,
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          if (!_loading && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Zinaonyesha ${items.length} malipo',
                  style: TextStyle(fontSize: 11, color: _kGrey500),
                ),
              ),
            ),
          const SizedBox(height: 6),
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
                      onPressed: () { _cache.remove(currentStatus); _loadTab(currentStatus); },
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
          else if (items.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: _kAmberBg, borderRadius: BorderRadius.circular(32)),
                      child: const Icon(Icons.receipt_long_outlined, color: _kAmber, size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text('Hakuna malipo yanayosubiri',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey700)),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () { _cache.remove(currentStatus); _loadTab(currentStatus); },
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _cache.remove(currentStatus);
                  await _loadTab(currentStatus);
                },
                color: _kBlue,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = items[i] as Map<String, dynamic>;
                    return _PaymentCard(
                      item: item,
                      status: currentStatus,
                      onApprove: _approve,
                      onReject: _reject,
                      onReply: _sendReply,
                    );
                  },
                ),
              ),
            ),
        ],
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
  final _replyCtrl = TextEditingController();
  bool _showReply = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return _kGreen;
      case 'rejected': return _kRed;
      default: return _kAmber;
    }
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'approved': return _kGreenBg;
      case 'rejected': return _kRedBg;
      default: return _kAmberBg;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved': return 'Imeidhinishwa';
      case 'rejected': return 'Imekataliwa';
      default: return 'Inasubiri';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final orderId = item['order_id']?.toString() ?? item['id']?.toString() ?? '';
    final amount = (item['amount'] as num?)?.toInt() ?? 0;
    final name = item['user_name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
    final phone = item['phone'] as String? ?? item['phone_primary'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final reference = item['reference'] as String? ?? item['mpesa_ref'] as String? ?? '';
    final messages = (item['messages'] as List?) ?? [];
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final statusColor = _statusColor(widget.status);
    final statusBg = _statusBg(widget.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TZS ${_fmt(amount)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                child: Text(_statusLabel(widget.status),
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kBlueBg,
                child: Text(initials,
                    style: TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900)),
                    if (phone.isNotEmpty)
                      Text(phone, style: TextStyle(fontSize: 11, color: _kBlue)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (createdAt.isNotEmpty) ...[
                const Icon(Icons.access_time, size: 12, color: _kGrey500),
                const SizedBox(width: 4),
                Text(createdAt, style: TextStyle(fontSize: 11, color: _kGrey500)),
              ],
              const Spacer(),
              if (reference.isNotEmpty)
                Text('#$reference', style: TextStyle(fontSize: 11, color: _kGrey400)),
            ],
          ),
          // Messages
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...messages.map((msg) {
              final m = msg as Map<String, dynamic>;
              final isAdmin = m['sender'] == 'admin';
              return Align(
                alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAdmin ? _kBlueBg : _kGrey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    m['message'] as String? ?? '',
                    style: TextStyle(fontSize: 12, color: isAdmin ? _kBlue : _kGrey700),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 10),
          if (widget.status == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onApprove(orderId),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Idhinisha', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onReject(orderId),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Kataa', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            if (_showReply) ...[
              TextField(
                controller: _replyCtrl,
                decoration: InputDecoration(
                  hintText: 'Andika ujumbe...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kGrey200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kGrey200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBlue),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: _kBlue),
                    onPressed: () async {
                      if (_replyCtrl.text.trim().isNotEmpty) {
                        await widget.onReply(orderId, _replyCtrl.text.trim());
                        if (mounted) {
                          _replyCtrl.clear();
                          setState(() { _showReply = false; });
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() { _showReply = !_showReply; }),
                  icon: const Icon(Icons.sms_outlined, size: 14),
                  label: const Text('SMS', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGrey700,
                    side: const BorderSide(color: _kGrey200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() { _showReply = !_showReply; }),
                    icon: const Icon(Icons.chat_bubble_outline, size: 14),
                    label: const Text('Funga mazungumzo', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color bgColor;
  const _StatCard({
    required this.icon, required this.value, required this.label,
    required this.color, required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
