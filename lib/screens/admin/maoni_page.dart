// maoni_page.dart
// Skrini ya Maoni na Malalamiko (design 2) - orodha + mazungumzo kama WhatsApp.
// Code ya design: kamili kama mockup iliyokubaliwa (rangi/sizes/spacing/icons/
// layout/maneno/animations HAZIJABADILISHWA). Chini ya faili kuna safu ya
// integration inayounganisha MaoniController na API halisi ya feedback
// (GET /feedback/admin/all, POST /feedback/admin/:id/reply, DELETE /feedback/admin/:id)
// + WS refresh real-time (feedback.new / feedback.replied).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/app_toast.dart' show AppToast, friendlyError;

const Color kBlue = Color(0xFF1A56DB);
const Color kAmber = Color(0xFFD97706);
const Color kGreen = Color(0xFF16A34A);

// ───────────────────────── RANGI ─────────────────────────
class MC {
  const MC();
  static MC of(BuildContext c) => const MC();

  Color get surface => Colors.white;
  Color get surface1 => const Color(0xFFF1F3F6);
  Color get chatBg => const Color(0xFFF5F7FB);
  Color get border => const Color(0xFFE3E6EB);
  Color get text => const Color(0xFF111827);
  Color get text2 => const Color(0xFF6B7280);
  Color get muted => const Color(0xFF9CA3AF);
  Color get avatarBg => const Color(0xFFD6E4FA);
  Color get sentBubble => const Color(0xFFD6E4FA);
  Color get accent => kBlue;
  Color get danger => const Color(0xFFE5484D);
  Color get dangerBg => const Color(0xFFFDECEC);
  Color get quoteBg => const Color(0x12000000);
}

// ───────────────────────── MODELS ─────────────────────────
class MaoniQuote {
  final String text;
  final bool fromAdmin;
  const MaoniQuote({required this.text, required this.fromAdmin});
}

class MaoniMsg {
  final String id;
  final String text;
  final bool fromAdmin; // true = wewe (admin), false = mtumiaji
  final DateTime time;
  final MaoniQuote? quote;
  bool deletedForAll;

  MaoniMsg({
    required this.id,
    required this.text,
    required this.fromAdmin,
    required this.time,
    this.quote,
    this.deletedForAll = false,
  });

  String get preview => deletedForAll ? 'Ujumbe umefutwa' : text;
}

class MaoniThread {
  final String id;
  final String name;
  final String phone;
  final List<MaoniMsg> messages;

  MaoniThread({
    required this.id,
    required this.name,
    required this.phone,
    required this.messages,
  });

  MaoniMsg get last => messages.last;

  /// Idadi ya jumbe za mtumiaji zilizo mwisho bila jibu lako.
  int get unread {
    var c = 0;
    for (var i = messages.length - 1; i >= 0 && !messages[i].fromAdmin; i--) {
      c++;
    }
    return c;
  }

  bool get hasName => !name.trim().startsWith('+');

  /// Jina la kwanza tu (kwa mstari wa "Wanaosubiri jibu lako").
  String get firstName {
    if (!hasName) return 'Mgeni';
    final w = name.trim().split(RegExp(r'\s+')).first;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }
}

// ───────────────────────── CONTROLLER ─────────────────────────
class MaoniController extends ChangeNotifier {
  List<MaoniThread> _threads;
  MaoniController(List<MaoniThread> threads) : _threads = threads;

  List<MaoniThread> get threads => _threads;

  void setThreads(List<MaoniThread> t) {
    _threads = t;
    notifyListeners();
  }

