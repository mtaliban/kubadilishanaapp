import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey50  = Color(0xFFF9FAFB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey700 = Color(0xFF374151);
const _kGrey900 = Color(0xFF111827);
const _kGreen50  = Color(0xFFF0FDF4);
const _kGreen200 = Color(0xFFBBF7D0);
const _kGreen700 = Color(0xFF15803D);
const _kRed    = Color(0xFFDC2626);
const _kRed50  = Color(0xFFFEF2F2);
const _kRed200 = Color(0xFFFEE2E2);
const _kAmber50  = Color(0xFFFFFBEB);
const _kAmber200 = Color(0xFFFDE68A);
const _kAmber700 = Color(0xFFB45309);
const _kPurple50  = Color(0xFFF5F3FF);
const _kPurple200 = Color(0xFFDDD6FE);
const _kPurple700 = Color(0xFF6D28D9);
const _kOrange50  = Color(0xFFFFF7ED);
const _kOrange200 = Color(0xFFFED7AA);
const _kOrange700 = Color(0xFFC2410C);

const _kPageSize = 8;

// ── Main page ──────────────────────────────────────────────────────────────
class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});
  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  List<dynamic> _allItems  = [];
  List<dynamic> _items     = [];
  bool   _loading          = true;
  String _status           = '';   // '' | 'open' | 'replied'
  String _q                = '';
  Timer? _debounce;
  int    _page             = 1;
  String? _flash;
  bool   _flashOk          = true;
  Timer? _flashTimer;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('notification', (p) {
      if (p['type'] == 'feedback.new' && mounted) {
        _showFlash('Maoni mapya yamefika');
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flashTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isOpen(dynamic f) {
    if (f['status'] == 'replied') return false;
    final reply = f['admin_reply'] ?? f['reply'];
    return reply == null || reply.toString().isEmpty;
  }

  List<dynamic> _computeFiltered() {
    var filtered = List<dynamic>.from(_allItems);
    if (_status == 'open') {
      filtered = filtered.where(_isOpen).toList();
    } else if (_status == 'replied') {
      filtered = filtered.where((f) => !_isOpen(f)).toList();
    }
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      filtered = filtered.where((f) {
        return (f['subject'] ?? '').toString().toLowerCase().contains(q) ||
               (f['message'] ?? '').toString().toLowerCase().contains(q) ||
               (f['user_name'] ?? f['name'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }
    return filtered;
  }

  void _applyFilter() {
    setState(() {
      _items = _computeFiltered();
      _page  = 1;
    });
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res = await ApiService().adminListFeedback(status: '', q: '');
      final data = res.data;
      if (mounted) {
        _allItems = (data is Map
            ? (data['items'] ?? data['feedback'] ?? [])
            : data) as List<dynamic>;
        setState(() {
          _items   = _computeFiltered();
          _page    = 1;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        if (!silent) _showFlash('Hitilafu ya kupakia maoni', ok: false);
      }
    }
  }

  void _showFlash(String msg, {bool ok = true}) {
    _flashTimer?.cancel();
    setState(() { _flash = msg; _flashOk = ok; });
    _flashTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    final id = f['_id'] ?? f['id'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Futa Maoni',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
        content: const Text('Una uhakika unataka kufuta maoni haya?',
            style: TextStyle(fontSize: 13, color: _kGrey700)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hapana')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ndio, Futa', style: TextStyle(color: _kRed))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().adminDeleteFeedback(id);
      _showFlash('Maoni yamefutwa');
      _load();
    } catch (_) {
      _showFlash('Hitilafu ya kufuta', ok: false);
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _q = val.trim());
      _applyFilter();
    });
  }

  void _setStatus(String s) {
    if (_status == s) return;
    setState(() => _status = s);
    _applyFilter();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalPages   = (_items.length / _kPageSize).ceil().clamp(1, 9999);
    final pageItems    = _items.skip((_page - 1) * _kPageSize).take(_kPageSize).toList();
    final totalCount   = _allItems.length;
    final openCount    = _allItems.where(_isOpen).length;
    final repliedCount = _allItems.where((f) => !_isOpen(f)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header with gradient background bar ──
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEFF6FF), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _kBlue50, borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Icon(Icons.assignment_outlined, size: 24, color: _kBlue)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Maoni${totalCount > 0 ? " ($totalCount)" : ""}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900),
                ),
                const Text('Maoni na malalamiko ya watumiaji',
                    style: TextStyle(fontSize: 12, color: _kGrey500)),
              ]),
            ),
          ]),
        ),

        // ── Stats summary row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _StatPill(label: 'Zote',      count: totalCount,   color: _kBlue,    icon: Icons.inbox),
            const SizedBox(width: 8),
            _StatPill(label: 'Wazi',      count: openCount,    color: _kAmber700, icon: Icons.mark_email_unread),
            const SizedBox(width: 8),
            _StatPill(label: 'Imejibiwa', count: repliedCount, color: _kGreen700, icon: Icons.mark_email_read),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Status filter chips ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _Chip(label: 'Zote',      value: '',        current: _status, onTap: _setStatus),
              const SizedBox(width: 8),
              _Chip(label: 'Wazi',      value: 'open',    current: _status, onTap: _setStatus),
              const SizedBox(width: 8),
              _Chip(label: 'Imejibiwa', value: 'replied', current: _status, onTap: _setStatus),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // ── Search box (48px, subtle shadow) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGrey200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.search, size: 18, color: _kGrey400),
              ),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 13, color: _kGrey900),
                  decoration: const InputDecoration(
                    hintText: 'Tafuta maoni...',
                    hintStyle: TextStyle(fontSize: 13, color: _kGrey400),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // ── Flash message ──
        if (_flash != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _flashOk ? _kGreen50 : _kRed50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _flashOk ? _kGreen200 : _kRed200),
              ),
              child: Row(children: [
                Icon(
                  _flashOk ? Icons.check_circle_outline : Icons.error_outline,
                  size: 16,
                  color: _flashOk ? _kGreen700 : _kRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_flash!,
                      style: TextStyle(
                          fontSize: 13, color: _flashOk ? _kGreen700 : _kRed)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── List ──
        Expanded(
          child: _loading
              ? const Center(
                  child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBlue)))
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  color: _kBlue,
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(
                                    color: _kGrey100,
                                    borderRadius: BorderRadius.circular(32)),
                                child: const Icon(Icons.inbox_outlined,
                                    size: 32, color: _kGrey400),
                              ),
                              const SizedBox(height: 12),
                              const Text('Hakuna maoni bado',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _kGrey500)),
                              const SizedBox(height: 4),
                              const Text('Maoni mapya yataonekana hapa',
                                  style: TextStyle(fontSize: 12, color: _kGrey400)),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                          children: [
                            ...pageItems.asMap().entries.map((e) {
                              final globalIndex =
                                  (_page - 1) * _kPageSize + e.key + 1;
                              return _FeedbackCard(
                                key: ValueKey(
                                    e.value['_id'] ?? e.value['id'] ?? e.key),
                                f: Map<String, dynamic>.from(e.value as Map),
                                index: globalIndex,
                                onDelete: _delete,
                                onReplied: () {
                                  _showFlash('Jibu limetumwa');
                                  _load(silent: true);
                                },
                                onFlash: _showFlash,
                              );
                            }),
                            if (totalPages > 1)
                              _PaginationRow(
                                page: _page,
                                totalPages: totalPages,
                                onPage: (p) => setState(() => _page = p),
                              ),
                            const SizedBox(height: 64),
                          ],
                        ),
                ),
        ),
      ],
    );
  }
}

