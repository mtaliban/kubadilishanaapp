// MALIPO — uthibitisho wa michango
// ─────────────────────────────────────────────────────────────────────────────
// DATA (habari halisi, hazijabadilika):
//   GET /payments/admin/all → {"payments": [...], "counts": {...},
//   "total_approved_tzs": N}. Status za backend ni "verifying"/"approved"/
//   "rejected". Data moja inapakiwa mara moja, kichujio cha hali kinafanyika
//   upande wa app, na WS 'notification' inaita _load() kwa malipo mapya.
// DESIGN (mpya — palette ya paper):
//   - RejectPaymentDialog: dialog ndogo "Kataa malipo?" + sababu (radio tiles)
//   - PaymentConfirmationCard: jina + "Inasubiri", namba (teal), kiasi +
//     nakili ya rejea, tarehe + kupiga simu, onyo la SMS, SMS expander,
//     vitufe vitatu vya mraba (Kataa / Thibitisha / Ongea)
//   - ChatWithContributorSheet: bubbles + quick replies + input bar
//   - Header ya kadi inaonyesha ukaguzi wa SMS (kijani/njano/nyekundu)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/admin_badge_service.dart';
import '../../services/websocket_service.dart';

const _cBlue     = Color(0xFF1959D6);
const _cBlueBg   = Color(0xFFEAF1FF);
const _cBg       = Color(0xFFF3F0E9); // paper
const _cCardBg   = Color(0xFFF7F8FA);
const _cBorder   = Color(0xFFE6E0D2);
const _cTextDark = Color(0xFF142033);
const _cTextGrey = Color(0xFF5B6779);
const _cFaint    = Color(0xFF93A0B3);
const _cGreen    = Color(0xFF1F7A4D);
const _cGreenBg  = Color(0xFFDDF3E6);
const _cRed      = Color(0xFFC2503E);
const _cRedBg    = Color(0xFFFBE6E2);
const _cAmber    = Color(0xFFB6791F);
const _cAmberBg  = Color(0xFFFBF0DD);
const _cLiveGreen = Color(0xFF16A34A);
const _cTeal     = Color(0xFF1C5F56);
const _cTealTint = Color(0xFFE7F1EE);
const _cPanelTint = Color(0xFFF6F5F1);
const _cBlueTint = Color(0xFFE6EFFF);

const _kPageSize = 10;

String _fmt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDate(dynamic iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse('$iso').toLocal();
    return '${_two(d.day)}/${_two(d.month)}/${d.year}, ${_two(d.hour)}:${_two(d.minute)}';
  } catch (_) {
    return '';
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

String _titleCase(String v) => v
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

String _ago(dynamic iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse('$iso').toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'sasa hivi';
    if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes} zilizopita';
    if (diff.inHours < 24) return 'saa ${diff.inHours} zilizopita';
    return 'siku ${diff.inDays} zilizopita';
  } catch (_) {
    return '';
  }
}

// ─── SMS analyzer: inamsaidia admin kuhukumu kwa haraka ──────────────────
enum _Verdict { ok, warning, danger }

class _SmsCheck {
  final _Verdict verdict;
  final String text;
  const _SmsCheck(this.verdict, this.text);
}

final _smsAmountRe = RegExp(
    r'(?:paid|sent|umetuma|umelipa)\s+([\d,]+(?:\.\d+)?)\s*tzs',
    caseSensitive: false);

String _normSms(String v) => v.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

List<_SmsCheck> _smsChecks(String sms, int amount,
    List<Map<String, dynamic>> all, String orderId) {
  final checks = <_SmsCheck>[];
  if (sms.trim().isEmpty) return checks;
  final m = _smsAmountRe.firstMatch(sms);
  if (m == null) {
    checks.add(const _SmsCheck(
        _Verdict.danger, 'Haionekani kama SMS ya muamala'));
  } else {
    final paid = double.parse(m.group(1)!.replaceAll(',', '')).round();
    if (paid == amount) {
      checks.add(_SmsCheck(
          _Verdict.ok, 'Kiasi kinalingana (${_fmt(paid)} TZS)'));
    } else {
      checks.add(_SmsCheck(
          _Verdict.danger,
          'Kiasi hakilingani: SMS ${_fmt(paid)}, kilichoandikwa ${_fmt(amount)}'));
    }
  }
  final k = _normSms(sms);
  if (k.length >= 40 &&
      all.any((o) =>
          '${o['order_id'] ?? ''}' != orderId &&
          _normSms('${o['sms_text'] ?? ''}') == k)) {
    checks.add(const _SmsCheck(
        _Verdict.warning, 'SMS inafanana na ya malipo mengine'));
  }
  return checks;
}

