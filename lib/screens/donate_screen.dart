import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';

const _kAdminCall = '0763795801';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});
  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  String _adminPhone = '';
  String _currency = 'TZS';

  final _amountCtrl = TextEditingController(text: '5000');
  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();

  List<dynamic> _history = [];
  String _historyFilter = '';
  bool _loadingHistory = true;
  bool _sending = false;
  bool _sent = false;
  bool _copied = false;
  String _error = '';

  Map<String, dynamic>? _flash;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadHistory();
    _setupRealtime();
    final auth = context.read<AuthProvider>();
    _phoneCtrl.text = auth.user?.phone ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final res = await ApiService().getDonationInfo();
      final d = res.data as Map<String, dynamic>;
      if (mounted) setState(() {
        _adminPhone = d['phone'] as String? ?? _kAdminCall;
        _currency = d['currency'] as String? ?? 'TZS';
      });
    } catch (_) {
      if (mounted) setState(() => _adminPhone = _kAdminCall);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiService().getPaymentHistory();
      final data = res.data;
      if (mounted) setState(() {
        if (data is Map) {
          _history = data['items'] ?? data['payments'] ?? [];
        } else if (data is List) {
          _history = data;
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  void _setupRealtime() {
    final ws = WebSocketService();
    ws.on('notification', (payload) {
      final type = payload['type'] ?? '';
      if (type == 'payment.approved') {
        _setFlash({'type': 'success', 'msg': '✓ Malipo yamethibitishwa'});
        _loadHistory();
      } else if (type == 'payment.rejected') {
        _setFlash({'type': 'info', 'msg': '✗ Malipo yamekataliwa'});
        _loadHistory();
      } else if (type == 'payment.reply' || type == 'payment.submitted') {
        _loadHistory();
      }
    });
  }

  void _setFlash(Map<String, dynamic> f) {
    if (!mounted) return;
    setState(() => _flash = f);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _copyPhone() {
    Clipboard.setData(ClipboardData(text: _adminPhone));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final sms = _smsCtrl.text.trim();

    if (amount < 500) { setState(() => _error = 'Kiwango lazima kiwe angalau 500'); return; }
    if (sms.length < 3) { setState(() => _error = 'Weka nakala ya SMS ya mtandao'); return; }

    setState(() => _sending = true);
    try {
      await ApiService().createDonation(
          amount: amount, smsText: sms,
          phone: _phoneCtrl.text.trim(), purpose: 'donation');
      if (mounted) {
        setState(() { _sent = true; _sending = false; });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) { setState(() { _sent = false; _smsCtrl.clear(); }); _loadHistory(); }
      }
    } catch (e) {
      if (mounted) setState(() { _error = _parseError(e); _sending = false; });
    }
  }

  String _parseError(dynamic e) {
    try {
      final detail = (e as dynamic).response?.data?['detail'];
      if (detail is String) return detail;
    } catch (_) {}
    return 'Imeshindikana — jaribu tena';
  }

  List<dynamic> get _filteredHistory => _historyFilter.isEmpty
      ? _history : _history.where((p) => p['status'] == _historyFilter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.volunteer_activism, size: 20, color: AppColors.error),
          SizedBox(width: 8),
          Text('Changia'),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Flash
            if (_flash != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _flash!['type'] == 'success' ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _flash!['type'] == 'success' ? Colors.green.shade200 : Colors.blue.shade200),
                ),
                child: Text('${_flash!['msg']}', style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13,
                  color: _flash!['type'] == 'success' ? Colors.green.shade800 : Colors.blue.shade800)),
              ),

            // Admin phone card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('LIPIA NAMBA HII', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(_adminPhone.isEmpty ? '...' : _adminPhone,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  const Text('Piga simu kwanza, kisha tuma SMS ya uthibitisho',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ])),
                OutlinedButton.icon(
                  onPressed: _copyPhone,
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 14,
                      color: _copied ? Colors.white : AppColors.primary),
                  label: Text(_copied ? 'Imenakiliwa' : 'Nakili',
                      style: TextStyle(fontSize: 12, color: _copied ? Colors.white : AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _copied ? AppColors.primary : null,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // Donation form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Kiasi ($_currency)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountCtrl, keyboardType: TextInputType.number,
                      enabled: !_sending && !_sent,
                      decoration: InputDecoration(hintText: '5000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
                    ),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Namba ya Simu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneCtrl, keyboardType: TextInputType.phone,
                      enabled: !_sending && !_sent,
                      decoration: InputDecoration(hintText: '0712345678',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
                    ),
                  ])),
                ]),
                const SizedBox(height: 12),
                const Text('Nakala ya SMS ya Mtandao', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _smsCtrl, maxLines: 4,
                  enabled: !_sending && !_sent,
                  onChanged: (_) => setState(() => _error = ''),
                  decoration: InputDecoration(
                    hintText: 'C2H8MZ3JX1 Confirmed. You have received TZS 5,000.00 from JOHN KAMWENDA...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: (_sending || _sent) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_sent ? '✓ Imetumwa' : 'Tuma Ombi', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // History header
            Row(children: [
              const Text('Historia ya Michango', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text('(${_filteredHistory.length})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 8),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in [['', 'Zote'], ['verifying', 'Inasubiri'], ['approved', 'Imeidhinishwa'], ['rejected', 'Imekataliwa']])
                  Padding(padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f[1], style: const TextStyle(fontSize: 11)),
                      selected: _historyFilter == f[0],
                      onSelected: (_) => setState(() => _historyFilter = f[0]),
                    )),
              ]),
            ),
            const SizedBox(height: 8),

            if (_loadingHistory)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_filteredHistory.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Hakuna michango bado', style: TextStyle(color: AppColors.textSecondary)),
              ))
            else ..._filteredHistory.map((p) => _PaymentCard(payment: p)),

            const SizedBox(height: 60),
          ]),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final dynamic payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final status = payment['status'] ?? 'verifying';
    final amount = payment['amount'];
    final note = payment['admin_note'] ?? payment['reply'] ?? '';
    final iso = payment['created_at'] ?? '';

    Color sc; String sl;
    if (status == 'approved') { sc = Colors.green; sl = '✓ Imeidhinishwa'; }
    else if (status == 'rejected') { sc = AppColors.error; sl = '✗ Imekataliwa'; }
    else { sc = const Color(0xFFD97706); sl = '⏳ Inasubiri'; }

    String ago = '';
    try {
      if (iso.isNotEmpty) {
        final d = DateTime.parse(iso).toLocal();
        final diff = DateTime.now().difference(d);
        if (diff.inMinutes < 1) ago = 'Sasa hivi';
        else if (diff.inMinutes < 60) ago = 'dakika ${diff.inMinutes} iliyopita';
        else if (diff.inHours < 24) ago = 'saa ${diff.inHours} iliyopita';
        else ago = 'siku ${diff.inDays} iliyopita';
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.withOpacity(0.3))),
            child: Text(sl, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sc)),
          ),
          const Spacer(),
          if (amount != null)
            Text('TZS $amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.4), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Jibu la Admin', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text('$note', style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ],
        if (ago.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6),
            child: Text(ago, style: const TextStyle(fontSize: 10, color: AppColors.textLight))),
      ]),
    );
  }
}
