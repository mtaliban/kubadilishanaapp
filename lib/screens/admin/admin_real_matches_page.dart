// =============================================================================
// admin_real_matches_page.dart
// Ukurasa wa "Match za kweli" — inapakua data kutoka API na kuionyesha
// kwenye MatchView. Scaffold inashughulikia loading/error; MatchView
// inashughulikia filtering, pagination, na UI yote.
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/cached_repository.dart';
import '../../widgets/skeletons.dart';
import 'match_view.dart';

class AdminRealMatchesPage extends StatefulWidget {
  const AdminRealMatchesPage({super.key});

  @override
  State<AdminRealMatchesPage> createState() => _AdminRealMatchesPageState();
}

class _AdminRealMatchesPageState extends State<AdminRealMatchesPage> {
  bool _loading = true;
  List<MatchPair> _pairs = [];
  final Set<String> _starred = {};
  List<String> _allRegions = const [];

  /// OFFLINE-FIRST — funguo ya diski ya CachedRepository.
  static const String _kKey = 'page:admin/real-matches';

  @override
  void initState() {
    super.initState();
    // DISKI PAPO HAPO — frame ya KWANZA (hakuna spring, hakuna kusubiri).
    CachedRepository().hydrate(_kKey, _applyPairs);
    _loadRegions();
    _load();
  }

  void _applyPairs(dynamic data) {
    if (data == null) return; // API imeshindwa → diski ibaki
    final list = data is List
        ? data
        : ((data['matches'] ?? data['results'] ?? const []) as List);
    setState(() {
      _pairs = list
          .whereType<Map<String, dynamic>>()
          .map(_mapPair)
          .toList();
      _loading = false;
    });
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
    await CachedRepository()
        .loadPage(_kKey, () async => (await ApiService().adminRealMatches(limit: 500)).data,
        _applyPairs);
    if (!mounted) return;
    if (_pairs.isEmpty && _loading) setState(() => _loading = false);
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasDisk = CachedRepository().readOrNull<dynamic>(_kKey) != null;
    if (_loading && _pairs.isEmpty && !hasDisk) {
      // KANUNI: KAMWE spinner — skeleton ya ukurasa tu.
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
        body: const WenzaoSkeleton(),
      );
    }

    if (_pairs.isEmpty && !hasDisk) {
      // HAKUNA data diski + API imeshindwa — skeleton MOYA (pull-to-refresh pekee).
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
        body: const WenzaoSkeleton(),
      );
    }

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: dark ? const Color(0xFF5FD49A) : const Color(0xFF0F7A52),
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
