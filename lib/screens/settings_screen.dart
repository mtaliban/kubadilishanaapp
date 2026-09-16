/// Settings screen — notification preferences and followed regions.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

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
      backgroundColor: Colors.white,
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _kGrey100, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kGrey700)),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withValues(alpha: 0.2))),
              child: const Icon(Icons.settings_outlined, size: 20, color: _kBlue)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mipangilio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900)),
              Text('Arifa na mikoa inayofuatwa',
                  style: TextStyle(fontSize: 12, color: _kGrey500)),
            ])),
          ]),
        ),
        Container(height: 1, color: _kGrey200),
        Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Section 1: Notification Preferences ──
          _sectionHeader(icon: Icons.notifications_outlined, title: 'Mipangilio ya Arifa'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGrey200),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
            ),
            child: _notifLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: _kBlue)),
                  )
                : Column(children: [
                    _buildNotifSwitch(key: 'match_found', title: 'Mechi Zimepatikana', subtitle: 'Pokea arifa unapopata mechi mpya'),
                    Container(height: 1, color: _kGrey200),
                    _buildNotifSwitch(key: 'payment_status', title: 'Hali ya Malipo', subtitle: 'Arifa za malipo yaliyoidhinishwa au kukataliwa'),
                    Container(height: 1, color: _kGrey200),
                    _buildNotifSwitch(key: 'announcements', title: 'Matangazo', subtitle: 'Matangazo mapya kutoka kwa admin'),
                    Container(height: 1, color: _kGrey200),
                    _buildNotifSwitch(key: 'messages', title: 'Ujumbe', subtitle: 'Arifa za ujumbe mpya'),
                    Container(height: 1, color: _kGrey200),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _notifSaving ? null : _saveNotifPrefs,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue, foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: _notifSaving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Hifadhi Arifa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ]),
          ),

          const SizedBox(height: 28),

          // ── Section 2: Followed Regions ──
          _sectionHeader(icon: Icons.map_outlined, title: 'Mikoa Inayofuatwa'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGrey200),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
            ),
            child: _regionsLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: _kBlue)),
                  )
                : Column(children: [
                    if (_allRegions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Hakuna mikoa', style: TextStyle(color: _kGrey400)),
                      )
                    else
                      ..._allRegions.map((r) {
                        final id = r['id'] ?? r['region_id'];
                        final name = r['name']?.toString() ?? r['region_name']?.toString() ?? '';
                        final isFollowed = _followedRegionIds.contains(id);
                        return CheckboxListTile(
                          title: Text(name, style: const TextStyle(fontSize: 14, color: _kGrey700)),
                          value: isFollowed,
                          activeColor: _kBlue,
                          checkColor: Colors.white,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) { _followedRegionIds.add(id); }
                              else { _followedRegionIds.remove(id); }
                            });
                          },
                        );
                      }),
                    Container(height: 1, color: _kGrey200),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _regionsSaving ? null : _saveFollowedRegions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kBlue, foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: _regionsSaving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Hifadhi Mikoa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ]),
          ),
        ],
        )),
      ]),
    );
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: _kBlue50, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Icon(icon, size: 14, color: _kBlue)),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kGrey700, letterSpacing: 0.2)),
    ]);
  }

  Widget _buildNotifSwitch({required String key, required String title, required String subtitle}) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, color: _kGrey700, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _kGrey400)),
      value: _notifPrefs[key] ?? false,
      activeColor: _kBlue,
      onChanged: (val) => setState(() { _notifPrefs = Map.from(_notifPrefs)..[key] = val; }),
    );
  }
}
