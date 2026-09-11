import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kBlue     = Color(0xFF1E40AF);
const _kBlue50   = Color(0xFFEFF6FF);
const _kBlue200  = Color(0xFFBFDBFE);
const _kGrey50   = Color(0xFFF9FAFB);
const _kGrey100  = Color(0xFFF3F4F6);
const _kGrey200  = Color(0xFFE5E7EB);
const _kGrey300  = Color(0xFFD1D5DB);
const _kGrey400  = Color(0xFF9CA3AF);
const _kGrey500  = Color(0xFF6B7280);
const _kGrey700  = Color(0xFF374151);
const _kGrey900  = Color(0xFF111827);
const _kGreen50  = Color(0xFFF0FDF4);
const _kGreen200 = Color(0xFFBBF7D0);
const _kGreen700 = Color(0xFF15803D);
const _kGreenDk  = Color(0xFF16A34A);
const _kRed      = Color(0xFFDC2626);
const _kRed50    = Color(0xFFFEF2F2);
const _kRed200   = Color(0xFFFEE2E2);
const _kAmber50  = Color(0xFFFFFBEB);
const _kAmber200 = Color(0xFFFDE68A);
const _kAmber700 = Color(0xFFB45309);
const _kPurple50  = Color(0xFFF5F3FF);
const _kPurple200 = Color(0xFFDDD6FE);
const _kPurple700 = Color(0xFF6D28D9);
const _kOrange50  = Color(0xFFFFF7ED);
const _kOrange200 = Color(0xFFFED7AA);
const _kOrange700 = Color(0xFFC2410C);

const _kPageSize = 10;

