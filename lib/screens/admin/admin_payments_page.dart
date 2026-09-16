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

Color _avatarColor(String name) {
  if (name.isEmpty) return _kBlue;
  final colors = [Color(0xFF16A34A), Color(0xFF2563EB), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF7C3AED), Color(0xFF0891B2)];
  return colors[name.codeUnitAt(0) % colors.length];
}

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  String? _error;
  String _tab = 'approved';
  List<dynamic> _allDonations = [];
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  double _totalApprovedAmount = 0;
  Map<String, List<dynamic>> _messages = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminAllDonations();
      if (!mounted) return;
      final list = (res.data is List) ? res.data as List : (res.data['donations'] as List? ?? []);
      int pending = 0, approved = 0, rejected = 0;
      double total = 0;
      for (final d in list) {
        final st = (d['status'] ?? '').toString().toLowerCase();
        if (st == 'pending') pending++;
        if (st == 'approved') {
          approved++;
          total += ((d['amount'] as num?) ?? 0).toDouble();
        }
        if (st == 'rejected') rejected++;
      }
      setState(() {
        _allDonations = list;
        _pendingCount = pending;
        _approvedCount = approved;
        _rejectedCount = rejected;
        _totalApprovedAmount = total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    return _allDonations.where((d) {
      final st = (d['status'] ?? '').toString().toLowerCase();
      if (_tab == 'pending') return st == 'pending';
      if (_tab == 'approved') return st == 'approved';
      if (_tab == 'rejected') return st == 'rejected';
      return true;
    }).toList();
  }

  String _formatAmount(dynamic amount) {
    final n = ((amount as num?) ?? 0).toDouble();
    if (n >= 1000) {
      return 'TZS ${(n / 1000).toStringAsFixed(0)}K';
    }
    return 'TZS ${n.toStringAsFixed(0)}';
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y · $h:$min';
    } catch (_) {
      return raw.toString().split('T')[0];
    }
  }

  Future<void> _approve(Map<String, dynamic> donation) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Idhinisha Malipo', style: TextStyle(color: _kGrey900, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Idhinisha malipo ya ${_formatAmount(donation['amount'])}?', style: TextStyle(color: _kGrey700)),
            SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                hintText: 'Maelezo (hiari)',
                hintStyle: TextStyle(color: _kGrey400),
                filled: true,
                fillColor: _kGrey100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Ghairi', style: TextStyle(color: _kGrey500))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Idhinisha'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService().adminApproveDonation(donation['order_id']?.toString() ?? donation['_id']?.toString() ?? '', note: noteCtrl.text.isEmpty ? null : noteCtrl.text);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
    }
  }

  Future<void> _reject(Map<String, dynamic> donation) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kataa Malipo', style: TextStyle(color: _kGrey900, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Toa sababu ya kukataa malipo haya:', style: TextStyle(color: _kGrey700)),
            SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Sababu ya kukataa *',
                hintStyle: TextStyle(color: _kGrey400),
                filled: true,
                fillColor: _kGrey100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _kGrey200)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Ghairi', style: TextStyle(color: _kGrey500))),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Kataa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService().adminRejectDonation(donation['order_id']?.toString() ?? donation['_id']?.toString() ?? '', note: reasonCtrl.text.isEmpty ? null : reasonCtrl.text);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
    }
  }

  Future<void> _sendMessage(Map<String, dynamic> donation, String message) async {
    final orderId = donation['order_id']?.toString() ?? donation['_id']?.toString() ?? '';
    try {
      await ApiService().sendPaymentMessage(orderId, message);
      if (!mounted) return;
      final msgRes = await ApiService().getPaymentMessages(orderId);
      if (!mounted) return;
      setState(() {
        _messages[orderId] = (msgRes.data is List) ? msgRes.data as List : [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: ${e.toString()}'), backgroundColor: _kRed));
    }
  }

  Future<void> _loadMessages(String orderId) async {
    try {
      final res = await ApiService().getPaymentMessages(orderId);
      if (!mounted) return;
      setState(() {
        _messages[orderId] = (res.data is List) ? res.data as List : [];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kGrey100,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _kBlue))
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _kBlue,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildHeader()),
                        SliverToBoxAdapter(child: _buildStats()),
                        SliverToBoxAdapter(child: _buildTabs()),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Text('Zinaonyesha ${_filtered.length} kati ya ${_allDonations.length}', style: TextStyle(color: _kGrey500, fontSize: 13)),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _buildPaymentCard(_filtered[i]),
                            childCount: _filtered.length,
                          ),
                        ),
                        if (_filtered.isEmpty) SliverToBoxAdapter(child: _buildEmpty()),
                        SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: _kRed),
          SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: _kGrey700), textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
            child: Text('Jaribu Tena'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.receipt_long_rounded, color: _kBlue, size: 24),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Malipo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900)),
              Text('Simamia michango ya watumiaji', style: TextStyle(fontSize: 13, color: _kGrey500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(child: _statCard(_formatAmount(_totalApprovedAmount), 'Imeidhinishwa', _kGreen, _kGreenBg, Icons.check_circle_outline)),
          SizedBox(width: 8),
          Expanded(child: _statCard('$_pendingCount', 'Zinasubiri', _kAmber, _kAmberBg, Icons.hourglass_empty_rounded)),
          SizedBox(width: 8),
          Expanded(child: _statCard('$_rejectedCount', 'Zimekataliwa', _kRed, _kRedBg, Icons.cancel_outlined)),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color, Color bg, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _tabPill('pending', 'Inasubiri', _pendingCount),
          SizedBox(width: 8),
          _tabPill('approved', 'Imeidhinishwa', _approvedCount),
          SizedBox(width: 8),
          _tabPill('rejected', 'Imekataliwa', _rejectedCount),
        ],
      ),
    );
  }

  Widget _tabPill(String tab, String label, int count) {
    final active = _tab == tab;
    Color col = tab == 'approved' ? _kGreen : tab == 'pending' ? _kAmber : _kRed;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? col : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? col : _kGrey200),
          ),
          child: Column(
            children: [
              Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? Colors.white : col)),
              Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.white.withOpacity(0.9) : _kGrey500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: _kGrey400),
            SizedBox(height: 12),
            Text('Hakuna malipo', style: TextStyle(color: _kGrey500, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> donation) {
    final status = (donation['status'] ?? '').toString().toLowerCase();
    final name = donation['user']?['name']?.toString() ?? donation['user']?['full_name']?.toString() ?? 'Mtumiaji';
    final phone = donation['user']?['phone']?.toString() ?? '';
    final amount = donation['amount'];
    final ref = donation['order_id']?.toString() ?? donation['reference']?.toString() ?? '';
    final shortRef = ref.length > 12 ? '#${ref.substring(ref.length - 12)}' : '#$ref';
    final dateStr = _formatDate(donation['created_at'] ?? donation['createdAt']);
    final orderId = donation['order_id']?.toString() ?? donation['_id']?.toString() ?? '';
    final msgCtrl = TextEditingController();
    final msgs = _messages[orderId];

    Color borderColor = Colors.white;
    if (status == 'rejected') borderColor = _kRedBg;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status == 'rejected' ? _kRed.withOpacity(0.3) : _kGrey200),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatAmount(amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                Spacer(),
                _statusBadge(status),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _avatarColor(name),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: _kGrey900, fontSize: 14)),
                      Text(phone, style: TextStyle(color: _kBlue, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 13, color: _kGrey400),
                SizedBox(width: 4),
                Text(dateStr, style: TextStyle(color: _kGrey500, fontSize: 12)),
                Spacer(),
                Text(shortRef, style: TextStyle(color: _kGrey400, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
            SizedBox(height: 12),
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(donation),
                      style: OutlinedButton.styleFrom(foregroundColor: _kRed, side: BorderSide(color: _kRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text('Kataa'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(donation),
                      style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text('Idhinisha'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              TextButton.icon(
                onPressed: () async {
                  if (msgs == null) await _loadMessages(orderId);
                },
                icon: Icon(Icons.sms_outlined, size: 16, color: _kBlue),
                label: Text('SMS', style: TextStyle(color: _kBlue)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ] else if (status == 'rejected') ...[
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      if (msgs == null) await _loadMessages(orderId);
                    },
                    icon: Icon(Icons.sms_outlined, size: 16, color: _kBlue),
                    label: Text('SMS', style: TextStyle(color: _kBlue)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                  SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      if (msgs == null) await _loadMessages(orderId);
                    },
                    icon: Icon(Icons.chat_bubble_outline, size: 16, color: _kBlue),
                    label: Text('Funga mazungumzo', style: TextStyle(color: _kBlue)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ],
              ),
              if (msgs != null) ...[
                Divider(color: _kGrey200),
                Text('Mazungumzo', style: TextStyle(fontWeight: FontWeight.bold, color: _kGrey700, fontSize: 13)),
                SizedBox(height: 6),
                if (msgs.isEmpty)
                  Text('Hakuna ujumbe.', style: TextStyle(color: _kGrey500, fontSize: 12))
                else
                  ...msgs.map((m) => Container(
                    margin: EdgeInsets.only(bottom: 6),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(8)),
                    child: Text(m['message']?.toString() ?? '', style: TextStyle(color: _kGrey700, fontSize: 13)),
                  )),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: msgCtrl,
                        decoration: InputDecoration(
                          hintText: 'Andika jibu...',
                          hintStyle: TextStyle(color: _kGrey400, fontSize: 13),
                          filled: true,
                          fillColor: _kGrey100,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kGrey200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kGrey200)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (msgCtrl.text.trim().isEmpty) return;
                        await _sendMessage(donation, msgCtrl.text.trim());
                        msgCtrl.clear();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), minimumSize: Size(48, 40)),
                      child: Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    if (status == 'approved') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _kGreenBg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 13, color: _kGreen),
            SizedBox(width: 4),
            Text('Imeidhinishwa', style: TextStyle(color: _kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    } else if (status == 'pending') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _kAmberBg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 13, color: _kAmber),
            SizedBox(width: 4),
            Text('Inasubiri', style: TextStyle(color: _kAmber, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _kRedBg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 13, color: _kRed),
            SizedBox(width: 4),
            Text('Imekataliwa', style: TextStyle(color: _kRed, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
  }
}
