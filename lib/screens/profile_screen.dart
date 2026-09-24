import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../screens/wasifu_view.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/safe_cast.dart';
import '../widgets/app_shell.dart';

// ── Msaidizi wa namba ─────────────────────────────────────────────────────────
String _fmtPhone(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('255')) {
    return '+255 ${d.substring(3, 6)} ${d.substring(6, 9)} ${d.substring(9)}';
  }
  if (d.length == 10 && d.startsWith('0')) {
    return '+255 ${d.substring(1, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
  }
  return p.isEmpty ? '' : '+$d';
}

String _strip255(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('255')) return d.substring(3);
  if (d.length == 10 && d.startsWith('0')) return d.substring(1);
  return d;
}

List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map) return (data['items'] ?? data['results'] ?? []) as List;
  return [];
}

String _parseErr(dynamic e) {
  try {
    final d = (e as dynamic).response?.data?['detail'];
    if (d is String) return d;
  } catch (_) {}
  return 'Imeshindikana';
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

  @override
  void initState() {
    super.initState();
    _load();
    WebSocketService().on('user.updated_by_admin', _onWs);
  }

  @override
  void dispose() {
    WebSocketService().off('user.updated_by_admin', _onWs);
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
    final isAdmin = context.read<AuthProvider>().isAdmin || (_raw?['is_admin'] == true);

    if (_loading) {
      return isAdmin
          ? _adminScaffold(const Center(child: CircularProgressIndicator()))
          : AppShell(tabIndex: 3, child: const Center(child: CircularProgressIndicator()));
    }

    if (_raw == null) {
      return isAdmin
          ? _adminScaffold(const Center(child: Text('Imeshindikana kupakia')))
          : AppShell(tabIndex: 3, child: const Center(child: Text('Imeshindikana kupakia')));
    }

    if (isAdmin) return _buildAdmin();

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

  /* ---------- Admin shell ---------- */

  Widget _adminScaffold(Widget body) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(children: [
                Material(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.maybePop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF374151)),
                    ),
                  ),
                ),
              ]),
            ),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            Expanded(child: body),
          ]),
        ),
      );

  Widget _buildAdmin() {
    return _AdminProfilePage(
      rawProfile: _raw!,
      onReload: _load,
    );
  }
}

/* ============================================================
   UKURASA WA ADMIN (design yake yenyewe)
   ============================================================ */
class _AdminProfilePage extends StatefulWidget {
  final Map<String, dynamic> rawProfile;
  final VoidCallback onReload;
  const _AdminProfilePage({required this.rawProfile, required this.onReload});

  @override
  State<_AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<_AdminProfilePage> {
  bool _editing = false;

  static const _accent = Color(0xFF2A3EB1);
  static const _accentMuted = Color(0xFFEDEFFA);
  static const _surface1 = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE4E6EE);
  static const _textPrimary = Color(0xFF1A1D29);
  static const _textMuted = Color(0xFF9297A8);

  String get _name => widget.rawProfile['full_name']?.toString() ?? '';
  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  void _onSaved() {
    setState(() => _editing = false);
    widget.onReload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // Header bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
            child: Row(children: [
              Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF374151)),
                  ),
                ),
              ),
            ]),
          ),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // ── Page header ──
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: _accentMuted, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.person_outline_rounded, size: 22, color: _accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(_editing ? 'Hariri wasifu' : 'Wasifu wa Admin',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary, height: 1.2)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _accentMuted, borderRadius: BorderRadius.circular(999)),
                        child: const Text('Admin',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _accent)),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(_editing ? 'Badilisha kisha hifadhi' : 'Taarifa za akaunti yako',
                        style: const TextStyle(fontSize: 12, color: _textMuted)),
                  ])),
                  const SizedBox(width: 8),
                  if (!_editing)
                    GestureDetector(
                      onTap: () => setState(() => _editing = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_outlined, size: 14, color: _textPrimary),
                          SizedBox(width: 5),
                          Text('Hariri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary)),
                        ]),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _editing = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.close_rounded, size: 14, color: _textPrimary),
                          SizedBox(width: 5),
                          Text('Ghairi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary)),
                        ]),
                      ),
                    ),
                ]),
                const SizedBox(height: 20),

                if (_editing)
                  _EditAdminProfile(profile: widget.rawProfile, onSaved: _onSaved)
                else
                  _ViewAdmin(profile: widget.rawProfile),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── View: Admin ───────────────────────────────────────────────────────────────
