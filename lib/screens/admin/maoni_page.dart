// maoni_page.dart
// Ukurasa wa Maoni - muundo wa gazeti (nukuu + jibu linalohaririwa papo hapo).
// Hakuna AppBar, drawer wala bottom navigation. Weka ndani ya Scaffold yako.
// Hakuna package za nje: unahitaji flutter/material.dart tu.

import 'dart:async';import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../services/admin_badge_service.dart';
import '../../widgets/app_toast.dart' show friendlyError;
import '../../widgets/app_drawer.dart' show BadgeController, NavItem;

// ---------------------------------------------------------------------------
// Rangi na mitindo
// ---------------------------------------------------------------------------
const Color _ac = Color(0xFF1F5FD6); // bluu ya pekee
const Color _ink = Color(0xFF2A3550);
const Color _muted = Color(0xFF8591A3);
const Color _line = Color(0xFFE8EBF0);
const Color _lineStrong = Color(0xFFD3D9E4);
const Color _danger = Color(0xFFD92D20);
const Color _fieldBg = Color(0xFFF3F6FB);

const List<String> _serifFallback = ['Georgia', 'Noto Serif', 'Times New Roman'];

TextStyle _serif(
  double size, {
  FontStyle? style,
  Color color = _ink,
  double height = 1.45,
}) =>
    TextStyle(
      fontFamily: 'serif',
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      fontStyle: style,
      color: color,
      height: height,
    );

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class Maoni {
  final int id;
  final String name;
  final String phone;
  final String date; // mfano "9 Okt"
  final String time; // mfano "07:41"
  final String message;
  String reply; // tupu = haijajibiwa

  Maoni({
    required this.id,
    required this.name,
    required this.phone,
    required this.date,
    required this.time,
    required this.message,
    this.reply = '',
  });

  bool get replied => reply.trim().isNotEmpty;
}

enum _Tab { all, unanswered, answered }

// ---------------------------------------------------------------------------
// Ukurasa
// ---------------------------------------------------------------------------
class MaoniPage extends StatefulWidget {
  /// Orodha ya maoni (badilisha na data kutoka API yako).
  final List<Maoni> items;

  /// Inaitwa mtumiaji akibonyeza "Tuma". Tupa exception ikishindikana.
  /// Ukiiacha null, jibu linahifadhiwa kwenye orodha ya ndani tu.
  final Future<void> Function(Maoni item, String text)? onSendReply;

  /// Inaitwa ukurasa unafunguliwa (kupakia data mpya).
  final VoidCallback? onRefresh;

  /// True = inaonyesha spinner (data ya kwanza bado inapakiwa).
  final bool loading;

  /// True = imepata data ya kwanza bila kufanikiwa (kupitia _error non-null
  /// from the caller).
  final String? loadError;

  /// Maoni kwa kila ukurasa.
  final int perPage;

  const MaoniPage({
    super.key,
    required this.items,
    this.onSendReply,
    this.onRefresh,
    this.loading = false,
    this.loadError,
    this.perPage = 3,
  });

  @override
  State<MaoniPage> createState() => _MaoniPageState();
}

class _MaoniPageState extends State<MaoniPage> {
  _Tab _tab = _Tab.all;
  int _page = 1;
  String _query = '';
  int? _editingId;
  String? _error;
  bool _sending = false;

  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _replyCtrl = TextEditingController();
  final _replyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  // ----- data -----
  List<Maoni> _filtered() {
    final q = _query.trim().toLowerCase();
    return widget.items.where((i) {
      final okTab = _tab == _Tab.all ||
          (_tab == _Tab.unanswered && !i.replied) ||
          (_tab == _Tab.answered && i.replied);
      final okQuery = q.isEmpty ||
          '${i.name} ${i.phone} ${i.message}'.toLowerCase().contains(q);
      return okTab && okQuery;
    }).toList();
  }

  // ----- vitendo -----
  void _resetEditing() {
    _editingId = null;
    _error = null;
  }

  void _setTab(_Tab t) => setState(() {
        _tab = t;
        _page = 1;
        _resetEditing();
      });

