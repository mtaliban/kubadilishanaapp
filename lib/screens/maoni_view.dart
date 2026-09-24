import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/* ============================================================
   MODEL
   ============================================================ */
class FeedbackItem {
  final String id;
  final String message;
  final DateTime createdAt;
  final String? reply; // jibu la admin (null = bado)

  const FeedbackItem({
    required this.id,
    required this.message,
    required this.createdAt,
    this.reply,
  });

  bool get answered => (reply ?? '').trim().isNotEmpty;
}

/* ============================================================
   UKURASA WA MAONI
   Weka ndani ya Scaffold yako (body). Menyu ya chini inabaki yako.
   ============================================================ */
class MaoniView extends StatefulWidget {
  final List<FeedbackItem> items;

  /// Inaitwa ukibonyeza "Tuma". Tuma kwenye API yako.
  /// Rudisha FeedbackItem iliyohifadhiwa (au null) ili ionekane juu ya orodha.
  final Future<FeedbackItem?> Function(String message)? onSend;

  final VoidCallback? onBack;
  final int pageSize;
  final int maxLength;

  /// Umbali wa toast kutoka chini (juu ya menyu yako ya chini)
  final double toastBottom;

  const MaoniView({
    super.key,
    this.items = const [],
    this.onSend,
    this.onBack,
    this.pageSize = 5,
    this.maxLength = 500,
    this.toastBottom = 16,
  });

  @override
  State<MaoniView> createState() => _MaoniViewState();
}

