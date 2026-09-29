// =============================================================================
// malipo_view.dart — standalone "Malipo" view widget
// admin_payments_page.dart inapakia data na kuipitisha hapa.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum PaymentStatus { pending, approved, rejected }

class PaymentMessage {
  final bool fromAdmin;
  final String text;
  final DateTime at;
  const PaymentMessage({
    required this.fromAdmin,
    required this.text,
    required this.at,
  });
}

class Payment {
  final String id;
  final String name;
  final String phone;
  final int amount;
  final String reference;
  final DateTime? createdAt;
  final PaymentStatus status;
  final String sms;
  final String note;
  final List<PaymentMessage> messages;

  const Payment({
    required this.id,
    required this.name,
    required this.phone,
    required this.amount,
    required this.reference,
    this.createdAt,
    required this.status,
    this.sms = '',
    this.note = '',
    this.messages = const [],
  });

  Payment copyWith({
    String? id,
    String? name,
    String? phone,
    int? amount,
    String? reference,
    DateTime? createdAt,
    PaymentStatus? status,
    String? sms,
    String? note,
    List<PaymentMessage>? messages,
  }) =>
      Payment(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        amount: amount ?? this.amount,
        reference: reference ?? this.reference,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        sms: sms ?? this.sms,
        note: note ?? this.note,
        messages: messages ?? this.messages,
      );
}

// ── Colors ────────────────────────────────────────────────────────────────────

class _MC {
  final bool _d;
  const _MC(this._d);

  Color get bg       => _d ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
  Color get card     => _d ? const Color(0xFF161B22) : Colors.white;
  Color get ink      => _d ? const Color(0xFFF0F6FF) : const Color(0xFF0F172A);
  Color get inkSoft  => _d ? const Color(0xFF8B949E) : const Color(0xFF475569);
  Color get inkFaint => _d ? const Color(0xFF484F58) : const Color(0xFFCBD5E1);
  Color get border   => _d ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
  Color get panel    => _d ? const Color(0xFF1C2128) : const Color(0xFFF1F5F9);

  Color get blue    => const Color(0xFF1959D6);
  Color get blueBg  => _d ? const Color(0xFF1A2744) : const Color(0xFFEFF4FF);

  Color get green    => const Color(0xFF16A34A);
  Color get greenBg  => _d ? const Color(0xFF0D2818) : const Color(0xFFDCFCE7);
  Color get greenFill => const Color(0xFF16A34A);

  Color get amber    => const Color(0xFFD97706);
  Color get amberBg  => _d ? const Color(0xFF2D1F00) : const Color(0xFFFEF3C7);
  Color get amberFill => const Color(0xFFD97706);

  Color get red    => const Color(0xFFDC2626);
  Color get redBg  => _d ? const Color(0xFF2D0A0A) : const Color(0xFFFEE2E2);
  Color get redFill => const Color(0xFFDC2626);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts[0][0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

String _fmtAmount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  const m = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]} ${d.year} · $hh:$mm';
}

String _fmtTime(DateTime d) {
  const m = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]} · $hh:$mm';
}

// ═══ MalipoView ══════════════════════════════════════════════════════════════

const _kPageSize = 10;

class MalipoView extends StatefulWidget {
  final List<Payment> payments;
  final Future<void> Function(Payment p)? onApprove;
  final Future<void> Function(Payment p, String reason)? onReject;
  final Future<PaymentMessage?> Function(Payment p, String text)? onSendMessage;
  final List<String> rejectReasons;
  final List<String> quickReplies;

  const MalipoView({
    super.key,
    required this.payments,
    this.onApprove,
    this.onReject,
    this.onSendMessage,
    this.rejectReasons = const [
      'SMS si halisi',
      'Kiasi hakilingani',
      'Pesa haijaingia',
      'Malipo yamerudiwa',
    ],
    this.quickReplies = const [
      'Tuma SMS sahihi',
      'Kiasi hakilingani',
    ],
  });

  @override
  State<MalipoView> createState() => _MalipoViewState();
}

