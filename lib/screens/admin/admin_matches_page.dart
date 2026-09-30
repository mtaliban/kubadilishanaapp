// =============================================================================
// admin_matches_page.dart
// "Waliopata wenzao" — inapakua data kutoka API na kuionyesha kwenye
// WenzaoView. WenzaoView inashughulikia filtering, pagination, na UI yote.
// Data halisi: GET /admin/users/with-matches
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'wenzao_view.dart';

class AdminMatchesPage extends StatefulWidget {
  const AdminMatchesPage({super.key});

  @override
  State<AdminMatchesPage> createState() => _AdminMatchesPageState();
}

class _AdminMatchesPageState extends State<AdminMatchesPage> {
  bool _loading = true;
  String? _error;
  List<WenzaoPerson> _people = [];
  List<String> _allRegions = const [];

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().adminUsersWithMatches(limit: 500);
      if (!mounted) return;
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw['users'] ?? raw['results'] ?? raw['data']) as List? ?? []);
      setState(() {
        _people =
            list.whereType<Map<String, dynamic>>().map(_mapPerson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0F7A52)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 52, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 14),
              const Text('Imeshindikana kupakia',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF5B6475), fontSize: 13)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Jaribu tena'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F7A52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF0F7A52),
        child: WenzaoView(people: _people, allRegions: _allRegions),
      ),
    );
  }
}
