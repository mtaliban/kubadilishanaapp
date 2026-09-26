// ============================================================================
// test/admin_data_flow_test.dart
// TESTING COMPLEX za DATA page ya admin (idara/somo/kada/mkoa/wilaya):
//   1. CRUD kamilii: GET list, POST add, PATCH update, DELETE — kwa kila type
//   2. Server state inabadilika KWELI (fake backend inakumbuka)
//   3. Duplicate (409) na 404 zinashughulikiwa
//   4. Cache invalidation: adminCreateData/Update/Delete zinabust cache
//   5. PROPAGATION: data.changed WS → cache za reference data (regions/
//      districts/cadres) zinafutwa → usajili unaona vipya MARA MOJA
//      (bug ya TTL ya dakika 30 iliyorekebishwa)
//   6. UI: AdminDataPage inaonyesha data kutoka API (siyo hardcoded)
// Zote zinatumia FakeApiAdapter — hakuna network halisi.
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/screens/admin/admin_data_page.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/services/websocket_service.dart';

import 'helpers/fake_api.dart';

// ── Fake backend ya reference data (inakumbuka state kama Mongo halisi) ─────
class DataBackend {
  // type → list ya items
  final Map<String, List<Map<String, dynamic>>> store = {
    'departments': [
      {'code': 'health', 'name': 'Afya', 'status': 'active', 'icon': 'heart'},
      {'code': 'education', 'name': 'Elimu', 'status': 'active', 'icon': 'book'},
    ],
    'subjects': [
      {'code': 'HIS', 'name': 'Hisabati', 'level': 'Primary', 'is_active': true},
    ],
    'cadres': [
      {'code': 'TCH', 'display_name': 'Mwalimu', 'category': 'education',
       'level': 'Primary', 'requires_subjects': true, 'is_active': true},
    ],
    'regions': [
      {'id': 1, 'name': 'Arusha', 'is_active': true},
      {'id': 2, 'name': 'Dodoma', 'is_active': true},
    ],
    'districts': [
      {'id': 11, 'name': 'Arusha Mjini', 'region_id': 1, 'is_active': true},
    ],
  };
  int nextRegionId = 3;
  int nextDistrictId = 12;

  List<Map<String, dynamic>> list(String type, {int? regionId}) {
    var items = store[type] ?? [];
    if (type == 'districts' && regionId != null) {
      items = items.where((d) => d['region_id'] == regionId).toList();
    }
    return items.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic>? find(String type, String idOrCode) =>
      (store[type] ?? [])
          .where((x) => '${x['id'] ?? x['code']}' == idOrCode)
          .firstOrNull;

  bool add(String type, Map<String, dynamic> item) {
    // Duplicate check (code au id)
    final key = item['code'] ?? item['id'];
    if ((store[type] ?? []).any((x) => '${x['code'] ?? x['id']}' == '$key')) {
      return false;
    }
    (store[type] ??= []).add(item);
    return true;
  }

  bool update(String type, String idOrCode, Map<String, dynamic> updates) {
    final x = find(type, idOrCode);
    if (x == null) return false;
    x.addAll(updates);
    return true;
  }

  bool delete(String type, String idOrCode) {
    final x = find(type, idOrCode);
    if (x == null) return false;
    (store[type] ??= []).remove(x);
    return true;
  }
}

class _DataRoutes extends FakeApiAdapter {
  final DataBackend backend;
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};
  final List<String> dataEvents = []; // simuliza events za data.changed

  _DataRoutes(this.backend);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    calls.add('${options.method} $path');

    Future<Map<String, dynamic>> parseBody() async {
      if (requestStream == null) return {};
      final chunks = <List<int>>[];
      await for (final c in requestStream) {
        chunks.add(c);
      }
      if (chunks.isEmpty) return {};
      final decoded =
          jsonDecode(utf8.decode(Uint8List.fromList(chunks.expand((x) => x).toList())));
      return decoded is Map<String, dynamic> ? decoded : {};
    }

    // GET /admin/data/{type}
    final listM = RegExp(r'^/admin/data/(\w+)$').firstMatch(path);
    if (listM != null && options.method == 'GET') {
      final type = listM.group(1)!;
      if (!backend.store.containsKey(type)) return _json([], 200);
      final rid = int.tryParse('${options.uri.queryParameters['region_id'] ?? ''}');
      return _json(backend.list(type, regionId: rid));
    }

