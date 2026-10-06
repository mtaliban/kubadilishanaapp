// malipo_screen.dart
// Skrini ya Malipo - muundo wa "Risiti" wenye duara la takwimu juu.
// Nakala kamili ya muundo ulioidhinishwa. Faili moja, hakuna package ya ziada.
// Inahitaji Flutter 3.13+ (Dart 3). Mwonekano wa mwanga tu.
//
// MATUMIZI:
//   final controller = MalipoController(
//     items: malipoYaUkurasaWa1,
//     completedCount: 47, pendingCount: 1, rejectedCount: 29,
//     completedAmount: 160000, pendingAmount: 2500,
//     page: 1, pages: 8,
//   );
//   MalipoScreen(controller: controller)
//
// KUUNGANISHA NA API: tengeneza class inayo-extend MalipoController na ubadilishe
//   approve / reject / undo / loadPage (piga API kisha notifyListeners()).
//   Kuchuja na kutafuta hapa kunafanya kazi kwenye malipo ya ukurasa uliopo;
//   kwa data nyingi, chuja kwenye server ndani ya loadPage.
//
// ICON: zote ziko sehemu moja (class MpIcons). Ni Material Icons zinazofanana na
//   seti ya Tabler iliyotumika kwenye muundo. Ukitaka Tabler halisi, badilisha
//   mistari ya MpIcons tu - hakuna kingine kinachohitaji kubadilishwa.

import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/admin_badge_service.dart';
import '../../services/api_service.dart';
import '../../services/network_service.dart';
import '../../services/offline_queue.dart';
import '../../services/websocket_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_drawer.dart' show BadgeController, NavItem;
import '../../widgets/app_toast.dart' show AppToast, friendlyError;

// ───────────────────────── RANGI ─────────────────────────
class _C {
  static const blue = Color(0xFF1A56DB);
  static const accentBg = Color(0xFFE8EEFC);
  static const accentBorder = Color(0xFFBFD2F8);
  static const surface = Colors.white;
  static const surface1 = Color(0xFFF1F3F6);
  static const border = Color(0xFFE3E6EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const text = Color(0xFF111827);
  static const text2 = Color(0xFF6B7280);
  static const muted = Color(0xFF9CA3AF);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
  static const successFg = Color(0xFF15803D);
  static const successBg = Color(0xFFDCFCE7);
  static const warningFg = Color(0xFFB45309);
  static const warningBg = Color(0xFFFEF3C7);
  static const dangerFg = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFEE9E9);
  static const dangerBorder = Color(0xFFFCA5A5);
}

// ───────────────────────── ICON (mahali pamoja) ─────────────────────────
class MpIcons {
  static const search = Icons.search_rounded; // search
  static const eye = Icons.visibility_outlined; // eye
  static const eyeOff = Icons.visibility_off_outlined; // eye-off
  static const copy = Icons.content_copy_outlined; // copy
  static const check = Icons.check_rounded; // check
  static const close = Icons.close_rounded; // x
  static const send = Icons.send_outlined; // send
  static const clock = Icons.schedule_rounded; // clock-hour-4
  static const eyeCheck = Icons.fact_check_outlined; // eye-check
  static const circleDashed = Icons.circle_outlined; // circle-dashed
  static const circleCheck = Icons.check_circle_outline; // circle-check
  static const circleX = Icons.cancel_outlined; // circle-x
  static const info = Icons.info_outline; // info-circle
  static const message = Icons.sms_outlined; // message-2
  static const ban = Icons.block_rounded; // ban
  static const back = Icons.undo_rounded; // arrow-back-up
  static const alert = Icons.error_outline; // alert-circle
  static const receipt = Icons.receipt_long_outlined; // receipt-off
  static const prev = Icons.chevron_left_rounded;
  static const next = Icons.chevron_right_rounded;
}

// ───────────────────────── MODELS ─────────────────────────
enum MalipoStatus { pending, completed, rejected }

extension MalipoStatusX on MalipoStatus {
  String get label => switch (this) {
        MalipoStatus.pending => 'Inasubiri',
        MalipoStatus.completed => 'Imekamilika',
        MalipoStatus.rejected => 'Imekataliwa',
      };
  Color get color => switch (this) {
        MalipoStatus.pending => _C.amber,
        MalipoStatus.completed => _C.green,
        MalipoStatus.rejected => _C.red,
      };
  Color get fg => switch (this) {
        MalipoStatus.pending => _C.warningFg,
        MalipoStatus.completed => _C.successFg,
        MalipoStatus.rejected => _C.dangerFg,
      };
  Color get bg => switch (this) {
        MalipoStatus.pending => _C.warningBg,
        MalipoStatus.completed => _C.successBg,
        MalipoStatus.rejected => _C.dangerBg,
      };
}

class Malipo {
  final String id;
  final String name;
  final String phone; // mf. +255 612 500 600 au 0612500600
  final int amount;
  final String code;
  final DateTime sentAt;
  final MalipoStatus status;
  final String? sms; // SMS ya mchangiaji
  final String? rejectReason;

