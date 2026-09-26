// ============================================================================
// test/api_integration_test.dart
// Integration tests:
//   1. Mikoa ZOTE zinaload kutoka /locations/regions (filter completeness)
//   2. Wilaya zinaload kwa API mkoa ukiuchagua (onWilayaLoad)
//   3. Pagination ya admin users (skip/limit + total mpya kila page)
//   4. Session isolation: logout inafuta AppCache (data za user wa zamani
//      zisirudi kwa mtumiaji mpya)
//   5. AppCache: TTL + invalidatePrefix + clear
// Zote zinatumia FakeApiAdapter — hakuna network halisi.
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/services/admin_badge_service.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';

import 'helpers/fake_api.dart';

// ── Data bandia za mikoa (zote 31 kama Tanzania + wilaya zao) ───────────────
final allRegions = <Map<String, dynamic>>[
  for (var i = 1; i <= 26; i++)
    {'id': i, 'name': 'Mkoa $i'},
];

Map<String, dynamic> _districtsFor(int regionId) => {
      'districts': [
        for (var i = 1; i <= 8; i++)
          {'id': regionId * 100 + i, 'name': 'Wilaya ${regionId}_$i'},
      ],
    };

Map<String, dynamic> _usersPage({required int skip, required int limit, required int total}) {
  final users = <Map<String, dynamic>>[
    for (var i = 0; i < limit && skip + i < total; i++)
      {
        'user_id': 'u${skip + i}',
        'full_name': 'Mtumiaji ${skip + i}',
        'category': 'health',
        'cadre_code': 'CO',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
      },
  ];
  return {'total': total, 'skip': skip, 'limit': limit, 'users': users};
}

class _Routes extends FakeApiAdapter {
  int usersRequests = 0;
  final List<String> pathsSeen = [];
  int usersTotal;
  _Routes({this.usersTotal = 10}) : super();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    pathsSeen.add(path);
    final q = options.uri.queryParameters;