// ── Stat pill ──────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _StatPill({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Text('$count',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;
  const _Chip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _kBlue : _kGrey200),
          boxShadow: active
              ? [BoxShadow(color: _kBlue.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kGrey500,
              )),
        ),
      ),
    );
  }
}

// ── Pagination row ─────────────────────────────────────────────────────────
class _PaginationRow extends StatelessWidget {
  final int page;
  final int totalPages;
  final void Function(int) onPage;

  const _PaginationRow(
      {required this.page, required this.totalPages, required this.onPage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _build()),
    );
  }

  List<Widget> _build() {
    final widgets = <Widget>[];

    widgets.add(_navBtn(Icons.chevron_left, page > 1 ? () => onPage(page - 1) : null));
    widgets.add(const SizedBox(width: 4));

    if (totalPages <= 7) {
      for (int i = 1; i <= totalPages; i++) {
        if (i > 1) widgets.add(const SizedBox(width: 4));
        widgets.add(_pageBtn(i));
      }
    } else {
      final show = <int>{1, totalPages, page};
      for (int i = page - 2; i <= page + 2; i++) {
        if (i >= 1 && i <= totalPages) show.add(i);
      }
      final sorted = show.toList()..sort();
      for (int idx = 0; idx < sorted.length; idx++) {
        if (idx > 0) {
          if (sorted[idx] - sorted[idx - 1] > 1) {
            widgets.add(const SizedBox(width: 4));
            widgets.add(const _Ellipsis());
          }
          widgets.add(const SizedBox(width: 4));
        }
        widgets.add(_pageBtn(sorted[idx]));
      }
    }

    widgets.add(const SizedBox(width: 4));
    widgets.add(_navBtn(Icons.chevron_right, page < totalPages ? () => onPage(page + 1) : null));

    return widgets;
  }

  Widget _pageBtn(int n) {
    final active = n == page;
    return GestureDetector(
      onTap: active ? null : () => onPage(n),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _kBlue : _kGrey200),
        ),
        child: Center(
          child: Text('$n',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _kGrey700)),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGrey200),
        ),
        child: Center(
            child: Icon(icon, size: 18, color: enabled ? _kGrey700 : _kGrey400)),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  const _Ellipsis();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 32, height: 32,
      child: Center(
          child: Text('…', style: TextStyle(fontSize: 14, color: _kGrey400))),
    );
  }
}