  const Malipo({
    required this.id,
    required this.name,
    required this.phone,
    required this.amount,
    required this.code,
    required this.sentAt,
    this.status = MalipoStatus.pending,
    this.sms,
    this.rejectReason,
  });

  Malipo copyWith({MalipoStatus? status, String? rejectReason, bool clearReason = false}) =>
      Malipo(
        id: id,
        name: name,
        phone: phone,
        amount: amount,
        code: code,
        sentAt: sentAt,
        status: status ?? this.status,
        sms: sms,
        rejectReason: clearReason ? null : (rejectReason ?? this.rejectReason),
      );
}

// ───────────────────────── CONTROLLER ─────────────────────────
class MalipoController extends ChangeNotifier {
  List<Malipo> items;
  int pendingCount;
  int completedCount;
  int rejectedCount;
  int completedAmount;
  int pendingAmount;
  int page;
  int pages;
  Malipo? _undoBefore;

  MalipoController({
    List<Malipo>? items,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.rejectedCount = 0,
    this.completedAmount = 0,
    this.pendingAmount = 0,
    this.page = 1,
    this.pages = 1,
  }) : items = items ?? <Malipo>[];

  int get totalCount => pendingCount + completedCount + rejectedCount;

  void _replace(Malipo m) {
    final i = items.indexWhere((x) => x.id == m.id);
    if (i >= 0) items[i] = m;
  }

  /// Thibitisha malipo. Badilisha hapa kupiga API yako.
  Future<void> approve(Malipo m) async {
    _undoBefore = m;
    _replace(m.copyWith(status: MalipoStatus.completed, clearReason: true));
    pendingCount--;
    completedCount++;
    completedAmount += m.amount;
    pendingAmount -= m.amount;
    notifyListeners();
  }

  /// Kataa malipo kwa sababu. Badilisha hapa kupiga API yako.
  Future<void> reject(Malipo m, String reason) async {
    _undoBefore = m;
    _replace(m.copyWith(status: MalipoStatus.rejected, rejectReason: reason));
    pendingCount--;
    rejectedCount++;
    pendingAmount -= m.amount;
    notifyListeners();
  }

  /// Tendua kitendo cha mwisho (kurudisha malipo kuwa yanayosubiri).
  Future<void> undo() async {
    final before = _undoBefore;
    if (before == null) return;
    final i = items.indexWhere((x) => x.id == before.id);
    if (i < 0) return;
    final now = items[i];
    if (now.status == MalipoStatus.completed) {
      completedCount--;
      completedAmount -= now.amount;
    } else if (now.status == MalipoStatus.rejected) {
      rejectedCount--;
    }
    pendingCount++;
    pendingAmount += now.amount;
    items[i] = before;
    _undoBefore = null;
    notifyListeners();
  }

  /// Badilisha ukurasa. Kwa API halisi: pakia malipo ya ukurasa [p] hapa.
  Future<void> loadPage(int p) async {
    page = p.clamp(1, pages);
    notifyListeners();
  }
}

// ───────────────────────── HELPERS ─────────────────────────
const _monthsShort = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
const _weekdays = ['Jumatatu', 'Jumanne', 'Jumatano', 'Alhamisi', 'Ijumaa', 'Jumamosi', 'Jumapili'];

String _fmt(int n) {
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer(neg ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = a.difference(b).inDays;
  if (diff <= 0) return 'Leo';
  if (diff == 1) return 'Jana';
  if (diff == 2) return 'Juzi';
  final date = '${d.day} ${_monthsShort[d.month - 1]}';
  if (diff < 7) return '${_weekdays[d.weekday - 1]}, $date';
  return '$date ${d.year}';
}

String _phone(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('255') && digits.length == 12) digits = '0${digits.substring(3)}';
  if (digits.length == 10) {
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
  }
  return raw;
}

const _reasons = ['Kiasi hakilingani', 'Pesa haijaingia', 'SMS si sahihi', 'Namba haifanani'];

// ═════════════════════════ SKRINI ═════════════════════════
class MalipoScreen extends StatefulWidget {
  final MalipoController controller;
  const MalipoScreen({super.key, required this.controller});

  @override
  State<MalipoScreen> createState() => _MalipoScreenState();
}

class _MalipoScreenState extends State<MalipoScreen> {
  MalipoStatus? _filter;
  bool _searchOpen = false;
  final _search = TextEditingController();
  final _other = TextEditingController();
  String? _openId;
  String? _rejectId;
  String _reason = '';
  String _error = '';
  String? _copiedId;
  String? _banner;
  MalipoStatus _bannerStatus = MalipoStatus.completed;
  bool _showUndo = false;
  int _bannerToken = 0;

