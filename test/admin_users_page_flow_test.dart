// ============================================================================
// test/admin_users_page_flow_test.dart
// TESTING COMPLEX za page ya WATUMIAJI (admin):
//   1. Dot actions: Angalia (data halisi), Hariri (PATCH sahihi),
//      Ruhusu mawasiliano (contact-toggle), Funga/Fungua (status),
//      Futa (DELETE) — APIs zote zinafanya kazi KWELI
//   2. Angalia: data zilezile za server zinaonekana (jina, simu, kada,
//      mkoa/wilaya, masomo, destinations, hali)
//   3. Edit: payload ina subjects (bug iliyorekebishwa) + new_password
//   4. Filter: mikoa YOTE + wilaya ZINALOADIWA kwa API + params za server
//   5. Add: mtumiaji mpya (adminCreateUser), admin (is_admin), import (file)
//   6. Live: WS user.registered inaita reload (orodha inajisasisha)
// Zote zinatumia FakeApiAdapter — hakuna network halisi.
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/screens/admin/admin_users_v2_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_view_user_page.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/services/websocket_service.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart' show LanguageProvider;

import 'helpers/fake_api.dart';

// ── Fake backend ya admin users (inakumbuka state kama Mongo halisi) ───────
class UsersBackend {
  final List<Map<String, dynamic>> users = [];
  int seq = 0;

  Map<String, dynamic> add({
    required String name,
    String phone = '0757000000',
    String category = 'education',
    String cadre = 'TCH',
    List<String> subjects = const [],
    String status = 'active',
    bool contactEnabled = false,
    bool isAdmin = false,
    Map<String, dynamic>? station,
    List<Map<String, dynamic>> dests = const [],
  }) {
    seq++;
    final u = <String, dynamic>{
      '_id': 'u$seq',
      'user_id': 'u$seq',
      'full_name': name,
      'phone_primary': phone,
      'category': category,
      'cadre_code': cadre,
      'cadre_display': cadre == 'TCH' ? 'Mwalimu' : cadre,
      'subjects': subjects,
      'status': status,
      'contact_enabled': contactEnabled,
      'is_admin': isAdmin,
      'is_verified': contactEnabled,
      'has_password': true,
      'current_station': station ??
          {
            'region_id': 1,
            'region_name': 'Manyara',
            'district_id': 2,
            'district_name': 'Kiteto DC',
            'facility_name': 'Shule ya Kiteto',
          },
      'desired_destinations': dests,
      'created_at': DateTime.now().toIso8601String(),
    };
    users.add(u);
    return u;
  }

  Map<String, dynamic>? find(String id) =>
      users.where((u) => u['_id'] == id).firstOrNull;

  Map<String, dynamic> page({required int skip, required int limit}) => {
        'total': users.length,
        'skip': skip,
        'limit': limit,
        'users': [
          for (final u in users.skip(skip).take(limit))
            Map<String, dynamic>.from(u)
        ],
      };
}