  MaoniThread? byId(String id) {
    for (final t in _threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Tuma jibu. Badilisha hapa kupiga API yako.
  void send(String threadId, String text, {MaoniQuote? quote}) {
    final t = byId(threadId);
    if (t == null) return;
    t.messages.add(MaoniMsg(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      fromAdmin: true,
      time: DateTime.now(),
      quote: quote,
    ));
    notifyListeners();
  }

  /// Futa ujumbe kwako tu.
  void deleteForMe(String threadId, String msgId) {
    final t = byId(threadId);
    if (t == null) return;
    t.messages.removeWhere((m) => m.id == msgId);
    notifyListeners();
  }

  /// Futa kwa wote (ujumbe wako tu). Unabaki "Ujumbe huu umefutwa".
  void deleteForAll(String threadId, String msgId) {
    final t = byId(threadId);
    if (t == null) return;
    for (final m in t.messages) {
      if (m.id == msgId) m.deletedForAll = true;
    }
    notifyListeners();
  }

  void deleteThread(String threadId) {
    _threads = _threads.where((t) => t.id != threadId).toList();
    notifyListeners();
  }
}

// ───────────────────────── HELPERS ─────────────────────────
String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

int _daysAgo(DateTime t) {
  final n = DateTime.now();
  final a = DateTime.utc(n.year, n.month, n.day);
  final b = DateTime.utc(t.year, t.month, t.day);
  return a.difference(b).inDays;
}

const _weekdays = [
  'Jumatatu', 'Jumanne', 'Jumatano', 'Alhamisi', 'Ijumaa', 'Jumamosi', 'Jumapili'
];
const _months = [
  'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'
];

/// Kwenye orodha: saa (leo), Jana, Juzi, jina la siku, kisha tarehe kamili.
String listTimeLabel(DateTime t) {
  final k = _daysAgo(t);
  if (k <= 0) return _hm(t);
  if (k == 1) return 'Jana';
  if (k == 2) return 'Juzi';
  if (k < 7) return _weekdays[t.weekday - 1];
  return '${t.day}/${t.month}/${t.year}';
}

/// Kwenye mazungumzo: Leo, Jana, Juzi, au tarehe kamili (mf. 12 Ago 2024).
String dateSeparator(DateTime t) {
  final k = _daysAgo(t);
  if (k <= 0) return 'Leo';
  if (k == 1) return 'Jana';
  if (k == 2) return 'Juzi';
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

const _filterLabels = ['Yote', 'Hayajajibiwa', 'Yamejibiwa'];
const _filterColors = [kBlue, kAmber, kGreen];

// ───────────────────────── WIDGETS ZA PAMOJA ─────────────────────────
class MaoniAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double fontSize;
  final double borderWidth;
  const MaoniAvatar({
    super.key,
    required this.name,
    this.size = 52,
    this.fontSize = 19,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    final isNumber = name.trim().startsWith('+');
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.avatarBg,
        border: borderWidth > 0 ? Border.all(color: kBlue, width: borderWidth) : null,
      ),
      child: isNumber
          ? Icon(Icons.person_outline, size: size * 0.5, color: c.accent)
          : Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: TextStyle(
                color: c.accent,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int n;
  final Color color;
  final double height;
  final double fontSize;
  final FontWeight weight;
  final double hPad;
  final Color? borderColor;
  const _CountBadge({
    required this.n,
    this.color = kBlue,
    this.height = 22,
    this.fontSize = 12,
    this.weight = FontWeight.w500,
    this.hPad = 6,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: height),
      height: height,
      padding: EdgeInsets.symmetric(horizontal: hPad),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
      ),
      child: Text(
        '$n',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
        ),
      ),
    );
  }
}

// ═════════════════════════ SKRINI YA ORODHA ═════════════════════════
class MaoniScreen extends StatefulWidget {
  final MaoniController controller;
  final void Function(MaoniThread thread)? onCall; // mf. url_launcher: tel:
  const MaoniScreen({super.key, required this.controller, this.onCall});

  @override
  State<MaoniScreen> createState() => _MaoniScreenState();
}

class _MaoniScreenState extends State<MaoniScreen> {
  int _filter = 0; // 0 yote, 1 hayajajibiwa, 2 yamejibiwa
  String _query = '';
  bool _filterOpen = false;

