/// Admin monitoring page — system status, traffic, and performance metrics.
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminMonitoringPage extends StatefulWidget {
  const AdminMonitoringPage({super.key});
  @override
  State<AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<AdminMonitoringPage> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('/admin/monitoring');
      if (mounted) {
        setState(() {
          _data = (res.data is Map<String, dynamic>)
              ? res.data as Map<String, dynamic>
              : {};
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatUptime(dynamic seconds) {
    if (seconds == null) return '—';
    final s = (seconds is num) ? seconds.toInt() : int.tryParse('$seconds') ?? 0;
    final d = s ~/ 86400;
    final h = (s % 86400) ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${d}d ${h}h ${m}m';
  }

  Widget _statusChip(String label, dynamic status) {
    final isOk = status != null &&
        status.toString().toLowerCase() != 'error' &&
        status.toString().toLowerCase() != 'down' &&
        status.toString().toLowerCase() != 'false';
    return Chip(
      avatar: Icon(
        isOk ? Icons.check_circle : Icons.error,
        size: 16,
        color: Colors.white,
      ),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: isOk ? AppColors.success : AppColors.error,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // System status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.health_and_safety,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text('Hali ya Mfumo',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _statusChip('Database', _data['db_status']),
                            _statusChip('Redis', _data['redis_status']),
                            _statusChip('MQTT', _data['mqtt_status']),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Traffic card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.show_chart,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text('Trafiki',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 20),
                        _statRow('Watumiaji Hai',
                            '${_data['active_users'] ?? 0}'),
                        _statRow('Maombi Leo',
                            '${_data['total_requests_today'] ?? 0}'),
                        _statRow('Makosa Leo',
                            '${_data['errors_today'] ?? 0}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Performance card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            const Text('Utendaji',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 20),
                        _statRow('Muda wa Wastani',
                            '${_data['avg_response_ms'] ?? 0} ms'),
                        _statRow('Uptime',
                            _formatUptime(_data['uptime_seconds'])),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Inasasisha kila sekunde 30',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
          );
  }
}