// ── Main page ──────────────────────────────────────────────────────────────
class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});
  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  List<dynamic> _allItems = [];
  List<dynamic> _items    = [];
  bool   _loading         = true;
  bool   _live            = false;
  String _status          = '';
  String _q               = '';
  int    _page            = 1;
  String? _flash;
  bool   _flashOk         = true;
  Timer? _debounce;
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
    final r = f['admin_reply'] ?? f['reply'];
    return r == null || r.toString().isEmpty;
  }

  List<dynamic> _computeFiltered() {
    var list = List<dynamic>.from(_allItems);
    if (_status == 'open')    list = list.where(_isOpen).toList();
    if (_status == 'replied') list = list.where((f) => !_isOpen(f)).toList();
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      list = list.where((f) =>
        (f['subject']   ?? '').toString().toLowerCase().contains(q) ||
        (f['message']   ?? '').toString().toLowerCase().contains(q) ||
        (f['user_name'] ?? f['name'] ?? '').toString().toLowerCase().contains(q),
      ).toList();
    }
    return list;
  }

  void _applyFilter() => setState(() { _items = _computeFiltered(); _page = 1; });

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res  = await ApiService().adminListFeedback(status: '', q: '');
      final data = res.data;
      if (mounted) {
        _allItems = (data is Map
            ? (data['items'] ?? data['feedback'] ?? [])
            : data) as List<dynamic>;
        setState(() { _items = _computeFiltered(); _page = 1; _loading = false; _live = false; });
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
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: _kGrey300, borderRadius: BorderRadius.circular(2)),
          ),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: _kRed50, borderRadius: BorderRadius.circular(28)),
            child: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Futa Maoni?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kGrey900)),
          const SizedBox(height: 6),
          const Text('Maoni haya yatafutwa kabisa na hayawezi kurudishwa.',
            style: TextStyle(fontSize: 13, color: _kGrey500), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kGrey200),
                  foregroundColor: _kGrey700,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Hapana', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _kRed,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Ndio, Futa', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
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

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      setState(() => _q = v.trim());
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

        // ── Header ────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEFF6FF), Colors.white],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.mark_chat_unread_outlined, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Maoni${totalCount > 0 ? " ($totalCount)" : ""}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900),
              ),
              const Text('Maoni na malalamiko ya watumiaji',
                style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
            if (_live)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGreen50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGreen200),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 7, color: _kGreenDk),
                  SizedBox(width: 5),
                  Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kGreenDk)),
                ]),
              ),
          ]),
        ),

        // ── Stat cards ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            _StatCard(label: 'Zote',      count: totalCount,   color: _kBlue,    bg: _kBlue50,   icon: Icons.inbox_outlined),
            const SizedBox(width: 8),
            _StatCard(label: 'Wazi',      count: openCount,    color: _kAmber700, bg: _kAmber50, icon: Icons.mark_email_unread_outlined),
            const SizedBox(width: 8),
            _StatCard(label: 'Imejibiwa', count: repliedCount, color: _kGreenDk, bg: _kGreen50,  icon: Icons.mark_email_read_outlined),
          ]),
        ),

        // ── Filter chips ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _FilterChip(label: 'Zote',      value: '',        current: _status, onTap: _setStatus),
            const SizedBox(width: 8),
            _FilterChip(label: 'Wazi',      value: 'open',    current: _status, onTap: _setStatus),
            const SizedBox(width: 8),
            _FilterChip(label: 'Imejibiwa', value: 'replied', current: _status, onTap: _setStatus),
          ]),
        ),

        // ── Search ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGrey200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.search_rounded, size: 18, color: _kGrey400),
              ),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  style: const TextStyle(fontSize: 13, color: _kGrey900),
                  decoration: const InputDecoration(
                    hintText: 'Tafuta jina, ujumbe...',
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

        // ── Flash ─────────────────────────────────────────────────────────
        if (_flash != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _flashOk ? _kGreen50 : _kRed50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _flashOk ? _kGreen200 : _kRed200),
              ),
              child: Row(children: [
                Icon(_flashOk ? Icons.check_circle_outline : Icons.error_outline,
                  size: 15, color: _flashOk ? _kGreenDk : _kRed),
                const SizedBox(width: 8),
                Expanded(child: Text(_flash!,
                  style: TextStyle(fontSize: 12, color: _flashOk ? _kGreenDk : _kRed))),
              ]),
            ),
          ),
        ],

        // ── Count row ─────────────────────────────────────────────────────
        if (!_loading && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text('Kuonyesha ${pageItems.length} kati ya ${_items.length}',
              style: const TextStyle(fontSize: 11, color: _kGrey400)),
          ),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
            ? const Center(child: SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBlue)))
            : RefreshIndicator(
                onRefresh: () => _load(),
                color: _kBlue,
                child: _items.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(32)),
                        child: const Icon(Icons.inbox_outlined, size: 32, color: _kGrey400),
                      ),
                      const SizedBox(height: 12),
                      const Text('Hakuna maoni',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kGrey500)),
                      const SizedBox(height: 4),
                      const Text('Maoni mapya yataonekana hapa',
                        style: TextStyle(fontSize: 12, color: _kGrey400)),
                    ]))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                      children: [
                        ...pageItems.asMap().entries.map((e) => _FeedbackCard(
                          key: ValueKey(e.value['_id'] ?? e.value['id'] ?? e.key),
                          f: Map<String, dynamic>.from(e.value as Map),
                          onDelete: _delete,
                          onReplied: () { _showFlash('Jibu limetumwa'); _load(silent: true); },
                          onFlash: _showFlash,
                        )),
                        if (totalPages > 1)
                          _PaginationRow(
                            page: _page, totalPages: totalPages,
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

// ── Stat card ──────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color, bg;
  final IconData icon;
  const _StatCard({required this.label, required this.count, required this.color, required this.bg, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text('$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, height: 1)),
          const SizedBox(height: 2),
          Text(label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75), fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _FilterChip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _kBlue : _kGrey200),
          boxShadow: active
            ? [BoxShadow(color: _kBlue.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
            : [],
        ),
        child: Center(child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : _kGrey500))),
      ),
    );
  }
}

