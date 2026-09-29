// =============================================================================
// wenzao_view.dart
// Ukurasa wa ADMIN: "Waliopata wenzao" (watu waliounganishwa na wenzao).
// Ni sehemu ya katikati (body) tu. Upau wa juu na menyu ya chini ya admin
// HAZIGUSWI, zinabaki kama zilivyo. Kwenye menyu ya chini, "Wenzao" ndiyo
// iliyochaguliwa (kijani).
//
// Packages: tabler_icons_plus, url_launcher
// =============================================================================

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/* ============================================================
   MODELS
   ============================================================ */
class WenzaoDestination {
  final String mkoa;
  final String? wilaya; // null = wilaya yoyote
  const WenzaoDestination({required this.mkoa, this.wilaya});
}

class WenzaoPerson {
  final String id;
  final String name;
  final bool paid;
  final String idara; // afya / elimu / kilimo / umma (au health / education)
  final String kada;
  final String fromMkoa;
  final String fromWilaya;

  /// Kwa mpangilio wa kipaumbele: la kwanza ndilo chaguo la kwanza.
  final List<WenzaoDestination> destinations;
  final String phone;
  final String? whatsapp;

  const WenzaoPerson({
    required this.id,
    required this.name,
    required this.paid,
    required this.idara,
    required this.kada,
    required this.fromMkoa,
    required this.fromWilaya,
    required this.destinations,
    required this.phone,
    this.whatsapp,
  });
}

/* ============================================================
   UKURASA
   ============================================================ */
class WenzaoView extends StatefulWidget {
  final List<WenzaoPerson> people;
  final int pageSize;
  final bool live;

  const WenzaoView({
    super.key,
    required this.people,
    this.pageSize = 10,
    this.live = true,
  });

  @override
  State<WenzaoView> createState() => _WenzaoViewState();
}

class _WenzaoViewState extends State<WenzaoView> {
  static const _all = '__all__';

  final _scroll = ScrollController();
  final _qCtrl = TextEditingController();

  String? region; // mkoa wa lengo, null = yote
  String? idara; // null = zote
  int page = 0;

  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(() => setState(() => page = 0));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  /* ---------- Data ---------- */
  List<String> get _regionOptions {
    final s = widget.people
        .expand((p) => p.destinations.map((d) => d.mkoa))
        .map(_place)
        .toSet()
        .toList()
      ..sort();
    return s;
  }

  List<String> get _idaraOptions {
    const order = ['afya', 'elimu', 'kilimo', 'umma'];
    final keys = widget.people.map((p) => _idaraKey(p.idara)).toSet();
    final sorted = order.where(keys.contains).toList();
    sorted.addAll(keys.where((k) => !order.contains(k)));
    return sorted;
  }

  List<WenzaoPerson> get _filtered {
    final q = _qCtrl.text.trim().toLowerCase();
    return widget.people.where((p) {
      if (idara != null && _idaraKey(p.idara) != idara) return false;
      if (region != null &&
          !p.destinations.any((d) => _place(d.mkoa) == region)) {
        return false;
      }
      if (q.isNotEmpty && !_matches(_haystack(p), q)) return false;
      return true;
    }).toList();
  }

  static bool _matches(String hay, String q) =>
      hay.contains(q) ||
      (q.startsWith('0') && q.length > 1 && hay.contains(q.substring(1)));

  static String _haystack(WenzaoPerson p) => [
        p.name,
        p.phone,
        _digits(p.phone),
        p.kada,
        p.fromMkoa,
        p.fromWilaya,
        ...p.destinations.expand((d) => [d.mkoa, d.wilaya ?? '']),
      ].join(' ').toLowerCase();

  void _setPage(int p) {
    setState(() => page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _pickRegion() async {
    final v = await _sheet(
      title: 'Chagua mkoa wa lengo',
      allLabel: 'Mikoa yote',
      allIcon: TablerIcons.map2,
      options: [
        for (final r in _regionOptions) (r, r, TablerIcons.mapPin),
      ],
      current: region,
    );
    if (v == null) return;
    setState(() {
      region = v == _all ? null : v;
      page = 0;
    });
  }

  Future<void> _pickIdara() async {
    final v = await _sheet(
      title: 'Chagua idara',
      allLabel: 'Idara zote',
      allIcon: TablerIcons.layoutGrid,
      options: [
        for (final k in _idaraOptions)
          (k, _idaraInfo(k).label, _idaraInfo(k).icon),
      ],
      current: idara,
    );
    if (v == null) return;
    setState(() {
      idara = v == _all ? null : v;
      page = 0;
    });
  }

  Future<String?> _sheet({
    required String title,
    required String allLabel,
    required IconData allIcon,
    required List<(String, String, IconData)> options,
    String? current,
  }) {
    final c = _PC.of(context);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _PickerSheet(
        c: c,
        title: title,
        options: [(_all, allLabel, allIcon), ...options],
        current: current ?? _all,
      ),
    );
  }

  void _openDestinations(WenzaoPerson p) {
    final c = _PC.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _DestSheet(c: c, p: p),
    );
  }

