// =============================================================================
// malipo_view.dart — standalone "Malipo" view widget
// admin_payments_page.dart inapakia data na kuipitisha hapa.
//
// MUUNDO (SPEC):
// 1. Kichwa: kisanduku cha bluu (wallet) + "Malipo" + "{n} malipo · {k} yanasubiri"
//    + kidonge cha "Live".
// 2. Vichujio vya hali: Yote | Inasubiri | Imekamilika | Imekataliwa (+ idadi).
// 3. Kutafuta "Tafuta kwa jina, namba au kodi" + "Inaonyesha x kati ya y".
// 4. Kadi ya malipo (wima): avatar ya initials + beji ndogo ya hali, jina,
//    simu (phoneCall → tel:), beji ya hali; mstari wa vitone (notch za risiti);
//    KIASI (TZS + namba kubwa; imekataliwa → lineThrough); KODI (mono + nakili);
//    hatua 3 za wima (Imetumwa/Inakaguliwa/Imekamilika au Imekataliwa);
//    kitufe cha "Ona" (eye) — kubonyeza kunaonyesha SMS ya mchangiaji INLINE
//    kwenye kadi (bonyeza tena kinafunga); kwa pending TU: vitufe vidogo 30x30
//    vya Kataa (X nyekundu) na Thibitisha (tiki kijani) — vina Tooltip.
//    HAKUNA button ya "Ongea" (mazungumzo yameondolewa kwa design hii).
// 5. KUKATAA: bottom sheet "Kataa malipo" — chips za sababu + sababu yako.
//    THIBITISHA hufanya kazi mara moja bila dialog.
// 6. Kurasa: vitufe vya duara (dirisha la 5) na mishale. Hali tupu:
//    "Hakuna malipo" / "Jaribu kichujio kingine".
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Color get borderStrong => _d ? const Color(0xFF465164) : const Color(0xFFC3CAD6);
  Color get panel    => _d ? const Color(0xFF1C2128) : const Color(0xFFF1F3F7);
  Color get soft     => panel;

  Color get blue    => const Color(0xFF1E66E0);
  Color get blueBg  => _d ? const Color(0xFF1C2A44) : const Color(0xFFE8F0FD);

  Color get green    => const Color(0xFF0F7A52);
  Color get greenBg  => _d ? const Color(0xFF15302A) : const Color(0xFFE3F5EC);
  Color get greenFill => const Color(0xFF16A34A);

  Color get amber    => const Color(0xFF9A5B00);
  Color get amberBg  => _d ? const Color(0xFF3A2C14) : const Color(0xFFFFF1D6);
  Color get amberFill => const Color(0xFFF59E0B);

  Color get red    => const Color(0xFFC62828);
  Color get redBg  => _d ? const Color(0xFF3A1D1F) : const Color(0xFFFDECEC);
  Color get redFill => const Color(0xFFDC2626);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts[0][0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

String _titleName(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

String _money(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

const _months = [
  'Jan','Feb','Mac','Apr','Mei','Jun',
  'Jul','Ago','Sep','Okt','Nov','Des'
];

String _two(int v) => v.toString().padLeft(2, '0');

/// 29 Sep 2026 · 07:34
String _fullDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]} ${d.year} · ${_two(d.hour)}:${_two(d.minute)}';
}

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

String _local9(String p) {
  var d = _digits(p);
  if (d.startsWith('255') && d.length > 9) d = d.substring(3);
  if (d.startsWith('0') && d.length > 9) d = d.substring(1);
  return d;
}

String _intl(String p) => '255${_local9(p)}';

String _prettyPhone(String p) {
  final l = _local9(p);
  if (l.length != 9) return p;
  return '+255 ${l.substring(0, 3)} ${l.substring(3, 6)} ${l.substring(6)}';
}

// ═══ KADI YA MALIPO (wima) ════════════════════════════════════════════════