// ── Pagination ────────────────────────────────────────────────────────────
class _PaginationRow extends StatelessWidget {
  final int page, totalPages;
  final void Function(int) onPage;
  const _PaginationRow({required this.page, required this.totalPages, required this.onPage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: _build()),
    );
  }

  List<Widget> _build() {
    final w = <Widget>[];
    w.add(_nav(Icons.chevron_left_rounded, page > 1 ? () => onPage(page - 1) : null));
    w.add(const SizedBox(width: 4));

    final show = <int>{1, totalPages, page};
    if (totalPages <= 7) {
      for (int i = 1; i <= totalPages; i++) show.add(i);
    } else {
      for (int i = page - 1; i <= page + 1; i++) {
        if (i >= 1 && i <= totalPages) show.add(i);
      }
    }
    final sorted = show.toList()..sort();
    for (int idx = 0; idx < sorted.length; idx++) {
      if (idx > 0) {
        if (sorted[idx] - sorted[idx - 1] > 1) {
          w.add(const SizedBox(width: 4));
          w.add(const _Ellipsis());
        }
        w.add(const SizedBox(width: 4));
      }
      w.add(_pageBtn(sorted[idx]));
    }

    w.add(const SizedBox(width: 4));
    w.add(_nav(Icons.chevron_right_rounded, page < totalPages ? () => onPage(page + 1) : null));
    return w;
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
        child: Center(child: Text('$n',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : _kGrey700))),
      ),
    );
  }

  Widget _nav(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGrey200)),
        child: Center(child: Icon(icon, size: 18, color: onTap != null ? _kGrey700 : _kGrey300)),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  const _Ellipsis();
  @override
  Widget build(BuildContext context) =>
    const SizedBox(width: 32, height: 32,
      child: Center(child: Text('…', style: TextStyle(fontSize: 14, color: _kGrey400))));
}

// ── Feedback card ──────────────────────────────────────────────────────────
class _FeedbackCard extends StatefulWidget {
  final Map<String, dynamic> f;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final VoidCallback onReplied;
  final void Function(String, {bool ok}) onFlash;

