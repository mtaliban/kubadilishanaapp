import 'package:flutter/material.dart';
import '../screens/maoni_view.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/app_shell.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<FeedbackItem> _items = [];
  bool _loading = true;

  void _onWs(dynamic payload) {
    // Admin akijibu (WS type=feedback.replied) — pakia majibu mapya papo hapo.
    // Backend inatuma event 'notification' yenye type ndani ya data pia;
    // tunakubili zote mbili ili jibu lifike kwa wakati bila refresh.
    final type = (payload['type'] ??
            (payload['data'] is Map ? payload['data']['type'] : null))
        ?.toString();
    if (type == 'feedback.replied' && mounted) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('notification', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMyFeedback();
      final raw = res.data;
      List<dynamic> list = [];
      if (raw is Map) {
        list = (raw['items'] ?? raw['feedbacks'] ?? []) as List;
      } else if (raw is List) {
        list = raw;
      }
      if (mounted) {
        setState(() => _items = list.map(_toItem).toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  FeedbackItem _toItem(dynamic f) => FeedbackItem(
        id: '${f['id'] ?? ''}',
        message: '${f['message'] ?? ''}',
        createdAt: _parseDate('${f['created_at'] ?? ''}'),
        reply: f['status'] == 'replied' ? '${f['admin_reply'] ?? ''}' : null,
      );

  DateTime _parseDate(String iso) {
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<FeedbackItem?> _onSend(String message) async {
    final subject = message.length > 60 ? '${message.substring(0, 60)}...' : message;
    final res = await ApiService().submitFeedback(subject: subject, message: message);
    final raw = res.data;
    if (raw is Map && raw['id'] != null) return _toItem(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      tabIndex: 2,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: MaoniView(
                items: _items,
                onSend: _onSend,
                toastBottom: 72,
              ),
            ),
    );
  }
}