class _MalipoViewState extends State<MalipoView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _filter = 'all';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _page = 0));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  List<Payment> get _filtered {
    final q = _search.text.toLowerCase().trim();
    return widget.payments.where((p) {
      if (_filter == 'pending' && p.status != PaymentStatus.pending) return false;
      if (_filter == 'approved' && p.status != PaymentStatus.approved) return false;
      if (_filter == 'rejected' && p.status != PaymentStatus.rejected) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.phone.contains(q) ||
          p.reference.toLowerCase().contains(q);
    }).toList();
  }

  int get _totalPages =>
      (_filtered.length / _kPageSize).ceil().clamp(1, 1 << 30);
  int get _safePage => _page.clamp(0, _totalPages - 1);

  void _goPage(int p) {
    setState(() => _page = p.clamp(0, _totalPages - 1));
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void _openDetail(BuildContext ctx, Payment p, {bool startChat = false}) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        payment: p,
        startTab: startChat ? 1 : 0,
        quickReplies: widget.quickReplies,
        onSendMessage: widget.onSendMessage == null
            ? null
            : (text) => widget.onSendMessage!(p, text),
      ),
    );
  }

  Future<void> _approve(Payment p) async => widget.onApprove?.call(p);

  Future<void> _reject(Payment p) async {
    final mc = _MC(Theme.of(context).brightness == Brightness.dark);
    final reason =
        await _RejectSheet.show(context, widget.rejectReasons, mc);
    if (reason == null) return;
    await widget.onReject?.call(p, reason);
  }

  @override
  Widget build(BuildContext context) {
    final mc = _MC(Theme.of(context).brightness == Brightness.dark);
    final filtered = _filtered;
    final pg = _safePage;
    final pageItems =
        filtered.skip(pg * _kPageSize).take(_kPageSize).toList();

    final counts = {
      'all': widget.payments.length,
      'pending':
          widget.payments.where((p) => p.status == PaymentStatus.pending).length,
      'approved':
          widget.payments.where((p) => p.status == PaymentStatus.approved).length,
      'rejected':
          widget.payments.where((p) => p.status == PaymentStatus.rejected).length,
    };

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        // Title + Live badge
        Row(children: [
          Expanded(
            child: Text('Malipo',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: mc.ink)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: mc.greenBg,
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: mc.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('Live',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: mc.green)),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Thibitisha michango ya watumiaji',
            style: TextStyle(fontSize: 14, color: mc.inkSoft)),
        const SizedBox(height: 14),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in [
                ('all', 'Zote'),
                ('pending', 'Zinasubiri'),
                ('approved', 'Zimekamilika'),
                ('rejected', 'Zimekataliwa'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: '${entry.$2} (${counts[entry.$1]})',
                    active: _filter == entry.$1,
                    mc: mc,
                    onTap: () =>
                        setState(() {
                          _filter = entry.$1;
                          _page = 0;
                        }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search
        TextField(
          controller: _search,
          style: TextStyle(fontSize: 14, color: mc.ink),
          decoration: InputDecoration(
            hintText: 'Tafuta kwa jina, namba, au kodi...',
            hintStyle: TextStyle(fontSize: 14, color: mc.inkFaint),
            prefixIcon:
                Icon(Icons.search_rounded, size: 20, color: mc.inkSoft),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: mc.inkSoft),
                    onPressed: _search.clear,
                  ),
            filled: true,
            fillColor: mc.card,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: mc.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: mc.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: mc.blue, width: 1.4)),
          ),
        ),
        const SizedBox(height: 10),

        Text('Inaonyesha ${pageItems.length} kati ya ${filtered.length}',
            style: TextStyle(fontSize: 13, color: mc.inkSoft)),
        const SizedBox(height: 10),

        if (filtered.isEmpty)
          _EmptyState(mc: mc)
        else ...[
          for (final p in pageItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PaymentCard(
                payment: p,
                mc: mc,
                onOna: () => _openDetail(context, p, startChat: false),
                onOngea: () => _openDetail(context, p, startChat: true),
                onApprove: () => _approve(p),
                onReject: () => _reject(p),
              ),
            ),
          _Pager(
              page: pg, total: _totalPages, mc: mc, onTap: _goPage),
        ],
      ],
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final _MC mc;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.active,
      required this.mc,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? mc.blue : mc.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? mc.blue : mc.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : mc.inkSoft)),
      ),
    );
  }
}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  final _MC mc;
  final VoidCallback onOna;
  final VoidCallback onOngea;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentCard({
    required this.payment,
    required this.mc,
    required this.onOna,
    required this.onOngea,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final pending = p.status == PaymentStatus.pending;
    final msgCount = p.messages.length;

    return Container(
      decoration: BoxDecoration(
        color: mc.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mc.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                _StatusAvatar(
                    name: p.name, status: p.status, mc: mc),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: mc.ink)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.phone_outlined,
                              size: 13, color: mc.inkSoft),
                          const SizedBox(width: 4),
                          Text(p.phone,
                              style: TextStyle(
                                  fontSize: 13, color: mc.inkSoft)),
                        ]),
                      ]),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: p.status, mc: mc),
              ]),

              const SizedBox(height: 12),
              _Cut(mc: mc),
              const SizedBox(height: 12),

              // KIASI
              Text('KIASI',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: mc.inkFaint,
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(
                'TZS ${_fmtAmount(p.amount)}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: mc.ink,
                  decoration: p.status == PaymentStatus.rejected
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: mc.red,
                ),
              ),

              const SizedBox(height: 12),
              _Cut(mc: mc),
              const SizedBox(height: 12),

              // KODI
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('KODI',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: mc.inkFaint,
                            letterSpacing: 0.8)),
                    _CopyText(text: p.reference, mc: mc),
                  ]),

              const SizedBox(height: 16),

              // Steps
              _Steps(
                  status: p.status,
                  createdAt: p.createdAt,
                  mc: mc),

              const SizedBox(height: 16),

              // Bottom buttons
              Row(children: [
                _ChipBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Ongea',
                  count: msgCount,
                  filled: true,
                  mc: mc,
                  onTap: onOngea,
                ),
                const SizedBox(width: 8),
                _ChipBtn(
                  icon: Icons.remove_red_eye_outlined,
                  label: 'Ona',
                  mc: mc,
                  onTap: onOna,
                ),
                if (pending) ...[
                  const Spacer(),
                  _SquareBtn(
                    icon: Icons.close_rounded,
                    color: mc.red,
                    fill: false,
                    mc: mc,
                    onTap: onReject,
                  ),
                  const SizedBox(width: 8),
                  _SquareBtn(
                    icon: Icons.check_rounded,
                    color: mc.green,
                    fill: true,
                    mc: mc,
                    onTap: onApprove,
                  ),
                ],
              ]),
            ]),
      ),
    );
  }
}