// ── Feedback card ──────────────────────────────────────────────────────────
class _FeedbackCard extends StatefulWidget {
  final Map<String, dynamic> f;
  final int index;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final VoidCallback onReplied;
  final void Function(String, {bool ok}) onFlash;

  const _FeedbackCard({
    super.key,
    required this.f,
    required this.index,
    required this.onDelete,
    required this.onReplied,
    required this.onFlash,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  final _replyCtrl = TextEditingController();
  bool _sending    = false;
  bool _expanded   = false;
  bool _showReply  = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final id = widget.f['_id'] ?? widget.f['id'];
      await ApiService().adminReplyFeedback(id, _replyCtrl.text.trim());
      _replyCtrl.clear();
      setState(() { _sending = false; _showReply = false; });
      widget.onReplied();
    } catch (_) {
      setState(() => _sending = false);
      widget.onFlash('Hitilafu ya kutuma jibu', ok: false);
    }
  }

  // ── Type badge data ────────────────────────────────────────────────────
  ({String label, Color bg, Color fg, Color border, IconData icon})
      _typeBadge(String rawType) {
    final t = rawType.toLowerCase();
    if (t.contains('malalamiko') || t.contains('complaint')) {
      return (label: 'Malalamiko', bg: _kRed50, fg: _kRed, border: _kRed200,
          icon: Icons.report_outlined);
    }
    if (t.contains('maoni') || t.contains('feedback') || t.contains('suggestion')) {
      return (label: 'Maoni', bg: _kBlue50, fg: _kBlue, border: const Color(0xFFBFDBFE),
          icon: Icons.chat_bubble_outline);
    }
    if (t.contains('swali') || t.contains('question')) {
      return (label: 'Swali', bg: _kPurple50, fg: _kPurple700, border: _kPurple200,
          icon: Icons.help_outline);
    }
    if (t.contains('tatizo') || t.contains('bug') || t.contains('issue')) {
      return (label: 'Tatizo', bg: _kOrange50, fg: _kOrange700, border: _kOrange200,
          icon: Icons.bug_report_outlined);
    }
    return (label: rawType.isNotEmpty ? rawType : 'Maoni',
        bg: _kGrey100, fg: _kGrey700, border: _kGrey200,
        icon: Icons.chat_bubble_outline);
  }

