// =============================================================================
//  waliopigiana_page.dart  -  Kubadilishana (EssTransfer) admin panel
//  "Waliopigiana" (call history) page — design iliyokubaliwa (mockup).
//  UI imenakiliwa kama ilivyo; integration layer (API halisi) ndiyo mpya.
//
//  Dependencies (zipo tayari pubspec.yaml):
//    flutter_tabler_icons: 1.43.0
//    url_launcher: ^6.3.1
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../utils/safe_cast.dart';
import '../../widgets/app_toast.dart';

// ----------------------------------------------------------------------------
// CONFIG: action button style on the expanded card.
//   square = small rounded boxes (icon only)  <- default
//   circle = small circles (icon only)
// ----------------------------------------------------------------------------
enum ActionButtonStyle { square, circle }

const ActionButtonStyle kActionButtonStyle = ActionButtonStyle.square;

// ----------------------------------------------------------------------------
// Colors (from the approved mockup)
// ----------------------------------------------------------------------------
class _C {
  static const blue = Color(0xFF1A3FA8);
  static const ink = Color(0xFF14224D);
  static const title = Color(0xFF0F1B4A);
  static const muted = Color(0xFF5A6B92);
  static const muted2 = Color(0xFF6B7BA3);
  static const muted3 = Color(0xFF7686AB);
  static const placeholder = Color(0xFF8A9BC2);
  static const border = Color(0xFFD6E2F6);
  static const borderSoft = Color(0xFFDFE7F7);
  static const boxBg = Color(0xFFF7F8FC);
  static const routeBg = Color(0xFFF6F8FD);
  static const chipBg = Color(0xFFE8EEFB);
  static const countBg = Color(0xFFE6EDFB);
  static const avatarBg = Color(0xFFEEF2FC);
  static const avatarBorder = Color(0xFFCDD9F3);
  static const dash = Color(0xFFA9BDE8);
  static const dashSoft = Color(0xFFC5D3F0);
  static const iconBoxBorder = Color(0xFFD6D9E0);
  static const iconBoxBg = Color(0xFFF7F8FA);
  static const chevBorder = Color(0xFFD6DBE8);
  static const liveBg = Color(0xFFDCF5E5);
  static const liveFg = Color(0xFF0F6E3A);
  static const liveDot = Color(0xFF1D9E5A);
  static const headIconBg = Color(0xFFE3EAFC);
  static const waBg = Color(0xFFDCF5E5);
  static const waFg = Color(0xFF0F6E3A);
  static const simuBg = Color(0xFFE1E9FB);
  static const simuFg = Color(0xFF1A3FA8);
  static const smsBg = Color(0xFFFDECC8);
  static const smsFg = Color(0xFF7A4A05);
}

// ----------------------------------------------------------------------------
// Models
// ----------------------------------------------------------------------------
enum CallType { simu, sms, whatsapp }

extension CallTypeX on CallType {
  String get label => switch (this) {
        CallType.simu => 'Simu',
        CallType.sms => 'SMS',
        CallType.whatsapp => 'WhatsApp',
      };
  IconData get icon => switch (this) {
        CallType.simu => TablerIcons.phone,
        CallType.sms => TablerIcons.message_2,
        CallType.whatsapp => TablerIcons.brand_whatsapp,
      };
  Color get bg => switch (this) {
        CallType.simu => _C.simuBg,
        CallType.sms => _C.smsBg,
        CallType.whatsapp => _C.waBg,
      };
  Color get fg => switch (this) {
        CallType.simu => _C.simuFg,
        CallType.sms => _C.smsFg,
        CallType.whatsapp => _C.waFg,
      };

  /// Thamani ya `contact_type` kwenye API ('call' | 'sms' | 'whatsapp').
  String get apiValue => switch (this) {
        CallType.simu => 'call',
        CallType.sms => 'sms',
        CallType.whatsapp => 'whatsapp',
      };

  static CallType fromApi(String? v) => switch (v) {
        'sms' => CallType.sms,
        'whatsapp' => CallType.whatsapp,
        _ => CallType.simu,
      };
}

