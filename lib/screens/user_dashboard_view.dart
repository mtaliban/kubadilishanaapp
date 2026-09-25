import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/* ============================================================
   MODELS
   ============================================================ */

/// Mtumiaji aliyeingia (wewe)
class DashMe {
  final String name;
  final String idara; // afya / elimu / kilimo / umma (au health / education)
  final String kada;
  final List<String> subjects; // walimu tu, mf. ['Hisabati', 'Fizikia']
  final String mkoa;
  final String wilaya;
  final bool paid;
  final List<String> wantedRegions; // mikoa anayotaka kwenda

  const DashMe({
    required this.name,
    required this.idara,
    required this.kada,
    this.subjects = const [],
    required this.mkoa,
    required this.wilaya,
    this.paid = false,
    this.wantedRegions = const [],
  });

  bool get isTeacher => _idaraKey(idara) == 'elimu';
}

/// Mwenzako anayetaka kuhamia mkoa wako
class Peer {
  final String name;
  final String idara;
  final String kada;
  final DateTime createdAt;
  final String fromMkoa;
  final String fromWilaya;
  final String? fromKituo;
  final String? toWilaya; // null = wilaya yoyote
  final List<String> subjects;
  final String? experience; // mf. "miaka 2"
  final String phone;
  final String? whatsapp;

  const Peer({
    required this.name,
    required this.idara,
    required this.kada,
    required this.createdAt,
    required this.fromMkoa,
    required this.fromWilaya,
    this.fromKituo,
    this.toWilaya,
    this.subjects = const [],
    this.experience,
    required this.phone,
    this.whatsapp,
  });
}

/// Mtindo wa vitufe vya Piga / SMS / WhatsApp
/// stacked = A (icon juu, neno chini)   circles = B (duara za icon)
enum ContactButtonStyle { stacked, circles }

/* ============================================================
   IDARA
   ============================================================ */
enum _Tone { red, blue, green, amber }

String _idaraKey(String raw) {
  final k = raw.trim().toLowerCase();
  if (k == 'health' || k == 'afya') return 'afya';
  if (k == 'education' || k == 'elimu') return 'elimu';
  if (k.contains('agri') || k.contains('kilimo')) return 'kilimo';
  if (k.contains('public') || k.contains('umma')) return 'umma';
  return k;
}

({String label, IconData icon, _Tone tone}) _idaraInfo(String raw) {
  switch (_idaraKey(raw)) {
    case 'afya':
      return (label: 'Afya', icon: TablerIcons.heartRateMonitor, tone: _Tone.green);
    case 'elimu':
      return (label: 'Elimu', icon: TablerIcons.school, tone: _Tone.blue);
    case 'kilimo':
      return (label: 'Kilimo na ufugaji', icon: TablerIcons.plant2, tone: _Tone.green);
    case 'umma':
      return (label: 'Watumishi wa umma', icon: TablerIcons.buildingBank, tone: _Tone.amber);
    default:
      return (label: raw, icon: TablerIcons.briefcase, tone: _Tone.blue);
  }
}

/* ============================================================
   DASHIBODI
   Weka ndani ya Scaffold yako (body). Upau wa juu na menyu ya
   chini zinabaki zako.
   ============================================================ */
class UserDashboardView extends StatefulWidget {
  final DashMe me;
  final List<Peer> peers;

  /// Kiasi cha kuchangia kinachoonyeshwa kwenye toast
  final String price;

  /// Inaitwa ukibonyeza "Changia" kwenye toast
  final VoidCallback? onChangia;

  /// Watu wangapi kwa kila ukurasa
  final int pageSize;

  /// Umbali wa toast kutoka chini (juu ya menyu yako ya chini)
  final double toastBottom;

  /// A = stacked (default), B = circles
  final ContactButtonStyle contactStyle;

  /// Widgets zinazowekwa juu, kabla ya kadi ya "Karibu" (mf. DashboardAnnouncement)
  final List<Widget> top;

