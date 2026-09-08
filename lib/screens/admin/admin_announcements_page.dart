import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

// ── Brand colours ──────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E40AF);
const _kBlue50    = Color(0xFFEFF6FF);
const _kBlue200   = Color(0xFFBFDBFE);
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

InputDecoration _inp(String hint, {IconData? prefix}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 14, color: _kGrey400),
  prefixIcon: prefix != null ? Icon(prefix, size: 18, color: _kGrey400) : null,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kGrey200),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kGrey200),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _kBlue, width: 1.5),
  ),
);

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Futa Tangazo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kGrey900)),
        content: const Text('Una uhakika wa kufuta tangazo hili?', style: TextStyle(fontSize: 14, color: _kGrey700)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _kGrey200),
              foregroundColor: _kGrey700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Hapana'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Futa'),
          ),
        ],
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
          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.campaign_outlined, size: 22, color: _kBlue),
              const SizedBox(width: 8),
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

          // ── Flash result ─────────────────────────────────────────
          if (_resultMsg.isNotEmpty) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _resultOk == true ? _kGreen50 : _kRed50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _resultOk == true ? const Color(0xFF86EFAC) : _kRed200),
              ),
              child: Row(
                children: [
                  Icon(
                    _resultOk == true ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                    size: 15,
                    color: _resultOk == true ? _kGreen600 : _kRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resultMsg,
                      style: TextStyle(fontSize: 13, color: _resultOk == true ? _kGreen600 : _kRed, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _resultMsg = ''),
                    child: const Icon(Icons.close, size: 15, color: _kGrey400),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Send form card ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kGrey200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Title ────────────────────────────────────────
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
                const SizedBox(height: 14),

                // ── 2. Message ──────────────────────────────────────
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
                const SizedBox(height: 14),

                // ── 3. Audience ─────────────────────────────────────
                const Text(
                  'WALENGWA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _kGrey500),
                ),
                const SizedBox(height: 8),
                _buildAudiencePills(),
                const SizedBox(height: 12),

                // ── 4. User search (when audience = 'user') ─────────
                if (_audience == 'user') ...[
                  _buildUserSearch(),
                  const SizedBox(height: 14),
                ],

                // ── 5. Send button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_sending || _titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      disabledBackgroundColor: _kBlue.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Tuma Tangazo'),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── History header ────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: _kGrey500),
              const SizedBox(width: 6),
              Text(
                'HISTORIA YA MATANGAZO (${_announcements.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _kGrey500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── History list ──────────────────────────────────────────
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2),
              ),
            )
          else if (_announcements.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kGrey200),
              ),
              child: const Column(
                children: [
                  Icon(Icons.campaign_outlined, size: 28, color: _kGrey400),
                  SizedBox(height: 8),
                  Text(
                    'Hakuna matangazo bado',
                    style: TextStyle(fontSize: 14, color: _kGrey500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else ...[
            for (final a in _pageItems)
              _AnnTile(
                item: a,
                audLabel: _audLabel((a['audience'] ?? 'all').toString()),
                busyId: _busyId,
                onResend: () => _resend((a['announcement_id'] ?? a['_id'] ?? '').toString()),
                onDelete: () => _delete((a['announcement_id'] ?? a['_id'] ?? '').toString()),
              ),
            // Pagination
            if (_totalPages > 1) ...[
              const SizedBox(height: 4),
              _buildPagination(),
            ],
          ],
        ],
      ),
    );
  }

  // ── Audience pills ────────────────────────────────────────────────
  Widget _buildAudiencePills() {
    final opts = <Map<String, String>>[
      {'v': 'all',  'label': 'Wote'},
      for (final d in _departments)
        {'v': (d['code'] as String?) ?? '', 'label': (d['name'] as String?) ?? ''},
      {'v': 'user', 'label': 'Mtumiaji Mmoja'},
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: opts.map((o) {
        final active = _audience == o['v'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _audience = o['v']!;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active ? _kBlue : Colors.white,
              border: Border.all(color: active ? _kBlue : _kGrey200),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              o['label']!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _kGrey600,
              ),
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
        // Selected user pill
        if (_targetName.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _kGreen50, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 13, color: _kGreen600),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _targetName,
                    style: const TextStyle(fontSize: 12, color: _kGreen600, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() { _targetId = ''; _targetName = ''; }),
                  child: const Icon(Icons.close, size: 13, color: _kGreen600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Search input
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 14),
          decoration: _inp('Tafuta jina, simu, email...', prefix: Icons.search),
        ),

        // Results
        if (_searchResults != null) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _kGrey200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _searchResults!.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined, size: 14, color: _kOrange600),
                        SizedBox(width: 6),
                        Text('Mtumiaji hajapatikana', style: TextStyle(fontSize: 13, color: _kOrange600)),
                      ],
                    ),
                  )
                : Column(
                    children: _searchResults!.map((u) {
                      final name  = (u['full_name']    ?? '').toString();
                      final phone = (u['phone_primary'] ?? '').toString();
                      final cadre = (u['cadre_code']   ?? '').toString();
                      return InkWell(
                        onTap: () => _pickUser(u),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: _kGrey500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.isNotEmpty ? name : phone,
                                        style: const TextStyle(fontSize: 13, color: _kGrey900, fontWeight: FontWeight.w600)),
                                    Text('$phone${cadre.isNotEmpty ? ' · $cadre' : ''}',
                                        style: const TextStyle(fontSize: 11, color: _kGrey500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
        GestureDetector(
          onTap: safe > 1 ? () => setState(() => _histPage = safe - 1) : null,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _kGrey200),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(Icons.chevron_left, color: safe > 1 ? _kGrey700 : _kGrey400),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$safe / $_totalPages',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey500),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: safe < _totalPages ? () => setState(() => _histPage = safe + 1) : null,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _kGrey200),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(Icons.chevron_right, color: safe < _totalPages ? _kGrey700 : _kGrey400),
          ),
        ),
      ],
    );
  }
}