  MalipoController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _other.dispose();
    super.dispose();
  }

  // ───────────────────────── Vitendo ─────────────────────────
  void _select(MalipoStatus? s) {
    setState(() {
      _filter = (s == _filter) ? null : s;
      _openId = null;
      _rejectId = null;
    });
    _c.loadPage(1);
  }

  void _toggleOpen(String id) {
    setState(() {
      _openId = _openId == id ? null : id;
      _rejectId = null;
    });
  }

  Future<void> _copy(Malipo m) async {
    await Clipboard.setData(ClipboardData(text: m.code));
    if (!mounted) return;
    setState(() => _copiedId = m.id);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _copiedId = null);
  }

  void _flash(String text, MalipoStatus status) {
    final token = ++_bannerToken;
    setState(() {
      _banner = text;
      _bannerStatus = status;
      _showUndo = true;
    });
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted || token != _bannerToken) return;
      setState(() {
        _banner = null;
        _showUndo = false;
      });
    });
  }

  Future<void> _approve(Malipo m) async {
    setState(() {
      _rejectId = null;
      _openId = null;
    });
    await _c.approve(m);
    _flash('Malipo yamethibitishwa', MalipoStatus.completed);
  }

  Future<void> _reject(Malipo m) async {
    final why = _other.text.trim().isNotEmpty ? _other.text.trim() : _reason;
    if (why.isEmpty) {
      setState(() => _error = 'Chagua sababu kwanza.');
      return;
    }
    setState(() {
      _rejectId = null;
      _openId = null;
    });
    await _c.reject(m, why);
    _flash('Malipo yamekataliwa', MalipoStatus.rejected);
  }

  Future<void> _undo() async {
    _bannerToken++;
    setState(() {
      _banner = null;
      _showUndo = false;
    });
    await _c.undo();
  }

  List<Malipo> _visible() {
    final q = _search.text.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'\s'), '');
    return _c.items.where((m) {
      if (_filter != null && m.status != _filter) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.phone.replaceAll(RegExp(r'\s'), '').contains(qDigits) ||
          m.code.toLowerCase().contains(q);
    }).toList();
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final list = _visible();
            return ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                _header(),
                _donutSection(),
                _tiles(),
                if (_filter != null) _filterLine(),
                if (_searchOpen) _searchField(),
                if (_banner != null) _bannerView(),
                if (list.isEmpty) _emptyState() else ..._tickets(list),
                if (list.isNotEmpty) _pagination(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── JUU ─────────────────────────
  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
        child: Row(children: [
          const Text('Malipo',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: _C.text)),
          const SizedBox(width: 10),
          const _LiveDot(),
          const Spacer(),
          Semantics(
            label: 'Tafuta',
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _search.clear();
              }),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.borderStrong, width: 0.6),
                ),
                child: Icon(MpIcons.search,
                    size: 20, color: _searchOpen ? _C.blue : _C.text),
              ),
            ),
          ),
        ]),
      );

  Widget _donutSection() {
    final ce = _centerTexts();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: _Donut(
          completed: _c.completedCount,
          pending: _c.pendingCount,
          rejected: _c.rejectedCount,
          selected: _filter,
          onSelect: (s) {
            if (s == null) {
              setState(() {
                _filter = null;
                _openId = null;
                _rejectId = null;
              });
              _c.loadPage(1);
            } else {
              _select(s);
            }
          },
          center: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ce.$1,
                    style: const TextStyle(fontSize: 12, color: _C.text2),
                    textAlign: TextAlign.center),
                Text(ce.$2,
                    style: TextStyle(
                        fontSize: ce.$2.length > 6 ? 22 : 32,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                        color: ce.$4),
                    textAlign: TextAlign.center),
                Text(ce.$3,
                    style: const TextStyle(fontSize: 11.5, height: 1.3, color: _C.text2),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, String, String, Color) _centerTexts() {
    switch (_filter) {
      case MalipoStatus.completed:
        return ('Imekamilika', 'TZS ${_fmt(_c.completedAmount)}', 'malipo ${_c.completedCount}', MalipoStatus.completed.fg);
      case MalipoStatus.pending:
        return ('Inasubiri', 'TZS ${_fmt(_c.pendingAmount)}', 'malipo ${_c.pendingCount}', MalipoStatus.pending.fg);
      case MalipoStatus.rejected:
        return ('Imekataliwa', '${_c.rejectedCount}', 'malipo', MalipoStatus.rejected.fg);
      case null:
        return ('Malipo yote', '${_c.totalCount}', 'TZS ${_fmt(_c.completedAmount)} zimekamilika', _C.text);
    }
  }

  Widget _tiles() {
    Widget tile(MalipoStatus s, int count, String sub) {
      final on = _filter == s;
      return Expanded(
        child: GestureDetector(
          onTap: () => _select(s),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
            decoration: BoxDecoration(
              color: on ? s.bg : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? s.color : _C.borderStrong, width: 0.6),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: on ? s.fg : _C.text2)),
                ),
              ]),
              const SizedBox(height: 2),
              Text('$count',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: on ? s.fg : _C.text)),
              Text(sub, style: const TextStyle(fontSize: 11, color: _C.muted)),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(children: [
        tile(MalipoStatus.completed, _c.completedCount, 'TZS ${_fmt(_c.completedAmount)}'),
        const SizedBox(width: 8),
        tile(MalipoStatus.pending, _c.pendingCount, 'TZS ${_fmt(_c.pendingAmount)}'),
        const SizedBox(width: 8),
        tile(MalipoStatus.rejected, _c.rejectedCount, 'hazihesabiwi'),
      ]),
    );
  }

  Widget _filterLine() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
        child: Row(children: [
          const Text('Zinaonyeshwa: ', style: TextStyle(fontSize: 13, color: _C.text2)),
          Text(_filter!.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _filter!.fg)),
          const Spacer(),
          GestureDetector(
            onTap: () => _select(_filter),
            behavior: HitTestBehavior.opaque,
            child: const Row(children: [
              Text('Onyesha yote', style: TextStyle(fontSize: 13, color: _C.blue)),
              SizedBox(width: 3),
              Icon(MpIcons.close, size: 15, color: _C.blue),
            ]),
          ),
        ]),
      );

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: TextField(
          controller: _search,
          autofocus: true,
          style: const TextStyle(fontSize: 15, color: _C.text),
          decoration: InputDecoration(
            hintText: 'Jina, namba au kodi',
            hintStyle: const TextStyle(color: _C.muted, fontSize: 15),
            prefixIcon: const Icon(MpIcons.search, size: 20, color: _C.muted),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.borderStrong, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.blue, width: 1.4),
            ),
          ),
        ),
      );

  Widget _bannerView() {
    final s = _bannerStatus;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(s == MalipoStatus.completed ? MpIcons.circleCheck : MpIcons.circleX,
            size: 20, color: s.fg),
        const SizedBox(width: 8),
        Expanded(child: Text(_banner!, style: TextStyle(fontSize: 14, color: s.fg))),
        if (_showUndo)
          GestureDetector(
            onTap: _undo,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('Tendua',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: s.fg,
                      decoration: TextDecoration.underline,
                      decorationColor: s.fg)),
            ),
          ),
      ]),
    );
  }

  // ───────────────────────── TIKETI ─────────────────────────
  List<Widget> _tickets(List<Malipo> list) {
    final out = <Widget>[];
    String? group;
    for (final m in list) {
      final g = _dayLabel(m.sentAt);
      if (g != group) {
        group = g;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(g, style: const TextStyle(fontSize: 12, color: _C.muted)),
        ));
      }
      out.add(_ticket(m));
    }
    return out;
  }

  Widget _ticket(Malipo m) {
    final s = m.status;
    final open = _openId == m.id;
    final rejecting = _rejectId == m.id;
    final pending = s == MalipoStatus.pending;
    final rejected = s == MalipoStatus.rejected;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.5),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Juu: jina + kiasi
            InkWell(
              onTap: () => _toggleOpen(m.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500, color: _C.text)),
                      const SizedBox(height: 2),
                      Text('${_phone(m.phone)} · ${_time(m.sentAt)}',
                          style: const TextStyle(fontSize: 13, color: _C.text2)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_fmt(m.amount),
                        style: TextStyle(
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w500,
                            color: rejected ? _C.muted : s.fg,
                            decoration:
                                rejected ? TextDecoration.lineThrough : TextDecoration.none,
                            decorationColor: _C.muted)),
                    const Text('TZS', style: TextStyle(fontSize: 11, color: _C.muted)),
                  ]),
                ]),
              ),
            ),
            // Kiunzi (stub): kodi + vitufe
            _stub(m, open: open, rejecting: rejecting, pending: pending),
            if (rejecting) _rejectPanel(m),
            if (open && !rejecting)
              Container(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _C.border, width: 0.5))),
                padding: const EdgeInsets.only(top: 10),
                child: _detail(m),
              ),
          ]),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: ColoredBox(color: s.color),
          ),
        ]),
      ),
    );
  }

  Widget _stub(Malipo m, {required bool open, required bool rejecting, required bool pending}) {
    final s = m.status;
    final copied = _copiedId == m.id;
    return Stack(clipBehavior: Clip.none, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 14, 0),
        child: CustomPaint(
          painter: _DashPainter(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Expanded(
                child: Text(m.code,
                    maxLines: 1,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        letterSpacing: 0.8,
                        color: _C.text)),
              ),
              Semantics(
                label: 'Nakili kodi',
                button: true,
                child: GestureDetector(
                  onTap: () => _copy(m),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 26,
                    height: 34,
                    child: Center(
                      child: copied
                          ? TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.5, end: 1),
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.elasticOut,
                              builder: (_, v, __) => Transform.scale(
                                scale: v,
                                child: const Icon(MpIcons.check,
                                    size: 19, color: _C.successFg),
                              ),
                            )
                          : const Icon(MpIcons.copy, size: 19, color: _C.text2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Ona ujumbe',
                button: true,
                child: GestureDetector(
                  onTap: () => _toggleOpen(m.id),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: open ? _C.accentBg : _C.surface1),
                    child: Icon(open ? MpIcons.eyeOff : MpIcons.eye,
                        size: 19, color: open ? _C.blue : _C.text2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (pending) ...[
                if (!rejecting) ...[
                  _roundButton(
                    icon: MpIcons.close,
                    label: 'Kataa',
                    color: _C.red,
                    onTap: () => setState(() {
                      _rejectId = m.id;
                      _openId = null;
                      _reason = '';
                      _other.clear();
                      _error = '';
                    }),
                  ),
                  const SizedBox(width: 8),
                  _roundButton(
                    icon: MpIcons.check,
                    label: 'Thibitisha',
                    color: _C.green,
                    filled: true,
                    onTap: () => _approve(m),
                  ),
                ],
              ] else
                _Stamp(label: s.label.toUpperCase(), color: s.color, fg: s.fg),
            ]),
          ),
        ),
      ),
      // Mikato kwenye kingo (notches)
      Positioned(left: -9, top: -9, child: _notch()),
      Positioned(right: -9, top: -9, child: _notch()),
    ]);
  }

  Widget _notch() => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: _C.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _C.border, width: 0.5),
        ),
      );

  Widget _roundButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : _C.surface,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, size: 18, color: filled ? Colors.white : color),
        ),
      ),
    );
  }

  Widget _rejectPanel(Malipo m) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: _C.dangerBg,
        border: Border(top: BorderSide(color: _C.dangerBorder, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Kwa nini unakataa?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _C.dangerFg)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in _reasons)
            GestureDetector(
              onTap: () => setState(() {
                _reason = r;
                _error = '';
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _reason == r ? _C.red : _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: _reason == r ? _C.red : _C.borderStrong, width: 0.6),
                ),
                child: Text(r,
                    style: TextStyle(
                        fontSize: 13, color: _reason == r ? Colors.white : _C.text)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: _other,
          onChanged: (_) => setState(() => _error = ''),
          style: const TextStyle(fontSize: 14, color: _C.text),
          decoration: InputDecoration(
            hintText: 'Sababu nyingine (hiari)',
            hintStyle: const TextStyle(color: _C.muted, fontSize: 14),
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.borderStrong, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.blue, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _error.isEmpty
                ? const SizedBox.shrink()
                : Row(children: [
                    const Icon(MpIcons.alert, size: 16, color: _C.dangerFg),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(_error,
                          style: const TextStyle(fontSize: 13, color: _C.dangerFg)),
                    ),
                  ]),
          ),
          Semantics(
            label: 'Ghairi',
            button: true,
            child: GestureDetector(
              onTap: () => setState(() => _rejectId = null),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.borderStrong, width: 0.6),
                ),
                child: const Icon(MpIcons.back, size: 20, color: _C.text),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Kataa malipo',
            button: true,
            child: GestureDetector(
              onTap: () => _reject(m),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration:
                    BoxDecoration(color: _C.red, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(MpIcons.ban, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Kataa',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // Maelezo: hatua kama risiti (vitone) + SMS ya mchangiaji
  Widget _detail(Malipo m) {
    final s = m.status;
    final p = s == MalipoStatus.pending;

    Widget row(IconData icon, Color iconColor, String label, String value, Color valueColor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14, color: _C.text)),
          const SizedBox(width: 8),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: SizedBox(height: 2, child: CustomPaint(painter: _DotsPainter())),
            ),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row(MpIcons.send, _C.blue, 'Imetumwa', _time(m.sentAt), _C.text),
        row(
          p ? MpIcons.clock : MpIcons.eyeCheck,
          p ? _C.amber : _C.blue,
          p ? 'Inakaguliwa' : 'Imekaguliwa',
          p ? 'inasubiri' : 'SMS imeangaliwa',
          p ? _C.warningFg : _C.text,
        ),
        row(
          p
              ? MpIcons.circleDashed
              : (s == MalipoStatus.completed ? MpIcons.circleCheck : MpIcons.circleX),
          p ? _C.muted : s.color,
          'Matokeo',
          p ? 'bado' : s.label,
          p ? _C.muted : s.fg,
        ),
        if (s == MalipoStatus.rejected && (m.rejectReason ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(MpIcons.info, size: 16, color: _C.dangerFg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(m.rejectReason!,
                    style: const TextStyle(fontSize: 13, color: _C.dangerFg)),
              ),
            ]),
          ),
        const SizedBox(height: 12),
        const Row(children: [
          Icon(MpIcons.message, size: 15, color: _C.muted),
          SizedBox(width: 5),
          Text('SMS ya mchangiaji', style: TextStyle(fontSize: 12, color: _C.muted)),
        ]),
        const SizedBox(height: 4),
        if ((m.sms ?? '').isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _C.surface1,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(m.sms!,
                style: const TextStyle(fontSize: 14, height: 1.55, color: _C.text)),
          )
        else
          const Text('Hakuna SMS iliyotumwa.',
              style: TextStyle(fontSize: 13, color: _C.muted)),
      ]),
    );
  }

  // ───────────────────────── HALI TUPU ─────────────────────────
  Widget _emptyState() {
    final s = _filter;
    final hasQuery = _search.text.trim().isNotEmpty;
    final bg = s?.bg ?? _C.accentBg;
    final fg = s?.fg ?? _C.blue;
    final text = hasQuery
        ? 'Hakuna matokeo ya "${_search.text.trim()}".'
        : 'Hakuna malipo ${switch (s) {
            MalipoStatus.pending => 'yanayosubiri',
            MalipoStatus.completed => 'yaliyokamilika',
            MalipoStatus.rejected => 'yaliyokataliwa',
            null => 'yaliyopo',
          }} kwa sasa.';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 300),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 30),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(MpIcons.receipt, size: 42, color: fg),
          ),
          const SizedBox(height: 16),
          const Text('Hakuna malipo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _C.text)),
          const SizedBox(height: 6),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: _C.text2)),
          const SizedBox(height: 18),
          Material(
            color: _C.accentBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _filter = null;
                  _search.clear();
                  _searchOpen = false;
                });
                _c.loadPage(1);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                child: Text('Angalia yote',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: _C.blue)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ───────────────────────── KURASA ─────────────────────────
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
      final fg = filled ? _C.blue : _C.text;
      return Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Material(
          color: filled ? _C.accentBg : Colors.transparent,
          shape: StadiumBorder(
              side: BorderSide(
                  color: filled ? Colors.transparent : _C.borderStrong, width: 0.6)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: disabled ? null : onTap,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (left) Icon(icon, size: 18, color: fg),
                  if (left) const SizedBox(width: 6),
                  Text(text, style: TextStyle(fontSize: 14, color: fg)),
                  if (!left) const SizedBox(width: 6),
                  if (!left) Icon(icon, size: 18, color: fg),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        pill(
          icon: MpIcons.prev,
          text: 'Iliyopita',
          left: true,
          disabled: first,
          onTap: () {
            setState(() => _openId = null);
            _c.loadPage(_c.page - 1);
          },
        ),
        Text('${_c.page} / ${_c.pages}',
            style: const TextStyle(fontSize: 13, color: _C.muted)),
        pill(
          icon: MpIcons.next,
          text: 'Inayofuata',
          left: false,
          disabled: last,
          filled: true,
          onTap: () {
            setState(() => _openId = null);
            _c.loadPage(_c.page + 1);
          },
        ),
      ]),
    );
  }
}

