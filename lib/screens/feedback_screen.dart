import 'package:flutter/material.dart';
import '../screens/maoni_view.dart';
import '../services/api_service.dart';
import '../services/cached_repository.dart';
import '../services/websocket_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/no_cached_data_widget.dart';

// OFFLINE-FIRST — funguo ya diski ya maoni ya mtumiaji mwenyewe.
const _kKey = 'page:my-feedback';

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
    // DISKI PAPO HAPO — data ya diski KWA FRAME YA KWANZA (hakuna spring);
    // refresh mtandaoni iko nyuma ya pazia.
    CachedRepository().hydrate(_kKey, _applyMaoni);
    _load();
    WebSocketService().on('notification', _onWs);
  }

  void _applyMaoni(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final raw = data;
    List<dynamic> list = [];
    if (raw is Map) {
      list = (raw['items'] ?? raw['feedbacks'] ?? []) as List;
    } else if (raw is List) {
      list = raw;
    }
    setState(() => _items = list.map(_toItem).toList());
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: maoni ya diski yabaki.
    if (_items.isEmpty) setState(() => _loading = true);
    await CachedRepository().loadPage(_kKey, _fetchFeedback, _applyMaoni);
    if (mounted) setState(() => _loading = false);
  }

  /// API ya ukurasa huu — huitwa na CachedRepository nyuma ya pazia.
  Future<dynamic> _fetchFeedback() async =>
      (await ApiService().getMyFeedback()).data;

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
      child: _loading && _items.isEmpty
          // Bado hakuna diski — NoCachedDataWidget (spinner mtandaoni,
          // "download" ikoni bila mtandao).
          ? const Center(child: NoCachedDataWidget())
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