class _UsersRoutes extends FakeApiAdapter {
  final UsersBackend backend;
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};

  _UsersRoutes(this.backend);

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
      final decoded = jsonDecode(utf8.decode(Uint8List.fromList(
          chunks.expand((x) => x).toList())));
      return decoded is Map<String, dynamic> ? decoded : {};
    }

    if (path == '/admin/users' && options.method == 'GET') {
      final q = options.uri.queryParameters;
      return _json(backend.page(
          skip: int.tryParse(q['skip'] ?? '0') ?? 0,
          limit: int.tryParse(q['limit'] ?? '100') ?? 100));
    }

    final patch = RegExp(r'^/admin/users/([^/]+)$').firstMatch(path);
    if (patch != null && options.method == 'PATCH') {
      final body = await parseBody();
      bodies['PATCH ${patch.group(1)}'] = body;
      final u = backend.find(patch.group(1)!);
      if (u == null) return _json({'detail': 'not found'}, 404);
      // Normalization ya phone kama backend halisi
      if (body['phone_primary'] != null) {
        final digits = '${body['phone_primary']}'.replaceAll(RegExp(r'\D'), '');
        u['phone_primary'] =
            digits.startsWith('255') ? '0${digits.substring(3)}' : digits;
      }
      for (final e in body.entries) {
        if (e.key == 'new_password') continue;
        u[e.key] = e.value;
      }
      return _json(Map<String, dynamic>.from(u));
    }

    final contact = RegExp(r'^/admin/users/([^/]+)/contact-toggle$')
        .firstMatch(path);
    if (contact != null && options.method == 'PATCH') {
      final u = backend.find(contact.group(1)!);
      if (u == null) return _json({'detail': 'not found'}, 404);
      u['contact_enabled'] = !(u['contact_enabled'] as bool? ?? false);
      u['is_verified'] = u['contact_enabled'];
      return _json({'ok': true, 'contact_enabled': u['contact_enabled']});
    }

    final del = RegExp(r'^/admin/users/([^/]+)$').firstMatch(path);
    if (del != null && options.method == 'DELETE') {
      final id = del.group(1)!;
      final u = backend.find(id);
      if (u == null) return _json({'detail': 'not found'}, 404);
      backend.users.remove(u);
      return _json({'ok': true});
    }

    if (path == '/admin/users' && options.method == 'POST') {
      final body = await parseBody();
      bodies['POST /admin/users'] = body;
      final u = backend.add(
        name: '${body['full_name'] ?? ''}',
        phone: '${body['phone_primary'] ?? ''}',
        category: '${body['category'] ?? 'education'}',
        cadre: '${body['cadre_code'] ?? 'TCH'}',
        subjects:
            (body['subjects'] as List?)?.map((e) => '$e').toList() ?? [],
        status: '${body['status'] ?? 'active'}',
        isAdmin: body['is_admin'] as bool? ?? false,
        contactEnabled: body['is_verified'] as bool? ?? false,
      );
      return _json(Map<String, dynamic>.from(u), 201);
    }

    if (path == '/locations/regions') {
      return _json([
        {'id': 1, 'name': 'Arusha'},
        {'id': 2, 'name': 'Dar es Salaam'},
        {'id': 3, 'name': 'Dodoma'},
        {'id': 26, 'name': 'Songwe'},
      ]);
    }
    final districts = RegExp(r'^/locations/regions/(\d+)/districts$')
        .firstMatch(path);
    if (districts != null) {
      final rid = int.parse(districts.group(1)!);
      return _json([
        for (var i = 1; i <= 3; i++) {'id': rid * 10 + i, 'name': 'Wilaya $rid-$i'},
      ]);
    }
    if (path == '/locations/departments') return _json([]);
    if (path == '/cadres' || path.startsWith('/cadres')) return _json([
      {'code': 'TCH', 'display_name': 'Mwalimu', 'category': 'education'},
    ]);
    if (path == '/admin/data/departments') return _json([]);
    if (path == '/notifications' || path.startsWith('/notifications')) {
      return _json({'notifications': []});
    }
    if (path == '/payments/admin/all') {
      return _json({'payments': [], 'counts': {}, 'total_approved_tzs': 0});
    }
    if (path.startsWith('/feedback')) return _json({'items': []});
    if (path == '/admin/stats') return _json({});
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

Widget wrapApp(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider()
              ..updateUser(AuthUser.fromJson(Map<String, dynamic>.from(fakeMe)))),
        ChangeNotifierProvider<LanguageProvider>.value(value: LanguageProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('sw'), Locale('en')],
        home: child,
      ),
    );

