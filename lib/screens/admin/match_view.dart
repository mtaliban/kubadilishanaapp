// =============================================================================
// match_view.dart
// Ukurasa wa ADMIN: "Match za kweli" (watu wawili wanaobadilishana).
// Ni sehemu ya katikati (body) tu. Upau wa juu na menyu ya chini
// ya admin HAZIGUSWI, zinabaki kama zilivyo.
//
// Packages: tabler_icons_plus, url_launcher
// =============================================================================

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/* ============================================================
   MODELS
   ============================================================ */
class MatchDestination {
  final String mkoa;
  final String? wilaya;
  const MatchDestination({required this.mkoa, this.wilaya});
}

class MatchPerson {
  final String name;
  final bool paid;
  final String fromMkoa;
  final String fromWilaya;
  final List<MatchDestination> destinations;
  final List<String> subjects;
  final String phone;
  final String? whatsapp;

  const MatchPerson({
    required this.name,
    required this.paid,
    required this.fromMkoa,
    required this.fromWilaya,
    required this.destinations,
    this.subjects = const [],
    required this.phone,
    this.whatsapp,
  });
}

class MatchPair {
  final String id;
  final int score;
  final String idara;
  final String kada;
  final List<String> matchedSubjects;
  final MatchPerson a;
  final MatchPerson b;

  const MatchPair({
    required this.id,
    required this.score,
    required this.idara,
    required this.kada,
    this.matchedSubjects = const [],
    required this.a,
    required this.b,
  });
}

/* ============================================================
   UKURASA
   ============================================================ */
class MatchView extends StatefulWidget {
  final List<MatchPair> pairs;
  final Set<String> starredIds;
  final void Function(MatchPair pair, bool starred)? onStar;
  final int pageSize;
  final bool live;

  const MatchView({
    super.key,
    required this.pairs,
    this.starredIds = const {},
    this.onStar,
    this.pageSize = 20,
    this.live = true,
  });

  @override
  State<MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<MatchView> {
  static const _all = '__all__';

  final _scroll = ScrollController();
  final _qCtrl = TextEditingController();
  final _sCtrl = TextEditingController();

  String? idara;
  String? kada;
  int page = 0;
  late Set<String> starred = {...widget.starredIds};

  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(() => setState(() => page = 0));
    _sCtrl.addListener(() => setState(() => page = 0));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _qCtrl.dispose();
    _sCtrl.dispose();
    super.dispose();
  }

  /* ---------- Data ---------- */
  List<String> get _idaraOptions {
    const order = ['afya', 'elimu', 'kilimo', 'umma'];
    final keys = widget.pairs.map((p) => _idaraKey(p.idara)).toSet();
    final sorted = order.where(keys.contains).toList();
    sorted.addAll(keys.where((k) => !order.contains(k)));
    return sorted;
  }

  List<String> get _kadaOptions {
    final list = widget.pairs
        .where((p) => idara == null || _idaraKey(p.idara) == idara)
        .map((p) => p.kada)
        .toSet()
        .toList()
      ..sort();
    return list;
  }

  List<MatchPair> get _filtered {
    final q = _norm(_qCtrl.text);
    final qs = _norm(_sCtrl.text);
    return widget.pairs.where((m) {
      if (idara != null && _idaraKey(m.idara) != idara) return false;
      if (kada != null && m.kada != kada) return false;
      if (q.isNotEmpty && !_matches(_haystack(m), q)) return false;
      if (qs.isNotEmpty && !_subjectHay(m).contains(qs)) return false;
      return true;
    }).toList();
  }

  static String _norm(String s) => s.trim().toLowerCase();

  static bool _matches(String hay, String q) =>
      hay.contains(q) ||
      (q.startsWith('0') && q.length > 1 && hay.contains(q.substring(1)));