  const UserDashboardView({
    super.key,
    required this.me,
    required this.peers,
    this.price = 'TZS 2,500',
    this.onChangia,
    this.pageSize = 10,
    this.toastBottom = 16,
    this.contactStyle = ContactButtonStyle.stacked,
    this.top = const [],
  });

  @override
  State<UserDashboardView> createState() => _UserDashboardViewState();
}

class _UserDashboardViewState extends State<UserDashboardView>
    with SingleTickerProviderStateMixin {
  String? region; // null = mikoa yote
  String? wilaya;
  String? kituo;
  String? idaraFilter; // wasio walimu
  int? matchFilter; // walimu: null = wote, 2, 1, 0
  int page = 0;

  // Toast
  late final AnimationController _toastCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  bool _toastVisible = false;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastCtrl.dispose();
    super.dispose();
  }

  /* ---------- Hesabu ---------- */
  int? _match(Peer p) {
    if (!widget.me.isTeacher) return null;
    final mine = widget.me.subjects.map((s) => s.toLowerCase()).toSet();
    return p.subjects.where((s) => mine.contains(s.toLowerCase())).length;
  }

  List<String> get _regions {
    final s = widget.peers.map((p) => p.fromMkoa).toSet().toList()..sort();
    return s;
  }

  List<Peer> get _inRegion =>
      widget.peers.where((p) => region == null || p.fromMkoa == region).toList();

  List<Peer> get _filtered => _inRegion.where((p) {
        if (wilaya != null && p.fromWilaya != wilaya) return false;
        if (kituo != null && p.fromKituo != kituo) return false;
        if (!widget.me.isTeacher &&
            idaraFilter != null &&
            _idaraKey(p.idara) != idaraFilter) {
          return false;
        }
        if (widget.me.isTeacher && matchFilter != null) {
          final m = _match(p) ?? 0;
          if (matchFilter == 2 && m < 2) return false;
          if (matchFilter == 1 && m != 1) return false;
          if (matchFilter == 0 && m != 0) return false;
        }
        return true;
      }).toList();

  void _setRegion(String? r) => setState(() {
        region = r;
        wilaya = null;
        kituo = null;
        page = 0;
      });

  /* ---------- Mawasiliano ---------- */
  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');
  static String _intl(String p) {
    var d = _digits(p);
    if (d.startsWith('0')) d = '255${d.substring(1)}';
    if (!d.startsWith('255')) d = '255$d';
    return d;
  }

  Future<void> _contact(Peer p, String how) async {
    if (!widget.me.paid) return _showToast();
    final num = _intl(how == 'wa' ? (p.whatsapp ?? p.phone) : p.phone);
    final uri = switch (how) {
      'tel' => Uri(scheme: 'tel', path: '+$num'),
      'sms' => Uri(scheme: 'sms', path: '+$num'),
      _ => Uri.parse('https://wa.me/$num'),
    };
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showToast() {
    _toastTimer?.cancel();
    setState(() => _toastVisible = true);
    _toastCtrl.forward(from: 0);
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toastVisible = false);
    });
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = _Cl.of(context);
    final list = _filtered;
    final pages = (list.length / widget.pageSize).ceil().clamp(1, 9999);
    final p = page.clamp(0, pages - 1);
    final slice = list.skip(p * widget.pageSize).take(widget.pageSize).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            ...widget.top,
            _welcome(c),
            const SizedBox(height: 10),
            _routeBanner(c),
            _title(c, 'Wanakotoka'),
            _regionChips(c),
            const SizedBox(height: 4),
            _dropdownRow(c),
            if (widget.me.isTeacher) ...[
              _title(c, 'Masomo'),
              _matchChips(c),
            ],
            const SizedBox(height: 12),
            if (slice.isEmpty)
              _empty(c)
            else
              ...slice.map((peer) => _PeerTicket(
                    c: c,
                    me: widget.me,
                    peer: peer,
                    match: _match(peer),
                    locked: !widget.me.paid,
                    style: widget.contactStyle,
                    onCall: () => _contact(peer, 'tel'),
                    onSms: () => _contact(peer, 'sms'),
                    onWhatsApp: () => _contact(peer, 'wa'),
                  )),
            if (slice.isNotEmpty && pages > 1) _pager(c, p, pages),
          ],
        ),

        // Toast yenye muda unaoisha
        Positioned(
          left: 10,
          right: 10,
          bottom: widget.toastBottom,
          child: IgnorePointer(
            ignoring: !_toastVisible,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              offset: _toastVisible ? Offset.zero : const Offset(0, .6),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _toastVisible ? 1 : 0,
                child: _toast(c),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _welcome(_Cl c) {
    final me = widget.me;
    final id = _idaraInfo(me.idara);
    final (fg, bg) = c.tone(id.tone);
    final first = me.name.trim().split(RegExp(r'\s+')).first;
    final kadaLine = me.isTeacher && me.subjects.isNotEmpty
        ? '${me.kada} · ${me.subjects.join(', ')}'
        : me.kada;

    return _Card(
      c: c,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: me.name, fg: fg, bg: bg, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Karibu, $first',
                    style: TextStyle(
                        color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                _IconText(c: c, icon: id.icon, iconColor: fg, text: kadaLine),
                _IconText(
                    c: c,
                    icon: TablerIcons.mapPin,
                    text: '${me.wilaya}, ${me.mkoa}'),
              ],
            ),
          ),
          me.paid
              ? _Pill(
                  label: 'Umelipa',
                  icon: TablerIcons.receipt,
                  fg: c.green,
                  bg: c.greenBg)
              : _Pill(
                  label: 'Haujalipa',
                  icon: TablerIcons.receiptOff,
                  fg: c.red,
                  bg: c.redBg),
        ],
      ),
    );
  }

  Widget _routeBanner(_Cl c) {
    final all = region == null;
    final count = _inRegion.length;
    TextStyle k() => TextStyle(color: c.muted, fontSize: 11);

    return _Card(
      c: c,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WAKITOKEA', style: k()),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(all ? TablerIcons.world : TablerIcons.mapPin,
                      size: 17, color: c.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(all ? 'Mikoa yote' : region!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                      color: c.blue,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 2),
                _PlaneLine(c: c),
                Text('wenzako', style: k()),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('WANAHAMIA', style: k()),
                const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(
                    child: Text(widget.me.mkoa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  Icon(TablerIcons.mapPinFilled, size: 17, color: c.green),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(_Cl c, String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t,
            style: TextStyle(
                color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _regionChips(_Cl c) {
    final items = <String?>[null, ..._regions];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r = items[i];
          final on = r == region;
          return GestureDetector(
            onTap: () => _setRegion(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.yellow : c.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? c.yellow : c.borderStrong),
              ),
              child: Text(r ?? 'Yote',
                  style: TextStyle(
                      color: on ? c.onYellow : c.text,
                      fontSize: 14,
                      fontWeight:
                          on ? FontWeight.w600 : FontWeight.w400)),
            ),
          );
        },
      ),
    );
  }

  Widget _dropdownRow(_Cl c) {
    final inR = _inRegion;
    final wilayas = inR.map((p) => p.fromWilaya).toSet().toList()..sort();
    final vituo = inR
        .where((p) => wilaya == null || p.fromWilaya == wilaya)
        .map((p) => p.fromKituo)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final teacher = widget.me.isTeacher;
    final idaras =
        widget.peers.map((p) => _idaraKey(p.idara)).toSet().toList()..sort();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniDropdown(
                c: c,
                icon: TablerIcons.buildingCommunity,
                allLabel: 'Wilaya zote',
                value: wilaya,
                options: wilayas,
                onChanged: (v) => setState(() {
                  wilaya = v;
                  kituo = null;
                  page = 0;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniDropdown(
                c: c,
                icon: teacher ? TablerIcons.school : TablerIcons.building,
                allLabel: teacher ? 'Shule zote' : 'Vituo vyote',
                value: kituo,
                options: vituo,
                onChanged: (v) => setState(() {
                  kituo = v;
                  page = 0;
                }),
              ),
            ),
          ],
        ),
        if (!teacher) ...[
          const SizedBox(height: 8),
          _MiniDropdown(
            c: c,
            icon: TablerIcons.layoutGrid,
            allLabel: 'Idara zote',
            value: idaraFilter,
            options: idaras,
            labelOf: (k) => _idaraInfo(k).label,
            onChanged: (v) => setState(() {
              idaraFilter = v;
              page = 0;
            }),
          ),
        ],
      ],
    );
  }

  Widget _matchChips(_Cl c) {
    const opts = [
      (null, 'Wote'),
      (2, 'Masomo yote mawili'),
      (1, 'Somo moja'),
      (0, 'Wasio match'),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (v, t) = opts[i];
          final on = v == matchFilter;
          return GestureDetector(
            onTap: () => setState(() {
              matchFilter = v;
              page = 0;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.blue : c.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? c.blue : c.borderStrong),
              ),
              child: Text(t,
                  style: TextStyle(
                      color: on ? Colors.white : c.text, fontSize: 13)),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(_Cl c) => _Card(
        c: c,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            Icon(TablerIcons.usersMinus, size: 26, color: c.muted),
            const SizedBox(height: 4),
            Text('Hakuna wenzako hapa',
                style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Text('Jaribu mkoa au kichujio kingine',
                style: TextStyle(color: c.muted, fontSize: 12)),
          ],
        ),
      );

  Widget _pager(_Cl c, int p, int pages) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _OutlineBtn(
            c: c,
            label: 'Iliyopita',
            icon: TablerIcons.chevronLeft,
            leading: true,
            onTap: p > 0 ? () => setState(() => page = p - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('${p + 1} / $pages',
                style: TextStyle(color: c.muted, fontSize: 13)),
          ),
          _OutlineBtn(
            c: c,
            label: 'Inayofuata',
            icon: TablerIcons.chevronRight,
            onTap: p < pages - 1 ? () => setState(() => page = p + 1) : null,
          ),
        ],
      );

  Widget _toast(_Cl c) {
    return Material(
      color: c.card,
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borderStrong, width: .5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
            child: Row(
              children: [
                Icon(TablerIcons.phoneOff, size: 18, color: c.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(
                    style: TextStyle(color: c.text, fontSize: 13),
                    children: [
                      const TextSpan(text: 'Changia '),
                      TextSpan(
                          text: widget.price,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      const TextSpan(text: ' upate namba'),
                    ],
                  )),
                ),
                _TonalBtn(
                  c: c,
                  label: 'Changia',
                  trailing: TablerIcons.arrowRight,
                  onTap: () {
                    setState(() => _toastVisible = false);
                    widget.onChangia?.call();
                  },
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _toastCtrl,
            builder: (_, __) => LinearProgressIndicator(
              value: 1 - _toastCtrl.value,
              minHeight: 3,
              backgroundColor: c.border,
              valueColor: AlwaysStoppedAnimation(c.blue),
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   KADI YA TIKETI YA MWENZAKO
   ============================================================ */
class _PeerTicket extends StatelessWidget {
  final _Cl c;
  final DashMe me;
  final Peer peer;
  final int? match;
  final bool locked;
  final ContactButtonStyle style;
  final VoidCallback onCall, onSms, onWhatsApp;

  const _PeerTicket({
    this.style = ContactButtonStyle.stacked,
    required this.c,
    required this.me,
    required this.peer,
    required this.match,
    required this.locked,
    required this.onCall,
    required this.onSms,
    required this.onWhatsApp,
  });

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays < 1) return 'leo';
    if (diff.inDays < 7) return 'siku ${diff.inDays} zilizopita';
    if (diff.inDays < 30) return 'wiki ${diff.inDays ~/ 7} zilizopita';
    if (diff.inDays < 365) return 'miezi ${diff.inDays ~/ 30} iliyopita';
    return 'miaka ${diff.inDays ~/ 365} iliyopita';
  }

  @override
  Widget build(BuildContext context) {
    final id = _idaraInfo(peer.idara);
    final (fg, bg) = c.tone(id.tone);
    final comesFromWanted = me.wantedRegions
        .map((r) => r.toLowerCase())
        .contains(peer.fromMkoa.toLowerCase());
    final mine = me.subjects.map((s) => s.toLowerCase()).toSet();
    final full = match == 2;
    TextStyle k() => TextStyle(color: c.muted, fontSize: 11);
    TextStyle sub() => TextStyle(color: c.muted, fontSize: 12);
    TextStyle place() =>
        TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w600);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: full ? c.green : c.border, width: full ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Juu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(name: peer.name, fg: fg, bg: bg, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(peer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: c.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          Text(_ago(peer.createdAt), style: sub()),
                        ],
                      ),
                    ),
                    if (match != null) _matchBadge(match!),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Pill(label: id.label, icon: id.icon, fg: fg, bg: bg, size: 12),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(peer.kada,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.text, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _TicketCut(c: c),

          // Safari
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ANATOKA', style: k()),
                          Text(peer.fromMkoa, style: place()),
                          Text(peer.fromWilaya, style: sub()),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
                      child: _PlaneLine(c: c, short: true),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('ANATAKA', style: k()),
                          Text(me.mkoa, style: place()),
                          Text(
                              peer.toWilaya ?? 'Wilaya yoyote',
                              style: sub()),
                        ],
                      ),
                    ),
                  ],
                ),
                if (me.isTeacher && peer.subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Masomo:', style: sub()),
                      ...peer.subjects.map((s) =>
                          mine.contains(s.toLowerCase())
                              ? _Pill(
                                  label: s,
                                  icon: TablerIcons.check,
                                  fg: Colors.white,
                                  bg: c.blue)
                              : _Pill(
                                  label: s,
                                  fg: c.muted,
                                  bg: c.card,
                                  border: c.borderStrong)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (comesFromWanted)
                      _Pill(
                          label: 'Anatoka unakotaka',
                          icon: TablerIcons.circleCheck,
                          fg: c.green,
                          bg: c.greenBg),
                    if (peer.experience != null)
                      _Pill(
                          label: 'Uzoefu: ${peer.experience}',
                          icon: TablerIcons.briefcase,
                          fg: c.muted,
                          bg: c.soft),
                  ],
                ),
              ],
            ),
          ),

          // Vitufe (havipiti upana hata kwenye simu nyembamba)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border))),
            child: style == ContactButtonStyle.stacked
                ? Row(
                    children: [
                      _StackedBtn(
                          icon: TablerIcons.phone,
                          label: 'Piga',
                          fg: c.blue,
                          bg: c.blueBg,
                          locked: locked,
                          onTap: onCall),
                      const SizedBox(width: 6),
                      _StackedBtn(
                          icon: TablerIcons.message,
                          label: 'SMS',
                          fg: c.text,
                          bg: c.soft,
                          locked: locked,
                          onTap: onSms),
                      const SizedBox(width: 6),
                      _StackedBtn(
                          icon: TablerIcons.brandWhatsapp,
                          label: 'WhatsApp',
                          fg: c.green,
                          bg: c.greenBg,
                          locked: locked,
                          onTap: onWhatsApp),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _CircleBtn(
                          c: c,
                          icon: TablerIcons.phone,
                          label: 'Piga',
                          fg: c.blue,
                          bg: c.blueBg,
                          locked: locked,
                          onTap: onCall),
                      _CircleBtn(
                          c: c,
                          icon: TablerIcons.message,
                          label: 'SMS',
                          fg: c.text,
                          bg: c.soft,
                          locked: locked,
                          onTap: onSms),
                      _CircleBtn(
                          c: c,
                          icon: TablerIcons.brandWhatsapp,
                          label: 'WhatsApp',
                          fg: c.green,
                          bg: c.greenBg,
                          locked: locked,
                          onTap: onWhatsApp),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _matchBadge(int m) => switch (m) {
        >= 2 => _Pill(
            label: 'Inalingana',
            icon: TablerIcons.circleCheck,
            fg: c.green,
            bg: c.greenBg),
        1 => _Pill(
            label: 'Kiasi',
            icon: TablerIcons.circleHalf2,
            fg: c.amber,
            bg: c.amberBg),
        _ => _Pill(
            label: 'Hakuna',
            icon: TablerIcons.circleX,
            fg: c.muted,
            bg: c.soft),
      };
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _Card extends StatelessWidget {
  final _Cl c;
  final Widget child;
  final EdgeInsets padding;
  const _Card(
      {required this.c, required this.child, required this.padding});

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

class _Avatar extends StatelessWidget {
  final String name;
  final Color fg, bg;
  final double size;
  const _Avatar(
      {required this.name,
      required this.fg,
      required this.bg,
      required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(initials,
          style: TextStyle(
              color: fg,
              fontSize: size * .33,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _IconText extends StatelessWidget {
  final _Cl c;
  final IconData icon;
  final Color? iconColor;
  final String text;
  const _IconText(
      {required this.c,
      required this.icon,
      required this.text,
      this.iconColor});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: iconColor ?? c.muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.muted, fontSize: 12)),
        ),
      ]);
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;
  final Color? border;
  final double size;
  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.border,
    this.size = 11,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border != null ? Border.all(color: border!) : null,
        ),
        // Flexible + ellipsis: pill haiwezi kuzidi upana wa mzazi (font kubwa).
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: size + 1, color: fg),
              const SizedBox(width: 4)
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg, fontSize: size, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}

class _PlaneLine extends StatelessWidget {
  final _Cl c;
  final bool short;
  const _PlaneLine({required this.c, this.short = false});

  @override
  Widget build(BuildContext context) {
    Widget dash() => SizedBox(
          width: short ? 12 : 14,
          child: LayoutBuilder(
            builder: (_, b) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                  3,
                  (_) => Container(
                      width: 3, height: 1.5, color: c.blue)),
            ),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      dash(),
      const SizedBox(width: 2),
      Icon(TablerIcons.plane, size: short ? 16 : 18, color: c.blue),
      const SizedBox(width: 2),
      dash(),
    ]);
  }
}

