/// Admin events page — system event log with filtering and pagination.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});
  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  List<dynamic> _events = [];
  Map<String, dynamic> _dailyStats = {};
  bool _loading = true;
  String _filter = '';
  int _page = 1;
  int _total = 0;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final skip = (_page - 1) * _pageSize;
    try {
      final res = await ApiService().adminEvents(
        eventType: _filter.isNotEmpty ? _filter : null,
        limit: _pageSize,
        skip: skip,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _events = data['events'] ?? [];
        _total = data['total'] ?? 0;
        _dailyStats = data['stats'] as Map<String, dynamic>? ?? {};
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
        // Daily stats mini row
        if (_dailyStats.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.primaryLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Wapya Leo',
                    '${_dailyStats['users_today'] ?? 0}'),
                _miniStat('Jana',
                    '${_dailyStats['users_yesterday'] ?? 0}'),
                _miniStat('Views Leo',
                    '${_dailyStats['views_today'] ?? 0}'),
              ],
            ),
          ),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _tab('', 'Zote'),
              _tab('user.registered', 'Usajili'),
              _tab('match.found', 'Mikataba'),
              _tab('payment.submitted', 'Malipo'),
              _tab('user.verified', 'Amethibitishwa'),
              _tab('call.initiated', 'Simu'),
            ],
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Chip(
                label: Text('Jumla: $_total',
                    style: const TextStyle(fontSize: 12))),
          ]),
        ),
        // Events list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _events.length,
                    itemBuilder: (context, i) =>
                        _eventTile(_events[i]),
                  ),
                ),
        ),
        // Pagination
        if (_total > _pageSize)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_page > 1)
                  IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() => _page--);
                        _load();
                      }),
                Text(
                    'Page $_page / ${(_total / _pageSize).ceil()}'),
                if (_page * _pageSize < _total)
                  IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() => _page++);
                        _load();
                      }),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary)),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _eventTile(Map<String, dynamic> e) {
    final type = e['event_type'] ?? e['type'] ?? '';
    final time = (e['occurred_at'] ?? e['created_at'] ?? '')
        .toString()
        .replaceAll('T', ' ')
        .split('.')
        .first;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading:
            Icon(_iconForType(type), size: 18, color: _colorForType(type)),
        title: Text(type,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          e['message'] ?? e['description'] ?? e['user_name'] ?? '',
          style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(time,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textLight)),
      ),
    );
  }

  Widget _tab(String filter, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _filter == filter,
        onSelected: (_) {
          setState(() {
            _filter = filter;
            _page = 1;
          });
          _load();
        },
        selectedColor: AppColors.primary,
        labelStyle:
            TextStyle(color: _filter == filter ? Colors.white : null),
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('registered')) return Icons.person_add;
    if (type.contains('match')) return Icons.people;
    if (type.contains('payment')) return Icons.payment;
    if (type.contains('verified')) return Icons.verified;
    if (type.contains('call') || type.contains('message')) return Icons.phone;
    if (type.contains('data')) return Icons.storage;
    if (type.contains('admin') || type.contains('updated')) {
      return Icons.admin_panel_settings;
    }
    if (type.contains('deleted')) return Icons.delete;
    return Icons.info;
  }

  Color _colorForType(String type) {
    if (type.contains('registered')) return AppColors.success;
    if (type.contains('match')) return Colors.purple;
    if (type.contains('payment')) return AppColors.warning;
    if (type.contains('verified')) return AppColors.success;
    if (type.contains('call')) return Colors.green;
    if (type.contains('deleted')) return AppColors.error;
    return AppColors.primary;
  }
}
