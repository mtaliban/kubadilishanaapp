// maoni_page.dart
// Ukurasa wa Maoni — NEW DESIGN (Lucide icons, nukuu za serif, Live dot).
// Design ni MOJA kabisa na maoni_page.dart waliyoishia: rangi, saizi, spacing —
// kama zilivyo. Data loading (adminListFeedback), reply endpoint
// (adminReplyFeedback), WebSocket refresh, na badge logic — zimetoka kwenye
// page ya zamani, hazijabadilika.
//
// Muundo wa API ya AdminShell → route 8 (Maoni). Hakuna ScaffoldAppBar
// wala bottom nav ya maoni — meshing na AdminShell drawer (AppDrawer).

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../services/api_service.dart';
import '../../services/cached_repository.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/tight_title.dart';
import '../../services/websocket_service.dart';
import '../../services/admin_badge_service.dart';
import '../../widgets/app_toast.dart' show AppToast, friendlyError;
import '../../widgets/app_drawer.dart' show BadgeController, NavItem;

// ---------------------------------------------------------------- Rangi

class _C {
  static const blue = Color(0xFF1E40AF);
  static const blueLink = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const green = Color(0xFF16A34A);
  static const greenDark = Color(0xFF15803D);
  static const greenSoft = Color(0xFFF0FDF4);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEF2F2);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE5E7EB);
  static const searchLine = Color(0xFF94A3B8);
  static const searchIcon = Color(0xFF334155);
  static const editFill = Color(0xFFF3F6FB);
  static const disabled = Color(0xFFcbd5e1);

  // DARK tokens (theme-aware ZA _of) — zitumike kwa kueleza dark variant
  static bool _d(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  static Color _of(BuildContext c, Color light, Color dark) =>
      _d(c) ? dark : light;
  static Color blueOf(BuildContext c) => _of(c, blue, const Color(0xFF7AA7FF));
  static Color blueLinkOf(BuildContext c) => _of(c, blueLink, const Color(0xFF7AA7FF));
  static Color blueSoftOf(BuildContext c) => _of(c, blueSoft, const Color(0xFF1C2A44));
  static Color greenSoftOf(BuildContext c) => _of(c, greenSoft, const Color(0xFF14532D));
  static Color redSoftOf(BuildContext c) => _of(c, redSoft, const Color(0xFF3A1D1B));
  static Color inkOf(BuildContext c) => _of(c, ink, const Color(0xFFE7ECF8));
  static Color bodyOf(BuildContext c) => _of(c, body, const Color(0xFFE7ECF8));
  static Color mutedOf(BuildContext c) => _of(c, muted, const Color(0xFF9AA8C7));
  static Color lineOf(BuildContext c) => _of(c, line, const Color(0xFF2A3240));
  static Color searchLineOf(BuildContext c) => _of(c, searchLine, const Color(0xFF475569));
  static Color searchIconOf(BuildContext c) => _of(c, searchIcon, const Color(0xFF94A3B8));
  static Color editFillOf(BuildContext c) => _of(c, editFill, const Color(0xFF212833));
  static Color greenDarkOf(BuildContext c) => _of(c, greenDark, const Color(0xFF86EFAC));
  static Color disabledOf(BuildContext c) => _of(c, disabled, const Color(0xFF334155));
  static Color redOf(BuildContext c) => _of(c, red, const Color(0xFFF87171));
  static Color greenOf(BuildContext c) => _of(c, green, const Color(0xFF5FD49A));
  static Color blueUnderlineOf(BuildContext c) => _of(c, blue, const Color(0xFF7AA7FF));
  static Color scaffoldOf(BuildContext c) => _of(c, Colors.white, const Color(0xFF0F172A));
}

// ---------------------------------------------------------------- Aikoni
// Aikoni zote ziko hapa pamoja. Kama namespace haipatikani, badilisha tu hapa.

