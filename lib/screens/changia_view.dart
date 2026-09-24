import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/* ============================================================
   MODELS
   ============================================================ */
enum ContributionStatus { pending, approved, rejected }

class Contribution {
  final String id;
  final int amount; // mf. 2500
  final DateTime createdAt;
  final ContributionStatus status;
  final String? reason; // sababu ya kukataliwa (Kiswahili)

  const Contribution({
    required this.id,
    required this.amount,
    required this.createdAt,
    required this.status,
    this.reason,
  });
}

class ContributionDraft {
  final int amount;
  final String phone; // mf. 0757502446
  final String sms;
  const ContributionDraft({required this.amount, required this.phone, required this.sms});
}

/* ============================================================
   UKURASA WA CHANGIA
   Weka ndani ya Scaffold yako (body). Menyu ya chini inabaki yako.
   ============================================================ */
class ChangiaView extends StatefulWidget {
  final String payNumber; // mf. '0763795801'
  final int defaultAmount; // mf. 2500
  final String? userPhone; // namba ya mtumiaji, inajazwa yenyewe
  final String supportPhone;
  final String supportWhatsapp;
  final List<Contribution> history;

  /// Inaitwa ukibonyeza "Tuma". Tuma kwenye API yako.
  /// Rudisha Contribution iliyohifadhiwa (au null) ili iongezwe kwenye historia.
  final Future<Contribution?> Function(ContributionDraft draft)? onSubmit;

  final VoidCallback? onBack;
  final VoidCallback? onContactAdmin;

  const ChangiaView({
    super.key,
    required this.payNumber,
    this.defaultAmount = 2500,
    this.userPhone,
    required this.supportPhone,
    required this.supportWhatsapp,
    this.history = const [],
    this.onSubmit,
    this.onBack,
    this.onContactAdmin,
  });

  @override
  State<ChangiaView> createState() => _ChangiaViewState();
}

class _ChangiaViewState extends State<ChangiaView> {
  late final amountCtrl = TextEditingController(text: _money(widget.defaultAmount));
  late final phoneCtrl = TextEditingController(text: _local9(widget.userPhone ?? ''));
  final smsCtrl = TextEditingController();

