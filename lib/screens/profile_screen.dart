import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../screens/wasifu_view.dart';
import '../services/api_service.dart';
import '../services/app_cache.dart';
import '../utils/safe_cast.dart';
import '../widgets/app_shell.dart';



List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map) return (data['items'] ?? data['results'] ?? []) as List;
  return [];
}



/* ============================================================
   SCREEN KUU
   ============================================================ */
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _raw;
  bool _loading = true;

  // Reference data (loaded once)
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _cadres = [];
  List<Map<String, dynamic>> _subjects = [];

  // Location caches (lazy-loaded)
  final Map<int, List<Map<String, dynamic>>> _distCache = {};
  final Map<int, List<Map<String, dynamic>>> _facCache = {};

  // Reverse lookups: name → id
  final Map<String, int> _regionIdFor = {};
  final Map<String, int> _districtIdFor = {};
  final Map<String, String> _facilityIdFor = {}; // displayName → facilityId
  final Map<String, String> _facilityNameFor = {}; // displayName → rawName (without type)

  // Code lookups
  final Map<String, String> _kadaCodeFor = {}; // displayName → code
  final Map<String, String> _subjectCodeFor = {}; // displayName → code

  // Prevent concurrent loads
  final Set<int> _loadingRegion = {};
  final Set<int> _loadingDist = {};

  void _onWs(dynamic _) => _load();

  int _cacheRev = 0;
  late final VoidCallback _cacheListener;

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('user.updated_by_admin', _onWs);
    // LIVE: admin ameongeza mkoa/wilaya/kituo → profile ipakie upya PAPO HAPO
    // (dropdowns za usajili-wa-pili/settings zione vitu vipya bila reload).
    _cacheRev = AppCache().revision;
    _cacheListener = () {
      if (AppCache().revision != _cacheRev && mounted) {
        _cacheRev = AppCache().revision;
        _load();
      }
    };
    AppCache().addListener(_cacheListener);
  }

  @override
  void dispose() {
    WebSocketService().off('user.updated_by_admin', _onWs);
    AppCache().removeListener(_cacheListener);
    super.dispose();
  }

  /* ---------- Data loading ---------- */

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService().getMyProfile().then((r) => r.data),
        ApiService().getRegions().then((r) => r.data),
      ]);
      final profile = asMapOrNull(results[0]);
      if (profile == null || !mounted) {
        setState(() => _loading = false);
        return;
      }
      _raw = profile;

      // Populate region list
      final regs = _asList(results[1]).map((r) => asMap(r)).toList();
      _regions = regs;
      _regionIdFor.clear();
      for (final r in _regions) {
        _regionIdFor[r['name'].toString()] = r['id'] as int;
      }

      final category = profile['category']?.toString() ?? '';

      // Load cadres + subjects concurrently with location pre-loading
      final cs = profile['current_station'] as Map? ?? {};
      final dests = profile['desired_destinations'] as List? ?? [];
      final regionIds = <int>{};
      if (cs['region_id'] is int) regionIds.add(cs['region_id'] as int);
      for (final d in dests) {
        if (d is Map && d['region_id'] is int) regionIds.add(d['region_id'] as int);
      }

      await Future.wait([
        _loadCadresAndSubjects(category, profile['cadre_code']?.toString()),
        ...regionIds.map(_ensureDistricts),
      ]);

      if (cs['district_id'] is int) {
        await _ensureFacilities(cs['district_id'] as int, category);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCadresAndSubjects(String category, String? cadreCode) async {
    try {
      final r = await ApiService().getCadres(category: category.isEmpty ? null : category);
      final cads = _asList(r.data).map((c) => asMap(c)).toList();
      _cadres = cads;
      _kadaCodeFor.clear();
      for (final c in _cadres) {
        final display = (c['display_name'] ?? c['code'] ?? '').toString();
        _kadaCodeFor[display] = (c['code'] ?? '').toString();
      }
      if (category == 'education' && cadreCode != null) {
        final cadre = _cadres.cast<Map<String, dynamic>?>().firstWhere(
            (c) => c?['code'] == cadreCode,
            orElse: () => null);
        final level = cadre?['level']?.toString();
        if (level != null) await _loadSubjects(level);
      }
    } catch (_) {}
  }

  Future<void> _loadSubjects(String level) async {
    try {
      final r = await ApiService().getSubjects(level: level);
      final subs = _asList(r.data).map((s) => asMap(s)).toList();
      _subjects = subs;
      _subjectCodeFor.clear();
      for (final s in _subjects) {
        final name = (s['name'] ?? s['code'] ?? '').toString();
        _subjectCodeFor[name] = (s['code'] ?? name).toString();
      }
    } catch (_) {}
  }

  Future<void> _ensureDistricts(int regionId) async {
    if (_distCache.containsKey(regionId) || _loadingRegion.contains(regionId)) return;
    _loadingRegion.add(regionId);
    try {
      final r = await ApiService().getDistricts(regionId);
      final dists = _asList(r.data).map((d) => asMap(d)).toList();
      _distCache[regionId] = dists;
      for (final d in dists) {
        _districtIdFor[d['name'].toString()] = d['id'] as int;
      }
    } catch (_) {}
    _loadingRegion.remove(regionId);
  }

  Future<void> _ensureFacilities(int districtId, String category) async {
    if (_facCache.containsKey(districtId) || _loadingDist.contains(districtId)) return;
    _loadingDist.add(districtId);
    try {
      final r = await ApiService().getFacilities(districtId, category: category.isEmpty ? 'health' : category);
      final facs = _asList(r.data).map((f) => asMap(f)).toList();
      _facCache[districtId] = facs;
      for (final f in facs) {
        final rawName = (f['name'] ?? '').toString();
        final type = (f['type'] ?? '').toString();
        final display = type.isNotEmpty ? '$rawName ($type)' : rawName;
        final id = (f['id'] ?? f['code'] ?? '').toString();
        _facilityIdFor[display] = id;
        _facilityNameFor[display] = rawName;
      }
    } catch (_) {}
    _loadingDist.remove(districtId);
  }

  /* ---------- Closures za WasifuView ---------- */

  List<String> _wilayaOf(String mkoa) {
    final regionId = _regionIdFor[mkoa];
    if (regionId == null) return [];
    final cached = _distCache[regionId];
    if (cached != null) return cached.map((d) => d['name'].toString()).toList();
    // Trigger lazy load na urudisha tupu kwa sasa
    _ensureDistricts(regionId).then((_) { if (mounted) setState(() {}); });
    return [];
  }

  List<String> _vituoOf(String wilaya) {
    final districtId = _districtIdFor[wilaya];
    if (districtId == null) return [];
    final cached = _facCache[districtId];
    if (cached != null) {
      return cached.map((f) {
        final name = (f['name'] ?? '').toString();
        final type = (f['type'] ?? '').toString();
        return type.isNotEmpty ? '$name ($type)' : name;
      }).toList();
    }
    final category = _raw?['category']?.toString() ?? 'health';
    _ensureFacilities(districtId, category).then((_) { if (mounted) setState(() {}); });
    return [];
  }

  /* ---------- Kubadilisha API data ↔ UserProfile ---------- */

  UserProfile _toUserProfile(Map<String, dynamic> p) {
    final cs = p['current_station'] as Map? ?? {};
    final dests = p['desired_destinations'] as List? ?? [];

    // Subject codes → display names
    final subjectCodes = (p['subjects'] as List? ?? []).map((s) => s.toString()).toList();
    final subjectNames = subjectCodes.map((code) {
      final entry = _subjects.cast<Map<String, dynamic>?>()
          .firstWhere((s) => s?['code'] == code, orElse: () => null);
      return (entry?['name'] ?? code).toString();
    }).toList();

    return UserProfile(
      name: (p['full_name'] ?? '').toString(),
      idara: (p['category'] ?? '').toString(),
      kada: (p['cadre_display'] ?? p['cadre_code'] ?? '').toString(),
      subjects: subjectNames,
      phone: (p['phone_primary'] ?? '').toString(),
      whatsapp: (p['phone_alt'] ?? '').toString(),
      mkoa: (cs['region_name'] ?? '').toString(),
      wilaya: (cs['district_name'] ?? '').toString(),
      kituo: () {
        final n = (cs['facility_name'] ?? '').toString();
        return n.isEmpty ? null : n;
      }(),
      destinations: dests.map((d) {
        final m = d is Map ? d : {};
        return Destination(
          mkoa: (m['region_name'] ?? '').toString(),
          wilaya: () {
            final w = (m['district_name'] ?? '').toString();
            return w.isEmpty ? null : w;
          }(),
        );
      }).toList(),
    );
  }

  Future<void> _onSave(UserProfile updated) async {
    // Pre-load location data we'll need for the save
    final csRegionId = _regionIdFor[updated.mkoa];
    if (csRegionId != null) {
      await _ensureDistricts(csRegionId);
      final csDistrictId = _districtIdFor[updated.wilaya];
      if (csDistrictId != null) {
        await _ensureFacilities(csDistrictId, _raw?['category']?.toString() ?? 'health');
      }
    }
    for (final dest in updated.destinations) {
      final rid = _regionIdFor[dest.mkoa];
      if (rid != null) await _ensureDistricts(rid);
    }

    final csDistrictId = _districtIdFor[updated.wilaya];
    final csFacilityId = updated.kituo != null ? _facilityIdFor[updated.kituo!] : null;
    final csFacilityName = updated.kituo != null ? _facilityNameFor[updated.kituo!] : null;

    final dests = updated.destinations
        .where((d) => d.mkoa.isNotEmpty)
        .map((d) => {
              'region_id': _regionIdFor[d.mkoa],
              'region_name': d.mkoa,
              'district_id': d.wilaya != null ? _districtIdFor[d.wilaya!] : null,
              'district_name': d.wilaya,
              'facility_id': null,
              'facility_name': null,
            })
        .where((d) => d['region_id'] != null)
        .toList();

    final subjectCodes = updated.subjects
        .map((name) => _subjectCodeFor[name] ?? name)
        .toList();

    final cadreCode = _kadaCodeFor[updated.kada] ?? updated.kada;

    final data = <String, dynamic>{
      'full_name': updated.name,
      'phone_primary': updated.phone,
      'phone_alt': updated.whatsapp,
      'cadre_code': cadreCode,
      if (subjectCodes.isNotEmpty) 'subjects': subjectCodes,
      if (csRegionId != null)
        'current_station': {
          'region_id': csRegionId,
          'region_name': updated.mkoa,
          'district_id': csDistrictId,
          'district_name': updated.wilaya,
          'facility_id': csFacilityId,
          'facility_name': csFacilityName ?? updated.kituo,
        },
      'desired_destinations': dests,
    };

    await ApiService().updateProfile(data);

    // Refresh profile silently
    final res = await ApiService().getMyProfile();
    final fresh = asMapOrNull(res.data);
    if (fresh != null && mounted) setState(() => _raw = fresh);
  }

  /* ---------- Build ---------- */

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AppShell(tabIndex: 3, child: const Center(child: CircularProgressIndicator()));
    }

    if (_raw == null) {
      return AppShell(tabIndex: 3, child: const Center(child: Text('Imeshindikana kupakia')));
    }

    // ── Mtumiaji wa kawaida → WasifuView ──────────────────────────────────────
    final profile = _toUserProfile(_raw!);
    final category = (_raw!['category'] ?? '').toString();
    return AppShell(
      tabIndex: 3,
      child: RefreshIndicator(
        onRefresh: _load,
        child: WasifuView(
          profile: profile,
          kadaOptions: _cadres
              .map((c) => (c['display_name'] ?? c['code'] ?? '').toString())
              .toList(),
          mikoa: _regions.map((r) => r['name'].toString()).toList(),
          wilayaOf: _wilayaOf,
          vituoOf: _vituoOf,
          subjectOptions: category == 'education'
              ? _subjects.map((s) => (s['name'] ?? s['code'] ?? '').toString()).toList()
              : [],
          onSave: _onSave,
          toastBottom: 72,
        ),
      ),
    );
  }
}
