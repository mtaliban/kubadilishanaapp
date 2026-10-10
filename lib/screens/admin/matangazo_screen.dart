// matangazo_screen.dart
// Skrini ya Matangazo: "Tangazo jipya" + "Historia" - nakala kamili ya muundo wa mwisho.
// Faili moja. Hakuna package ya ziada. Inahitaji Flutter 3.13+ (Dart 3).
//
// MATUMIZI:
//   final controller = MatangazoController(
//     items: itemsZaUkurasaWa1, total: 50, pages: 9,
//     audiences: [...],            // hiari, la sivyo zinatumika za msingi hapa chini
//   );
//   MatangazoScreen(controller: controller)
//
// KUUNGANISHA NA API: tengeneza class inayo-extend MatangazoController na ubadilishe
//   send / resend / delete / loadPage (piga API kisha notifyListeners()).
//
// ICON: zote zimewekwa sehemu moja (class MtIcons). Ni Material Icons zinazofanana
//   na seti 2 ya Tabler. Ukitaka Tabler halisi, ongeza package ya Tabler icons na
//   ubadilishe mistari ya MtIcons tu - hakuna kingine kinachohitaji kubadilishwa.

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart' show AppToast, friendlyError;

// ───────────────────────── RANGI ─────────────────────────
class _C {
  static const blue = Color(0xFF1A56DB);
  static const surface = Colors.white;
  static const border = Color(0xFFE3E6EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const text = Color(0xFF111827);
  static const text2 = Color(0xFF6B7280);
  static const muted = Color(0xFF9CA3AF);
  static const danger = Color(0xFFE5484D);
  static const dangerBg = Color(0xFFFDECEC);
  static const accentBg = Color(0xFFE8EEFC);
  static const successFg = Color(0xFF15803D);
  static const successBg = Color(0xFFDCFCE7);

  // ── DARK/LIGHT: getters zinazotumia Theme.of(context).brightness ────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color of(BuildContext context, Color light, Color darkDark) =>
      isDark(context) ? darkDark : light;

  // Dark variants (zinazosomeka)
  static const surfaceD = Color(0xFF1E293B);
  static const borderD = Color(0xFF2A3240);
  static const borderStrongD = Color(0xFF334155);
  static const textD = Color(0xFFE7ECF8);
  static const text2D = Color(0xFF9AA8C7);
  static const mutedD = Color(0xFF7B8DA5);
  static const accentBgD = Color(0xFF1C2A44);
  static const successFgD = Color(0xFF86EFAC);
  static const successBgD = Color(0xFF14532D);
}

// ───────────────────────── ICON (mahali pamoja) ─────────────────────────
class MtIcons {
  // Icon ya matangazo — ile ile ya drawer (bell-ringing ya Tabler).
  static const campaign = TablerIcons.bell_ringing;
  static const campaignOff = Icons.volume_off_outlined; // speakerphone-off
  // "Tangazo jipya" — Phosphor (kalamu).
  static const compose = PhosphorIconsRegular.pencilSimpleLine;
  static const history = Icons.history; // history
  static const info = Icons.info_outline; // info-circle
  static const warning = Icons.warning_amber_rounded; // alert-triangle
  static const success = Icons.check_circle_outline; // circle-check
  // Wasikilizaji (watu) — style ya drawer (Tabler).
  static const groups = TablerIcons.users_group; // Wote
  static const afya = TablerIcons.stethoscope; // Afya
  static const elimu = TablerIcons.school; // Elimu
  static const kilimo = TablerIcons.plant_2; // Kilimo na ufugaji
  static const umma = TablerIcons.building_community; // Watumishi wa Umma
  static const person = TablerIcons.user; // Mtu mmoja
  static const send = Icons.send_rounded; // brand-telegram
  // "Tuma tena" — Phosphor (rotate-clockwise).
  static const revert = PhosphorIconsRegular.arrowsClockwise;
  static const trash = Icons.delete_outline; // trash
  static const calendar = Icons.calendar_month_outlined; // calendar-month
  static const check = Icons.check_rounded;
  static const close = Icons.close_rounded;
  static const plus = Icons.add_rounded;
  static const error = Icons.error_outline;
  static const prev = Icons.chevron_left_rounded;
  static const next = Icons.chevron_right_rounded;
}

// ───────────────────────── MODELS ─────────────────────────
enum TangazoType { taarifa, onyo, mafanikio }

extension TangazoTypeX on TangazoType {
  String get label => switch (this) {
        TangazoType.taarifa => 'Taarifa',
        TangazoType.onyo => 'Onyo',
        TangazoType.mafanikio => 'Mafanikio',
      };
  IconData get icon => switch (this) {
        TangazoType.taarifa => MtIcons.info,
        TangazoType.onyo => MtIcons.warning,
        TangazoType.mafanikio => MtIcons.success,
      };
  Color get fg => switch (this) {
        TangazoType.taarifa => _C.blue,
        TangazoType.onyo => const Color(0xFFB45309),
        TangazoType.mafanikio => _C.of(context, _C.successFg, _C.successFgD),
      };
  Color get bg => switch (this) {
        TangazoType.taarifa => _C.of(context, _C.accentBg, _C.accentBgD),
        TangazoType.onyo => const Color(0xFFFEF3C7),
        TangazoType.mafanikio => _C.of(context, _C.successBg, _C.successBgD),
      };
}

class Tangazo {
  final String id;
  final String title;
  final TangazoType type;
  final DateTime date;
  final String message;
  const Tangazo({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.message,
  });
}

class AudienceOption {
  final String id; // 'all' na 'one' ni maalum
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const AudienceOption({
    required this.id,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });
}

/// Idadi (count) zibadilishwe na data halisi kutoka API yako.
const kDefaultAudiences = <AudienceOption>[
  AudienceOption(id: 'all', label: 'Wote', count: 1346, icon: MtIcons.groups, color: Color(0xFF378ADD)),
  AudienceOption(id: 'afya', label: 'Afya', count: 443, icon: MtIcons.afya, color: Color(0xFFD85A30)),
  AudienceOption(id: 'elimu', label: 'Elimu', count: 882, icon: MtIcons.elimu, color: Color(0xFF7F77DD)),
  AudienceOption(id: 'kilimo', label: 'Kilimo na ufugaji', count: 5, icon: MtIcons.kilimo, color: Color(0xFF639922)),
  AudienceOption(id: 'umma', label: 'Watumishi wa Umma', count: 9, icon: MtIcons.umma, color: Color(0xFFBA7517)),
  AudienceOption(id: 'one', label: 'Mtu mmoja', count: 1, icon: MtIcons.person, color: Color(0xFF888780)),
];

class TangazoDraft {
  final String title;
  final String message;
  final TangazoType type;
  final Set<String> audienceIds;
  final String? phone; // ikiwa 'one' imechaguliwa
  final int recipients;
  const TangazoDraft({
    required this.title,
    required this.message,
    required this.type,
    required this.audienceIds,
    required this.phone,
    required this.recipients,
  });
}

// ───────────────────────── CONTROLLER ─────────────────────────
class MatangazoController extends ChangeNotifier {
  List<Tangazo> items;
  int total;
  int page;
  int pages;
  List<AudienceOption> audiences;