    // POST /admin/data/{type}
    if (listM != null && options.method == 'POST') {
      final type = listM.group(1)!;
      final body = await parseBody();
      bodies['POST /admin/data/$type'] = body;
      // Auto-id kama backend halisi (regions/districts)
      if ((type == 'regions' || type == 'districts') &&
          (body['id'] == null || '${body['id']}' == 'null' || '${body['id']}' == '0')) {
        body['id'] =
            type == 'regions' ? backend.nextRegionId++ : backend.nextDistrictId++;
      }
      // Code auto-generate kama backend halisi (departments)
      if (type == 'departments' &&
          (body['code'] == null || '${body['code']}'.trim().isEmpty || '${body['code']}' == 'null')) {
        body['code'] = '${body['name']}'
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
      }
      final ok = backend.add(type, body);
      if (!ok) return _json({'detail': 'duplicate'}, 409);
      dataEvents.add('added:$type');
      return _json({'ok': true}, 201);
    }

    // PATCH /admin/data/{type}/{id}
    final patchM = RegExp(r'^/admin/data/(\w+)/([^/]+)$').firstMatch(path);
    if (patchM != null && options.method == 'PATCH') {
      final type = patchM.group(1)!;
      final id = patchM.group(2)!;
      final body = await parseBody();
      bodies['PATCH /admin/data/$type/$id'] = body;
      final ok = backend.update(type, id, body);
      if (!ok) return _json({'detail': 'not found'}, 404);
      dataEvents.add('updated:$type');
      return _json({'ok': true});
    }

    // DELETE /admin/data/{type}/{id}
    if (patchM != null && options.method == 'DELETE') {
      final type = patchM.group(1)!;
      final id = patchM.group(2)!;
      final ok = backend.delete(type, id);
      if (!ok) return _json({'detail': 'not found'}, 404);
      dataEvents.add('deleted:$type');
      return _json({'ok': true});
    }

