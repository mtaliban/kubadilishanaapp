import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ──────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kBlue700   = Color(0xFF1D4ED8);
const _kGrey100   = Color(0xFFF3F4F6);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey600   = Color(0xFF4B5563);
const _kGrey700   = Color(0xFF374151);
const _kGrey900   = Color(0xFF111827);
const _kGreen50   = Color(0xFFF0FDF4);
const _kGreen600  = Color(0xFF16A34A);
const _kRed       = Color(0xFFDC2626);
const _kRed50     = Color(0xFFFEF2F2);
const _kRed200    = Color(0xFFFECACA);
const _kOrange600 = Color(0xFFEA580C);

const _kPageSize = 5;

// ── Helpers ────────────────────────────────────────────────────────
String _ago(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1)  return 'Sasa hivi';
    if (diff.inMinutes < 60) return 'dakika ${diff.inMinutes} iliyopita';
    if (diff.inHours < 24)   return 'saa ${diff.inHours} iliyopita';
    return 'siku ${diff.inDays} iliyopita';
  } catch (_) {
    return iso.split('T').first;
  }
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  } catch (_) {
    return iso.split('T').first;
  }
}

InputDecoration _inp(String hint, {IconData? prefix}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 14, color: _kGrey400),
  prefixIcon: prefix != null ? Icon(prefix, size: 18, color: _kGrey400) : null,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _kGrey200),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _kGrey200),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _kBlue, width: 1.5),
  ),
);

// ── Audience colour helper ─────────────────────────────────────────
Color _audColor(String aud) {
  if (aud == 'all')  return _kBlue;
  if (aud == 'user') return _kOrange600;
  return _kGreen600;
}

IconData _audIcon(String aud) {
  if (aud == 'all')  return Icons.public;
  if (aud == 'user') return Icons.person;
  return Icons.business;
}