class _ViewAdmin extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ViewAdmin({required this.profile});

  String get _name => profile['full_name']?.toString() ?? '';
  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String get _phoneAlt => (profile['phone_alt'] ?? '').toString();

  static const _accent = Color(0xFF2A3EB1);
  static const _accentMuted = Color(0xFFEDEFFA);
  static const _success = Color(0xFF1E9E5A);
  static const _successBg = Color(0xFFE7F7EE);
  static const _surface1 = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE4E6EE);
  static const _textPrimary = Color(0xFF1A1D29);
  static const _textSecondary = Color(0xFF5C6072);
  static const _textMuted = Color(0xFF9297A8);

  Widget _contactRow({
    required BuildContext context,
    required IconData leadingIcon,
    required Color leadingColor,
    required Color leadingBg,
    required String label,
    required String value,
    Widget? statusBadge,
    required IconData trailingIcon,
    required Color trailingColor,
    required Color trailingBg,
    required VoidCallback onTrailingTap,
  }) {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: leadingBg, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Icon(leadingIcon, color: leadingColor, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 13, color: _textMuted)),
            if (statusBadge != null) statusBadge,
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
        ]),
      ),
      const SizedBox(width: 8),
      InkWell(
        onTap: onTrailingTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: trailingBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(trailingIcon, color: trailingColor, size: 18),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final emailVerified = profile['email_verified'] == true;
    final email = profile['email']?.toString() ?? '';
    final phone = profile['phone_primary']?.toString() ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Center(
            child: Column(children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _accent, border: Border.all(color: _accentMuted, width: 6)),
                alignment: Alignment.center,
                child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 14),
              Text(_name, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: _accentMuted, borderRadius: BorderRadius.circular(999)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_outlined, size: 16, color: _accent),
                  SizedBox(width: 6),
                  Text('Administrator', style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 0.6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mawasiliano', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _contactRow(
                context: context,
                leadingIcon: Icons.email_outlined, leadingColor: _accent, leadingBg: _accentMuted,
                label: 'Barua pepe', value: email,
                statusBadge: emailVerified
                    ? const _AdminStatusBadge(label: 'Imethibitishwa', color: _success, background: _successBg)
                    : null,
                trailingIcon: Icons.copy_outlined, trailingColor: _textSecondary, trailingBg: _surface1,
                onTrailingTap: () {
                  Clipboard.setData(ClipboardData(text: email));
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Barua pepe imenakiliwa')));
                },
              ),
              const Divider(height: 26, color: _border),
              _contactRow(
                context: context,
                leadingIcon: Icons.call_outlined, leadingColor: _accent, leadingBg: _accentMuted,
                label: 'Namba ya simu', value: phone.isNotEmpty ? _fmtPhone(phone) : '—',
                trailingIcon: Icons.call, trailingColor: _accent, trailingBg: _accentMuted,
                onTrailingTap: () async {
                  final digits = phone.replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) return;
                  await launchUrl(Uri.parse('tel:+$digits'), mode: LaunchMode.externalApplication);
                },
              ),
              if (_phoneAlt.isNotEmpty) ...[
                const Divider(height: 26, color: _border),
                _contactRow(
                  context: context,
                  leadingIcon: Icons.chat_bubble_outline, leadingColor: _success, leadingBg: _successBg,
                  label: 'WhatsApp / Simu ya pili', value: _fmtPhone(_phoneAlt),
                  trailingIcon: Icons.chat_bubble, trailingColor: Colors.white, trailingBg: _success,
                  onTrailingTap: () async {
                    final digits = _phoneAlt.replaceAll(RegExp(r'\D'), '');
                    final intl = digits.startsWith('0') ? '255${digits.substring(1)}' : digits;
                    await launchUrl(Uri.parse('https://wa.me/$intl'), mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ]),
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.info_outline, size: 18, color: _textMuted)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Barua pepe haiwezi kubadilishwa hapa — wasiliana na admin mwenza.',
                  style: TextStyle(fontSize: 13, color: _textMuted, height: 1.35)),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 60),
    ]);
  }
}

