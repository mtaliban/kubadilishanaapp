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
        setState(() => _live = true);
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
        '${f['subject'] ?? ''}${f['message'] ?? ''}${f['user_name'] ?? f['name'] ?? ''}'
          .toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _applyFilter() => setState(() { _items = _computeFiltered(); _page = 1; });

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res  = await ApiService().adminListFeedback(status: '', q: '');
      final data = res.data;
      if (mounted) {
        _allItems = (data is Map
            ? (data['items'] ?? data['feedback'] ?? [])
            : data) as List<dynamic>;
        setState(() {
          _items   = _computeFiltered();
          _page    = 1;
          _loading = false;
          _live    = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        if (!silent) _showFlash('Hitilafu ya kupakia', ok: false);
      }
    }
  }

  void _showFlash(String msg, {bool ok = true}) {
    _flashTimer?.cancel();
    setState(() { _flash = msg; _flashOk = ok; });
    _flashTimer = Timer(const Duration(seconds: 4),
        () { if (mounted) setState(() => _flash = null); });
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    final id = f['_id'] ?? f['id'];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 4, margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(color: _kGrey300, borderRadius: BorderRadius.circular(2))),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: _kRed50, shape: BoxShape.circle),
            child: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 24),
          ),
          const SizedBox(height: 12),
          const Text('Futa Maoni?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
          const SizedBox(height: 4),
          const Text('Hayawezi kurudishwa baada ya kufuta.',
            style: TextStyle(fontSize: 12, color: _kGrey500)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kGrey200),
                foregroundColor: _kGrey700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Hapana', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: _kRed,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Futa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().adminDeleteFeedback(id);
      _showFlash('Yamefutwa');
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
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.rate_review_rounded, size: 20, color: _kBlue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Maoni na Malalamiko',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kGrey900)),
                if (_live) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _kGreen50, borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kGreen200)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 6, color: _kGreenDk),
                      SizedBox(width: 4),
                      Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kGreenDk)),
                    ]),
                  ),
                ],
              ]),
              const SizedBox(height: 1),
              const Text('Maoni ya watumiaji',
                style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
          ]),
        ),

        const Divider(height: 1, color: _kGrey100),

        // ── Stats row (compact pills) ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            _StatPill(label: 'Zote',      count: totalCount,   icon: Icons.inbox_rounded,              color: _kBlue),
            const SizedBox(width: 6),
            _StatPill(label: 'Wazi',      count: openCount,    icon: Icons.mail_outline_rounded,        color: _kAmber700),
            const SizedBox(width: 6),
            _StatPill(label: 'Imejibiwa', count: repliedCount, icon: Icons.mark_email_read_outlined,    color: _kGreenDk),
          ]),
        ),

        // ── Filter + Search row ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            // Filter chips
            _FilterChip(label: 'Zote',      value: '',        current: _status, onTap: _setStatus),
            const SizedBox(width: 6),
            _FilterChip(label: 'Wazi',      value: 'open',    current: _status, onTap: _setStatus),
            const SizedBox(width: 6),
            _FilterChip(label: 'Imejibiwa', value: 'replied', current: _status, onTap: _setStatus),
            const Spacer(),
            // Search icon tap → expand
            GestureDetector(
              onTap: () async {
                await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 32, height: 4, margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(color: _kGrey300, borderRadius: BorderRadius.circular(2))),
                        TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: _onSearch,
                          style: const TextStyle(fontSize: 13, color: _kGrey900),
                          decoration: InputDecoration(
                            hintText: 'Tafuta jina au ujumbe...',
                            hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kGrey400),
                            filled: true, fillColor: _kGrey50,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _kGrey200),
                              foregroundColor: _kGrey700,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Tafuta', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              },
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _q.isNotEmpty ? _kBlue50 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _q.isNotEmpty ? _kBlue200 : _kGrey200),
                ),
                child: Icon(Icons.search_rounded, size: 17,
                  color: _q.isNotEmpty ? _kBlue : _kGrey400),
              ),
            ),
          ]),
        ),

        // ── Flash ─────────────────────────────────────────────────────────
        if (_flash != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _flashOk ? _kGreen50 : _kRed50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _flashOk ? _kGreen200 : _kRed200),
              ),
              child: Row(children: [
                Icon(_flashOk ? Icons.check_circle_outline : Icons.error_outline,
                  size: 14, color: _flashOk ? _kGreenDk : _kRed),
                const SizedBox(width: 7),
                Expanded(child: Text(_flash!,
                  style: TextStyle(fontSize: 12, color: _flashOk ? _kGreenDk : _kRed))),
              ]),
            ),
          ),

        // ── Count ─────────────────────────────────────────────────────────
        if (!_loading && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('${pageItems.length} / ${_items.length} maoni',
              style: const TextStyle(fontSize: 11, color: _kGrey400)),
          ),

        // ── List ──────────────────────────────────────────────────────────
        Expanded(
          child: _loading
            ? const Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
            : RefreshIndicator(
                onRefresh: () => _load(),
                color: _kBlue,
                child: _items.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 56, height: 56,
                        decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(28)),
                        child: const Icon(Icons.inbox_outlined, size: 28, color: _kGrey400)),
                      const SizedBox(height: 10),
                      const Text('Hakuna maoni',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey500)),
                      const SizedBox(height: 3),
                      const Text('Maoni mapya yataonekana hapa',
                        style: TextStyle(fontSize: 12, color: _kGrey400)),
                    ]))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      children: [
                        ...pageItems.asMap().entries.map((e) => _FeedbackCard(
                          key: ValueKey(e.value['_id'] ?? e.value['id'] ?? e.key),
                          f: Map<String, dynamic>.from(e.value as Map),
                          onDelete: _delete,
                          onReplied: () { _showFlash('Jibu limetumwa'); _load(silent: true); },
                          onFlash: _showFlash,
                        )),
                        if (totalPages > 1)
                          _PaginationRow(page: _page, totalPages: totalPages,
                            onPage: (p) => setState(() => _page = p)),
                        const SizedBox(height: 64),
                      ],
                    ),
              ),
        ),
      ],
    );
  }
}