class _PaymentCard extends StatefulWidget {
  final _MC c;
  final Payment p;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentCard({
    required this.c,
    required this.p,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool smsOpen = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final p = widget.p;
    final st = _st(c, p.status);
    final pending = p.status == PaymentStatus.pending;
    final rejected = p.status == PaymentStatus.rejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // a. juu: avatar + jina + simu + beji ya hali
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              _StatusAvatar(
                  c: c, name: p.name, size: 44, fill: st.fill, icon: st.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_titleName(p.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: () => launchUrl(
                            Uri(scheme: 'tel', path: '+${_intl(p.phone)}')),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(TablerIcons.phoneCall, size: 14, color: c.inkSoft),
                          const SizedBox(width: 5),
                          Text(_prettyPhone(p.phone),
                              style:
                                  TextStyle(color: c.inkSoft, fontSize: 12)),
                        ]),
                      ),
                    ]),
              ),
              const SizedBox(width: 8),
              _Pill(label: st.label, fg: st.fg, bg: st.bg),
            ]),
          ),

          // b. mstari wa vitone (notch za risiti)
          _Cut(c: c),

          // c. kiasi + kodi, d. hatua
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _AmountBox(c: c, p: p, struck: rejected, big: 28),
              const SizedBox(height: 14),
              _Steps(c: c, p: p),
            ]),
          ),

          // SMS inline (bonyeza "Ona" kufungua/kufunga)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: smsOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _SmsBox(c: c, p: p),
            ),
          ),

          // e. vitufe: "Ona" (+ Kataa/Thibitisha kwa pending TU)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(children: [
              _ChipBtn(
                  c: c,
                  icon: smsOpen ? TablerIcons.eyeOff : TablerIcons.eye,
                  label: 'Ona',
                  onTap: () => setState(() => smsOpen = !smsOpen)),
              const Spacer(),
              if (pending) ...[
                _SquareBtn(
                    c: c,
                    icon: TablerIcons.x,
                    kind: _SqKind.reject,
                    tooltip: 'Kataa',
                    onTap: widget.onReject),
                const SizedBox(width: 8),
                _SquareBtn(
                    c: c,
                    icon: TablerIcons.check,
                    kind: _SqKind.approve,
                    tooltip: 'Thibitisha',
                    onTap: widget.onApprove),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── SMS ya mchangiaji (inline) ───────────────────────────────────────────

class _SmsBox extends StatelessWidget {
  final _MC c;
  final Payment p;
  const _SmsBox({required this.c, required this.p});

  @override
  Widget build(BuildContext context) {
    final hasSms = p.sms.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(TablerIcons.message2, size: 15, color: c.inkSoft),
          const SizedBox(width: 6),
          Text('SMS YA MCHANGIAJI',
              style: TextStyle(
                  color: c.inkSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .9)),
        ]),
        const SizedBox(height: 6),
        SelectableText(
          hasSms ? p.sms : 'Hakuna SMS',
          style: TextStyle(
              color: hasSms ? c.ink : c.inkSoft, fontSize: 14, height: 1.5),
        ),
      ]),
    );
  }
}

// ─── Kisanduku cha kiasi + kodi ───────────────────────────────────────────

class _AmountBox extends StatelessWidget {
  final _MC c;
  final Payment p;
  final bool struck;
  final double big;
  const _AmountBox(
      {required this.c, required this.p, required this.struck, required this.big});

  @override
  Widget build(BuildContext context) {
    final amountColor = struck ? c.inkSoft : c.ink;
    final deco = struck ? TextDecoration.lineThrough : TextDecoration.none;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          BoxDecoration(color: c.panel, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('KIASI', style: _label(c)),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(
            text: 'TZS ',
            style: TextStyle(
                color: c.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: deco),
          ),
          TextSpan(
            text: _money(p.amount),
            style: TextStyle(
              color: amountColor,
              fontSize: big,
              fontWeight: FontWeight.w600,
              letterSpacing: -.5,
              height: 1,
              decoration: deco,
              decorationThickness: 2,
            ),
          ),
        ])),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: c.borderStrong.withValues(alpha: .7)))),
          child: Row(children: [
            Text('KODI', style: _label(c)),
            const Spacer(),
            _CopyText(c: c, text: p.reference),
          ]),
        ),
      ]),
    );
  }
}