// ═════════════════════════ DURA LA TAKWIMU ═════════════════════════
class _Seg {
  final MalipoStatus status;
  final double start; // radiani, kuanzia juu
  final double sweep; // eneo la kubonyeza
  final double draw; // sweep inayochorwa
  const _Seg(this.status, this.start, this.sweep, this.draw);
}

List<_Seg> _layoutSegments(int c, int p, int r) {
  final total = c + p + r;
  if (total == 0) return const [];
  const radius = 60.0;
  final circ = 2 * math.pi * radius;
  final out = <_Seg>[];
  var offset = 0.0;
  for (final e in [
    (MalipoStatus.completed, c),
    (MalipoStatus.pending, p),
    (MalipoStatus.rejected, r),
  ]) {
    if (e.$2 <= 0) continue;
    final len = math.max(circ * e.$2 / total, 5.0);
    out.add(_Seg(e.$1, offset / radius, len / radius, math.max(len - 3, 2) / radius));
    offset += len;
  }
  return out;
}

class _Donut extends StatefulWidget {
  final int completed, pending, rejected;
  final MalipoStatus? selected;
  final ValueChanged<MalipoStatus?> onSelect;
  final Widget center;

  const _Donut({
    required this.completed,
    required this.pending,
    required this.rejected,
    required this.selected,
    required this.onSelect,
    required this.center,
  });