// ── Stat pill (compact) ───────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text('$count',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Flexible(child: Text(label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
            overflow: TextOverflow.ellipsis)),
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
        duration: const Duration(milliseconds: 160),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _kBlue : _kGrey200),
        ),
        child: Center(child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
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
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: active ? _kBlue : _kGrey200),
        ),
        child: Center(child: Text('$n',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : _kGrey700))),
      ),
    );
  }

  Widget _nav(IconData icon, VoidCallback? cb) => GestureDetector(
    onTap: cb,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _kGrey200)),
      child: Icon(icon, size: 16, color: cb != null ? _kGrey700 : _kGrey300),
    ),
  );
}

class _Ellipsis extends StatelessWidget {
  const _Ellipsis();
  @override
  Widget build(BuildContext context) =>
    const SizedBox(width: 30, height: 30,
      child: Center(child: Text('…', style: TextStyle(fontSize: 13, color: _kGrey400))));
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
      await ApiService().adminReplyFeedback(
          widget.f['_id'] ?? widget.f['id'], _replyCtrl.text.trim());
      _replyCtrl.clear();
      setState(() { _sending = false; _showReply = false; });
      widget.onReplied();
    } catch (_) {
      setState(() => _sending = false);
      widget.onFlash('Hitilafu ya kutuma jibu', ok: false);
    }
  }

  ({Color stripe, Color bg, Color fg, Color border, String label, IconData icon})
      _type(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('malalamiko') || t.contains('complaint'))
      return (stripe: _kRed,      bg: _kRed50,    fg: _kRed,      border: _kRed200,    label: 'Malalamiko', icon: Icons.report_outlined);
    if (t.contains('swali') || t.contains('question'))
      return (stripe: _kPurple700, bg: _kPurple50, fg: _kPurple700, border: _kPurple200, label: 'Swali',      icon: Icons.help_outline_rounded);
    if (t.contains('tatizo') || t.contains('bug'))
      return (stripe: _kOrange700, bg: _kOrange50, fg: _kOrange700, border: _kOrange200, label: 'Tatizo',     icon: Icons.bug_report_outlined);
    return   (stripe: _kBlue,      bg: _kBlue50,   fg: _kBlue,     border: _kBlue200,   label: 'Maoni',      icon: Icons.chat_bubble_outline_rounded);
  }

  Color _avatarBg(String n) {
    const c = [Color(0xFF1E40AF), Color(0xFF6D28D9), Color(0xFF065F46),
                Color(0xFF92400E), Color(0xFF991B1B)];
    return n.isEmpty ? c[0] : c[n.codeUnitAt(0) % c.length];
  }

  @override
  Widget build(BuildContext context) {
    final f         = widget.f;
    final reply     = f['admin_reply'] ?? f['reply'];
    final hasReply  = reply != null && reply.toString().isNotEmpty;
    final subject   = (f['subject']   ?? '').toString().trim();
    final message   = (f['message']   ?? '').toString();
    final name      = (f['user_name'] ?? f['name'] ?? 'Mtumiaji').toString();
    final phone     = (f['user_phone'] ?? f['phone'] ?? '').toString().trim();
    final rawType   = (f['type'] ?? f['category'] ?? '').toString();
    final dateRaw   = (f['created_at'] ?? f['createdAt'] ?? '').toString();
    final dateStr   = dateRaw.isNotEmpty
        ? dateRaw.replaceAll('T', ' ').split('.').first : '';

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final tp      = _type(rawType.isNotEmpty ? rawType : subject);
    final stripe  = hasReply ? _kGreenDk : tp.stripe;
    final isLong  = message.length > 130;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasReply ? _kGreen200 : _kGrey200),
        boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Left stripe
            Container(width: 4, color: stripe),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Top row: avatar + name + badges + delete ──
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    // Avatar
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _avatarBg(name), shape: BoxShape.circle),
                      child: Center(child: Text(initial,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))),
                    ),
                    const SizedBox(width: 8),

                    // Name + phone
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900),
                        overflow: TextOverflow.ellipsis),
                      if (phone.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.phone_outlined, size: 10, color: _kGrey400),
                          const SizedBox(width: 3),
                          Text(phone, style: const TextStyle(fontSize: 10, color: _kGrey500)),
                        ]),
                    ])),

                    // Status + type badges
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _Pill(
                        label: hasReply ? 'Imejibiwa' : 'Mpya',
                        bg: hasReply ? _kGreen50 : _kAmber50,
                        fg: hasReply ? _kGreenDk : _kAmber700,
                        border: hasReply ? _kGreen200 : _kAmber200,
                        icon: hasReply ? Icons.check_circle_outline : Icons.schedule_rounded,
                      ),
                      const SizedBox(height: 3),
                      _Pill(label: tp.label, bg: tp.bg, fg: tp.fg, border: tp.border, icon: tp.icon),
                    ]),
                    const SizedBox(width: 6),

                    // Delete button
                    GestureDetector(
                      onTap: () => widget.onDelete(widget.f),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: _kRed50, borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: _kRed200)),
                        child: const Icon(Icons.delete_outline_rounded, size: 14, color: _kRed),
                      ),
                    ),
                  ]),

                  // Subject
                  if (subject.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(subject,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kGrey900)),
                  ],

                  // Message
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: isLong ? () => setState(() => _expanded = !_expanded) : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(message,
                        style: const TextStyle(fontSize: 12, color: _kGrey700, height: 1.55),
                        maxLines: _expanded ? null : 3,
                        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis),
                      if (isLong) Row(children: [
                        Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 13, color: _kBlue),
                        Text(_expanded ? 'Punguza' : 'Soma zaidi',
                          style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  ),

                  // Date + reply button row
                  const SizedBox(height: 8),
                  Row(children: [
                    // Date
                    Row(children: [
                      const Icon(Icons.access_time_rounded, size: 11, color: _kGrey400),
                      const SizedBox(width: 3),
                      Text(dateStr, style: const TextStyle(fontSize: 10, color: _kGrey400)),
                    ]),
                    const Spacer(),
                    // Jibu button — small, inline
                    if (!_showReply && !hasReply)
                      GestureDetector(
                        onTap: () => setState(() => _showReply = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kBlue50, borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: _kBlue200)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.reply_rounded, size: 13, color: _kBlue),
                            SizedBox(width: 4),
                            Text('Jibu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kBlue)),
                          ]),
                        ),
                      ),
                    if (hasReply && !_showReply)
                      GestureDetector(
                        onTap: () => setState(() => _showReply = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kGrey50, borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: _kGrey200)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.edit_outlined, size: 12, color: _kGrey500),
                            SizedBox(width: 4),
                            Text('Badilisha', style: TextStyle(fontSize: 11, color: _kGrey500, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                  ]),

                  // Admin reply display
                  if (hasReply && !_showReply) ...[
                    const SizedBox(height: 8),
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Container(width: 3,
                          decoration: BoxDecoration(color: _kBlue,
                            borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Expanded(child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          decoration: BoxDecoration(
                            color: _kBlue50, borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBlue200)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Row(children: [
                              Icon(Icons.verified_user_outlined, size: 11, color: _kBlue),
                              SizedBox(width: 4),
                              Text('JIBU LA ADMIN', style: TextStyle(fontSize: 9,
                                fontWeight: FontWeight.bold, color: _kBlue, letterSpacing: 0.7)),
                            ]),
                            const SizedBox(height: 4),
                            Text(reply.toString(),
                              style: const TextStyle(fontSize: 12, color: _kGrey700, height: 1.5)),
                          ]),
                        )),
                      ]),
                    ),
                  ],

                  // Reply input
                  if (_showReply) ...[
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: TextField(
                          controller: _replyCtrl,
                          minLines: 2,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 12, color: _kGrey900),
                          decoration: InputDecoration(
                            hintText: hasReply ? 'Badilisha jibu...' : 'Andika jibu...',
                            hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
                            filled: true, fillColor: _kGrey50,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kGrey200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Column(children: [
                        // Send
                        GestureDetector(
                          onTap: _sending ? null : _send,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _sending ? _kBlue.withValues(alpha: 0.5) : _kBlue,
                              borderRadius: BorderRadius.circular(8)),
                            child: _sending
                              ? const Center(child: SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                              : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Cancel
                        GestureDetector(
                          onTap: () => setState(() => _showReply = false),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _kGrey50, borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kGrey200)),
                            child: const Icon(Icons.close_rounded, size: 16, color: _kGrey500),
                          ),
                        ),
                      ]),
                    ]),
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

// ── Pill badge ────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color bg, fg, border;
  final IconData icon;
  const _Pill({required this.label, required this.bg, required this.fg,
    required this.border, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5),
      border: Border.all(color: border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 9, color: fg),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    ]),
  );
}