class _AppIcons {
  static final search = LucideIcons.search;
  static final inbox = LucideIcons.inbox;
  static final pending = LucideIcons.clock;
  static final done = LucideIcons.checkCircle2;
  static final send = LucideIcons.send;
  static final reply = LucideIcons.cornerUpLeft;
  static final prev = LucideIcons.chevronLeft;
  static final next = LucideIcons.chevronRight;
}

// ---------------------------------------------------------------- Modeli

class Maoni {
  Maoni({
    required this.id,
    required this.text,
    required this.name,
    required this.phone,
    required this.date,
    this.reply = '',
  });

  final int id;
  final String text;
  final String name;
  final String phone;
  final String date;
  String reply;

  bool get answered => reply.trim().isNotEmpty;
}

// ---------------------------------------------------------------- Live dot

class LiveDot extends StatefulWidget {
  const LiveDot({super.key});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _C.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _C.green.withOpacity(0.45 * (1 - _c.value)),
                spreadRadius: 7 * _c.value,
              ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------- Mitindo

const _serifFallback = ['Georgia', 'Noto Serif', 'Times New Roman'];

// RANGI DARK-AWARE: color LAZIMA itumwe waziwa (default ya _serif ilikuwa
// _C.body — meusi hardcoded, haionekani kwenye dark mode).
TextStyle _serif(
  double size, {
  FontStyle style = FontStyle.normal,
  required Color color,
  double height = 1.5,
}) =>
    TextStyle(
      fontFamily: 'serif',
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      fontStyle: style,
      color: color,
      height: height,
    );

// ---------------------------------------------------------------- Modeli & mapping

const _monthsShort = [
  'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
];

DateTime _parseIso(dynamic v, {DateTime? fallback}) {
  final s = v?.toString() ?? '';
  if (s.isEmpty) return fallback ?? DateTime.now();
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return fallback ?? DateTime.now();
  }
}

/** Ramani ya item ya API → Maoni (id int-ish, jina/simu/tarehe jformatted). */
@visibleForTesting
Maoni maoniFromFeedbackForTest(Map<String, dynamic> m, int fallbackId) =>
    _maoniFromFeedback(m, fallbackId);

Maoni _maoniFromFeedback(Map<String, dynamic> m, int fallbackId) {
  final idStr = (m['id'] ?? m['_id'] ?? fallbackId).toString();
  final idFallback = int.tryParse(idStr) ?? fallbackId;
  final phone = (m['user_phone'] ?? m['phone'] ?? '').toString();
  final nameRaw = (m['user_name'] ?? m['full_name'] ?? '').toString();
  final name = nameRaw.isNotEmpty && !nameRaw.startsWith('+')
      ? nameRaw
      : (phone.isNotEmpty ? phone : 'Mtumiaji');
  final created = _parseIso(m['created_at']);
  final subject = (m['subject'] ?? '').toString().trim();
  final message = (m['message'] ?? '').toString().trim();
  // BUG-WA-MAJIRUDIA: app ya user inatuma subject = herufi 60 za kwanza za
  // ujumbe mwenyewe (au ujumbe mzima kama fupi), hivyo kadi ilionyesha subject
  // na message zinazofanana kama MBILI ("Okay\nOkay", kichwa fkula + ujumbe).
  // Subject inaonyeshwa TU kama SI sehemu ya ujumbe — inatibu pia data ya
  // zamani iliyohifadhiwa kwenye DB bila kubadilisha backend.
  // Kichwa fkula kina '...' ya truncation (app ya user: herufi 60 + '...') —
  // tunafuta vitone vinavyoishia na kupima kama subject ni mwanzo wa ujumbe.
  final subjectCore = subject.replaceAll(RegExp(r'\.{1,3}$'), '').trim();
  final subjectIsPrefix =
      subjectCore.isNotEmpty && message.startsWith(subjectCore);
  final userText = [
    if (subject.isNotEmpty && !message.contains(subject) && !subjectIsPrefix)
      subject,
    if (message.isNotEmpty) message,
  ].join('\n');
  final reply = (m['admin_reply'] ?? m['reply'] ?? '').toString().trim();

  // Tarehe iko katika mfano "11 Okt, 06:57" kama picha.
  final hh = created.hour.toString().padLeft(2, '0');
  final mm = created.minute.toString().padLeft(2, '0');
  final date = '${created.day} ${_monthsShort[created.month - 1]}, $hh:$mm';

  return Maoni(
    id: idFallback,
    name: name,
    phone: phone,
    date: date,
    text: userText.isEmpty ? '(tupu)' : userText,
    reply: reply,
  );
}

