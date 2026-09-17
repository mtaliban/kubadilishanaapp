import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kBlue      = Color(0xFF1E40AF);
const _kBlueBg    = Color(0xFFEFF6FF);
const _kGreen     = Color(0xFF16A34A);
const _kGreenBg   = Color(0xFFDCFCE7);
const _kEmerald   = Color(0xFF047857);
const _kEmeraldBg = Color(0xFFECFDF5);
const _kGrey900   = Color(0xFF111827);
const _kGrey500   = Color(0xFF6B7280);
const _kGrey400   = Color(0xFF9CA3AF);
const _kGrey200   = Color(0xFFE5E7EB);
const _kGrey50    = Color(0xFFF9FAFB);
const _kRed       = Color(0xFFDC2626);

const _kPageSize = 20;

Color _typeColor(String t) {
  switch (t) {
    case 'sms':      return _kBlue;
    case 'whatsapp': return _kEmerald;
    default:         return _kGreen;
  }
}

Color _typeBg(String t) {
  switch (t) {
    case 'sms':      return _kBlueBg;
    case 'whatsapp': return _kEmeraldBg;
    default:         return _kGreenBg;
  }
}

Color _typeBorder(String t) {
  switch (t) {
    case 'sms':      return const Color(0xFFBFDBFE);
    case 'whatsapp': return const Color(0xFFD1FAE5);
    default:         return const Color(0xFFBBF7D0);
  }
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'sms':      return Icons.sms_outlined;
    case 'whatsapp': return Icons.chat_outlined;
    default:         return Icons.phone_outlined;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'sms':      return 'SMS';
    case 'whatsapp': return 'WhatsApp';
    default:         return 'Simu';
  }
}

class AdminContactsPage extends StatefulWidget {
  const AdminContactsPage({super.key});
  @override
  State<AdminContactsPage> createState() => _AdminContactsPageState();
}

