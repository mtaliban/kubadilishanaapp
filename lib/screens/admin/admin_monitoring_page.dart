import 'package:flutter/material.dart';
import 'admin_theme.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kAmber   = Color(0xFFD97706);
const _kRed     = Color(0xFFDC2626);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);

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
    // SILENT REFRESH: spinner TU wakati orodha bado tupu — refresh (na
    // clear events) haikati mtumiaji wala kurudisha scroll.
    final first = _events.isEmpty && _loading;
    setState(() {
      if (first) _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminGetMonitoring();
      if (!mounted) return;
      final data = res.data;
      setState(() {
        if (data is List) {
          _events = data;
        } else if (data is Map && data['events'] is List) {
          _events = data['events'] as List;
        } else {
          _events = [];
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyError(e); });
    }
  }

  Color _dotColor(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'error': return _kRed;
      case 'warning': return _kAmber;
      case 'success': return _kGreen;
      default: return _kBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Color(0xFF0F172A)
          : Ad.card(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Ad.blueSoft(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.monitor_heart_outlined, color: _kBlue, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Moni', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Ad.ink(context))),
                      Text('Matukio ya mfumo', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Ad.muted(context))),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: _kBlue),
                  onPressed: _load,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Ad.border(context)),
          if (_loading && _events.isEmpty)
            Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: _kRed, size: 48),
                    SizedBox(height: 12),
                    Text('Kosa la kupakia', style: TextStyle(color: Ad.muted(context))),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: Icon(Icons.refresh),
                      label: Text('Jaribu tena'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue, foregroundColor: Ad.card(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_events.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, color: Ad.muted(context), size: 48),
                    SizedBox(height: 12),
                    Text('Hakuna matukio', style: TextStyle(color: Ad.muted(context))),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _events.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = asMap(_events[i]);
                    final type = e['event_type'] as String? ?? e['type'] as String? ?? '';
                    final desc = e['description'] as String? ?? e['message'] as String? ?? type;
                    final ts = e['created_at'] as String? ?? e['timestamp'] as String? ?? '';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Ad.card(context),
                        border: Border.all(color: Ad.border(context)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10, height: 10,
                            margin: const EdgeInsets.only(top: 4, right: 10),
                            decoration: BoxDecoration(
                              color: _dotColor(type),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(desc,
                                    style: TextStyle(fontSize: 13, color: Ad.inkStrong(context))),
                                if (ts.isNotEmpty) ...[
                                  SizedBox(height: 4),
                                  Text(ts,
                                      style: TextStyle(fontSize: 11, color: Ad.muted(context))),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