/// Kodi yenye kunakili
class _CopyText extends StatefulWidget {
  final _MC c;
  final String text;
  const _CopyText({required this.c, required this.text});

  @override
  State<_CopyText> createState() => _CopyTextState();
}

class _CopyTextState extends State<_CopyText> {
  bool done = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => done = true);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (mounted) setState(() => done = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(done ? 'Imenakiliwa ✓' : widget.text,
            style: TextStyle(
                color: done ? c.green : c.ink,
                fontSize: 13,
                fontFamily: done ? null : 'monospace',
                fontFamilyFallback: const ['RobotoMono', 'Courier'])),
        const SizedBox(width: 6),
        Icon(done ? TablerIcons.check : TablerIcons.copy,
            size: 14, color: done ? c.green : c.inkSoft),
      ]),
    );
  }
}

// ═══ DIRISHA LA KUKATAA ═══════════════════════════════════════════════════

class _RejectSheet extends StatefulWidget {
  final _MC c;
  final Payment p;
  final List<String> reasons;
  const _RejectSheet(
      {required this.c, required this.p, required this.reasons});

  static Future<String?> show(
      BuildContext ctx, _MC c, Payment p, List<String> reasons) {
    return showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _RejectSheet(c: c, p: p, reasons: reasons),
    );
  }

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  String? picked;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_ctrl.text.isNotEmpty && picked != null) picked = null;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _reason => (picked ?? _ctrl.text).trim();

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final mq = MediaQuery.of(context);
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: col, width: w));

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + mq.padding.bottom),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: c.redBg,
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(TablerIcons.x, size: 19, color: c.red),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kataa malipo',
                        style: TextStyle(
                            color: c.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    Text(
                        '${_titleName(widget.p.name)} · TZS ${_money(widget.p.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.inkSoft, fontSize: 12)),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          Text('CHAGUA SABABU', style: _label(c)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in widget.reasons)
              GestureDetector(
                onTap: () => setState(() {
                  picked = picked == r ? null : r;
                  if (picked != null) _ctrl.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: picked == r ? c.redBg : c.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: picked == r ? c.red : c.borderStrong),
                  ),
                  child: Text(r,
                      style: TextStyle(
                          color: picked == r ? c.red : c.ink, fontSize: 13)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            style: TextStyle(color: c.ink, fontSize: 14),
            cursorColor: c.blue,
            decoration: InputDecoration(
              hintText: 'Au andika sababu nyingine…',
              hintStyle: TextStyle(
                  color: c.inkSoft.withValues(alpha: .8), fontSize: 14),
              isDense: true,
              filled: true,
              fillColor: c.card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: b(c.borderStrong),
              enabledBorder: b(c.borderStrong),
              focusedBorder: b(c.blue, 1.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: SizedBox(height: 38, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: c.ink, side: BorderSide(color: c.borderStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 13)), child: const Text('Ghairi')))), const SizedBox(width: 8), Expanded(child: SizedBox(height: 38, child: FilledButton(onPressed: _reason.isEmpty ? null : () => Navigator.pop(context, _reason), style: FilledButton.styleFrom(backgroundColor: c.redFill, foregroundColor: Colors.white, disabledBackgroundColor: c.redFill.withValues(alpha: .35), disabledForegroundColor: Colors.white70, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), child: const Text('Kataa'))))]),
        ]),
      ),
    );
  }
}


// ═══ MalipoView ══════════════════════════════════════════════════════════════

const _kPageSize = 10;

class MalipoView extends StatefulWidget {
  final List<Payment> payments;

  /// Jumla halisi ya TZS zilizothibitishwa (kutoka API: total_approved_tzs).
  /// Kama haipati, inahesabiwa kutoka kwenye orodha.
  final int? totalApprovedTzs;
  final Future<void> Function(Payment p)? onApprove;
  final Future<void> Function(Payment p, String reason)? onReject;
  final List<String> rejectReasons;