  static String _haystack(MatchPair m) {
    String person(MatchPerson p) => [
          p.name,
          p.phone,
          _digits(p.phone),
          p.fromMkoa,
          p.fromWilaya,
          ...p.destinations.expand((d) => [d.mkoa, d.wilaya ?? '']),
        ].join(' ');
    return '${m.kada} ${person(m.a)} ${person(m.b)}'.toLowerCase();
  }

  static String _subjectHay(MatchPair m) =>
      [...m.a.subjects, ...m.b.subjects, ...m.matchedSubjects]
          .expand((s) => [s, subjectLabel(s)])
          .join(' ')
          .toLowerCase();

  void _setPage(int p) {
    setState(() => page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _pickIdara() async {
    final v = await _sheet(
      title: 'Chagua idara',
      allLabel: 'Idara zote',
      icon: TablerIcons.building,
      options: [for (final k in _idaraOptions) (k, _idaraInfo(k).label)],
      current: idara,
    );
    if (v == null) return;
    setState(() {
      final next = v == _all ? null : v;
      if (next != idara) kada = null;
      idara = next;
      if (idara != 'elimu') _sCtrl.clear();
      page = 0;
    });
  }

  Future<void> _pickKada() async {
    final v = await _sheet(
      title: 'Chagua kada',
      allLabel: 'Kada zote',
      icon: TablerIcons.idBadge2,
      options: [for (final k in _kadaOptions) (k, k)],
      current: kada,
    );
    if (v == null) return;
    setState(() {
      kada = v == _all ? null : v;
      page = 0;
    });
  }

  Future<String?> _sheet({
    required String title,
    required String allLabel,
    required IconData icon,
    required List<(String, String)> options,
    String? current,
  }) {
    final c = _XC.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _PickerSheet(
        c: c,
        title: title,
        icon: icon,
        options: [(_all, allLabel), ...options],
        current: current ?? _all,
      ),
    );
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = _XC.of(context);
    final list = _filtered;
    final pages = (list.length / widget.pageSize).ceil().clamp(1, 100000);
    final p = page.clamp(0, pages - 1);
    final slice =
        list.skip(p * widget.pageSize).take(widget.pageSize).toList();

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _header(c, list.length),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _FilterBtn(
              c: c,
              icon: TablerIcons.building,
              label: idara == null ? 'Idara zote' : _idaraInfo(idara!).label,
              active: idara != null,
              onTap: _pickIdara,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterBtn(
              c: c,
              icon: TablerIcons.idBadge2,
              label: kada ?? 'Kada zote',
              active: kada != null,
              onTap: _pickKada,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _SearchBox(
            c: c,
            controller: _qCtrl,
            icon: TablerIcons.search,
            hint: 'Tafuta kwa jina, namba, kada au mkoa…'),
        if (idara == 'elimu') ...[
          const SizedBox(height: 8),
          _SearchBox(
              c: c,
              controller: _sCtrl,
              icon: TablerIcons.book2,
              hint: 'Somo, mf. Kemia'),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
          child: Text('Inaonyesha ${slice.length} kati ya ${list.length}',
              style: TextStyle(color: c.muted, fontSize: 12)),
        ),
        if (slice.isEmpty)
          _empty(c)
        else
          for (final m in slice)
            _PairCard(
              c: c,
              pair: m,
              starred: starred.contains(m.id),
              onStar: () {
                final on = !starred.contains(m.id);
                setState(
                    () => on ? starred.add(m.id) : starred.remove(m.id));
                widget.onStar?.call(m, on);
              },
            ),
        if (slice.isNotEmpty && pages > 1) _pager(c, p, pages),
      ],
    );
  }

  Widget _header(_XC c, int count) => Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: c.greenBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(TablerIcons.arrowsExchange, size: 21, color: c.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Match za kweli',
                      style: TextStyle(
                          color: c.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  Text('$count match zilizopatikana',
                      style: TextStyle(color: c.muted, fontSize: 12)),
                ]),
          ),
          if (widget.live)
            _Pill(
                label: 'Live',
                icon: TablerIcons.sparkles,
                fg: c.green,
                bg: c.greenBg,
                size: 12,
                vpad: 4,
                hpad: 10),
        ],
      );

  Widget _empty(_XC c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: c.blueBg, shape: BoxShape.circle),
            child: Icon(TablerIcons.searchOff, size: 26, color: c.blue),
          ),
          const SizedBox(height: 10),
          Text('Hakuna match',
              style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Jaribu kubadilisha vichujio',
              style: TextStyle(color: c.muted, fontSize: 12)),
        ]),
      );

  Widget _pager(_XC c, int p, int pages) {
    final shown = pages < 5 ? pages : 5;
    final start = (p - 2).clamp(0, pages - shown);

    Widget circle(
            {required Widget child,
            VoidCallback? onTap,
            bool on = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: on ? c.blue : c.card,
            shape: CircleBorder(
                side: BorderSide(color: on ? c.blue : c.borderStrong)),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Opacity(
                opacity: onTap == null && !on ? .4 : 1,
                child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(child: child)),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          circle(
            child: Icon(TablerIcons.chevronLeft, size: 16, color: c.text),
            onTap: p > 0 ? () => _setPage(p - 1) : null,
          ),
          for (var i = start; i < start + shown; i++)
            circle(
              on: i == p,
              onTap: i == p ? null : () => _setPage(i),
              child: Text('${i + 1}',
                  style: TextStyle(
                      color: i == p ? Colors.white : c.text,
                      fontSize: 13,
                      fontWeight:
                          i == p ? FontWeight.w600 : FontWeight.w400)),
            ),
          circle(
            child: Icon(TablerIcons.chevronRight, size: 16, color: c.text),
            onTap: p < pages - 1 ? () => _setPage(p + 1) : null,
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   KADI YA MATCH
   ============================================================ */
class _PairCard extends StatelessWidget {
  final _XC c;
  final MatchPair pair;
  final bool starred;
  final VoidCallback onStar;

  const _PairCard(
      {required this.c,
      required this.pair,
      required this.starred,
      required this.onStar});

  @override
  Widget build(BuildContext context) {
    final m = pair;
    final (gradeLabel, gFg, gBg) = m.score >= 100
        ? ('SAHIHI', c.green, c.greenBg)
        : m.score >= 80
            ? ('NZURI', c.blue, c.blueBg)
            : ('KIASI', c.amber, c.amberBg);
    final info = _idaraInfo(m.idara);
    final (iFg, iBg) = c.tone(info.tone);
    final teacher = _idaraKey(m.idara) == 'elimu';
    final hit = m.matchedSubjects.map((s) => s.toUpperCase()).toSet();
    final top = m.score >= 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: top ? c.green : c.border, width: top ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // a. kiduara + daraja + nyota
          Row(children: [
            _ScoreRing(
                score: m.score, color: gFg, track: c.border, text: c.text),
            const SizedBox(width: 10),
            _Pill(
                label: gradeLabel,
                fg: gFg,
                bg: gBg,
                size: 12,
                vpad: 4,
                hpad: 11,
                spacing: .4),
            const Spacer(),
            InkWell(
              onTap: onStar,
              customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(
                  starred ? TablerIcons.starFilled : TablerIcons.star,
                  size: 20,
                  color: starred ? c.star : c.muted,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // b. idara + kada
          Row(children: [
            _Pill(
                label: info.label,
                icon: info.icon,
                fg: iFg,
                bg: iBg,
                size: 12),
            const SizedBox(width: 8),
            Expanded(
                child: Text(m.kada,
                    style: TextStyle(color: c.text, fontSize: 13))),
          ]),

          // c. masomo yanayofanana (bila tick, bluu)
          if (teacher && m.matchedSubjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: c.blueBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Masomo yanayofanana:',
                      style: TextStyle(
                          color: c.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  for (final s in m.matchedSubjects)
                    _Pill(
                        label: subjectLabel(s),
                        fg: Colors.white,
                        bg: c.blue,
                        size: 11),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // d. watu wawili
          _PersonBlock(c: c, p: m.a, teacher: teacher, hit: hit),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: _Dashed(color: c.borderStrong)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _Pill(
                  label: 'KUBADILISHANA',
                  icon: TablerIcons.arrowsExchange,
                  fg: c.green,
                  bg: c.greenBg,
                  border: c.green.withValues(alpha: .5),
                  spacing: .5,
                ),
              ),
              Expanded(child: _Dashed(color: c.borderStrong)),
            ]),
          ),
          _PersonBlock(c: c, p: m.b, teacher: teacher, hit: hit),
        ],
      ),
    );
  }
}

/* ============================================================
   KIZUIZI CHA MTU — tiketi-style na _MXRail
   ============================================================ */
class _PersonBlock extends StatelessWidget {
  final _XC c;
  final MatchPerson p;
  final bool teacher;
  final Set<String> hit;

  const _PersonBlock(
      {required this.c,
      required this.p,
      required this.teacher,
      required this.hit});

  void _openDests(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _MXDestSheet(c: c, p: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dests = p.destinations;
    final first = dests.isEmpty ? null : dests.first;
    final more = dests.length - 1;
    final tap = more > 0;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Jina + avatar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: c.blueBg, shape: BoxShape.circle),
                child: Text(_initials(p.name),
                    style: TextStyle(
                        color: c.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_titleName(p.name),
                    style: TextStyle(
                        color: c.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25)),
              ),
              const SizedBox(width: 6),
              p.paid
                  ? _Pill(
                      label: 'Amelipa',
                      icon: TablerIcons.circleCheck,
                      fg: c.green,
                      bg: c.greenBg)
                  : _Pill(
                      label: 'Hajalipa',
                      icon: TablerIcons.circleX,
                      fg: c.red,
                      bg: c.redBg),
            ]),
          ),

          // Mstari wa tiketi wenye notch
          _MXCut(c: c),

          // Safari: ANATOKA → ANATAKA KUJA
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MXRail(c: c, hollow: true, line: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ANATOKA', style: _lbl(c)),
                              const SizedBox(height: 2),
                              Text(_place(p.fromMkoa),
                                  style: TextStyle(
                                      color: c.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              Text(_place(p.fromWilaya),
                                  style:
                                      TextStyle(color: c.muted, fontSize: 12)),
                            ]),
                      ),
                    ]),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: tap ? () => _openDests(context) : null,
                borderRadius: BorderRadius.circular(10),
                child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MXRail(c: c, hollow: false, line: false),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('ANATAKA KUJA', style: _lbl(c)),
                                    const SizedBox(height: 2),
                                    Text(
                                        first == null
                                            ? '-'
                                            : _place(first.mkoa),
                                        style: TextStyle(
                                            color: c.text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        first?.wilaya == null
                                            ? 'Wilaya yoyote'
                                            : _place(first!.wilaya!),
                                        style: TextStyle(
                                            color: c.muted, fontSize: 12)),
                                  ]),
                            ),
                            if (tap) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.fromLTRB(11, 4, 8, 4),
                                decoration: BoxDecoration(
                                    color: c.blueBg,
                                    borderRadius:
                                        BorderRadius.circular(999)),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('+$more zaidi',
                                          style: TextStyle(
                                              color: c.blue,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 2),
                                      Icon(TablerIcons.chevronRight,
                                          size: 12, color: c.blue),
                                    ]),
                              ),
                            ],
                          ]),
                        ),
                      ]),
                ),
              ),
            ]),
          ),

          // Masomo (Elimu tu)
          if (teacher && p.subjects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final s in p.subjects)
                    hit.contains(s.toUpperCase())
                        ? _Pill(
                            label: subjectLabel(s),
                            fg: c.blue,
                            bg: c.blueBg,
                            size: 11)
                        : _Pill(
                            label: subjectLabel(s),
                            fg: c.muted,
                            bg: c.soft,
                            border: c.borderStrong,
                            size: 11),
                ],
              ),
            ),

          // Vitufe vya mawasiliano
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border))),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextButton(
                    onPressed: () => launchUrl(
                        Uri(scheme: 'tel', path: '+${_intl(p.phone)}')),
                    style: TextButton.styleFrom(
                      backgroundColor: c.blueBg,
                      foregroundColor: c.blue,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(TablerIcons.phone, size: 16),
                        const SizedBox(width: 6),
                        Text(_prettyPhone(p.phone)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                height: 34,
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                        'https://wa.me/${_intl(p.whatsapp ?? p.phone)}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: c.greenBg,
                    foregroundColor: c.green,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Icon(TablerIcons.brandWhatsapp, size: 18),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  static TextStyle _lbl(_XC c) => TextStyle(
      color: c.muted,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: .8);
}

/* ============================================================
   VIPANDE VIDOGO
   ============================================================ */
class _ScoreRing extends StatelessWidget {
  final int score;
  final Color color, track, text;
  const _ScoreRing(
      {required this.score,
      required this.color,
      required this.track,
      required this.text});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: (score.clamp(0, 100)) / 100,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: track,
            ),
          ),
          Text('$score%',
              style: TextStyle(
                  color: text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;
  final Color? border;
  final double size, vpad, hpad, spacing;

  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.border,
    this.size = 11,
    this.vpad = 3,
    this.hpad = 9,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ic = icon == null ? null : Icon(icon, size: size, color: fg);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hpad, vertical: vpad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (ic != null) ...[ic, const SizedBox(width: 4)],
        Text(label,
            style: TextStyle(
                color: fg,
                fontSize: size,
                fontWeight: FontWeight.w600,
                letterSpacing: spacing)),
      ]),
    );
  }
}