class _TicketCut extends StatelessWidget {
  final _Cl c;
  const _TicketCut({required this.c});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 18,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: LayoutBuilder(
                  builder: (_, b) {
                    final n = (b.maxWidth / 11).floor();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                          n,
                          (_) => Container(
                              width: 6, height: 2, color: c.borderStrong)),
                    );
                  },
                ),
              ),
            ),
            Positioned(left: -10, top: 0, child: _notch(context)),
            Positioned(right: -10, top: 0, child: _notch(context)),
          ],
        ),
      );

  Widget _notch(BuildContext context) => Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          shape: BoxShape.circle));
}

class _MiniDropdown extends StatelessWidget {
  final _Cl c;
  final IconData icon;
  final String allLabel;
  final String? value;
  final List<String> options;
  final String Function(String)? labelOf;
  final ValueChanged<String?> onChanged;

  const _MiniDropdown({
    required this.c,
    required this.icon,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    String lbl(String? v) => v == null ? allLabel : (labelOf?.call(v) ?? v);
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      color: c.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.borderStrong)),
      itemBuilder: (_) => [null, ...options]
          .map((o) => PopupMenuItem<String?>(
                value: o,
                height: 42,
                child: Row(children: [
                  Icon(icon, size: 16, color: c.blue),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(lbl(o),
                          style:
                              TextStyle(color: c.text, fontSize: 14))),
                  if (o == value)
                    Icon(TablerIcons.check, size: 16, color: c.blue),
                ]),
              ))
          .toList(),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value != null ? c.blue : c.borderStrong),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: c.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(lbl(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: value != null ? c.text : c.muted,
                    fontSize: 13)),
          ),
          Icon(TablerIcons.chevronDown, size: 14, color: c.muted),
        ]),
      ),
    );
  }
}

