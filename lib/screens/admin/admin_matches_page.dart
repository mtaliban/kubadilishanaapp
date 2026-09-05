/// Admin matches page — view all matches/pairings with filters.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});
  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  List<dynamic> _matches = [];
  bool _loading = true;
  String _region = '';
  String _cadre = '';

  final _cadres = [
    {'code': 'P1', 'label': 'Mwalimu wa Msingi'},
    {'code': 'S1', 'label': 'Mwalimu wa Sekondari'},
    {'code': 'Nurse', 'label': 'Muuguzi'},
    {'code': 'Doctor', 'label': 'Daktari'},
    {'code': 'CO', 'label': 'Afisa wa Afya'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/matches', queryParameters: {
        'region': _region,
        'cadre': _cadre,
      });
      setState(() {
        _matches = res.data is List ? res.data : (res.data['matches'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ..._cadres.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c['label']!, style: const TextStyle(fontSize: 11)),
                  selected: _cadre == c['code'],
                  onSelected: (_) { setState(() => _cadre = _cadre == c['code'] ? '' : c['code']!); _load(); },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _cadre == c['code'] ? Colors.white : null),
                ),
              )),
            ],
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Chip(label: Text('${_matches.length} mikataba', style: const TextStyle(fontSize: 12))),
        ),
        // Match list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _matches.isEmpty
                      ? const Center(child: Text('Hakuna mikataba', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _matches.length,
                          itemBuilder: (context, i) => _matchTile(_matches[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _matchTile(Map<String, dynamic> m) {
    final a = m['user_a'] ?? {};
    final b = m['user_b'] ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Mikataba', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text(m['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
              ],
            ),
            const Divider(height: 12),
            _personRow(a, 'A'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Icon(Icons.swap_vert, color: AppColors.textLight, size: 16),
            ),
            _personRow(b, 'B'),
          ],
        ),
      ),
    );
  }

  Widget _personRow(Map<String, dynamic> person, String label) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryLight,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person['full_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${person['cadre_code'] ?? ''} • ${person['region_name'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (person['phone_primary'] != null)
          IconButton(
            icon: const Icon(Icons.phone, size: 16, color: Colors.green),
            onPressed: () {},
          ),
      ],
    );
  }
}