class _FilterBtn extends StatelessWidget {
  final _XC c;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterBtn(
      {required this.c,
      required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: active ? c.blueBg : c.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? c.blue : c.borderStrong),
            ),
            child: Row(children: [
              Icon(icon, size: 17, color: c.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: active ? c.blue : c.text, fontSize: 13)),
              ),
              Icon(TablerIcons.chevronDown, size: 14, color: c.muted),
            ]),
          ),
        ),
      );
}

class _SearchBox extends StatelessWidget {
  final _XC c;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  const _SearchBox(
      {required this.c,
      required this.controller,
      required this.icon,
      required this.hint});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: controller,
      style: TextStyle(color: c.text, fontSize: 14),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: c.muted.withValues(alpha: .8), fontSize: 14),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        prefixIcon: Icon(icon, size: 17, color: c.muted),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

// Mstari wa vitone wa usawa (unaotumika kwenye KUBADILISHANA separator)
class _Dashed extends StatelessWidget {
  final Color color;
  const _Dashed({required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashPainter(color));
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 5.0, gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1),
          Offset((x + dash).clamp(0, size.width), 1), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

// Vitone vya usawa — katikati ya urefu (unaotumika kwenye _MXCut)
class _DashHPainter extends CustomPainter {
  final Color color;
  _DashHPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 5.0, gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y),
          Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashHPainter old) => old.color != color;
}