class _AdminContactsPageState extends State<AdminContactsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _filterType = '';
  int _page = 0;

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
      final res = await ApiService().getContactActivity(limit: 300);
      if (!mounted) return;
      final data = res.data;
      final raw = data is List ? data : ((data['contacts'] ?? data['results']) as List? ?? []);
      setState(() {
        _all = raw;
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
        final fromName  = (m['from_full_name'] as String? ?? m['caller_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final toName    = (m['to_full_name'] as String? ?? '').toLowerCase();
        final fromPhone = (m['from_phone'] as String? ?? '').toLowerCase();
        final toPhone   = (m['to_phone'] as String? ?? '').toLowerCase();
        final type      = (m['contact_type'] as String? ?? m['type'] as String? ?? '').toLowerCase();
        final matchQ    = q.isEmpty || fromName.contains(q) || toName.contains(q) || fromPhone.contains(q) || toPhone.contains(q);
        final matchType = _filterType.isEmpty || type == _filterType;
        return matchQ && matchType;
      }).toList();
      _page = 0;
    });
  }

  void _setType(String t) {
    setState(() { _filterType = t; });
    _applyFilter();
  }

  int _countType(String t) => _all.where((item) {
    final m = item as Map;
    final ct = m['contact_type'] as String? ?? m['type'] as String? ?? '';
    return ct == t;
  }).length;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: _kBlueBg, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.phone_in_talk_outlined, color: _kBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Waliopigiana',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                              Text('Historia ya mawasiliano',
                                  style: TextStyle(fontSize: 12, color: _kGrey500)),
                            ],
                          ),
                        ),
                        if (!_loading)
                          Text('${_filtered.length}/${_all.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kGrey500)),
                      ],
                    ),
                  ),
                  // Stat-filter pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _StatPill(
                          icon: Icons.trending_up,
                          label: 'Zote',
                          count: _all.length,
                          active: _filterType.isEmpty,
                          color: _kBlue,
                          bg: _kBlueBg,
                          border: const Color(0xFFBFDBFE),
                          onTap: () => _setType(''),
                        ),
                        const SizedBox(width: 6),
                        _StatPill(
                          icon: Icons.phone_outlined,
                          label: 'Simu',
                          count: _countType('call'),
                          active: _filterType == 'call',
                          color: _kGreen,
                          bg: _kGreenBg,
                          border: const Color(0xFFBBF7D0),
                          onTap: () => _setType(_filterType == 'call' ? '' : 'call'),
                        ),
                        const SizedBox(width: 6),
                        _StatPill(
                          icon: Icons.sms_outlined,
                          label: 'SMS',
                          count: _countType('sms'),
                          active: _filterType == 'sms',
                          color: _kBlue,
                          bg: _kBlueBg,
                          border: const Color(0xFFBFDBFE),
                          onTap: () => _setType(_filterType == 'sms' ? '' : 'sms'),
                        ),
                        const SizedBox(width: 6),
                        _StatPill(
                          icon: Icons.chat_outlined,
                          label: 'WhatsApp',
                          count: _countType('whatsapp'),
                          active: _filterType == 'whatsapp',
                          color: _kEmerald,
                          bg: _kEmeraldBg,
                          border: const Color(0xFFD1FAE5),
                          onTap: () => _setType(_filterType == 'whatsapp' ? '' : 'whatsapp'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Tafuta kwa jina au namba...',
                        hintStyle: const TextStyle(fontSize: 13, color: _kGrey400),
                        prefixIcon: const Icon(Icons.filter_list_outlined, color: _kGrey400, size: 16),
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
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_outlined, color: _kGrey500, size: 48),
                      const SizedBox(height: 12),
                      const Text('Hakuna mawasiliano bado',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kGrey500)),
                      const SizedBox(height: 4),
                      const Text('Watumiaji wataonekana hapa wanapopigiana simu',
                          style: TextStyle(fontSize: 11, color: _kGrey400)),
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
                      for (int p = 0; p < totalPages.clamp(0, 10); p++)
                        _PageNum(
                          n: p + 1,
                          active: _page == p,
                          onTap: () => setState(() => _page = p),
                        ),
                      if (totalPages > 10)
                        const Text('...', style: TextStyle(color: _kGrey400, fontSize: 12)),
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

  Widget _buildCard(Map<String, dynamic> item) {
    final fromName   = item['from_full_name'] as String? ?? item['caller_name'] as String? ?? item['full_name'] as String? ?? '—';
    final toName     = item['to_full_name'] as String? ?? '—';
    final fromCadre  = item['from_cadre'] as String? ?? '';
    final toCadre    = item['to_cadre'] as String? ?? '';
    final fromRegion = item['from_region'] as String? ?? '';
    final toRegion   = item['to_region'] as String? ?? '';
    final fromCat    = (item['from_category'] as String? ?? '') == 'education' ? 'Elimu' : 'Afya';
    final toCat      = (item['to_category'] as String? ?? '') == 'education' ? 'Elimu' : 'Afya';
    final type       = item['contact_type'] as String? ?? item['type'] as String? ?? 'call';
    final ts         = item['initiated_at'] as String? ?? item['created_at'] as String? ?? item['timestamp'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGrey200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeBg(type),
                  border: Border.all(color: _typeBorder(type)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon(type), size: 11, color: _typeColor(type)),
                    const SizedBox(width: 4),
                    Text(_typeLabel(type),
                        style: TextStyle(
                            fontSize: 11, color: _typeColor(type), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              if (ts.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 10, color: _kGrey400),
                    const SizedBox(width: 3),
                    Text(ts, style: const TextStyle(fontSize: 10, color: _kGrey400)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kGrey50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MTUMAJI',
                          style: TextStyle(
                              fontSize: 9, color: _kGrey400, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(fromName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: _kGrey900),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$fromCat · ${fromCadre.isNotEmpty ? fromCadre : '—'}',
                          style: const TextStyle(fontSize: 10, color: _kGrey500)),
                      if (fromRegion.isNotEmpty)
                        Text(fromRegion,
                            style: const TextStyle(
                                fontSize: 10, color: _kBlue, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kBlueBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MPOKEAJI',
                          style: TextStyle(
                              fontSize: 9, color: _kBlue, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(toName,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: _kGrey900),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$toCat · ${toCadre.isNotEmpty ? toCadre : '—'}',
                          style: const TextStyle(fontSize: 10, color: _kGrey500)),
                      if (toRegion.isNotEmpty)
                        Text(toRegion,
                            style: const TextStyle(
                                fontSize: 10, color: _kBlue, fontWeight: FontWeight.w500)),
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

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final Color color;
  final Color bg;
  final Color border;
  final VoidCallback onTap;
  const _StatPill({
    required this.icon, required this.label, required this.count,
    required this.active, required this.color, required this.bg,
    required this.border, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? bg : Colors.white,
          border: Border.all(color: active ? color : _kGrey200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? color : _kGrey400),
            const SizedBox(width: 5),
            Text('$count',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: active ? color : const Color(0xFF374151))),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active ? color : const Color(0xFF6B7280))),
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
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: active ? Colors.white : const Color(0xFF374151))),
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