  const MalipoView({
    super.key,
    required this.payments,
    this.totalApprovedTzs,
    this.onApprove,
    this.onReject,
    this.rejectReasons = const [
      'Kiasi hakilingani',
      'Pesa haijaingia',
      'SMS si sahihi',
      'Namba haifanani',
    ],
  });

  @override
  State<MalipoView> createState() => _MalipoViewState();
}

class _MalipoViewState extends State<MalipoView> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  PaymentStatus? _filter; // null = yote
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

  int _count(PaymentStatus s) =>
      widget.payments.where((p) => p.status == s).length;

  int _sumTzs(PaymentStatus s) => widget.payments
      .where((p) => p.status == s)
      .fold<int>(0, (sum, p) => sum + p.amount);

  int get _approvedTzs =>
      widget.totalApprovedTzs ?? _sumTzs(PaymentStatus.approved);

  List<Payment> get _filtered {
    final q = _search.text.toLowerCase().trim();
    return widget.payments.where((p) {
      if (_filter != null && p.status != _filter) return false;
      if (q.isEmpty) return true;
      final hay =
          '${p.name} ${p.phone} ${_digits(p.phone)} ${p.reference}'.toLowerCase();
      return hay.contains(q) ||
          (q.startsWith('0') && q.length > 1 && hay.contains(q.substring(1)));
    }).toList();
  }

  int get _totalPages =>
      (_filtered.length / _kPageSize).ceil().clamp(1, 1 << 30);
  int get _safePage => _page.clamp(0, _totalPages - 1);

  void _goPage(int p) {
    setState(() => _page = p.clamp(0, _totalPages - 1));
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _approve(Payment p) async => widget.onApprove?.call(p);

  Future<void> _reject(Payment p) async {
    final c = _MC(Theme.of(context).brightness == Brightness.dark);
    final reason =
        await _RejectSheet.show(context, c, p, widget.rejectReasons);
    if (reason == null || reason.trim().isEmpty) return;
    await widget.onReject?.call(p, reason.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = _MC(Theme.of(context).brightness == Brightness.dark);
    final filtered = _filtered;
    final pg = _safePage;
    final slice =
        filtered.skip(pg * _kPageSize).take(_kPageSize).toList();

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _header(c),
        const SizedBox(height: 10),
        _stats(c),
        const SizedBox(height: 12),
        _chips(c),
        const SizedBox(height: 10),
        _searchField(c),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
          child: Text('Inaonyesha ${slice.length} kati ya ${filtered.length}',
              style: TextStyle(color: c.inkSoft, fontSize: 12)),
        ),
        if (slice.isEmpty)
          _empty(c)
        else ...[
          for (final p in slice)
            _PaymentCard(
              c: c,
              p: p,
              onApprove: () => _approve(p),
              onReject: () => _reject(p),
            ),
          if (_totalPages > 1)
            _Pager(page: pg, total: _totalPages, c: c, onTap: _goPage),
        ],
      ],
    );
  }

  /* ---------- Takwimu za pesa ---------- */

  Widget _stats(_MC c) {
    final total = widget.payments.length;
    final approved = _count(PaymentStatus.approved);
    final pending = _count(PaymentStatus.pending);
    final rejected = _count(PaymentStatus.rejected);
    final approvedTzs = _approvedTzs;
    final pendingTzs = _sumTzs(PaymentStatus.pending);

    Widget statTile({
      required IconData icon,
      required Color fg,
      required Color bg,
      required String value,
      required String label,
    }) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                  child: Icon(icon, size: 14, color: fg),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: TextStyle(
                          color: fg,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.3)),
                ),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.inkSoft, fontSize: 11)),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Kichwa cha takwimu
        Row(children: [
          Icon(TablerIcons.chartBar, size: 16, color: c.inkSoft),
          const SizedBox(width: 6),
          Text('Muhtasari wa Miamala',
              style: TextStyle(
                  color: c.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: c.panel, borderRadius: BorderRadius.circular(999)),
            child: Text('$total jumla',
                style: TextStyle(
                    color: c.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),

        // Kiasi kikubwa - Zimekamilika
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.greenBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: c.card,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.green.withValues(alpha: .12), blurRadius: 8)]),
              child: Icon(TablerIcons.circleCheck, size: 18, color: c.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Zimekamilika',
                    style: TextStyle(color: c.green, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('TZS ${_money(approvedTzs)}',
                      style: TextStyle(
                          color: c.green,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.5)),
                ),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$approved',
                  style: TextStyle(
                      color: c.green,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1)),
              Text('malipo',
                  style: TextStyle(color: c.green.withValues(alpha: .7), fontSize: 11)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),

        // Vipande vidogo — Zinasubiri + Zimekataliwa
        Row(children: [
          statTile(
            icon: TablerIcons.clock,
            fg: c.amber,
            bg: c.amberBg,
            value: 'TZS ${_money(pendingTzs)}',
            label: '$pending zinasubiri',
          ),
          const SizedBox(width: 8),
          statTile(
            icon: TablerIcons.x,
            fg: c.red,
            bg: c.redBg,
            value: '$rejected',
            label: 'Zimekataliwa',
          ),
        ]),
      ]),
    );
  }

  /* ---------- Kichwa ---------- */

  Widget _header(_MC c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.blueBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: c.card, borderRadius: BorderRadius.circular(12)),
            child: Icon(TablerIcons.wallet, size: 21, color: c.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Malipo',
                  style: TextStyle(
                      color: c.ink, fontSize: 17, fontWeight: FontWeight.w600)),
              Text(
                  '${widget.payments.length} malipo · ${_count(PaymentStatus.pending)} yanasubiri',
                  style: TextStyle(color: c.inkSoft, fontSize: 12)),
            ]),
          ),
          _Pill(
              label: 'Live',
              icon: TablerIcons.sparkles,
              fg: c.green,
              bg: c.greenBg,
              size: 12,
              vpad: 4,
              hpad: 10),
        ]),
      );

  /* ---------- Vichujio ---------- */

  Widget _chips(_MC c) {
    final opts = <(PaymentStatus?, String, int)>[
      (null, 'Yote', widget.payments.length),
      (PaymentStatus.pending, 'Inasubiri', _count(PaymentStatus.pending)),
      (PaymentStatus.approved, 'Imekamilika', _count(PaymentStatus.approved)),
      (PaymentStatus.rejected, 'Imekataliwa', _count(PaymentStatus.rejected)),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (s, t, n) = opts[i];
          final on = s == _filter;
          return GestureDetector(
            onTap: () => setState(() {
              _filter = s;
              _page = 0;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: on ? c.blue : c.card,
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: on ? c.blue : c.borderStrong),
              ),
              child: Row(children: [
                Text(t,
                    style: TextStyle(
                        color: on ? Colors.white : c.ink, fontSize: 13)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: on ? Colors.white24 : c.panel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$n',
                      style: TextStyle(
                          color: on ? Colors.white : c.inkSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  /* ---------- Kutafuta ---------- */

  Widget _searchField(_MC c) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: _search,
      style: TextStyle(color: c.ink, fontSize: 14),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: 'Tafuta kwa jina, namba au kodi',
        hintStyle: TextStyle(
            color: c.inkSoft.withValues(alpha: .8), fontSize: 14),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        prefixIcon: Icon(TablerIcons.search, size: 17, color: c.inkSoft),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }

  /* ---------- Hali tupu ---------- */

  Widget _empty(_MC c) => Container(
        padding:
            const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(color: c.blueBg, shape: BoxShape.circle),
            child: Icon(TablerIcons.receiptOff, size: 26, color: c.blue),
          ),
          const SizedBox(height: 10),
          Text('Hakuna malipo',
              style: TextStyle(
                  color: c.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Jaribu kichujio kingine',
              style: TextStyle(color: c.inkSoft, fontSize: 12)),
        ]),
      );
}

// ─── Hatua za malipo (wima) ───────────────────────────────────────────────

enum _StepState { done, active, todo }

class _StepData {
  final String title;
  final String sub;
  final _StepState state;
  final Color fill;
  final Color text;
  final IconData icon;
  const _StepData(
      this.title, this.sub, this.state, this.fill, this.text, this.icon);
}

class _Steps extends StatelessWidget {
  final _MC c;
  final Payment p;
  const _Steps({required this.c, required this.p});

  @override
  Widget build(BuildContext context) {
    final s = p.status;
    final first = _StepData('Imetumwa', _fullDate(p.createdAt),
        _StepState.done, c.blue, c.ink, TablerIcons.check);
    final mid = s == PaymentStatus.pending
        ? _StepData('Inakaguliwa', 'Inasubiri uthibitisho wako',
            _StepState.active, c.amberFill, c.amber, TablerIcons.clock)
        : _StepData('Imekaguliwa', 'Admin ameangalia SMS', _StepState.done,
            c.blue, c.ink, TablerIcons.check);
    final fin = switch (s) {
      PaymentStatus.approved => _StepData('Imekamilika',
          'Malipo yamethibitishwa', _StepState.done, c.greenFill, c.green,
          TablerIcons.check),
      PaymentStatus.rejected => _StepData('Imekataliwa',
          'Malipo hayakukubaliwa', _StepState.done, c.redFill, c.red,
          TablerIcons.x),
      PaymentStatus.pending => _StepData('Matokeo', 'Bado', _StepState.todo,
          c.borderStrong, c.inkSoft, TablerIcons.check),
    };
    final list = [first, mid, fin];

    return Column(children: [
      for (var i = 0; i < list.length; i++)
        _StepRow(
          c: c,
          step: list[i],
          last: i == list.length - 1,
          lineColor: i == list.length - 1
              ? null
              : (list[i + 1].state == _StepState.todo
                  ? c.borderStrong
                  : list[i + 1].fill),
        ),
    ]);
  }
}

class _StepRow extends StatelessWidget {
  final _MC c;
  final _StepData step;
  final bool last;
  final Color? lineColor;
  const _StepRow(
      {required this.c, required this.step, required this.last, this.lineColor});

  @override
  Widget build(BuildContext context) {
    final Widget dot = switch (step.state) {
      _StepState.todo => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.card,
            border: Border.all(color: c.borderStrong, width: 2),
          ),
        ),
      _StepState.active =>
        _PulseDot(color: step.fill, halo: c.amberBg, icon: step.icon),
      _StepState.done => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: step.fill, shape: BoxShape.circle),
          child: Icon(step.icon, size: 10, color: Colors.white),
        ),
    };

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 16,
          child: Column(children: [
            dot,
            if (!last)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.title,
                  style: TextStyle(
                      color: step.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2)),
              const SizedBox(height: 1),
              Text(step.sub,
                  style: TextStyle(color: c.inkSoft, fontSize: 11.5)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Duara linalopepesa (hatua inayoendelea — "Inakaguliwa")
class _PulseDot extends StatefulWidget {
  final Color color;
  final Color halo;
  final IconData icon;
  const _PulseDot(
      {required this.color, required this.halo, required this.icon});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.halo.withValues(alpha: (1 - _ctrl.value) * .9),
                spreadRadius: _ctrl.value * 6,
              ),
            ],
          ),
          child: Icon(widget.icon, size: 10, color: Colors.white),
        ),
      );
}

