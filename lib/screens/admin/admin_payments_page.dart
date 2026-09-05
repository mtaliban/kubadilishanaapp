/// Admin payments page — view and approve/reject donations.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  List<dynamic> _payments = [];
  bool _loading = true;
  // Backend statuses: verifying | approved | rejected | all
  String _filter = 'verifying';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().adminAllDonations(status: _filter);
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _payments = data['payments'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            _tab('verifying', 'Inasubiri'),
            _tab('approved', 'Imekubaliwa'),
            _tab('rejected', 'Imekataliwa'),
            _tab('all', 'Zote'),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _payments.isEmpty
                      ? const Center(
                          child: Text('Hakuna malipo',
                              style: TextStyle(
                                  color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _payments.length,
                          itemBuilder: (context, i) =>
                              _paymentTile(_payments[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _paymentTile(Map<String, dynamic> p) {
    final status = p['status'] ?? 'verifying';
    final isPending = status == 'verifying';
    final id = (p['_id'] ?? p['order_id'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TZS ${p['amount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 4),
            Text(p['user_name'] ?? p['full_name'] ?? '',
                style: const TextStyle(fontSize: 13)),
            Text(p['phone'] ?? p['phone_primary'] ?? '',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            if (p['sms_text'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  p['sms_text'].toString().length > 80
                      ? '${p['sms_text'].toString().substring(0, 80)}...'
                      : p['sms_text'].toString(),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic),
                ),
              ),
            Text(
              (p['created_at'] ?? '').toString().split('T').first,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textLight),
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Thibitisha'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reject(id),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Kataa'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = AppColors.success;
        label = '✓ Imekubaliwa';
        break;
      case 'rejected':
        color = AppColors.error;
        label = '✗ Imekataliwa';
        break;
      default:
        color = AppColors.warning;
        label = '⏳ Inasubiri';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _tab(String filter, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _filter == filter,
        onSelected: (_) {
          setState(() => _filter = filter);
          _load();
        },
        selectedColor: AppColors.primary,
        labelStyle:
            TextStyle(color: _filter == filter ? Colors.white : null),
      ),
    );
  }

  Future<void> _approve(String id) async {
    try {
      await ApiService().adminApproveDonation(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Malipo yamekubaliwa!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _reject(String id) async {
    try {
      await ApiService().adminRejectDonation(id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Malipo yamekataliwa'),
            backgroundColor: AppColors.warning));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }
}