  /* ---------- UI ---------- */
  @override
  Widget build(BuildContext context) {
    final c = _PC.of(context);
    final list = _filtered;
    final pages = (list.length / widget.pageSize).ceil().clamp(1, 100000);
    final pg = page.clamp(0, pages - 1);
    final slice =
        list.skip(pg * widget.pageSize).take(widget.pageSize).toList();

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
              icon: TablerIcons.map2,
              label: region ?? 'Mkoa wa lengo',
              active: region != null,
              onTap: _pickRegion,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterBtn(
              c: c,
              icon: TablerIcons.building,
              label: idara == null ? 'Idara zote' : _idaraInfo(idara!).label,
              active: idara != null,
              onTap: _pickIdara,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _SearchBox(
            c: c,
            controller: _qCtrl,
            hint: 'Tafuta kwa jina, namba, kada au wilaya'),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
          child: Text('Inaonyesha ${slice.length} kati ya ${list.length}',
              style: TextStyle(color: c.muted, fontSize: 12)),
        ),
        if (slice.isEmpty)
          _empty(c)
        else
          for (final p in slice)
            _Ticket(
                c: c, p: p, onDestinations: () => _openDestinations(p)),
        if (slice.isNotEmpty && pages > 1) _pager(c, pg, pages),
      ],
    );
  }

  Widget _header(_PC c, int count) => Row(
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Waliopata wenzao',
                  style: TextStyle(
                      color: c.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              Text('$count watu wamepata wenzao',
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

  Widget _empty(_PC c) => Container(
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
            child: Icon(TablerIcons.searchOff, size: 26, color: c.blue),
          ),
          const SizedBox(height: 10),
          Text('Hakuna waliopatikana',
              style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Jaribu kubadilisha vichujio',
              style: TextStyle(color: c.muted, fontSize: 12)),
        ]),
      );

  Widget _pager(_PC c, int p, int pages) {
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
                side: BorderSide(
                    color: on ? c.blue : c.borderStrong)),
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
                      fontWeight: i == p
                          ? FontWeight.w600
                          : FontWeight.w400)),
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
   KADI YA TIKETI
   ============================================================ */
class _Ticket extends StatelessWidget {
  final _PC c;
  final WenzaoPerson p;
  final VoidCallback onDestinations;

  const _Ticket(
      {required this.c,
      required this.p,
      required this.onDestinations});

  @override
  Widget build(BuildContext context) {
    final info = _idaraInfo(p.idara);
    final (fg, bg) = c.tone(info.tone);
    final dests = p.destinations;
    final first = dests.isEmpty ? null : dests.first;
    final more = dests.length - 1;
    final tap = more > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // a. juu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Text(_initials(p.name),
                    style: TextStyle(
                        color: fg,
                        fontSize: 14,
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
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(info.icon, size: 13, color: fg),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(p.kada,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: c.muted, fontSize: 12)),
                        ),
                      ]),
                    ]),
              ),
              const SizedBox(width: 8),
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

          // b. mstari wa vitone wenye mashimo
          _Cut(c: c),

          // c. safari wima
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Rail(c: c, hollow: true, line: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('ANATOKA', style: _Ticket._label(c)),
                              const SizedBox(height: 1),
                              Text(_place(p.fromMkoa),
                                  style: TextStyle(
                                      color: c.text,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                              Text(_place(p.fromWilaya),
                                  style: TextStyle(
                                      color: c.muted, fontSize: 12)),
                            ]),
                      ),
                    ]),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: tap ? onDestinations : null,
                borderRadius: BorderRadius.circular(10),
                child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Rail(c: c, hollow: false, line: false),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('ANATAKA KUJA',
                                        style: _Ticket._label(c)),
                                    const SizedBox(height: 1),
                                    Text(
                                        first == null
                                            ? '-'
                                            : _place(first.mkoa),
                                        style: TextStyle(
                                            color: c.text,
                                            fontSize: 17,
                                            fontWeight:
                                                FontWeight.w600)),
                                    Text(
                                        first?.wilaya == null
                                            ? 'Wilaya yoyote'
                                            : _place(first!.wilaya!),
                                        style: TextStyle(
                                            color: c.muted,
                                            fontSize: 12)),
                                  ]),
                            ),
                            if (tap) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                    11, 4, 8, 4),
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
                                              fontWeight:
                                                  FontWeight.w600)),
                                      const SizedBox(width: 2),
                                      Icon(
                                          TablerIcons.chevronRight,
                                          size: 12,
                                          color: c.blue),
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

          // d. mawasiliano
          Container(
            padding:
                const EdgeInsets.fromLTRB(14, 10, 14, 14),
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
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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

  static TextStyle _label(_PC c) => TextStyle(
      color: c.muted,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: .8);
}

/// Mstari wa vitone wenye mashimo mawili pembeni (kama tiketi).
class _Cut extends StatelessWidget {
  final _PC c;
  const _Cut({required this.c});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    Widget notch() => Container(
        width: 18,
        height: 18,
        decoration:
            BoxDecoration(color: bg, shape: BoxShape.circle));
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
      canvas.drawLine(Offset(x, y),
          Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashH old) => old.color != color;
}

