// ============================================================================
// WALIOPIGIANA — orodha ya mawasiliano kati ya watumiaji (Simu, SMS, WhatsApp)
// Design (kama reference):
//  - Kadi ina watu WAWILI juu→chini (Mtumaji -> Mpokeaji); majina yanashuka
//    mstari badala ya kukatwa.
//  - Maandishi makubwa, sentence case (MISABO EVARIST -> Misabo Evarist).
//  - Role za mfumo zinasafishwa (TEACHER_SECONDARY -> Teacher secondary).
//  - Orodha imepangwa kwa siku (Leo, Jana, 17 Sep 2026); muda ni saa tu.
//  - Rangi za njia: Simu (bluu), SMS (njano), WhatsApp (kijani).
//  - Search ya kweli (jina au namba) + "Onyesha zaidi".
//  - Gusa kadi kuona namba za simu na kuzinakili.
// Data halisi: GET /messages/admin/contacts (ApiService.getContactActivity)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _kPrimary = Color(0xFF1E40AF);
const _kBg      = Color(0xFFF8FAFC);
const _kInk     = Color(0xFF0F172A);
const _kMuted   = Color(0xFF64748B);
const _kLine    = Color(0xFFE2E8F0);
const _kSoft    = Color(0xFFF1F5F9);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreenBg = Color(0xFFDCFCE7);

const _kStep = 25;

// ───────────────────────── Channel styling ─────────────────────────
({Color fg, Color bg, IconData icon, String label}) _channelStyle(String type, bool sw) {
  switch (type) {
    case 'sms':
      return (
        fg: const Color(0xFFB45309),
        bg: const Color(0xFFFEF3C7),
        icon: Icons.sms_rounded,
        label: 'SMS',
      );
    case 'whatsapp':
      return (
        fg: const Color(0xFF15803D),
        bg: _kGreenBg,
        icon: Icons.chat_rounded,
        label: 'WhatsApp',
      );
    default:
      return (
        fg: const Color(0xFF1D4ED8),
        bg: const Color(0xFFDBEAFE),
        icon: Icons.call_rounded,
        label: sw ? 'Simu' : 'Call',
      );
  }
}