class Participant {
  final String name;
  final String idara;
  final String cheo;
  final String mkoa;
  final String phone; // local format, e.g. 0719345608

  const Participant({
    required this.name,
    required this.idara,
    required this.cheo,
    required this.mkoa,
    required this.phone,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  /// 0719345608 -> 0719 345 608
  String get phonePretty {
    final d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.length == 10) {
      return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
    }
    return phone;
  }
}

class CallRecord {
  final String id;
  final CallType type;
  final Participant from; // Mtumaji
  final Participant to; // Mpokeaji
  final DateTime time;

  const CallRecord({
    required this.id,
    required this.type,
    required this.from,
    required this.to,
    required this.time,
  });

  /// Mapi kutoka GET /messages/admin/contacts (moja kwa moja kutoka backend):
  /// contact_type, from_/to_full_name, from_/to_phone, from_/to_cadre,
  /// from_/to_category, from_/to_region, initiated_at.
  factory CallRecord.fromApi(Map<String, dynamic> e, int fallbackIndex) {
    final idaraOf = (dynamic cat) {
      switch (cat?.toString()) {
        case 'education':
          return 'Elimu';
        case 'health':
          return 'Afya';
        case 'kilimo':
          return 'Kilimo na Ufugaji';
        case 'watumishi_wa_umma':
          return 'Watumishi wa Umma';
        default:
          return (cat == null || cat.toString().isEmpty)
              ? ''
              : cat.toString();
      }
    };
    final initTs = e['initiated_at']?.toString() ?? '';
    DateTime time;
    try {
      time = initTs.isEmpty ? DateTime.now() : DateTime.parse(initTs).toLocal();
    } catch (_) {
      time = DateTime.now();
    }
    return CallRecord(
      id: (e['id'] ?? e['contact_id'] ?? 'c$fallbackIndex').toString(),
      type: CallTypeX.fromApi(e['contact_type']?.toString()),
      from: Participant(
        name: e['from_full_name']?.toString() ?? '',
        idara: idaraOf(e['from_category']),
        cheo: e['from_cadre']?.toString() ?? '',
        mkoa: e['from_region']?.toString() ?? '',
        phone: (e['from_phone'] ?? '').toString().replaceAll('+255', '0'),
      ),
      to: Participant(
        name: e['to_full_name']?.toString() ?? '',
        idara: idaraOf(e['to_category']),
        cheo: e['to_cadre']?.toString() ?? '',
        mkoa: e['to_region']?.toString() ?? '',
        phone: (e['to_phone'] ?? '').toString().replaceAll('+255', '0'),
      ),
      time: time,
    );
  }
}

// ----------------------------------------------------------------------------
// Page
// ----------------------------------------------------------------------------
class WaliopigianaPage extends StatefulWidget {
  /// Real records from backend. If null, demo data is shown.
  final List<CallRecord>? records;

  /// Called once when the page opens (use it to clear the drawer badge).
  final VoidCallback? onOpened;

  const WaliopigianaPage({super.key, this.records, this.onOpened});

  @override
  State<WaliopigianaPage> createState() => _WaliopigianaPageState();
}

class _WaliopigianaPageState extends State<WaliopigianaPage> {
  static const int _perPage = 5;

  final _search = TextEditingController();
  final Set<String> _open = {};
  CallType? _filter; // null = Zote
  String _query = '';
  int _page = 1;

  // ── API halisi (inatumika records == null) ──
  bool _loading = false;
  String? _error;
  List<CallRecord> _apiList = [];

  /// Orodha inayotumika: records za nje (tests/zenye data) AU API halisi.
  List<CallRecord> get _all {
    if (widget.records != null) return widget.records!;
    return _apiList;
  }