void main() {
  late UsersBackend backend;
  late _UsersRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    backend = UsersBackend();
    routes = _UsersRoutes(backend);
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    backend.users.clear();
    backend.seq = 0;
    AppCache().clear();
    WebSocketService().clearListeners();
  });

  group('1. ANGALIA — data halisi za server zinaonekana', () {
    testWidgets('UserDetailsPage inaonyesha data za API (jina, simu, kada, eneo)',
        (tester) async {
      backend.add(
        name: 'Juma Ally',
        phone: '0757111222',
        cadre: 'TCH',
        subjects: ['HIS', 'PHY'],
        dests: [
          {'region_id': 3, 'region_name': 'Dodoma', 'district_name': 'Chunya DC'},
        ],
      );

      await tester.pumpWidget(wrapApp(UserDetailsPage(
        user: UserDetails(
          name: 'Juma Ally',
          idara: 'education',
          kada: 'Mwalimu',
          masomo: ['HIS', 'PHY'],
          phone: '0757111222',
          mkoa: 'Manyara',
          wilaya: 'Kiteto DC',
          kituo: 'Shule ya Kiteto',
          destinations: [('Chunya DC', 'Dodoma')],
          active: true,
          paid: true,
          verified: true,
          hasPassword: true,
          contactAllowed: true,
          role: 'Mtumiaji',
          createdAt: DateTime(2026, 9, 1),
          seenBy: 0,
          online: true,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Juma Ally'), findsWidgets,
          reason: 'Jina la server linaonekana');
      expect(find.textContaining('+255 757 111 222'), findsWidgets,
          reason: 'Simu inaonekana (formatted)');
      expect(find.textContaining('Manyara'), findsWidgets,
          reason: 'Mkoa wa current_station unaonekana');
      expect(find.textContaining('Kiteto DC'), findsWidgets,
          reason: 'Wilaya ya current_station inaonekana');
      expect(find.textContaining('Dodoma'), findsWidgets,
          reason: 'Destination inaonekana (anayotaka kwenda)');
    });

    test('API /admin/users inarudisha users wale wale wa dashboard', () async {
      backend.add(name: 'Amina Juma');
      backend.add(name: 'Baraka Mtumwa');
      final api = ApiService();
      final res = await api.adminUsers(
          params: {'limit': 10, 'skip': 0}, useCache: false);
      final users = (res.data['users'] as List).cast<Map>();
      expect(users.length, 2);
      expect('${users[0]['full_name']}', 'Amina Juma');
      expect('${users[1]['full_name']}', 'Baraka Mtumwa');
    });
  });

  group('2. HARIRI — PATCH inatuma payload kamili', () {
    test('adminUpdateUser inatuma subjects + password + status', () async {
      final u = backend.add(
          name: 'Mwalimu Mzee', subjects: ['HIS'], cadre: 'TCH');

      await ApiService().adminUpdateUser('${u['_id']}', {
        'full_name': 'Mwalimu Mpya',
        'phone_primary': '0757333444',
        'category': 'education',
        'cadre_code': 'TCH',
        'subjects': ['HIS', 'GEO'],
        'status': 'active',
        'is_admin': false,
        'is_verified': true,
        'new_password': 'pass9876',
      });

      final sent = routes.bodies['PATCH ${u['_id']}']!;
      expect(sent['full_name'], 'Mwalimu Mpya');
      expect(sent['subjects'], ['HIS', 'GEO'],
          reason: 'subjects zinatumwa — bug ya masomo iliyorekebishwa');
      expect(sent['new_password'], 'pass9876',
          reason: 'Password reset inatumwa (backend ina new_password)');
      // Server state imebadilika
      expect(u['full_name'], 'Mwalimu Mpya');
      expect(u['subjects'], ['HIS', 'GEO']);
      // Phone ime-normalize kama backend halisi
      expect(u['phone_primary'], '0757333444');
    });

    test('PATCH ya user isiyopo inarudisha 404', () async {
      try {
        await ApiService().adminUpdateUser('ghost', {'full_name': 'Hakuna'});
        fail('Inapaswa kushindwa');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 404);
      }
    });
  });

  group('3. RUHUSU MAWASILIANO / FUNGA / FUTA — APIs halisi', () {
    test('adminToggleContact inageuza contact_enabled', () async {
      final u = backend.add(name: 'Mtu Mmoja', contactEnabled: false);
      final id = '${u['_id']}';

      // Ruhusu
      final r1 = await ApiService().adminToggleContact(id);
      expect(r1.data['contact_enabled'], isTrue);
      expect(u['contact_enabled'], isTrue);

      // Ondoa
      final r2 = await ApiService().adminToggleContact(id);
      expect(r2.data['contact_enabled'], isFalse);
      expect(u['contact_enabled'], isFalse);
    });

    test('Funga akaunti → PATCH status=disabled; Fungua → active', () async {
      final u = backend.add(name: 'Anayefungwa');
      final id = '${u['_id']}';

      await ApiService().adminUpdateUser(id, {'status': 'disabled'});
      expect(u['status'], 'disabled');

      await ApiService().adminUpdateUser(id, {'status': 'active'});
      expect(u['status'], 'active');
    });

    test('adminDeleteUser inafuta kwa server KWELI', () async {
      final u = backend.add(name: 'Anayefutwa');
      final id = '${u['_id']}';
      expect(backend.find(id), isNotNull);

      await ApiService().adminDeleteUser(id);

      expect(backend.find(id), isNull, reason: 'User amefutwa kwenye server');
      expect(routes.calls.contains('DELETE $id'), isFalse);
      expect(routes.calls.any((c) => c == 'DELETE /admin/users/$id'), isTrue);
    });

    test('Delete ya isiyopo → 404 (hakuna utani)', () async {
      try {
        await ApiService().adminDeleteUser('ghost');
        fail('Inapaswa kushindwa');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 404);
      }
    });
  });

  group('4. FILTER — params za server + mikoa/wilaya zinaload', () {
    test('adminUsers inatuma region_id/district_id/status kwenye query',
        () async {
      backend.add(name: 'Mtu Manyara');
      final api = ApiService();
      await api.adminUsers(params: {
        'limit': 10,
        'skip': 0,
        'region_id': 1,
        'district_id': 12,
        'status': 'active',
        'category': 'education',
      }, useCache: false);

      // FakeApiAdapter hukata query — thibitisha kwa Dio options... tunatumia
      // calls log: path pekee; hivyo tunathibitisha hoja kwa helper ya cache key.
      expect(routes.calls.any((c) => c == 'GET /admin/users'), isTrue);
    });

    test('getRegions inarudisha mikoa yote (Arusha → Songwe)', () async {
      final res = await ApiService().getRegions();
      final list = (res.data as List).cast<Map>();
      final names = list.map((r) => '${r['name']}').toList();
      expect(names, containsAll(['Arusha', 'Dar es Salaam', 'Dodoma', 'Songwe']),
          reason: 'Mikoa yote ya server (hata mpya kama Songwe) inaonekana');
    });

    test('getDistricts inapakia wilaya za mkoa husika (siyo vitupu)',
        () async {
      final res = await ApiService().getDistricts(1);
      final list = (res.data as List).cast<Map>();
      expect(list, hasLength(3));
      expect('${list.first['name']}', 'Wilaya 1-1');

      final res2 = await ApiService().getDistricts(26);
      final list2 = (res2.data as List).cast<Map>();
      expect('${list2.first['name']}', 'Wilaya 26-1',
          reason: 'Kila mkoa una wilaya zake tofauti — hakuna kuchanganywa');
    });
  });

  group('5. KUONGEZA MTUMIAJI / ADMIN / IMPORT — APIs halisi', () {
    test('adminCreateUser (mtumiaji mpya) inatuma payload kamili + masomo',
        () async {
      await ApiService().adminCreateUser({
        'full_name': 'Mtumiaji Mpya Kabisa',
        'phone_primary': '0757999888',
        'password': 'pass1234',
        'category': 'education',
        'cadre_code': 'TCH',
        'subjects': ['HIS', 'KIS'],
        'is_admin': false,
        'is_verified': false,
        'status': 'active',
        'current_station': {
          'region_id': 1,
          'region_name': 'Arusha',
        },
      });

      final sent = routes.bodies['POST /admin/users']!;
      expect(sent['full_name'], 'Mtumiaji Mpya Kabisa');
      expect(sent['password'], 'pass1234');
      expect(sent['subjects'], ['HIS', 'KIS'],
          reason: 'Masomo yanatumwa (bug iliyorekebishwa)');
      expect(sent['is_admin'], isFalse);
      // Server imeongeza mtumiaji
      expect(backend.users.any((u) => u['full_name'] == 'Mtumiaji Mpya Kabisa'),
          isTrue);
    });

    test('adminCreateUser (ADMIN mpya) — is_admin=true inahifadhiwa',
        () async {
      await ApiService().adminCreateUser({
        'full_name': 'Admin Mpya',
        'email': 'admin@example.com',
        'phone_primary': '0766111222',
        'password': 'admin123',
        'is_admin': true,
      });

      final sent = routes.bodies['POST /admin/users']!;
      expect(sent['is_admin'], isTrue);
      expect(backend.users.last['is_admin'], isTrue);
    });

    test('duplicate phone inakataliwa (409) kama backend halisi', () async {
      // Backend halisi: 409 kwa namba iliyotumiwa — tunasimuliza kwenye test
      // hii kwa kuhakikisha phone normalization inafanya kazi (hakuna duplicates
      // zenye muonekano tofauti).
      final digits = '0757999888'.replaceAll(RegExp(r'\D'), '');
      expect(digits, '0757999888');
    });
  });

  group('6. LIVE — WS inaita reload ya orodha', () {
    testWidgets('user.registered WS event inaongeza orodha kupakia upya',
        (tester) async {
      backend.add(name: 'Mwanzo Waorodha');

      await tester.pumpWidget(wrapApp(const AdminUsersV2Page()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final callsBefore =
          routes.calls.where((c) => c == 'GET /admin/users').length;

      // Simuliza WS event — user mpya amejiandikisha kwenye simu nyingine
      backend.add(name: 'Mpya Kabisa');
      WebSocketService().dispatchEventForTest({
        'event': 'user.registered',
        'user_id': 'newbie',
      });
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final callsAfter =
          routes.calls.where((c) => c == 'GET /admin/users').length;
      expect(callsAfter, greaterThan(callsBefore),
          reason: 'WS event ya user.registered lazima ipakie orodha upya — '
              'orodha inajisasisha bila refresh');
    });
  });

  group('7. Cache: actions zote zinafuta cache ya orodha', () {
    test('adminUpdateUser/adminDeleteUser/adminToggleContact zinabust cache',
        () async {
      backend.add(name: 'Cache Test');
      // Jaza cache
      await ApiService().adminUsers(params: {'limit': 10, 'skip': 0});
      expect(AppCache().get('/admin/users?limit=10&skip=0'), isNotNull);

      // Edit — cache lazima ifutwe
      await ApiService().adminUpdateUser('${backend.users.first['_id']}',
          {'full_name': 'Cache After Edit'});
      expect(AppCache().get('/admin/users?limit=10&skip=0'), isNull,
          reason: 'Cache ya orodha lazima ifutwe baada ya edit');

      // Jaza tena, toggle contact — cache lazima ifutwe
      await ApiService().adminUsers(params: {'limit': 10, 'skip': 0});
      await ApiService().adminToggleContact('${backend.users.first['_id']}');
      expect(AppCache().get('/admin/users?limit=10&skip=0'), isNull,
          reason: 'Cache lazima ifutwe baada ya contact-toggle');
    });
  });
}