  @override
  State<_Donut> createState() => _DonutState();
}

class _DonutState extends State<_Donut> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250), value: 1);
  MalipoStatus? _prev;

  @override
  void didUpdateWidget(covariant _Donut old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _prev = old.selected;
      _a.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _tap(Offset p) {
    const c = Offset(88, 88);
    final dx = p.dx - c.dx, dy = p.dy - c.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 42) {
      widget.onSelect(null);
      return;
    }
    if (dist > 78) return;
    var ang = math.atan2(dy, dx) + math.pi / 2;
    if (ang < 0) ang += 2 * math.pi;
    for (final s in _layoutSegments(widget.completed, widget.pending, widget.rejected)) {
      if (ang >= s.start && ang < s.start + s.sweep) {
        widget.onSelect(s.status);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 176,
      child: GestureDetector(
        onTapUp: (d) => _tap(d.localPosition),
        child: Stack(children: [
          AnimatedBuilder(
            animation: _a,
            builder: (_, __) => CustomPaint(
              size: const Size(176, 176),
              painter: _DonutPainter(
                segs: _layoutSegments(widget.completed, widget.pending, widget.rejected),
                selected: widget.selected,
                prev: _prev,
                t: Curves.easeOut.transform(_a.value),
              ),
            ),
          ),
          IgnorePointer(child: Center(child: widget.center)),
        ]),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Seg> segs;
  final MalipoStatus? selected;
  final MalipoStatus? prev;
  final double t;
  const _DonutPainter(
      {required this.segs, required this.selected, required this.prev, required this.t});

  double _w(MalipoStatus s, MalipoStatus? sel) => sel == s ? 22 : 16;
  double _o(MalipoStatus s, MalipoStatus? sel) => (sel != null && sel != s) ? 0.3 : 1;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 60.0;
    final rect = Rect.fromCircle(center: const Offset(88, 88), radius: radius);
    canvas.drawCircle(
      const Offset(88, 88),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = _C.surface1,
    );
    for (final s in segs) {
      final w = _w(s.status, prev) + (_w(s.status, selected) - _w(s.status, prev)) * t;
      final o = _o(s.status, prev) + (_o(s.status, selected) - _o(s.status, prev)) * t;
      canvas.drawArc(
        rect,
        -math.pi / 2 + s.start,
        s.draw,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.butt
          ..color = s.status.color.withAlpha((255 * o).round()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segs.length != segs.length ||
      old.selected != selected ||
      old.prev != prev ||
      old.t != t ||
      !_sameSegs(old.segs, segs);

  bool _sameSegs(List<_Seg> a, List<_Seg> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].sweep != b[i].sweep) return false;
    }
    return true;
  }
}

// ───────────────────────── Vidogo vya mapambo ─────────────────────────
class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _C.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _C.green.withAlpha((255 * (1 - _a.value) * 0.5).round()),
              spreadRadius: _a.value * 7,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  final String label;
  final Color color;
  final Color fg;
  const _Stamp({required this.label, required this.color, required this.fg});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.rotate(
          angle: (-14 + 8 * v) * math.pi / 180,
          child: Transform.scale(scale: 1.7 - 0.7 * v, child: child),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            maxLines: 1,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: fg)),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _C.borderStrong
      ..strokeWidth = 1.5;
    // Mstari wa vipande unaanzia ukingo hadi ukingo (kufidia padding ya kushoto 22 na kulia 14).
    var x = -22.0;
    while (x < size.width + 14) {
      canvas.drawLine(Offset(x, 0), Offset(x + 6, 0), p);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _C.borderStrong
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawPoints(PointMode.points, [Offset(x, size.height / 2)], p);
      x += 4;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================================
// INTEGRATION LAYER — API halisi ya backend (Kubadilishana / EssTransfer)
//
//   DATA   → GET /payments/admin/all (adminAllDonations):
//              order_id, user_name, phone, amount, status
//              ('verifying'|'approved'|'rejected'), created_at, sms_text, note
//            WS 'notification' (payment.submitted / payment.message) → reload
//   APPROVE→ POST /payments/admin/{order_id}/approve  (note: null)
//   REJECT → POST /payments/admin/{order_id}/reject   (note: sababu)
//   UNDO   → API ya tendua HAIPATIKANI kwenye backend ya sasa — undo ya UI
//            inafanya kazi ndani ya app tu (bila kupiga API); refresh inarejesha
//            hali halisi ya server.
//   OFFLINE→ NetworkService().isOffline → OfflineQueue (kama ukurasa wa zamani)
//   BADGE  → AdminBadgeService().refresh() + BadgeController.decrement(NavItem.malipo)
//            (badge ya malipo inaisha TU baada ya hatua — kama ilivyo)
//   UKURASA→ upagaji wa upande wa app (12 kwa ukurasa).
// ============================================================================

const int _kMalipoPerPage = 12;

DateTime _malipoDate(dynamic iso) {
  final s = iso?.toString() ?? '';
  if (s.isEmpty) return DateTime.now();
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

class ApiMalipoController extends MalipoController {
  ApiMalipoController();

  List<Malipo> _all = [];
  bool _busy = false;

  int _pagesFor(int n) => (n / _kMalipoPerPage).ceil().clamp(1, 9999);

  void _applyPage() {
    final start = ((page - 1) * _kMalipoPerPage).clamp(0, _all.length);
    final end = (start + _kMalipoPerPage).clamp(0, _all.length);
    items = _all.sublist(start, end);
  }

  Malipo _map(Map<String, dynamic> m) {
    final status = switch ((m['status'] ?? 'verifying').toString()) {
      'approved' => MalipoStatus.completed,
      'rejected' => MalipoStatus.rejected,
      _ => MalipoStatus.pending,
    };
    return Malipo(
      id: (m['order_id'] ?? m['id'] ?? '').toString(),
      name: _titleCase((m['user_name'] ?? '').toString()),
      phone: (m['phone'] ?? '').toString(),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      code: (m['order_id'] ?? '').toString(),
      sentAt: _malipoDate(m['created_at']),
      status: status,
      sms: (m['sms_text'] ?? '').toString(),
      rejectReason: (m['note'] ?? '').toString(),
    );
  }

  static String _titleCase(String v) => v
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  /// PAKIA malipo yote kutoka API, halafu gawanya kurasa. Inaitwa na page
  /// (ukifungua) na shell (WS event).
  Future<void> load() async {
    if (_busy) return;
    _busy = true;
    try {
      final res = await ApiService().adminAllDonations();
      final data = res.data;
      final raw = data is List
          ? data
          : (asMap(data)['payments'] as List? ??
              asMap(data)['results'] as List? ??
              const []);
      _all = [for (final e in raw) _map(asMap(e))];
      _recompute();
      notifyListeners();
    } catch (e) {
      AppToast.error(friendlyError(e));
    } finally {
      _busy = false;
    }
  }

  void _recompute() {
    pendingCount = _all.where((m) => m.status == MalipoStatus.pending).length;
    completedCount = _all.where((m) => m.status == MalipoStatus.completed).length;
    rejectedCount = _all.where((m) => m.status == MalipoStatus.rejected).length;
    completedAmount =
        _all.where((m) => m.status == MalipoStatus.completed).fold(0, (s, m) => s + m.amount);
    pendingAmount =
        _all.where((m) => m.status == MalipoStatus.pending).fold(0, (s, m) => s + m.amount);
    pages = _pagesFor(_all.length);
    if (page > pages) page = pages;
    _applyPage();
  }

  void _afterAction(String orderId, Malipo updated) {
    final i = _all.indexWhere((x) => x.id == orderId);
    if (i >= 0) _all[i] = updated;
    _recompute();
    notifyListeners();
    // Badge ya Malipo inaisha TU baada ya hatua (kama ukurasa wa zamani).
    AdminBadgeService().refresh();
    BadgeController.instance.decrement(NavItem.malipo);
  }

  @override
  Future<void> approve(Malipo m) async {
    // Undo ya UI inatumia hali iliyohifadhiwa ya base class — tunaiweka
    // wenyewe ili banner ya "Tendua" ifanye kazi.
    final before = m;
    if (NetworkService().isOffline) {
      await OfflineQueue().enqueue(
        type: 'approve_payment',
        payload: {'order_id': m.id},
        displayText: 'Thibitisha malipo',
      );
      AppToast.info('Imewekwa foleni. Itatumwa mtandao ukiingia');
      return;
    }
    try {
      await ApiService().adminApproveDonation(m.id);
      _undoBefore = before;
      _afterAction(
          m.id, m.copyWith(status: MalipoStatus.completed, clearReason: true));
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Future<void> reject(Malipo m, String reason) async {
    final before = m;
    if (NetworkService().isOffline) {
      await OfflineQueue().enqueue(
        type: 'reject_payment',
        payload: {'order_id': m.id, 'note': reason},
        displayText: 'Kataa malipo',
      );
      AppToast.info('Imewekwa foleni. Itatumwa mtandao ukiingia');
      return;
    }
    try {
      await ApiService().adminRejectDonation(m.id, note: reason);
      _undoBefore = before;
      _afterAction(
          m.id, m.copyWith(status: MalipoStatus.rejected, rejectReason: reason));
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Future<void> undo() async {
    // API ya tendua haipo — undo inarekebisha UI tu (kama base class);
    // refresh ijayo (WS/timer) inaleta hali halisi ya server.
    super.undo();
  }

  @override
  Future<void> loadPage(int p) async {
    page = p.clamp(1, pages);
    _applyPage();
    notifyListeners();
  }
}

// ----------------------------------------------------------------------------
// Ukurasa wa Malipo kwenye AdminShell (nav index 6) — controller ya API halisi.
// WS 'notification' (payment.submitted / payment.message) → live reload.
// ----------------------------------------------------------------------------
class AdminMalipoScreenPage extends StatefulWidget {
  const AdminMalipoScreenPage({super.key});

  @override
  State<AdminMalipoScreenPage> createState() => _AdminMalipoScreenPageState();
}

class _AdminMalipoScreenPageState extends State<AdminMalipoScreenPage> {
  late final ApiMalipoController _controller;

  void _onWs(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? payload['event'])?.toString() ?? '';
    if (type == 'payment.submitted' || type == 'payment.message') {
      _controller.load();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = ApiMalipoController();
    _controller.load();
    WebSocketService().on('notification', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MalipoScreen(controller: _controller);
  }
}