  // ── Avatar color from name ────────────────────────────────────────────
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF1E40AF), // blue
      const Color(0xFF6D28D9), // purple
      const Color(0xFF065F46), // green
      const Color(0xFF92400E), // amber
      const Color(0xFF991B1B), // red
      const Color(0xFF1E3A5F), // navy
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final f          = widget.f;
    final adminReply = f['admin_reply'] ?? f['reply'];
    final hasReply   = adminReply != null && adminReply.toString().isNotEmpty;
    final subject    = (f['subject'] ?? '').toString().trim();
    final message    = (f['message'] ?? '').toString();
    final userName   = (f['user_name'] ?? f['name'] ?? 'Mtumiaji').toString();
    final userPhone  = (f['user_phone'] ?? f['phone'] ?? '').toString().trim();
    final rawType    = (f['type'] ?? f['category'] ?? '').toString();
    final rawDate    = (f['created_at'] ?? f['createdAt'] ?? '').toString();
    final dateStr    = rawDate.isNotEmpty
        ? rawDate.replaceAll('T', ' ').split('.').first
        : '';

    final initial    = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    final avatarColor = _avatarColor(userName);
    final badge      = _typeBadge(rawType.isNotEmpty ? rawType : (subject.isNotEmpty ? subject : ''));

    final isLong     = message.length > 120;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: hasReply ? _kGreen200 : _kGrey200, width: hasReply ? 1.5 : 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Card top accent bar (4px) ──
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: hasReply ? _kGreen700 : _kAmber700,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Row 1: Avatar + name/phone + badges + delete ──
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar (44x44)
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(22)),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),

              // Name + phone
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(userName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold,
                          color: _kGrey900),
                      overflow: TextOverflow.ellipsis),
                  if (userPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.phone_outlined, size: 11, color: _kGrey400),
                      const SizedBox(width: 3),
                      Text(userPhone,
                          style: const TextStyle(fontSize: 11, color: _kGrey500)),
                    ]),
                  ],
                ]),
              ),

              // Badges column
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                // Status badge
                _Badge(
                  label: hasReply ? 'Imejibiwa' : 'Mpya',
                  bg: hasReply ? _kGreen50 : _kAmber50,
                  fg: hasReply ? _kGreen700 : _kAmber700,
                  border: hasReply ? _kGreen200 : _kAmber200,
                  icon: hasReply ? Icons.check_circle_outline : Icons.schedule,
                ),
                const SizedBox(height: 4),
                // Type badge
                _Badge(
                  label: badge.label,
                  bg: badge.bg,
                  fg: badge.fg,
                  border: badge.border,
                  icon: badge.icon,
                ),
              ]),

              // Delete button
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => widget.onDelete(widget.f),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kRed50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kRed200),
                  ),
                  child: const Center(
                      child: Icon(Icons.delete_outline, size: 16, color: _kRed)),
                ),
              ),
            ]),

            // ── Subject ──
            if (subject.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(subject,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900)),
            ],

            // ── Message (truncatable) ──
            const SizedBox(height: 8),
            GestureDetector(
              onTap: isLong ? () => setState(() => _expanded = !_expanded) : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 13, color: _kGrey700, height: 1.55),
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (isLong) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 14, color: _kBlue,
                    ),
                    Text(
                      _expanded ? 'Onyesha kidogo' : 'Soma zaidi',
                      style: const TextStyle(
                          fontSize: 11, color: _kBlue,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ],
              ]),
            ),

            // ── Date/time ──
            const SizedBox(height: 10),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _kGrey50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kGrey200)),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded, size: 11, color: _kGrey400),
                  const SizedBox(width: 4),
                  Text(dateStr,
                      style: const TextStyle(fontSize: 11, color: _kGrey500)),
                ]),
              ),
            ]),

            // ── Admin reply display — blue-50 bg with left accent bar ──
            if (hasReply) ...[
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left 3px blue accent bar
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: _kBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _kBlue50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.verified_user_outlined, size: 13, color: _kBlue),
                            SizedBox(width: 5),
                            Text('JIBU LA ADMIN',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _kBlue,
                                    letterSpacing: 0.8)),
                          ]),
                          const SizedBox(height: 6),
                          Text(adminReply.toString(),
                              style: const TextStyle(
                                  fontSize: 13, color: _kGrey700, height: 1.5)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Reply toggle / input ──
            const SizedBox(height: 12),
            if (!_showReply && !hasReply)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showReply = true),
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: const Text('Jibu Maoni',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kBlue,
                    backgroundColor: _kBlue50,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            else if (_showReply || hasReply) ...[
              if (hasReply)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Badilisha jibu:',
                    style: TextStyle(
                        fontSize: 11,
                        color: _kGrey500,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kGrey50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kGrey200),
                    ),
                    child: TextField(
                      controller: _replyCtrl,
                      style: const TextStyle(fontSize: 13, color: _kGrey900),
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: hasReply ? 'Badilisha jibu...' : 'Andika jibu...',
                        hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)))
                        : const Center(
                            child: Icon(Icons.send_rounded,
                                size: 18, color: Colors.white)),
                  ),
                ),
              ]),
              if (!hasReply) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => setState(() => _showReply = false),
                  child: const Text('Ghairi',
                      style: TextStyle(
                          fontSize: 11, color: _kGrey500,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Small badge widget ─────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;

  const _Badge({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}
