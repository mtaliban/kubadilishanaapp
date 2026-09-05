/// Admin real-matches page — reciprocal pairs computed in real-time.
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
  String _category = '';
  String _cadreCode = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().adminRealMatches(
        category: _category.isNotEmpty ? _category : null,
        cadreCode: _cadreCode.isNotEmpty ? _cadreCode : null,
        limit: 500,
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _matches = data['matches'] ?? [];
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
        // Category filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _catChip('', 'Zote'),
              _catChip('health', 'Afya'),
              _catChip('education', 'Elimu'),
            ],
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Chip(
              label: Text('${_matches.length} real matches',
                  style: const TextStyle(fontSize: 12))),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _matches.isEmpty
                      ? const Center(
                          child: Text('Hakuna real matches bado',
                              style: TextStyle(
                                  color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          itemCount: _matches.length,
                          itemBuilder: (context, i) =>
                              _matchCard(_matches[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _catChip(String cat, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _category == cat,
        onSelected: (_) {
          setState(() => _category = cat);
          _load();
        },
        selectedColor: AppColors.primary,
        labelStyle:
            TextStyle(color: _category == cat ? Colors.white : null),
      ),
    );
  }

  Widget _matchCard(Map<String, dynamic> m) {
    final score = (m['score'] as num?)?.toStringAsFixed(2) ?? '0';
    final cadreDisplay = m['cadre_display'] ?? m['cadre_code'] ?? '';
    final commonSubjects = (m['common_subjects'] as List?)?.join(', ') ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: 6),
                Text('Score: $score',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (cadreDisplay.isNotEmpty)
                  Chip(
                    label: Text(cadreDisplay,
                        style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                const Spacer(),
              ],
            ),
            if (commonSubjects.isNotEmpty)
              Text('Masomo: $commonSubjects',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.info)),
            const Divider(height: 12),
            _person(
                m['user_a'] as Map<String, dynamic>? ?? {}, 'A'),
            const SizedBox(height: 6),
            const Center(
                child: Icon(Icons.swap_vert,
                    color: AppColors.primary, size: 20)),
            const SizedBox(height: 6),
            _person(
                m['user_b'] as Map<String, dynamic>? ?? {}, 'B'),
          ],
        ),
      ),
    );
  }

  Widget _person(Map<String, dynamic> p, String label) {
    if (p.isEmpty) return const SizedBox();
    // Backend fields: user_id, full_name, phone_primary, phone_alt,
    //   cadre_code, cadre_display, category, subjects,
    //   current_region, current_district, current_facility,
    //   destinations (list of region names), online, is_verified
    final name = p['full_name'] ?? '';
    final cadre = p['cadre_display'] ?? p['cadre_code'] ?? '';
    final region = p['current_region'] ?? '';
    final dests =
        (p['destinations'] as List?)?.take(3).join(', ') ?? '';
    final online = p['online'] ?? false;
    final verified = p['is_verified'] ?? false;

    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
            if (online)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                  if (verified)
                    const Icon(Icons.verified,
                        size: 14, color: AppColors.success),
                ],
              ),
              Text(
                '$cadre • $region'
                '${dests.isNotEmpty ? ' → $dests' : ''}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary),
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