// ── Announcement history tile ──────────────────────────────────────
class _AnnTile extends StatelessWidget {
  final dynamic  item;
  final String   audLabel;
  final String   busyId;
  final VoidCallback onResend;
  final VoidCallback onDelete;

  const _AnnTile({
    required this.item,
    required this.audLabel,
    required this.busyId,
    required this.onResend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id          = (item['announcement_id'] ?? item['_id'] ?? '').toString();
    final title       = (item['title']            ?? '').toString();
    final message     = (item['message'] ?? item['body'] ?? '').toString();
    final recipients  = item['recipient_count'] ?? 0;
    final createdBy   = (item['created_by_name'] ?? item['sender_name'] ?? '').toString();
    final createdAt   = (item['created_at'] ?? '').toString();
    final isBusy      = busyId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGrey200),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + audience badge + time ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.campaign_outlined, size: 15, color: _kGrey400),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kGrey100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            audLabel,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kGrey600),
                          ),
                        ),
                        if (createdAt.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(_ago(createdAt), style: const TextStyle(fontSize: 10, color: _kGrey400)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Message ────────────────────────────────────────────
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: _kGrey700, height: 1.45),
          ),
          const SizedBox(height: 10),

          // ── Meta: recipients + created_by ──────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 11, color: _kGrey500),
                  const SizedBox(width: 4),
                  Text(
                    'Walengwa: $recipients watu',
                    style: const TextStyle(fontSize: 11, color: _kGrey500),
                  ),
                ],
              ),
              if (createdBy.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 11, color: _kGrey500),
                    const SizedBox(width: 4),
                    Text(createdBy, style: const TextStyle(fontSize: 11, color: _kGrey500)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Action buttons: Resend + Delete ────────────────────
          Row(
            children: [
              _pillBtn(
                label: 'Tuma Tena',
                icon: Icons.refresh_outlined,
                color: _kBlue700,
                bg: _kBlue50,
                border: _kBlue200,
                busy: isBusy,
                onTap: onResend,
              ),
              const SizedBox(width: 8),
              _pillBtn(
                label: 'Futa',
                icon: Icons.delete_outline,
                color: _kRed,
                bg: _kRed50,
                border: _kRed200,
                busy: isBusy,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillBtn({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Opacity(
        opacity: busy ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
                  : Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

