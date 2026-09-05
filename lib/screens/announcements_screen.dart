/// Announcements screen — view latest announcements from admin.
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

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('announcement', (_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getAnnouncements();
      setState(() {
        _announcements = res.data is List ? res.data : (res.data['announcements'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
                          Icon(Icons.campaign_outlined, size: 64, color: AppColors.textLight),
                          SizedBox(height: 16),
                          Text('Hakuna matangazo kwa sasa', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _announcements.length,
                      itemBuilder: (context, i) {
                        final a = _announcements[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.campaign, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(a['title'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(a['body'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                                const SizedBox(height: 8),
                                Text(a['created_at'] ?? '',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
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

