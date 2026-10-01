// =============================================================================
// admin_real_matches_page.dart
// Ukurasa wa "Match za kweli" — inapakua data kutoka API na kuionyesha
// kwenye MatchView. Scaffold inashughulikia loading/error; MatchView
// inashughulikia filtering, pagination, na UI yote.
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/app_toast.dart';
import 'match_view.dart';

class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});

  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  bool _loading = true;
  String? _error;
  List<MatchPair> _pairs = [];
  final Set<String> _starred = {};
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
      final res = await ApiService().adminRealMatches(limit: 500);
      if (!mounted) return;
      final raw = res.data;
      final list = raw is List
          ? raw
          : ((raw['matches'] ?? raw['results']) as List? ?? []);
      setState(() {
        _pairs = list
            .whereType<Map<String, dynamic>>()
            .map(_mapPair)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  /* ── Data mapping ── */

  static MatchPair _mapPair(Map<String, dynamic> m) {
    final a = m['user_a'] as Map<String, dynamic>? ?? {};
    final b = m['user_b'] as Map<String, dynamic>? ?? {};

    // Score: API inatuma 0.0–1.0 au 0–100
    final scoreRaw = (m['score'] as num?)?.toDouble() ?? 0.0;
    final score =
        scoreRaw > 1 ? scoreRaw.round() : (scoreRaw * 100).round();

    final cat = (m['category'] as String?) ??
        (a['category'] as String?) ??
        '';
    final kada = (m['cadre_display'] as String?) ??
        (a['cadre_display'] as String?) ??
        (a['cadre_name'] as String?) ??
        (m['cadre_code'] as String?) ??
        (a['cadre_code'] as String?) ??
        '';
    final subs = (m['common_subjects'] as List?)
            ?.map((s) => s.toString())
            .toList() ??
        [];
    final id = (m['id'] as String?) ??
        '${a['id'] ?? ''}_${b['id'] ?? ''}';

    return MatchPair(
      id: id,
      score: score,
      idara: cat,
      kada: kada,
      matchedSubjects: subs,
      a: _mapPerson(a),
      b: _mapPerson(b),
    );
  }

  static MatchPerson _mapPerson(Map<String, dynamic> u) {
    final station = u['current_station'] as Map? ?? {};
    final region = (u['current_region'] as String?) ??
        (station['region_name'] as String?) ??
        '';
    final district = (u['current_district'] as String?) ??
        (station['district_name'] as String?) ??
        '';

    final rawDests =
        (u['desired_destinations'] ?? u['destinations']) as List? ?? [];
    final dests = rawDests.map((d) {
      if (d is Map) {
        final w =
            (d['district_name'] ?? d['district'])?.toString().trim();
        return MatchDestination(
          mkoa: (d['region_name'] ?? d['region'] ?? '').toString(),
          wilaya: (w == null || w.isEmpty) ? null : w,
        );
      }
      return MatchDestination(mkoa: d.toString());
    }).toList();

    final wa = (u['phone_alt'] as String?)?.trim();

    return MatchPerson(
      name: (u['full_name'] as String?) ?? '',
      paid: (u['is_verified'] as bool?) ?? false,
      fromMkoa: region,
      fromWilaya: district,
      destinations: dests,
      subjects: (u['subjects'] as List?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
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
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0F7A52)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF0F7A52),
        child: MatchView(
          pairs: _pairs,
          allRegions: _allRegions,
          starredIds: _starred,
          onStar: (pair, on) => setState(
            () => on
                ? _starred.add(pair.id)
                : _starred.remove(pair.id),
          ),
        ),
      ),
    );
  }
}