// ---------------------------------------------------------------- Ukurasa

enum _Tab { yote, hayajibiwa, yamejibiwa }

class MaoniPage extends StatefulWidget {
  const MaoniPage({
    super.key,
    this.initialItems,
    this.onSendReply,
    this.pageSize = 5,
  });

  final List<Maoni>? initialItems;
  final Future<void> Function(Maoni maoni, String reply)? onSendReply;
  final int pageSize;

  @override
  State<MaoniPage> createState() => _MaoniPageState();
}

class _MaoniPageState extends State<MaoniPage> {
  late final List<Maoni> _items = widget.initialItems ?? const <Maoni>[];
  final _scroll = ScrollController();
  final _replyCtrl = TextEditingController();

  _Tab _tab = _Tab.yote;
  String _query = '';
  int _page = 1;
  Maoni? _editing;

  @override
  void dispose() {
    _scroll.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  // ----- data

  int get _answered => _items.where((m) => m.answered).length;
  int get _pending => _items.length - _answered;

  List<Maoni> get _filtered {
    final q = _query.toLowerCase().trim();
    return _items.where((m) {
      if (_tab == _Tab.hayajibiwa && m.answered) return false;
      if (_tab == _Tab.yamejibiwa && !m.answered) return false;
      if (q.isEmpty) return true;
      return '${m.name} ${m.phone} ${m.text}'.toLowerCase().contains(q);
    }).toList();
  }

  int _pagesOf(int total) => total == 0 ? 1 : (total / widget.pageSize).ceil();

  // ----- actions

  void _setTab(_Tab t) => setState(() {
        _tab = t;
        _page = 1;
        _editing = null;
      });

  void _goToPage(int p) {
    setState(() {
      _page = p;
      _editing = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _startEdit(Maoni m) {
    _replyCtrl.text = m.reply;
    setState(() => _editing = m);
  }

  Future<void> _send(Maoni m) async {
    final text = _replyCtrl.text.trim();
    setState(() {
      m.reply = text;
      _editing = null;
    });
    try {
      await widget.onSendReply?.call(m, text);
      if (mounted) AppToast.success('Jibu limetumwa');
    } catch (e) {
      // Jibu halikuhifadhiwa — rudisha kwenye "Hayajibiwa" na uonyeshe kosa.
      if (mounted) {
        setState(() {
          m.reply = '';
          _editing = m;
        });
        AppToast.error(friendlyError(e));
      }
    }
  }

  // ----- build

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final pages = _pagesOf(all.length);
    final page = _page > pages ? pages : _page;
    final start = (page - 1) * widget.pageSize;
    final shown = all.skip(start).take(widget.pageSize).toList();

    return Scaffold(
      backgroundColor: _C.scaffoldOf(context),
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _header()),
          if (shown.isEmpty)
            SliverToBoxAdapter(child: _empty())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _tile(shown[i]),
                  childCount: shown.length,
                ),
              ),
            ),
          SliverToBoxAdapter(child: _pagination(page, pages)),
        ],
      ),
    );
  }

  // ----- kichwa, vichupo, utafutaji

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // RESPONSIVE: 'Maoni' kwenye font kubwa — FittedBox badala ya
                // Row ikibeyuka (LiveDot + 'Live' haziwezi pungua).
                TightTitle('Maoni',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: _C.inkOf(context))),
                const SizedBox(width: 12),
                LiveDot(),
                const SizedBox(width: 8),
                Text('Live',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _C.greenDarkOf(context))),
              ],
            ),
            const SizedBox(height: 12),
            _tabs(),
            _search(),
          ],
        ),
      );

  Widget _tabs() => Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _C.lineOf(context)))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tabItem(_Tab.yote, 'Yote', _AppIcons.inbox, _items.length,
                  _C.blueSoftOf(context), _C.blueOf(context), _C.blueOf(context)),
              const SizedBox(width: 16),
              _tabItem(_Tab.hayajibiwa, 'Hayajibiwa', _AppIcons.pending,
                  _pending,
                  _C.redSoftOf(context),
                  _C.redOf(context),
                  _C.redOf(context)),
              const SizedBox(width: 16),
              _tabItem(_Tab.yamejibiwa, 'Yamejibiwa', _AppIcons.done,
                  _answered,
                  _C.greenSoftOf(context),
                  _C.greenDarkOf(context),
                  _C.greenOf(context)),
            ],
          ),
        ),
      );

  Widget _tabItem(_Tab t, String label, IconData icon, int count,
      Color badgeBg, Color badgeFg, Color iconColor) {
    final on = _tab == t;
    return InkWell(
      onTap: () => _setTab(t),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: on ? _C.blueOf(context) : Colors.transparent,
                  width: 2.5)),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: t == _Tab.yote
                    ? (on ? _C.blueOf(context) : _C.mutedOf(context))
                    : iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                color: on ? _C.blueOf(context) : _C.mutedOf(context),
              ),
            ),
            const SizedBox(width: 6),
            _badge(count, badgeBg, badgeFg),
          ],
        ),
      ),
    );
  }

  // Namba ndani ya duara. Hayajibiwa inabaki nyekundu hata ikiwa 0.
  Widget _badge(int n, Color bg, Color fg) => Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: bg,
            shape: n < 100 ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                n < 100 ? null : BorderRadius.circular(11)),
        child: Text('$n',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
      );

  Widget _search() => TextField(
        onChanged: (v) => setState(() {
          _query = v;
          _page = 1;
        }),
        style: TextStyle(fontSize: 15, color: _C.inkOf(context)),
        decoration: InputDecoration(
          hintText: 'Tafuta jina, namba au ujumbe',
          hintStyle: TextStyle(color: _C.searchLineOf(context), fontSize: 15),
          prefixIcon:
              Icon(_AppIcons.search, size: 20, color: _C.searchIconOf(context)),
          prefixIconConstraints: const BoxConstraints(minWidth: 30),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder:
              UnderlineInputBorder(borderSide: BorderSide(color: _C.searchLineOf(context))),
          focusedBorder:
              UnderlineInputBorder(borderSide: BorderSide(color: _C.blueOf(context), width: 1.5)),
        ),
      );

  // ----- ujumbe

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Column(
          children: [
            Icon(_AppIcons.done, size: 30, color: _C.green),
            const SizedBox(height: 8),
            Text(
              _tab == _Tab.hayajibiwa
                  ? 'Hakuna maoni yasiyojibiwa'
                  : 'Hakuna maoni hapa',
              style: TextStyle(fontSize: 14, color: _C.mutedOf(context)),
            ),
          ],
        ),
      );

  Widget _tile(Maoni m) {
    final editing = identical(_editing, m);
    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 16),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: _C.lineOf(context)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RESPONSIVE: nukuu + hali — kwenye font kubwa (2.0) 'Haijajibiwa'
          // haki-tooshi pamoja na nukuu kwenye mstari mmoja: hali inapunguka
          // (ellipsis) badala ya Row ikibeyuka (overflow).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 22,
                child:
                    Text('\u201C', style: _serif(30, color: _C.blueLinkOf(context), height: 1)),
              ),
              Flexible(child: _status(m.answered)),
            ],
          ),
          // RANGI DARK-AWARE: default ya _serif ilikuwa _C.body (meusi hardcoded)
          // — kwenye dark mode HAIONEKANI. Tumia bodyOf(context).
          Text(m.text, style: _serif(17, color: _C.bodyOf(context))),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Text(
              '\u2014 ${m.name} \u00B7 ${m.phone} \u00B7 ${m.date}',
              style: TextStyle(fontSize: 12, color: _C.mutedOf(context)),
            ),
          ),
          if (editing)
            _editor(m)
          else if (m.answered)
            _replyBlock(m)
          else
            _replyButton(m),
        ],
      ),
    );
  }

  Widget _status(bool answered) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(answered ? _AppIcons.done : _AppIcons.pending,
              size: 16,
                color: answered
                    ? _C.greenOf(context)
                    : _C.redOf(context)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              answered ? 'Imejibiwa' : 'Haijajibiwa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: answered ? _C.greenDarkOf(context) : _C.redOf(context)),
            ),
          ),
        ],
      );

  // Jibu lililopo: mstari wa bluu kushoto + "Hariri jibu"
  Widget _replyBlock(Maoni m) => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: _C.blueLinkOf(context), width: 3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jibu lako',
                style: TextStyle(fontSize: 12, color: _C.mutedOf(context))),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(m.reply,
                  style: _serif(15, style: FontStyle.italic, color: _C.inkOf(context))),
            ),
            InkWell(
              onTap: () => _startEdit(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('Hariri jibu',
                    style: TextStyle(fontSize: 13, color: _C.blueLinkOf(context))),
              ),
            ),
          ],
        ),
      );

  // Kitufe cha Jibu: duara la bluu lenye mshale + neno "Jibu"
  Widget _replyButton(Maoni m) => InkWell(
        onTap: () => _startEdit(m),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _C.blueOf(context),
              child: Icon(_AppIcons.reply, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('Jibu',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _C.blue)),
            const SizedBox(width: 8),
          ],
        ),
      );

  // Kisanduku cha kuandika jibu + Tuma (aikoni ya kutuma) + Ghairi
  Widget _editor(Maoni m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _replyCtrl,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            style: _serif(16, style: FontStyle.italic, color: _C.inkOf(context), height: 1.4),
            decoration: InputDecoration(
              hintText: 'Andika jibu lako...',
              filled: true,
              fillColor: _C.editFillOf(context),
              contentPadding: EdgeInsets.all(12),
              border: UnderlineInputBorder(
                  borderSide: BorderSide(color: _C.blueLinkOf(context), width: 2)),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _C.blueLinkOf(context), width: 2)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _C.blueLinkOf(context), width: 2)),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              InkWell(
                onTap: () => _send(m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(_AppIcons.send, size: 19, color: _C.blue),
                      SizedBox(width: 6),
                      Text('Tuma',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _C.blue)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              InkWell(
                onTap: () => setState(() => _editing = null),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child:
                      Text('Ghairi', style: TextStyle(fontSize: 14, color: _C.mutedOf(context))),
                ),
              ),
            ],
          ),
        ],
      );

  // ----- kurasa: mshale wa nyuma, namba 1 2 3 ..., mshale wa mbele

  Widget _pagination(int page, int pages) {
    if (pages <= 1) return const SizedBox(height: 16);
    final canPrev = page > 1;
    final canNext = page < pages;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _C.lineOf(context)))),
      // RESPONSIVE: kurasa nyingi + font kubwa — Wrap inavunja mstari
      // badala ya Row ikibeyuka (overflow).
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: canPrev ? () => _goToPage(page - 1) : null,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(_AppIcons.prev,
                  size: 22, color: canPrev ? _C.ink : _C.disabled),
            ),
          ),
          for (var p = 1; p <= pages; p++)
            InkWell(
              onTap: () => _goToPage(p),
              customBorder: const CircleBorder(),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p == page ? _C.blue : Colors.transparent),
                child: Text(
                  '$p',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: p == page ? FontWeight.w500 : FontWeight.w400,
                    color: p == page ? Colors.white : _C.mutedOf(context),
                  ),
                ),
              ),
            ),
          InkWell(
            onTap: canNext ? () => _goToPage(page + 1) : null,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(_AppIcons.next,
                  size: 22, color: canNext ? _C.ink : _C.disabled),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INTEGRATION LAYER — AdminShell route 8 (Maoni): PAGE MOJA ya design mpya
// na data halisi ya API. Loading state + error state + pull-to-refresh
// zimehifadhiwa kama page ya zamani.
// ============================================================================

class AdminMaoniPage extends StatefulWidget {
  const AdminMaoniPage({super.key});

  @override
  State<AdminMaoniPage> createState() => _AdminMaoniPageState();
}

class _AdminMaoniPageState extends State<AdminMaoniPage> {
  List<Maoni> _items = [];
  // Mapping: Maoni.id (int) ↔ feedback id ya string ya API.
  final Map<int, String> _apiIds = {};
  int _fallbackCounter = 1000;
  bool _loading = true;

  /// OFFLINE-FIRST — funguo ya diski ya CachedRepository (maoni yote).
  static const String kMaoniCacheKey = 'page:admin/feedback';

  void _onWs(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? payload['event'])?.toString() ?? '';
    if ((type == 'feedback.new' || type == 'feedback.replied') && mounted) {
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    // DISKI PAPO HAPO — frame ya KWANZA (hakuna spring, hakuna kusubiri).
    CachedRepository().hydrate(kMaoniCacheKey, _applyMaoniDisk);
    _load();
    WebSocketService().on('notification', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    super.dispose();
  }

  // DISKI/API → maoni (SYNC: frame ya kwanza, hakuna spring).
  void _applyMaoniDisk(dynamic data) {
    if (data == null) return;
    final list = data is List
        ? data
        : (data is Map
            ? (data['items'] as List? ??
                data['results'] as List? ??
                const [])
            : const <dynamic>[]);
    final items = <Maoni>[];
    for (final it in list) {
      if (it is! Map) continue;
      final m = Map<String, dynamic>.from(it);
      final maoni = _maoniFromFeedback(m, _fallbackCounter++);
      _apiIds[maoni.id] = (m['id'] ?? m['_id'] ?? '').toString();
      items.add(maoni);
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _load() async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: data ya diski inabaki.
    setState(() {
      if (_items.isEmpty && _loading) _loading = true;
    });
    await CachedRepository().loadPage(
        kMaoniCacheKey,
        () async => (await ApiService().adminListFeedback(status: '', q: '')).data,
        _applyMaoniDisk);
    if (!mounted) return;
    if (_items.isEmpty && _loading) setState(() => _loading = false);
  }

  Future<void> _sendReply(Maoni item, String text) async {
    final apiId = _apiIds[item.id];
    if (apiId == null || apiId.isEmpty) {
      throw Exception('ID ya maoni haipatikani');
    }
    try {
      await ApiService().adminReplyFeedback(apiId, text);
      if (!mounted) return;
      // Badge ya Maoni inapungua TU baada ya kujibu (clearOnAction).
      BadgeController.instance.decrement(NavItem.maoni);
      AdminBadgeService().refresh();
      // Pakia upya — data halisi itaingia (nyuma kwa pazia).
      unawaited(_load());
    } catch (_) {
      rethrow; // MaoniPage inaonyesha kosa la ndani
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDisk = CachedRepository().readOrNull<dynamic>(kMaoniCacheKey) != null;
    if (_loading && _items.isEmpty) {
      // KANUNI: KAMWE spinner — kijivu (skeleton) tu, hata mara ya kwanza.
      return Scaffold(
        backgroundColor: _C.scaffoldOf(context),
        body: const MaoniSkeleton(),
      );
    }
    if (_items.isEmpty && !hasDisk) {
      // HAKUNA data diski + API imeshindwa — skeleton ya ukurasa
      // (pull-to-refresh pekee; hakuna kitufe cha "Jaribu tena", hakuna ikoni nyekundu).
      return Scaffold(
        backgroundColor: _C.scaffoldOf(context),
        body: const MaoniSkeleton(),
      );
    }
    return MaoniPage(
      initialItems: _items,
      onSendReply: _sendReply,
    );
  }
}
