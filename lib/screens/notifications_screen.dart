/// Notifications screen — list with auto-mark-read and type-based navigation.
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
    WebSocketService().on('notification', (_) => _loadNotifications());
    WebSocketService().on('notification.new', (_) => _loadNotifications());
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await ApiService().getNotifications();
      final data = res.data;
      List<dynamic> items = [];
      if (data is List) {
        items = data;
      } else if (data is Map) {
        items = data['notifications'] ?? data['items'] ?? [];
      }
      setState(() {
        _notifications = items;
        _loading = false;
      });
      // Auto-mark all read
      _markAllRead(silent: true);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead({bool silent = false}) async {
    try {
      await ApiService().markAllRead();
      if (!silent && mounted) {
        setState(() {
          for (var n in _notifications) {
            n['read'] = true;
          }
        });
      }
    } catch (_) {}
  }

  void _onTap(dynamic n) {
    final type = n['type'] as String? ?? '';
    if (!mounted) return;
    switch (type) {
      case 'payment.approved':
      case 'payment.rejected':
      case 'payment.submitted':
        Navigator.pushNamed(context, '/donate');
        break;
      case 'admin.reply':
        Navigator.pushNamed(context, '/feedback');
        break;
      case 'announcement':
        Navigator.pushNamed(context, '/announcements');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arifa'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead().then((_) {
              if (mounted) {
                setState(() {
                  for (var n in _notifications) n['read'] = true;
                });
              }
            }),
            child: const Text('Soma Zote',
                style: TextStyle(color: Colors.white)),
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
                          Icon(Icons.notifications_none,
                              size: 64, color: AppColors.textLight),
                          SizedBox(height: 16),
                          Text('Hakuna arifa',
                              style: TextStyle(
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, i) {
                        final n = _notifications[i];
                        final read = n['read'] ?? false;
                        return ListTile(
                          onTap: () => _onTap(n),
                          tileColor: read
                              ? null
                              : AppColors.primary.withOpacity(0.04),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: read
                                ? AppColors.border
                                : AppColors.primaryLight,
                            child: Icon(
                              _iconForType(n['type']),
                              color: read
                                  ? AppColors.textLight
                                  : AppColors.primary,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            n['title'] ?? '',
                            style: TextStyle(
                                fontWeight: read
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 14),
                          ),
                          subtitle: Text(
                            n['body'] ?? '',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: !read
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary))
                              : null,
                        );
                      },
                    ),
            ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'payment.approved':
        return Icons.check_circle;
      case 'payment.rejected':
        return Icons.cancel;
      case 'payment.submitted':
        return Icons.payment;
      case 'match.found':
        return Icons.people;
      case 'admin.reply':
        return Icons.reply;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }
}