class _AdminStatusBadge extends StatelessWidget {
  const _AdminStatusBadge({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

// ── Edit: Admin ───────────────────────────────────────────────────────────────
class _EditAdminProfile extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onSaved;
  const _EditAdminProfile({required this.profile, required this.onSaved});
  @override
  State<_EditAdminProfile> createState() => _EditAdminProfileState();
}

class _EditAdminProfileState extends State<_EditAdminProfile> {
  late TextEditingController _nameCtrl, _altCtrl;
  bool _saving = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  static const _accent = Color(0xFF2A3EB1);
  static const _accentMuted = Color(0xFFEDEFFA);
  static const _success = Color(0xFF1E9E5A);
  static const _surface1 = Color(0xFFF5F6FA);
  static const _border = Color(0xFFE4E6EE);
  static const _textPrimary = Color(0xFF1A1D29);
  static const _textSecondary = Color(0xFF5C6072);
  static const _textMuted = Color(0xFF9297A8);

  String get _name => widget.profile['full_name']?.toString() ?? '';
  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile['full_name'] ?? '');
    _altCtrl = TextEditingController(text: _strip255(widget.profile['phone_alt']?.toString() ?? ''));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _altCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService().updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone_alt': _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      });
      widget.onSaved();
    } catch (e) {
      setState(() { _saving = false; _error = _parseErr(e); });
    }
  }

  InputDecoration _inputDec(IconData? icon) => InputDecoration(
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _textMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _accent, width: 1.6)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
      );

  @override
  Widget build(BuildContext context) {
    final email = widget.profile['email']?.toString() ?? '';

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null) _ErrBox(_error!),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _accent),
                alignment: Alignment.center,
                child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _accentMuted, borderRadius: BorderRadius.circular(999)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield_outlined, size: 14, color: _accent),
                      SizedBox(width: 5),
                      Text('Administrator', style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            const Text('Taarifa za msingi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            const Text('Jina kamili', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _accent)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(fontSize: 15, color: _textPrimary),
              decoration: _inputDec(Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Weka jina kamili' : null,
            ),
            const SizedBox(height: 18),
            const Text('Namba ya simu (Pili / WhatsApp)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: const BoxDecoration(
                    color: _surface1,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                  child: const Text('+255', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _textPrimary)),
                ),
                Container(width: 1, height: 24, color: _border),
                Expanded(
                  child: TextFormField(
                    controller: _altCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 15, color: _textPrimary),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    validator: (v) =>
                        (v != null && v.trim().isNotEmpty && v.trim().length < 9) ? 'Namba si sahihi' : null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chat_bubble, color: _success, size: 20),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('Barua pepe',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: _surface1, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.email_outlined, size: 20, color: _textMuted),
                const SizedBox(width: 10),
                Expanded(child: Text(email, style: const TextStyle(fontSize: 15, color: _textMuted))),
                const Icon(Icons.lock_outline, size: 18, color: _textMuted),
              ]),
            ),
            const SizedBox(height: 10),
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.info_outline, size: 16, color: _textMuted)),
              SizedBox(width: 6),
              Expanded(child: Text('Barua pepe haiwezi kubadilishwa hapa — wasiliana na admin mwenza.',
                  style: TextStyle(fontSize: 12, color: _textMuted, height: 1.35))),
            ]),
          ]),
        ),

        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.maybePop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                side: const BorderSide(color: _border),
                foregroundColor: _textPrimary,
              ),
              child: const Text('Ghairi', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Inahifadhi...' : 'Hifadhi mabadiliko',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 60),
      ]),
    );
  }
}

class _ErrBox extends StatelessWidget {
  final String message;
  const _ErrBox(this.message);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
        child: Text(message, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 14)),
      );
}