// ───────────────────────── Helpers ─────────────────────────
String _titleCase(String s) => s
    .trim()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _prettyRole(String r) {
  if (r.isEmpty || !r.contains('_')) return r;
  final s = r.replaceAll('_', ' ').toLowerCase();
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

String _catLabel(String? c) {
  switch (c) {
    case 'education':         return 'Elimu';
    case 'health':            return 'Afya';
    case 'kilimo':            return 'Kilimo na Ufugaji';
    case 'watumishi_wa_umma': return 'Watumishi wa Umma';
    default:                  return c == null || c.isEmpty ? '' : _titleCase(c);
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
}

String _two(int n) => n.toString().padLeft(2, '0');
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

const _monthsSw = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _dateText(DateTime d, bool sw) =>
    '${d.day} ${(sw ? _monthsSw : _monthsEn)[d.month - 1]} ${d.year}';

String _dayLabel(DateTime d, bool sw) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return sw ? 'Leo' : 'Today';
  if (diff == 1) return sw ? 'Jana' : 'Yesterday';
  return _dateText(d, sw);
}

DateTime? _parseTs(String ts) {
  if (ts.isEmpty) return null;
  try {
    return DateTime.parse(ts).toLocal();
  } catch (_) {
    return null;
  }
}

// ───────────────────────── Page ─────────────────────────
class AdminContactsPage extends StatefulWidget {
  const AdminContactsPage({super.key});
  @override
  State<AdminContactsPage> createState() => _AdminContactsPageState();
}

class _AdminContactsPageState extends State<AdminContactsPage> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  String _channel = ''; // '' = zote, 'call' | 'sms' | 'whatsapp'
  String _query = '';
  int _shown = _kStep;

  String t(String sw, String en) => sw;

  int _countOf(String c) => _all.where((e) => (e['contact_type'] as String? ?? 'call') == c).length;

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'[^0-9+]'), '');
    return _all.where((e) {
      if (_channel.isNotEmpty && (e['contact_type'] as String? ?? 'call') != _channel) return false;
      if (q.isEmpty) return true;
      final fromName = ((e['from_full_name'] as String?) ?? '').toLowerCase();
      final toName = ((e['to_full_name'] as String?) ?? '').toLowerCase();
      final fromPhone = ((e['from_phone'] as String?) ?? '').toLowerCase();
      final toPhone = ((e['to_phone'] as String?) ?? '').toLowerCase();
      final byName = fromName.contains(q) || toName.contains(q);
      final byPhone = digits.isNotEmpty && (fromPhone.contains(digits) || toPhone.contains(digits));
      return byName || byPhone;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().getContactActivity(limit: 300);
      if (!mounted) return;
      final data = res.data;
      final raw = data is List ? data : ((data['contacts'] ?? data['results']) as List? ?? []);
      setState(() {
        _all = raw.whereType<Map<String, dynamic>>().toList();
        _loading = false;
        _shown = _kStep;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _setChannel(String c) => setState(() {
        _channel = (_channel == c) ? '' : c;
        _shown = _kStep;
      });

  void _copy(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Namba imenakiliwa'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _channel = '';
      _shown = _kStep;
    });
  }

  void _goToPage(int p) {
    setState(() => _shown = p);
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _openDetails(Map<String, dynamic> e, bool sw) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _DetailSheet(e: e, sw: sw, onCopy: _copy),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final visible = filtered.take(_shown).toList();
    final remaining = filtered.length - visible.length;

    // Makundi kwa siku (Leo / Jana / tarehe)
    final rows = <Widget>[];
    String? lastDay;
    for (final e in visible) {
      final at = _parseTs(e['initiated_at'] as String? ?? '') ?? DateTime.now();
      final day = _dayLabel(at, true);
      if (day != lastDay) {
        rows.add(Padding(
          padding: EdgeInsets.only(top: lastDay == null ? 4 : 14, bottom: 10),
          child: Text(day,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _kMuted)),
        ));
        lastDay = day;
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _InteractionCard(
          e: e,
          at: at,
          onTap: () => _openDetails(e, true),
        ),
      ));
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kPrimary,
        child: ListView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            // ── Header ──
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.phone_in_talk_rounded, color: _kPrimary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Waliopigiana',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kInk)),
              ),
              const _StatusChip(online: true),
            ]),
            const SizedBox(height: 8),
            Text(
              t('Watumiaji waliowasiliana kwa simu, SMS na WhatsApp.',
                  'Users who contacted each other by call, SMS, and WhatsApp.'),
              style: const TextStyle(fontSize: 15, color: _kMuted, height: 1.4),
            ),
            const SizedBox(height: 16),

            // ── Search ──
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() {
                _query = v;
                _shown = _kStep;
              }),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Tafuta kwa jina au namba ya simu',
                prefixIcon: const Icon(Icons.search_rounded, color: _kMuted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Futa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                          _shown = _kStep;
                        }),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kLine)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kLine)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _kPrimary, width: 1.6)),
              ),
            ),
            const SizedBox(height: 12),

            // ── Channel chips (na idadi) ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('Zote', _all.length, null, null, _channel.isEmpty, () => _setChannel('')),
                for (final c in const ['call', 'sms', 'whatsapp'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Builder(builder: (_) {
                      final st = _channelStyle(c, true);
                      return _chip(st.label, _countOf(c), st.icon, st.fg,
                          _channel == c, () => _setChannel(c));
                    }),
                  ),
              ]),
            ),
            const SizedBox(height: 14),

            if (!_loading && _error == null)
              Text(
                'Inaonyesha ${visible.length} kati ya ${filtered.length}',
                style: const TextStyle(fontSize: 13, color: _kMuted),
              ),
            const SizedBox(height: 10),

            // ── Body ──
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: _kPrimary)),
              )
            else if (_error != null)
              _ErrorState(onRetry: _load)
            else if (filtered.isEmpty)
              _EmptyState(onClear: _clearSearch)
            else ...[
              ...rows,
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton(
                    onPressed: () => _goToPage(_shown + _kStep),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Onyesha zaidi ($remaining zimebaki)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, int count, IconData? icon, Color? color, bool selected,
      VoidCallback onTap) {
    final c = color ?? _kPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 18, color: selected ? Colors.white : c),
        label: Text('$label  $count'),
        selected: selected,
        showCheckmark: false,
        selectedColor: c,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? c : _kLine),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        labelStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _kInk),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

// ───────────────────────── Widgets ─────────────────────────
class _StatusChip extends StatelessWidget {
  final bool online;
  const _StatusChip({required this.online});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: online ? _kGreenBg : _kSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 6),
        Text(online ? 'Live' : 'Offline',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: online ? const Color(0xFF166534) : _kMuted)),
      ]),
    );
  }
}

class _ChannelPill extends StatelessWidget {
  final String type;
  const _ChannelPill({required this.type});

  @override
  Widget build(BuildContext context) {
    final st = _channelStyle(type, true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(st.icon, size: 16, color: st.fg),
        const SizedBox(width: 6),
        Text(st.label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: st.fg)),
      ]),
    );
  }
}