// Vitone vya wima (unaotumika kwenye _MXRail)
class _DashVPainter extends CustomPainter {
  final Color color;
  _DashVPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 4.0, gap = 3.5;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
          Offset(size.width / 2, y),
          Offset(size.width / 2, (y + dash).clamp(0, size.height)),
          paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashVPainter old) => old.color != color;
}

/// Mstari wa vitone wenye mashimo pembeni (tiketi-style) — kwa _PersonBlock.
class _MXCut extends StatelessWidget {
  final _XC c;
  const _MXCut({required this.c});

  @override
  Widget build(BuildContext context) {
    Widget notch() => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: c.card, shape: BoxShape.circle));
    return SizedBox(
      height: 18,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CustomPaint(painter: _DashHPainter(c.borderStrong)),
          ),
        ),
        Positioned(left: -10, top: 0, child: notch()),
        Positioned(right: -10, top: 0, child: notch()),
      ]),
    );
  }
}

/// Reli ya safari: duara tupu (anatoka) au duara la bluu (anataka kuja).
class _MXRail extends StatelessWidget {
  final _XC c;
  final bool hollow;
  final bool line;
  const _MXRail(
      {required this.c, required this.hollow, required this.line});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          top: 3,
          left: 0,
          child: hollow
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.muted, width: 2.5),
                  ),
                )
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: c.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: c.blueBg, spreadRadius: 3),
                    ],
                  ),
                ),
        ),
        if (line)
          Positioned(
            left: 5,
            top: 19,
            bottom: -17,
            child: SizedBox(
              width: 2,
              child: CustomPaint(painter: _DashVPainter(c.borderStrong)),
            ),
          ),
      ]),
    );
  }
}