// ── Page ───────────────────────────────────────────────────────────
class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  // form fields
  final _titleCtrl   = TextEditingController();
  final _msgCtrl     = TextEditingController();
  final _searchCtrl  = TextEditingController();
  String _audience   = 'all';
  String _targetId   = '';
  String _targetName = '';
  List<dynamic>? _searchResults; // null=idle, []=no results, [..]=hits
  Timer? _debounce;

  // state
  List<dynamic> _departments   = [];
  List<dynamic> _announcements = [];
  bool   _loading = true;
  bool   _sending = false;
  String _busyId  = '';  // for resend/delete busy state
  int    _histPage = 1;

  // result
  bool?  _resultOk;
  String _resultMsg = '';

  @override
  void initState() {
    super.initState();
    _load();
    _loadDepts();
    _titleCtrl.addListener(() => setState(() {}));
    _msgCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!mounted) return;
    try {
      final res  = await ApiService().adminListAnnouncements();
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _announcements = (data['announcements'] ?? []) as List<dynamic>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDepts() async {
    try {
      final res  = await ApiService().adminListDepartments();
      final data = res.data;
      List<dynamic> list = [];
      if (data is Map) {
        list = (data['departments'] ?? data['data'] ?? []) as List<dynamic>;
      } else if (data is List) {
        list = data;
      }
      if (mounted) setState(() => _departments = list);
    } catch (_) {}
  }

  // ── User search ───────────────────────────────────────────────────
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() => _searchResults = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    try {
      final res  = await ApiService().adminUsers(params: {'q': q, 'limit': '10'});
      final data = res.data as Map<String, dynamic>;
      if (mounted) setState(() => _searchResults = (data['users'] ?? []) as List<dynamic>);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    }
  }

  void _pickUser(dynamic u) {
    final id   = (u['_id'] ?? u['user_id'] ?? '').toString();
    final name = (u['full_name'] ?? '').toString();
    final phone = (u['phone_primary'] ?? '').toString();
    setState(() {
      _targetId      = id;
      _targetName    = name.isNotEmpty ? '$name ($phone)' : id;
      _searchResults = null;
      _searchCtrl.clear();
    });
  }

  // ── Send ──────────────────────────────────────────────────────────
  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final msg   = _msgCtrl.text.trim();
    if (title.isEmpty || msg.isEmpty || _sending) return;
    setState(() { _sending = true; _resultOk = null; _resultMsg = ''; });

    try {
      final body = <String, dynamic>{
        'title':   title,
        'message': msg,
        'audience': _audience,
        if (_audience == 'user' && _targetId.isNotEmpty)
          'target_user_id': _targetId,
      };
      final res = await ApiService().adminSendAnnouncement(body);
      final sent = (res.data as Map<String, dynamic>?)?['sent_to'] ?? 0;
      _titleCtrl.clear();
      _msgCtrl.clear();
      if (mounted) {
        setState(() {
          _audience   = 'all';
          _targetId   = '';
          _targetName = '';
          _searchResults = null;
          _sending    = false;
          _resultOk   = true;
          _resultMsg  = '✓ Tangazo limetumwa kwa $sent walengwa';
          _histPage   = 1;
        });
        _load();
      }
    } catch (e) {
      String errMsg = 'Imeshindikana kutuma — jaribu tena';
      try {
        final d = (e as dynamic).response?.data?['detail'];
        if (d is String) errMsg = d;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _sending   = false;
          _resultOk  = false;
          _resultMsg = errMsg;
        });
      }
    }
  }

  // ── Resend ────────────────────────────────────────────────────────
  Future<void> _resend(String id) async {
    if (id.isEmpty || _busyId.isNotEmpty) return;
    setState(() { _busyId = id; _resultOk = null; _resultMsg = ''; });
    try {
      final res = await ApiService().post('/admin/announcements/$id/resend');
      final sent = (res.data as Map<String, dynamic>?)?['sent_to'] ?? 0;
      if (mounted) {
        setState(() {
          _busyId    = '';
          _resultOk  = true;
          _resultMsg = '✓ Tangazo limetumwa tena kwa $sent walengwa';
        });
        _load();
      }
    } catch (e) {
      if (mounted) setState(() { _busyId = ''; _resultOk = false; _resultMsg = 'Imeshindikana kutuma tena'; });
    }
  }

  // ── Delete ────────────────────────────────────────────────────────
  Future<void> _delete(String id) async {
    if (id.isEmpty || _busyId.isNotEmpty) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _kRed50, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline, color: _kRed, size: 20),
            ),
            const SizedBox(height: 12),
            const Text('Futa Tangazo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
            const SizedBox(height: 6),
            const Text('Una uhakika wa kufuta tangazo hili?',
                style: TextStyle(fontSize: 13, color: _kGrey500), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(_, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _kGrey200),
                    foregroundColor: _kGrey700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Hapana'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(_, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Futa'),
                ),
              ),
            ]),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() { _busyId = id; _resultOk = null; _resultMsg = ''; });
    try {
      await ApiService().adminDeleteAnnouncement(id);
      if (mounted) {
        setState(() {
          _busyId = '';
          _announcements = _announcements.where((a) => (a['announcement_id'] ?? a['_id'] ?? '') != id).toList();
          _resultOk  = true;
          _resultMsg = '✓ Tangazo limefutwa';
          if (_histPage > (_totalPages).clamp(1, 9999)) _histPage = 1;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _busyId = ''; _resultOk = false; _resultMsg = 'Imeshindikana kufuta'; });
    }
  }

  // ── Audience label ────────────────────────────────────────────────
  String _audLabel(String aud) {
    if (aud == 'all')  return 'Wote';
    if (aud == 'user') return 'Mtumiaji Mmoja';
    try {
      final d = _departments.firstWhere((x) => x['code'] == aud, orElse: () => null);
      if (d != null) return (d['name'] as String?) ?? aud;
    } catch (_) {}
    return aud;
  }

  // ── Pagination ────────────────────────────────────────────────────
  int get _totalPages => (_announcements.length / _kPageSize).ceil().clamp(1, 99999);

  List<dynamic> get _pageItems {
    final safe  = _histPage.clamp(1, _totalPages);
    final start = (safe - 1) * _kPageSize;
    final end   = (start + _kPageSize).clamp(0, _announcements.length);
    return _announcements.sublist(start, end);
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Page header ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kBlue, _kBlue700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Matangazo',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGrey900),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tuma matangazo kwa watumiaji wote au wachaguliwa',
                      style: TextStyle(fontSize: 12, color: _kGrey500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Result banner ────────────────────────────────────────
          if (_resultMsg.isNotEmpty) ...[
            _ResultBanner(
              ok: _resultOk == true,
              message: _resultMsg,
              onDismiss: () => setState(() => _resultMsg = ''),
            ),
            const SizedBox(height: 12),
          ],

          // ── Compose card ──────────────────────────────────────────
          _buildComposeCard(),
          const SizedBox(height: 24),

          // ── History header ────────────────────────────────────────
          _buildHistoryHeader(),
          const SizedBox(height: 12),

          // ── History list ──────────────────────────────────────────
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2),
              ),
            )
          else if (_announcements.isEmpty)
            _buildEmptyState()
          else ...[
            for (final a in _pageItems)
              _AnnTile(
                item: a,
                audLabel: _audLabel((a['audience'] ?? 'all').toString()),
                audRaw: (a['audience'] ?? 'all').toString(),
                busyId: _busyId,
                onResend: () => _resend((a['announcement_id'] ?? a['_id'] ?? '').toString()),
                onDelete: () => _delete((a['announcement_id'] ?? a['_id'] ?? '').toString()),
              ),
            if (_totalPages > 1) ...[
              const SizedBox(height: 4),
              _buildPagination(),
            ],
          ],
        ],
      ),
    );
  }

  // ── Compose card ──────────────────────────────────────────────────
  Widget _buildComposeCard() {
    final titleLen = _titleCtrl.text.length;
    final msgLen   = _msgCtrl.text.length;
    final canSend  = !_sending && _titleCtrl.text.trim().isNotEmpty && _msgCtrl.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue gradient banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBlue, _kBlue700],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.campaign, size: 22, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Tuma Tangazo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // White form area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title field ─────────────────────────────────────
                const Text(
                  'KICHWA CHA HABARI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _kGrey500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  style: const TextStyle(fontSize: 14, color: _kGrey900),
                  decoration: _inp('Mfano: Tangazo la Uhamisho wa Mwalimu').copyWith(counterText: ''),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$titleLen / 120',
                    style: const TextStyle(fontSize: 11, color: _kGrey400),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Message field ───────────────────────────────────
                const Text(
                  'UJUMBE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _kGrey500),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 5,
                  minLines: 4,
                  maxLength: 2000,
                  style: const TextStyle(fontSize: 14, color: _kGrey900),
                  decoration: _inp('Andika ujumbe wa tangazo hapa...').copyWith(counterText: ''),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$msgLen / 2000',
                    style: const TextStyle(fontSize: 11, color: _kGrey400),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Audience pills ──────────────────────────────────
                const Text(
                  'WALENGWA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _kGrey500),
                ),
                const SizedBox(height: 8),
                _buildAudiencePills(),
                const SizedBox(height: 12),

                // ── User search ─────────────────────────────────────
                if (_audience == 'user') ...[
                  _buildUserSearch(),
                  const SizedBox(height: 14),
                ],

                // ── Send button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canSend ? _send : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      disabledBackgroundColor: _kBlue.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, size: 17),
                              SizedBox(width: 8),
                              Text('Tuma Tangazo'),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── History section header ─────────────────────────────────────────
  Widget _buildHistoryHeader() {
    return Row(
      children: [
        const Text(
          'MATANGAZO YALIYOTUMWA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: _kGrey500,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _kBlue,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_announcements.length}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGrey200),
      ),
      child: const Column(
        children: [
          Icon(Icons.campaign_outlined, size: 36, color: _kGrey400),
          SizedBox(height: 10),
          Text(
            'Hakuna matangazo bado',
            style: TextStyle(fontSize: 14, color: _kGrey500, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            'Matangazo yaliyotumwa yataonekana hapa',
            style: TextStyle(fontSize: 12, color: _kGrey400),
          ),
        ],
      ),
    );
  }

  // ── Audience pills ────────────────────────────────────────────────
  Widget _buildAudiencePills() {
    final opts = <Map<String, dynamic>>[
      {'v': 'all',  'label': 'Wote',         'icon': Icons.public},
      {'v': 'user', 'label': 'Mtu Mmoja',    'icon': Icons.person},
      for (final d in _departments)
        {'v': (d['code'] as String?) ?? '', 'label': (d['name'] as String?) ?? '', 'icon': Icons.business},
    ];

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: opts.map((o) {
        final active = _audience == o['v'];
        final icon   = o['icon'] as IconData;
        return GestureDetector(
          onTap: () {
            setState(() {
              _audience = o['v'] as String;
              if (_audience != 'user') {
                _targetId   = '';
                _targetName = '';
                _searchResults = null;
                _searchCtrl.clear();
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? _kBlue : Colors.white,
              border: Border.all(color: active ? _kBlue : _kGrey200, width: active ? 1.5 : 1.0),
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? [const BoxShadow(color: Color(0x331E40AF), blurRadius: 6, offset: Offset(0, 2))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: active ? Colors.white : _kGrey500),
                const SizedBox(width: 5),
                Text(
                  o['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : _kGrey600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── User search ───────────────────────────────────────────────────
  Widget _buildUserSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected user chip
        if (_targetName.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _kGreen50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 14, color: _kGreen600),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _targetName,
                    style: const TextStyle(fontSize: 13, color: _kGreen600, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() { _targetId = ''; _targetName = ''; }),
                  child: const Icon(Icons.close, size: 15, color: _kGreen600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Search field
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 14),
          decoration: _inp('Tafuta jina, simu, email...', prefix: Icons.search),
        ),

        // Results dropdown
        if (_searchResults != null) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _kGrey200),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: _searchResults!.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined, size: 15, color: _kOrange600),
                        SizedBox(width: 6),
                        Text('Mtumiaji hajapatikana', style: TextStyle(fontSize: 13, color: _kOrange600)),
                      ],
                    ),
                  )
                : Column(
                    children: _searchResults!.asMap().entries.map((entry) {
                      final idx  = entry.key;
                      final u    = entry.value;
                      final name  = (u['full_name']    ?? '').toString();
                      final phone = (u['phone_primary'] ?? '').toString();
                      final cadre = (u['cadre_code']   ?? '').toString();
                      return Column(
                        children: [
                          if (idx > 0) const Divider(height: 1, color: _kGrey100),
                          InkWell(
                            onTap: () => _pickUser(u),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _kBlue50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.person_outline, size: 16, color: _kBlue),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.isNotEmpty ? name : phone,
                                          style: const TextStyle(fontSize: 13, color: _kGrey900, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '$phone${cadre.isNotEmpty ? ' · $cadre' : ''}',
                                          style: const TextStyle(fontSize: 11, color: _kGrey500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 16, color: _kGrey400),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ],
    );
  }

  // ── Pagination ────────────────────────────────────────────────────
  Widget _buildPagination() {
    final safe = _histPage.clamp(1, _totalPages);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pageBtn(
          icon: Icons.chevron_left,
          enabled: safe > 1,
          onTap: () => setState(() => _histPage = safe - 1),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kGrey100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$safe / $_totalPages',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey700),
          ),
        ),
        const SizedBox(width: 16),
        _pageBtn(
          icon: Icons.chevron_right,
          enabled: safe < _totalPages,
          onTap: () => setState(() => _histPage = safe + 1),
        ),
      ],
    );
  }

  Widget _pageBtn({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : _kGrey100,
          border: Border.all(color: _kGrey200),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [const BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Icon(icon, size: 18, color: enabled ? _kGrey700 : _kGrey400),
      ),
    );
  }
}

// ── Result banner ──────────────────────────────────────────────────
class _ResultBanner extends StatelessWidget {
  final bool ok;
  final String message;
  final VoidCallback onDismiss;

  const _ResultBanner({required this.ok, required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final bg     = ok ? _kGreen50 : _kRed50;
    final border = ok ? const Color(0xFF86EFAC) : _kRed200;
    final color  = ok ? _kGreen600 : _kRed;
    final icon   = ok ? Icons.check_circle : Icons.error_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(Icons.close, size: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Announcement history tile ──────────────────────────────────────
class _AnnTile extends StatefulWidget {
  final dynamic  item;
  final String   audLabel;
  final String   audRaw;
  final String   busyId;
  final VoidCallback onResend;
  final VoidCallback onDelete;

  const _AnnTile({
    required this.item,
    required this.audLabel,
    required this.audRaw,
    required this.busyId,
    required this.onResend,
    required this.onDelete,
  });

  @override
  State<_AnnTile> createState() => _AnnTileState();
}

class _AnnTileState extends State<_AnnTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final id         = (widget.item['announcement_id'] ?? widget.item['_id'] ?? '').toString();
    final title      = (widget.item['title']            ?? '').toString();
    final message    = (widget.item['message'] ?? widget.item['body'] ?? '').toString();
    final recipients = widget.item['recipient_count'] ?? 0;
    final createdAt  = (widget.item['created_at'] ?? '').toString();
    final isBusy     = widget.busyId == id;
    final senderName = (() {
      final cb = widget.item['created_by'];
      if (cb is Map) return (cb['full_name'] ?? cb['name'] ?? '').toString();
      return (widget.item['sender_name'] ?? widget.item['admin_name'] ?? '').toString();
    })();

    final accentColor = _audColor(widget.audRaw);
    final audIcon     = _audIcon(widget.audRaw);
    final timeStr     = _ago(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
          top: BorderSide(color: _kGrey200, width: 0.8),
          right: BorderSide(color: _kGrey200, width: 0.8),
          bottom: BorderSide(color: _kGrey200, width: 0.8),
        ),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colored icon circle
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.campaign, size: 18, color: accentColor),
                ),
                const SizedBox(width: 10),
                // Title + audience badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _kGrey900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          // Audience badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(audIcon, size: 11, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  widget.audLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Time
                if (timeStr.isNotEmpty)
                  Text(timeStr, style: const TextStyle(fontSize: 11, color: _kGrey400)),
              ],
            ),
          ),

          // ── Message body ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _kGrey700, height: 1.5),
                ),
                if (message.length > 120) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Funga' : 'Soma zaidi',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Meta: recipients + sender + date ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline, size: 13, color: _kGrey400),
                  const SizedBox(width: 4),
                  Text('kwa watu: $recipients',
                      style: const TextStyle(fontSize: 12, color: _kGrey600)),
                ]),
                if (senderName.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_outline, size: 13, color: _kGrey400),
                    const SizedBox(width: 4),
                    Text(senderName.toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: _kGrey600, fontWeight: FontWeight.w500)),
                  ]),
                if (createdAt.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.schedule, size: 12, color: _kGrey400),
                    const SizedBox(width: 4),
                    Text(_fmtDate(createdAt),
                        style: const TextStyle(fontSize: 11, color: _kGrey500)),
                  ]),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: _kGrey100),

          // ── Bottom row: actions ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                const Spacer(),
                _ActionBtn(
                  label: 'Tuma Tena',
                  icon: Icons.refresh,
                  color: _kBlue,
                  filled: false,
                  busy: isBusy,
                  onTap: widget.onResend,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'Futa',
                  icon: Icons.delete_outline,
                  color: _kRed,
                  filled: false,
                  busy: isBusy,
                  onTap: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small action button ────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool busy;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Opacity(
        opacity: busy ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? SizedBox(
                      width: 11, height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: filled ? Colors.white : color,
                      ),
                    )
                  : Icon(icon, size: 13, color: filled ? Colors.white : color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
