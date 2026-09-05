/// Announcements screen — active announcements from admin with dismiss.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<dynamic> _announcements = [];
  bool _loading = true;
  final Set<String> _dismissing = {};

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('announcement', (_) => _load());
    WebSocketService().on('announcement.new', (_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getAnnouncements();
      final data = res.data;
      setState(() {
        if (data is List) {
          _announcements = data;
        } else if (data is Map) {
          _announcements = data['announcements'] ?? data['items'] ?? [];
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissing.add(id));
    try {
      await ApiService().dismissAnnouncement(id);
      setState(() {
        _announcements.removeWhere((a) => a['id'] == id || a['_id'] == id);
        _dismissing.remove(id);
      });
    } catch (_) {
      setState(() => _dismissing.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matangazo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _announcements.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 64, color: AppColors.textLight),
                          SizedBox(height: 16),
                          Text('Hakuna matangazo kwa sasa',
                              style: TextStyle(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _announcements.length,
                      itemBuilder: (context, i) {
                        final a = _announcements[i];
                        final id = (a['id'] ?? a['_id'] ?? '').toString();
                        final isDismissing = _dismissing.contains(id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.campaign,
                                        color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a['title'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                    if (isDismissing)
                                      const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                    else
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18,
                                            color: AppColors.textLight),
                                        tooltip: 'Funga',
                                        onPressed: id.isNotEmpty
                                            ? () => _dismiss(id)
                                            : null,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(a['body'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.5)),
                                const SizedBox(height: 8),
                                Text(
                                  (a['created_at'] ?? '')
                                      .toString()
                                      .split('T')
                                      .first,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
