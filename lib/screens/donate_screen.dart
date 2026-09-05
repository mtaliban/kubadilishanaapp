/// Donate screen — manual SMS verification payment flow + history tab.
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen>
    with SingleTickerProviderStateMixin {
  // status: idle | sending | processing | confirmed | failed
  String _status = 'idle';
  String _orderId = '';
  int _amount = 2000;
  String? _error;
  Map<String, dynamic>? _donationInfo;
  bool _infoLoading = true;

  // History tab
  late TabController _tabCtrl;
  List<dynamic> _history = [];
  bool _historyLoading = false;
  String _histFilter = 'all';

  final _smsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 1 && _history.isEmpty) _loadHistory();
    });
    _loadInfo();
    _setupWS();
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    try {
      final res = await ApiService().getPaymentHistory();
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _history = data['payments'] ?? data['items'] ?? [];
        _historyLoading = false;
      });
    } catch (_) {
      setState(() => _historyLoading = false);
    }
  }

  Future<void> _loadInfo() async {
    try {
      final res = await ApiService().getDonationInfo();
      setState(() {
        _donationInfo = res.data as Map<String, dynamic>?;
        _infoLoading = false;
      });
    } catch (_) {
      setState(() => _infoLoading = false);
    }
  }

  void _setupWS() {
    final ws = WebSocketService();
    ws.on('payment.approved', (event) {
      if (event['order_id'] == _orderId || event['data']?['order_id'] == _orderId) {
        if (!mounted) return;
        setState(() => _status = 'confirmed');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Malipo yamethibitishwa!'),
            backgroundColor: AppColors.success));
        Timer(const Duration(seconds: 3), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        });
      }
    });
    ws.on('payment.rejected', (event) {
      if (event['order_id'] == _orderId || event['data']?['order_id'] == _orderId) {
        if (mounted) setState(() => _status = 'failed');
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Michango'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.payment), text: 'Lipa'),
            Tab(icon: Icon(Icons.history), text: 'Historia'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _infoLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16), child: _buildBody()),
          _buildHistory(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_status == 'confirmed') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          const SizedBox(height: 16),
          const Text('Umefanikiwa!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success)),
          const SizedBox(height: 8),
          const Text('Malipo yako yamethibitishwa. Utapelekwa Dashboard...'),
        ],
      );
    }

    if (_status == 'failed') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.error, size: 80, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('Umekataliwa',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error)),
          const SizedBox(height: 8),
          const Text('Mchango wako umekataliwa. Wasiliana na admin.'),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: () => setState(() => _status = 'idle'),
              child: const Text('Jaribu Tena')),
        ],
      );
    }

    final phone = _donationInfo?['phone'] ?? '0763795801';
    final currency = _donationInfo?['currency'] ?? 'TZS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step 1 — instructions
        Card(
          color: AppColors.primaryLight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hatua ya 1: Lipa',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 8),
                Text('Tuma $currency $_amount kwa namba hii:',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                SelectableText(
                  phone,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                const Text(
                    'M-Pesa / Tigo Pesa / Airtel Money / Halopesa',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Step 2 — paste SMS
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hatua ya 2: Bandika SMS ya Uthibitisho',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Baada ya kulipa, utapata SMS. Bandika ujumbe huo hapa:',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextField(
                  controller: _smsCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Mfano: Confirmed. TZS 2,000 sent to 0763795801 ...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Kiasi (TZS)',
                    prefixIcon: const Icon(Icons.attach_money),
                    hintText: '$_amount',
                  ),
                  onChanged: (v) =>
                      setState(() => _amount = int.tryParse(v) ?? 2000),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!,
                style:
                    const TextStyle(color: AppColors.error, fontSize: 13)),
          ),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                (_status == 'sending' || _status == 'processing')
                    ? null
                    : _submit,
            icon: _status == 'sending'
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_status == 'processing'
                ? 'Inashughulikiwa...'
                : 'Tuma Mchango'),
          ),
        ),

        if (_status == 'processing') ...[
          const SizedBox(height: 24),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Admin anathibitisha — subiri arifa...'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submit() async {
    final smsText = _smsCtrl.text.trim();
    if (smsText.length < 10) {
      setState(() => _error =
          'Bandika SMS yote ya uthibitisho (angalau herufi 10)');
      return;
    }

    setState(() {
      _status = 'sending';
      _error = null;
    });

    try {
      final res = await ApiService().createDonation(
        amount: _amount,
        smsText: smsText,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _orderId = data['order_id']?.toString() ?? '';
        _status = 'processing';
      });
    } catch (e) {
      String msg = 'Hitilafu — jaribu tena';
      try {
        final detail = (e as dynamic).response?.data?['detail'];
        if (detail is String) msg = detail;
      } catch (_) {}
      setState(() {
        _status = 'idle';
        _error = msg;
      });
    }
  }

  Widget _buildHistory() {
    final filtered = _histFilter == 'all'
        ? _history
        : _history.where((p) => (p['status'] ?? '') == _histFilter).toList();

    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _histChip('all', 'Zote'),
            _histChip('verifying', 'Inasubiri'),
            _histChip('approved', 'Imekubaliwa'),
            _histChip('rejected', 'Imekataliwa'),
          ]),
        ),
        Expanded(
          child: _historyLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long,
                              size: 48, color: AppColors.textLight),
                          const SizedBox(height: 12),
                          const Text('Hakuna historia ya malipo',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _histTile(filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _histChip(String val, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _histFilter == val,
        onSelected: (_) => setState(() => _histFilter = val),
        selectedColor: AppColors.primary,
        labelStyle:
            TextStyle(color: _histFilter == val ? Colors.white : null),
      ),
    );
  }

  Widget _histTile(Map<String, dynamic> p) {
    final status = p['status'] ?? '';
    final amount = p['amount'] ?? 0;
    final date = (p['created_at'] ?? '').toString().split('T').first;
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 28),
        title: Text('TZS ${amount.toString()}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          p['sms_text'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(status,
                style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.bold)),
            Text(date,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}
