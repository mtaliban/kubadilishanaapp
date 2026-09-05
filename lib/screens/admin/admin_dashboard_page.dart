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
      setState(() {
        _stats = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Backend returns: {totals: {users, users_health, users_education,
  //   users_verified, users_active_7d, matches, matches_24h,
  //   events, events_24h, messages, calls}, by_cadre, by_region, events_by_type}
  Map<String, dynamic> get _totals =>
      (_stats['totals'] as Map<String, dynamic>?) ?? {};

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final byRegion = (_stats['by_region'] as List?) ?? [];
    final byCadre = (_stats['by_cadre'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _statsGrid([
            _stat('Watumiaji', '${_totals['users'] ?? 0}',
                Icons.people, AppColors.primary),
            _stat('Waliolipia', '${_totals['users_verified'] ?? 0}',
                Icons.check_circle, AppColors.success),
            _stat('Mikataba', '${_totals['matches'] ?? 0}',
                Icons.swap_horiz, Colors.purple),
            _stat('Mikataba (24h)', '${_totals['matches_24h'] ?? 0}',
                Icons.timeline, Colors.indigo),
            _stat('Afya', '${_totals['users_health'] ?? 0}',
                Icons.local_hospital, AppColors.error),
            _stat('Elimu', '${_totals['users_education'] ?? 0}',
                Icons.school, AppColors.info),
            _stat('Mawasiliano', '${_totals['calls'] ?? 0}',
                Icons.phone_in_talk, Colors.teal),
            _stat('Hai (7 siku)', '${_totals['users_active_7d'] ?? 0}',
                Icons.online_prediction, AppColors.warning),
          ]),
          const SizedBox(height: 12),

          // Quick info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Taarifa za Haraka',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _quickInfo('Majukumu (events jumla)',
                      '${_totals['events'] ?? 0}'),
                  _quickInfo('Majukumu (24h)',
                      '${_totals['events_24h'] ?? 0}'),
                  _quickInfo('Ujumbe wote',
                      '${_totals['messages'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Top regions
          if (byRegion.isNotEmpty) ...[
            const Text('Mikoa Inayoongoza',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...byRegion.take(5).map((r) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on,
                        size: 18, color: AppColors.primary),
                    title: Text(r['region'] ?? '',
                        style: const TextStyle(fontSize: 14)),
                    trailing: Text('${r['count'] ?? 0}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
          const SizedBox(height: 12),

          // Top cadres
          if (byCadre.isNotEmpty) ...[
            const Text('Kada Inayoongoza',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...byCadre.take(5).map((c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge,
                        size: 18, color: AppColors.primary),
                    title: Text(
                        '${c['cadre'] ?? ''} (${c['category'] ?? ''})',
                        style: const TextStyle(fontSize: 14)),
                    trailing: Text('${c['count'] ?? 0}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
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

  Widget _stat(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
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
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
