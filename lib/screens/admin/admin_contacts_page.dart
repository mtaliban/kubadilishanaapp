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
        final name = (m['caller_name'] as String? ?? m['full_name'] as String? ?? '').toLowerCase();
        final type = (m['contact_type'] as String? ?? m['type'] as String? ?? '').toLowerCase();
        final matchQ = q.isEmpty || name.contains(q);
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
      body: Column(
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
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: _kBlue)))
          else if (_error != null)
            Expanded(
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
            Expanded(
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: _kBlue,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final item = _filtered[i] as Map<String, dynamic>;
                    final name = item['caller_name'] as String? ?? item['full_name'] as String? ?? 'Mtumiaji';
                    final type = item['contact_type'] as String? ?? item['type'] as String? ?? 'call';
                    final ts = item['created_at'] as String? ?? item['timestamp'] as String? ?? '';
                    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _kGrey200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _typeBg(type),
                            child: Text(initials,
                                style: TextStyle(color: _typeColor(type), fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                                if (ts.isNotEmpty)
                                  Text(ts, style: TextStyle(fontSize: 11, color: _kGrey500)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _typeBg(type),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_typeIcon(type), color: _typeColor(type), size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  type == 'call' ? 'Simu' : type == 'sms' ? 'SMS' : 'WhatsApp',
                                  style: TextStyle(fontSize: 11, color: _typeColor(type), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
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
