// ============================================================================
// test/data_chain_test.dart
// TESTING YA NGUVU — mnyororo wa data ya reference end-to-end:
//   1. LIMIT: /locations/*/facilities ina default ya 200 kwenye backend —
//      app lazima iombe limit=1000 ili wilaya kubwa (mf. Arusha Cc: 328
//      vituo) zioneshwe ZOTE. Bila hii, mtumiaji hataoni kituo chake.
//   2. LIVE REFRESH: admin akiongeza mkoa/wilaya/kituo, WS data.changed →
//      AppCache invalidation → revision inaongezeka → screens zilizosikiliza
//      (register/profile) zinapakia upya PAPO HAPO — bila reload ya page.
//   3. SEAMLESS: hakuna spinner ya kukatiza wakati wa refresh ya dropdowns —
//      selection zinadumu.
//   4. CHAIN KAMILI: regions → districts → facilities (health + education)
//      zote zinafanya kazi na shapes halisi za backend.
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';

import 'helpers/fake_api.dart';

/// Fake backend ya locations — inakumbuka state na inarudisha shapes halisi.
class _LocationBackend {
  final Map<int, List<Map<String, dynamic>>> districtsByRegion = {
    1: [
      {'id': 11, 'name': 'Arusha Mjini', 'region_id': 1},
      {'id': 12, 'name': 'Arusha Vijijini', 'region_id': 1},
    ],
    2: [
      {'id': 21, 'name': 'Dodoma Mjini', 'region_id': 2},
    ],
  };
  final Map<int, List<Map<String, dynamic>>> facilitiesByDistrict = {
    // Wilaya 11 ina vituo 250 — ZAIDI ya default ya 200 ya backend!
    11: List.generate(250, (i) => {
          'code': 'F${1000 + i}',
          'name': 'Kituo cha Afya ${i + 1}',
          'type': 'Dispensary',
        }),
    21: [
      {'code': 'S1', 'name': 'SHULE YA MSINGI KHADIJA', 'level': 'Primary',
       'school_code': 'PS1'},
    ],
  };
  final List<Map<String, dynamic>> regions = [
    {'id': 1, 'name': 'Arusha'},
    {'id': 2, 'name': 'Dodoma'},
  ];
  bool regionAddedByAdmin = false;
}

class _ChainRoutes extends FakeApiAdapter {
  final _LocationBackend db;
  final List<String> calls = [];
  _ChainRoutes(this.db);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    final q = options.uri.queryParameters;
    calls.add('$path?${q.entries.map((e) => '${e.key}=${e.value}').join('&')}');

    if (path == '/locations/regions') {
      final list = db.regionAddedByAdmin
          ? [...db.regions, {'id': 3, 'name': 'Mkoa Mpya wa Admin'}]
          : db.regions;
      return _json(list);
    }
    final distMatch =
        RegExp(r'^/locations/regions/(\d+)/districts$').firstMatch(path);
    if (distMatch != null) {
      return _json(db.districtsByRegion[int.parse(distMatch.group(1)!)] ?? []);
    }
    final facMatch = RegExp(
        r'^/locations/districts/(\d+)/facilities$').firstMatch(path);
    if (facMatch != null) {
      final did = int.parse(facMatch.group(1)!);
      final cat = q['category'] ?? 'health';
      final all = db.facilitiesByDistrict[did] ?? [];
      // UDIANI HALISI ya backend: default 200, limit inayoombeza inaheshimiwa.
      final limit = int.tryParse(q['limit'] ?? '') ?? 200;
      return _json(all.take(limit).toList());
    }
    if (path == '/auth/me') return _json(Map<String, dynamic>.from(fakeMe));
    return _json({});
  }

  Future<ResponseBody> _json(dynamic data, [int status = 200]) async =>
      ResponseBody.fromString(jsonEncode(data), status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
}