// ─── VIPANDE VIDOGO ───────────────────────────────────────────────────────

class _StatusAvatar extends StatelessWidget {
  final _MC c;
  final String name;
  final double size;
  final Color fill;
  final IconData icon;
  const _StatusAvatar(
      {required this.c,
      required this.name,
      required this.size,
      required this.fill,
      required this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: c.blueBg, shape: BoxShape.circle),
            child: Text(_initials(name),
                style: TextStyle(
                    color: c.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: c.card, width: 2),
              ),
              child: Icon(icon, size: 11, color: Colors.white),
            ),
          ),
        ]),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;
  final double size, vpad, hpad;
  const _Pill(
      {required this.label,
      required this.fg,
      required this.bg,
      this.icon,
      this.size = 11,
      this.vpad = 3,
      this.hpad = 9});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: hpad, vertical: vpad),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: size, color: fg),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: size, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// "Ona": kidonge kidogo chenye icon na neno (urefu 30)
class _ChipBtn extends StatelessWidget {
  final _MC c;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ChipBtn(
      {required this.c,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: c.panel,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.borderStrong, width: .5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: c.ink),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: c.ink, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

enum _SqKind { approve, reject }

/// Kitufe kidogo cha mraba cha icon tu (30x30): Thibitisha au Kataa
class _SquareBtn extends StatelessWidget {
  final _MC c;
  final IconData icon;
  final _SqKind kind;
  final String tooltip;
  final VoidCallback onTap;
  const _SquareBtn(
      {required this.c,
      required this.icon,
      required this.kind,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final approve = kind == _SqKind.approve;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: approve ? c.greenFill : c.card,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: approve
                  ? null
                  : Border.all(color: c.red.withValues(alpha: .55)),
            ),
            child: Icon(icon,
                size: 16, color: approve ? Colors.white : c.red),
          ),
        ),
      ),
    );
  }
}