  void _setPage(int p, int pages) {
    if (p < 1 || p > pages) return;
    setState(() {
      _page = p;
      _resetEditing();
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _startEdit(Maoni i) {
    setState(() {
      _editingId = i.id;
      _error = null;
      _replyCtrl.text = i.reply;
      _replyCtrl.selection =
          TextSelection.collapsed(offset: _replyCtrl.text.length);
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _replyFocus.requestFocus());
  }

  Future<void> _send(Maoni i) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Andika jibu kwanza');
      return;
    }
    setState(() => _sending = true);
    try {
      if (widget.onSendReply != null) {
        await widget.onSendReply!(i, text);
      }
      i.reply = text;
      if (!mounted) return;
      setState(_resetEditing);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Jibu limetumwa', textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _ink,
            duration: const Duration(milliseconds: 1600),
            shape: const StadiumBorder(),
            width: 180,
          ),
        );
    } catch (_) {
      if (mounted) setState(() => _error = 'Imeshindikana kutuma. Jaribu tena.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ----- build -----
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final pages =
        math.max(1, (filtered.length + widget.perPage - 1) ~/ widget.perPage);
    final page = math.min(math.max(_page, 1), pages);
    final visible =
        filtered.skip((page - 1) * widget.perPage).take(widget.perPage).toList();

    return Material(
      color: Colors.transparent,
      child: RefreshIndicator(
        color: _ac,
        onRefresh: () async => widget.onRefresh?.call(),
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(),
            _buildTabs(),
            _buildSearch(),
            if (widget.loading && widget.items.isEmpty)
              _buildLoading()
            else if (widget.loadError != null && widget.items.isEmpty)
              _buildLoadError()
            else if (filtered.isEmpty)
              _buildEmpty()
            else ...[
              ...visible.map(_buildItem),
              if (pages > 1) _buildPager(page, pages),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
            child: CircularProgressIndicator(color: Color(0xFF1F5FD6))),
      );

  Widget _buildLoadError() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 40, color: _danger),
          const SizedBox(height: 12),
          Text(widget.loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh, size: 16, color: _ac),
            label: const Text('Jaribu tena', style: TextStyle(color: _ac)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Text('Maoni',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w500, color: _ink)),
          const Spacer(),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: _ac, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('Live', style: TextStyle(fontSize: 13, color: _ac)),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final items = widget.items;
    final counts = {
      _Tab.all: items.length,
      _Tab.unanswered: items.where((i) => !i.replied).length,
      _Tab.answered: items.where((i) => i.replied).length,
    };
    const labels = {
      _Tab.all: 'Yote',
      _Tab.unanswered: 'Yasiyojibiwa',
      _Tab.answered: 'Yaliyojibiwa',
    };
    // Rangi za pill: Kijani = yaliyojibiwa, Nyekundu = yasiyojibiwa
    // (namba bado nyekundu kama ulivyoomba jengine), Wote = kijivu.
    Color pillFg(_Tab t) => t == _Tab.answered
        ? const Color(0xFF15803D)
        : t == _Tab.unanswered
            ? _danger
            : _muted;
    Color pillBg(_Tab t) => t == _Tab.answered
        ? const Color(0xFFECFDF5)
        : t == _Tab.unanswered
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF3F4F6);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _Tab.values.map((t) {
          final on = _tab == t;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _setTab(t),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  // Underline ya bluu bado: tab iliyochaguliwa.
                  border: Border(
                    bottom: BorderSide(
                        color: on ? _ac : Colors.transparent, width: 2),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  // Namba ndani ya pill (kijani/nyekundu/kijivu).
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pillBg(t),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${counts[t]}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: pillFg(t)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[t]!,
                    style: TextStyle(
                      fontSize: 13,
                      color: on ? _ac : _muted,
                      fontWeight: on ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ]),
              ),
            ),
          );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Border ya box imeondolewa (design) — bluu ya focus pia imeondoka.
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: const TextStyle(fontSize: 14, color: _ink),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration.collapsed(
                hintText: 'Tafuta jina, namba au ujumbe',
                hintStyle: TextStyle(fontSize: 14, color: _muted),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _page = 1;
                _resetEditing();
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final String msg;
    if (_query.trim().isNotEmpty) {
      msg = 'Hakuna maoni yanayolingana na ulichotafuta.';
    } else if (_tab == _Tab.unanswered) {
      msg = 'Umejibu maoni yote.';
    } else if (_tab == _Tab.answered) {
      msg = 'Hakuna maoni yaliyojibiwa bado.';
    } else {
      msg = 'Maoni ya watumiaji yataonekana hapa.';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 0),
      child: Column(
        children: [
          const Icon(Icons.speaker_notes_off_outlined, size: 36, color: _muted),
          const SizedBox(height: 8),
          const Text('Hakuna maoni hapa',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500, color: _ink)),
          const SizedBox(height: 2),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _muted)),
        ],
      ),
    );
  }

  // ----- kipengee cha ujumbe (nukuu) -----
  Widget _buildItem(Maoni i) {
    final editing = _editingId == i.id;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxHeight: 60,
              child: Text('\u201C', style: _serif(44, color: _ac, height: 0.9)),
            ),
          ),
          Text(i.message, style: _serif(19)),
          const SizedBox(height: 8),
          // Meta ya mtumiaji: inafungwa ndani ya soft-wrap (isiitole kwenye
          // simu ndogo au font kubwa). Mtiririko/mtiririko wa horizontal
          // HAIBADILISHI — maandishi na rangi zimebaki kama mockup.
          Text(
            '\u2014 ${i.name} \u00B7 ${i.phone} \u00B7 ${i.date}, ${i.time}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          _buildReplyArea(i, editing),
        ],
      ),
    );
  }

  Widget _buildReplyArea(Maoni i, bool editing) {
    // 1) Anaandika / anahariri
    if (editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _replyCtrl,
            focusNode: _replyFocus,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: _serif(17, style: FontStyle.italic),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              hintText: 'Andika jibu lako',
              hintStyle: _serif(17, style: FontStyle.italic, color: _muted),
              filled: true,
              fillColor: _fieldBg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _ac, width: 1.5),
              ),
            ),
          ),
          SizedBox(
            height: 20,
            child: _error == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_error!,
                        style: const TextStyle(fontSize: 12, color: _danger)),
                  ),
          ),
          Row(
            children: [
              InkWell(
                onTap: _sending ? null : () => _send(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _ac),
                        )
                      : const Text('Tuma',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _ac)),
                ),
              ),
              const SizedBox(width: 20),
              InkWell(
                onTap: _sending ? null : () => setState(_resetEditing),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child:
                      Text('Ghairi', style: TextStyle(fontSize: 14, color: _muted)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 2) Tayari amejibiwa
    if (i.replied) {
      return Container(
        padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _ac, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jibu lako', style: TextStyle(fontSize: 11, color: _muted)),
            Text(i.reply, style: _serif(16, style: FontStyle.italic)),
            InkWell(
              onTap: () => _startEdit(i),
              child: const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 2),
                child: Text('Hariri jibu',
                    style: TextStyle(fontSize: 13, color: _ac)),
              ),
            ),
          ],
        ),
      );
    }

    // 3) Hajajibiwa
    return InkWell(
      onTap: () => _startEdit(i),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon ile ile ya Matangazo (bell-ringing ya Tabler).
            Icon(TablerIcons.bell_ringing, size: 16, color: _ac),
            SizedBox(width: 6),
            Text('Andika jibu', style: TextStyle(fontSize: 14, color: _ac)),
          ],
        ),
      ),
    );
  }

  // ----- kurasa -----
  Widget _buildPager(int page, int pages) {
    // Pager: chevron mbili tu (Previous/Next) — hakuna namba za kurasa.
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageButton(
            icon: Icons.chevron_left,
            disabled: page == 1,
            onTap: () => _setPage(page - 1, pages),
          ),
          const SizedBox(width: 6),
          _PageButton(
            icon: Icons.chevron_right,
            disabled: page == pages,
            onTap: () => _setPage(page + 1, pages),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  const _PageButton({
    this.label,
    this.icon,
    this.active = false,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: InkResponse(
        onTap: disabled ? null : onTap,
        radius: 20,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _ac : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: icon != null
              ? Icon(icon, size: 20, color: _ink)
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    color: active ? Colors.white : _ink,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INTEGRATION LAYER — data halisi ya backend kwenye page MOJA hii.
// (Hii HAIBADILISHI UI hapo juu — inaunganisha MaoniPage na API: GET
// /feedback/admin/all + POST /feedback/admin/:id/reply + WS live + badge
// Decrement kama admin anapofanikiwa kujibu.)
// ---------------------------------------------------------------------------

const _monthsShort = [
  'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'
];

DateTime _parseIso(dynamic iso, [DateTime? fallback]) {
  final s = iso?.toString() ?? '';
  if (s.isEmpty) return fallback ?? DateTime.now();
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return fallback ?? DateTime.now();
  }
}

/// Ramani ya item ya API → Maoni ya mockup (id int-ish string hash).
Maoni _maoniFromFeedback(Map<String, dynamic> m, int fallbackId) {
  final idStr = (m['id'] ?? m['_id'] ?? fallbackId).toString();
  final idFallback = int.tryParse(idStr) ?? fallbackId;
  final phone = (m['user_phone'] ?? m['phone'] ?? '').toString();
  final nameRaw = (m['user_name'] ?? m['full_name'] ?? '').toString();
  final name =
      nameRaw.isNotEmpty && !nameRaw.startsWith('+') ? nameRaw : (phone.isNotEmpty ? phone : 'Mtumiaji');
  final created = _parseIso(m['created_at']);
  final subject = (m['subject'] ?? '').toString().trim();
  final message = (m['message'] ?? '').toString().trim();
  final userText = [
    if (subject.isNotEmpty) subject,
    if (message.isNotEmpty) message,
  ].join('\n');
  final reply = (m['admin_reply'] ?? m['reply'] ?? '').toString().trim();

  return Maoni(
    id: idFallback,
    name: name,
    phone: phone,
    date: '${created.day} ${_monthsShort[created.month - 1]}',
    time:
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
    message: userText.isEmpty ? '(tupu)' : userText,
    reply: reply,
  );
}

/// Ukurasa wa Maoni kwenye AdminShell — data halisi ya API ndani ya page
/// MOJA ya mockup (HUJAHAMISHA textbox: unajibu pale pale chini ya nukuu).
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
  String? _loadError;

  void _onWs(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? payload['event'])?.toString() ?? '';
    if ((type == 'feedback.new' || type == 'feedback.replied') && mounted) {
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('notification', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    super.dispose();
  }

  Future<void> _load() async {
    final first = _items.isEmpty && _loading;
    setState(() {
      if (first) _loading = true;
      _loadError = null;
    });
    try {
      final res = await ApiService().adminListFeedback(status: '', q: '');
      if (!mounted) return;
      final data = res.data;
      final list = data is List
          ? data
          : (data is Map
              ? (data['items'] as List? ?? data['results'] as List? ?? [])
              : <dynamic>[]);
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = friendlyError(e);
      });
    }
  }

  Future<void> _sendReply(Maoni item, String text) async {
    final apiId = _apiIds[item.id];
    if (apiId == null || apiId.isEmpty) {
      throw Exception('ID ya maoni haipatikani');
    }
    try {
      await ApiService().adminReplyFeedback(apiId, text);
      if (!mounted) return;
      // Badge ya Maoni inaisha TU baada ya kujibu (clearOnAction).
      BadgeController.instance.decrement(NavItem.maoni);
      AdminBadgeService().refresh();
      // Pakia upya list ya nyuma ya pazia — data halisi itaingia.
      unawaited(_load());
    } catch (_) {
      rethrow; // MaoniPage inaonyesha kosa la ndani
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaoniPage(
      items: _items,
      loading: _loading,
      loadError: _loadError,
      onRefresh: _load,
      onSendReply: _sendReply,
    );
  }
}
