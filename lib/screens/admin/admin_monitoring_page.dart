import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminMonitoringPage extends StatefulWidget {
  const AdminMonitoringPage({super.key});

  @override
  State<AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<AdminMonitoringPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminGetMonitoring();
      if (!mounted) return;
      final raw = res.data;
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map && raw['events'] != null) {
        items = raw['events'] as List<dynamic>;
      }
      setState(() {
        _events = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _dotColor(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'login':
      case 'register':
        return _kBlue;
      case 'payment':
        return _kGreen;
      case 'error':
        return _kRed;
      case 'match':
        return _kAmber;
      default:
        return _kGrey400;
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return raw.toString();
      final local = dt.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      return '${local.day}/${local.month} $hour:$min';
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kBlueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.monitor_heart_rounded, color: _kBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Moni', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kGrey900)),
                      Text('Shughuli za mfumo', style: TextStyle(fontSize: 13, color: _kGrey500)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kBlueBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, size: 16, color: _kBlue),
                          SizedBox(width: 6),
                          Text('Refresh', style: TextStyle(fontSize: 13, color: _kBlue, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(height: 1, color: _kGrey200),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kBlue))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: _kRed),
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: _kGrey700), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white),
                            child: const Text('Jaribu Tena'),
                          ),
                        ],
                      ),
                    )
                  : _events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monitor_heart_outlined, size: 56, color: _kGrey400),
                              const SizedBox(height: 12),
                              const Text('Hakuna shughuli', style: TextStyle(fontSize: 16, color: _kGrey500, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, i) {
                            final item = _events[i] as Map<String, dynamic>;
                            final type = item['event_type'] as String? ?? item['type'] as String?;
                            final description = item['description'] as String? ?? item['message'] as String? ?? type ?? 'Shughuli';
                            final createdAt = item['created_at'] ?? item['createdAt'] ?? item['timestamp'];
                            final dotColor = _dotColor(type);
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kGrey200),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                title: Text(
                                  description,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kGrey900),
                                ),
                                subtitle: type != null
                                    ? Text(
                                        type,
                                        style: const TextStyle(fontSize: 11, color: _kGrey500),
                                      )
                                    : null,
                                trailing: Text(
                                  _formatTime(createdAt),
                                  style: const TextStyle(fontSize: 11, color: _kGrey400),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
