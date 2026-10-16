/// Settings screen — notification preferences and followed regions.
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cached_repository.dart';
import '../widgets/skeletons.dart';
import '../config/theme.dart';
import '../utils/safe_cast.dart';
import '../widgets/app_toast.dart';

// OFFLINE-FIRST — funguo za diski za ukurasa wa mipangilio.
const _kSettingsKey = 'page:settings'; // notification_prefs + regions + followed

const _kBlue    = Color(0xFF1E40AF);
const _kBlue50  = Color(0xFFEFF6FF);
const _kGrey900 = Color(0xFF111827);
const _kGrey700 = Color(0xFF374151);
const _kGrey500 = Color(0xFF6B7280);
const _kGrey400 = Color(0xFF9CA3AF);
const _kGrey200 = Color(0xFFE5E7EB);
const _kGrey100 = Color(0xFFF3F4F6);

bool _nd(BuildContext c__) => Theme.of(c__).brightness == Brightness.dark;
Color _kGrey100T(BuildContext c__) => _nd(c__) ? const Color(0xFF212833) : _kGrey100;
Color _kGrey200T(BuildContext c__) => _nd(c__) ? const Color(0xFF2A3240) : _kGrey200;
Color _kGrey400T(BuildContext c__) => _nd(c__) ? const Color(0xFF64748B) : _kGrey400;
Color _kGrey500T(BuildContext c__) => _nd(c__) ? const Color(0xFF9AA8C7) : _kGrey500;
Color _kGrey700T(BuildContext c__) => _nd(c__) ? const Color(0xFFCBD5E1) : _kGrey700;
Color _kGrey900T(BuildContext c__) => _nd(c__) ? const Color(0xFFE7ECF8) : _kGrey900;
Color _kBlue50T(BuildContext c__) => _nd(c__) ? const Color(0xFF1C2A44) : _kBlue50;
Color _kBlueT(BuildContext c__) => _nd(c__) ? const Color(0xFF7AA7FF) : _kBlue;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification prefs
  // Funguo zinazokubaliwa na backend (NotificationPrefs):
  // new_matches + messages. Backend haiwezi kutuma arifa za
  // payment_status/announcements kwa sasa — hizo ni za app-side pekee.
  Map<String, bool> _notifPrefs = {
    'new_matches': true,
    'messages': true,
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
    // DISKI PAPO HAPO — frame ya KWANZA (hakuna spring, hakuna kusubiri).
    final repo = CachedRepository();
    repo.hydrate('page:profile/me', _applyNotifPrefs);
    repo.hydrate(_kSettingsKey, _applySettings);
    _loadNotifPrefs();
    _loadRegions();
  }

  void _applyNotifPrefs(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final prefs = asMap(asMap(data)['notification_prefs']);
    setState(() {
      _notifPrefs = {
        'new_matches': prefs['new_matches'] as bool? ?? true,
        'messages': prefs['messages'] as bool? ?? true,
      };
      _notifLoading = false;
    });
  }

  void _applySettings(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final b = data as Map;
    // Parse all regions — could be List or Map with 'regions' key
    List<Map<String, dynamic>> regions = [];
    final regData = b['regions'];
    if (regData is List) {
      regions = regData.map(asMap).toList();
    } else if (regData is Map) {
      final list = regData['regions'] ?? regData['items'] ?? [];
      regions = asList(list).map(asMap).toList();
    }

    // Parse followed region ids
    final followedData = asMap(b['followed']);
    final followedList =
        (followedData['followed_regions'] as List<dynamic>?) ?? [];
    final ids =
        asList(followedList).whereType<Map>().map((r) => r['region_id']).toSet();

    setState(() {
      _allRegions = regions;
      _followedRegionIds = ids;
      _regionsLoading = false;
    });
  }

  // ── Notification Prefs ───────────────────────────────────────────────────

  Future<void> _loadNotifPrefs() async {
    // OFFLINE-FIRST: prefs za diski (papo hapo) kutoka wasifu, kisha refresh
    // nyuma ya pazia. API imeshindwa → skrini inabaki na kwa diski.
    setState(() => _notifLoading = true);
    await CachedRepository().loadPage('page:profile/me', _fetchPrefs, _applyNotifPrefs);
    if (mounted && _notifLoading) setState(() => _notifLoading = false);
  }

  /// API ya wasifu — huitwa na CachedRepository nyuma ya pazia.
  /// Inatumia funguo ile ile ya wasifu: bundle moja ya diski inawaka prefs.
  Future<dynamic> _fetchPrefs() async =>
      (await ApiService().getMyProfile()).data;

  Future<void> _saveNotifPrefs() async {
    setState(() => _notifSaving = true);
    try {
      await ApiService().updateNotificationPrefs(_notifPrefs);
      // Diski ya wasifu (prefs zimemo) ifutwe — ifunguliwe tena ipakie mpya.
      CachedRepository().invalidateKey('page:profile/me');
      if (mounted) {
        AppToast.success('Mipangilio ya arifa imehifadhiwa');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _notifSaving = false);
    }
  }

  // ── Followed Regions ─────────────────────────────────────────────────────

  Future<void> _loadRegions() async {
    // OFFLINE-FIRST: mikoa + zilizofuatwa za diski (papo hapo), kisha
    // refresh nyuma ya pazia. API imeshindwa → skrini inabaki na diski.
    setState(() => _regionsLoading = true);
    await CachedRepository().loadPage(_kSettingsKey, _fetchFollowedBundle, _applySettings);
    if (mounted && _regionsLoading) setState(() => _regionsLoading = false);
  }

  /// API za followed regions — huitwa na CachedRepository nyuma ya pazia.
  Future<Map<String, dynamic>> _fetchFollowedBundle() async {
    final results = await Future.wait([
      ApiService().getRegions(),
      ApiService().get('/users/me/followed-regions'),
    ]);
    return {'regions': results[0].data, 'followed': results[1].data};
  }

  Future<void> _saveFollowedRegions() async {
    setState(() => _regionsSaving = true);
    try {
      await ApiService().put('/users/me/followed-regions', data: {
        'region_ids': _followedRegionIds.toList(),
      });
      // Diski ya settings ifutwe — ifunguliwe tena ipakie mpya.
      CachedRepository().invalidateKey(_kSettingsKey);
      if (mounted) {
        AppToast.success('Mikoa iliyofuatwa imehifadhiwa');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _regionsSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : Colors.white,
      body: ToastHost(child: Column(children: [
        Container(
          color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: _kGrey100T(context), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _kGrey700T(context))),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue50T(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlueT(context).withValues(alpha: 0.2))),
              child: Icon(Icons.settings_outlined, size: 20, color: _kBlueT(context))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mipangilio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kGrey900T(context))),
              Text('Arifa na mikoa inayofuatwa',
                  style: TextStyle(fontSize: 12, color: _kGrey500T(context))),
            ])),
          ]),
        ),
        Container(height: 1, color: _kGrey200T(context)),
        Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Section 1: Notification Preferences ──
          _sectionHeader(icon: Icons.notifications_outlined, title: 'Mipangilio ya Arifa'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGrey200T(context)),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
            ),
            child: _notifLoading
                // KANUNI: KAMWE spinner — kijivu (skeleton) tu.
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: WatumiajiSkeleton(count: 2, showChips: true),
                  )
                : Column(children: [
                    _buildNotifSwitch(key: 'new_matches', title: 'Mechi Zimepatikana', subtitle: 'Pokea arifa unapopata mechi mpya'),
                    Container(height: 1, color: _kGrey200T(context)),
                    _buildNotifSwitch(key: 'messages', title: 'Ujumbe', subtitle: 'Arifa za ujumbe mpya'),
                    Container(height: 1, color: _kGrey200T(context)),
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
              color: Theme.of(context).brightness == Brightness.dark ? Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kGrey200T(context)),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 2))],
            ),
            child: _regionsLoading
                // KANUNI: KAMWE spinner — kijivu (skeleton) tu.
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: WatumiajiSkeleton(count: 3, showChips: true),
                  )
                : Column(children: [
                    if (_allRegions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Hakuna mikoa', style: TextStyle(color: _kGrey400T(context))),
                      )
                    else
                      ..._allRegions.map((r) {
                        final id = r['id'] ?? r['region_id'];
                        final name = r['name']?.toString() ?? r['region_name']?.toString() ?? '';
                        final isFollowed = _followedRegionIds.contains(id);
                        return Material(
                          type: MaterialType.transparency,
                          // ListTile inahitaji Material yake ili ink/ripple isifichwe
                          // na Container yenye background hapo juu.
                          child: CheckboxListTile(
                            title: Text(name, style: TextStyle(fontSize: 14, color: _kGrey700T(context))),
                            value: isFollowed,
                            activeColor: _kBlue,
                            checkColor: Colors.white,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) { _followedRegionIds.add(id); }
                                else { _followedRegionIds.remove(id); }
                              });
                            },
                          ),
                        );
                      }),
                    Container(height: 1, color: _kGrey200T(context)),
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
      ])),
    );
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: _kBlue50T(context), borderRadius: BorderRadius.circular(8)),
        child: Center(child: Icon(icon, size: 14, color: _kBlue)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: _kGrey700T(context), letterSpacing: 0.2)),
      ),
    ]);
  }

  Widget _buildNotifSwitch({required String key, required String title, required String subtitle}) {
    return Material(
      type: MaterialType.transparency,
      // ListTile inahitaji Material yake ili ink/ripple isifichwe na Container
      // yenye background ya WhiteCard.
      child: SwitchListTile(
        title: Text(title, style: TextStyle(fontSize: 14, color: _kGrey700T(context), fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: _kGrey400T(context))),
        value: _notifPrefs[key] ?? false,
        activeThumbColor: _kBlue,
        onChanged: (val) => setState(() { _notifPrefs = Map.from(_notifPrefs)..[key] = val; }),
      ),
    );
  }
}