import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey700   = Color(0xFF374151);
const _kGrey900   = Color(0xFF111827);
const _kGreen50   = Color(0xFFF0FDF4);
const _kGreen200  = Color(0xFFBBF7D0);
const _kGreen700  = Color(0xFF15803D);
const _kRed50     = Color(0xFFFEF2F2);
const _kRed200    = Color(0xFFFECACA);
const _kRed700    = Color(0xFFB91C1C);
const _kAmber50   = Color(0xFFFFFBEB);
const _kAmber200  = Color(0xFFFDE68A);
const _kAmber700  = Color(0xFFB45309);
const _kPurple50  = Color(0xFFF5F3FF);
const _kPurple200 = Color(0xFFDDD6FE);
const _kPurple700 = Color(0xFF6D28D9);

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
    if (mounted) setState(() { for (var n in _notifications) { n['read'] = true; } });
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !(n['read'] ?? false)).length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Custom header ──
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: _kGrey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kGrey700),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kBlue50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.notifications_rounded, size: 20, color: _kBlue),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Arifa Zako',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900)),
                Text(unread > 0 ? '$unread hazijasomwa' : 'Zote zimesomwa',
                  style: TextStyle(
                    fontSize: 12,
                    color: unread > 0 ? _kBlue : _kGrey500,
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                  )),
              ])),
              if (unread > 0)
                GestureDetector(
                  onTap: _markAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kBlue50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.done_all_rounded, size: 14, color: _kBlue),
                      SizedBox(width: 4),
                      Text('Soma Zote', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kBlue)),
                    ]),
                  ),
                ),
            ]),
          ),
          const Divider(height: 1, color: _kGrey200),

          // ── Content ──
          Expanded(
            child: _loading
                ? const Center(child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _kBlue,
                    child: _notifications.isEmpty
                        ? ListView(children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                            Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                  color: _kGrey100,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.notifications_none_rounded, size: 30, color: _kGrey400),
                              ),
                              const SizedBox(height: 16),
                              const Text('Hakuna arifa bado',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kGrey700)),
                              const SizedBox(height: 6),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'Ukipata match, ujumbe au mchango — itaonekana hapa.',
                                  style: TextStyle(fontSize: 12, color: _kGrey500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ])),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                            itemCount: _notifications.length,
                            itemBuilder: (context, i) {
                              final n = _notifications[i];
                              final read = n['read'] ?? false;
                              final type = (n['type'] as String?) ?? '';
                              final title = (n['title'] ?? '').toString();
                              final body  = (n['body']  ?? '').toString();
                              final ago   = _timeAgo(n['created_at'] ?? '');
                              final (iconData, iconColor, bgColor, bdColor) = _styleForType(type);

                              return GestureDetector(
                                onTap: () => _onTap(n),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: read ? _kGrey200 : _kBlue.withValues(alpha: 0.2),
                                    ),
                                    boxShadow: [BoxShadow(
                                      color: const Color(0x08000000),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    )],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      // Icon circle
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: bgColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: bdColor),
                                        ),
                                        child: Center(child: Icon(iconData, size: 20, color: iconColor)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Expanded(child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                                              color: _kGrey900,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )),
                                          if (!read)
                                            Container(
                                              width: 8, height: 8,
                                              margin: const EdgeInsets.only(left: 8, top: 3),
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _kBlue,
                                              ),
                                            ),
                                        ]),
                                        if (body.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(body,
                                            style: const TextStyle(fontSize: 12, color: _kGrey500),
                                            maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ],
                                        if (ago.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            const Icon(Icons.schedule_rounded, size: 11, color: _kGrey400),
                                            const SizedBox(width: 4),
                                            Text(ago, style: const TextStyle(fontSize: 11, color: _kGrey400)),
                                          ]),
                                        ],
                                      ])),
                                    ]),
                                  ),
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

  (IconData, Color, Color, Color) _styleForType(String type) {
    switch (type) {
      case 'payment.approved':
        return (Icons.check_circle_outline_rounded, _kGreen700, _kGreen50, _kGreen200);
      case 'payment.rejected':
        return (Icons.cancel_outlined, _kRed700, _kRed50, _kRed200);
      case 'payment.submitted':
      case 'payment.message':
      case 'payment.reply':
        return (Icons.payment_rounded, _kAmber700, _kAmber50, _kAmber200);
      case 'match.found':
        return (Icons.handshake_rounded, _kPurple700, _kPurple50, _kPurple200);
      case 'admin.reply':
      case 'feedback.replied':
      case 'feedback.new':
        return (Icons.rate_review_rounded, _kAmber700, _kAmber50, _kAmber200);
      case 'announcement':
        return (Icons.campaign_rounded, _kBlue, _kBlue50, _kBlue.withValues(alpha: 0.2));
      case 'password_reset.new':
        return (Icons.key_rounded, _kGrey700, _kGrey100, _kGrey200);
      default:
        return (Icons.notifications_rounded, _kBlue, _kBlue50, _kBlue.withValues(alpha: 0.2));
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