// ─── Status Avatar ────────────────────────────────────────────────────────────

class _StatusAvatar extends StatelessWidget {
  final String name;
  final PaymentStatus status;
  final _MC mc;
  const _StatusAvatar(
      {required this.name, required this.status, required this.mc});

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeIcon) = switch (status) {
      PaymentStatus.approved => (mc.green, Icons.check_rounded),
      PaymentStatus.rejected => (mc.red, Icons.close_rounded),
      PaymentStatus.pending => (mc.amber, Icons.access_time_rounded),
    };
    return Stack(clipBehavior: Clip.none, children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: mc.blueBg,
        child: Text(_initials(name),
            style: TextStyle(
                color: mc.blue,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
      ),
      Positioned(
        bottom: -2,
        left: -2,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
            border: Border.all(color: mc.card, width: 2),
          ),
          child: Icon(badgeIcon, size: 10, color: Colors.white),
        ),
      ),
    ]);
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  final _MC mc;
  const _StatusBadge({required this.status, required this.mc});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      PaymentStatus.approved => ('Imekamilika', mc.green, mc.greenBg),
      PaymentStatus.rejected => ('Imekataliwa', mc.red, mc.redBg),
      PaymentStatus.pending => ('Inasubiri', mc.amber, mc.amberBg),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}