/// Mstari wa vitone wenye mashimo pembeni (mashimo yanachukua rangi ya nyuma
/// ya ukurasa wako).
class _Cut extends StatelessWidget {
  final _MC c;
  const _Cut({required this.c});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    Widget notch() => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle));
    return SizedBox(
      height: 18,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CustomPaint(painter: _DashH(c.borderStrong)),
          ),
        ),
        Positioned(left: -10, top: 0, child: notch()),
        Positioned(right: -10, top: 0, child: notch()),
      ]),
    );
  }
}

class _DashH extends CustomPainter {
  final Color color;
  _DashH(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 5.0, gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashH old) => old.color != color;
}

TextStyle _label(_MC c) => TextStyle(
    color: c.inkSoft,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: .9);

({String label, Color fg, Color bg, Color fill, IconData icon}) _st(
        _MC c, PaymentStatus s) =>
    switch (s) {
      PaymentStatus.pending => (
          label: 'Inasubiri',
          fg: c.amber,
          bg: c.amberBg,
          fill: c.amberFill,
          icon: TablerIcons.clock
        ),
      PaymentStatus.approved => (
          label: 'Imekamilika',
          fg: c.green,
          bg: c.greenBg,
          fill: c.greenFill,
          icon: TablerIcons.check
        ),
      PaymentStatus.rejected => (
          label: 'Imekataliwa',
          fg: c.red,
          bg: c.redBg,
          fill: c.redFill,
          icon: TablerIcons.x
        ),
    };

