/// Admin dashboard — stats overview.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../config/theme.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().onAny((_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().adminStats();
      setState(() { _stats = res.data; _loading = false; });
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
          _statsGrid([
            _stat('Watumiaji', '${_stats['total_users'] ?? 0}', Icons.people, AppColors.primary),
            _stat('Waliolipia', '${_stats['verified_users'] ?? 0}', Icons.check_circle, AppColors.success),
            _stat('Michango', 'TZS ${(_stats['total_donations'] ?? 0)}', Icons.payment, AppColors.warning),
            _stat('Malipo Pending', '${_stats['pending_payments'] ?? 0}', Icons.hourglass_empty, AppColors.info),
            _stat('Mikataba', '${_stats['total_matches'] ?? 0}', Icons.people, Colors.purple),
            _stat('Maoni', '${_stats['total_feedback'] ?? 0}', Icons.message, Colors.teal),
            _stat('Matangazo', '${_stats['total_announcements'] ?? 0}', Icons.campaign, Colors.orange),
            _stat('Nenosiri', '${_stats['pending_resets'] ?? 0}', Icons.lock_reset, Colors.brown),
          ]),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Taarifa za Haraka', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _quickInfo('Watumiaji Wapya (wiki hii)', '${_stats['new_users_week'] ?? 0}'),
                  _quickInfo('Michango ya Wiki', 'TZS ${_stats['donations_week'] ?? 0}'),
                  _quickInfo('Mitandao ya Leo', '${_stats['matches_today'] ?? 0}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(List<Widget> children) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2,
      children: children,
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