  @override
  void initState() {
    super.initState();
    if (widget.records == null) _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onOpened?.call());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().getContactActivity(limit: 300);
      if (!mounted) return;
      final data = res.data;
      final raw = data is List
          ? data
          : (asMap(data)['contacts'] ?? asMap(data)['results'] as List? ?? []);
      setState(() {
        _apiList = [
          for (var i = 0; i < raw.length; i++)
            CallRecord.fromApi(asMap(raw[i]), i),
        ]..sort((a, b) => b.time.compareTo(a.time));
        _loading = false;
        _page = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  bool _matchesQuery(CallRecord r) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    String s(Participant p) =>
        '${p.name} ${p.idara} ${p.cheo} ${p.mkoa} ${p.phone}'.toLowerCase();
    return s(r.from).contains(q) || s(r.to).contains(q);
  }

  int _count(CallType? t) =>
      _all.where((r) => (t == null || r.type == t) && _matchesQuery(r)).length;

  List<CallRecord> get _view {
    final filtered = _all
        .where((r) => (_filter == null || r.type == _filter) && _matchesQuery(r))
        .toList();
    if (widget.records != null) return filtered;
    // API halisi inakuja imeshapangwa kutoka server; kama mtumiaji ame-sort
    // kupitia init, hapa tunahakikisha mpya zinaelekea juu.
    return filtered;
  }

  void _setQuery(String v) => setState(() {
        _query = v.trim();
        _page = 1;
      });

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final pages = (view.length / _perPage).ceil().clamp(1, 9999);
    if (_page > pages) _page = pages;
    final start = (_page - 1) * _perPage;
    final slice = view.skip(start).take(_perPage).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            _header(),
            const SizedBox(height: 10),
            const Text(
              'Watumiaji waliowasiliana kwa simu, SMS na WhatsApp.',
              style: TextStyle(color: _C.muted, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 12),
            _searchBox(),
            const SizedBox(height: 12),
            _examples(),
            const SizedBox(height: 12),
            _filters(),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(color: _C.blue)),
              )
            else if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: _C.muted, fontSize: 14)),
              ),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(TablerIcons.refresh, size: 16),
                  label: const Text('Jaribu tena'),
                ),
              ),
            ] else ...[
              if (view.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Text(
                    'Inaonyesha ${start + 1}–${start + slice.length} kati ya ${view.length}',
                    style: const TextStyle(color: _C.muted3, fontSize: 14),
                  ),
                ),
              ..._groupedCards(slice),
              if (view.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Hakuna matokeo',
                        style: TextStyle(color: _C.muted, fontSize: 14)),
                  ),
                ),
              if (view.isNotEmpty) _pagination(pages),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Header --------------------------------------------------------------
  Widget _header() => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.headIconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(TablerIcons.phone_call, size: 22, color: _C.blue),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Waliopigiana',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w500, color: _C.title),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _C.liveBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircleAvatar(radius: 4, backgroundColor: _C.liveDot),
                SizedBox(width: 6),
                Text('Live',
                    style: TextStyle(color: _C.liveFg, fontSize: 13)),
              ],
            ),
          ),
        ],
      );

  // ---- Search box (single field, icon on the RIGHT, X appears when typing) --
  Widget _searchBox() => SizedBox(
        height: 48,
        child: TextField(
          controller: _search,
          onChanged: _setQuery,
          style: const TextStyle(fontSize: 15, color: _C.ink),
          decoration: InputDecoration(
            hintText: 'Andika jina, mkoa au idara',
            hintStyle: const TextStyle(color: _C.placeholder, fontSize: 15),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_search.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _search.clear();
                      _setQuery('');
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: _C.avatarBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(TablerIcons.x,
                          size: 16, color: _C.muted),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(TablerIcons.search, size: 20, color: _C.blue),
                ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _C.blue, width: 1.5),
            ),
          ),
        ),
      );

  // ---- "Mfano:" chips (wrap, never overflow) --------------------------------
  Widget _examples() {
    const samples = ['Iringa', 'Felix', 'Afya', 'Teacher'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Mfano:',
            style: TextStyle(color: _C.muted3, fontSize: 13.5)),
        for (final s in samples)
          GestureDetector(
            onTap: () {
              _search.text = s;
              _search.selection =
                  TextSelection.collapsed(offset: _search.text.length);
              _setQuery(s);
            },
            child: Container(
              height: 28,
              padding: const EdgeInsets.only(left: 9, right: 11),
              decoration: BoxDecoration(
                color: _C.chipBg,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(TablerIcons.search, size: 14, color: _C.muted),
                  const SizedBox(width: 6),
                  Text(s,
                      style: const TextStyle(
                          fontSize: 13.5, color: Color(0xFF2C3E6E))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---- Filter pills (wrap, all visible, no horizontal scroll) ----------------
  Widget _filters() {
    final items = <(CallType?, String, IconData?)>[
      (null, 'Zote', null),
      (CallType.simu, 'Simu', TablerIcons.phone),
      (CallType.sms, 'SMS', TablerIcons.message_2),
      (CallType.whatsapp, 'WhatsApp', TablerIcons.brand_whatsapp),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items) _pill(it.$1, it.$2, it.$3),
      ],
    );
  }

  Widget _pill(CallType? t, String label, IconData? icon) {
    final on = _filter == t;
    return GestureDetector(
      onTap: () => setState(() {
        _filter = t;
        _page = 1;
      }),
      child: Container(
        height: 42,
        padding: const EdgeInsets.only(left: 14, right: 6),
        decoration: BoxDecoration(
          color: on ? _C.blue : Colors.white,
          border: Border.all(color: on ? _C.blue : _C.border, width: 1.5),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: on ? Colors.white : _C.ink),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                color: on ? Colors.white : _C.ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 28),
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? Colors.white.withValues(alpha: .25) : _C.countBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${_count(t)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: on ? Colors.white : _C.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Grouped cards (Jana / Juzi with full date + year) -----------------
  List<Widget> _groupedCards(List<CallRecord> items) {
    final out = <Widget>[];
    String? last;
    for (final r in items) {
      final g = _groupOf(r.time);
      if (g.$1 != last) {
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(g.$1,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _C.ink)),
              if (g.$2.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(g.$2,
                    style: const TextStyle(fontSize: 13.5, color: _C.muted2)),
              ],
            ],
          ),
        ));
        last = g.$1;
      }
      out.add(_CallCard(
        record: r,
        open: _open.contains(r.id),
        onToggle: () => setState(() {
          if (!_open.add(r.id)) _open.remove(r.id);
        }),
      ));
    }
    return out;
  }

  /// Returns (label, dateText). Leo/Jana/Juzi get label + full date;
  /// older days show only the full date.
  (String, String) _groupOf(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    final full = _fullDate(day);
    if (diff == 0) return ('Leo', full);
    if (diff == 1) return ('Jana', full);
    if (diff == 2) return ('Juzi', full);
    return (full, '');
  }

  // ---- Pagination: small Iliyopita / Inayofuata buttons --------------------
  Widget _pagination(int pages) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pageBtn('Iliyopita', TablerIcons.chevron_left, true,
                _page > 1 ? () => setState(() => _page--) : null),
            Flexible(
              child: Text('Ukurasa $_page / $pages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted2, fontSize: 13)),
            ),
            _pageBtn('Inayofuata', TablerIcons.chevron_right, false,
                _page < pages ? () => setState(() => _page++) : null),
          ],
        ),
      );

  Widget _pageBtn(String label, IconData icon, bool iconFirst, VoidCallback? onTap) {
    final enabled = onTap != null;
    final children = <Widget>[
      if (iconFirst) Icon(icon, size: 15, color: _C.blue),
      if (iconFirst) const SizedBox(width: 4),
      Flexible(
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: _C.blue)),
      ),
      if (!iconFirst) const SizedBox(width: 4),
      if (!iconFirst) Icon(icon, size: 15, color: _C.blue),
    ];
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: _Pressable(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _C.avatarBorder),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Call card (collapsed timeline  <->  expanded details)
// ----------------------------------------------------------------------------
class _CallCard extends StatelessWidget {
  final CallRecord record;
  final bool open;
  final VoidCallback onToggle;