  MatangazoController({
    List<Tangazo>? items,
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    List<AudienceOption>? audiences,
  })  : items = items ?? <Tangazo>[],
        audiences = audiences ?? kDefaultAudiences;

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Tuma tangazo jipya. Badilisha hapa kupiga API yako.
  Future<void> send(TangazoDraft d) async {
    page = 1;
    items.insert(
      0,
      Tangazo(
        id: _newId(),
        title: d.title.toUpperCase(),
        type: d.type,
        date: DateTime.now(),
        message: d.message,
      ),
    );
    total++;
    notifyListeners();
  }

  /// Tuma tena tangazo lililopita. Tangazo jipya linaingia juu ya historia.
  Future<void> resend(Tangazo t) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    page = 1;
    items.insert(
      0,
      Tangazo(
        id: _newId(),
        title: t.title,
        type: t.type,
        date: DateTime.now(),
        message: t.message,
      ),
    );
    total++;
    notifyListeners();
  }

  Future<void> delete(Tangazo t) async {
    items.removeWhere((x) => x.id == t.id);
    if (total > 0) total--;
    notifyListeners();
  }

  /// Badilisha ukurasa. Kwa API halisi: pakia items za ukurasa [p] hapa.
  Future<void> loadPage(int p) async {
    page = p.clamp(1, pages);
    notifyListeners();
  }
}

