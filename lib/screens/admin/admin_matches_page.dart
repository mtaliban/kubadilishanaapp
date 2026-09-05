/// Admin matches page — all pairings stored in DB (historical matches).
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
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().adminListMatches(limit: 200);
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _matches = data['matches'] ?? [];
        _total = data['total'] ?? 0;
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
        // Count
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Chip(
                  label: Text('$_total mikataba yote',
                      style: const TextStyle(fontSize: 12))),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _load),
            ],
          ),
        ),
        // Match list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _matches.isEmpty
                      ? const Center(
                          child: Text('Hakuna mikataba',
                              style: TextStyle(
                                  color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          itemCount: _matches.length,
                          itemBuilder: (context, i) =>
                              _matchTile(_matches[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _matchTile(Map<String, dynamic> m) {
    // Backend returns: {user_a: {full_name, phone, cadre, region, district, destinations}, user_b: {...}}
    final a = m['user_a'] as Map<String, dynamic>? ?? {};
    final b = m['user_b'] as Map<String, dynamic>? ?? {};
    final date =
        (m['matched_at'] ?? m['created_at'] ?? '').toString().split('T').first;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('Mkataba',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Text(date,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textLight)),
              ],
            ),
            const Divider(height: 12),
            _personRow(a),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(
                  child: Icon(Icons.swap_vert,
                      color: AppColors.textLight, size: 16)),
            ),
            _personRow(b),
          ],
        ),
      ),
    );
  }

  Widget _personRow(Map<String, dynamic> person) {
    // Backend fields: full_name, phone, cadre, region, district, destinations
    final name = person['full_name'] ?? '';
    final cadre = person['cadre'] ?? '';
    final region = person['region'] ?? '';
    final dests = (person['destinations'] as List?)?.join(', ') ?? '';
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryLight,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                '$cadre • $region${dests.isNotEmpty ? ' → $dests' : ''}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
