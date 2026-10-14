// =============================================================================
// admin_matches_page.dart
// "Waliopata wenzao" — inapakua data kutoka API na kuionyesha kwenye
// WenzaoView. WenzaoView inashughulikia filtering, pagination, na UI yote.
// Data halisi: GET /admin/users/with-matches
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cached_repository.dart';
import '../../widgets/no_cached_data_widget.dart';
import 'wenzao_view.dart';

class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});

  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  bool _loading = true;
  List<WenzaoPerson> _people = [];
  List<String> _allRegions = const [];

  /// OFFLINE-FIRST — funguo ya diski ya CachedRepository.
  static const String _kKey = 'page:admin/users-with-matches';

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _load();
  }

  Future<void> _loadRegions() async {
    try {
      final res = await ApiService().getRegions();
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw is Map ? raw['regions'] ?? raw['data'] : null) as List? ?? []);
      final names = <String>[];
      for (final r in list) {
        if (r is! Map) continue;
        final name = '${r['name'] ?? r['region_name'] ?? ''}'.trim();
        if (name.isNotEmpty) names.add(name);
      }
      names.sort();
      if (mounted) setState(() => _allRegions = names);
    } catch (_) {}
  }

  Future<void> _load() async {
    // OFFLINE-FIRST: diski kwanza (papo hapo), kisha refresh nyuma ya pazia.
    // Ikishindwa (offline) — skrini HAKIBADILIKI: data ya diski inabaki.
    await CachedRepository().loadPage(
        _kKey,
        () async =>
            (await ApiService().adminUsersWithMatches(limit: 500)).data,
        (data) async {
      if (!mounted || data == null) return;
      final list = data is List
          ? data
          : ((data['users'] ?? data['results'] ?? data['data'] ?? const [])
              as List);
      setState(() {
        _people =
            list.whereType<Map<String, dynamic>>().map(_mapPerson).toList();
        _loading = false;
      });
    });
    if (!mounted) return;
    if (_people.isEmpty && _loading) setState(() => _loading = false);
  }

  /* ── Data mapping ── */

  static WenzaoPerson _mapPerson(Map<String, dynamic> u) {
    final station = u['current_station'] as Map? ?? {};
    final region = (u['region_name'] as String?) ??
        (u['current_region'] as String?) ??
        (station['region_name'] as String?) ??
        '';
    final district = (u['district_name'] as String?) ??
        (u['current_district'] as String?) ??
        (station['district_name'] as String?) ??
        '';
    final kada = (u['cadre_display'] as String?) ??
        (u['cadre_name'] as String?) ??
        (u['cadre_code'] as String?) ??
        '';
    final rawDests =
        (u['destinations'] ?? u['desired_destinations']) as List? ?? [];
    final dests = rawDests.map((d) {
      if (d is Map) {
        final mkoa =
            (d['region_name'] ?? d['name'] ?? '').toString();
        final w =
            (d['district_name'] ?? d['district'])?.toString().trim();
        return WenzaoDestination(
          mkoa: mkoa,
          wilaya: (w == null || w.isEmpty) ? null : w,
        );
      }
      return WenzaoDestination(mkoa: d.toString());
    }).toList();

    final wa = (u['phone_alt'] as String?)?.trim();

    return WenzaoPerson(
      id: (u['id'] ?? u['_id'] ?? '').toString(),
      name: (u['full_name'] as String?) ?? '',
      paid: (u['is_verified'] as bool?) ?? false,
      idara: (u['category'] as String?) ?? '',
      kada: kada,
      fromMkoa: region,
      fromWilaya: district,
      destinations: dests,
      phone: (u['phone_primary'] as String?) ??
          (u['phone'] as String?) ??
          '',
      whatsapp: (wa == null || wa.isEmpty) ? null : wa,
    );
  }

  /* ── Build ── */

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasDisk = CachedRepository().readOrNull<dynamic>(_kKey) != null;
    if (_loading && _people.isEmpty && !hasDisk) {
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
        body: Center(
          child: CircularProgressIndicator(
              color: dark ? const Color(0xFF5FD49A) : const Color(0xFF0F7A52)),
        ),
      );
    }

    if (_people.isEmpty && !hasDisk) {
      // HAKUNA data diski + API imeshindwa — widget MOYA ya "haijapakuliwa"
      // (pull-to-refresh pekee; huwezi "Jaribu tena" button).
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
        body: RefreshIndicator(
          onRefresh: _load,
          color: dark ? const Color(0xFF5FD49A) : const Color(0xFF0F7A52),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              NoCachedDataWidget(
                hint: 'Vuta chini kupakia — wenzao watahifadhiwa kwenye simu.',
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: dark ? const Color(0xFF5FD49A) : const Color(0xFF0F7A52),
        child: WenzaoView(people: _people, allRegions: _allRegions),
      ),
    );
  }
}
