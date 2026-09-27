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
const _kGreen700  = Color(0xFF15803D);
const _kRed700    = Color(0xFFB91C1C);
const _kAmber700  = Color(0xFFB45309);

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
    WebSocketService().on('notification', _onWsNotification);
    WebSocketService().on('notification.new', _onWsNotification);
  }

  void _onWsNotification(Map<String, dynamic> _) {
    if (mounted) _load();
  }

  @override
  void dispose() {
    final ws = WebSocketService();
    ws.off('notification', _onWsNotification);
    ws.off('notification.new', _onWsNotification);
    super.dispose();
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Kichwa kikubwa 'Arifa' (kama design ya mwisho)
                const Text('Arifa',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kGrey900)),
                Text(unread > 0 ? '$unread hazijasomwa' : 'Zote zimesomwa',
                  style: TextStyle(
                    fontSize: 12.5,
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
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                            itemCount: _notifications.length,
                            itemBuilder: (context, i) {
                              final n = _notifications[i];
                              final read = n['read'] ?? false;
                              final type = (n['type'] as String?) ?? '';
                              final title = (n['title'] ?? '').toString();
                              final body  = (n['body']  ?? '').toString();
                              final (iconData, iconColor) = _styleForType(type);

                              return GestureDetector(
                                onTap: () => _onTap(n),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    border: Border(bottom: BorderSide(color: _kGrey200, width: 1)),
                                  ),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      // Icon circle + badge ya ESS
                                      Stack(clipBehavior: Clip.none, children: [
                                        Container(
                                          width: 46, height: 46,
                                          decoration: const BoxDecoration(
                                            color: _kGrey100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(child: Icon(iconData, size: 22, color: iconColor)),
                                        ),
                                        // Badge ndogo ya ESS chini-kulia
                                        Positioned(
                                          right: -2, bottom: -2,
                                          child: _essBadge(18),
                                        ),
                                      ]),
                                      const SizedBox(width: 12),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Expanded(child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                                              color: _kGrey900,
                                              height: 1.25,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )),
                                          if (_shortTime(n['created_at'] ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 8, top: 2),
                                              child: Text(
                                                _shortTime(n['created_at'] ?? ''),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: read ? _kGrey400 : _kBlue,
                                                ),
                                              ),
                                            ),
                                        ]),
                                        if (body.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(body,
                                            style: const TextStyle(fontSize: 13, color: _kGrey500, height: 1.35),
                                            maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ],
                                      ])),
                                    ]),
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

  /// Badge ndogo ya ESS logo chini-kulia ya icon circle (kama design ya picha)
  Widget _essBadge(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _kGrey200, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: Image.asset('assets/images/ess_badge.png', fit: BoxFit.contain),
      ),
    );
  }

  (IconData, Color) _styleForType(String type) {
    switch (type) {
      case 'payment.approved':
        return (Icons.check_circle_outline_rounded, _kGreen700);
      case 'payment.rejected':
        return (Icons.cancel_outlined, _kRed700);
      case 'payment.submitted':
      case 'payment.message':
      case 'payment.reply':
        return (Icons.payment_rounded, _kAmber700);
      case 'match.found':
        return (Icons.handshake_rounded, _kAmber700);
      case 'admin.reply':
      case 'feedback.replied':
      case 'feedback.new':
        return (Icons.chat_bubble_outline_rounded, _kBlue);
      case 'announcement':
        return (Icons.campaign_rounded, _kGrey700);
      case 'password_reset.new':
        return (Icons.key_rounded, _kGrey700);
      default:
        return (Icons.chat_bubble_outline_rounded, _kBlue);
    }
  }

  /// Muda mfupi wa kulia ya kichwa — '10:32' (leo), 'Jana', '27 Sep' (zamani)
  String _shortTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final that = DateTime(d.year, d.month, d.day);
      final diffDays = today.difference(that).inDays;
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ago','Sep','Okt','Nov','Des'];
      final date = '${d.day} ${months[d.month - 1]}';
      if (diffDays == 0) return '$date · $hh:$mm';
      if (diffDays == 1) return 'Jana';
      return date;
    } catch (_) { return ''; }
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