// ─── Cut (dashed separator) ───────────────────────────────────────────────────

class _Cut extends StatelessWidget {
  final _MC mc;
  const _Cut({required this.mc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 1,
        child: CustomPaint(painter: _DashPainter(mc.border)));
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const w = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + w, 0), paint);
      x += w + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

// ─── CopyText ─────────────────────────────────────────────────────────────────

class _CopyText extends StatefulWidget {
  final String text;
  final _MC mc;
  const _CopyText({required this.text, required this.mc});

  @override
  State<_CopyText> createState() => _CopyTextState();
}

class _CopyTextState extends State<_CopyText> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1300),
        () { if (mounted) setState(() => _copied = false); });
  }

  @override
  Widget build(BuildContext context) {
    final mc = widget.mc;
    return GestureDetector(
      onTap: _copy,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mc.card,
          border:
              Border.all(color: _copied ? mc.green : mc.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            _copied ? 'Imenakiliwa ✓' : widget.text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _copied ? mc.green : mc.ink,
              fontFamily: 'monospace',
            ),
          ),
          if (!_copied) ...[
            const SizedBox(width: 8),
            Icon(Icons.copy_outlined, size: 14, color: mc.inkSoft),
          ],
        ]),
      ),
    );
  }
}

// ─── Steps ────────────────────────────────────────────────────────────────────

class _Steps extends StatelessWidget {
  final PaymentStatus status;
  final DateTime? createdAt;
  final _MC mc;
  const _Steps(
      {required this.status,
      required this.createdAt,
      required this.mc});

  @override
  Widget build(BuildContext context) {
    final pending = status == PaymentStatus.pending;
    final approved = status == PaymentStatus.approved;
    final rejected = status == PaymentStatus.rejected;

    final step2Color =
        pending ? mc.amber : mc.blue;
    final step2Icon =
        pending ? Icons.access_time_rounded : Icons.check_rounded;
    final step2Label = pending ? 'Inakaguliwa' : 'Imekaguliwa';
    final step2Sub = pending
        ? 'Inasubiri uthibitisho wako'
        : 'Admin ameangalia SMS';
    final step2LabelColor = pending ? mc.amber : mc.ink;

    final line1Color = pending ? mc.amber : mc.blue;

    final step3Color = approved
        ? mc.green
        : (rejected ? mc.red : mc.inkFaint);
    final step3Icon = approved
        ? Icons.check_rounded
        : (rejected ? Icons.close_rounded : null);
    final step3Label = approved
        ? 'Imekamilika'
        : (rejected ? 'Imekataliwa' : 'Matokeo');
    final step3Sub = approved
        ? 'Malipo yamethibitishwa'
        : (rejected ? 'Malipo hayakukubaliwa' : 'Bado');
    final step3LabelColor = approved
        ? mc.green
        : (rejected ? mc.red : mc.inkSoft);
    final line2Color = approved
        ? mc.green
        : (rejected ? mc.red : mc.inkFaint);

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepRow(
            color: mc.blue,
            icon: Icons.check_rounded,
            label: 'Imetumwa',
            labelColor: mc.ink,
            sub: _fmtDate(createdAt),
            mc: mc,
          ),
          _StepLine(color: line1Color),
          _StepRow(
            color: step2Color,
            icon: step2Icon,
            label: step2Label,
            labelColor: step2LabelColor,
            sub: step2Sub,
            mc: mc,
            hollow: pending,
          ),
          _StepLine(color: line2Color),
          _StepRow(
            color: step3Color,
            icon: step3Icon,
            label: step3Label,
            labelColor: step3LabelColor,
            sub: step3Sub,
            mc: mc,
            hollow: pending,
          ),
        ]);
  }
}