/// A · icon juu, neno chini, kufuli pembeni ya juu
class _StackedBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg, bg;
  final bool locked;
  final VoidCallback onTap;

  const _StackedBtn({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 52,
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 19, color: fg),
                        const SizedBox(height: 3),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style:
                                  TextStyle(color: fg, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  if (locked)
                    Positioned(
                      top: 5,
                      right: 6,
                      child: Icon(TablerIcons.lock,
                          size: 11, color: fg.withValues(alpha: .6)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// B · duara la icon, neno chini yake, kufuli kwenye kitone
class _CircleBtn extends StatelessWidget {
  final _Cl c;
  final IconData icon;
  final String label;
  final Color fg, bg;
  final bool locked;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.c,
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: bg,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(icon, size: 20, color: fg),
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.card,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: c.borderStrong, width: .5),
                      ),
                      child: Icon(TablerIcons.lock,
                          size: 10, color: c.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(color: c.muted, fontSize: 11)),
        ],
      );
}

class _TonalBtn extends StatelessWidget {
  final _Cl c;
  final String label;
  final IconData? trailing;
  final VoidCallback onTap;
  const _TonalBtn(
      {required this.c,
      required this.label,
      required this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 28,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: c.blueBg,
            foregroundColor: c.blue,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w400),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 13)
            ],
          ]),
        ),
      );
}

