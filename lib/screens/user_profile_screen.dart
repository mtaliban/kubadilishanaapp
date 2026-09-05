/// User profile public view — shows identity, station, destinations, subjects.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().get('/users/${widget.userId}');
      setState(() {
        _user = res.data as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['full_name']?.toString() ?? 'Mtumiaji';

    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Wasifu' : name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Hitilafu: $_error',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('Jaribu Tena')),
                    ],
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final u = _user!;
    final fullName = u['full_name']?.toString() ?? 'Mtumiaji';
    final phone = u['phone_primary']?.toString() ?? '';
    final cadreDisplay = u['cadre_display']?.toString() ?? '';
    final cadreCode = u['cadre_code']?.toString() ?? '';
    final category = u['category']?.toString() ?? '';
    final isVerified = u['is_verified'] == true;
    final online = u['online'] == true;
    final station = u['current_station'] as Map<String, dynamic>? ?? {};
    final destinations =
        (u['desired_destinations'] as List<dynamic>?) ?? [];
    final subjects = (u['subjects'] as List<dynamic>?) ?? [];

    final initials = fullName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + badges
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        initials,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                    ),
                    if (online)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  fullName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isVerified) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Amethibitishwa',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                  ),
                ],
                if (online) ...[
                  const SizedBox(height: 4),
                  const Text('• Mtandaoni',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.success)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Identity card
          _SectionCard(
            title: 'Maelezo ya Mtumiaji',
            icon: Icons.badge_outlined,
            children: [
              _InfoRow(label: 'Jina', value: fullName),
              if (cadreDisplay.isNotEmpty)
                _InfoRow(label: 'Cheo', value: cadreDisplay),
              if (cadreCode.isNotEmpty && cadreCode != cadreDisplay)
                _InfoRow(label: 'Namba ya Cheo', value: cadreCode),
              if (category.isNotEmpty)
                _InfoRow(label: 'Sekta', value: category),
              if (phone.isNotEmpty)
                _InfoRow(label: 'Simu', value: phone),
            ],
          ),
          const SizedBox(height: 12),

          // Station card
          _SectionCard(
            title: 'Kituo cha Sasa',
            icon: Icons.location_on_outlined,
            children: [
              if ((station['region_name']?.toString() ?? '').isNotEmpty)
                _InfoRow(
                    label: 'Mkoa',
                    value: station['region_name'].toString()),
              if ((station['district_name']?.toString() ?? '').isNotEmpty)
                _InfoRow(
                    label: 'Wilaya',
                    value: station['district_name'].toString()),
              if ((station['facility_name']?.toString() ?? '').isNotEmpty)
                _InfoRow(
                    label: 'Kituo',
                    value: station['facility_name'].toString()),
              if (station.isEmpty ||
                  (station['region_name'] == null &&
                      station['district_name'] == null))
                const Text('Hakuna taarifa za kituo',
                    style: TextStyle(
                        color: AppColors.textLight, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          // Desired destinations card
          _SectionCard(
            title: 'Maeneo Yanayotakiwa',
            icon: Icons.map_outlined,
            children: [
              if (destinations.isEmpty)
                const Text('Hakuna maeneo yaliyochaguliwa',
                    style: TextStyle(
                        color: AppColors.textLight, fontSize: 13))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: destinations.map((d) {
                    final regionName =
                        (d as Map<String, dynamic>)['region_name']
                                ?.toString() ??
                            d.toString();
                    return Chip(
                      label: Text(regionName,
                          style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.primaryLight,
                      labelStyle:
                          const TextStyle(color: AppColors.primary),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
            ],
          ),

          // Subjects card (only if non-empty)
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Masomo',
              icon: Icons.school_outlined,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: subjects
                      .map((s) => Chip(
                            label: Text(s.toString(),
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.surfaceDark,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                          ))
                      .toList(),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Shared card / row widgets ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
