import 'package:flutter/material.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

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
      final res = await ApiService().getContactActivity(limit: 200);
      if (!mounted) return;
      final data = res.data;
      setState(() {
        _all = data is List ? data : (data['results'] as List? ?? []);
        _filtered = List.from(_all);
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
        final fromName = (m['from_full_name'] as String? ?? m['caller_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final toName   = (m['to_full_name'] as String? ?? '').toLowerCase();
        final type = (m['contact_type'] as String? ?? m['type'] as String? ?? '').toLowerCase();
        final matchQ = q.isEmpty || fromName.contains(q) || toName.contains(q);
        final matchType = _filterType.isEmpty || type == _filterType.toLowerCase();
        return matchQ && matchType;
      }).toList();
    });
  }

  void _setType(String t) {
    setState(() { _filterType = t; });
    _applyFilter();
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'sms': return _kAmber;
      case 'whatsapp': return _kGreen;
      default: return _kBlue;
    }
  }

  Color _typeBg(String type) {
    switch (type.toLowerCase()) {
      case 'sms': return _kAmberBg;
      case 'whatsapp': return _kGreenBg;
      default: return _kBlueBg;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sms': return Icons.sms_outlined;
      case 'whatsapp': return Icons.chat_outlined;
      default: return Icons.phone_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          child: const Icon(Icons.phone_in_talk_outlined, color: _kBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Waliopigiana',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                            Text('Historia ya mawasiliano',
                                style: TextStyle(fontSize: 12, color: _kGrey500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Tafuta...',
                        prefixIcon: const Icon(Icons.search, color: _kGrey500),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kGrey200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kGrey200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBlue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _FilterChip(label: 'Zote', selected: _filterType.isEmpty, onTap: () => _setType('')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Simu', selected: _filterType == 'call', onTap: () => _setType('call')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'SMS', selected: _filterType == 'sms', onTap: () => _setType('sms')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'WhatsApp', selected: _filterType == 'whatsapp', onTap: () => _setType('whatsapp')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _kGrey200),
                ],
              ),
            ),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: _kBlue)))
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 48),
                      const SizedBox(height: 12),
                      Text('Kosa la kupakia', style: TextStyle(color: _kGrey500)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Jaribu tena'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue, foregroundColor: Colors.white,
                        ),
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
                      Icon(Icons.phone_outlined, color: _kGrey500, size: 48),
                      const SizedBox(height: 12),
                      Text('Hakuna mawasiliano', style: TextStyle(color: _kGrey500)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = _filtered[i] as Map<String, dynamic>;
                      final fromName = item['from_full_name'] as String? ?? item['caller_name'] as String? ?? item['full_name'] as String? ?? '—';
                      final toName   = item['to_full_name'] as String? ?? '—';
                      final fromCadre = item['from_cadre'] as String? ?? '';
                      final toCadre   = item['to_cadre'] as String? ?? '';
                      final fromRegion = item['from_region'] as String? ?? '';
                      final toRegion   = item['to_region'] as String? ?? '';
                      final fromCat  = (item['from_category'] as String? ?? '') == 'education' ? 'Elimu' : 'Afya';
                      final toCat    = (item['to_category'] as String? ?? '') == 'education' ? 'Elimu' : 'Afya';
                      final type = item['contact_type'] as String? ?? item['type'] as String? ?? 'call';
                      final ts = item['created_at'] as String? ?? item['timestamp'] as String? ?? '';
                      return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _kGrey200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          // FROM
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(fromName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (fromCadre.isNotEmpty)
                              Text('$fromCat · $fromCadre', style: const TextStyle(fontSize: 11, color: _kGrey500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (fromRegion.isNotEmpty)
                              Text(fromRegion, style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w500)),
                          ])),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded, size: 14, color: _kGrey500),
                          ),
                          // TO
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(toName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kGrey900), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (toCadre.isNotEmpty)
                              Text('$toCat · $toCadre', style: const TextStyle(fontSize: 11, color: _kGrey500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (toRegion.isNotEmpty)
                              Text(toRegion, style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w500)),
                          ])),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: _typeBg(type), borderRadius: BorderRadius.circular(6)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_typeIcon(type), color: _typeColor(type), size: 12),
                              const SizedBox(width: 4),
                              Text(type == 'call' ? 'Simu' : type == 'sms' ? 'SMS' : 'WhatsApp',
                                  style: TextStyle(fontSize: 10, color: _typeColor(type), fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          if (ts.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(ts, style: const TextStyle(fontSize: 10, color: _kGrey500)),
                          ],
                        ]),
                      ]),
                    );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

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