/* ============================================================
   BOTTOM SHEET: MAENEO YOTE ANAYOTAKA KUJA
   ============================================================ */
class _MXDestSheet extends StatelessWidget {
  final _XC c;
  final MatchPerson p;
  const _MXDestSheet({required this.c, required this.p});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 10, 6),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: c.blueBg, shape: BoxShape.circle),
                  child: Text(_initials(p.name),
                      style: TextStyle(
                          color: c.blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_titleName(p.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        Text(
                            'Anatoka ${_place(p.fromMkoa)} · ${_place(p.fromWilaya)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: c.muted, fontSize: 12)),
                      ]),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(TablerIcons.x, size: 18, color: c.muted),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
              child: Text(
                  'ANATAKA KUJA · ${p.destinations.length}',
                  style: TextStyle(
                      color: c.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .8)),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: p.destinations.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: c.border),
                itemBuilder: (_, i) {
                  final d = p.destinations[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: c.blue, shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_place(d.mkoa),
                                  style: TextStyle(
                                      color: c.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  d.wilaya == null
                                      ? 'Wilaya yoyote'
                                      : _place(d.wilaya!),
                                  style: TextStyle(
                                      color: c.muted, fontSize: 12)),
                            ]),
                      ),
                      if (i == 0)
                        _Pill(
                            label: 'Chaguo la kwanza',
                            fg: c.blue,
                            bg: c.blueBg),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   BOTTOM SHEET YA KUCHAGUA (idara / kada)
   ============================================================ */