class _StepRow extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final String label;
  final Color labelColor;
  final String sub;
  final _MC mc;
  final bool hollow;
  const _StepRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.sub,
    required this.mc,
    this.hollow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hollow ? Colors.transparent : color,
          border: hollow
              ? Border.all(color: color, width: 1.5)
              : null,
        ),
        child: (icon != null && !hollow)
            ? Icon(icon, size: 13, color: Colors.white)
            : null,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: labelColor)),
              if (sub.isNotEmpty)
                Text(sub,
                    style: TextStyle(
                        fontSize: 12, color: mc.inkSoft)),
            ]),
      ),
    ]);
  }
}

class _StepLine extends StatelessWidget {
  final Color color;
  const _StepLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Container(width: 2, height: 26, color: color),
    );
  }
}

// ─── ChipBtn ──────────────────────────────────────────────────────────────────

class _ChipBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool filled;
  final _MC mc;
  final VoidCallback? onTap;
  const _ChipBtn({
    required this.icon,
    required this.label,
    this.count = 0,
    this.filled = false,
    required this.mc,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? mc.blueBg : mc.card;
    final fg = filled ? mc.blue : mc.inkSoft;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  filled ? mc.blue.withValues(alpha: 0.3) : mc.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  color: mc.blue, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$count',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─── SquareBtn ────────────────────────────────────────────────────────────────

class _SquareBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool fill;
  final _MC mc;
  final VoidCallback? onTap;
  const _SquareBtn({
    required this.icon,
    required this.color,
    required this.fill,
    required this.mc,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: fill ? color : mc.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: fill ? color : color.withValues(alpha: 0.4),
              width: 1.4),
        ),
        child: Icon(icon,
            size: 18, color: fill ? Colors.white : color),
      ),
    );
  }
}

// ─── Detail Sheet ─────────────────────────────────────────────────────────────

class _DetailSheet extends StatefulWidget {
  final Payment payment;
  final int startTab;
  final List<String> quickReplies;
  final Future<PaymentMessage?> Function(String text)? onSendMessage;

