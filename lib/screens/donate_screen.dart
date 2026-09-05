/// Donate screen — manual SMS verification payment flow.
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

class _DonateScreenState extends State<DonateScreen> {
  // status: idle | sending | processing | confirmed | failed
  String _status = 'idle';
  String _orderId = '';
  int _amount = 2000;
  String? _error;
  Map<String, dynamic>? _donationInfo;
  bool _infoLoading = true;

  final _smsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _setupWS();
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
    _smsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fanya Mchango')),
      body: _infoLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildBody(),
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
}