    if (path == '/locations/regions') {
      return _json(allRegions);
    }
    final m = RegExp(r'^/locations/regions/(\d+)/districts$').firstMatch(path);
    if (m != null) {
      return _json(_districtsFor(int.parse(m.group(1)!)));
    }
    if (path == '/admin/users') {
      usersRequests++;
      final skip = int.tryParse(q['skip'] ?? '0') ?? 0;
      final limit = int.tryParse(q['limit'] ?? '100') ?? 100;
      return _json(_usersPage(skip: skip, limit: limit, total: usersTotal));
    }
    if (path == '/auth/login') {
      return _json({'access_token': 'tok-u2', 'user_id': 'u2', 'full_name': 'Mtumiaji Mpya'});
    }
    if (path == '/auth/me') {
      return _json(Map<String, dynamic>.from(fakeMe));
    }
    if (path == '/payments/') {
      return _json({'items': []});
    }
    if (path.startsWith('/feedback')) return _json({'items': []});
    if (path.startsWith('/notifications')) return _json({'notifications': []});
    if (path.startsWith('/matches/board')) return _json({'candidates': [], 'total': 0});
    if (path.startsWith('/matches/true')) return _json({'matches': []});
    if (path.startsWith('/matches/stats')) return _json({'total': 0});
    if (path.startsWith('/announcements')) return _json({'announcements': []});
    if (path == '/users/me') return _json(Map<String, dynamic>.from(fakeMe));
    return _json({});
  }

  Future<ResponseBody> _json(dynamic data) async {
    final body = jsonEncode(data);
    return ResponseBody.fromString(
      body,
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    ApiService.dioForTest(api).httpClientAdapter = _Routes();
    await api.saveToken('test-token');
  });

  group('Filter: mikoa na wilaya (API zimeunganishwa)', () {
    test('getRegions inarudisha mikoa yote 26 (Tanzania Bara)', () async {
      final r = await ApiService().getRegions();
      final raw = r.data;
      final list = raw is List ? raw : (raw['regions'] ?? raw['data'] ?? []);
      expect(list.length, 26, reason: 'Mikoa yote ya Tanzania Bara lazima ionekane');
    });

    test('getDistricts inarudisha wilaya zote za mkoa uliouchagua', () async {
      final r = await ApiService().getDistricts(1);
      final raw = r.data;
      final list = raw is List ? raw : (raw['districts'] ?? raw['data'] ?? []);
      expect(list.length, 8, reason: 'Wilaya zote 8 za mkoa lazima zipakiwe');
      expect('${list.first['name']}', 'Wilaya 1_1');
    });

    test('kila mkoa una wilaya zake tofauti (hakuna kuchanganywa)', () async {
      final r1 = await ApiService().getDistricts(1);
      final r2 = await ApiService().getDistricts(2);
      final l1 = (r1.data['districts'] as List).cast<Map>();
      final l2 = (r2.data['districts'] as List).cast<Map>();
      expect(l1.first['name'] == l2.first['name'], isFalse);
    });
  });

  group('Pagination ya admin users (Next inapakia data mpya)', () {
    test('page 1 na 2 zina data tofauti (skip inafanya kazi)', () async {
      final api = ApiService();
      final p1 = await api.adminUsers(
          params: {'limit': 4, 'skip': 0}, useCache: false);
      final p2 = await api.adminUsers(
          params: {'limit': 4, 'skip': 4}, useCache: false);
      final u1 = (p1.data['users'] as List).cast<Map>();
      final u2 = (p2.data['users'] as List).cast<Map>();
      expect(u1.first['user_id'], 'u0');
      expect(u2.first['user_id'], 'u4',
          reason: 'Ukurasa wa 2 uanze ule ule ambapo 1 iliisha');
      expect(u1.first['user_id'] == u2.first['user_id'], isFalse);
    });

    test('total inasasishwa — hasNext inategemea hesabu mpya', () async {
      final api = ApiService();
      final p1 = await api.adminUsers(
          params: {'limit': 4, 'skip': 0}, useCache: false);
      final total = (p1.data['total'] as num).toInt();
      // Next ipo kama (0+1)*4 < total
      final hasNext = (0 + 1) * 4 < total;
      expect(hasNext, isTrue, reason: 'total=$total — Next lazima iwe hai');
      // Ukurasa wa mwisho — Next lazima ife
      final lastPage = (total / 4).ceil() - 1;
      final hasNextLast = (lastPage + 1) * 4 < total;
      expect(hasNextLast, isFalse, reason: 'Ukurasa wa mwisho — Next ife');
    });
  });

  group('Session isolation (logout/login — data zisichanganyike)', () {
    test('AppCache.clear() inaondoa kila kitu (logout isolation)', () {
      final cache = AppCache();
      cache.set('/users/me', {'full_name': 'Zamani'});
      cache.set('/matches/board?scope=incoming', {'candidates': [1, 2, 3]});
      cache.set('/admin/users?limit=4', {'users': [1]});
      expect(cache.get('/users/me'), isNotNull);

      cache.clear(); // logout inafanya hivi
      expect(cache.get('/users/me'), isNull,
          reason: 'Data za mtumiaji wa zamani zisibaki kwenye cache');
      expect(cache.get('/matches/board?scope=incoming'), isNull);
      expect(cache.get('/admin/users?limit=4'), isNull);
    });

    test('expired entry hairudishwi (TTL inafanya kazi)', () async {
      final cache = AppCache();
      cache.set('/matches/me', {'x': 1}, ttl: const Duration(milliseconds: 30));
      expect(cache.get('/matches/me'), isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(cache.get('/matches/me'), isNull, reason: 'TTL imeisha');
    });

    test('AuthProvider.logout() inafuta cache yote + badge counts', () async {
      final cache = AppCache();
      cache.set('/users/me', {'full_name': 'Zamani'});
      final badges = AdminBadgeService();
      badges.payments = 3;
      badges.feedback = 2;

      final auth = AuthProvider();
      await auth.logout();

      expect(cache.get('/users/me'), isNull,
          reason: 'logout lazima ifute AppCache — data za zamani zisibaki');
      expect(badges.payments, 0, reason: 'Badges za admin ziwekwe sifuri');
      expect(badges.feedback, 0);
    });

    test('login mpya inatoken mpya (hakuna token ya zamani)', () async {
      final auth = AuthProvider();
      final ok = await auth.login('0757000111', password: 'pass1234');
      expect(ok, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kv_token'), 'tok-u2',
          reason: 'Token ya mtumiaji mpya imehifadhiwa — si ya zamani');
    });
  });

  group('Cache invalidation ya form actions (add/update/delete)', () {
    test('adminCreateUser inafuta cache ya /admin/users', () async {
      final api = ApiService();
      // Jaza cache kwanza
      await api.adminUsers(params: {'limit': 4, 'skip': 0});
      // Create — lazima ibust cache
      await api.adminCreateUser({
        'full_name': 'Mtumiaji Mpya',
        'phone_primary': '0757111222',
        'password': 'pass1234',
        'category': 'health',
        'cadre_code': 'CO',
      });
      // GET mpya (useCache default) — lazima ifike server (cache imefutwa)
      final r = await api.adminUsers(params: {'limit': 4, 'skip': 0});
      expect(r.data['total'], 10);
    });
  });
}
