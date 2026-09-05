/// Admin reports page — revenue, user trends, match trends.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  Map<String, dynamic> _reports = {};
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/reports', queryParameters: {'days': _days});
      setState(() { _reports = res.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Period selector
          Row(
            children: [7, 30, 90, 365].map((d) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${d}s', style: const TextStyle(fontSize: 12)),
                selected: _days == d,
                onSelected: (_) { setState(() => _days = d); _load(); },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _days == d ? Colors.white : null),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          // Revenue card
          _card('Mapato', [
            _row('Jumla ya Malipo', 'TZS ${_reports['total_revenue'] ?? 0}'),
            _row('Malipo Yaliyokubaliwa', '${_reports['approved_payments'] ?? 0}'),
            _row('Malipo Yakataliwa', '${_reports['rejected_payments'] ?? 0}'),
          ]),
          const SizedBox(height: 12),
          // Users card
          _card('Watumiaji', [
            _row('Watumiaji Wote', '${_reports['total_users'] ?? 0}'),
            _row('Wapya wiki hii', '${_reports['new_users_week'] ?? 0}'),
            _row('Waliolipia', '${_reports['verified_users'] ?? 0}'),
          ]),
          const SizedBox(height: 12),
          // Matches card
          _card('Mikataba', [
            _row('Mikataba Yote', '${_reports['total_matches'] ?? 0}'),
            _row('Wiki hii', '${_reports['matches_week'] ?? 0}'),
          ]),
          const SizedBox(height: 12),
          // Feedback card
          _card('Maoni', [
            _row('Maoni Yote', '${_reports['total_feedback'] ?? 0}'),
            _row('Malalamiko', '${_reports['total_complaints'] ?? 0}'),
            _row('Mapendekezo', '${_reports['total_suggestions'] ?? 0}'),
          ]),
          const SizedBox(height: 12),
          // Top regions
          if (_reports['top_regions'] != null) ...[
            const Text('Mikoa Inayoongoza', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...((_reports['top_regions'] as List?) ?? []).map((r) => Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, size: 18),
                title: Text(r['name'] ?? '', style: const TextStyle(fontSize: 14)),
                trailing: Text('${r['count'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
