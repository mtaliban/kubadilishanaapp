import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kRed     = Color(0xFFDC2626);
const _kRedBg   = Color(0xFFFEE2E2);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

const _kOrangeBg  = Color(0xFFFFF7ED);
const _kOrangeFg  = Color(0xFFC2410C);
const _kOrangeBdr = Color(0xFFFED7AA);

const _kPageSize = 5;

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});
  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();
  int _tabIndex = 0;
  int _page = 0;
  Map<String, String>? _flash;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService().adminListFeedback(status: '', q: '');
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _all = data is List ? data : (data['items'] as List? ?? data['results'] as List? ?? []);
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((item) {
        final m = item as Map<String, dynamic>;
        final name    = (m['user_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final msg     = (m['message'] as String? ?? m['subject'] as String? ?? '').toLowerCase();
        final replied = m['reply'] != null || m['admin_reply'] != null;
        final matchQ  = q.isEmpty || name.contains(q) || msg.contains(q);
        bool matchTab = true;
        if (_tabIndex == 1) matchTab = !replied;
        if (_tabIndex == 2) matchTab = replied;
        return matchQ && matchTab;
      }).toList();
      _page = 0;
    });
  }

  void _setTab(int i) {
    setState(() { _tabIndex = i; });
    _applyFilter();
  }

  void _showFlash(String type, String msg) {
    setState(() => _flash = {'type': type, 'msg': msg});
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Futa Maoni'),
        content: const Text('Una uhakika unataka kufuta maoni haya?'),
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
      await ApiService().adminDeleteFeedback(id);
      if (!mounted) return;
      _showFlash('success', 'Yamefutwa');
      _load();
    } catch (e) {
      if (!mounted) return;
      _showFlash('error', 'Kosa: $e');
    }
  }

  Future<void> _reply(String id, String text) async {
    try {
      await ApiService().adminReplyFeedback(id, text);
      if (!mounted) return;
      _showFlash('success', 'Jibu limetumwa kwa mtumiaji');
      _load();
    } catch (e) {
      if (!mounted) return;
      _showFlash('error', 'Imeshindikana');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filtered.length / _kPageSize).ceil().clamp(0, 9999);
    final pageItems = _loading || _error != null
        ? <dynamic>[]
        : _filtered.skip(_page * _kPageSize).take(_kPageSize).toList();

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
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.feedback_outlined, color: _kBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Maoni',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                              Text('Maoni na malamiko ya watumiaji',
                                  style: TextStyle(fontSize: 12, color: _kGrey500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Tafuta maoni...',
                        hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
                        prefixIcon: const Icon(Icons.search, color: _kGrey400),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _TabPill(label: 'Yote', selected: _tabIndex == 0, onTap: () => _setTab(0)),
                        const SizedBox(width: 8),
                        _TabPill(label: 'Hayajajibiwa', selected: _tabIndex == 1, onTap: () => _setTab(1)),
                        const SizedBox(width: 8),
                        _TabPill(label: 'Yamejibiwa', selected: _tabIndex == 2, onTap: () => _setTab(2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _kGrey200),
                ],
              ),
            ),
            // Flash message
            if (_flash != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _flash!['type'] == 'success' ? _kGreenBg : _kRedBg,
                    border: Border.all(
                      color: _flash!['type'] == 'success'
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFECACA),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _flash!['type'] == 'success'
                            ? Icons.check_circle_outline
                            : Icons.warning_outlined,
                        size: 13,
                        color: _flash!['type'] == 'success' ? _kGreen : _kRed,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _flash!['msg']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _flash!['type'] == 'success' ? _kGreen : _kRed,
                          ),
                        ),
                      ),
                    ],
                  ),
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
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.feedback_outlined, color: _kGrey500, size: 48),
                      const SizedBox(height: 12),
                      const Text('Hakuna maoni',
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
                    (ctx, i) => _FeedbackCard(
                      key: ValueKey(pageItems[i]['id'] ?? i),
                      index: (_page * _kPageSize) + i + 1,
                      item: pageItems[i] as Map<String, dynamic>,
                      onReply: _reply,
                      onDelete: _delete,
                    ),
                    childCount: pageItems.length,
                  ),
                ),
              ),
            // Pagination
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

class _FeedbackCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final Future<void> Function(String id, String text) onReply;
  final Future<void> Function(String id) onDelete;
  const _FeedbackCard({
    super.key,
    required this.index,
    required this.item,
    required this.onReply,
    required this.onDelete,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item      = widget.item;
    final id        = item['id']?.toString() ?? '';
    final name      = item['user_name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
    final phone     = item['user_phone'] as String? ?? item['phone'] as String? ?? '';
    final subject   = item['subject'] as String? ?? '';
    final msg       = item['message'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final reply     = item['reply'] as String? ?? item['admin_reply'] as String?;
    final replied   = reply != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: index + name/phone | status badge + delete
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.index}',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: _kGrey400),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900)),
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 11, color: _kBlue),
                          const SizedBox(width: 3),
                          Text(phone,
                              style: const TextStyle(
                                  fontSize: 11, color: _kBlue, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: replied ? _kGreenBg : _kOrangeBg,
                      border: Border.all(
                          color: replied
                              ? const Color(0xFFBBF7D0)
                              : _kOrangeBdr),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          replied ? Icons.check_circle_outline : Icons.access_time,
                          size: 10,
                          color: replied ? _kGreen : _kOrangeFg,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          replied ? 'Imejibiwa' : 'Wazi',
                          style: TextStyle(
                            fontSize: 10,
                            color: replied ? _kGreen : _kOrangeFg,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => widget.onDelete(id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kRedBg,
                        border: Border.all(color: const Color(0xFFFECACA)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete_outline, size: 12, color: _kRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (subject.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subject,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          ],
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(msg,
                style: const TextStyle(
                    fontSize: 13, color: _kGrey700, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 10, color: _kGrey400),
              const SizedBox(width: 3),
              Text(createdAt, style: const TextStyle(fontSize: 11, color: _kGrey400)),
            ],
          ),
          // Admin reply box
          if (reply != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBlueBg,
                border: Border.all(color: const Color(0xFFBFDBFE)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified_user_outlined, size: 11, color: _kBlue),
                      SizedBox(width: 4),
                      Text('JIBU LAKO',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _kBlue,
                              letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reply,
                      style: const TextStyle(
                          fontSize: 12, color: _kGrey700, height: 1.4)),
                ],
              ),
            ),
          ],
          // Inline reply input (always visible)
          const SizedBox(height: 10),
          const Divider(height: 1, color: _kGrey100),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Andika jibu...',
                    hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kGrey200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBlue)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : () async {
                  final text = _ctrl.text.trim();
                  if (text.isEmpty) return;
                  setState(() => _sending = true);
                  await widget.onReply(id, text);
                  if (mounted) {
                    _ctrl.clear();
                    setState(() => _sending = false);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.send, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Jibu',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kBlueBg : Colors.white,
          border: Border.all(color: selected ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? _kBlue : _kGrey700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
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
        width: 32, height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? _kBlue : Colors.white,
          border: Border.all(color: active ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text('$n',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : _kGrey700)),
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
        width: 32, height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: onTap != null ? _kBlue : _kGrey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 16, color: onTap != null ? _kBlue : _kGrey200),
      ),
    );
  }
}
