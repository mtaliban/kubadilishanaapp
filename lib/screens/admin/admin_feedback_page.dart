import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';
import '../../services/admin_badge_service.dart';
import '../../widgets/app_drawer.dart' show BadgeController, NavItem;
import '../../widgets/app_toast.dart';
import '../../services/network_service.dart';
import '../../services/offline_queue.dart';
import '../../services/websocket_service.dart';
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
const _kSoft    = Colors.white;

const _kPageSize = 5;

String _fmtDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}, $h:$m:$s';
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

  // ── LIVE halisi: WS inaita _load() maoni mapya yanapofika ──
  // (Bila hii "LIVE" ilikuwa ni maandishi tu — maoni mapya yangeonekana
  //  baada ya refresh mwenyewe tu.)
  void _onWs(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? payload['event'])?.toString() ?? '';
    if (type == 'feedback.new' && mounted) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
    WebSocketService().on('notification', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // SILENT REFRESH: spinner TU wakati hAKUNA data bado — refresh za
    // reply/delete/WS zinabadilisha list HAPO HAPO bila kukatiza mtumiaji.
    final first = _all.isEmpty && _loading;
    setState(() {
      if (first) _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminListFeedback(status: '', q: '');
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _all = data is List ? data : (data['items'] as List? ?? data['results'] as List? ?? []);
        _applyFilter(keepPage: true);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyError(e); });
    }
  }

  bool _isReplied(dynamic m) =>
      m['reply'] != null || (m['admin_reply'] as String? ?? '').isNotEmpty;

  int get _countUnanswered => _all.where((m) => !_isReplied(m)).length;
  int get _countAnswered => _all.where(_isReplied).length;

  void _applyFilter({bool keepPage = false}) {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = _all.where((item) {
        final m = asMap(item);
        final name  = (m['user_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final msg   = (m['message'] as String? ?? '').toLowerCase();
        final subj  = (m['subject'] as String? ?? '').toLowerCase();
        final phone = (m['user_phone'] as String? ?? m['phone'] as String? ?? '');
        final replied = _isReplied(m);
        final matchQ = q.isEmpty ||
            name.contains(q) ||
            msg.contains(q) ||
            subj.contains(q) ||
            phone.contains(q);
        bool matchF = true;
        if (_filter == 'Hayajajibiwa') matchF = !replied;
        if (_filter == 'Yamejibiwa') matchF = replied;
        return matchQ && matchF;
      }).toList();
      if (!keepPage) _page = 0;
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
    if (NetworkService().isOffline) {
      await OfflineQueue().enqueue(
        type: 'reply_feedback',
        payload: {'feedback_id': id, 'reply': text},
        displayText: 'Jibu maoni',
      );
      _showFlash('success', '⏳ Jibu limewekwa foleni — litatumwa mtandao ukiingia');
      return;
    }
    try {
      await ApiService().adminReplyFeedback(id, text);
      if (!mounted) return;
      _showFlash('success', 'Jibu limetumwa kwa mtumiaji');
      AdminBadgeService().refresh();
      // Badge ya Maoni ni "pending" — inaisha TU baada ya kujibu (siyo kufungua ukurasa)
      BadgeController.instance.decrement(NavItem.maoni);
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

                    // ── Vichujio: chips zenye duara za namba (kama picha) ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _FilterChip(
                          label: 'Yote',
                          count: _all.length,
                          badgeBg: _kGreenBg,
                          badgeFg: _kGreen,
                          badgeBorder: _kGreenBg,
                          selected: _filter == 'Yote',
                          onTap: () {
                            setState(() => _filter = 'Yote');
                            _applyFilter();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Yasiyojibiwa',
                          count: _countUnanswered,
                          badgeBg: _kRed,
                          badgeFg: Colors.white,
                          badgeBorder: _kRed,
                          selected: _filter == 'Hayajajibiwa',
                          onTap: () {
                            setState(() => _filter = 'Hayajajibiwa');
                            _applyFilter();
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Yaliyojibiwa',
                          count: _countAnswered,
                          badgeBg: _kGreenBg,
                          badgeFg: _kGreen,
                          badgeBorder: _kGreenBg,
                          selected: _filter == 'Yamejibiwa',
                          onTap: () {
                            setState(() => _filter = 'Yamejibiwa');
                            _applyFilter();
                          },
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),

                    // ── Tafuta ──
                    TextField(
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
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: _kBlue, width: 1.2),
                        ),
                      ),
                    ),
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
                    if (_loading && _all.isEmpty)
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

// ─── Kidonge cha kichujio + duara la namba (kama picha) ──────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color badgeBg;
  final Color badgeFg;
  final Color badgeBorder;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.count,
    required this.badgeBg,
    required this.badgeFg,
    required this.badgeBorder,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF6B7280) : _kBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kInk)),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: badgeBorder),
              ),
              child: Text('$count',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: badgeFg)),
            ),
          ],
        ),
      ),
    );
  }
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

  Future<void> _send() async {
    final id = widget.item['id']?.toString() ?? '';
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      AppToast.warning('Andika jibu kwanza');
      return;
    }
    setState(() => _sending = true);
    await widget.onReply(id, text);
    if (mounted) {
      _ctrl.clear();
      setState(() => _sending = false);
    }
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

    // Kichwa (bold) + ujumbe (kama picha): title = subject, body = message.
    final title = subject.isNotEmpty ? subject : msg;
    final body = (msg.isNotEmpty && msg != subject) ? msg : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mstari 1: namba + jina + simu (kulia, bluu) ──
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('${widget.index}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey400)),
              ),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
              ),
              const SizedBox(width: 8),
              if (phone.isNotEmpty)
                Flexible(
                  child: GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      AppToast.success('Namba imenakiliwa');
                    },
                    child: Text(phone,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600, color: _kBlue)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Mstari 2: hali (kushoto) + kufuta (kulia) ──
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusBadge(answered: replied),
                InkWell(
                  onTap: () => widget.onDelete(id),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _kRedBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Icon(PhosphorIcons.trash(), size: 16, color: _kRed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Kichwa (bold) na ujumbe ──
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, height: 1.4, color: _kInk)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body,
                style: GoogleFonts.inter(
                    fontSize: 15, height: 1.5, color: _kGrey)),
          ],
          const SizedBox(height: 10),

          // ── Muda ──
          Row(children: [
            Icon(PhosphorIcons.clock(), size: 15, color: _kInk),
            const SizedBox(width: 6),
            Text(_fmtDate(createdAt),
                style: GoogleFonts.inter(fontSize: 13, color: _kInk)),
          ]),

          // ── JIBU LAKO (kama limejibiwa) ──
          if (replied) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: _kBlueBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      size: 14, color: _kBlue),
                  const SizedBox(width: 6),
                  Text('JIBU LAKO',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _kBlue, letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 4),
                Text(reply,
                    style: GoogleFonts.inter(fontSize: 15, color: _kInk, height: 1.45)),
              ]),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),

          // ── Andika jibu + kitufe cha kutuma (bluu, ikoni tu — kama picha) ──
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: 2,
                  minLines: 1,
                  style: GoogleFonts.inter(fontSize: 14, color: _kInk),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Andika jibu lako...',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: _kGrey400),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kBlue, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _sending ? null : _send,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 46,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _sending ? _kGrey400 : _kBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                          size: 19, color: Colors.white),
                ),
              ),
            ],
          ),
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
    // Kama picha: "Yaliyojibiwa" (kijani, duara la check) /
    // "Yasiyojibiwa" (orange, saa).
    final fg = answered ? const Color(0xFF15803D) : const Color(0xFFC2410C);
    final bg = answered ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED);
    final bd = answered ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA);
    final label = answered ? 'Yaliyojibiwa' : 'Yasiyojibiwa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bd),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          answered ? Icons.check_circle_outline : Icons.access_time,
          size: 15, color: fg,
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
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
