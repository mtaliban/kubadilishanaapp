import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlueBg  = Color(0xFFEFF6FF);
const _kGreen   = Color(0xFF16A34A);
const _kGreenBg = Color(0xFFDCFCE7);
const _kAmber   = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFEF3C7);
const _kRed     = Color(0xFFDC2626);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});
  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _categoryFilter = '';
  String _districtFilter = '';

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
      final res = await ApiService().adminListMatches();
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
        final name = (m['full_name'] as String? ?? '').toLowerCase();
        final cat = (m['category'] as String? ?? '').toLowerCase();
        final dist = (m['district'] as String? ?? '').toLowerCase();
        final matchQ = q.isEmpty || name.contains(q);
        final matchCat = _categoryFilter.isEmpty || cat == _categoryFilter.toLowerCase();
        final matchDist = _districtFilter.isEmpty || dist.contains(_districtFilter.toLowerCase());
        return matchQ && matchCat && matchDist;
      }).toList();
    });
  }

  Color _catColor(String cat) => cat.toLowerCase() == 'afya' ? _kRed : _kGreen;
  Color _catBg(String cat) => cat.toLowerCase() == 'afya' ? const Color(0xFFFEE2E2) : _kGreenBg;

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
                  child: const Icon(Icons.people_alt_outlined, color: _kBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Waliopata Wenzao',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kGrey900)),
                    Text('Mechi zinazowezekana',
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
                hintText: 'Tafuta kwa jina...',
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
                _FilterChip(label: 'Zote', selected: _categoryFilter.isEmpty,
                    onTap: () { setState(() { _categoryFilter = ''; }); _applyFilter(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Afya', selected: _categoryFilter == 'afya',
                    onTap: () { setState(() { _categoryFilter = 'afya'; }); _applyFilter(); }),
                const SizedBox(width: 8),
                _FilterChip(label: 'Elimu', selected: _categoryFilter == 'elimu',
                    onTap: () { setState(() { _categoryFilter = 'elimu'; }); _applyFilter(); }),
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
                    const Icon(Icons.error_outline, color: _kRed, size: 48),
                    const SizedBox(height: 12),
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
                    Icon(Icons.people_alt_outlined, color: _kGrey500, size: 48),
                    const SizedBox(height: 12),
                    Text('Hakuna mechi', style: TextStyle(color: _kGrey500)),
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
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _MatchCard(item: _filtered[i] as Map<String, dynamic>),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MatchCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['full_name'] as String? ?? '';
    final category = item['category'] as String? ?? '';
    final cadre = item['cadre_display'] as String? ?? item['cadre_name'] as String? ?? '';
    final region = item['current_region'] as String? ?? item['region'] as String? ?? '';
    final district = item['current_district'] as String? ?? item['district'] as String? ?? '';
    final wantsRegions = (item['destination_regions'] as List?)?.map((r) => r.toString()).toList() ?? [];
    final matchRegion = item['match_region'] as String? ?? '';
    final phone = item['phone_primary'] as String? ?? item['phone'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final subjects = (item['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final catColor = category.toLowerCase() == 'afya' ? _kRed : _kGreen;
    final catBg = category.toLowerCase() == 'afya' ? const Color(0xFFFEE2E2) : _kGreenBg;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: _kBlue, width: 4)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(initials,
                      style: TextStyle(color: _kBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kGrey900)),
                      Text('$category${cadre.isNotEmpty ? ' · $cadre' : ''}',
                          style: TextStyle(fontSize: 11, color: _kGrey500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(category,
                      style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (region.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: _kGrey500),
                  const SizedBox(width: 4),
                  Text('Kutoka: ', style: TextStyle(fontSize: 12, color: _kGrey500)),
                  Text('$region${district.isNotEmpty ? ', $district' : ''}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kGrey700)),
                ],
              ),
            if (wantsRegions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.my_location, size: 13, color: _kBlue),
                  const SizedBox(width: 4),
                  Text('Anataka: ', style: TextStyle(fontSize: 12, color: _kGrey500)),
                  Expanded(
                    child: Text(wantsRegions.join(', '),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kBlue)),
                  ),
                ],
              ),
            ],
            if (matchRegion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.arrow_downward, size: 13, color: _kGreen),
                  const SizedBox(width: 4),
                  Text('Anakuja $matchRegion — inalingana!',
                      style: TextStyle(fontSize: 12, color: _kGreen, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            if (subjects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: subjects.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kGrey200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 10, color: _kGrey700)),
                )).toList(),
              ),
            ],
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: _kGrey500),
                  const SizedBox(width: 4),
                  Text(createdAt, style: TextStyle(fontSize: 11, color: _kGrey500)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: phone.isNotEmpty ? () => _call(phone) : null,
                  icon: const Icon(Icons.phone_outlined, size: 14),
                  label: const Text('Piga', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kBlue,
                    side: const BorderSide(color: _kGrey200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: phone.isNotEmpty ? () => _sms(phone) : null,
                  icon: const Icon(Icons.sms_outlined, size: 14),
                  label: const Text('SMS', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kGrey700,
                    side: const BorderSide(color: _kGrey200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: phone.isNotEmpty ? () => _whatsapp(phone) : null,
                  icon: const Icon(Icons.chat_outlined, size: 14),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _call(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
  }

  void _sms(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
  }

  void _whatsapp(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
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