class _OutlineBtn extends StatelessWidget {
  final _Cl c;
  final String label;
  final IconData icon;
  final bool leading;
  final VoidCallback? onTap;
  const _OutlineBtn({
    required this.c,
    required this.label,
    required this.icon,
    this.leading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w400),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading) ...[
              Icon(icon, size: 14),
              const SizedBox(width: 4)
            ],
            Text(label),
            if (!leading) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 14)
            ],
          ]),
        ),
      );
}

/* ============================================================
   RANGI
   ============================================================ */
class _Cl {
  final Color page, card, soft, border, borderStrong, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg, red, redBg,
      yellow, onYellow;

  const _Cl({
    required this.page,
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
    required this.yellow,
    required this.onYellow,
  });

  static const light = _Cl(
    page: Color(0xFFF3F5F9),
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
    yellow: Color(0xFFFACC15),
    onYellow: Color(0xFF1F2937),
  );

  static const dark = _Cl(
    page: Color(0xFF0F1319),
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
    yellow: Color(0xFFFACC15),
    onYellow: Color(0xFF1F2937),
  );

  static _Cl of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.red => (red, redBg),
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}

/* ============================================================
   TANGAZO LA DASHIBODI
   Weka ndani ya `top` ya UserDashboardView.
   Aina inafuata ile admin aliyochagua: taarifa / onyo / mafanikio
   ============================================================ */
