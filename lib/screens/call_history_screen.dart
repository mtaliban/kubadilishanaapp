/// Call/contact history screen — lists all logged contacts (/messages/calls).
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

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
      appBar: AppBar(
        title: const Text('Historia ya Mawasiliano'),
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: _filters.map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _applyFilter(f));
                    },
                    selectedColor: AppColors.primaryLight,
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text('Hitilafu: $_error',
                                style: const TextStyle(
                                    color: AppColors.textSecondary),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _load,
                                child: const Text('Jaribu Tena')),
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
    // Backend returns: direction ("out"/"in"), with_full_name, contact_type, initiated_at
    final direction = call['direction']?.toString() ?? 'out';
    final withName = call['with_full_name']?.toString() ?? 'Mtumiaji';
    final contactType = call['contact_type']?.toString() ?? 'call';
    final initiatedAt = call['initiated_at']?.toString() ?? '';

    // Show date only (strip time)
    final dateStr = initiatedAt.contains('T')
        ? initiatedAt.split('T').first
        : initiatedAt;

    final icon = iconForType(contactType);
    final color = colorForType(contactType);
    final swahiliType = typeToSwahili(contactType);
    final dirIcon = direction == 'out' ? Icons.call_made : Icons.call_received;
    final dirColor = direction == 'out' ? Colors.blue : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(children: [
          Icon(dirIcon, size: 14, color: dirColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              withName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        subtitle: Text(
          swahiliType,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Text(
          dateStr,
          style: const TextStyle(
              fontSize: 11, color: AppColors.textLight),
        ),
      ),
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
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, size: 64, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(
                filter == 'Zote'
                    ? 'Hakuna historia ya mawasiliano'
                    : 'Hakuna rekodi za $filter',
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
