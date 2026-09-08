import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kGrey900 = Color(0xFF111827);
const _kGrey800 = Color(0xFF1F2937);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

const _kPageSize = 2;

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<dynamic> _active = [];
  List<dynamic> _history = [];
  bool _loading = true;
  final Set<String> _dismissing = {};
  final Set<String> _expandedHistory = {};
  int _activePage = 1;
  int _historyPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('announcement', (_) { if (mounted) _load(); });
    WebSocketService().on('announcement.new', (_) { if (mounted) _load(); });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService().getAnnouncements(),
        ApiService().getNotifications(limit: 50),
      ]);
      final annData = results[0].data;
      final notifData = results[1].data;

      List<dynamic> active = [];
      if (annData is Map) {
        active = (annData['announcements'] ?? annData['items'] ?? []) as List;
      } else if (annData is List) {
        active = annData;
      }

      List<dynamic> notifs = [];
      if (notifData is Map) {
        notifs = (notifData['notifications'] ?? notifData['items'] ?? []) as List;
      } else if (notifData is List) {
        notifs = notifData;
      }
      final hist = notifs.where((n) => n['type'] == 'announcement').toList();

      if (mounted) {
        setState(() {
          _active = _deduplicate(active, 'title', 'message');
          _history = _deduplicate(hist, 'title', 'body');
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _deduplicate(List<dynamic> items, String titleKey, String bodyKey) {
    final seen = <String, dynamic>{};
    for (final item in items) {
      final key = '${item[titleKey] ?? ''}|${item[bodyKey] ?? ''}';
      final existing = seen[key];
      if (existing == null) {
        seen[key] = item;
      } else {
        final a = DateTime.tryParse(item['created_at'] ?? '') ?? DateTime(0);
        final b = DateTime.tryParse(existing['created_at'] ?? '') ?? DateTime(0);
        if (a.isAfter(b)) seen[key] = item;
      }
    }
    return seen.values.toList();
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissing.add(id));
    setState(() => _active.removeWhere((a) =>
        (a['announcement_id'] ?? a['id'] ?? a['_id'] ?? '').toString() == id));
    try {
      await ApiService().dismissAnnouncement(id);
    } catch (_) {}
    if (mounted) setState(() => _dismissing.remove(id));
  }

  void _toggleHistory(String id) {
    setState(() {
      if (_expandedHistory.contains(id)) {
        _expandedHistory.remove(id);
      } else {
        _expandedHistory.add(id);
      }
    });
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'Sasa hivi';
      if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes} iliyopita';
      if (diff.inHours < 24) return 'saa ${diff.inHours} iliyopita';
      return 'siku ${diff.inDays} iliyopita';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalActivePages = (_active.length / _kPageSize).ceil().clamp(1, 9999);
    final safeActivePage = _activePage.clamp(1, totalActivePages);
    final activeStart = (safeActivePage - 1) * _kPageSize;
    final activeEnd = (activeStart + _kPageSize).clamp(0, _active.length);
    final pagedActive = _active.sublist(activeStart, activeEnd);

    final totalHistoryPages = (_history.length / _kPageSize).ceil().clamp(1, 9999);
    final safeHistoryPage = _historyPage.clamp(1, totalHistoryPages);
    final histStart = (safeHistoryPage - 1) * _kPageSize;
    final histEnd = (histStart + _kPageSize).clamp(0, _history.length);
    final pagedHistory = _history.sublist(histStart, histEnd);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kGrey900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Row(children: [
          Icon(Icons.campaign_outlined, size: 20, color: _kBlue),
          SizedBox(width: 8),
          Text('Matangazo',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _kGrey900)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kGrey200),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtitle
              const Text(
                'Matangazo ya rasmi kutoka kwa admin — unaweza kufuta (✕) baada ya kusoma.',
                style: TextStyle(fontSize: 12, color: _kGrey500),
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: _kBlue),
                  ),
                )
              else ...[
                // ── MPYA heading ──
                Row(children: [
                  const Icon(Icons.campaign_outlined, size: 13, color: _kGrey400),
                  const SizedBox(width: 6),
                  Text('MPYA (${_active.length})',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kGrey500,
                          letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 10),

                // Empty state
                if (_active.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kGrey200),
                    ),
                    child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 28, color: _kGrey400),
                          SizedBox(height: 10),
                          Text('Hakuna matangazo mpya.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _kGrey500,
                                  fontWeight: FontWeight.w500)),
                        ]),
                  )
                else ...[
                  for (final a in pagedActive) _buildActiveCard(a),

                  // Pagination ya active
                  if (_active.length > _kPageSize)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _pageBtn(
                                Icons.chevron_left,
                                safeActivePage > 1,
                                () => setState(
                                    () => _activePage = safeActivePage - 1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('$safeActivePage / $totalActivePages',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _kGrey500)),
                            ),
                            _pageBtn(
                                Icons.chevron_right,
                                safeActivePage < totalActivePages,
                                () => setState(
                                    () => _activePage = safeActivePage + 1)),
                          ]),
                    ),
                ],

                // ── ZILIZOPITA section ──
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Row(children: [
                    const Icon(Icons.access_time, size: 13, color: _kGrey400),
                    const SizedBox(width: 6),
                    Text('ZILIZOPITA (${_history.length})',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kGrey500,
                            letterSpacing: 0.8)),
                  ]),
                  const SizedBox(height: 10),

                  for (final n in pagedHistory) _buildHistoryTile(n),

                  // Pagination ya history
                  if (_history.length > _kPageSize)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _pageBtn(
                                Icons.chevron_left,
                                safeHistoryPage > 1,
                                () => setState(
                                    () => _historyPage = safeHistoryPage - 1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                  '$safeHistoryPage / $totalHistoryPages',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _kGrey500)),
                            ),
                            _pageBtn(
                                Icons.chevron_right,
                                safeHistoryPage < totalHistoryPages,
                                () => setState(
                                    () => _historyPage = safeHistoryPage + 1)),
                          ]),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard(dynamic a) {
    final id = (a['announcement_id'] ?? a['id'] ?? a['_id'] ?? '').toString();
    final title = '${a['title'] ?? ''}';
    final message = '${a['message'] ?? a['body'] ?? ''}';
    final author = '${a['created_by_name'] ?? 'Admin'}';
    final ago = _timeAgo(a['created_at'] as String?);
    final recipientCount = a['recipient_count'];
    final isDismissing = _dismissing.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title + meta
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // font-bold text-brand-grey-900 text-[15px] leading-snug
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.3,
                      color: _kGrey900)),
              const SizedBox(height: 6),
              // text-[11px] text-brand-grey-500
              Wrap(spacing: 10, runSpacing: 4, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline, size: 11, color: _kBlue),
                  const SizedBox(width: 3),
                  Text(author,
                      style:
                          const TextStyle(fontSize: 11, color: _kGrey500)),
                ]),
                if (ago.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.access_time, size: 11, color: _kGrey400),
                    const SizedBox(width: 3),
                    Text(ago,
                        style: const TextStyle(
                            fontSize: 11, color: _kGrey500)),
                  ]),
                if (recipientCount != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.people, size: 11, color: _kBlue),
                    const SizedBox(width: 3),
                    Text('$recipientCount walengwa',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kBlue)),
                  ]),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          // X dismiss — w-7 h-7 rounded-full bg-brand-grey-100
          GestureDetector(
            onTap: isDismissing || id.isEmpty ? null : () => _dismiss(id),
            child: Opacity(
              opacity: isDismissing ? 0.4 : 1.0,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGrey100,
                ),
                child: isDismissing
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kBlue))
                    : const Icon(Icons.close, size: 14, color: _kGrey500),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // message — text-sm text-brand-grey-800 whitespace-pre-wrap leading-relaxed
        Text(message,
            style: const TextStyle(fontSize: 14, height: 1.6, color: _kGrey800)),
      ]),
    );
  }

  Widget _buildHistoryTile(dynamic n) {
    final id = '${n['notification_id'] ?? n['id'] ?? ''}';
    final title = '${n['title'] ?? ''}';
    final body = '${n['body'] ?? ''}';
    final ago = _timeAgo(n['created_at'] as String?);
    final expanded = _expandedHistory.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        // Header — tappable
        InkWell(
          onTap: () => _toggleHistory(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.campaign_outlined,
                            size: 12, color: _kBlue),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _kGrey900),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      if (!expanded && body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(body,
                            style: const TextStyle(
                                fontSize: 11, color: _kGrey500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ]),
              ),
              const SizedBox(width: 8),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: _kGrey400),
            ]),
          ),
        ),
        // Expanded body
        if (expanded) ...[
          Container(height: 1, color: _kGrey200),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(body,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: _kGrey800)),
              if (ago.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.access_time, size: 10, color: _kGrey400),
                  const SizedBox(width: 4),
                  Text(ago,
                      style:
                          const TextStyle(fontSize: 11, color: _kGrey400)),
                ]),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color:
                    enabled ? _kGrey200 : _kGrey200.withValues(alpha: 0.4)),
          ),
          child: Icon(icon,
              size: 16, color: enabled ? _kGrey500 : _kGrey400),
        ),
      );
}