class _MaoniViewState extends State<MaoniView> {
  final msgCtrl = TextEditingController();
  late List<FeedbackItem> list = List.of(widget.items);
  int page = 0;
  bool sending = false;
  bool toast = false;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    msgCtrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant MaoniView old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items) list = List.of(widget.items);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    msgCtrl.dispose();
    super.dispose();
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

  bool get _canSend => !sending && msgCtrl.text.trim().isNotEmpty;

  Future<void> _send() async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => sending = true);
    try {
      final saved = await widget.onSend?.call(text);
      if (!mounted) return;
      setState(() {
        list.insert(
          0,
          saved ??
              FeedbackItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                message: text,
                createdAt: DateTime.now(),
              ),
        );
        msgCtrl.clear();
        page = 0;
      });
      _showToast();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Imeshindikana kutuma: $e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _showToast() {
    _toastTimer?.cancel();
    setState(() => toast = true);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => toast = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _MC.of(context);
    final pages = (list.length / widget.pageSize).ceil().clamp(1, 9999);
    final p = page.clamp(0, pages - 1);
    final slice = list.skip(p * widget.pageSize).take(widget.pageSize).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _header(c),
            const SizedBox(height: 12),
            _compose(c),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Row(children: [
                Expanded(
                  child: Text('Maoni yangu',
                      style: TextStyle(
                          color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.border),
                  ),
                  child: Text('${list.length}',
                      style: TextStyle(
                          color: c.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            if (list.isEmpty)
              _empty(c)
            else ...[
              ...slice.map((f) => _FeedbackCard(c: c, item: f, ago: _ago(f.createdAt))),
              if (pages > 1) _pager(c, p, pages),
            ],
          ],
        ),

        // Toast ya "Yametumwa"
        Positioned(
          left: 10,
          right: 10,
          bottom: widget.toastBottom,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              offset: toast ? Offset.zero : const Offset(0, .6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: toast ? 1 : 0,
                child: _toast(c),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(_MC c) => Row(
        children: [
          if (widget.onBack != null) ...[
            Material(
              color: c.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: c.border)),
              child: InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(PhosphorIcons.arrowLeft(), size: 18, color: c.text)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(color: c.blueBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(PhosphorIcons.chatText(), size: 21, color: c.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maoni na malalamiko',
                    style: TextStyle(
                        color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
                Text('Tuma kwa admin, utajibiwa hapa',
                    style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      );

  Widget _compose(_MC c) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: col, width: w));
    return _Card(
      c: c,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(PhosphorIcons.pencil(), size: 16, color: c.blue),
            const SizedBox(width: 6),
            Text('Ujumbe wako',
                style: TextStyle(
                    color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: msgCtrl,
            minLines: 4,
            maxLines: 8,
            maxLength: widget.maxLength,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: c.text, fontSize: 14),
            cursorColor: c.blue,
            decoration: InputDecoration(
              hintText: 'Andika maoni au malalamiko yako hapa…',
              hintStyle:
                  TextStyle(color: c.muted.withValues(alpha: .7), fontSize: 14),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: c.card,
              contentPadding: const EdgeInsets.all(12),
              border: b(c.borderStrong),
              enabledBorder: b(c.borderStrong),
              focusedBorder: b(c.blue, 1.5),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('${msgCtrl.text.length} / ${widget.maxLength}',
                    style: TextStyle(color: c.muted, fontSize: 12)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      textStyle:
                          const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Tuma'),
                            const SizedBox(width: 6),
                            Icon(PhosphorIcons.paperPlaneTilt(), size: 15),
                          ]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(_MC c) => _Card(
        c: c,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: c.blueBg, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.chatCircle(), size: 26, color: c.blue),
            ),
            const SizedBox(height: 10),
            Text('Hujatuma maoni bado',
                style: TextStyle(
                    color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
                'Ukiwa na swali au tatizo, liandike juu.\nJibu la admin litaonekana hapa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _pager(_MC c, int p, int pages) {
    Widget btn(String label, IconData icon, bool leading, VoidCallback? onTap) =>
        SizedBox(
          height: 30,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: c.text,
              disabledForegroundColor: c.muted,
              side: BorderSide(color: c.borderStrong),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
              Text(label),
              if (!leading) ...[const SizedBox(width: 4), Icon(icon, size: 14)],
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          btn('Iliyopita', PhosphorIcons.caretLeft(), true,
              p > 0 ? () => setState(() => page = p - 1) : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${p + 1} / $pages',
                style: TextStyle(color: c.muted, fontSize: 13)),
          ),
          btn('Inayofuata', PhosphorIcons.caretRight(), false,
              p < pages - 1 ? () => setState(() => page = p + 1) : null),
        ],
      ),
    );
  }

  Widget _toast(_MC c) => Material(
        color: c.card,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.borderStrong, width: .5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: c.greenBg, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.check(), size: 16, color: c.green),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Yametumwa kwa admin',
                    style: TextStyle(
                        color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('Utajibiwa hivi karibuni',
                    style: TextStyle(color: c.muted, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      );
}

/* ============================================================
   KADI YA MAONI (ujumbe + jibu la admin)
   ============================================================ */
class _FeedbackCard extends StatelessWidget {
  final _MC c;
  final FeedbackItem item;
  final String ago;
  const _FeedbackCard({required this.c, required this.item, required this.ago});

  @override
  Widget build(BuildContext context) {
    final ans = item.answered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        c: c,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              ans
                  ? _Pill(
                      label: 'Yamejibiwa',
                      icon: PhosphorIcons.checkCircle(),
                      fg: c.green,
                      bg: c.greenBg)
                  : _Pill(
                      label: 'Inasubiri jibu',
                      icon: PhosphorIcons.clock(),
                      fg: c.amber,
                      bg: c.amberBg),
              const Spacer(),
              Text(ago, style: TextStyle(color: c.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 8),

            // Ujumbe wako
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Dot(icon: PhosphorIcons.user(), fg: c.muted, bg: c.soft),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Wewe', style: TextStyle(color: c.muted, fontSize: 11)),
                    Text(item.message,
                        style: TextStyle(color: c.text, fontSize: 14, height: 1.45)),
                  ]),
                ),
              ],
            ),

            // Jibu la admin
            if (ans) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Dot(icon: PhosphorIcons.shieldCheck(), fg: c.blue, bg: c.blueBg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.blueBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jibu la admin',
                                style: TextStyle(
                                    color: c.blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 1),
                            Text(item.reply!,
                                style: TextStyle(
                                    color: c.text, fontSize: 14, height: 1.45)),
                          ]),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _Card extends StatelessWidget {
  final _MC c;
  final Widget child;
  final EdgeInsets padding;
  const _Card(
      {required this.c,
      required this.child,
      this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: child,
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color fg, bg;
  const _Pill(
      {required this.label,
      required this.icon,
      required this.fg,
      required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Dot extends StatelessWidget {
  final IconData icon;
  final Color fg, bg;
  const _Dot({required this.icon, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 14, color: fg),
      );
}

/* ============================================================
   RANGI
   ============================================================ */
class _MC {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg;

  const _MC({
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
  });

  static const light = _MC(
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
  );

  static const dark = _MC(
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
  );

  static _MC of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