// ═══ KURASA (PAGINATION) ═══════════════════════════════════════════════════

class _Pager extends StatelessWidget {
  final int page, total;
  final _MC c;
  final ValueChanged<int> onTap;
  const _Pager({required this.page, required this.total, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final shown = total < 5 ? total : 5;
    final start = (page - 2).clamp(0, total - shown);

    Widget circle({required Widget child, VoidCallback? onTap, bool on = false}) => Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Material(color: on ? c.blue : c.card, shape: CircleBorder(side: BorderSide(color: on ? c.blue : c.borderStrong)), child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Opacity(opacity: onTap == null && !on ? .4 : 1, child: SizedBox(width: 34, height: 34, child: Center(child: child))))));

    return Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      circle(child: Icon(TablerIcons.chevronLeft, size: 16, color: c.ink), onTap: page > 0 ? () => onTap(page - 1) : null),
      for (var i = start; i < start + shown; i++)
        circle(on: i == page, onTap: i == page ? null : () => onTap(i), child: Text('${i + 1}', style: TextStyle(color: i == page ? Colors.white : c.ink, fontSize: 13, fontWeight: i == page ? FontWeight.w600 : FontWeight.w400))),
      circle(child: Icon(TablerIcons.chevronRight, size: 16, color: c.ink), onTap: page < total - 1 ? () => onTap(page + 1) : null),
    ]));
  }
}