// ───────────────────────── TAREHE ─────────────────────────
const _monthsShort = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
const _monthsLong = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba'
];
String _dateLabel(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';
String _monthLabel(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';
String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// ═════════════════════════ SKRINI ═════════════════════════
class MatangazoScreen extends StatefulWidget {
  final MatangazoController controller;

  /// Wasikilizaji waliochaguliwa mwanzoni (kama kwenye muundo: Elimu, Kilimo, Watumishi wa Umma).
  final Set<String> initialAudience;

  const MatangazoScreen({
    super.key,
    required this.controller,
    this.initialAudience = const {'elimu', 'kilimo', 'umma'},
  });

  @override
  State<MatangazoScreen> createState() => _MatangazoScreenState();
}

class _MatangazoScreenState extends State<MatangazoScreen> {
  int _tab = 0; // 0 = Tangazo jipya, 1 = Historia
  TangazoType _type = TangazoType.taarifa;
  TangazoType? _filter; // null = Yote
  late Set<String> _aud;
  final _title = TextEditingController();
  final _msg = TextEditingController();
  final _phone = TextEditingController();
  String _err = '';
  String? _deleteId;
  String? _busyId; // tangazo linalotumwa tena (spinner)
  String? _okId; // tangazo jipya lililotumwa tena (tiki)
  String _banner = '';

  MatangazoController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _aud = {...widget.initialAudience};
    _title.addListener(_refresh);
    _msg.addListener(_refresh);
  }

  void _refresh() => setState(() => _err = '');

  @override
  void dispose() {
    _title.dispose();
    _msg.dispose();
    _phone.dispose();
    super.dispose();
  }

  int get _recipients {
    var t = 0;
    for (final a in _c.audiences) {
      if (_aud.contains(a.id)) t += a.count;
    }
    return t;
  }

  void _pick(String id) {
    setState(() {
      _err = '';
      if (id == 'all' || id == 'one') {
        final on = !_aud.contains(id);
        _aud = {};
        if (on) _aud.add(id);
      } else {
        _aud.remove('all');
        _aud.remove('one');
        if (!_aud.add(id)) _aud.remove(id);
      }
    });
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final msg = _msg.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      setState(() => _err = 'Weka kichwa cha habari na ujumbe.');
      return;
    }
    if (_aud.isEmpty) {
      setState(() => _err = 'Chagua angalau mlengwa mmoja.');
      return;
    }
    if (_aud.contains('one') && _phone.text.trim().isEmpty) {
      setState(() => _err = 'Weka namba ya simu.');
      return;
    }
    await _c.send(TangazoDraft(
      title: title,
      message: msg,
      type: _type,
      audienceIds: {..._aud},
      phone: _aud.contains('one') ? _phone.text.trim() : null,
      recipients: _recipients,
    ));
    if (!mounted) return;
    _title.clear();
    _msg.clear();
    setState(() {
      _err = '';
      _tab = 1;
      _filter = null;
    });
  }

  Future<void> _resend(Tangazo t) async {
    if (_busyId != null) return;
    setState(() => _busyId = t.id);
    await _c.resend(t);
    if (!mounted) return;
    setState(() {
      _busyId = null;
      _okId = _c.items.isNotEmpty ? _c.items.first.id : null;
      _banner = 'Tangazo limetumwa tena';
      _filter = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() {
      _okId = null;
      _banner = '';
    });
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.of(context, _C.surface, _C.surfaceD),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                child: Row(
                  // Icon ya matangazo — kama ya drawer (bell-ringing) ya Phosphor.
                  // (const imeondolewa: PhosphorIcons.* ni functions, siyo const.)
                  children: [
                    Icon(PhosphorIcons.bellRinging(), size: 26, color: _C.of(context, _C.blue, Color(0xFF7AA7FF))),
                    const SizedBox(width: 10),
                    const Text('Matangazo',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w500, color: _C.of(context, _C.text, _C.textD))),
                  ],
                ),
              ),
              _segment(),
              if (_tab == 0) ..._compose() else ..._history(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment() {
    Widget tab(int i, IconData icon, String label) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? _C.of(context, _C.surface, _C.surfaceD) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: on ? Border.all(color: _C.of(context, _C.border, _C.borderD), width: 0.5) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? _C.of(context, _C.text, _C.textD) : _C.of(context, _C.text2, _C.text2D)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                        color: on ? _C.of(context, _C.text, _C.textD) : _C.of(context, _C.text2, _C.text2D))),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      padding: const EdgeInsets.all(4),
      // Background yote NYEUPE (ilikuwa kijivu #F1F3F6) — tab active ina border.
      decoration: BoxDecoration(
        color: _C.of(context, _C.surface, _C.surfaceD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.of(context, _C.border, _C.borderD), width: 0.5),
      ),
      child: Row(children: [
        tab(0, MtIcons.compose, 'Tangazo jipya'),
        const SizedBox(width: 4),
        tab(1, MtIcons.history, 'Historia (${_c.total})'),
      ]),
    );
  }

  // ───────────────────────── TANGAZO JIPYA ─────────────────────────
  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.of(context, _C.surface, _C.surfaceD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.of(context, _C.border, _C.borderD), width: 0.5),
        ),
        child: child,
      );

  Widget _label(int n, String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _C.of(context, _C.accentBg, _C.accentBgD), shape: BoxShape.circle),
            child: Text('$n',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: _C.of(context, _C.blue, Color(0xFF7AA7FF)))),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500, color: _C.of(context, _C.text, _C.textD))),
          const Spacer(),
          if (trailing != null) trailing,
        ]),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _C.of(context, _C.muted, _C.mutedD), fontSize: 15),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _C.of(context, _C.borderStrong, _C.borderStrongD), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _C.of(context, _C.blue, Color(0xFF7AA7FF)), width: 1.4),
        ),
      );

  List<Widget> _compose() {
    final auds = _c.audiences;
    return [
      // 1. Aina ya tangazo
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(1, 'Aina ya tangazo'),
          Row(
            children: [
              for (final t in TangazoType.values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = t),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == t ? t.bg : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _type == t ? t.fg : _C.of(context, _C.borderStrong, _C.borderStrongD), width: 0.8),
                      ),
                      child: Column(children: [
                        Icon(t.icon, size: 22, color: _type == t ? t.fg : _C.of(context, _C.text, _C.textD)),
                        const SizedBox(height: 4),
                        Text(t.label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    _type == t ? FontWeight.w500 : FontWeight.w400,
                                color: _type == t ? t.fg : _C.of(context, _C.text, _C.textD))),
                      ]),
                    ),
                  ),
                ),
                if (t != TangazoType.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ]),
      ),
      // 2. Kichwa cha habari
      _card(
        child: Column(children: [
          _label(2, 'Kichwa cha habari',
              trailing: Text('${_title.text.length}/60',
                  style: TextStyle(fontSize: 12, color: _C.of(context, _C.muted, _C.mutedD)))),
          TextField(
            controller: _title,
            maxLength: 60,
            style: TextStyle(fontSize: 15, color: _C.of(context, _C.text, _C.textD)),
            decoration: _input('Andika kichwa cha habari'),
          ),
        ]),
      ),
      // 3. Ujumbe
      _card(
        child: Column(children: [
          _label(3, 'Ujumbe',
              trailing: Text('${_msg.text.length}/500',
                  style: TextStyle(fontSize: 12, color: _C.of(context, _C.muted, _C.mutedD)))),
          TextField(
            controller: _msg,
            maxLength: 500,
            minLines: 4,
            maxLines: 6,
            style: TextStyle(fontSize: 15, color: _C.of(context, _C.text, _C.textD)),
            decoration: _input('Andika ujumbe wako hapa...'),
          ),
        ]),
      ),
      // 4. Wasikilizaji
      _card(
        child: Column(children: [
          _label(
            4,
            'Wasikilizaji',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: _C.of(context, _C.accentBg, _C.accentBgD), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(MtIcons.groups, size: 15, color: _C.of(context, _C.blue, Color(0xFF7AA7FF))),
                const SizedBox(width: 4),
                Text('${_fmt(_recipients)} watapokea',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: _C.of(context, _C.blue, Color(0xFF7AA7FF)))),
              ]),
            ),
          ),
          for (var i = 0; i < auds.length; i++) _audienceRow(auds[i], first: i == 0),
          if (_aud.contains('one'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 15, color: _C.of(context, _C.text, _C.textD)),
                decoration: _input('Namba ya simu, mf. 0712 345 678'),
              ),
            ),
        ]),
      ),
      // 5. Muonekano
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(5, 'Muonekano'),
          Container(
            padding: const EdgeInsets.all(12),
            // Background NYEUPE (ilikuwa kijivu #F1F3F6) + mstari mwembamba.
            decoration: BoxDecoration(
                color: _C.of(context, _C.surface, _C.surfaceD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.of(context, _C.border, _C.borderD), width: 0.5)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _iconBox(_type.icon, _type.fg, _type.bg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_type.label,
                          style: TextStyle(fontSize: 12, color: _C.of(context, _C.muted, _C.mutedD))),
                      const Text('sasa hivi',
                          style: TextStyle(fontSize: 12, color: _C.of(context, _C.muted, _C.mutedD))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_title.text.isEmpty ? 'Kichwa cha habari' : _title.text,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500, color: _C.of(context, _C.text, _C.textD))),
                  const SizedBox(height: 2),
                  Text(_msg.text.isEmpty ? 'Ujumbe wako utaonekana hapa...' : _msg.text,
                      style: TextStyle(fontSize: 14, color: _C.of(context, _C.text2, _C.text2D))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      // Kitufe cha kutuma (icon peke yake) + kosa
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Row(children: [
          Expanded(
            child: _err.isEmpty
                ? const SizedBox.shrink()
                : Row(children: [
                    const Icon(MtIcons.error, size: 16, color: _C.danger),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(_err,
                          style: const TextStyle(fontSize: 13, color: _C.danger)),
                    ),
                  ]),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Tuma tangazo',
            button: true,
            child: Material(
              color: _C.of(context, _C.blue, Color(0xFF7AA7FF)),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _send,
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(MtIcons.send, size: 22, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    ];
  }

  Widget _iconBox(IconData icon, Color fg, Color bg, {double opacity = 1}) => Opacity(
        opacity: opacity,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 21, color: fg),
        ),
      );

  Widget _audienceRow(AudienceOption a, {required bool first}) {
    final on = _aud.contains(a.id);
    return InkWell(
      onTap: () => _pick(a.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: _C.of(context, _C.border, _C.borderD), width: 0.5)),
        ),
        child: Row(children: [
          _iconBox(a.icon, a.color, a.color.withAlpha(36), opacity: on ? 1 : 0.55),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.label, style: TextStyle(fontSize: 15, color: _C.of(context, _C.text, _C.textD))),
              Text('${_fmt(a.count)} watu',
                  style: TextStyle(fontSize: 12, color: _C.of(context, _C.muted, _C.mutedD))),
            ]),
          ),
          _Toggle(on: on),
        ]),
      ),
    );
  }

  // ───────────────────────── HISTORIA ─────────────────────────
  List<Widget> _history() {
    final out = <Widget>[];

    // Vichujio: Yote | Taarifa | Onyo | Mafanikio
    out.add(Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(children: [
        _filterPill('Yote', null),
        const SizedBox(width: 6),
        _filterPill('Taarifa', TangazoType.taarifa),
        const SizedBox(width: 6),
        _filterPill('Onyo', TangazoType.onyo),
        const SizedBox(width: 6),
        _filterPill('Mafanikio', TangazoType.mafanikio),
      ]),
    ));

    if (_banner.isNotEmpty) {
      out.add(Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: _C.of(context, _C.successBg, _C.successBgD), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(MtIcons.success, size: 20, color: _C.of(context, _C.successFg, _C.successFgD)),
          const SizedBox(width: 8),
          Text(_banner, style: TextStyle(fontSize: 14, color: _C.of(context, _C.successFg, _C.successFgD))),
        ]),
      ));
    }

    final list = _c.items.where((t) => _filter == null || t.type == _filter).toList();

    if (list.isEmpty) {
      out.add(_emptyState());
      return out;
    }

    int? lastMonth;
    for (final t in list) {
      final key = t.date.year * 100 + t.date.month;
      if (key != lastMonth) {
        lastMonth = key;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(children: [
            Icon(MtIcons.calendar, size: 16, color: _C.of(context, _C.text2, _C.text2D)),
            const SizedBox(width: 6),
            Text(_monthLabel(t.date),
                style: TextStyle(fontSize: 13, color: _C.of(context, _C.text2, _C.text2D))),
          ]),
        ));
      }
      out.add(_historyCard(t));
    }

    out.add(_pagination());
    return out;
  }

  Widget _filterPill(String label, TangazoType? t) {
    final on = _filter == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _filter = t;
          _deleteId = null;
        }),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? _C.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: on ? _C.blue : _C.of(context, _C.borderStrong, _C.borderStrongD), width: 0.6),
          ),
          child: Text(label,
              maxLines: 1,
              style: TextStyle(fontSize: 13, color: on ? Colors.white : _C.of(context, _C.text2, _C.text2D))),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final t = _filter ?? TangazoType.taarifa;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 440),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
              child: Icon(PhosphorIcons.bellSlash(), size: 42, color: t.fg),
            ),
            const SizedBox(height: 16),
            const Text('Hakuna matangazo',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w500, color: _C.of(context, _C.text, _C.textD))),
            const SizedBox(height: 6),
            Text('Bado hujatuma tangazo la aina ya ${t.label}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: _C.of(context, _C.text2, _C.text2D))),
            const SizedBox(height: 18),
            Material(
              color: t.bg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _type = t;
                  _tab = 0;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(MtIcons.plus, size: 18, color: t.fg),
                    const SizedBox(width: 8),
                    Text('Tunga tangazo',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: t.fg)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(Tangazo t) {
    final confirming = _deleteId == t.id;
    final busy = _busyId == t.id;
    final ok = _okId == t.id;
    return _card(
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _iconBox(t.type.icon, t.type.fg, t.type.bg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: _C.of(context, _C.text, _C.textD))),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text('${t.type.label} · ${_dateLabel(t.date)}',
                    style: TextStyle(fontSize: 12, color: _C.of(context, _C.muted, _C.mutedD))),
              ),
              Text(t.message,
                  style: TextStyle(fontSize: 14, height: 1.5, color: _C.of(context, _C.text2, _C.text2D))),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (confirming) ...[
            Text('Futa tangazo?', style: TextStyle(fontSize: 13, color: _C.of(context, _C.text, _C.textD))),
            const SizedBox(width: 12),
            _squareButton(
              icon: MtIcons.close,
              color: _C.of(context, _C.text, _C.textD),
              label: 'Hapana',
              onTap: () => setState(() => _deleteId = null),
            ),
            const SizedBox(width: 8),
            _squareButton(
              icon: MtIcons.check,
              color: Colors.white,
              bg: _C.danger,
              label: 'Thibitisha kufuta',
              onTap: () async {
                setState(() => _deleteId = null);
                await _c.delete(t);
              },
            ),
          ] else ...[
            _squareButton(
              icon: MtIcons.revert,
              color: ok ? _C.of(context, _C.successFg, _C.successFgD) : _C.blue,
              bg: ok ? _C.of(context, _C.successBg, _C.successBgD) : null,
              label: 'Tuma tena',
              onTap: () => _resend(t),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _C.of(context, _C.blue, Color(0xFF7AA7FF))),
                    )
                  : ok
                      ? TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.5, end: 1),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.elasticOut,
                          builder: (_, v, __) => Transform.scale(
                            scale: v,
                            child: const Icon(MtIcons.check,
                                size: 22, color: _C.of(context, _C.successFg, _C.successFgD)),
                          ),
                        )
                      : null,
            ),
            const SizedBox(width: 8),
            _squareButton(
              icon: PhosphorIcons.trash(),
              color: _C.danger,
              label: 'Futa',
              onTap: () => setState(() => _deleteId = t.id),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _squareButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    Color? bg,
    Widget? child,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: bg ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: bg == null ? _C.of(context, _C.borderStrong, _C.borderStrongD) : Colors.transparent, width: 0.6),
        ),
        child: InkWell(
          customBorder:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(child: child ?? Icon(icon, size: 20, color: color)),
          ),
        ),
      ),
    );
  }

  Widget _pagination() {
    final first = _c.page <= 1;
    final last = _c.page >= _c.pages;
    Widget pill({
      required IconData icon,
      required String text,
      required bool left,
      required bool disabled,
      required VoidCallback onTap,
      bool filled = false,
    }) {
      final fg = filled ? _C.blue : _C.of(context, _C.text, _C.textD);
      final children = <Widget>[
        if (left) Icon(icon, size: 18, color: fg),
        if (left) const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: fg)),
        if (!left) const SizedBox(width: 6),
        if (!left) Icon(icon, size: 18, color: fg),
      ];
      return Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Material(
          color: filled ? _C.of(context, _C.accentBg, _C.accentBgD) : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
                color: filled ? Colors.transparent : _C.of(context, _C.borderStrong, _C.borderStrongD), width: 0.6),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: disabled ? null : onTap,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          pill(
            icon: MtIcons.prev,
            text: 'Iliyopita',
            left: true,
            disabled: first,
            onTap: () async {
              setState(() => _deleteId = null);
              await _c.loadPage(_c.page - 1);
            },
          ),
          Text('${_c.page} / ${_c.pages}',
              style: TextStyle(fontSize: 13, color: _C.of(context, _C.muted, _C.mutedD))),
          pill(
            icon: MtIcons.next,
            text: 'Inayofuata',
            left: false,
            disabled: last,
            filled: true,
            onTap: () async {
              setState(() => _deleteId = null);
              await _c.loadPage(_c.page + 1);
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Toggle ─────────────────────────
class _Toggle extends StatelessWidget {
  final bool on;
  const _Toggle({required this.on});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? _C.blue : _C.of(context, _C.borderStrong, _C.borderStrongD),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

// ============================================================================
// INTEGRATION LAYER — API halisi ya backend (Kubadilishana / EssTransfer)
//
// Ramani ya data (GET /admin/announcements):
//   announcement_id/id, type ('info'|'warning'|'success'), title, message,
//   created_at  →  Tangazo (taarifa/onyo/mafanikio)
//
//   send    → POST /admin/announcements
//             {title, message, type, audience: 'all'|'custom'|'user',
//              audiences: [codes], target_user_id?}
//             'Mtu mmoja': namba ya simu inatafutwa kwenye /admin/users
//             ili kupata target_user_id halisi.
//   resend  → POST /admin/announcements/{id}/resend
//   delete  → DELETE /admin/announcements/{id}
//   Ukurasa → items hupaguliwa upande wa app (6 kwa ukurasa, kama zamani).
//   Wasikilizaji → /admin/departments (makundi) + /admin/stats (counts).
// ============================================================================

const int _kMatangazoPerPage = 6;

DateTime _matangazoDate(dynamic iso) {
  final s = iso?.toString() ?? '';
  if (s.isEmpty) return DateTime.now();
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

TangazoType _typeFromApi(String? v) => switch (v) {
      'warning' => TangazoType.onyo,
      'success' => TangazoType.mafanikio,
      _ => TangazoType.taarifa,
    };

String _typeToApi(TangazoType t) => switch (t) {
      TangazoType.taarifa => 'info',
      TangazoType.onyo => 'warning',
      TangazoType.mafanikio => 'success',
    };

String _deptLabel(String code, String fallback) {
  switch (code) {
    case 'health':
      return 'Afya';
    case 'education':
      return 'Elimu';
    case 'kilimo':
      return 'Kilimo na ufugaji';
    case 'watumishi_wa_umma':
    case 'service':
      return 'Watumishi wa Umma';
    default:
      return fallback;
  }
}

IconData _deptIcon(String code) {
  switch (code) {
    case 'health':
      return MtIcons.afya;
    case 'education':
      return MtIcons.elimu;
    case 'kilimo':
      return MtIcons.kilimo;
    case 'watumishi_wa_umma':
    case 'service':
      return MtIcons.umma;
    default:
      return MtIcons.groups;
  }
}

Color _deptColor(String code) {
  switch (code) {
    case 'health':
      return const Color(0xFFD85A30);
    case 'education':
      return const Color(0xFF7F77DD);
    case 'kilimo':
      return const Color(0xFF639922);
    case 'watumishi_wa_umma':
    case 'service':
      return const Color(0xFFBA7517);
    default:
      return const Color(0xFF378ADD);
  }
}

/// Wasikilizaji wa mwanzo (codes halisi za backend, counts 0 mpaka API irejee).
List<AudienceOption> _seedAudiences() => const [
      AudienceOption(id: 'all', label: 'Wote', count: 0, icon: MtIcons.groups, color: Color(0xFF378ADD)),
      AudienceOption(id: 'health', label: 'Afya', count: 0, icon: MtIcons.afya, color: Color(0xFFD85A30)),
      AudienceOption(id: 'education', label: 'Elimu', count: 0, icon: MtIcons.elimu, color: Color(0xFF7F77DD)),
      AudienceOption(id: 'kilimo', label: 'Kilimo na ufugaji', count: 0, icon: MtIcons.kilimo, color: Color(0xFF639922)),
      AudienceOption(id: 'watumishi_wa_umma', label: 'Watumishi wa Umma', count: 0, icon: MtIcons.umma, color: Color(0xFFBA7517)),
      AudienceOption(id: 'one', label: 'Mtu mmoja', count: 1, icon: MtIcons.person, color: Color(0xFF888780)),
    ];

class ApiMatangazoController extends MatangazoController {
  ApiMatangazoController() : super(audiences: _seedAudiences());

  List<Tangazo> _all = [];
  bool _busy = false;

  int _pagesFor(int n) => (n / _kMatangazoPerPage).ceil().clamp(1, 9999);

  void _applyPage() {
    final start = ((page - 1) * _kMatangazoPerPage).clamp(0, _all.length);
    final end = (start + _kMatangazoPerPage).clamp(0, _all.length);
    items = _all.sublist(start, end);
  }

  /// PAKIA historia + wasikilizaji kutoka API. Inaitwa mara moja na page.
  Future<void> load() async {
    if (_busy) return;
    _busy = true;
    try {
      final res = await ApiService().adminListAnnouncements();
      final data = res.data;
      final raw = data is List
          ? data
          : (asMap(data)['announcements'] as List? ??
              asMap(data)['results'] as List? ??
              const []);
      _all = [
        for (final e in raw)
          Tangazo(
            id: (asMap(e)['announcement_id'] ?? asMap(e)['id'] ?? '').toString(),
            title: asMap(e)['title']?.toString() ?? '',
            type: _typeFromApi(asMap(e)['type']?.toString()),
            date: _matangazoDate(asMap(e)['created_at']),
            message: asMap(e)['message']?.toString() ?? '',
          ),
      ];
      total = _all.length;
      pages = _pagesFor(_all.length);
      page = 1;
      _applyPage();
      notifyListeners();
    } catch (e) {
      AppToast.error(friendlyError(e));
    } finally {
      _busy = false;
    }
    await _loadAudiences();
  }

  /// Makundi (idara) + idadi halisi za watumiaji (kama ukurasa wa zamani).
  Future<void> _loadAudiences() async {
    final options = <AudienceOption>[
      const AudienceOption(
          id: 'all', label: 'Wote', count: 0, icon: MtIcons.groups, color: Color(0xFF378ADD)),
    ];
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      final depts = (raw is List
              ? raw
              : (asMap(raw)['results'] ?? asMap(raw)['items'] ?? const [])) as List;
      for (final e in depts) {
        final d = asMap(e);
        final code = (d['code'] ?? '').toString();
        if (code.isEmpty || code == 'all' || code == 'user') continue;
        options.add(AudienceOption(
          id: code,
          label: _deptLabel(code, (d['display_name'] ?? d['name'] ?? code).toString()),
          count: 0,
          icon: _deptIcon(code),
          color: _deptColor(code),
        ));
      }
    } catch (_) {}
    try {
      final r = await ApiService().adminStats();
      final d = asMap(r.data);
      final totals = asMap(d['totals']);
      final allCount = (totals['users'] as num?)?.toInt() ?? 0;
      options[0] = AudienceOption(
          id: 'all', label: 'Wote', count: allCount, icon: MtIcons.groups, color: const Color(0xFF378ADD));
      final byCat = <String, int>{};
      for (final row in asList(d['by_cadre'])) {
        final m = asMap(row);
        final cat = m['category']?.toString() ?? '';
        if (cat.isEmpty) continue;
        byCat[cat] = (byCat[cat] ?? 0) + ((m['count'] as num?)?.toInt() ?? 0);
      }
      for (var i = 1; i < options.length; i++) {
        final a = options[i];
        options[i] = AudienceOption(
            id: a.id, label: a.label, count: byCat[a.id] ?? 0, icon: a.icon, color: a.color);
      }
    } catch (_) {}
    options.add(const AudienceOption(
        id: 'one', label: 'Mtu mmoja', count: 1, icon: MtIcons.person, color: Color(0xFF888780)));
    audiences = options;
    notifyListeners();
  }

  /// 'Mtu mmoja': tafuta user_id kwa namba ya simu (/admin/users).
  Future<String?> _userIdByPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return null;
    final r = await ApiService()
        .adminUsers(params: {'q': phone.trim(), 'limit': 10}, useCache: false);
    final data = r.data;
    final list = (data is List
            ? data
            : (asMap(data)['users'] ?? asMap(data)['results'] ?? const [])) as List;
    for (final e in list) {
      final m = asMap(e);
      final p =
          (m['phone_primary'] ?? m['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      if (p == digits || p.endsWith(digits)) {
        return (m['user_id'] ?? m['id'] ?? m['_id'] ?? '').toString();
      }
    }
    return null;
  }

  @override
  Future<void> send(TangazoDraft d) async {
    try {
      final groups =
          d.audienceIds.where((id) => id != 'all' && id != 'one').toList();
      String audience;
      List<String> audiences;
      String? targetUserId;
      if (d.audienceIds.contains('one')) {
        targetUserId = await _userIdByPhone(d.phone ?? '');
        if (targetUserId == null || targetUserId.isEmpty) {
          AppToast.error('Hakuna mtumiaji aliyepatikana kwa namba ${d.phone ?? ''}');
          return;
        }
        audience = 'user';
        audiences = const ['user'];
      } else if (d.audienceIds.contains('all')) {
        audience = 'all';
        audiences = const ['all'];
      } else {
        if (groups.isEmpty) {
          AppToast.error('Chagua angalau mlengwa mmoja.');
          return;
        }
        audience = 'custom';
        audiences = groups;
      }
      await ApiService().adminSendAnnouncement({
        'title': d.title,
        'message': d.message,
        'type': _typeToApi(d.type),
        'audience': audience,
        'audiences': audiences,
        if (targetUserId != null) 'target_user_id': targetUserId,
      });
      await load(); // historia mpya — tangazo jipya linaingia juu
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Future<void> resend(Tangazo t) async {
    try {
      await ApiService().adminResendAnnouncement(t.id);
      await load();
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Future<void> delete(Tangazo t) async {
    try {
      await ApiService().adminDeleteAnnouncement(t.id);
      _all.removeWhere((x) => x.id == t.id);
      total = _all.length;
      pages = _pagesFor(_all.length);
      if (page > pages) page = pages;
      _applyPage();
      notifyListeners();
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Future<void> loadPage(int p) async {
    page = p.clamp(1, pages);
    _applyPage();
    notifyListeners();
  }
}

// ----------------------------------------------------------------------------
// Ukurasa wa Matangazo kwenye AdminShell (nav index 5) — controller ya API halisi.
// ----------------------------------------------------------------------------
class AdminMatangazoPage extends StatefulWidget {
  const AdminMatangazoPage({super.key});

  @override
  State<AdminMatangazoPage> createState() => _AdminMatangazoPageState();
}

class _AdminMatangazoPageState extends State<AdminMatangazoPage> {
  late final ApiMatangazoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ApiMatangazoController();
    _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return MatangazoScreen(controller: _controller);
  }
}