  late List<Contribution> items = List.of(widget.history);
  ContributionStatus? filter; // null = zote
  bool copied = false;
  bool step1Done = false;
  bool step2Done = false;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    smsCtrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant ChangiaView old) {
    super.didUpdateWidget(old);
    if (old.history != widget.history) {
      items = List.of(widget.history);
      filter = null;
    }
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    phoneCtrl.dispose();
    smsCtrl.dispose();
    super.dispose();
  }

  /* ---------- Msaidizi ---------- */
  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String _local9(String p) {
    var d = _digits(p);
    if (d.startsWith('255')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length != 9) return d;
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }

  static String _groupLocal(String p) {
    final d = _digits(p);
    if (d.length == 10) return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
    if (d.length == 9) return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
    return p;
  }

  static String _prettyIntl(String p) => '+255 ${_local9(p)}';

  static String _intl(String p) => '255${_digits(_local9(p))}';

  static String _money(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'sasa hivi';
    if (diff.inMinutes < 60) {
      return 'dakika ${diff.inMinutes} ${diff.inMinutes == 1 ? 'iliyopita' : 'zilizopita'}';
    }
    if (diff.inHours < 24) {
      return 'saa ${diff.inHours} ${diff.inHours == 1 ? 'iliyopita' : 'zilizopita'}';
    }
    if (diff.inDays < 30) {
      return 'siku ${diff.inDays} ${diff.inDays == 1 ? 'iliyopita' : 'zilizopita'}';
    }
    final m = diff.inDays ~/ 30;
    return m == 1 ? 'mwezi 1 uliopita' : 'miezi $m iliyopita';
  }

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
  }

  bool get _canSend => !sending && smsCtrl.text.trim().length > 10;

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /* ---------- Vitendo ---------- */
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _digits(widget.payNumber)));
    setState(() {
      copied = true;
      step1Done = true;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => copied = false);
  }

  Future<void> _send() async {
    final amount = int.tryParse(_digits(amountCtrl.text)) ?? 0;
    final phone = _digits(_local9(phoneCtrl.text));
    if (amount <= 0) return _toast('Andika kiasi ulicholipa');
    if (phone.length != 9) return _toast('Namba iwe tarakimu 9 baada ya +255');
    if (smsCtrl.text.trim().length <= 10) return _toast('Bandika SMS nzima ya malipo');

    setState(() => sending = true);
    try {
      final saved = await widget.onSubmit?.call(ContributionDraft(
        amount: amount,
        phone: '0$phone',
        sms: smsCtrl.text.trim(),
      ));
      if (!mounted) return;
      setState(() {
        items.insert(
          0,
          saved ??
              Contribution(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                amount: amount,
                createdAt: DateTime.now(),
                status: ContributionStatus.pending,
              ),
        );
        smsCtrl.clear();
        step2Done = true;
        filter = null;
      });
      _toast('Imetumwa. Subiri uthibitisho.');
    } catch (e) {
      if (mounted) _toast('Imeshindikana kutuma: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = _PC.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _header(c),
        const SizedBox(height: 12),
        _step1(c),
        const SizedBox(height: 10),
        _step2(c),
        const SizedBox(height: 10),
        _history(c),
        const SizedBox(height: 10),
        _support(c),
      ],
    );
  }

  Widget _header(_PC c) => Row(
        children: [
          if (widget.onBack != null) ...[
            _SquareIcon(c: c, icon: TablerIcons.arrowLeft, onTap: widget.onBack!),
            const SizedBox(width: 10),
          ],
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.amberBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(TablerIcons.heartHandshake, size: 21, color: c.amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Changia huduma',
                    style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
                Text('Lipa, kisha tuma SMS ya kuthibitisha',
                    style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      );

  Widget _step1(_PC c) => _Card(
        c: c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepTitle(c: c, n: 1, done: step1Done, text: 'Lipa kwa namba hii'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('NAMBA YA MALIPO', style: _k(c)),
                      const SizedBox(height: 3),
                      Text(_groupLocal(widget.payNumber),
                          style: TextStyle(
                              color: c.blue,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5)),
                    ],
                  ),
                  _TonalBtn(
                    c: c,
                    icon: copied ? TablerIcons.check : TablerIcons.copy,
                    label: copied ? 'Imenakiliwa' : 'Nakili',
                    onTap: _copy,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _step2(_PC c) => _Card(
        c: c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepTitle(c: c, n: 2, done: step2Done, text: 'Jaza taarifa za malipo'),
            Text('KIASI', style: _label(c)),
            const SizedBox(height: 6),
            _Input(
              c: c,
              controller: amountCtrl,
              icon: TablerIcons.cash,
              prefix: 'TZS',
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            Text('NAMBA ULIYOLIPIA', style: _label(c)),
            const SizedBox(height: 6),
            _Input(
              c: c,
              controller: phoneCtrl,
              icon: TablerIcons.phone,
              prefix: '+255',
              hint: '712 345 678',
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Text('SMS YA KUTHIBITISHA', style: _label(c)),
            const SizedBox(height: 6),
            TextField(
              controller: smsCtrl,
              minLines: 3,
              maxLines: 5,
              style: TextStyle(color: c.text, fontSize: 13),
              cursorColor: c.blue,
              decoration: _dec(c).copyWith(
                hintText: 'Bandika hapa SMS uliyopokea, mf. C2H8MZ3JX1 Confirmed. '
                    'You have received TZS 2,500.00 from…',
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _canSend ? 'Tayari kutuma' : 'Bandika SMS kwanza',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ),
                Opacity(
                  opacity: _canSend || sending ? 1 : .45,
                  child: SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: _canSend ? _send : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.blue,
                        disabledBackgroundColor: c.blue,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Tuma'),
                                SizedBox(width: 6),
                                Icon(TablerIcons.send, size: 15),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _history(_PC c) {
    int count(ContributionStatus s) => items.where((i) => i.status == s).length;
    final list = items.where((i) => filter == null || i.status == filter).toList();
    final chips = <(ContributionStatus?, String, int)>[
      (null, 'Zote', items.length),
      (ContributionStatus.pending, 'Inasubiri', count(ContributionStatus.pending)),
      (ContributionStatus.approved, 'Imekamilika', count(ContributionStatus.approved)),
      (ContributionStatus.rejected, 'Imekataliwa', count(ContributionStatus.rejected)),
    ];

    return _Card(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(TablerIcons.history, size: 18, color: c.blue),
            const SizedBox(width: 8),
            Text('Historia ya malipo',
                style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final (s, t, n) = chips[i];
                final on = s == filter;
                return GestureDetector(
                  onTap: () => setState(() => filter = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: on ? c.blue : c.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? c.blue : c.borderStrong),
                    ),
                    child: Row(children: [
                      Text(t, style: TextStyle(color: on ? Colors.white : c.text, fontSize: 13)),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: on ? Colors.white24 : c.soft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$n',
                            style: TextStyle(
                                color: on ? Colors.white : c.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('Hakuna malipo hapa',
                  textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12)),
            )
          else
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              _historyRow(c, list[i]),
            ],
        ],
      ),
    );
  }

  Widget _historyRow(_PC c, Contribution h) {
    final (label, fg, bg, icon) = switch (h.status) {
      ContributionStatus.approved => ('Imekamilika', c.green, c.greenBg, TablerIcons.circleCheck),
      ContributionStatus.pending => ('Inasubiri', c.amber, c.amberBg, TablerIcons.clock),
      ContributionStatus.rejected => ('Imekataliwa', c.red, c.redBg, TablerIcons.circleX),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('TZS ${_money(h.amount)}',
                        style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  _Pill(label: label, fg: fg, bg: bg),
                ]),
                const SizedBox(height: 2),
                Text('${_ago(h.createdAt)} · ${_date(h.createdAt)}',
                    style: TextStyle(color: c.muted, fontSize: 12)),
                if (h.status == ContributionStatus.rejected) ...[
                  if ((h.reason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration:
                          BoxDecoration(color: c.redBg, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(TablerIcons.alertCircle, size: 15, color: c.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(h.reason!, style: TextStyle(color: c.red, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _TonalBtn(
                    c: c,
                    icon: TablerIcons.messageCircle,
                    label: 'Wasiliana na admin',
                    height: 28,
                    onTap: widget.onContactAdmin ??
                        () => launchUrl(Uri.parse('https://wa.me/${_intl(widget.supportWhatsapp)}'),
                            mode: LaunchMode.externalApplication),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _support(_PC c) => _Card(
        c: c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MASWALI AU MATATIZO?', style: _k(c)),
            _SupportRow(
              c: c,
              icon: TablerIcons.phoneCall,
              fg: c.blue,
              bg: c.blueBg,
              label: 'Piga simu',
              value: _groupLocal(widget.supportPhone),
              onTap: () => launchUrl(Uri(scheme: 'tel', path: '+${_intl(widget.supportPhone)}')),
            ),
            Divider(height: 1, color: c.border),
            _SupportRow(
              c: c,
              icon: TablerIcons.brandWhatsapp,
              fg: c.green,
              bg: c.greenBg,
              label: 'SMS / WhatsApp',
              value: _prettyIntl(widget.supportWhatsapp),
              onTap: () => launchUrl(Uri.parse('https://wa.me/${_intl(widget.supportWhatsapp)}'),
                  mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      );

  /* ---------- Mitindo ---------- */
  TextStyle _k(_PC c) =>
      TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .8);
  TextStyle _label(_PC c) =>
      TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600);

  InputDecoration _dec(_PC c) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: col, width: w));
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: c.card,
      hintStyle: TextStyle(color: c.muted.withValues(alpha: .7), fontSize: 13),
      border: b(c.borderStrong),
      enabledBorder: b(c.borderStrong),
      focusedBorder: b(c.blue, 1.5),
    );
  }
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _Card extends StatelessWidget {
  final _PC c;
  final Widget child;
  const _Card({required this.c, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: child,
      );
}

class _StepTitle extends StatelessWidget {
  final _PC c;
  final int n;
  final bool done;
  final String text;
  const _StepTitle({required this.c, required this.n, required this.done, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? c.green : c.blue, shape: BoxShape.circle),
            child: done
                ? const Icon(TablerIcons.check, size: 13, color: Colors.white)
                : Text('$n',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Input extends StatelessWidget {
  final _PC c;
  final TextEditingController controller;
  final IconData icon;
  final String prefix;
  final String? hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;

  const _Input({
    required this.c,
    required this.controller,
    required this.icon,
    required this.prefix,
    this.hint,
    this.keyboard,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      style: TextStyle(color: c.text, fontSize: 15),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.muted.withValues(alpha: .7), fontSize: 15),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: c.blue),
            const SizedBox(width: 10),
            Text(prefix, style: TextStyle(color: c.text, fontSize: 15)),
            const SizedBox(width: 10),
            Container(width: 1, height: 20, color: c.borderStrong),
          ]),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

class _TonalBtn extends StatelessWidget {
  final _PC c;
  final IconData icon;
  final String label;
  final double height;
  final VoidCallback onTap;
  const _TonalBtn({
    required this.c,
    required this.icon,
    required this.label,
    required this.onTap,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: c.blueBg,
            foregroundColor: c.blue,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: Size(0, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15),
            const SizedBox(width: 5),
            Text(label),
          ]),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg, bg;
  const _Pill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

class _SquareIcon extends StatelessWidget {
  final _PC c;
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIcon({required this.c, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: c.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), side: BorderSide(color: c.border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: c.text)),
        ),
      );
}

class _SupportRow extends StatelessWidget {
  final _PC c;
  final IconData icon;
  final Color fg, bg;
  final String label, value;
  final VoidCallback onTap;

  const _SupportRow({
    required this.c,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
                Text(value,
                    style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
            Icon(TablerIcons.chevronRight, size: 18, color: c.muted),
          ]),
        ),
      );
}

/* ============================================================
   RANGI
   ============================================================ */
class _PC {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg, red, redBg;

  const _PC({
    required this.card,
    required this.soft,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.muted,
    required this.blue,
    required this.blueBg,
    required this.green,
    required this.greenBg,
    required this.amber,
    required this.amberBg,
    required this.red,
    required this.redBg,
  });

  static const light = _PC(
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    borderStrong: Color(0xFFC3CAD6),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    green: Color(0xFF0F7A52),
    greenBg: Color(0xFFE3F5EC),
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFFFFF1D6),
    red: Color(0xFFC62828),
    redBg: Color(0xFFFDECEC),
  );

  static const dark = _PC(
    card: Color(0xFF181D26),
    soft: Color(0xFF212833),
    border: Color(0xFF2A3240),
    borderStrong: Color(0xFF465164),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    green: Color(0xFF5FD49A),
    greenBg: Color(0xFF15302A),
    amber: Color(0xFFF0B35A),
    amberBg: Color(0xFF3A2C14),
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
  );

  static _PC of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