  const _DetailSheet({
    required this.payment,
    this.startTab = 0,
    required this.quickReplies,
    this.onSendMessage,
  });

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late int _tab;
  late List<PaymentMessage> _msgs;
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.startTab;
    _msgs = List.of(widget.payment.messages);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _sending) return;
    final now = DateTime.now();
    setState(() {
      _msgs.add(PaymentMessage(fromAdmin: true, text: t, at: now));
      _msgCtrl.clear();
      _sending = true;
    });
    try {
      await widget.onSendMessage?.call(t);
    } catch (_) {
      if (!mounted) return;
      setState(() => _msgs.removeLast());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mc = _MC(Theme.of(context).brightness == Brightness.dark);
    final p = widget.payment;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: mc.card,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: mc.border,
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 14),
            // Sheet header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _StatusAvatar(
                    name: p.name, status: p.status, mc: mc),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: mc.ink)),
                        Row(children: [
                          Icon(Icons.phone_outlined,
                              size: 12, color: mc.inkSoft),
                          const SizedBox(width: 4),
                          Text(p.phone,
                              style: TextStyle(
                                  fontSize: 12, color: mc.inkSoft)),
                        ]),
                      ]),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: p.status, mc: mc),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: mc.panel,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: mc.inkSoft),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                    child: _TabBtn(
                  icon: Icons.receipt_long_outlined,
                  label: 'Maelezo',
                  active: _tab == 0,
                  mc: mc,
                  onTap: () => setState(() => _tab = 0),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: _TabBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Mazungumzo',
                  badge: _msgs.length,
                  active: _tab == 1,
                  mc: mc,
                  onTap: () => setState(() => _tab = 1),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: _tab == 0
                  ? _buildMaelezo(mc, p)
                  : _buildMazungumzo(mc, p),
            ),
            if (_tab == 1) ...[
              if (widget.quickReplies.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.quickReplies.length,
                    separatorBuilder: (context2, idx) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context2, i) {
                      final q = widget.quickReplies[i];
                      return GestureDetector(
                        onTap: () => _send(q),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: mc.border),
                            borderRadius: BorderRadius.circular(20),
                            color: mc.card,
                          ),
                          child: Center(
                              child: Text(q,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: mc.inkSoft))),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: mc.panel,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        minLines: 1,
                        maxLines: 4,
                        style:
                            TextStyle(fontSize: 13, color: mc.ink),
                        decoration: InputDecoration(
                          hintText: 'Andika jibu kwa mchangiaji',
                          hintStyle: TextStyle(
                              fontSize: 13, color: mc.inkFaint),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_msgCtrl.text),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: mc.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ],
            SizedBox(
                height: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom
                    : 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMaelezo(_MC mc, Payment p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KIASI',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: mc.inkFaint,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text('TZS ${_fmtAmount(p.amount)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: mc.ink,
                            decoration:
                                p.status == PaymentStatus.rejected
                                    ? TextDecoration.lineThrough
                                    : null,
                            decorationColor: mc.red,
                          )),
                    ]),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('KODI',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: mc.inkFaint,
                            letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    _CopyText(text: p.reference, mc: mc),
                  ]),
            ]),
            const SizedBox(height: 14),
            _Cut(mc: mc),
            const SizedBox(height: 12),
            if (p.createdAt != null)
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: mc.inkSoft),
                const SizedBox(width: 8),
                Text(_fmtDate(p.createdAt),
                    style:
                        TextStyle(fontSize: 13, color: mc.inkSoft)),
              ]),
            if (p.sms.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('SMS YA MCHANGIAJI',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: mc.inkFaint,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Expanded(
                  child: SelectableText(p.sms,
                      style: TextStyle(
                          fontSize: 13,
                          color: mc.inkSoft,
                          height: 1.5)),
                ),
                const SizedBox(width: 8),
                _CopyIconBtn(text: p.sms, mc: mc),
              ]),
            ],
            if (p.status == PaymentStatus.rejected &&
                p.note.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: mc.redBg,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: mc.red),
                        const SizedBox(width: 6),
                        Text('SABABU YA KUKATAA',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: mc.red,
                                letterSpacing: 0.6)),
                      ]),
                      const SizedBox(height: 4),
                      Text(p.note,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: mc.red)),
                    ]),
              ),
            ],
          ]),
    );
  }

  Widget _buildMazungumzo(_MC mc, Payment p) {
    if (_msgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: mc.blueBg, shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 22, color: mc.blue),
          ),
          const SizedBox(height: 12),
          Text('Hakuna ujumbe bado',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: mc.ink)),
          const SizedBox(height: 4),
          Text('Andika ujumbe wa kwanza kwa mchangiaji.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: mc.inkSoft)),
          const SizedBox(height: 16),
        ]),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: _msgs.length,
      itemBuilder: (context2, i) {
        final m = _msgs[i];
        final isMe = m.fromAdmin;
        return Align(
          alignment:
              isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                constraints:
                    const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: isMe ? mc.blue : mc.panel,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft:
                        Radius.circular(isMe ? 14 : 3),
                    bottomRight:
                        Radius.circular(isMe ? 3 : 14),
                  ),
                ),
                child: Text(m.text,
                    style: TextStyle(
                        fontSize: 14,
                        color:
                            isMe ? Colors.white : mc.ink)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${isMe ? 'Wewe' : p.name.split(' ').first} · ${_fmtTime(m.at)}',
                  style: TextStyle(
                      fontSize: 10.5, color: mc.inkFaint),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab button ───────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final bool active;
  final _MC mc;
  final VoidCallback onTap;
  const _TabBtn({
    required this.icon,
    required this.label,
    this.badge = 0,
    required this.active,
    required this.mc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? mc.panel : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: mc.border),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? mc.ink : mc.inkSoft),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? mc.ink : mc.inkSoft)),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      color: mc.blue, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('$badge',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ]),
      ),
    );
  }
}

// ─── Copy icon button ─────────────────────────────────────────────────────────