enum AnnouncementKind { taarifa, onyo, mafanikio }

AnnouncementKind announcementKindFrom(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'onyo':
    case 'warning':
      return AnnouncementKind.onyo;
    case 'mafanikio':
    case 'success':
      return AnnouncementKind.mafanikio;
    default:
      return AnnouncementKind.taarifa;
  }
}

class DashboardAnnouncement extends StatefulWidget {
  final String title;
  final String message;
  final AnnouncementKind kind;
  final DateTime? date;

  /// Inaitwa ukibonyeza ×. Hifadhi (mf. SharedPreferences) ili lisionekane tena.
  final VoidCallback? onClose;

  const DashboardAnnouncement({
    super.key,
    required this.title,
    required this.message,
    this.kind = AnnouncementKind.taarifa,
    this.date,
    this.onClose,
  });

  @override
  State<DashboardAnnouncement> createState() => _DashboardAnnouncementState();
}

class _DashboardAnnouncementState extends State<DashboardAnnouncement> {
  bool open = false;
  bool visible = true;

  static String _calm(String s) {
    final t = s.trim();
    final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty || letters != letters.toUpperCase()) return t;
    final lower = t.toLowerCase();
    return lower.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-z])'),
      (m) => '${m[1]}${m[2]!.toUpperCase()}',
    );
  }

  static String _when(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days <= 0) return 'Leo';
    if (days == 1) return 'Jana';
    if (days < 7) return 'Siku $days';
    const m = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${m[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final c = _AC.of(context);
    final (fg, bg, icon) = switch (widget.kind) {
      AnnouncementKind.taarifa => (c.blue, c.blueBg, TablerIcons.speakerphone),
      AnnouncementKind.onyo => (c.amber, c.amberBg, TablerIcons.alertTriangle),
      AnnouncementKind.mafanikio => (c.green, c.greenBg, TablerIcons.circleCheck),
    };
    final msg = _calm(widget.message);
    final long = msg.length > 90;
    final when = _when(widget.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: fg),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration:
                          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, size: 17, color: fg),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(_calm(widget.title),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: c.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                            if (when.isNotEmpty)
                              Text(when, style: TextStyle(color: c.muted, fontSize: 11)),
                          ]),
                          const SizedBox(height: 2),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.topCenter,
                            child: Text(
                              msg,
                              maxLines: open ? null : 2,
                              overflow: open ? null : TextOverflow.ellipsis,
                              style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
                            ),
                          ),
                          if (long)
                            GestureDetector(
                              onTap: () => setState(() => open = !open),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  open ? 'Punguza' : 'Soma zaidi',
                                  style: TextStyle(
                                      color: c.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: c.soft,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          setState(() => visible = false);
                          widget.onClose?.call();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(TablerIcons.x, size: 14, color: c.muted),
                        ),
                      ),
                    ),
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