  const _FeedbackCard({
    super.key,
    required this.f,
    required this.onDelete,
    required this.onReplied,
    required this.onFlash,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  final _replyCtrl = TextEditingController();
  bool _sending   = false;
  bool _expanded  = false;
  bool _showReply = false;

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

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

  // ── Type badge ────────────────────────────────────────────────────────
  ({String label, Color bg, Color fg, Color border, IconData icon, Color stripe})
      _typeBadge(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('malalamiko') || t.contains('complaint'))
      return (label: 'Malalamiko', bg: _kRed50,     fg: _kRed,      border: _kRed200,    icon: Icons.report_outlined,        stripe: _kRed);
    if (t.contains('swali') || t.contains('question'))
      return (label: 'Swali',      bg: _kPurple50,   fg: _kPurple700, border: _kPurple200, icon: Icons.help_outline,           stripe: _kPurple700);
    if (t.contains('tatizo') || t.contains('bug'))
      return (label: 'Tatizo',     bg: _kOrange50,   fg: _kOrange700, border: _kOrange200, icon: Icons.bug_report_outlined,    stripe: _kOrange700);
    return               (label: 'Maoni',       bg: _kBlue50,    fg: _kBlue,     border: _kBlue200,   icon: Icons.chat_bubble_outline,    stripe: _kBlue);
  }

  Color _avatarColor(String name) {
    const colors = [Color(0xFF1E40AF), Color(0xFF6D28D9), Color(0xFF065F46),
                    Color(0xFF92400E), Color(0xFF991B1B), Color(0xFF1E3A5F)];
    return name.isEmpty ? colors[0] : colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final f          = widget.f;
    final adminReply = f['admin_reply'] ?? f['reply'];
    final hasReply   = adminReply != null && adminReply.toString().isNotEmpty;
    final subject    = (f['subject']   ?? '').toString().trim();
    final message    = (f['message']   ?? '').toString();
    final userName   = (f['user_name'] ?? f['name'] ?? 'Mtumiaji').toString();
    final userPhone  = (f['user_phone'] ?? f['phone'] ?? '').toString().trim();
    final rawType    = (f['type'] ?? f['category'] ?? '').toString();
    final rawDate    = (f['created_at'] ?? f['createdAt'] ?? '').toString();
    final dateStr    = rawDate.isNotEmpty
        ? rawDate.replaceAll('T', ' ').split('.').first : '';

    final initial     = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    final avatarColor = _avatarColor(userName);
    final badge       = _typeBadge(rawType.isNotEmpty ? rawType : subject);
    final stripeColor = hasReply ? _kGreenDk : badge.stripe;
    final isLong      = message.length > 140;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasReply ? _kGreen200 : _kGrey200),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Left accent stripe ─────────────────────────────────────
            Container(width: 4, color: stripeColor),

            // ── Card body ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Row 1: Avatar + name/phone + badges + delete ──
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Avatar
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: avatarColor, borderRadius: BorderRadius.circular(21)),
                      child: Center(child: Text(initial,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white))),
                    ),
                    const SizedBox(width: 10),

                    // Name + phone
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(userName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900),
                        overflow: TextOverflow.ellipsis),
                      if (userPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.phone_outlined, size: 11, color: _kGrey400),
                          const SizedBox(width: 3),
                          Text(userPhone, style: const TextStyle(fontSize: 11, color: _kGrey500)),
                        ]),
                      ],
                    ])),

                    // Badges
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _BadgePill(
                        label: hasReply ? 'Imejibiwa' : 'Mpya',
                        bg: hasReply ? _kGreen50  : _kAmber50,
                        fg: hasReply ? _kGreenDk  : _kAmber700,
                        border: hasReply ? _kGreen200 : _kAmber200,
                        icon: hasReply ? Icons.check_circle_outline : Icons.schedule_rounded,
                      ),
                      const SizedBox(height: 4),
                      _BadgePill(
                        label: badge.label, bg: badge.bg, fg: badge.fg,
                        border: badge.border, icon: badge.icon,
                      ),
                    ]),

                    // Delete
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => widget.onDelete(widget.f),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _kRed50, borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kRed200),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: _kRed),
                      ),
                    ),
                  ]),

                  // ── Subject ──────────────────────────────────────────
                  if (subject.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(subject,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGrey900)),
                  ],

                  // ── Message ───────────────────────────────────────────
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: isLong ? () => setState(() => _expanded = !_expanded) : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(message,
                        style: const TextStyle(fontSize: 13, color: _kGrey700, height: 1.6),
                        maxLines: _expanded ? null : 3,
                        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis),
                      if (isLong) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 14, color: _kBlue),
                          Text(_expanded ? 'Onyesha kidogo' : 'Soma zaidi',
                            style: const TextStyle(fontSize: 11, color: _kBlue, fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ]),
                  ),

                  // ── Date ──────────────────────────────────────────────
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kGrey50, borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kGrey200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: _kGrey400),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(fontSize: 11, color: _kGrey500)),
                    ]),
                  ),

                  // ── Admin reply block ─────────────────────────────────
                  if (hasReply) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _kBlue50, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBlue200),
                      ),
                      child: IntrinsicHeight(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Container(
                            width: 3,
                            decoration: const BoxDecoration(
                              color: _kBlue,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Row(children: [
                                  Icon(Icons.verified_user_outlined, size: 12, color: _kBlue),
                                  SizedBox(width: 5),
                                  Text('JIBU LA ADMIN', style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold, color: _kBlue, letterSpacing: 0.8)),
                                ]),
                                const SizedBox(height: 5),
                                Text(adminReply.toString(),
                                  style: const TextStyle(fontSize: 13, color: _kGrey700, height: 1.5)),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],

                  // ── Reply section ─────────────────────────────────────
                  const SizedBox(height: 12),
                  if (!_showReply && !hasReply)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _showReply = true),
                        icon: const Icon(Icons.reply_rounded, size: 17),
                        label: const Text('Jibu Maoni',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kBlue,
                          backgroundColor: _kBlue50,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          side: const BorderSide(color: _kBlue200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    )
                  else if (_showReply || hasReply) ...[
                    if (hasReply)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('Badilisha jibu:',
                          style: const TextStyle(fontSize: 11, color: _kGrey500, fontWeight: FontWeight.w600)),
                      ),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _kGrey50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kGrey200),
                          ),
                          child: TextField(
                            controller: _replyCtrl,
                            minLines: 2,
                            maxLines: 4,
                            style: const TextStyle(fontSize: 13, color: _kGrey900),
                            decoration: InputDecoration(
                              hintText: hasReply ? 'Badilisha jibu...' : 'Andika jibu lako...',
                              hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            color: _sending ? _kBlue.withValues(alpha: 0.5) : _kBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _sending
                            ? const Center(child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                            : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ]),
                    if (!hasReply) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => setState(() => _showReply = false),
                        child: const Text('Ghairi',
                          style: TextStyle(fontSize: 11, color: _kGrey500,
                            decoration: TextDecoration.underline, decorationColor: _kGrey400)),
                      ),
                    ],
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Badge pill widget ─────────────────────────────────────────────────────
class _BadgePill extends StatelessWidget {
  final String label;
  final Color bg, fg, border;
  final IconData icon;
  const _BadgePill({required this.label, required this.bg, required this.fg, required this.border, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}