class _CopyIconBtn extends StatefulWidget {
  final String text;
  final _MC mc;
  const _CopyIconBtn({required this.text, required this.mc});

  @override
  State<_CopyIconBtn> createState() => _CopyIconBtnState();
}

class _CopyIconBtnState extends State<_CopyIconBtn> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1300),
        () { if (mounted) setState(() => _copied = false); });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _copy,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: widget.mc.panel,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(
            _copied
                ? Icons.check_rounded
                : Icons.copy_outlined,
            size: 16,
            color:
                _copied ? widget.mc.green : widget.mc.inkSoft),
      ),
    );
  }
}

// ─── Reject Sheet ─────────────────────────────────────────────────────────────

class _RejectSheet extends StatefulWidget {
  final List<String> reasons;
  final _MC mc;
  const _RejectSheet({required this.reasons, required this.mc});

  static Future<String?> show(
      BuildContext ctx, List<String> reasons, _MC mc) {
    return showModalBottomSheet<String>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _RejectSheet(reasons: reasons, mc: mc),
    );
  }

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.reasons.first;
  }

  @override
  Widget build(BuildContext context) {
    final mc = widget.mc;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      decoration: BoxDecoration(
        color: mc.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: mc.border,
                    borderRadius: BorderRadius.circular(999)))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: mc.redBg,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.warning_amber_rounded,
                  size: 16, color: mc.red),
            ),
            const SizedBox(width: 10),
            Text('Kataa malipo?',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: mc.ink)),
          ]),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Chagua sababu ya kukataa.',
              style: TextStyle(fontSize: 12, color: mc.inkSoft)),
        ),
        const SizedBox(height: 14),
        for (final r in widget.reasons)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: GestureDetector(
              onTap: () => setState(() => _selected = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _selected == r ? mc.blueBg : mc.card,
                  border: Border.all(
                      color: _selected == r
                          ? mc.blue
                          : mc.border,
                      width: _selected == r ? 1.3 : 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selected == r
                          ? mc.blue
                          : Colors.transparent,
                      border: Border.all(
                          color: _selected == r
                              ? mc.blue
                              : mc.border,
                          width: 1.2),
                    ),
                    child: _selected == r
                        ? const Icon(Icons.check,
                            size: 9, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(r,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: _selected == r
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: mc.ink)),
                ]),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: TextButton.styleFrom(
                      foregroundColor: mc.inkSoft),
                  child: const Text('Ghairi',
                      style: TextStyle(
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_selected),
                  style: FilledButton.styleFrom(
                      backgroundColor: mc.red,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10))),
                  icon: const Icon(Icons.close,
                      size: 14, color: Colors.white),
                  label: const Text('Kataa',
                      style: TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ]),
        ),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _MC mc;
  const _EmptyState({required this.mc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.payments_outlined, size: 40, color: mc.inkFaint),
        const SizedBox(height: 12),
        Text('Hakuna malipo kwa sasa',
            style: TextStyle(color: mc.inkSoft, fontSize: 14.5)),
      ]),
    );
  }
}

// ─── Pagination ───────────────────────────────────────────────────────────────

class _Pager extends StatelessWidget {
  final int page, total;
  final _MC mc;
  final ValueChanged<int> onTap;
  const _Pager(
      {required this.page,
      required this.total,
      required this.mc,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final start =
        (page - 2).clamp(0, (total - 5).clamp(0, 1 << 30));
    final end = (start + 5).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              onPressed: page > 0 ? () => onTap(page - 1) : null,
              icon: Icon(Icons.chevron_left, color: mc.inkSoft),
            ),
            for (var i = start; i < end; i++)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == page ? mc.blue : mc.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              i == page ? mc.blue : mc.border),
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: i == page
                              ? Colors.white
                              : mc.ink,
                        )),
                  ),
                ),
              ),
            IconButton.outlined(
              onPressed: page < total - 1
                  ? () => onTap(page + 1)
                  : null,
              icon: Icon(Icons.chevron_right, color: mc.inkSoft),
            ),
          ]),
    );
  }
}
