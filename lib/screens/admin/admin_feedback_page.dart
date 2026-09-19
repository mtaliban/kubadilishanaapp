import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/api_service.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────
const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey300 = Color(0xFFD1D5DB);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey50  = Color(0xFFF9FAFB);

const _kPageSize = 5;

String _fmtDate(String iso) {
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    const months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
                    'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
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
  int _tabIndex = 0;
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

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((item) {
        final m = item as Map<String, dynamic>;
        final name    = (m['user_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final msg     = (m['message'] as String? ?? m['subject'] as String? ?? '').toLowerCase();
        final replied = m['reply'] != null || m['admin_reply'] != null;
        final matchQ  = q.isEmpty || name.contains(q) || msg.contains(q);
        bool matchTab = true;
        if (_tabIndex == 1) matchTab = !replied;
        if (_tabIndex == 2) matchTab = replied;
        return matchQ && matchTab;
      }).toList();
      _page = 0;
    });
  }

  void _setTab(int i) {
    setState(() { _tabIndex = i; });
    _applyFilter();
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
                  style: GoogleFonts.inter(fontSize: 13.5, color: _kGrey500)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: _kGrey200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Hapana',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _kGrey700)),
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
    final totalPages = (_filtered.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems = _loading || _error != null
        ? <dynamic>[]
        : _filtered.skip(_page * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── HERO ya gradient ──
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F3D73), Color(0xFF1D6FBF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(PhosphorIcons.chatCenteredDots(PhosphorIconsStyle.fill),
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Maoni',
                              style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text('Maoni na malalamiko ya watumiaji',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text('LIVE',
                              style: GoogleFonts.inter(
                                  fontSize: 10.5, fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8, color: Colors.white)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // ── Search ──
                    TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF141A2E)),
                      decoration: InputDecoration(
                        hintText: 'Tafuta maoni...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white60),
                        prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                            color: Colors.white60, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.12),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Tab chips ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _Chip(label: 'Yote', isSelected: _tabIndex == 0,
                            onTap: () => _setTab(0)),
                        const SizedBox(width: 8),
                        _Chip(label: 'Hayajajibiwa', isSelected: _tabIndex == 1,
                            onTap: () => _setTab(1)),
                        const SizedBox(width: 8),
                        _Chip(label: 'Yamejibiwa', isSelected: _tabIndex == 2,
                            onTap: () => _setTab(2)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // ── Flash message ──
            if (_flash != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _flash!['type'] == 'success' ? _kGreenBg : _kRedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(
                      _flash!['type'] == 'success'
                          ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                          : PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                      size: 14,
                      color: _flash!['type'] == 'success' ? _kGreen : _kRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_flash!['msg']!,
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _flash!['type'] == 'success' ? _kGreen : _kRed)),
                    ),
                  ]),
                ),
              ),

            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                        color: _kRed, size: 48),
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(PhosphorIcons.chatCenteredDots(), color: _kGrey400, size: 48),
                    const SizedBox(height: 12),
                    Text('Hakuna maoni',
                        style: GoogleFonts.inter(color: _kGrey500)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _FeedbackCard(
                      key: ValueKey(pageItems[i]['id'] ?? i),
                      index: (_page * _kPageSize) + i + 1,
                      item: pageItems[i] as Map<String, dynamic>,
                      onReply: _reply,
                      onDelete: _delete,
                    ),
                    childCount: pageItems.length,
                  ),
                ),
              ),

            // ── Pagination ──
            if (!_loading && _error == null && totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Center(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        _PaginationBtn(
                          icon: PhosphorIcons.caretLeft(),
                          enabled: _page > 0,
                          onTap: _page > 0 ? () => setState(() => _page--) : null,
                        ),
                        ...List.generate(totalPages, (i) => _PaginationNum(
                          n: i + 1,
                          active: _page == i,
                          onTap: () => setState(() => _page = i),
                        )),
                        _PaginationBtn(
                          icon: PhosphorIcons.caretRight(),
                          enabled: _page < totalPages - 1,
                          onTap: _page < totalPages - 1
                              ? () => setState(() => _page++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _kBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _kBlue : _kGrey200),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? _kBlue : _kGrey500,
          ),
        ),
      ),
    );
  }
}

// ─── Pagination widgets ────────────────────────────────────────────────────────

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
          color: active ? _kBlue : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text('$n',
            style: GoogleFonts.inter(
                fontSize: 12.5, fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kGrey500)),
      ),
    );
  }
}

class _PaginationBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _PaginationBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? _kGrey200 : _kGrey100),
        ),
        child: Icon(icon, size: 14, color: enabled ? _kGrey700 : _kGrey300),
      ),
    );
  }
}

// ─── Feedback card ─────────────────────────────────────────────────────────────

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
    final subject   = item['subject'] as String? ?? '';
    final msg       = item['message'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final reply     = item['reply'] as String? ?? item['admin_reply'] as String?;
    final replied   = reply != null;

    final fullText = subject.isNotEmpty
        ? (msg.isNotEmpty ? '$subject\n$msg' : subject)
        : msg;
    final isLong = fullText.length > 90;
    final displayText = (!_expanded && isLong)
        ? '${fullText.substring(0, 90)}...'
        : fullText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F1F1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index circle
              Container(
                width: 24, height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _kGrey100, shape: BoxShape.circle),
                child: Text('${widget.index}',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _kGrey500)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name,
                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(PhosphorIcons.phone(PhosphorIconsStyle.fill),
                          size: 12, color: _kGrey400),
                      const SizedBox(width: 4),
                      Text(phone,
                          style: GoogleFonts.inter(fontSize: 11.5, color: _kGrey400)),
                    ]),
                  ],
                ]),
              ),
              // Status badge (non-tappable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: replied ? _kGreenBg : _kAmberBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    replied
                        ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                        : PhosphorIcons.clock(PhosphorIconsStyle.fill),
                    size: 12,
                    color: replied ? _kGreen : _kAmber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    replied ? 'Imejibiwa' : 'Hayajajibiwa',
                    style: GoogleFonts.inter(
                        fontSize: 10.5, fontWeight: FontWeight.w600,
                        color: replied ? _kGreen : _kAmber),
                  ),
                ]),
              ),
              const SizedBox(width: 6),
              // Delete — icon button, distinct from status
              Material(
                color: _kRedBg,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => widget.onDelete(id),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(PhosphorIcons.trash(), size: 15, color: _kRed),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Message
          Text(displayText,
              style: GoogleFonts.inter(fontSize: 13, color: _kGrey700, height: 1.5)),
          if (isLong)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_expanded ? 'Ficha' : 'Soma zaidi',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _kBlue)),
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(PhosphorIcons.clock(), size: 12, color: _kGrey400),
            const SizedBox(width: 4),
            Text(_fmtDate(createdAt),
                style: GoogleFonts.inter(fontSize: 10.5, color: _kGrey400)),
          ]),

          // Admin reply box
          if (reply != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kBlueBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                      size: 13, color: _kBlue),
                  const SizedBox(width: 5),
                  Text('JIBU LAKO',
                      style: GoogleFonts.inter(
                          fontSize: 10.5, fontWeight: FontWeight.w700,
                          color: _kBlue, letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 5),
                Text(reply,
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: const Color(0xFF1E3A8A))),
              ]),
            ),
          ],

          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Andika jibu...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: _kGrey400),
                  filled: true,
                  fillColor: _kGrey50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kGrey200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kGrey200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
              icon: _sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.fill),
                      size: 14),
              label: Text('Jibu',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
