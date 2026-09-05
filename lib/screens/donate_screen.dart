/// Donate screen — mobile money payment flow.
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
  String _status = 'idle'; // idle, sending, processing, confirmed, failed
  String _orderId = '';
  String _phone = '';
  int _amount = 2000;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupWS();
  }

  void _setupWS() {
    final ws = WebSocketService();
    ws.on('notification', (event) {
      if (event['type'] == 'payment.approved' && event['data']?['order_id'] == _orderId) {
        setState(() => _status = 'confirmed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Malipo yamethibitishwa!'), backgroundColor: AppColors.success));
        Timer(const Duration(seconds: 3), () {
          if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        });
      } else if (event['type'] == 'payment.rejected' && event['data']?['order_id'] == _orderId) {
        setState(() => _status = 'failed');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fanya Mchango')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status indicator
            if (_status == 'confirmed') ...[
              const Icon(Icons.check_circle, size: 80, color: AppColors.success),
              const SizedBox(height: 16),
              const Text('✓ Umelipa!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success)),
              const SizedBox(height: 8),
              const Text('Malipo yako yamethibitishwa. Utapelekwa Dashboard...'),
            ] else if (_status == 'failed') ...[
              const Icon(Icons.error, size: 80, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('✗ Umekataliwa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.error)),
              const SizedBox(height: 8),
              const Text('Mchango wako umekataliwa. Wasiliana na admin.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => setState(() => _status = 'idle'), child: const Text('Jaribu Tena')),
            ] else ...[
              // Payment form
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Maelezo ya Malipo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kiasi (TZS)',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        onChanged: (v) => _amount = int.tryParse(v) ?? 2000,
                      ),
                      const SizedBox(height: 12),
                      const Text('Mawasiliano', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _phoneOption('M-Pesa', '0763795801'),
                      _phoneOption('Tigo Pesa', '0763795801'),
                      _phoneOption('Airtel Money', '0763795801'),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                        ),
                      ElevatedButton(
                        onPressed: _status == 'sending' ? null : _submit,
                        child: _status == 'sending'
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_status == 'processing' ? 'Inashughulikiwa...' : 'Tuma Mchango'),
                      ),
                      if (_status == 'processing') ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Tafadhali subiri — admin anathibitisha...'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _phoneOption(String label, String phone) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Radio<String>(
        value: label,
        groupValue: _phone,
        onChanged: (v) => setState(() => _phone = v ?? ''),
        activeColor: AppColors.primary,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text('Lipa kwa $phone', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _status = 'sending';
      _error = null;
    });

    try {
      final res = await ApiService().createPayment({
        'amount': _amount,
        'phone': '0763795801',
        'method': 'mobile',
      });
      setState(() {
        _orderId = res.data['order_id'] ?? '';
        _status = 'processing';
      });
      // Start polling for status
      _pollStatus();
    } catch (e) {
      setState(() {
        _status = 'idle';
        _error = 'Hitilafu — jaribu tena';
      });
    }
  }

  void _pollStatus() async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (_status != 'processing') return;
      try {
        final res = await ApiService().getPaymentStatus(_orderId);
        final status = res.data['status'] ?? '';
        if (status == 'approved') {
          setState(() => _status = 'confirmed');
          Timer(const Duration(seconds: 3), () {
            if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
          });
          return;
        } else if (status == 'rejected') {
          setState(() => _status = 'failed');
          return;
        }
      } catch (_) {}
    }
  }
}