  const _CallCard({
    required this.record,
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _C.border, width: 1.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top row: type chip, time, chevron
          Row(
            children: [
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: r.type.bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(r.type.icon, size: 19, color: r.type.fg),
                    const SizedBox(width: 7),
                    Text(r.type.label,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: r.type.fg)),
                  ],
                ),
              ),
              const Spacer(),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(TablerIcons.clock, size: 19, color: _C.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(_hm(r.time),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, color: _C.muted)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Pressable(
                onTap: onToggle,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _C.chevBorder),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(TablerIcons.chevron_down,
                        size: 17, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: open ? _expanded(r) : _collapsed(r),
          ),
        ],
      ),
    );
  }

  // ---- Collapsed: dotted timeline ------------------------------------------
  Widget _collapsed(CallRecord r) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            _timelineRow('Mtumaji', r.from, isFirst: true),
            _timelineRow('Mpokeaji', r.to, isFirst: false),
          ],
        ),
      );

  Widget _timelineRow(String role, Participant p, {required bool isFirst}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Stack(
              children: [
                if (isFirst)
                  Positioned(
                    left: 6,
                    top: 24,
                    bottom: 0,
                    child: CustomPaint(
                      size: const Size(2, double.infinity),
                      painter: _DashedLinePainter(
                          vertical: true, color: _C.dash, strokeWidth: 2),
                    ),
                  ),
                Positioned(
                  left: 0,
                  top: 6,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isFirst ? Colors.white : _C.blue,
                      shape: BoxShape.circle,
                      border: isFirst
                          ? Border.all(color: _C.blue, width: 3.5)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isFirst ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role,
                      style: const TextStyle(
                          fontSize: 13.5, color: Color(0xFF8190B2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(p.name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: _C.ink)),
                  ),
                  Text('${p.idara} · ${p.cheo}',
                      style: const TextStyle(fontSize: 14.5, color: _C.muted)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(TablerIcons.map_pin, size: 15, color: _C.blue),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(p.mkoa,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, color: _C.blue)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Expanded: Mtumaji block, dashed divider, Mpokeaji block -------------
  Widget _expanded(CallRecord r) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PersonBlock(
                role: 'Mtumaji', person: r.from, to: r.to, filledChip: true),
            const SizedBox(height: 18),
            SizedBox(
              height: 1.5,
              width: double.infinity,
              child: CustomPaint(
                painter: _DashedLinePainter(
                    vertical: false, color: _C.dashSoft, strokeWidth: 1.5),
              ),
            ),
            const SizedBox(height: 18),
            _PersonBlock(
                role: 'Mpokeaji', person: r.to, to: null, filledChip: false),
          ],
        ),
      );
}

// ----------------------------------------------------------------------------
// One person block inside the expanded card. Mtumaji and Mpokeaji use the SAME
// layout; only Mtumaji shows the Anatoka -> Anaenda route box.
// ----------------------------------------------------------------------------
class _PersonBlock extends StatelessWidget {
  final String role;
  final Participant person;
  final Participant? to; // non-null => show route box (Mtumaji only)
  final bool filledChip;

  const _PersonBlock({
    required this.role,
    required this.person,
    required this.to,
    required this.filledChip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // avatar + name + role chip
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _C.avatarBg,
                shape: BoxShape.circle,
                border: Border.all(color: _C.avatarBorder, width: 1.5),
              ),
              child: Text(person.initials,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _C.blue)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: _C.ink)),
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: filledChip ? _C.blue : Colors.white,
                      border: Border.all(color: _C.blue),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(role,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: filledChip ? Colors.white : _C.blue)),
                  ),
                ],
              ),
            ),
          ],
        ),

        // route box (Mtumaji only)
        if (to != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _C.routeBg,
              border: Border.all(color: _C.borderSoft),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _routeEnd('Anatoka', person.mkoa, CrossAxisAlignment.start),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 6, right: 6, top: 14),
                    child: _DashedArrow(),
                  ),
                ),
                _routeEnd('Anaenda', to!.mkoa, CrossAxisAlignment.end),
              ],
            ),
          ),
        ],

        // number box: label, number + copy, divider, Idara / Cheo
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.boxBg,
            border: Border.all(color: _C.borderSoft),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(TablerIcons.phone, size: 16, color: _C.blue),
                  SizedBox(width: 6),
                  Text('Namba ya simu',
                      style: TextStyle(fontSize: 14, color: _C.muted2)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(person.phonePretty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: _C.ink)),
                  ),
                  _Pressable(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: person.phone));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                          content: Text('Namba imenakiliwa'),
                          duration: Duration(seconds: 1),
                        ));
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _C.avatarBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(TablerIcons.copy,
                          size: 18, color: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: _C.borderSoft),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _kv(TablerIcons.building, 'Idara', person.idara),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _kv(TablerIcons.briefcase, 'Cheo', person.cheo)),
                ],
              ),
            ],
          ),
        ),

        // action buttons: icon only (Simu, SMS, WhatsApp)
        const SizedBox(height: 14),
        _ActionButtons(phone: person.phone),
      ],
    );
  }

  Widget _routeEnd(String label, String mkoa, CrossAxisAlignment align) =>
      Column(
        crossAxisAlignment: align,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _C.muted2)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(TablerIcons.map_pin, size: 17, color: _C.blue),
              const SizedBox(width: 4),
              Text(mkoa,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: _C.blue)),
            ],
          ),
        ],
      );

  Widget _kv(IconData icon, String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: _C.blue),
              const SizedBox(width: 5),
              Text(k, style: const TextStyle(fontSize: 14, color: _C.muted2)),
            ],
          ),
          const SizedBox(height: 4),
          Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w500, color: _C.ink)),
        ],
      );
}