// ═══ REJECT DIALOG ══════════════════════════════════════════════════════════
/// Dialog ndogo "Kataa malipo?" — inarudisha sababu iliyochaguliwa (String)
/// kama admin alibonyeza "Kataa", au null kama alighairi.
Future<String?> showRejectPaymentDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _RejectPaymentDialog(),
  );
}

class _RejectPaymentDialog extends StatefulWidget {
  const _RejectPaymentDialog();

  @override
  State<_RejectPaymentDialog> createState() => _RejectPaymentDialogState();
}

class _RejectPaymentDialogState extends State<_RejectPaymentDialog> {
  static const accent = Color(0xFF2F3EC7);
  static const danger = _cRed;

  final List<String> _reasons = const [
    'SMS si halisi',
    'Kiasi hakilingani',
    'Pesa haijaingia',
    'Malipo yamerudiwa',
  ];

  String _selected = 'SMS si halisi';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning icon badge.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  size: 16, color: danger),
            ),
            const SizedBox(height: 10),

            const Text(
              'Kataa malipo?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chagua sababu.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 12),

            // Reason options.
            ..._reasons.map((reason) {
              final selected = reason == _selected;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => setState(() => _selected = reason),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEAF0FE)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? accent : const Color(0xFFE0E1E6),
                        width: selected ? 1.2 : 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? accent : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? accent
                                  : const Color(0xFFD0D2D8),
                              width: 1.1,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  size: 8, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 7),

            // Actions.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Ghairi',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: danger,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 10, color: Colors.white),
                  label: const Text(
                    'Kataa',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ PAGE ═══════════════════════════════════════════════════════════════════
class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic> _counts = {};
  int _totalApprovedTzs = 0;

  String _status = 'all'; // all | verifying | approved | rejected
  int _page = 0;
  final _searchCtrl = TextEditingController();

  // ── LIVE halisi: WS inaita _load() malipo mapya yanapofika ──
  void _onWs(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? payload['event'])?.toString() ?? '';
    if (type == 'payment.submitted' || type == 'payment.message') {
      if (mounted) _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() { if (mounted) setState(() => _page = 0); });
    WebSocketService().on('notification', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('notification', _onWs);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── DATA: /payments/admin/all → {payments, counts, total_approved_tzs} ────
  Future<void> _load() async {
    // SILENT REFRESH: spinner TU wakati hAKUNA data bado (kwanza kabisa).
    final first = _payments.isEmpty && _loading;
    setState(() {
      if (first) _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminAllDonations();
      if (!mounted) return;
      final d = res.data;
      final map = d is Map ? d : <String, dynamic>{};
      final list = (d is List ? d : (map['payments'] ?? map['results'] ?? [])) as List;
      final c = map['counts'];
      setState(() {
        _payments = list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _counts = c is Map ? c.cast<String, dynamic>() : {};
        _totalApprovedTzs = (map['total_approved_tzs'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  int get _totalAll => _payments.length;

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.toLowerCase().trim();
    return _payments.where((p) {
      final st = '${p['status'] ?? ''}';
      if (_status != 'all' && st != _status) return false;
      if (q.isEmpty) return true;
      final name  = '${p['user_name'] ?? ''}'.toLowerCase();
      final phone = '${p['phone'] ?? ''}';
      final order = '${p['order_id'] ?? ''}'.toLowerCase();
      final sms   = '${p['sms_text'] ?? ''}'.toLowerCase();
      return name.contains(q) || phone.contains(q) || order.contains(q) || sms.contains(q);
    }).toList();
  }

  int get _totalPages => _filtered.isEmpty ? 1 : (_filtered.length / _kPageSize).ceil();
  int get _safePage => _page.clamp(0, _totalPages - 1);

  void _goToPage(int p) {
    setState(() => _page = p.clamp(0, _totalPages - 1));
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  // ── Vitendo ────────────────────────────────────────────────────────────────

  Future<void> _approve(Map<String, dynamic> p) async {
    final checks = _smsChecks('${p['sms_text'] ?? ''}',
        (p['amount'] as num?)?.toInt() ?? 0, _payments, '${p['order_id'] ?? ''}');
    final risky = checks.where((c) => c.verdict != _Verdict.ok).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(risky.isEmpty ? Icons.verified_outlined : Icons.warning_amber_rounded,
            color: risky.isEmpty ? _cGreen : _cAmber),
        title: const Text('Thibitisha malipo haya?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${_titleCase('${p['user_name'] ?? ''}')} · ${_fmt((p['amount'] as num?)?.toInt() ?? 0)} TZS',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Hakikisha pesa imefika kwenye simu yako kabla ya kuthibitisha.'),
            if (risky.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final c in risky)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            c.verdict == _Verdict.danger
                                ? Icons.error_outline_rounded
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: c.verdict == _Verdict.danger ? _cRed : _cAmber),
                        const SizedBox(width: 6),
                        Expanded(child: Text(c.text)),
                      ]),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ghairi'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _cGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thibitisha',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().adminApproveDonation('${p['order_id']}');
      if (!mounted) return;
      _showSnack('Malipo yamethibitishwa ✓', _cGreen);
      AdminBadgeService().refresh();
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _cRed);
    }
  }

  Future<void> _reject(Map<String, dynamic> p) async {
    final reason = await showRejectPaymentDialog(context);
    if (reason == null) return;
    // reason ina sababu iliyochaguliwa, mfano "SMS si halisi"
    try {
      await ApiService().adminRejectDonation('${p['order_id']}', note: reason);
      if (!mounted) return;
      _showSnack('Malipo yamekataliwa', _cAmber);
      AdminBadgeService().refresh();
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Kosa: $e', _cRed);
    }
  }

  Future<void> _sendReply(String orderId, String msg) async {
    // OPTIMISTIC: ujumbe uonekane HAPO HAPO kwenye chat (hakuna "nimeona
    // situma"). Kisha tunathibitisha na server (messages za kweli).
    setState(() {
      for (final p in _payments) {
        if ('${p['order_id']}' == orderId) {
          final msgs = ((p['messages'] as List?) ?? [])
              .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
          msgs.add({'from': 'admin', 'text': msg, 'at': DateTime.now().toIso8601String()});
          p['messages'] = msgs;
        }
      }
    });
    try {
      await ApiService().adminPaymentReply(orderId, msg);
      if (!mounted) return;
      _showSnack('Ujumbe umetumwa ✓', _cGreen);
      // Thibitisha na server: messages halisi za order hii
      try {
        final r = await ApiService().getPaymentMessages(orderId);
        if (!mounted) return;
        final raw = r.data;
        final list = raw is List
            ? raw
            : (raw is Map ? (raw['messages'] ?? raw['items'] ?? []) : []) as List;
        setState(() {
          for (final p in _payments) {
            if ('${p['order_id']}' == orderId) {
              p['messages'] = list
                  .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
            }
          }
        });
      } catch (_) {}
      await _load(); // list ya kina (counts/status)
    } catch (e) {
      if (!mounted) return;
      // Ondoa optimistic message iliyoshindikana
      setState(() {
        for (final p in _payments) {
          if ('${p['order_id']}' == orderId) {
            final msgs = ((p['messages'] as List?) ?? [])
                .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
            msgs.removeWhere((m) =>
                '${m['from']}'.contains('admin') && '${m['text']}' == msg);
            p['messages'] = msgs;
          }
        }
      });
      _showSnack('Ujumbe haukutumwa — jaribu tena', _cRed);
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$what imenakiliwa', _cTextDark);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _call(String phone) async {
    // Kupiga simu kunafanyika kwenye kadi (onCall) — hii ni placeholder
    // ya siku mbadala; kwa sasa tunanakili namba tu kama fallback.
    if (phone.isEmpty) return;
    _copy(phone, 'Namba ya simu');
  }

  // ── Chat na mchangiaji (bottom sheet mpya) ─────────────────────────────────
  void _openChat(Map<String, dynamic> p) {
    final orderId = '${p['order_id']}';
    final msgs = ((p['messages'] as List?) ?? [])
        .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatWithContributorSheet(
        name: _titleCase('${p['user_name'] ?? 'Mchangiaji'}'),
        online: false,
        messages: [
          for (final m in msgs)
            ChatMessage(
              text: '${m['text'] ?? m['message'] ?? ''}',
              isMe:
                  '${m['from'] ?? m['sender'] ?? m['role'] ?? ''}'.contains('admin') ||
                      m['is_admin'] == true ||
                      '${m['from'] ?? m['sender'] ?? m['role'] ?? ''}' == 'staff',
              time: _fmtTime(m['at'] ?? m['created_at']),
            ),
        ],
        quickReplies: const ['Nimepokea malipo lako', 'Namba si sahihi', 'Asante'],
        onSend: (text) => _sendReply(orderId, text),
      ),
    );
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse('$iso').toLocal();
      final t = TimeOfDay.fromDateTime(d);
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final m = t.minute.toString().padLeft(2, '0');
      final period = t.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $period';
    } catch (_) {
      return '';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageItems = filtered.skip(_safePage * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: _cBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _cBlue,
        backgroundColor: Colors.white,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            // ── Title + LIVE ──
            Row(children: [
              const Expanded(
                child: Text('Malipo',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800, color: _cTextDark)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _cGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8, color: _cLiveGreen),
                  SizedBox(width: 6),
                  Text('Live',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: _cGreen)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Thibitisha michango ya watumiaji (TigoPesa, M-Pesa, Airtel...)',
                style: TextStyle(fontSize: 14, color: _cTextGrey)),
            const SizedBox(height: 16),

            // ── Jumla iliyothibitishwa ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cBorder),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: _cBlueTint, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.trending_up_rounded, color: _cBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TZS ${_fmt(_totalApprovedTzs)}',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800, color: _cBlue)),
                    const Text('Jumla ya michango iliyothibitishwa',
                        style: TextStyle(fontSize: 12.5, color: _cTextGrey)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Hali (dropdown yenye counts) + Tafuta ──
            Row(children: [
              Expanded(
                child: _StatusDropdown(
                  value: _status,
                  total: _totalAll,
                  counts: _counts,
                  onChanged: (v) => setState(() { _status = v; _page = 0; }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 14, color: _cTextDark),
                  decoration: InputDecoration(
                    hintText: 'Tafuta...',
                    hintStyle: const TextStyle(fontSize: 14, color: _cFaint),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _cTextGrey),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Futa',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _cBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _cBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _cBlue, width: 1.4)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            Text('Inaonyesha ${pageItems.length} kati ya ${filtered.length} michango',
                style: const TextStyle(fontSize: 13, color: _cTextGrey)),
            const SizedBox(height: 10),

            // ── Body ──
            if (_loading && _payments.isEmpty)
              ...List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _SkeletonCard(),
                  ))
            else if (_error != null)
              _errorCard()
            else if (filtered.isEmpty)
              _emptyCard()
            else ...[
              for (final p in pageItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PaymentConfirmationCard(
                    name: _titleCase('${p['user_name'] ?? '(bila jina)'}'),
                    phone: '${p['phone'] ?? ''}',
                    amount: _fmt((p['amount'] as num?)?.toInt() ?? 0),
                    reference: '${p['order_id'] ?? ''}',
                    dateTime:
                        '${_fmtDate(p['created_at'])}${_ago(p['created_at']).isEmpty ? '' : ' · ${_ago(p['created_at'])}'}',
                    smsPreview: '${p['sms_text'] ?? ''}',
                    checks: _smsChecks('${p['sms_text'] ?? ''}',
                        (p['amount'] as num?)?.toInt() ?? 0, _payments,
                        '${p['order_id'] ?? ''}'),
                    status: '${p['status'] ?? 'verifying'}',
                    rejectedNote: '${p['note'] ?? ''}',
                    onConfirm: () => _approve(p),
                    onReject: () => _reject(p),
                    onChat: () => _openChat(p),
                    onCall: () => _call('${p['phone'] ?? ''}'),
                    onCopy: (text) => _copy(text, 'Rejea'),
                  ),
                ),
              _pager(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pager() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    final p = _safePage;
    final total = _totalPages;
    final start = (p - 2).clamp(0, (total - 5).clamp(0, 1 << 31));
    final end = (start + 5).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.outlined(
          onPressed: p > 0 ? () => _goToPage(p - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (var i = start; i < end; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _goToPage(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == p ? _cBlue : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: i == p ? _cBlue : _cBorder),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: i == p ? Colors.white : _cTextDark)),
              ),
            ),
          ),
        IconButton.outlined(
          onPressed: p < total - 1 ? () => _goToPage(p + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
      ),
      child: Column(children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: _cFaint),
        const SizedBox(height: 12),
        const Text('Imeshindikana kupakia malipo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _cTextDark)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Jaribu tena', style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(backgroundColor: _cBlue),
        ),
      ]),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cBorder),
      ),
      child: Column(children: [
        const Icon(Icons.payments_outlined, size: 40, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        Text(
          _status == 'verifying'
              ? 'Hakuna malipo yanayosubiri uthibitisho wako kwa sasa.'
              : 'Hakuna malipo katika hali hii kwa sasa.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _cTextGrey, fontSize: 14.5),
        ),
      ]),
    );
  }
}

// ═══ PAYMENT CONFIRMATION CARD (design mpya) ════════════════════════════════
/// Kadi ya uthibitisho wa malipo — jina + lebo ya hali sambamba, namba ya
/// simu chini yake, kiasi + kitufe cha kunakili rejea, tarehe + kitufe cha
/// kupiga simu, onyo la SMS (au ukaguzi), sehemu inayofunguka ya SMS, na
/// vitufe vitatu vya mraba (Kataa / Thibitisha / Ongea) mstari mmoja.
class PaymentConfirmationCard extends StatefulWidget {
  final String name;
  final String phone;
  final String amount;
  final String currency;
  final String reference;
  final String dateTime;
  final String smsPreview;
  final List<_SmsCheck> checks;
  final String status; // verifying | approved | rejected
  final String rejectedNote;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onChat;
  final VoidCallback? onCall;
  final ValueChanged<String>? onCopy;

  const PaymentConfirmationCard({
    super.key,
    required this.name,
    required this.phone,
    required this.amount,
    this.currency = 'TZS',
    required this.reference,
    required this.dateTime,
    this.smsPreview = '',
    this.checks = const [],
    this.status = 'verifying',
    this.rejectedNote = '',
    this.onConfirm,
    this.onReject,
    this.onChat,
    this.onCall,
    this.onCopy,
  });

  @override
  State<PaymentConfirmationCard> createState() =>
      _PaymentConfirmationCardState();
}

class _PaymentConfirmationCardState extends State<PaymentConfirmationCard> {
  bool _copied = false;
  bool _smsExpanded = false;

  // Rangi za muundo — zinaendana na design language iliyotumika awali.
  static const _ink = _cTextDark;
  static const _inkSoft = _cTextGrey;
  static const _inkFaint = _cFaint;
  static const _line = _cBorder;
  static const _panelTint = _cPanelTint;

  static const _teal = _cTeal;
  static const _tealTint = _cTealTint;
  static const _blue = _cBlue;
  static const _blueTint = _cBlueTint;
  static const _amber = _cAmber;
  static const _amberTint = _cAmberBg;
  static const _green = _cGreen;
  static const _red = _cRed;
  static const _redTint = _cRedBg;

  Future<void> _copyReference() async {
    await Clipboard.setData(ClipboardData(text: widget.reference));
    widget.onCopy?.call(widget.reference);
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  bool get _pending => widget.status == 'verifying';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(color: Color(0x0F142033), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildAmountPanel(),
          const SizedBox(height: 12),
          _buildMetaRow(),
          const SizedBox(height: 10),
          // Onyo la SMS au ukaguzi wa SMS (checks)
          if (widget.checks.isNotEmpty)
            _buildChecks()
          else if (_pending)
            _buildWarning(),
          if (widget.checks.isNotEmpty || _pending)
            const SizedBox(height: 10),
          if (widget.smsPreview.trim().isNotEmpty) ...[
            _buildSmsExpander(),
            const SizedBox(height: 14),
          ],
          _buildActions(),
          // Sababu ya kukataliwa
          if (widget.status == 'rejected' && widget.rejectedNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.flag_rounded, size: 15, color: _red),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Sababu: ${widget.rejectedNote}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: _red)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: _tealTint,
          child: Text(
            _initials(widget.name),
            style: const TextStyle(
              color: _teal,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        color: _ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(),
                ],
              ),
              const SizedBox(height: 3),
              if (widget.phone.isNotEmpty)
                GestureDetector(
                  onTap: widget.onCall,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, size: 13, color: _teal),
                      const SizedBox(width: 5),
                      Text(
                        widget.phone,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _teal,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final (label, color, bg, icon) = switch (widget.status) {
      'approved' => ('Imeidhinishwa', _green, _cGreenBg, Icons.check_circle_outline_rounded),
      'rejected' => ('Imekataliwa', _red, _redTint, Icons.cancel_outlined),
      _          => ('Inasubiri', _amber, _amberTint, Icons.access_time_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: _panelTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${widget.currency} ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _inkSoft,
                  ),
                ),
                TextSpan(
                  text: widget.amount,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _copyReference,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: _copied ? _green : _line,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.copy_rounded,
                    size: 13,
                    color: _copied ? _green : _teal,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _copied ? 'Imenakiliwa' : widget.reference,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _copied ? _green : _inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: _inkFaint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.dateTime,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _inkSoft),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onCall,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _blueTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.call, size: 14, color: _blue),
          ),
        ),
      ],
    );
  }

  Widget _buildWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _redTint,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: _red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Haionekani kama SMS ya muamala',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecks() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in widget.checks)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: switch (c.verdict) {
                  _Verdict.ok      => _cGreenBg,
                  _Verdict.warning => _amberTint,
                  _Verdict.danger  => _redTint,
                },
                borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                    switch (c.verdict) {
                      _Verdict.ok      => Icons.check_circle_outline_rounded,
                      _Verdict.warning => Icons.warning_amber_rounded,
                      _Verdict.danger  => Icons.error_outline_rounded,
                    },
                    size: 13,
                    color: switch (c.verdict) {
                      _Verdict.ok      => _green,
                      _Verdict.warning => _amber,
                      _Verdict.danger  => _red,
                    }),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(c.text,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: switch (c.verdict) {
                            _Verdict.ok      => _green,
                            _Verdict.warning => _amber,
                            _Verdict.danger  => _red,
                          })),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSmsExpander() {
    return Container(
      decoration: BoxDecoration(
        color: _panelTint,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => setState(() => _smsExpanded = !_smsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sms_outlined, size: 16, color: _inkSoft),
                      SizedBox(width: 8),
                      Text(
                        'Ona SMS ya mchangiaji',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  AnimatedRotation(
                    turns: _smsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: _inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _smsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _line)),
                ),
                child: SelectableText(
                  widget.smsPreview,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _inkSoft,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    // Kwa zilizoidhinishwa/zilizokataliwa: vitufe vya kitendo vimekwisha —
    // tunaonyesha tu "Ongea" (chat) badala ya Kataa/Thibitisha.
    if (!_pending) {
      return Row(
        children: [
          Expanded(
            child: _SquareIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: _blue,
              background: _blueTint,
              tooltip: 'Ongea na mchangiaji',
              onTap: widget.onChat,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _SquareIconButton(
            icon: Icons.close_rounded,
            iconColor: _red,
            background: Colors.white,
            borderColor: const Color(0xFFECC3BA),
            tooltip: 'Kataa',
            onTap: widget.onReject,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _SquareIconButton(
            icon: Icons.check_rounded,
            iconColor: Colors.white,
            background: _green,
            tooltip: 'Thibitisha',
            onTap: widget.onConfirm,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _SquareIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: _blue,
            background: _blueTint,
            tooltip: 'Ongea na mchangiaji',
            onTap: widget.onChat,
          ),
        ),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color? borderColor;
  final String tooltip;
  final VoidCallback? onTap;

  const _SquareIconButton({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.tooltip,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1.3)
                  : null,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}

// ═══ CHAT SHEET (design mpya) ═══════════════════════════════════════════════
class ChatMessage {
  final String text;
  final bool isMe;
  final String time;
  const ChatMessage({required this.text, required this.isMe, required this.time});
}

/// Fungua kama modal bottom sheet:
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => ChatWithContributorSheet(name: 'Hassan Hussein'),
/// );
class ChatWithContributorSheet extends StatefulWidget {
  final String name;
  final bool online;
  final List<ChatMessage> messages;
  final List<String> quickReplies;
  final void Function(String text)? onSend;

  const ChatWithContributorSheet({
    super.key,
    required this.name,
    this.online = false,
    this.messages = const [],
    this.quickReplies = const ['Sio sahihi'],
    this.onSend,
  });

  @override
  State<ChatWithContributorSheet> createState() =>
      _ChatWithContributorSheetState();
}

class _ChatWithContributorSheetState extends State<ChatWithContributorSheet> {
  final _controller = TextEditingController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.messages);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _now() {
    final t = TimeOfDay.now();
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: trimmed, isMe: true, time: _now()));
      _controller.clear();
    });
    widget.onSend?.call(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _cBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            _buildHeader(context),
            const Divider(height: 1, color: _cBorder),
            Flexible(child: _buildBody()),
            if (widget.quickReplies.isNotEmpty) _buildQuickReplies(),
            _buildInputBar(),
            SizedBox(
              height: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _cTealTint,
                child: Text(
                  _initials(widget.name),
                  style: const TextStyle(
                    color: _cTeal,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (widget.online)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _cLiveGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ongea na mchangiaji',
                  style: TextStyle(fontSize: 11, color: _cTextGrey),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _cTextDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, color: _cTextGrey, size: 20),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _cPanelTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 19,
                  color: _cFaint,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Hakuna ujumbe bado',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _cTextGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        return Align(
          alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            constraints: const BoxConstraints(maxWidth: 240),
            child: Column(
              crossAxisAlignment:
                  msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: msg.isMe ? _cBlue : _cPanelTint,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(13),
                      topRight: const Radius.circular(13),
                      bottomLeft: Radius.circular(msg.isMe ? 13 : 3),
                      bottomRight: Radius.circular(msg.isMe ? 3 : 13),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: msg.isMe ? Colors.white : _cTextDark,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    msg.time,
                    style: const TextStyle(fontSize: 10, color: _cFaint),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = widget.quickReplies[i];
          return Material(
            color: _cBlueTint,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _send(label),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _cBlue,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 38, maxHeight: 100),
              decoration: BoxDecoration(
                color: _cPanelTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 13, color: _cTextDark),
                decoration: const InputDecoration(
                  hintText: 'Andika jibu kwa mchangiaji…',
                  hintStyle: TextStyle(fontSize: 12.5, color: _cFaint),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: _send,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _cBlue,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _send(_controller.text),
              child: const Padding(
                padding: EdgeInsets.all(9),
                child: Icon(Icons.send_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ Dropdown ya hali yenye counts ══════════════════════════════════════════

class _StatusDropdown extends StatelessWidget {
  final String value;
  final int total;
  final Map<String, dynamic> counts;
  final ValueChanged<String> onChanged;
  const _StatusDropdown({
    required this.value,
    required this.total,
    required this.counts,
    required this.onChanged,
  });

  int _of(String s) => (counts[s] as num?)?.toInt() ?? 0;

  String _label(String v) => switch (v) {
        'all' => 'Zote ($total)',
        'verifying' => 'Zinasubiri (${_of('verifying')})',
        'approved' => 'Zimeidhinishwa (${_of('approved')})',
        'rejected' => 'Zimekataliwa (${_of('rejected')})',
        _ => v,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final v in ['all', 'verifying', 'approved', 'rejected'])
          PopupMenuItem<String>(
            value: v,
            child: Row(children: [
              if (value == v) ...[
                const Icon(Icons.check_rounded, size: 16, color: _cBlue),
                const SizedBox(width: 6),
              ],
              Text(_label(v),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: value == v ? FontWeight.w700 : FontWeight.w400,
                      color: value == v ? _cBlue : _cTextDark)),
            ]),
          ),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cBorder),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              _label(value),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: _cTextDark),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _cTextGrey),
        ]),
      ),
    );
  }
}

// ─── Skeleton loading (inang'aa badala ya spinner) ────────────────────

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: _cPanelTint, borderRadius: BorderRadius.circular(8)),
        );
    return FadeTransition(
      opacity: Tween<double>(begin: .45, end: 1).animate(_a),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cBorder),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: _cPanelTint, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  bar(140, 13),
                  const SizedBox(height: 8),
                  bar(100, 11),
                ]),
              ]),
              const SizedBox(height: 14),
              bar(double.infinity, 52),
              const SizedBox(height: 12),
              bar(180, 12),
            ]),
      ),
    );
  }
}