class _DashV extends CustomPainter {
  final Color color;
  _DashV(this.color);

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
  bool shouldRepaint(covariant _DashV old) => old.color != color;
}

/// Reli ya safari: duara tupu (anatoka) au duara la bluu (anataka kuja),
/// pamoja na mstari wa vitone unaoshuka hadi duara la pili.
class _Rail extends StatelessWidget {
  final _PC c;
  final bool hollow;
  final bool line;
  const _Rail(
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
                      BoxShadow(color: c.blueBg, spreadRadius: 3)
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
              child: CustomPaint(painter: _DashV(c.borderStrong)),
            ),
          ),
      ]),
    );
  }
}

/* ============================================================
   BOTTOM SHEET: MAENEO YOTE ANAYOTAKA KUJA
   ============================================================ */
class _DestSheet extends StatelessWidget {
  final _PC c;
  final WenzaoPerson p;
  const _DestSheet({required this.c, required this.p});

  @override
  Widget build(BuildContext context) {
    final info = _idaraInfo(p.idara);
    final (fg, bg) = c.tone(info.tone);
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
                      BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Text(_initials(p.name),
                      style: TextStyle(
                          color: fg,
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
                            style: TextStyle(
                                color: c.muted, fontSize: 12)),
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
                    child:
                        Icon(TablerIcons.x, size: 18, color: c.muted),
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
                separatorBuilder: (context2, idx) =>
                    Divider(height: 1, color: c.border),
                itemBuilder: (_, i) {
                  final d = p.destinations[i];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
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
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
   BOTTOM SHEET YA KUCHAGUA (mkoa / idara)
   ============================================================ */
class _PickerSheet extends StatefulWidget {
  final _PC c;
  final String title;
  final List<(String, String, IconData)> options; // (thamani, jina, icon)
  final String current;

  const _PickerSheet({
    required this.c,
    required this.title,
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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    child:
                        Icon(TablerIcons.x, size: 18, color: c.muted),
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
                  hintStyle:
                      TextStyle(color: c.muted, fontSize: 14),
                  prefixIcon: Icon(TablerIcons.search,
                      size: 17, color: c.muted),
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
                  for (final (value, label, icon) in list)
                    Builder(builder: (_) {
                      final on = value == widget.current;
                      return InkWell(
                        onTap: () => Navigator.pop(context, value),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: on ? c.blueBg : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: on ? c.card : c.soft,
                                borderRadius:
                                    BorderRadius.circular(9),
                              ),
                              child: Icon(icon,
                                  size: 16,
                                  color: on ? c.blue : c.muted),
                            ),
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
                          style: TextStyle(
                              color: c.muted, fontSize: 13)),
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
   VIPANDE VIDOGO
   ============================================================ */
class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fg, bg;
  final double size, vpad, hpad;

  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.size = 11,
    this.vpad = 3,
    this.hpad = 9,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: hpad, vertical: vpad),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: size, color: fg),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: TextStyle(
                  color: fg,
                  fontSize: size,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _FilterBtn extends StatelessWidget {
  final _PC c;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterBtn({
    required this.c,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

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
              border:
                  Border.all(color: active ? c.blue : c.borderStrong),
            ),
            child: Row(children: [
              Icon(icon, size: 17, color: c.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: active ? c.blue : c.text,
                        fontSize: 13)),
              ),
              Icon(TablerIcons.chevronDown, size: 14, color: c.muted),
            ]),
          ),
        ),
      );
}

class _SearchBox extends StatelessWidget {
  final _PC c;
  final TextEditingController controller;
  final String hint;
  const _SearchBox(
      {required this.c,
      required this.controller,
      required this.hint});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color col, [double w = 1]) =>
        OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: col, width: w));
    return TextField(
      controller: controller,
      style: TextStyle(color: c.text, fontSize: 14),
      cursorColor: c.blue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: c.muted.withValues(alpha: .8), fontSize: 14),
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        prefixIcon:
            Icon(TablerIcons.search, size: 17, color: c.muted),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        border: b(c.borderStrong),
        enabledBorder: b(c.borderStrong),
        focusedBorder: b(c.blue, 1.5),
      ),
    );
  }
}

/* ============================================================
   MSAIDIZI: IDARA, MAJINA, SIMU
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
        icon: TablerIcons.briefcase,
        tone: _Tone.amber
      );
    default:
      return (
        label: raw,
        icon: TablerIcons.briefcase,
        tone: _Tone.blue
      );
  }
}

String _place(String s) {
  const upper = {'DC', 'TC', 'MC', 'CC', 'HC'};
  const lower = {'es', 'na', 'ya', 'wa'};
  return s.trim().split(RegExp(r'\s+')).map((w) {
    final bare =
        w.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
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
    amber: Color(0xFF9A5B00),
    amberBg: Color(0xFF3A2C14),
    red: Color(0xFFFF8A8A),
    redBg: Color(0xFF3A1D1F),
  );

  static _PC of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  (Color, Color) tone(_Tone t) => switch (t) {
        _Tone.blue => (blue, blueBg),
        _Tone.green => (green, greenBg),
        _Tone.amber => (amber, amberBg),
      };
}