class _InteractionCard extends StatelessWidget {
  final Map<String, dynamic> e;
  final DateTime at;
  final VoidCallback onTap;
  const _InteractionCard({required this.e, required this.at, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = e['contact_type'] as String? ?? 'call';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kLine),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _ChannelPill(type: type),
              const Spacer(),
              const Icon(Icons.schedule, size: 16, color: _kMuted),
              const SizedBox(width: 5),
              Text(_hm(at),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _kMuted)),
            ]),
            const SizedBox(height: 14),
            _PersonBlock(
              label: 'Mtumaji',
              name: e['from_full_name'] as String? ?? '—',
              phone: e['from_phone'] as String? ?? '',
              sector: _catLabel(e['from_category'] as String?),
              role: e['from_cadre'] as String? ?? '',
              region: e['from_region'] as String? ?? '',
              recipient: false,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(child: Icon(Icons.arrow_downward_rounded, size: 20, color: _kMuted)),
            ),
            _PersonBlock(
              label: 'Mpokeaji',
              name: e['to_full_name'] as String? ?? '—',
              phone: e['to_phone'] as String? ?? '',
              sector: _catLabel(e['to_category'] as String?),
              role: e['to_cadre'] as String? ?? '',
              region: e['to_region'] as String? ?? '',
              recipient: true,
            ),
          ]),
        ),
      ),
    );
  }
}

class _PersonBlock extends StatelessWidget {
  final String label;
  final String name;
  final String phone;
  final String sector;
  final String role;
  final String region;
  final bool recipient;
  const _PersonBlock({
    required this.label,
    required this.name,
    required this.phone,
    required this.sector,
    required this.role,
    required this.region,
    required this.recipient,
  });

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (sector.isNotEmpty) sector,
      if (role.isNotEmpty) _prettyRole(role),
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: recipient ? _kBlueBg : _kBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: recipient ? const Color(0xFFDBEAFE) : _kSoft,
          child: Text(_initials(name),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: recipient ? _kPrimary : _kInk)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: recipient ? _kPrimary : _kMuted)),
            const SizedBox(height: 2),
            // Jina linashuka mstari unaofuata — hakuna ellipsis
            Text(_titleCase(name),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: _kInk, height: 1.25)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 14, color: _kMuted, height: 1.3)),
            ],
            if (region.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 17, color: _kPrimary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(region,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _kPrimary)),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kLine),
      ),
      child: Column(children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        const Text('Imeshindikana kupakia mawasiliano',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Jaribu tena',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: _kPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kLine),
      ),
      child: Column(children: [
        const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        const Text('Hakuna matokeo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Jaribu jina au namba nyingine.',
            style: TextStyle(color: _kMuted, fontSize: 15)),
        const SizedBox(height: 14),
        TextButton(onPressed: onClear, child: const Text('Futa utafutaji')),
      ]),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final Map<String, dynamic> e;
  final bool sw;
  final ValueChanged<String> onCopy;
  const _DetailSheet({required this.e, required this.sw, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final type = e['contact_type'] as String? ?? 'call';
    final at = _parseTs(e['initiated_at'] as String? ?? '');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: _kLine, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _ChannelPill(type: type),
            const Spacer(),
            Text(
              at == null ? '' : '${_dateText(at, sw)}, ${_hm(at)}',
              style: const TextStyle(
                  fontSize: 15, color: _kMuted, fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 16),
          _contact(
            'Mtumaji',
            name: e['from_full_name'] as String? ?? '—',
            sector: _catLabel(e['from_category'] as String?),
            role: e['from_cadre'] as String? ?? '',
            region: e['from_region'] as String? ?? '',
            phone: e['from_phone'] as String? ?? '',
          ),
          const SizedBox(height: 12),
          _contact(
            'Mpokeaji',
            name: e['to_full_name'] as String? ?? '—',
            sector: _catLabel(e['to_category'] as String?),
            role: e['to_cadre'] as String? ?? '',
            region: e['to_region'] as String? ?? '',
            phone: e['to_phone'] as String? ?? '',
          ),
        ]),
      ),
    );
  }

  Widget _contact(String label,
      {required String name,
      required String sector,
      required String role,
      required String region,
      required String phone}) {
    final sub = [
      if (sector.isNotEmpty) sector,
      if (role.isNotEmpty) _prettyRole(role),
      if (region.isNotEmpty) region,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: _kMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(_titleCase(name),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 14, color: _kMuted)),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.phone_outlined, size: 18, color: _kPrimary),
            const SizedBox(width: 8),
            Text(phone,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _kPrimary)),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: 'Nakili namba',
              onPressed: () => onCopy(phone),
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
          ]),
        ],
      ]),
    );
  }
}
