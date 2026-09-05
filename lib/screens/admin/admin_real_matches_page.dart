/// Admin real-matches page — actual pairings that have been made with details.
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});
  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  List<dynamic> _matches = [];
  bool _loading = true;
  String _q = '';
  String _cadre = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/real-matches', queryParameters: {
        'q': _q,
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
        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Tafuta kwa jina au kada...',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
            onChanged: (v) => _q = v,
            onSubmitted: (_) => _load(),
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Chip(label: Text('${_matches.length} real matches', style: const TextStyle(fontSize: 12))),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _matches.isEmpty
                      ? const Center(child: Text('Hakuna real matches bado', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _matches.length,
                          itemBuilder: (context, i) => _matchCard(_matches[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _matchCard(Map<String, dynamic> m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.warning, size: 16),
                const SizedBox(width: 6),
                Text('Score: ${m['score'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(m['created_at'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
              ],
            ),
            const Divider(height: 12),
            _person(m['user_a'] ?? m['from_user'] ?? {}, 'Kutoka'),
            const SizedBox(height: 8),
            const Center(child: Icon(Icons.swap_vert, color: AppColors.primary, size: 20)),
            const SizedBox(height: 8),
            _person(m['user_b'] ?? m['to_user'] ?? {}, 'Kwenda'),
          ],
        ),
      ),
    );
  }

  Widget _person(Map<String, dynamic> p, String label) {
    if (p.isEmpty) return const SizedBox();
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            (p['full_name'] ?? '?')[0].toString().toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${p['cadre_code'] ?? ''} • ${p['region_name'] ?? p['current_station']?['region_name'] ?? ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (p['phone_primary'] != null)
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.phone, size: 18, color: Colors.green),
                onPressed: () {},
              ),
              const Text('Piga', style: TextStyle(fontSize: 10, color: Colors.green)),
            ],
          ),
      ],
    );
  }
}
