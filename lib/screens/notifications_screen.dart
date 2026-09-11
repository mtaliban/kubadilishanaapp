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
    _load();
    WebSocketService().on('notification', (_) => _load());
    WebSocketService().on('notification.new', (_) => _load());
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getNotifications(limit: 100);
      final data = res.data;
      List<dynamic> items = data is List ? data : (data['notifications'] ?? data['items'] ?? []);
      if (mounted) setState(() { _notifications = items; _loading = false; });
      try { await ApiService().markAllRead(); } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTap(dynamic n) async {
    final id = n['notification_id'] ?? n['id'] ?? '';
    final type = (n['type'] as String?) ?? '';
    final read = n['read'] ?? false;
    if (!read && id.toString().isNotEmpty) {
      setState(() => n['read'] = true);
      try { await ApiService().markNotificationRead(id.toString()); } catch (_) {}
    }
    if (!mounted) return;
    switch (type) {
      case 'payment.approved':
      case 'payment.rejected':
      case 'payment.submitted':
      case 'payment.message':
      case 'payment.reply':
        Navigator.pushNamed(context, '/donate');
        break;
      case 'admin.reply':
      case 'feedback.replied':
      case 'feedback.new':
        Navigator.pushNamed(context, '/feedback');
        break;
      case 'announcement':
        Navigator.pushNamed(context, '/announcements');
        break;
      case 'match.found':
        Navigator.pop(context);
        break;
      default:
        break;
    }
  }

  Future<void> _markAll() async {
    try { await ApiService().markAllRead(); } catch (_) {}
    if (mounted) setState(() { for (var n in _notifications) n['read'] = true; });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !(n['read'] ?? false)).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Arifa Zako'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAll,
              child: Text('✓ Soma Zote ($unread)',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade100,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.notifications_none, size: 28, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 16),
                      const Text('Hakuna arifa bado.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('Ukipata match, ujumbe au mchango — itaonekana hapa.',
                          style: TextStyle(color: AppColors.textLight, fontSize: 12),
                          textAlign: TextAlign.center),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                      itemBuilder: (context, i) {
                        final n = _notifications[i];
                        final read = n['read'] ?? false;
                        final type = (n['type'] as String?) ?? '';
                        final emoji = _emojiForType(type);
                        final icon = _iconForType(type);
                        final title = n['title'] ?? '';
                        final body = n['body'] ?? '';
                        final ago = _timeAgo(n['created_at'] ?? '');

                        return InkWell(
                          onTap: () => _onTap(n),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: read ? Colors.grey.shade100 : AppColors.primaryLight,
                                  border: Border.all(
                                    color: read ? AppColors.border : AppColors.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Center(child: Icon(icon,
                                    size: 18,
                                    color: read ? AppColors.textLight : AppColors.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(
                                    '$emoji $title',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: read ? FontWeight.normal : FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                  if (!read)
                                    Container(
                                      width: 8, height: 8,
                                      margin: const EdgeInsets.only(left: 6, top: 3),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                ]),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(body,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                                if (ago.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(ago, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                                ],
                              ])),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  String _emojiForType(String type) {
    switch (type) {
      case 'match.found': return '🤝';
      case 'message.sent': return '💬';
      case 'call.initiated': return '📞';
      case 'payment.submitted': return '💰';
      case 'payment.approved': return '✅';
      case 'payment.rejected': return '❌';
      case 'user.registered': return '👤';
      case 'user.profile_updated': return '✏️';
      case 'announcement': return '📢';
      case 'feedback.new': return '📝';
      case 'feedback.replied': return '💬';
      case 'payment.message': return '💬';
      case 'payment.reply': return '💬';
      case 'password_reset.new': return '🔑';
      default: return '🔔';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'payment.approved': return Icons.check_circle_outline;
      case 'payment.rejected': return Icons.cancel_outlined;
      case 'payment.submitted': return Icons.payment;
      case 'payment.message':
      case 'payment.reply': return Icons.chat_bubble_outline;
      case 'match.found': return Icons.people_outline;
      case 'admin.reply':
      case 'feedback.replied':
      case 'feedback.new': return Icons.assignment_outlined;
      case 'announcement': return Icons.campaign_outlined;
      case 'user.registered': return Icons.person_add_outlined;
      case 'user.profile_updated': return Icons.edit_outlined;
      case 'password_reset.new': return Icons.key_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'Sasa hivi';
      if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes} iliyopita';
      if (diff.inHours < 24) return 'saa ${diff.inHours} iliyopita';
      return 'siku ${diff.inDays} iliyopita';
    } catch (_) { return ''; }
  }
}
