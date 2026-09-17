import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);

const _kPageSize = 6;

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];
  int _page = 0;

  List<dynamic> _departments = [];

  final _titleCtrl = TextEditingController();
  final _msgCtrl   = TextEditingController();
  String _type     = 'info';
  String _audience = 'all';
  bool   _sending  = false;
  String? _sendResult;

  final _userSearchCtrl = TextEditingController();
  List<dynamic> _userResults = [];
  Map<String, dynamic>? _selectedUser;
  bool _searchingUsers = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadDepts();
    _userSearchCtrl.addListener(_onUserSearch);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminListAnnouncements();
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _items = data is List ? data
            : (data['announcements'] as List?
                ?? data['results'] as List?
                ?? data['items'] as List?
                ?? []);
        _loading = false;
        _page = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _loadDepts() async {
    try {
      final r = await ApiService().adminListDepartments();
      final raw = r.data;
      if (!mounted) return;
      setState(() {
        _departments = raw is List ? raw : (raw['results'] ?? raw['items'] ?? raw['data'] ?? []);
      });
    } catch (_) {}
  }

  void _onUserSearch() async {
    final q = _userSearchCtrl.text.trim();
    if (q.isEmpty) { setState(() { _userResults = []; }); return; }
    setState(() { _searchingUsers = true; });
    try {
      final r = await ApiService().adminUsers(params: {'search': q, 'limit': 10}, useCache: false);
      if (!mounted) return;
      final data = r.data;
      setState(() {
        _userResults = data is List ? data : (data['results'] as List? ?? []);
        _searchingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _searchingUsers = false; });
    }
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) return;
    setState(() { _sending = true; _sendResult = null; });
    try {
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'type': _type,
        'audience': _audience,
      };
      if (_audience == 'user' && _selectedUser != null) {
        payload['user_id'] = _selectedUser!['id'];
      }
      await ApiService().adminSendAnnouncement(payload);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendResult = 'ok';
        _titleCtrl.clear();
        _msgCtrl.clear();
        _type = 'info';
        _audience = 'all';
        _selectedUser = null;
        _userSearchCtrl.clear();
        _userResults = [];
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() { _sending = false; _sendResult = e.toString(); });
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Tangazo'),
        content: const Text('Una uhakika unataka kufuta tangazo hili?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hapana')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Futa', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiService().adminDeleteAnnouncement(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  Future<void> _resend(String id) async {
    try {
      await ApiService().adminResendAnnouncement(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tangazo limetumwa tena'), backgroundColor: _kGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kosa: $e'), backgroundColor: _kRed),
      );
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'warning': return _kAmber;
      case 'success': return _kGreen;
      case 'urgent':  return _kRed;
      default:        return _kBlue;
    }
  }

  Color _typeBg(String t) {
    switch (t) {
      case 'warning': return _kAmberBg;
      case 'success': return _kGreenBg;
      case 'urgent':  return _kRedBg;
      default:        return _kBlueBg;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'warning': return 'Onyo';
      case 'success': return 'Mafanikio';
      case 'urgent':  return 'Haraka';
      default:        return 'Taarifa';
    }
  }

  String _audienceLabel(String a) {
    if (a == 'all') return 'Wote';
    if (a == 'user') return 'Mtu Mmoja';
    try {
      final dept = _departments.firstWhere((d) => (d['code'] ?? '') == a);
      return dept['name'] as String? ?? a;
    } catch (_) {
      return a;
    }
  }

  InputDecoration _inputDec(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: _kGrey500),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
    suffixIcon: suffix,
  );

  Widget _buildSendForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_alert_outlined, color: _kBlue, size: 16),
              ),
              const SizedBox(width: 8),
              Text('Tuma Tangazo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDec('Kichwa cha habari'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDec('Ujumbe wa tangazo...'),
          ),
          const SizedBox(height: 10),
          Text('Aina', style: TextStyle(fontSize: 11, color: _kGrey500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in ['info', 'warning', 'success', 'urgent'])
                  _Pill(
                    label: _typeLabel(t),
                    selected: _type == t,
                    color: _typeColor(t),
                    bg: _typeBg(t),
                    onTap: () => setState(() { _type = t; }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('Wasikilizaji', style: TextStyle(fontSize: 11, color: _kGrey500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Pill(
                  label: 'Wote',
                  selected: _audience == 'all',
                  color: _kBlue,
                  bg: _kBlueBg,
                  onTap: () => setState(() { _audience = 'all'; }),
                ),
                ..._departments.map((d) => _Pill(
                  label: '${d['icon'] != null ? '${d['icon']} ' : ''}${d['name'] ?? d['code']}',
                  selected: _audience == (d['code'] ?? ''),
                  color: _kBlue,
                  bg: _kBlueBg,
                  onTap: () => setState(() { _audience = d['code'] ?? 'all'; }),
                )),
                _Pill(
                  label: 'Mtu Mmoja',
                  selected: _audience == 'user',
                  color: _kAmber,
                  bg: _kAmberBg,
                  onTap: () => setState(() { _audience = 'user'; }),
                ),
              ],
            ),
          ),
          if (_audience == 'user') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _userSearchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDec(
                'Tafuta mtumiaji...',
                suffix: _searchingUsers
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
                        ),
                      )
                    : null,
              ),
            ),
            if (_selectedUser != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: _kBlue, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedUser!['full_name'] as String? ?? '',
                        style: const TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w600),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedUser = null;
                        _userSearchCtrl.clear();
                        _userResults = [];
                      }),
                      child: const Icon(Icons.close, color: _kBlue, size: 14),
                    ),
                  ],
                ),
              ),
            ],
            if (_userResults.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _kGrey200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _userResults.length,
                  itemBuilder: (context, i) {
                    final u = _userResults[i] as Map<String, dynamic>;
                    return InkWell(
                      onTap: () => setState(() {
                        _selectedUser = u;
                        _userSearchCtrl.text = u['full_name'] as String? ?? '';
                        _userResults = [];
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: _kGrey500),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                u['full_name'] as String? ?? '',
                                style: const TextStyle(fontSize: 13, color: _kGrey900),
                              ),
                            ),
                            Text(
                              u['phone'] as String? ?? '',
                              style: const TextStyle(fontSize: 11, color: _kGrey500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          if (_sendResult != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _sendResult == 'ok' ? _kGreenBg : _kRedBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _sendResult == 'ok' ? Icons.check_circle_outline : Icons.error_outline,
                    color: _sendResult == 'ok' ? _kGreen : _kRed,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sendResult == 'ok' ? 'Tangazo limetumwa!' : 'Kosa: $_sendResult',
                      style: TextStyle(
                        fontSize: 12,
                        color: _sendResult == 'ok' ? _kGreen : _kRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Tuma Tangazo',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id            = item['id']?.toString() ?? '';
    final title         = item['title'] as String? ?? '';
    final message       = item['message'] as String? ?? '';
    final type          = item['type'] as String? ?? 'info';
    final audience      = item['audience'] as String? ?? 'all';
    final createdAt     = item['created_at'] as String? ?? '';
    final createdBy     = item['created_by'] as String? ?? item['creator_name'] as String? ?? '';
    final recipientsCount = item['recipients_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.campaign_outlined, color: _kBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _audienceLabel(audience),
                  style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(fontSize: 13, color: _kGrey700, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (recipientsCount > 0) ...[
                const Icon(Icons.people_outline, size: 11, color: _kGrey500),
                const SizedBox(width: 3),
                Text('$recipientsCount', style: const TextStyle(fontSize: 11, color: _kGrey500)),
                const SizedBox(width: 10),
              ],
              if (createdBy.isNotEmpty) ...[
                const Icon(Icons.person_outline, size: 11, color: _kGrey500),
                const SizedBox(width: 3),
                Text(createdBy, style: const TextStyle(fontSize: 11, color: _kGrey500)),
                const SizedBox(width: 10),
              ],
              if (createdAt.isNotEmpty) ...[
                const Icon(Icons.access_time, size: 11, color: _kGrey500),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(createdAt, style: const TextStyle(fontSize: 11, color: _kGrey500)),
                ),
              ] else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _typeBg(type), borderRadius: BorderRadius.circular(4)),
                child: Text(_typeLabel(type),
                    style: TextStyle(fontSize: 10, color: _typeColor(type), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ActionPill(
                icon: Icons.replay,
                label: 'Tuma Tena',
                color: _kBlue,
                bg: _kBlueBg,
                onTap: () => _resend(id),
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Icons.delete_outline,
                label: 'Futa',
                color: _kRed,
                bg: _kRedBg,
                onTap: () => _delete(id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_items.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems  = _loading || _error != null
        ? <dynamic>[]
        : _items.skip(_page * _kPageSize).take(_kPageSize).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _kBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.notifications_outlined, color: _kBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Matangazo',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                            Text('Tuma taarifa kwa watumiaji',
                                style: TextStyle(fontSize: 12, color: _kGrey500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildSendForm(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Historia ya Matangazo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _kGrey200),
                ],
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: _kBlue)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: _kRed, size: 48),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Jaribu tena'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              )
            else if (_items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, color: _kGrey500, size: 48),
                      SizedBox(height: 12),
                      Text('Hakuna matangazo bado',
                          style: TextStyle(color: _kGrey500)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildCard(pageItems[i] as Map<String, dynamic>),
                    childCount: pageItems.length,
                  ),
                ),
              ),
            if (!_loading && _error == null && totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PageBtn(
                        icon: Icons.chevron_left,
                        onTap: _page > 0 ? () => setState(() => _page--) : null,
                      ),
                      for (int p = 0; p < totalPages; p++)
                        _PageNum(
                          n: p + 1,
                          active: _page == p,
                          onTap: () => setState(() => _page = p),
                        ),
                      _PageBtn(
                        icon: Icons.chevron_right,
                        onTap: _page < totalPages - 1 ? () => setState(() => _page++) : null,
                      ),
                    ],
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _Pill({
    required this.label, required this.selected,
    required this.color, required this.bg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : Colors.white,
          border: Border.all(color: selected ? color : _kGrey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? color : _kGrey700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ActionPill({
    required this.icon, required this.label,
    required this.color, required this.bg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PageNum extends StatelessWidget {
  final int n;
  final bool active;
  final VoidCallback onTap;
  const _PageNum({required this.n, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          border: Border.all(color: active ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            '$n',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : _kGrey700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PageBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: onTap != null ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16, color: onTap != null ? _kBlue : _kGrey200),
      ),
    );
  }
}
