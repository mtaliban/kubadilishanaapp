/// Notifications screen — list of user notifications.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../config/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtime();
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await ApiService().getNotifications();
      setState(() {
        _notifications = res.data['notifications'] ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _setupRealtime() {
    WebSocketService().on('notification', (_) => _loadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arifa'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Soma Zote', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: AppColors.textLight),
                          SizedBox(height: 16),
                          Text('Hakuna arifa', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, i) {
                        final n = _notifications[i];
                        final read = n['read'] ?? false;
                        return ListTile(
                          leading: Icon(
                            _iconForType(n['type']),
                            color: read ? AppColors.textLight : AppColors.primary,
                            size: 20,
                          ),
                          title: Text(n['title'] ?? '',
                              style: TextStyle(
                                  fontWeight: read ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 14)),
                          subtitle: Text(n['body'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          trailing: !read
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle, color: AppColors.primary))
                              : null,
                        );
                      },
                    ),
            ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'payment.approved': return Icons.check_circle;
      case 'payment.rejected': return Icons.cancel;
      case 'payment.submitted': return Icons.payment;
      case 'match.found': return Icons.people;
      case 'admin.reply': return Icons.reply;
      case 'announcement': return Icons.campaign;
      default: return Icons.notifications;
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService().markAllRead();
      setState(() {
        for (var n in _notifications) n['read'] = true;
      });
    } catch (_) {}
  }
}
