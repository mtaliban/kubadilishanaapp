/// Call/contact history screen — lists all logged contacts (/messages/calls).
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<dynamic> _allCalls = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  String _filter = 'Zote';

  static const _filters = ['Zote', 'Simu', 'SMS', 'WhatsApp'];

  void _onWs(dynamic _) {
    if (mounted) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Mtumiaji akipigiwa simu/SMS/WhatsApp, historia inajisasisha PAPO HAPO
    WebSocketService().on('contact.activity', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('contact.activity', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().getCallHistory();
      // Backend returns a plain list [], not a map {calls: [...]}
      final raw = res.data;
      final calls = raw is List ? raw : <dynamic>[];
      if (mounted) {
        setState(() {
          _allCalls = calls;
          _applyFilter(_filter);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applyFilter(String filter) {
    _filter = filter;
    if (filter == 'Zote') {
      _filtered = List.from(_allCalls);
    } else {
      final typeKey = _swahiliToType(filter);
      _filtered =
          _allCalls.where((c) => c['contact_type'] == typeKey).toList();
    }
  }

  String _swahiliToType(String swahili) {
    switch (swahili) {
      case 'Simu':
        return 'call';
      case 'SMS':
        return 'sms';
      case 'WhatsApp':
        return 'whatsapp';
      default:
        return swahili.toLowerCase();
    }
  }

  String _typeToSwahili(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return 'Simu';
      case 'sms':
        return 'SMS';
      case 'whatsapp':
        return 'WhatsApp';
      default:
        return type;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return Icons.phone;
      case 'sms':
        return Icons.sms;
      case 'whatsapp':
        return Icons.chat;
      default:
        return Icons.contact_phone;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'call':
        return Colors.green;
      case 'sms':
        return Colors.blue;
      case 'whatsapp':
        return const Color(0xFF25D366);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kGrey100,
                borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.arrow_back, size: 18, color: _kGrey900))),
          ),
        ),
        title: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _kBlue50,
              borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Icon(Icons.history_rounded, size: 22, color: _kBlue)),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Historia ya Mawasiliano',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kGrey900, height: 1.2)),
            Text('Simu, SMS na WhatsApp zako', style: TextStyle(fontSize: 11, color: _kGrey500)),
          ]),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kGrey200),
        ),
      ),
      body: Column(
        children: [
          // Filter row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: _filters.map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _applyFilter(f)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? _kBlue : _kGrey100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? _kBlue : _kGrey200,
                        ),
                      ),
                      child: Text(f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _kGrey500)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(height: 1, color: _kGrey200),

          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(16)),
                              child: const Center(child: Icon(Icons.error_outline, size: 26, color: Color(0xFFDC2626))),
                            ),
                            const SizedBox(height: 14),
                            const Text('Hitilafu ya kuunganisha',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey700)),
                            const SizedBox(height: 4),
                            Text(_error!,
                                style: const TextStyle(fontSize: 11, color: _kGrey400),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Jaribu Tena'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBlue, foregroundColor: Colors.white,
                                minimumSize: const Size(140, 44),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? _EmptyState(filter: _filter)
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final call = _filtered[i];
                                  return _CallCard(
                                    call: call,
                                    iconForType: _iconForType,
                                    colorForType: _colorForType,
                                    typeToSwahili: _typeToSwahili,
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

class _CallCard extends StatelessWidget {
  final dynamic call;
  final IconData Function(String) iconForType;
  final Color Function(String) colorForType;
  final String Function(String) typeToSwahili;

  const _CallCard({
    required this.call,
    required this.iconForType,
    required this.colorForType,
    required this.typeToSwahili,
  });

  @override
  Widget build(BuildContext context) {
    final direction = call['direction']?.toString() ?? 'out';
    final withName = call['with_full_name']?.toString() ?? 'Mtumiaji';
    final contactType = call['contact_type']?.toString() ?? 'call';
    final initiatedAt = call['initiated_at']?.toString() ?? '';

    final dateStr = initiatedAt.contains('T')
        ? initiatedAt.split('T').first
        : initiatedAt;

    final icon = iconForType(contactType);
    final color = colorForType(contactType);
    final swahiliType = typeToSwahili(contactType);
    final isOut = direction == 'out';
    final dirIcon = isOut ? Icons.call_made : Icons.call_received;
    final dirColor = isOut ? const Color(0xFF1D4ED8) : const Color(0xFF16A34A);
    final dirLabel = isOut ? 'Ilitoka' : 'Iliingia';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGrey200),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
          child: Center(child: Icon(icon, color: color, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(withName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900),
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Icon(dirIcon, size: 11, color: dirColor),
            const SizedBox(width: 3),
            Text('$dirLabel · $swahiliType',
              style: const TextStyle(fontSize: 11, color: _kGrey500)),
          ]),
        ])),
        if (dateStr.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kGrey100,
              borderRadius: BorderRadius.circular(8)),
            child: Text(dateStr,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kGrey500)),
          ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _kGrey100,
                  borderRadius: BorderRadius.circular(18)),
                child: const Center(child: Icon(Icons.history_rounded, size: 28, color: _kGrey400)),
              ),
              const SizedBox(height: 16),
              Text(
                filter == 'Zote'
                    ? 'Hakuna historia ya mawasiliano'
                    : 'Hakuna rekodi za $filter',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kGrey700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text('Mawasiliano yako yataonekana hapa',
                style: TextStyle(fontSize: 12, color: _kGrey400),
                textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}