class _PickerSheet extends StatefulWidget {
  final _XC c;
  final String title;
  final IconData icon;
  final List<(String, String)> options;
  final String current;

  const _PickerSheet({
    required this.c,
    required this.title,
    required this.icon,
    required this.options,
    required this.current,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final list = widget.options
        .where((o) => o.$2.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 10, 8),
              child: Row(children: [
                Expanded(
                  child: Text(widget.title,
                      style: TextStyle(
                          color: c.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(TablerIcons.x, size: 18, color: c.muted),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                style: TextStyle(color: c.text, fontSize: 14),
                cursorColor: c.blue,
                decoration: InputDecoration(
                  hintText: 'Tafuta…',
                  hintStyle: TextStyle(color: c.muted, fontSize: 14),
                  prefixIcon:
                      Icon(TablerIcons.search, size: 17, color: c.muted),
                  isDense: true,
                  filled: true,
                  fillColor: c.soft,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: [
                  for (final (value, label) in list)
                    Builder(builder: (_) {
                      final on = value == widget.current;
                      return InkWell(
                        onTap: () => Navigator.pop(context, value),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: on ? c.blueBg : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Icon(widget.icon, size: 17, color: c.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(label,
                                  style: TextStyle(
                                      color: on ? c.blue : c.text,
                                      fontSize: 14,
                                      fontWeight: on
                                          ? FontWeight.w600
                                          : FontWeight.w400)),
                            ),
                            if (on)
                              Icon(TablerIcons.check,
                                  size: 17, color: c.blue),
                          ]),
                        ),
                      );
                    }),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Hakuna kinacholingana',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: c.muted, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================================================
   MSAIDIZI: IDARA, MASOMO, MAJINA, SIMU
   ============================================================ */
enum _Tone { blue, green, amber }

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
      return (
        label: 'Afya',
        icon: TablerIcons.heartRateMonitor,
        tone: _Tone.green
      );
    case 'elimu':
      return (
        label: 'Elimu',
        icon: TablerIcons.school,
        tone: _Tone.blue
      );
    case 'kilimo':
      return (
        label: 'Kilimo na ufugaji',
        icon: TablerIcons.plant2,
        tone: _Tone.green
      );
    case 'umma':
      return (
        label: 'Watumishi wa umma',
        icon: TablerIcons.buildingBank,
        tone: _Tone.amber
      );
    default:
      return (label: raw, icon: TablerIcons.briefcase, tone: _Tone.blue);
  }
}

const _subjectNames = <String, String>{
  'MATH': 'Mathematics',
  'GEO': 'Geography',
  'CHEM': 'Chemistry',
  'BIO': 'Biology',
  'PHY': 'Physics',
  'PHYS': 'Physics',
  'KISW': 'Kiswahili',
  'KISWAH': 'Kiswahili',
  'KISWAHILI': 'Kiswahili',
  'ENG': 'English',
  'KING': 'English',
  'ENGLISH': 'English',
  'HIST': 'History',
  'HISTORIA': 'History',
  'HISTMAADILI': 'History & Ethics',
  'CIV': 'Civics',
  'URAIA': 'Civics',
  'COMP': 'Computer Studies',
  'ICT': 'ICT',
  'COMM': 'Commerce',
  'BOOK': 'Book-Keeping',
  'ACC': 'Accounting',
  'AGRI': 'Agriculture',
  'FRE': 'French',
  'ARB': 'Arabic',
};

String subjectLabel(String raw) {
  final key = raw.trim().toUpperCase();
  final hit = _subjectNames[key];
  if (hit != null) return hit;
  final t = raw.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

String _place(String s) {
  const upper = {'DC', 'TC', 'MC', 'CC', 'HC'};
  const lower = {'es', 'na', 'ya', 'wa'};
  return s.trim().split(RegExp(r'\s+')).map((w) {
    final bare = w.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (upper.contains(bare)) return w.toUpperCase();
    if (lower.contains(w.toLowerCase())) return w.toLowerCase();
    final i = w.indexOf(RegExp(r'[A-Za-z]'));
    if (i < 0) return w;
    return w.substring(0, i) +
        w[i].toUpperCase() +
        w.substring(i + 1).toLowerCase();
  }).join(' ');
}

String _titleName(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) =>
        w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

String _initials(String n) => n
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

String _local9(String p) {
  var d = _digits(p);
  if (d.startsWith('255')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  return d;
}

String _intl(String p) => '255${_local9(p)}';

String _prettyPhone(String p) {
  final l = _local9(p);
  if (l.length != 9) return p;
  return '+255 ${l.substring(0, 3)} ${l.substring(3, 6)} ${l.substring(6)}';
}

/* ============================================================
   RANGI
   ============================================================ */
class _XC {
  final Color card, soft, border, borderStrong, text, muted;
  final Color blue,
      blueBg,
      green,
      greenBg,
      greenStrong,
      amber,
      amberBg,
      red,
      redBg,
      star;

  const _XC({
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
    required this.greenStrong,
    required this.amber,
    required this.amberBg,
    required this.red,
    required this.redBg,
    required this.star,
  });

  static const light = _XC(
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
    greenStrong: Color(0xFF0F7A52),
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFFFFF1D6),
    red: Color(0xFFC62828),
    redBg: Color(0xFFFDECEC),
    star: Color(0xFFF59E0B),
  );

  static const dark = _XC(
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
    greenStrong: Color(0xFF1E8F63),
    amber: Color(0xFFF0B35A),
    amberBg: Color(0xFF3A2C14),
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
    star: Color(0xFFFBBF24),
  );

  static _XC of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}