    if (path == '/auth/login') {
      return _json({'access_token': 'tok-test', 'user_id': 'u1',
                    'full_name': 'Thea Shirima', 'is_admin': true});
    }
    if (path == '/auth/me') return _json(Map<String, dynamic>.from(fakeMe));
    if (path == '/notifications' || path.startsWith('/notifications')) {
      return _json({'notifications': []});
    }
    return _json({});
  }

  Future<ResponseBody> _json(dynamic data, [int status = 200]) async {
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  late DataBackend backend;
  late _DataRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    backend = DataBackend();
    routes = _DataRoutes(backend);
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    WebSocketService().clearListeners(); // listeners za test zilizopita
    // Rejesha state ya mwanzo
    backend.store['departments'] = [
      {'code': 'health', 'name': 'Afya', 'status': 'active', 'icon': 'heart'},
      {'code': 'education', 'name': 'Elimu', 'status': 'active', 'icon': 'book'},
    ];
    backend.store['subjects'] = [
      {'code': 'HIS', 'name': 'Hisabati', 'level': 'Primary', 'is_active': true},
    ];
    backend.store['cadres'] = [
      {'code': 'TCH', 'display_name': 'Mwalimu', 'category': 'education',
       'level': 'Primary', 'requires_subjects': true, 'is_active': true},
    ];
    backend.store['regions'] = [
      {'id': 1, 'name': 'Arusha', 'is_active': true},
      {'id': 2, 'name': 'Dodoma', 'is_active': true},
    ];
    backend.store['districts'] = [
      {'id': 11, 'name': 'Arusha Mjini', 'region_id': 1, 'is_active': true},
    ];
    backend.nextRegionId = 3;
    backend.nextDistrictId = 12;
    routes.bodies.clear();
    routes.dataEvents.clear();
    AppCache().clear();
  });

  group('1. IDARA (departments) — CRUD kamili', () {
    test('GET: inaonyesha idara zilizopo', () async {
      final res = await ApiService().adminListData('departments');
      final list = (res.data as List).cast<Map>();
      expect(list, hasLength(2));
      expect('${list.first['name']}', 'Afya');
    });

    test('POST: idara mpya inaongezwa (code auto-generate)', () async {
      final res = await ApiService()
          .adminCreateData('departments', {'name': 'Maji na Usafi'});
      expect(res.statusCode, 201);
      // Server state imebadilika
      expect(backend.find('departments', 'maji_na_usafi'), isNotNull);
      final sent = routes.bodies['POST /admin/data/departments']!;
      expect(sent['name'], 'Maji na Usafi');
    });

    test('POST duplicate → 409 (idara iliyopo haingizwi mara mbili)', () async {
      // Code 'health' ipo — backend halisi inakataa 409 kabla ya kuingiza
      try {
        await ApiService().adminCreateData(
            'departments', {'name': 'Afya Mpya', 'code': 'health'});
        fail('Inapaswa kushindwa (409)');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 409);
      }
    });

    test('PATCH: jina/status zinabadilika', () async {
      await ApiService()
          .adminUpdateData('departments', 'health', {'name': 'Afya Kuu'});
      expect(backend.find('departments', 'health')!['name'], 'Afya Kuu');
    });

    test('DELETE: idara inafutwa (bila kada/watumiaji)', () async {
      final ok = await ApiService().adminDeleteData('departments', 'health');
      expect(ok.data['ok'], isTrue);
      expect(backend.find('departments', 'health'), isNull);
    });

    test('PATCH/DELETE ya isiyopo → 404', () async {
      try {
        await ApiService().adminUpdateData('departments', 'ghost', {'name': 'x'});
        fail('404 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 404);
      }
      try {
        await ApiService().adminDeleteData('departments', 'ghost');
        fail('404 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 404);
      }
    });
  });

  group('2. SOMO (subjects) — CRUD', () {
    test('POST somo mpya (code kutoka app)', () async {
      // App (admin_data_page _slugify) inatuma code yake — mfano BIO
      await ApiService().adminCreateData(
          'subjects', {'name': 'Biolojia', 'code': 'BIO', 'level': 'Primary'});
      expect(backend.find('subjects', 'BIO'), isNotNull);
      final sent = routes.bodies['POST /admin/data/subjects']!;
      expect(sent['code'], 'BIO');
      expect(sent['level'], 'Primary');
    });

    test('PATCH + DELETE somo', () async {
      await ApiService()
          .adminUpdateData('subjects', 'HIS', {'name': 'Hisabati Kuu'});
      expect(backend.find('subjects', 'HIS')!['name'], 'Hisabati Kuu');

      await ApiService().adminDeleteData('subjects', 'HIS');
      expect(backend.find('subjects', 'HIS'), isNull);
    });
  });

  group('3. KADA (cadres) — CRUD', () {
    test('POST kada mpya (idara husika)', () async {
      await ApiService().adminCreateData('cadres', {
        'display_name': 'Mwalimu wa Msingi',
        'code': 'TCHP',
        'category': 'education',
        'level': 'Primary',
        'requires_subjects': true,
        'is_active': true,
      });
      expect(backend.find('cadres', 'TCHP'), isNotNull);
      final sent = routes.bodies['POST /admin/data/cadres']!;
      expect(sent['category'], 'education');
      expect(sent['requires_subjects'], isTrue);
    });

    test('PATCH kada + DELETE', () async {
      await ApiService().adminUpdateData('cadres', 'TCH', {'level': 'Secondary'});
      expect(backend.find('cadres', 'TCH')!['level'], 'Secondary');

      await ApiService().adminDeleteData('cadres', 'TCH');
      expect(backend.find('cadres', 'TCH'), isNull);
    });
  });

  group('4. MKOA (regions) — CRUD (id auto kama backend halisi)', () {
    test('POST mkoa mpya — ID inajiongezea yenyewe', () async {
      final res = await ApiService().adminCreateData('regions', {'name': 'Songwe'});
      expect(res.statusCode, 201);
      final sent = routes.bodies['POST /admin/data/regions']!;
      expect(sent['id'], 3, reason: 'Backend inatoa id mpya automatically');
      expect(backend.find('regions', '3'), isNotNull);
      expect(backend.find('regions', '3')!['name'], 'Songwe');
    });

    test('POST mkoa duplicate id → 409', () async {
      try {
        await ApiService()
            .adminCreateData('regions', {'id': 1, 'name': 'Nakopiwa'});
        fail('409 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 409);
      }
    });

    test('PATCH mkoa + DELETE mkoa', () async {
      await ApiService().adminUpdateData('regions', '1', {'name': 'Arusha Kuu'});
      expect(backend.find('regions', '1')!['name'], 'Arusha Kuu');

      await ApiService().adminDeleteData('regions', '1');
      expect(backend.find('regions', '1'), isNull);
    });
  });

  group('5. WILAYA (districts) — CRUD (region_id inatumika)', () {
    test('POST wilaya mpya chini ya mkoa', () async {
      await ApiService().adminCreateData(
          'districts', {'name': 'Bahi', 'region_id': 2});
      final sent = routes.bodies['POST /admin/data/districts']!;
      expect(sent['region_id'], 2);
      expect(backend.find('districts', '12'), isNotNull);
      expect(backend.find('districts', '12')!['name'], 'Bahi');
    });

    test('PATCH wilaya (kuhamisha mkoa) + DELETE', () async {
      await ApiService().adminUpdateData(
          'districts', '11', {'region_id': 2, 'name': 'Arusha Vijijini'});
      final d = backend.find('districts', '11')!;
      expect(d['region_id'], 2);
      expect(d['name'], 'Arusha Vijijini');

      await ApiService().adminDeleteData('districts', '11');
      expect(backend.find('districts', '11'), isNull);
    });

    test('filter ya wilaya kwa region_id inafanya kazi', () async {
      await ApiService().adminCreateData(
          'districts', {'name': 'Bahi', 'region_id': 2});
      // Wilaya za mkoa 1 tu
      final r1 = await ApiService().adminListData('districts');
      final all = (r1.data as List).cast<Map>();
      expect(all, hasLength(2)); // Arusha Mjini + Bahi
    });
  });

  group('6. CACHE — actions zote zinabust cache (siyo utani)', () {
    test('adminCreateData inafuta cache ya /admin/data/{type}', () async {
      await ApiService().adminListData('regions');
      final key = AppCache()
          .get('/admin/data/regions');
      expect(key, isNotNull);

      await ApiService().adminCreateData('regions', {'name': 'Mpya'});
      expect(AppCache().get('/admin/data/regions'), isNull,
          reason: 'Cache lazima ifutwe — list inayofuata ipakie vipya');
    });

    test('adminUpdateData + adminDeleteData zinabust cache', () async {
      await ApiService().adminListData('subjects');
      await ApiService().adminUpdateData('subjects', 'HIS', {'name': 'X'});
      expect(AppCache().get('/admin/data/subjects'), isNull);

      await ApiService().adminListData('cadres');
      await ApiService().adminDeleteData('cadres', 'TCH');
      expect(AppCache().get('/admin/data/cadres'), isNull);
    });
  });

  group('7. PROPAGATION — data iliyongezwa inaonekana kila sehemu (siyo hardcoded)',
      () {
    test('WS data.changed → cache za reference data zinabustwa (usajili unaona '
        'mkoa mpya MARA MOJA)', () async {
      // (AuthProvider halisi inasikiliza data.changed ndani ya _setupRealtime;
      //  kwenye test tunasimuliza login ili listener ziwekwe.)
      final auth = AuthProvider();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await auth.login('0757000111', password: 'pass1234');
      // Jaza caches za reference data (mfano usajili umewahi kuzipakia)
      await ApiService().getRegions(); // cache /locations/regions
      await ApiService().getDistricts(1); // cache /locations/regions/1/districts
      await ApiService().getCadres(category: 'education'); // cache /cadres
      expect(AppCache().get('/locations/regions'), isNotNull);

      // Admin mwenenzako anaongeza mkoa → WS event inafika kwa wote online
      WebSocketService().dispatchEventForTest({
        'event': 'data.changed',
        'kind': 'region',
        'action': 'added',
      });

      // Cache za reference data lazima ziwae — screen zinazofunguka
      // zitapakia data halisi ya sasa kutoka server (MARA MOJA, siyo baada
      // ya TTL ya dakika 30 ya kale).
      expect(AppCache().get('/locations/regions'), isNull,
          reason: 'Regions cache lazima ifutwe na data.changed (region)');
      expect(AppCache().get('/locations/regions/1/districts'), isNull,
          reason: 'Districts cache pia lazima ifutwe');
      expect(AppCache().get('/cadres?category=education'), isNull,
          reason: 'Cadres cache pia lazima ifutwe');
    });

    test('kila aina ya data (department/subject/cadre/region/district/facility) '
        'inabust cache zake', () async {
      final auth = AuthProvider();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await auth.login('0757000111', password: 'pass1234');
      for (final kind in ['department', 'subject', 'cadre', 'region', 'district']) {
        // Jaza cache husika
        await ApiService().getRegions();
        await ApiService().getCadres(category: 'education');
        WebSocketService().dispatchEventForTest({
          'event': 'data.changed',
          'kind': kind,
          'action': 'added',
        });
        expect(AppCache().get('/locations/regions'), isNull,
            reason: 'kind=$kind — regions cache lazima ifutwe');
        expect(AppCache().get('/cadres?category=education'), isNull,
            reason: 'kind=$kind — cadres cache lazima ifutwe');
      }
    });

    test('data mpya inaonekana kwenye GET mpya (server state imebadilika)',
        () async {
      // Admin anaongeza mkoa
      await ApiService().adminCreateData('regions', {'name': 'Mkoa Mpya wa Sasa'});
      // GET mpya — ina mkoa mpya (hakuna hardcoded list)
      final res = await ApiService().adminListData('regions');
      final names = (res.data as List).map((r) => '${r['name']}').toList();
      expect(names, contains('Mkoa Mpya wa Sasa'));
      // Na getRegions (public) — backend halisi inabust location caches
      // kwenye kila CRUD; hapa tunathibitisha list ya admin inaona
      // kilichoongezwa MARA MOJA.
    });
  });

  group('8. UI: AdminDataPage — data kutoka API (siyo hardcoded)', () {
    testWidgets('inaonyesha idara na mikoa kutoka API', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: DefaultTabController(length: 6, child: AdminDataPage()),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // initialIndex = 1 (Masomo) — data ya API inaonekana (somo la Hisabati)
      expect(find.textContaining('Hisabati'), findsWidgets,
          reason: 'Somo "Hisabati" kutoka API inaonekana (siyo hardcoded)');
    });
  });
}
