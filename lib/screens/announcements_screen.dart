import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cached_repository.dart';
import '../services/websocket_service.dart';
import '../widgets/no_cached_data_widget.dart';

// OFFLINE-FIRST — funguo ya diski ya matangazo + historia yake.
const _kAnnouncementsKey = 'page:announcements';

const _kBlue    = Color(0xFF1E40AF);
const _kGrey900 = Color(0xFF111827);
const _kGrey800 = Color(0xFF1F2937);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

bool _nd(BuildContext c__) => Theme.of(c__).brightness == Brightness.dark;
Color _kGrey100T(BuildContext c__) => _nd(c__) ? const Color(0xFF212833) : _kGrey100;
Color _kGrey200T(BuildContext c__) => _nd(c__) ? const Color(0xFF2A3240) : _kGrey200;
Color _kGrey400T(BuildContext c__) => _nd(c__) ? const Color(0xFF64748B) : _kGrey400;
Color _kGrey500T(BuildContext c__) => _nd(c__) ? const Color(0xFF9AA8C7) : _kGrey500;
Color _kGrey700T(BuildContext c__) => _nd(c__) ? const Color(0xFFCBD5E1) : (const Color(0xFF374151));
Color _kGrey900T(BuildContext c__) => _nd(c__) ? const Color(0xFFE7ECF8) : _kGrey900;
Color _kBlue50T(BuildContext c__) => _nd(c__) ? const Color(0xFF1C2A44) : const Color(0xFFEFF6FF);
Color _kBlueT(BuildContext c__) => _nd(c__) ? const Color(0xFF7AA7FF) : _kBlue;

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
    WebSocketService().on('announcement', _onAnnouncement);
    WebSocketService().on('announcement.new', _onAnnouncement);
  }

  void _onAnnouncement(Map<String, dynamic> _) {
    if (mounted) _load();
  }

  @override
  void dispose() {
    final ws = WebSocketService();
    ws.off('announcement', _onAnnouncement);
    ws.off('announcement.new', _onAnnouncement);
    super.dispose();
  }

  Future<void> _load() async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: matangazo ya diski yabaki.
    await CachedRepository().loadPage(
        _kAnnouncementsKey, _fetchBundle, (data) async {
      if (!mounted || data == null) return; // API imeshindwa → diski ibaki
      final b = data as Map;
      final annData = b['announcements'];
      final notifData = b['notifications'];

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
    });
    if (mounted && _loading) setState(() => _loading = false);
  }

  /// API za ukurasa huu — huitwa na CachedRepository nyuma ya pazia.
  Future<Map<String, dynamic>> _fetchBundle() async {
    final results = await Future.wait([
      ApiService().getAnnouncements(),
      ApiService().getNotifications(limit: 50),
    ]);
    return {'announcements': results[0].data, 'notifications': results[1].data};
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
      body: Column(children: [
        Container(
          color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _kGrey100T(context), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kGrey900T(context))),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlueT(context).withValues(alpha: 0.2))),
              child: Icon(Icons.campaign_outlined, size: 20, color: _kBlueT(context))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Matangazo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900T(context))),
              Text('Matangazo rasmi kutoka kwa admin',
                  style: TextStyle(fontSize: 12, color: _kGrey500T(context))),
            ])),
          ]),
        ),
        Container(height: 1, color: _kGrey200T(context)),
        Expanded(child: RefreshIndicator(
          onRefresh: _load,
          color: _kBlue,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtitle
              Text(
                'Matangazo ya rasmi kutoka kwa admin — unaweza kufuta (✕) baada ya kusoma.',
                style: TextStyle(fontSize: 12, color: _kGrey500T(context)),
              ),
              const SizedBox(height: 20),

              if (_loading && _active.isEmpty && _history.isEmpty)
                // Bado hakuna diski — NoCachedDataWidget (spinner mtandaoni,
                // "download" ikoni bila mtandao).
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: NoCachedDataWidget(),
                  ),
                )
              else if (_active.isEmpty &&
                  _history.isEmpty &&
                  CachedRepository().readOrNull<dynamic>(_kAnnouncementsKey) == null)
                // HAKUNA data diski + API imeshindwa — widget MOYA ya
                // "haijapakuliwa" (pull-to-refresh pekee).
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: NoCachedDataWidget(
                      hint: 'Vuta chini kupakia — matangazo yatahifadhiwa kwenye simu.',
                    ),
                  ),
                )
              else ...[
                // ── MPYA heading ──
                Row(children: [
                  Icon(Icons.campaign_outlined, size: 13, color: _kGrey400T(context)),
                  const SizedBox(width: 6),
                  Text('MPYA (${_active.length})',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kGrey500T(context),
                          letterSpacing: 0.8)),
                ]),
                const SizedBox(height: 10),

                // Empty state
                if (_active.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kGrey200T(context)),
                      boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 28, color: _kGrey400T(context)),
                          const SizedBox(height: 10),
                          Text('Hakuna matangazo mpya.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _kGrey500T(context),
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
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _kGrey500T(context))),
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
                    Icon(Icons.access_time, size: 13, color: _kGrey400T(context)),
                    const SizedBox(width: 6),
                    Text('ZILIZOPITA (${_history.length})',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kGrey500T(context),
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
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _kGrey500T(context))),
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
        )),
      ]),
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
        color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGrey200T(context)),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title + meta
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // font-bold text-brand-grey-900 text-[15px] leading-snug
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.3,
                      color: _kGrey900T(context))),
              const SizedBox(height: 6),
              // text-[11px] text-brand-grey-500
              Wrap(spacing: 10, runSpacing: 4, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 11, color: _kBlueT(context)),
                  const SizedBox(width: 3),
                  Text(author,
                      style:
                          TextStyle(fontSize: 11, color: _kGrey500T(context))),
                ]),
                if (ago.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.access_time, size: 11, color: _kGrey400T(context)),
                    const SizedBox(width: 3),
                    Text(ago,
                        style: TextStyle(
                            fontSize: 11, color: _kGrey500T(context))),
                  ]),
                if (recipientCount != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people, size: 11, color: _kBlueT(context)),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGrey100T(context),
                ),
                child: isDismissing
                    ? Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kBlue))
                    : Icon(Icons.close, size: 14, color: _kGrey500T(context)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // message — text-sm text-brand-grey-800 whitespace-pre-wrap leading-relaxed
        Text(message,
            style: TextStyle(fontSize: 14, height: 1.6, color: _kGrey900T(context))),
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
        color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGrey200T(context)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
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
                        Icon(Icons.campaign_outlined,
                            size: 12, color: _kBlue),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _kGrey900T(context)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      if (!expanded && body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(body,
                            style: TextStyle(
                                fontSize: 11, color: _kGrey500T(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ]),
              ),
              const SizedBox(width: 8),
              Icon(expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: _kGrey400T(context)),
            ]),
          ),
        ),
        // Expanded body
        if (expanded) ...[
          Container(height: 1, color: _kGrey200T(context)),
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
                  Icon(Icons.access_time, size: 10, color: _kGrey400T(context)),
                  const SizedBox(width: 4),
                  Text(ago,
                      style:
                          TextStyle(fontSize: 11, color: _kGrey400T(context))),
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