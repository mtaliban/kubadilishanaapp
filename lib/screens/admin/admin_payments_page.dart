/// Admin payments page — view and approve/reject pending payments.
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
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get(
        '/payments/admin/list',
        queryParameters: {'status': _filter},
      );
      setState(() {
        _payments = res.data is List ? res.data : (res.data['payments'] ?? []);
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
          child: Row(
            children: [
              _tab('pending', 'Inasubiri'),
              _tab('approved', 'Imekubaliwa'),
              _tab('rejected', 'Imekataliwa'),
              _tab('all', 'Zote'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _payments.isEmpty
                      ? const Center(child: Text('Hakuna malipo', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _payments.length,
                          itemBuilder: (context, i) => _paymentTile(_payments[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _paymentTile(Map<String, dynamic> p) {
    final status = p['status'] ?? 'pending';
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
                Text('TZS ${p['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 4),
            Text(p['user_name'] ?? '', style: const TextStyle(fontSize: 13)),
            Text(p['phone'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(p['created_at'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            if (status == 'pending') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approve(p),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Thibitisha'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _reject(p),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Kataa'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
      case 'approved': color = AppColors.success; label = '✓ Imekubaliwa'; break;
      case 'rejected': color = AppColors.error; label = '✗ Imekataliwa'; break;
      default: color = AppColors.warning; label = '⏳ Inasubiri';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tab(String filter, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _filter == filter,
        onSelected: (_) { setState(() => _filter = filter); _load(); },
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: _filter == filter ? Colors.white : null),
      ),
    );
  }

  Future<void> _approve(Map<String, dynamic> p) async {
    try {
      await ApiService().post('/payments/admin/${p['_id']}/approve');
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _reject(Map<String, dynamic> p) async {
    try {
      await ApiService().post('/payments/admin/${p['_id']}/reject');
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }
}