  void _open(MaoniThread t) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MaoniChatScreen(
        controller: widget.controller,
        threadId: t.id,
        onCall: widget.onCall,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    return Scaffold(
      backgroundColor: c.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final all = widget.controller.threads
                .where((t) => t.messages.isNotEmpty)
                .toList()
              ..sort((a, b) => b.last.time.compareTo(a.last.time));
            final counts = [
              all.length,
              all.where((t) => t.unread > 0).length,
              all.where((t) => t.unread == 0).length,
            ];
            final badgeCount = _filter == 0 ? counts[1] : counts[_filter];
            final waiting = all.where((t) => t.unread > 0).toList();

            final q = _query.trim().toLowerCase();
            final rows = all.where((t) {
              final u = t.unread;
              final okF = _filter == 0 || (_filter == 1 ? u > 0 : u == 0);
              final okQ = q.isEmpty ||
                  t.name.toLowerCase().contains(q) ||
                  t.phone.contains(q) ||
                  t.last.preview.toLowerCase().contains(q);
              return okF && okQ;
            }).toList();

            return Column(
              children: [
                // ── Kichwa: Maoni + kitufe cha kuchuja ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                  child: Row(
                    children: [
                      Text('Maoni',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                              color: c.text)),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: kGreen, shape: BoxShape.circle),
                      ),
                      const Spacer(),
                      _FilterButton(
                        count: badgeCount,
                        color: _filterColors[_filter],
                        onTap: () => setState(() => _filterOpen = !_filterOpen),
                      ),
                    ],
                  ),
                ),
                // ── Kisanduku cha kutafuta (kinaonekana moja kwa moja) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(fontSize: 15, color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Tafuta jina, namba au ujumbe',
                        hintStyle: TextStyle(color: c.muted, fontSize: 15),
                        prefixIcon: Icon(Icons.search, size: 20, color: c.muted),
                        filled: true,
                        fillColor: c.surface1,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // ── Orodha ya kuchuja (inafunguka ukibonyeza kitufe) ──
                      if (_filterOpen)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border, width: 0.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: List.generate(3, (i) {
                                return InkWell(
                                  onTap: () => setState(() {
                                    _filter = i;
                                    _filterOpen = false;
                                  }),
                                  child: Container(
                                    height: 54,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          child: _filter == i
                                              ? const Icon(Icons.check,
                                                  size: 20, color: kBlue)
                                              : null,
                                        ),
                                        Expanded(
                                          child: Text(_filterLabels[i],
                                              style: TextStyle(
                                                  fontSize: 15, color: c.text)),
                                        ),
                                        Text('${counts[i]}',
                                            style: TextStyle(
                                                fontSize: 15, color: c.text2)),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      // ── Mstari wa kichujio kilichochaguliwa ──
                      if (_filter != 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: _filterColors[_filter],
                                      shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text('${_filterLabels[_filter]} (${counts[_filter]})',
                                    style: TextStyle(fontSize: 13, color: c.text2)),
                                InkWell(
                                  onTap: () => setState(() => _filter = 0),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Text('Ondoa',
                                        style: TextStyle(
                                            fontSize: 13, color: c.accent)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // ── Wanaosubiri jibu lako (inasogezwa kulia) ──
                      if (_filter == 0 && waiting.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                                child: Text('Wanaosubiri jibu lako',
                                    style: TextStyle(fontSize: 12, color: c.text2)),
                              ),
                              SizedBox(
                                height: 92,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                                  itemCount: waiting.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (_, i) =>
                                      _WaitingItem(thread: waiting[i], onTap: () => _open(waiting[i])),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Divider(height: 1, thickness: 0.5, color: c.border),
                      ),
                      if (rows.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('Hakuna maoni',
                                  style: TextStyle(fontSize: 14, color: c.muted)),
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (_, i) =>
                              _ThreadRow(thread: rows[i], onTap: () => _open(rows[i])),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _FilterButton({required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: c.surface1,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.filter_list, size: 22, color: c.text),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: IgnorePointer(
                child: _CountBadge(
                  n: count,
                  color: color,
                  height: 18,
                  fontSize: 11,
                  hPad: 5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WaitingItem extends StatelessWidget {
  final MaoniThread thread;
  final VoidCallback onTap;
  const _WaitingItem({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  MaoniAvatar(
                      name: thread.name, size: 50, fontSize: 17, borderWidth: 1.5),
                  Positioned(
                    top: -3,
                    right: -5,
                    child: _CountBadge(
                      n: thread.unread,
                      height: 18,
                      fontSize: 11,
                      weight: FontWeight.w400,
                      hPad: 5,
                      borderColor: c.surface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              thread.firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final MaoniThread thread;
  final VoidCallback onTap;
  const _ThreadRow({required this.thread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    final l = thread.last;
    final u = thread.unread;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            MaoniAvatar(name: thread.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          thread.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: c.text),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        listTimeLabel(l.time),
                        style: TextStyle(
                            fontSize: 12.5, color: u > 0 ? kBlue : c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (l.fromAdmin && !l.deletedForAll)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.done_all, size: 17, color: kBlue),
                              ),
                            if (l.deletedForAll)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.block, size: 15, color: c.text2),
                              ),
                            Expanded(
                              child: Text(
                                l.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, color: c.text2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (u > 0) ...[
                        const SizedBox(width: 8),
                        _CountBadge(n: u),
                      ],
                    ],
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

// ═════════════════════════ SKRINI YA MAZUNGUMZO ═════════════════════════
class MaoniChatScreen extends StatefulWidget {
  final MaoniController controller;
  final String threadId;
  final void Function(MaoniThread thread)? onCall;
  const MaoniChatScreen({
    super.key,
    required this.controller,
    required this.threadId,
    this.onCall,
  });

  @override
  State<MaoniChatScreen> createState() => _MaoniChatScreenState();
}

class _MaoniChatScreenState extends State<MaoniChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  String? _selectedId;
  MaoniMsg? _replyTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom(animate: false));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (animate) {
      _scroll.animateTo(max,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(max);
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final r = _replyTo;
    widget.controller.send(
      widget.threadId,
      text,
      quote: r == null
          ? null
          : MaoniQuote(text: r.preview, fromAdmin: r.fromAdmin),
    );
    _input.clear();
    setState(() {
      _replyTo = null;
      _selectedId = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  void _startReply(MaoniMsg m) {
    setState(() {
      _replyTo = m;
      _selectedId = null;
    });
  }

  Future<void> _confirmDeleteThread(MaoniThread t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa mazungumzo yote?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Futa', style: TextStyle(color: Color(0xFFE5484D))),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.controller.deleteThread(t.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final t = widget.controller.byId(widget.threadId);
        if (t == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return Scaffold(backgroundColor: c.chatBg);
        }

        // Jenga orodha ya tarehe + jumbe
        final items = <Widget>[];
        String? prevDay;
        MaoniMsg? prev;
        for (final m in t.messages) {
          final day = dateSeparator(m.time);
          double top = 4;
          if (day != prevDay) {
            items.add(_DatePill(label: day));
          } else if (prev != null && prev.fromAdmin != m.fromAdmin) {
            top = 12;
          }
          items.add(_messageRow(t, m, top, c));
          prevDay = day;
          prev = m;
        }

        return Scaffold(
          backgroundColor: c.chatBg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Kichwa cha mazungumzo ──
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: c.text),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      MaoniAvatar(name: t.name, size: 42, fontSize: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w500,
                                    color: c.text)),
                            Text(t.phone,
                                style: TextStyle(fontSize: 12.5, color: c.text2)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.phone_outlined, color: c.text),
                        onPressed: widget.onCall == null ? null : () => widget.onCall!(t),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: c.danger),
                        onPressed: () => _confirmDeleteThread(t),
                      ),
                    ],
                  ),
                ),
                // ── Jumbe ──
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      if (_selectedId != null) setState(() => _selectedId = null);
                    },
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                      children: items,
                    ),
                  ),
                ),
                // ── Upau wa "Unamjibu..." ──
                if (_replyTo != null) _replyBar(t, _replyTo!, c),
                // ── Sehemu ndogo ya kuandika ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 42),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: c.border, width: 0.5),
                          ),
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(fontSize: 15.5, height: 1.35, color: c.text),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 11),
                              hintText: 'Andika jibu lako hapa...',
                              hintStyle: TextStyle(color: c.muted, fontSize: 15.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: kBlue,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _send,
                          child: const SizedBox(
                            width: 42,
                            height: 42,
                            child: Icon(Icons.send, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _replyBar(MaoniThread t, MaoniMsg r, MC c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: c.surface1,
        border: const Border(left: BorderSide(color: kBlue, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.fromAdmin ? 'Wewe' : t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w500, color: c.accent)),
                Text(r.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, height: 1.3, color: c.text2)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 20, color: c.text2),
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _messageRow(MaoniThread t, MaoniMsg m, double top, MC c) {
    final selected = _selectedId == m.id;
    final admin = m.fromAdmin;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: admin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _SwipeReply(
            enabled: !m.deletedForAll,
            onReply: () => _startReply(m),
            child: Align(
              alignment: admin ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => setState(() => _selectedId = selected ? null : m.id),
                onLongPress: () => setState(() => _selectedId = m.id),
                child: _Bubble(msg: m, threadName: t.name, selected: selected),
              ),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!m.deletedForAll)
                    _ActionChip(
                      label: 'Jibu',
                      icon: Icons.reply,
                      onTap: () => _startReply(m),
                    ),
                  _ActionChip(
                    label: 'Futa kwangu',
                    danger: true,
                    onTap: () {
                      setState(() {
                        _selectedId = null;
                        if (_replyTo?.id == m.id) _replyTo = null;
                      });
                      widget.controller.deleteForMe(t.id, m.id);
                    },
                  ),
                  // Ujumbe wa mtumiaji huwezi kuufuta kwa wote - wako tu
                  if (admin && !m.deletedForAll)
                    _ActionChip(
                      label: 'Futa kwa wote',
                      danger: true,
                      onTap: () {
                        setState(() {
                          _selectedId = null;
                          if (_replyTo?.id == m.id) _replyTo = null;
                        });
                        widget.controller.deleteForAll(t.id, m.id);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Kipande cha tarehe ─────────────────────────
class _DatePill extends StatelessWidget {
  final String label;
  const _DatePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 14, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: c.text2)),
      ),
    );
  }
}

// ───────────────────────── Vitufe vya Jibu / Futa ─────────────────────────
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool danger;
  final VoidCallback onTap;
  const _ActionChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    final fg = danger ? c.danger : c.text;
    return Material(
      color: danger ? c.dangerBg : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: danger ? c.danger : c.border, width: 0.5),
      ),
      child: InkWell(
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 4),
              ],
              Text(label, style: TextStyle(fontSize: 13, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Vuta kulia kujibu (kama WhatsApp) ─────────────────────────
class _SwipeReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  const _SwipeReply({
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<_SwipeReply> createState() => _SwipeReplyState();
}

class _SwipeReplyState extends State<_SwipeReply> {
  double _dx = 0;
  bool _dragging = false;

  void _end() {
    if (_dx > 55) {
      HapticFeedback.lightImpact();
      widget.onReply();
    }
    setState(() {
      _dx = 0;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: (d) {
        if (!widget.enabled) return;
        setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, 70.0).toDouble());
      },
      onHorizontalDragEnd: (_) => _end(),
      onHorizontalDragCancel: _end,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 6,
            child: Opacity(
              opacity: (_dx / 55).clamp(0.0, 1.0).toDouble(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.surface1, shape: BoxShape.circle),
                child: Icon(Icons.reply, size: 18, color: c.text2),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Kiputo cha ujumbe ─────────────────────────
class _Bubble extends StatelessWidget {
  final MaoniMsg msg;
  final String threadName;
  final bool selected;
  const _Bubble({
    required this.msg,
    required this.threadName,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final c = MC.of(context);
    final admin = msg.fromAdmin;
    final maxW = MediaQuery.of(context).size.width * 0.84;

    final radius = admin
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(3),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );

    final bodyStyle = TextStyle(fontSize: 16.5, height: 1.4, color: c.text);
    // Nafasi ya saa (na ✓✓) mwishoni mwa mstari wa mwisho - kama WhatsApp
    final gap = '\u00A0' * (admin ? 15 : 10);

    final Widget body = msg.deletedForAll
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 16, color: c.text2),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Ujumbe huu umefutwa$gap',
                  style: bodyStyle.copyWith(
                      fontStyle: FontStyle.italic, color: c.text2),
                ),
              ),
            ],
          )
        : Text('${msg.text}$gap', style: bodyStyle);

    final q = msg.quote;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW, minWidth: 76),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        decoration: BoxDecoration(
          color: admin ? c.sentBubble : c.surface,
          borderRadius: radius,
          border: admin ? null : Border.all(color: c.border, width: 0.5),
        ),
        foregroundDecoration: selected
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: kBlue.withAlpha(160), width: 2),
              )
            : null,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (q != null && !msg.deletedForAll)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                  decoration: BoxDecoration(
                    color: c.quoteBg,
                    border: const Border(left: BorderSide(color: kBlue, width: 4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(q.fromAdmin ? 'Wewe' : threadName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: c.accent)),
                      const SizedBox(height: 2),
                      Text(q.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5, height: 1.35, color: c.text2)),
                    ],
                  ),
                ),
              Stack(
                children: [
                  body,
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_hm(msg.time),
                            style: TextStyle(fontSize: 11.5, height: 1, color: c.text2)),
                        if (admin && !msg.deletedForAll) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.done_all, size: 17, color: kBlue),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// INTEGRATION LAYER — API halisi (kubadilishanaapp backend)
//
// GET  /feedback/admin/all           → orodha ya maoni (threads)
// POST /feedback/admin/:id/reply     → jibu la admin (send)
// DELETE /feedback/admin/:id         → futa mazungumzo yote (deleteThread)
// WS   'notification' feedback.new / feedback.replied → refresh ya moja kwa moja
//
// Ramani ya data:
//   feedback item → MaoniThread:
//     id = feedback.id, name = user_name (au user_phone kama jina hakipo),
//     phone = user_phone
//     msg 1 (mtumiaji)  = "subject\nmessage"  @created_at
//     msg 2 (admin)     = admin_reply         @admin_replied_at
//                          + quote ya ujumbe wa mtumiaji (kama WhatsApp)
// ═══════════════════════════════════════════════════════════════════════

DateTime _parseIso(dynamic iso, [DateTime? fallback]) {
  final s = iso?.toString() ?? '';
  if (s.isEmpty) return fallback ?? DateTime.now();
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return fallback ?? DateTime.now();
  }
}

MaoniThread _threadFromFeedback(Map<String, dynamic> m) {
  final id = (m['id'] ?? m['_id'] ?? '').toString();
  final phone = (m['user_phone'] ?? m['phone'] ?? '').toString();
  final nameRaw = (m['user_name'] ?? m['full_name'] ?? '').toString().trim();
  final name =
      nameRaw.isNotEmpty ? nameRaw : (phone.isNotEmpty ? phone : 'Mtumiaji');
  final created = _parseIso(m['created_at']);
  final subject = (m['subject'] ?? '').toString().trim();
  final message = (m['message'] ?? '').toString().trim();
  final userText = [
    if (subject.isNotEmpty) subject,
    if (message.isNotEmpty) message,
  ].join('\n');

  final msgs = <MaoniMsg>[];
  if (userText.isNotEmpty) {
    msgs.add(MaoniMsg(id: '${id}u', text: userText, fromAdmin: false, time: created));
  }
  final reply = (m['admin_reply'] ?? '').toString().trim();
  if (reply.isNotEmpty) {
    msgs.add(MaoniMsg(
      id: '${id}r',
      text: reply,
      fromAdmin: true,
      time: _parseIso(m['admin_replied_at'], created),
      quote: userText.isEmpty ? null : MaoniQuote(text: userText, fromAdmin: false),
    ));
  }
  return MaoniThread(id: id, name: name, phone: phone, messages: msgs);
}

/// MaoniController yenye API halisi: send → adminReplyFeedback,
/// deleteThread → adminDeleteFeedback. (Kufuta ujumbe mmoja kwa wote
/// hakuna kwenye API — kinafanya kazi ndani ya app tu.)
class ApiMaoniController extends MaoniController {
  ApiMaoniController(super.threads);

  @override
  Future<void> send(String threadId, String text, {MaoniQuote? quote}) async {
    try {
      await ApiService().adminReplyFeedback(threadId, text);
      final t = byId(threadId);
      if (t != null) {
        t.messages.add(MaoniMsg(
          id: 'r${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          fromAdmin: true,
          time: DateTime.now(),
          quote: quote,
        ));
        notifyListeners();
      }
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }

  @override
  Future<void> deleteThread(String threadId) async {
    try {
      await ApiService().adminDeleteFeedback(threadId);
      super.deleteThread(threadId);
    } catch (e) {
      AppToast.error(friendlyError(e));
    }
  }
}

/// Ukurasa wa Maoni kwenye AdminShell — anza loading, pata data, WS refresh.
class MaoniPage extends StatefulWidget {
  const MaoniPage({super.key});

  @override
  State<MaoniPage> createState() => _MaoniPageState();
}

class _MaoniPageState extends State<MaoniPage> {
  late final ApiMaoniController _controller = ApiMaoniController(const []);
  bool _loading = true;
  String? _error;

  // LIVE halisi: WS inaita _load() maoni mpya / majibu yanapofika.
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

  // SILENT REFRESH: spinner TU wakati hakuna data bado.
  Future<void> _load() async {
    final first = _loading;
    setState(() {
      if (first) _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminListFeedback(status: '', q: '');
      if (!mounted) return;
      final data = res.data;
      final items = data is List
          ? data
          : (data is Map
              ? (data['items'] as List? ?? data['results'] as List? ?? [])
              : <dynamic>[]);
      final threads = <MaoniThread>[
        for (final it in items)
          if (it is Map)
            _threadFromFeedback(Map<String, dynamic>.from(it)),
      ];
      _controller.setThreads(threads);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _call(MaoniThread t) async {
    final digits = t.phone.replaceAll(RegExp(r'\D'), '');
    try {
      await launchUrl(Uri.parse('tel:$digits'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      AppToast.error('Imeshindikana kufungua');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: kBlue),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MC().text2, fontSize: 14)),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16, color: kBlue),
                label: const Text('Jaribu tena',
                    style: TextStyle(color: kBlue)),
              ),
            ],
          ),
        ),
      );
    }
    return MaoniScreen(controller: _controller, onCall: _call);
  }
}
