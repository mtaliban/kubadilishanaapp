/// Admin monitoring page — system status, traffic, and performance metrics.
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kBlue200   = Color(0xFFBFDBFE);
const _kGrey50    = Color(0xFFF9FAFB);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey700   = Color(0xFF374151);
const _kGrey900   = Color(0xFF111827);
const _kGreenDk   = Color(0xFF16A34A);
const _kGreen50   = Color(0xFFF0FDF4);
const _kGreen200  = Color(0xFFBBF7D0);
const _kRed       = Color(0xFFDC2626);
const _kRed50     = Color(0xFFFEF2F2);
const _kRed200    = Color(0xFFFECACA);
const _kAmber50   = Color(0xFFFFFBEB);
const _kAmber200  = Color(0xFFFDE68A);
const _kAmber700  = Color(0xFFB45309);

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

  bool _isStatusOk(dynamic status) =>
      status != null &&
      status.toString().toLowerCase() != 'error' &&
      status.toString().toLowerCase() != 'down' &&
      status.toString().toLowerCase() != 'false';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.monitor_heart_rounded, size: 20, color: _kBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ufuatiliaji',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kGrey900)),
              Text('Hali ya mfumo na utendaji',
                style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
            GestureDetector(
              onTap: _load,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kGrey50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kGrey200),
                ),
                child: const Center(child: Icon(Icons.refresh_rounded, size: 18, color: _kGrey700)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: _kGrey100),

        // ── Content ──
        Expanded(
          child: _loading
              ? const Center(child: SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kBlue,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                    children: [
                      // ── System Status ──
                      _SectionLabel(label: 'Hali ya Mfumo'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _StatusChip(
                          label: 'Database',
                          status: _data['db_status'],
                          icon: Icons.storage_rounded,
                          ok: _isStatusOk(_data['db_status']),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _StatusChip(
                          label: 'Redis',
                          status: _data['redis_status'],
                          icon: Icons.memory_rounded,
                          ok: _isStatusOk(_data['redis_status']),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _StatusChip(
                          label: 'MQTT',
                          status: _data['mqtt_status'],
                          icon: Icons.wifi_rounded,
                          ok: _isStatusOk(_data['mqtt_status']),
                        )),
                      ]),
                      const SizedBox(height: 16),

                      // ── Traffic ──
                      _SectionLabel(label: 'Trafiki'),
                      const SizedBox(height: 8),
                      _InfoCard(children: [
                        _StatRow(
                          label: 'Watumiaji Hai',
                          value: '${_data['active_users'] ?? 0}',
                          icon: Icons.people_rounded,
                          color: _kBlue,
                        ),
                        _StatRow(
                          label: 'Maombi Leo',
                          value: '${_data['total_requests_today'] ?? 0}',
                          icon: Icons.bar_chart_rounded,
                          color: _kGreenDk,
                        ),
                        _StatRow(
                          label: 'Makosa Leo',
                          value: '${_data['errors_today'] ?? 0}',
                          icon: Icons.warning_amber_rounded,
                          color: _kRed,
                          isLast: true,
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // ── Performance ──
                      _SectionLabel(label: 'Utendaji'),
                      const SizedBox(height: 8),
                      _InfoCard(children: [
                        _StatRow(
                          label: 'Muda wa Wastani',
                          value: '${_data['avg_response_ms'] ?? 0} ms',
                          icon: Icons.speed_rounded,
                          color: _kAmber700,
                        ),
                        _StatRow(
                          label: 'Uptime',
                          value: _formatUptime(_data['uptime_seconds']),
                          icon: Icons.timer_outlined,
                          color: _kBlue,
                          isLast: true,
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // ── Auto-refresh notice ──
                      Center(child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kBlue50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _kBlue200),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.refresh_rounded, size: 12, color: _kBlue),
                          SizedBox(width: 5),
                          Text('Inasasisha kila sekunde 30',
                            style: TextStyle(fontSize: 11, color: _kBlue, fontWeight: FontWeight.w500)),
                        ]),
                      )),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _kGrey700),
  );
}

// ── Info card container ────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kGrey200),
      boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: Column(children: children),
  );
}

// ── Stat row ───────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isLast;
  const _StatRow({
    required this.label, required this.value,
    required this.icon, required this.color,
    this.isLast = false,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
            style: const TextStyle(fontSize: 13, color: _kGrey700))),
          Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
        ]),
      ),
      if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14, color: _kGrey100),
    ],
  );
}

// ── Status chip ────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final dynamic status;
  final IconData icon;
  final bool ok;
  const _StatusChip({required this.label, required this.status, required this.icon, required this.ok});

  @override
  Widget build(BuildContext context) {
    final bg     = ok ? _kGreen50  : _kRed50;
    final border = ok ? _kGreen200 : _kRed200;
    final color  = ok ? _kGreenDk  : _kRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(
              ok ? 'Online' : 'Offline',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
          const SizedBox(height: 4),
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
