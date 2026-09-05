/// Settings screen — notification preferences and followed regions.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification prefs
  Map<String, bool> _notifPrefs = {
    'match_found': false,
    'payment_status': false,
    'announcements': false,
    'messages': false,
  };
  bool _notifLoading = true;
  bool _notifSaving = false;

  // Regions
  List<Map<String, dynamic>> _allRegions = [];
  Set<dynamic> _followedRegionIds = {};
  bool _regionsLoading = true;
  bool _regionsSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
    _loadRegions();
  }

  // ── Notification Prefs ───────────────────────────────────────────────────

  Future<void> _loadNotifPrefs() async {
    setState(() => _notifLoading = true);
    try {
      final res = await ApiService().getMyProfile();
      final data = res.data as Map<String, dynamic>;
      final prefs = data['notification_prefs'] as Map<String, dynamic>? ?? {};
      setState(() {
        _notifPrefs = {
          'match_found': prefs['match_found'] == true,
          'payment_status': prefs['payment_status'] == true,
          'announcements': prefs['announcements'] == true,
          'messages': prefs['messages'] == true,
        };
        _notifLoading = false;
      });
    } catch (_) {
      setState(() => _notifLoading = false);
    }
  }

  Future<void> _saveNotifPrefs() async {
    setState(() => _notifSaving = true);
    try {
      await ApiService().patch('/users/me', data: {
        'notification_prefs': _notifPrefs,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mipangilio ya arifa imehifadhiwa'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hitilafu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _notifSaving = false);
    }
  }

  // ── Followed Regions ─────────────────────────────────────────────────────

  Future<void> _loadRegions() async {
    setState(() => _regionsLoading = true);
    try {
      final results = await Future.wait([
        ApiService().getRegions(),
        ApiService().get('/users/me/followed-regions'),
      ]);

      final regionsRes = results[0];
      final followedRes = results[1];

      // Parse all regions — could be List or Map with 'regions' key
      List<Map<String, dynamic>> regions = [];
      final regData = regionsRes.data;
      if (regData is List) {
        regions = regData.cast<Map<String, dynamic>>();
      } else if (regData is Map) {
        final list = regData['regions'] ?? regData['items'] ?? [];
        regions = (list as List).cast<Map<String, dynamic>>();
      }

      // Parse followed region ids
      final followedData = followedRes.data as Map<String, dynamic>;
      final followedList =
          (followedData['followed_regions'] as List<dynamic>?) ?? [];
      final ids =
          followedList.map((r) => (r as Map<String, dynamic>)['region_id']).toSet();

      setState(() {
        _allRegions = regions;
        _followedRegionIds = ids;
        _regionsLoading = false;
      });
    } catch (_) {
      setState(() => _regionsLoading = false);
    }
  }

  Future<void> _saveFollowedRegions() async {
    setState(() => _regionsSaving = true);
    try {
      await ApiService().put('/users/me/followed-regions', data: {
        'region_ids': _followedRegionIds.toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mikoa iliyofuatwa imehifadhiwa'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hitilafu: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _regionsSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mipangilio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Section 1: Notification Preferences ──
          _sectionHeader(
            icon: Icons.notifications_outlined,
            title: 'Mipangilio ya Arifa',
          ),
          const SizedBox(height: 8),
          Card(
            child: _notifLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      _buildNotifSwitch(
                        key: 'match_found',
                        title: 'Mechi Zimepatikana',
                        subtitle: 'Pokea arifa unapopata mechi mpya',
                      ),
                      const Divider(height: 1),
                      _buildNotifSwitch(
                        key: 'payment_status',
                        title: 'Hali ya Malipo',
                        subtitle: 'Arifa za malipo yaliyoidhinishwa au kukataliwa',
                      ),
                      const Divider(height: 1),
                      _buildNotifSwitch(
                        key: 'announcements',
                        title: 'Matangazo',
                        subtitle: 'Matangazo mapya kutoka kwa admin',
                      ),
                      const Divider(height: 1),
                      _buildNotifSwitch(
                        key: 'messages',
                        title: 'Ujumbe',
                        subtitle: 'Arifa za ujumbe mpya',
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _notifSaving ? null : _saveNotifPrefs,
                            child: _notifSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Hifadhi Arifa'),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ── Section 2: Followed Regions ──
          _sectionHeader(
            icon: Icons.map_outlined,
            title: 'Mikoa Inayofuatwa',
          ),
          const SizedBox(height: 8),
          Card(
            child: _regionsLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      if (_allRegions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Hakuna mikoa',
                              style: TextStyle(color: AppColors.textSecondary)),
                        )
                      else
                        ..._allRegions.map((r) {
                          final id = r['id'] ?? r['region_id'];
                          final name =
                              r['name']?.toString() ?? r['region_name']?.toString() ?? '';
                          final isFollowed = _followedRegionIds.contains(id);
                          return CheckboxListTile(
                            title: Text(name,
                                style: const TextStyle(fontSize: 14)),
                            value: isFollowed,
                            activeColor: AppColors.primary,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _followedRegionIds.add(id);
                                } else {
                                  _followedRegionIds.remove(id);
                                }
                              });
                            },
                          );
                        }),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _regionsSaving ? null : _saveFollowedRegions,
                            child: _regionsSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Hifadhi Mikoa'),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildNotifSwitch({
    required String key,
    required String title,
    required String subtitle,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: _notifPrefs[key] ?? false,
      activeColor: AppColors.primary,
      onChanged: (val) {
        setState(() {
          _notifPrefs = Map.from(_notifPrefs)..[key] = val;
        });
      },
    );
  }
}
