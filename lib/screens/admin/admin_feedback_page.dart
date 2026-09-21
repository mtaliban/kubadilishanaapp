import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';

// ─── Rangi (zingatia esstranfer.com/admin) ───────────────────────────────────
const _kBlue    = Color(0xFF1959D6);
const _kBlueBg  = Color(0xFFEAF0FE);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kOrange  = Color(0xFFEA5A0C);
const _kOrangeBg = Color(0xFFFFF3EB);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFCEBEB);
const _kInk     = Color(0xFF16181D);
const _kGrey    = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kBorder  = Color(0xFFECEEF1);
const _kSoft    = Color(0xFFF7F8FA);

const _kPageSize = 5;

String _fmtDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}, $h:$m';
  } catch (_) {
    return iso;
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});
  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  String _filter = 'Yote'; // Yote | Hayajajibiwa | Yamejibiwa
  int _page = 0;
  Map<String, String>? _flash;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminListFeedback(status: '', q: '');
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _all = data is List ? data : (data['items'] as List? ?? data['results'] as List? ?? []);
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  bool _isReplied(dynamic m) =>
      m['reply'] != null || (m['admin_reply'] as String? ?? '').isNotEmpty;

  int get _countUnanswered => _all.where((m) => !_isReplied(m)).length;
  int get _countAnswered => _all.where(_isReplied).length;

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = _all.where((item) {
        final m = asMap(item);
        final name  = (m['user_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final msg   = (m['message'] as String? ?? m['subject'] as String? ?? '').toLowerCase();
        final phone = (m['user_phone'] as String? ?? m['phone'] as String? ?? '');
        final replied = _isReplied(m);
        final matchQ = q.isEmpty || name.contains(q) || msg.contains(q) || phone.contains(q);
        bool matchF = true;
        if (_filter == 'Hayajajibiwa') matchF = !replied;
        if (_filter == 'Yamejibiwa') matchF = replied;
        return matchQ && matchF;
      }).toList();
      _page = 0;
    });
  }

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _showFlash(String type, String msg) {
    setState(() => _flash = {'type': type, 'msg': msg});
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: const BoxDecoration(color: _kRedBg, shape: BoxShape.circle),
                child: Icon(PhosphorIcons.trash(PhosphorIconsStyle.fill),
                    color: _kRed, size: 26),
              ),
              const SizedBox(height: 14),
              Text('Futa Maoni',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Una uhakika unataka kufuta maoni haya?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13.5, color: _kGrey)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Hapana',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _kInk)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Futa',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService().adminDeleteFeedback(id);
      if (!mounted) return;
      _showFlash('success', 'Yamefutwa');
      _load();
    } catch (e) {
      if (!mounted) return;
      _showFlash('error', 'Kosa: $e');
    }
  }

  Future<void> _reply(String id, String text) async {
    try {
      await ApiService().adminReplyFeedback(id, text);
      if (!mounted) return;
      _showFlash('success', 'Jibu limetumwa kwa mtumiaji');
      _load();
    } catch (e) {
      if (!mounted) return;
      _showFlash('error', 'Imeshindikana');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filtered.length / _kPageSize).ceil().clamp(1, 9999);
    final pageItems = _loading || _error != null
        ? <dynamic>[]
        : _filtered.skip(_page * _kPageSize).take(_kPageSize).toList();

    // Dirisha la kurasa 5
    int startPage = max(0, min(_page - 2, totalPages - 5));
    final windowPages = List.generate(min(5, totalPages), (i) => startPage + i);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title + LIVE ──
                    Row(children: [
                      Icon(PhosphorIcons.chatCenteredDots(PhosphorIconsStyle.fill),
                          color: _kBlue, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Maoni na Malalamiko',
                            style: GoogleFonts.inter(
                                fontSize: 22, fontWeight: FontWeight.w800, color: _kInk)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _kSoft,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  color: _kGreen, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text('LIVE',
                              style: GoogleFonts.inter(
                                  fontSize: 12.5, fontWeight: FontWeight.w700, color: _kInk)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Soma maoni ya watumiaji na uwajibu — real-time (maoni mapya yanafika papo hapo).',
                      style: GoogleFonts.inter(fontSize: 14, color: _kGrey, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // ── Filter (na counts) + Search pembeni ──
                    Row(children: [
                      Expanded(
                        child: _FilterDropdown(
                          value: _filter,
                          total: _all.length,
                          unanswered: _countUnanswered,
                          answered: _countAnswered,
                          onChanged: (v) {
                            setState(() => _filter = v);
                            _applyFilter();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.inter(fontSize: 14, color: _kInk),
                          decoration: InputDecoration(
                            hintText: 'Tafuta...',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: _kGrey400),
                            prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                                size: 18, color: _kGrey),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _kBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _kBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: _kBlue, width: 1.4),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),

                    // ── Flash ──
                    if (_flash != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _flash!['type'] == 'success' ? _kGreenBg : _kRedBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(
                            _flash!['type'] == 'success'
                                ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                                : PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                            size: 15,
                            color: _flash!['type'] == 'success' ? _kGreen : _kRed,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_flash!['msg']!,
                                style: GoogleFonts.inter(
                                    fontSize: 12.5, fontWeight: FontWeight.w600,
                                    color: _flash!['type'] == 'success' ? _kGreen : _kRed)),
                          ),
                        ]),
                      ),

                    // ── Loading / Error / Empty / Cards ──
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator(color: _kBlue)),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                                color: _kRed, size: 44),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _load,
                              icon: Icon(PhosphorIcons.arrowClockwise(), size: 16),
                              label: Text('Jaribu tena', style: GoogleFonts.inter()),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBlue, foregroundColor: Colors.white),
                            ),
                          ]),
                        ),
                      )
                    else if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(PhosphorIcons.chatCenteredDots(),
                                color: _kGrey400, size: 44),
                            const SizedBox(height: 12),
                            Text('Hakuna maoni',
                                style: GoogleFonts.inter(fontSize: 15, color: _kGrey)),
                          ]),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 10),
                      for (int i = 0; i < pageItems.length; i++) ...[
                        _FeedbackCard(
                          key: ValueKey(pageItems[i]['id'] ?? i),
                          index: (_page * _kPageSize) + i + 1,
                          item: asMap(pageItems[i]),
                          onReply: _reply,
                          onDelete: _delete,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Pagination (dirisha la kurasa 5) ──
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Center(
                            child: Wrap(
                              spacing: 6,
                              children: [
                                _PaginationBtn(
                                  icon: PhosphorIcons.caretLeft(),
                                  enabled: _page > 0,
                                  onTap: _page > 0 ? () => _goToPage(_page - 1) : null,
                                ),
                                for (final p in windowPages)
                                  _PaginationNum(
                                    n: p + 1,
                                    active: _page == p,
                                    onTap: () => _goToPage(p),
                                  ),
                                _PaginationBtn(
                                  icon: PhosphorIcons.caretRight(),
                                  enabled: _page < totalPages - 1,
                                  onTap: _page < totalPages - 1
                                      ? () => _goToPage(_page + 1)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter dropdown yenye counts ─────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String value;
  final int total;
  final int unanswered;
  final int answered;
  final ValueChanged<String> onChanged;
  const _FilterDropdown({
    required this.value,
    required this.total,
    required this.unanswered,
    required this.answered,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _item('Yote', 'Yote ($total)'),
        _item('Hayajajibiwa', 'Hayajajibiwa ($unanswered)'),
        _item('Yamejibiwa', 'Yamejibiwa ($answered)'),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              value == 'Yote' ? 'Yote ($total)' : value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 14, color: _kInk),
            ),
          ),
          Icon(PhosphorIcons.caretDown(), size: 16, color: _kGrey),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _item(String v, String label) => PopupMenuItem<String>(
        value: v,
        child: Row(children: [
          if (value == v) ...[
            Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), size: 15, color: _kBlue),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: value == v ? FontWeight.w700 : FontWeight.w400,
                  color: value == v ? _kBlue : _kInk)),
        ]),
      );
}

// ─── Kadi ya maoni ────────────────────────────────────────────────────────────

class _FeedbackCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final Future<void> Function(String id, String text) onReply;
  final Future<void> Function(String id) onDelete;
  const _FeedbackCard({
    super.key,
    required this.index,
    required this.item,
    required this.onReply,
    required this.onDelete,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _expanded = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item      = widget.item;
    final id        = item['id']?.toString() ?? '';
    final name      = item['user_name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
    final phone     = item['user_phone'] as String? ?? item['phone'] as String? ?? '';
    final msg       = item['message'] as String? ?? '';
    final subject   = item['subject'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final reply     = item['reply'] as String? ?? item['admin_reply'] as String?;
    final replied   = reply != null && reply.trim().isNotEmpty;

    final fullText = subject.isNotEmpty && msg.isNotEmpty && subject != msg
        ? '$subject\n$msg'
        : (subject.isNotEmpty ? subject : msg);
    final isLong = fullText.length > 120;
    final displayText = (!_expanded && isLong)
        ? '${fullText.substring(0, 120)}...'
        : fullText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Namba + jina + simu + badge + futa ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text('${widget.index}',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _kGrey400)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                              content: const Text('Namba imenakiliwa'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))));
                      },
                      child: Row(children: [
                        Icon(PhosphorIcons.phone(PhosphorIconsStyle.fill),
                            size: 13, color: _kBlue),
                        const SizedBox(width: 5),
                        Text(phone,
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600, color: _kBlue)),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(width: 6),
              _StatusBadge(answered: replied),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => widget.onDelete(id),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kRedBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(PhosphorIcons.trash(), size: 16, color: _kRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Swali (kubwa, bold) ──
          Text(displayText,
              style: GoogleFonts.inter(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: _kInk, height: 1.5)),
          if (isLong)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_expanded ? 'Ficha' : 'Soma zaidi',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: _kBlue)),
              ),
            ),
          const SizedBox(height: 8),

          // ── Muda ──
          Row(children: [
            Icon(PhosphorIcons.clock(), size: 13, color: _kGrey400),
            const SizedBox(width: 5),
            Text(_fmtDate(createdAt),
                style: GoogleFonts.inter(fontSize: 12, color: _kGrey400)),
          ]),

          // ── JIBU LAKO ──
          if (replied) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBlueBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      size: 13, color: _kBlue),
                  const SizedBox(width: 6),
                  Text('JIBU LAKO',
                      style: GoogleFonts.inter(
                          fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: _kBlue, letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 6),
                Text(reply,
                    style: GoogleFonts.inter(fontSize: 14, color: _kInk, height: 1.45)),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 12),

          // ── Andika jibu + Jibu ──
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: GoogleFonts.inter(fontSize: 14, color: _kInk),
                decoration: InputDecoration(
                  hintText: 'Andika jibu lako...',
                  hintStyle: GoogleFonts.inter(fontSize: 13.5, color: _kGrey400),
                  filled: true,
                  fillColor: _kSoft,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: _kBlue)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _sending
                  ? null
                  : () async {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;
                      setState(() => _sending = true);
                      await widget.onReply(id, text);
                      if (mounted) {
                        _ctrl.clear();
                        setState(() => _sending = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                      size: 15),
              label: Text('Jibu',
                  style: GoogleFonts.inter(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Badge ya hali ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool answered;
  const _StatusBadge({required this.answered});

  @override
  Widget build(BuildContext context) {
    final color = answered ? _kGreen : _kOrange;
    final bg = answered ? _kGreenBg : _kOrangeBg;
    final label = answered ? 'Imejibiwa' : 'Hayajajibiwa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          answered
              ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
              : PhosphorIcons.clock(PhosphorIconsStyle.fill),
          size: 12, color: color,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ─── Pagination ───────────────────────────────────────────────────────────────

class _PaginationBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _PaginationBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : _kSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        child: Icon(icon, size: 15, color: enabled ? _kInk : _kGrey400),
      ),
    );
  }
}

class _PaginationNum extends StatelessWidget {
  final int n;
  final bool active;
  final VoidCallback onTap;
  const _PaginationNum({required this.n, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kBlue : _kBorder),
        ),
        child: Text('$n',
            style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : _kInk)),
      ),
    );
  }
}