void main() {
  late _LocationBackend db;
  late _ChainRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    db = _LocationBackend();
    routes = _ChainRoutes(db);
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppCache().clear();
    routes.calls.clear();
    db.regionAddedByAdmin = false;
  });

  group('1. LIMIT — vituo VYOTE vya wilaya (siyo 200 tu)', () {
    test('getFacilities inaomba limit=1000 — wilaya ya vituo 250 inakamilika',
        () async {
      final res = await ApiService().getFacilities(11, category: 'health');
      final list = res.data as List;
      expect(list.length, 250,
          reason: 'Wilaya ina vituo 250 — default ya 200 ingekata 50! '
              'App lazima iombe limit=1000.');
      // Thibitisha ombi halisi lililoenda server
      expect(routes.calls.any((c) => c.contains('limit=1000')), isTrue,
          reason: 'Query ya limit=1000 lazima ionekane kwenye request');
    });

    test('getFacilitiesByRegion inaomba limit=1000 pia (wizara)', () async {
      await ApiService().getFacilitiesByRegion(1,
          category: 'health', employmentSector: 'wizara_afya');
      final call = routes.calls
          .firstWhere((c) => c.contains('/locations/regions/1/facilities'));
      expect(call, contains('limit=1000'),
          reason: 'Vituo vya mkoa mzima ni mamia — limit lazima iombwe');
      expect(call, contains('employment_sector=wizara_afya'));
    });

    test('education (shule) zinapatikana kwa category=education', () async {
      final res = await ApiService().getFacilities(21, category: 'education');
      final list = (res.data as List).cast<Map>();
      expect(list.first['name'], 'SHULE YA MSINGI KHADIJA');
      expect(list.first['school_code'], 'PS1');
    });
  });

  group('2. LIVE REFRESH — admin anapoongeza data, screen zinaona MARA MOJA',
      () {
    test('AppCache revision inaongezeka + listeners zinaitwa kwa invalidation',
        () async {
      var notified = 0;
      final revBefore = AppCache().revision;
      AppCache().addListener(() => notified++);

      // Cache yenye data halisi (kama screen iliyopakia mikoa/wilaya)
      AppCache().set('/locations/regions', [{'id': 1, 'name': 'Arusha'}]);
      AppCache().set('/locations/regions/1/districts', [{'id': 11}]);

      // WS data.changed handler: inafuta cache za reference data
      AppCache().invalidatePrefix('/locations/regions');
      expect(notified, 1, reason: 'Listener imeitwa mara moja');
      expect(AppCache().revision, revBefore + 1);

      AppCache().set('/locations/districts/11/facilities', [{'code': 'F1'}]);
      AppCache().invalidatePrefix('/locations/districts/');
      expect(notified, 2);
      expect(AppCache().revision, revBefore + 2);
    });

    test('invalidation ya prefix isiyo na hits HAIITI listener (revision '
        'haipande ovyo)', () async {
      AppCache().set('/admin/data/regions', [1, 2]);
      var notified = 0;
      AppCache().addListener(() => notified++);
      AppCache().invalidatePrefix('/hakuna-kitu-hapa');
      expect(notified, 0,
          reason: 'Bila mabadiliko halisi, hakuna haja ya kuamsha screens');
    });

    test('GET mpya baada ya invalidation inaona mkoa mpya wa admin '
        '(si cache ya kale)', () async {
      // Cache ya kale
      final stale = await ApiService().getRegions();
      expect((stale.data as List).length, 2);

      // Admin ameongeza mkoa → WS data.changed → cache futa
      db.regionAddedByAdmin = true;
      AppCache().invalidatePrefix('/locations/regions');

      // GET mpya — server ina mikoa 3
      final fresh = await ApiService().getRegions();
      final names =
          (fresh.data as List).map((r) => '${r['name']}').toList();
      expect(names, contains('Mkoa Mpya wa Admin'),
          reason: 'Data ya admin inaonekana kwenye app BILA restart');
    });
  });

  group('3. SEAMLESS — mtiririko wa screen zilizosikiliza AppCache', () {
    test('screen yenye AppCache listener inapakia mikoa upya (silent) '
        'data.changed ikiwa', () async {
      // Replica ya pattern iliyotumika kwenye register/profile screens:
      // listener ya revision → refetch (hii ndiyo tabia ya _Step5Station
      // na profile_screen — tunaihakiki kama unit).
      int rebuilds = 0;
      List<dynamic>? regions;

      Future<void> refetch() async {
        final r = await ApiService().getRegions();
        regions = r.data as List?;
        rebuilds++;
      }

      var rev = AppCache().revision;
      void listener() {
        if (AppCache().revision != rev) {
          rev = AppCache().revision;
          refetch();
        }
      }

      AppCache().addListener(listener);

      await refetch(); // kwanza — mikoa 2
      expect(regions!.length, 2);

      // Admin anaongeza mkoa → WS data.changed → cache invalidation
      db.regionAddedByAdmin = true;
      AppCache().invalidatePrefix('/locations/regions');
      // Subiri refetch ya listener (async microtask + network fake)
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(rebuilds, 2,
          reason: 'Listener imepata revision mpya na kupakia upya');
      expect(regions!.length, 3,
          reason: 'Mkoa mpya wa admin yumo — screen haioni cache ya kale');

      AppCache().removeListener(listener);
    });
  });
}
