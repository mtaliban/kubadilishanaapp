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

const _kPageSize = 3;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _kBlue50, borderRadius: BorderRadius.circular(10)),
              child: const Center(
                  child: Icon(Icons.assignment_outlined, size: 20, color: _kBlue)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Maoni${totalCount > 0 ? " ($totalCount)" : ""}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900),
                ),
                const Text('Maoni na malalamiko ya watumiaji',
                    style: TextStyle(fontSize: 12, color: _kGrey500)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Status filter chips with counts ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _Chip(label: 'Zote ($totalCount)',         value: '',        current: _status, onTap: _setStatus),
              const SizedBox(width: 8),
              _Chip(label: 'Wazi ($openCount)',           value: 'open',    current: _status, onTap: _setStatus),
              const SizedBox(width: 8),
              _Chip(label: 'Imejibiwa ($repliedCount)',   value: 'replied', current: _status, onTap: _setStatus),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // ── Search box ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGrey200),
            ),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.search, size: 18, color: _kGrey500),
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
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                borderRadius: BorderRadius.circular(20),
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
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)))
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  color: _kBlue,
                  child: _items.isEmpty
                      ? const Center(
                          child: Text('Hakuna maoni bado',
                              style: TextStyle(fontSize: 13, color: _kGrey500)))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
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
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kBlue),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : _kGrey700,
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
        width: 28, height: 28,
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
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGrey200),
        ),
        child: Center(
            child: Icon(icon, size: 16, color: enabled ? _kGrey700 : _kGrey400)),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  const _Ellipsis();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28, height: 28,
      child: Center(
          child: Text('…', style: TextStyle(fontSize: 13, color: _kGrey400))),
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
      widget.onReplied();
    } catch (_) {
      setState(() => _sending = false);
      widget.onFlash('Hitilafu ya kutuma jibu', ok: false);
    }
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
    final rawDate    = (f['created_at'] ?? f['createdAt'] ?? '').toString();
    final dateStr    = rawDate.isNotEmpty ? rawDate.split('T').first : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header: index + name + badge + delete ──
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 22, height: 22,
            decoration:
                BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(6)),
            child: Center(
              child: Text('${widget.index}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: _kGrey500)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(userName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasReply ? _kGreen50 : _kAmber50,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: hasReply ? _kGreen200 : _kAmber200),
            ),
            child: Text(
              hasReply ? 'Imejibiwa' : 'Wazi',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: hasReply ? _kGreen700 : _kAmber700),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => widget.onDelete(widget.f),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _kRed50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kRed200),
              ),
              child:
                  const Center(child: Icon(Icons.delete_outline, size: 15, color: _kRed)),
            ),
          ),
        ]),

        // ── Phone ──
        if (userPhone.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.phone_outlined, size: 12, color: _kGrey400),
            const SizedBox(width: 4),
            Text(userPhone, style: const TextStyle(fontSize: 11, color: _kGrey500)),
          ]),
        ],

        // ── Subject ──
        if (subject.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subject,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey900)),
        ],

        // ── Message ──
        const SizedBox(height: 6),
        Text(message,
            style: const TextStyle(fontSize: 13, color: _kGrey700, height: 1.5)),

        // ── Date ──
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.access_time, size: 12, color: _kGrey400),
          const SizedBox(width: 4),
          Text(dateStr, style: const TextStyle(fontSize: 11, color: _kGrey500)),
        ]),

        // ── Admin reply display ──
        if (hasReply) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kBlue50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.verified_user_outlined, size: 12, color: _kBlue),
                SizedBox(width: 4),
                Text('JIBU LA ADMIN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _kBlue,
                        letterSpacing: 0.6)),
              ]),
              const SizedBox(height: 4),
              Text(adminReply.toString(),
                  style: const TextStyle(fontSize: 13, color: _kGrey700)),
            ]),
          ),
        ],

        // ── Reply input — always visible ──
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: _kGrey50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kGrey200),
              ),
              child: TextField(
                controller: _replyCtrl,
                style: const TextStyle(fontSize: 13, color: _kGrey900),
                decoration: InputDecoration(
                  hintText: hasReply ? 'Badilisha jibu...' : 'Andika jibu...',
                  hintStyle: const TextStyle(fontSize: 12, color: _kGrey400),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : const Center(
                      child: Icon(Icons.send, size: 16, color: Colors.white)),
            ),
          ),
        ]),
      ]),
    );
  }
}