/* ============================================================
   RANGI — MATANGAZO
   ============================================================ */
class _AC {
  final Color card, soft, border, text, muted;
  final Color blue, blueBg, green, greenBg, amber, amberBg;

  const _AC({
    required this.card,
    required this.soft,
    required this.border,
    required this.text,
    required this.muted,
    required this.blue,
    required this.blueBg,
    required this.green,
    required this.greenBg,
    required this.amber,
    required this.amberBg,
  });

  static const light = _AC(
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFF1F3F7),
    border: Color(0xFFE3E7EE),
    text: Color(0xFF111827),
    muted: Color(0xFF5B6475),
    blue: Color(0xFF1E66E0),
    blueBg: Color(0xFFE8F0FD),
    green: Color(0xFF0F7A52),
    greenBg: Color(0xFFE3F5EC),
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFFFFF1D6),
  );

  static const dark = _AC(
    card: Color(0xFF181D26),
    soft: Color(0xFF212833),
    border: Color(0xFF2A3240),
    text: Color(0xFFEEF1F6),
    muted: Color(0xFFA8B1C1),
    blue: Color(0xFF7AA7FF),
    blueBg: Color(0xFF1C2A44),
    green: Color(0xFF5FD49A),
    greenBg: Color(0xFF15302A),
    amber: Color(0xFFF0B35A),
    amberBg: Color(0xFF3A2C14),
  );

  static _AC of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