// ----------------------------------------------------------------------------
// Action buttons (Simu / SMS / WhatsApp), icon only, with press animation
// ----------------------------------------------------------------------------
class _ActionButtons extends StatelessWidget {
  final String phone;
  const _ActionButtons({required this.phone});

  String get _digits => phone.replaceAll(RegExp(r'\D'), '');

  String get _intl {
    final d = _digits;
    if (d.startsWith('0')) return '255${d.substring(1)}';
    return d;
  }

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      AppToast.error('Imeshindikana kufungua');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, VoidCallback)>[
      (TablerIcons.phone_call, () => _open(Uri.parse('tel:$_digits'))),
      (TablerIcons.message_2, () => _open(Uri.parse('sms:$_digits'))),
      (TablerIcons.brand_whatsapp, () => _open(Uri.parse('https://wa.me/$_intl'))),
    ];

    if (kActionButtonStyle == ActionButtonStyle.circle) {
      return Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _Pressable(
              onTap: actions[i].$2,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _C.iconBoxBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.iconBoxBorder),
                ),
                child: Icon(actions[i].$1, size: 21, color: Colors.black),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(
            child: _Pressable(
              onTap: actions[i].$2,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _C.iconBoxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.iconBoxBorder),
                ),
                child: Icon(actions[i].$1, size: 22, color: Colors.black),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Small helpers
// ----------------------------------------------------------------------------

/// Press animation: scales down to 0.92 while pressed.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .92 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final bool vertical;
  final Color color;
  final double strokeWidth;
  _DashedLinePainter({
    required this.vertical,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    const dash = 5.0, gap = 4.0;
    final len = vertical ? size.height : size.width;
    for (double d = 0; d < len; d += dash + gap) {
      final end = (d + dash).clamp(0, len).toDouble();
      if (vertical) {
        canvas.drawLine(Offset(strokeWidth / 2, d), Offset(strokeWidth / 2, end), p);
      } else {
        canvas.drawLine(Offset(d, strokeWidth / 2), Offset(end, strokeWidth / 2), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) =>
      old.color != color || old.vertical != vertical;
}

/// Dashed horizontal line ending with an arrow (inside the route box).
class _DashedArrow extends StatelessWidget {
  const _DashedArrow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(
                  vertical: false, color: _C.dash, strokeWidth: 2),
              child: const SizedBox(height: 2, width: double.infinity),
            ),
          ),
          const Icon(TablerIcons.arrow_right, size: 20, color: _C.blue),
        ],
      ),
    );
  }
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _months = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];

String _fullDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
