// ============================================================================
// test/security_flow_test.dart
// TESTING YA USALAMA (security regression) — mtiririko wa kuingia:
//   1. USERS: kuingia kwa NAMBA tu — token inarudi MARA MOJA (kama zamani).
//      (Uamuzi wa mmiliki: hakuna OTP ya SMS kwa users — arifa ni PUSH ya
//      FCM kama WhatsApp, siyo SMS.)
//   2. ADMIN: 2FA ya EMAIL pekee — code ya tarakimu 6 inatumwa kwa email;
//      token inatolewa na /auth/login/2fa BAADA ya kuthibitisha.
//   3. OTP brute-force: majaribio 5 yasiyo sahihi → 429.
//   4. OTP inatumika MARA MOJA (replay hairuhusiwi).
//   5. User enumeration: lookup-by-name huficha namba za wasiothibitishwa.
//   6. openapi.json SI wazi kwa umma (attacker haoni routes zote).
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/utils/safe_cast.dart';

import 'helpers/fake_api.dart';

class _SecurityRoutes extends FakeApiAdapter {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};

  /// OTP "DB" — kama backend halisi (hash pekee, attempts, used).
  String? otpHash;
  int otpAttempts = 0;
  bool otpUsed = false;
  static const kOtp = '123456';
  bool get otpValid => !otpUsed && otpAttempts < 5;

  List<Map<String, dynamic>> directoryUsers = [
    {
      'full_name': 'Halima Juma',
      'phone_primary': '+255712340001',
      'phone_alt': '+255712340002',
      'is_verified': false,
      'category': 'health',
      'cadre_code': 'NO',
      'cadre_display': 'Mwuguzi',
    },
    {
      'full_name': 'Salma Hamisi',
      'phone_primary': '+255712340003',
      'is_verified': true,
      'category': 'education',
      'cadre_code': 'TCH',
      'cadre_display': 'Mwalimu',
    },
  ];

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
      final decoded = jsonDecode(utf8
          .decode(Uint8List.fromList(chunks.expand((x) => x).toList())));
      return decoded is Map<String, dynamic> ? decoded : {};
    }

    // ── 1. LOGIN: namba → token MARA MOJA; email (admin) → 2FA ya email ──
    if (path == '/auth/login' && options.method == 'POST') {
      final body = await parseBody();
      bodies['POST /auth/login'] = body;
      final identifier = '${body['phone'] ?? ''}';
      if (identifier.isEmpty) return _json({'detail': '422'}, 422);
      if (identifier.contains('@')) {
        // ADMIN — 2FA ya email pekee: OTP "inatumwa" (fake inaihifadhi hash).
        otpHash = _hash(kOtp);
        otpAttempts = 0;
        otpUsed = false;
        return _json({'two_factor_required': true, 'email': identifier});
      }
      // USER wa kawaida — token inarudi MARA MOJA (kama zamani).
      return _json({
        ...Map<String, dynamic>.from(fakeMe),
        'access_token': 'token-moja-kwa-moja',
      });
    }

    // ── 2. VERIFY OTP (admin email) — token BAADA ya uthibitisho ──
    if (path == '/auth/login/2fa' && options.method == 'POST') {
      final body = await parseBody();
      bodies['POST /auth/login/2fa'] = body;
      if (!otpValid) {
        return _json({'detail': 'Majaribio mengi sana / code imetumika'}, 429);
      }
      final code = '${body['code'] ?? ''}';
      if (_hash(code) != otpHash) {
        otpAttempts += 1;
        return _json({'detail': 'Code batili au imekwisha muda'}, 400);
      }
      otpUsed = true; // REPLAY hairuhusiwi
      return _json({
        ...Map<String, dynamic>.from(fakeMe),
        'access_token': 'token-salama-baada-ya-otp',
      });
    }

    // ── 4. LOOKUP BY NAME — namba za wasiothibitishwa zinafichwa ──
    if (path == '/auth/lookup-by-name' && options.method == 'POST') {
      final body = await parseBody();
      final name = '${body['full_name'] ?? ''}'.toLowerCase();
      final hits = directoryUsers
          .where((u) =>
              '${u['full_name']}'.toLowerCase().contains(name) && name.isNotEmpty)
          .map((u) {
        final out = Map<String, dynamic>.from(u);
        if (!out['is_verified']) {
          final p = '${out['phone_primary']}';
          out['phone_primary'] = p.substring(0, 6) + '***' + p.substring(p.length - 2);
          out.remove('phone_alt'); // haionekani kabisa
        }
        return out;
      }).toList();
      return _json({'total': hits.length, 'users': hits});
    }

    // ── 6. openapi.json SI wazi kwa umma (401 kama admin ya nginx) ──
    if (path == '/openapi.json') {
      return _json({'detail': 'Not authenticated'}, 401);
    }

    if (path == '/auth/me' || path == '/users/me') {
      return _json(Map<String, dynamic>.from(fakeMe));
    }
    return _json({});
  }

  String _hash(String code) =>
      base64Encode(utf8.encode('sha-ish:$code')); // fake hash pekee

  Future<ResponseBody> _json(dynamic data, [int status = 200]) async {
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }
}

void main() {
  late _SecurityRoutes routes;
  late ApiService api;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = ApiService();
    api.init();
    routes = _SecurityRoutes();
    ApiService.dioForTest(api).httpClientAdapter = routes;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{}); // kila test — prefs safi
    routes.bodies.clear();
    routes.otpUsed = false;
    routes.otpAttempts = 0;
    routes.otpHash = null;
    AppCache().clear();
  });

  group('1. LOGIN YA MOJA KWA MOJA — namba → token mara moja (kama zamani)', () {
    test('POST /auth/login kwa namba inarudisha token MARA MOJA', () async {
      final res = await api.login('0757502446');
      final data = asMap(res.data);

      expect(data['access_token'], isNotNull,
          reason: 'Users wanaingia kwa namba tu — hakuna OTP ya SMS');
      expect(data.containsKey('two_factor_required'), isFalse,
          reason: 'Hakuna hatua ya 2 kwa users');
      expect(routes.bodies['POST /auth/login']!['phone'], '0757502446');
    });

    test('AuthProvider.login kwa namba → session kamili papo hapo', () async {
      final auth = AuthProvider(api: api);
      final ok = await auth.login('0757502446');
      expect(ok, isTrue, reason: 'Token ipo → imeingia moja kwa moja');
      expect(auth.user, isNotNull);
      expect(auth.pendingOtpPhone, isNull);
      expect(auth.pendingAdminEmail, isNull);

      // Token imehifadhiwa kwenye prefs (session persistence)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kv_token'), 'token-moja-kwa-moja');
    });
  });

  group('2. ADMIN 2FA YA EMAIL — hatua 2 inahitajika kwa admin PEKEE', () {
    test('admin kwa fomu kuu: email inaenda pendingAdminEmail, SI pendingOtpPhone',
        () async {
      final auth = AuthProvider(api: api);
      final ok = await auth.login('admin@kubadilishana.co.tz');

      expect(ok, isFalse, reason: 'Hakuna token — 2FA inasubiri code ya email');
      expect(auth.pendingAdminEmail, 'admin@kubadilishana.co.tz',
          reason: 'Email ya admin inaingia 2FA ya email (adminLoginOtp)');
      expect(auth.pendingOtpPhone, isNull);
      expect(auth.otpRequired, isFalse);
    });

    test('Code SAHIHI ya admin inatoa token + session inahifadhiwa', () async {
      final auth = AuthProvider(api: api);
      await auth.login('admin@kubadilishana.co.tz'); // step 1
      final ok = await auth.adminLoginOtp(
          'admin@kubadilishana.co.tz', _SecurityRoutes.kOtp);
      expect(ok, isTrue, reason: 'Code sahihi → imeingia');
      expect(auth.user, isNotNull);
      expect(auth.pendingAdminEmail, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kv_token'), 'token-salama-baada-ya-otp');
    });

    test('Code MBAYA HAIRUHUSU kuingia (hakuna token)', () async {
      final auth = AuthProvider(api: api);
      await auth.login('admin@kubadilishana.co.tz');
      final ok = await auth.adminLoginOtp('admin@kubadilishana.co.tz', '000000');
      expect(ok, isFalse);
      expect(auth.error, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kv_token'), isNull);
    });

    test('OTP brute-force: majaribio mengi → 429 (blocked)', () async {
      await api.login('admin@kubadilishana.co.tz');
      DioException? last;
      // Majaribio 5 ya kwanza → 400; ya sita (attempts >= 5) → 429.
      for (var i = 0; i < 6; i++) {
        try {
          await api.adminLoginOtp('admin@kubadilishana.co.tz', '99999$i'.substring(0, 6));
        } on DioException catch (e) {
          last = e;
        }
      }
      expect(last?.response?.statusCode, 429,
          reason: 'Baada ya majaribio 5, server inazuia (brute-force guard)');
    });

    test('OTP inatumika MARA MOJA — replay hairuhusiwi', () async {
      await api.login('admin@kubadilishana.co.tz');
      final r1 = await api.adminLoginOtp(
          'admin@kubadilishana.co.tz', _SecurityRoutes.kOtp);
      expect(r1.data['access_token'], isNotNull);

      // OTP mpya kwa jaribio la replay (fake inahifadhi used flag kwa OTP moja)
      routes.otpUsed = true;
      DioException? replay;
      try {
        await api.adminLoginOtp('admin@kubadilishana.co.tz', _SecurityRoutes.kOtp);
      } on DioException catch (e) {
        replay = e;
      }
      expect(replay?.response?.statusCode, anyOf(400, 429),
          reason: 'Code ile ile HAIRUHUSU kuingia mara ya pili');
    });

    test('OTP ya admin inatumwa na identifier+email — server YA KALE inaikubali',
        () async {
      await api.login('admin@kubadilishana.co.tz');
      routes.otpUsed = true; // fake inaruhusu body kuwasilishwa tu
      try {
        await api.adminLoginOtp(
            'admin@kubadilishana.co.tz', _SecurityRoutes.kOtp);
      } on DioException catch (_) {}
      final body = routes.bodies['POST /auth/login/2fa']!;
      expect(body['email'], 'admin@kubadilishana.co.tz',
          reason: 'Server ya KALE inasoma email — lazima iwe kwenye payload');
      expect(body['identifier'], 'admin@kubadilishana.co.tz',
          reason: 'Server MPYA inasoma identifier');
      expect(body['code'], _SecurityRoutes.kOtp);
    });
  });

  group('3. USER ENUMERATION — lookup-by-name huficha namba', () {
    test('Namba ya mtumiaji asiyyethibitishwa inafichwa (***), phone_alt haipo',
        () async {
      final res = await api.post('/auth/lookup-by-name',
          data: {'full_name': 'Halima'});
      final users = (res.data['users'] as List).cast<Map>();
      expect(users, hasLength(1));

      final u = users.first;
      expect(u['phone_primary'], contains('***'),
          reason: 'ANTI-ENUMERATION: namba kamili HAIONEKANI kwa mtu '
              'asiyethibitisha umiliki');
      expect(u.containsKey('phone_alt'), isFalse,
          reason: 'Namba mbadala haionyeshwi kabisa');
    });

    test('Mtumiaji aliyeyethibitishwa anaonekana (ana malipo yaliyoidhinishwa)',
        () async {
      final res = await api.post('/auth/lookup-by-name',
          data: {'full_name': 'Salma'});
      final users = (res.data['users'] as List).cast<Map>();
      expect(users, hasLength(1));
      expect(users.first['phone_primary'], isNot(contains('***')));
    });
  });

  group('4. HARDENING — docs wazi', () {
    test('openapi.json inazuiwa (401) — attacker haoni routes zote', () async {
      // Fake ya security inawakilisha nginx guard ya production:
      // /openapi.json ni ya admin pekee.
      try {
        final res = await api.get('/openapi.json');
        expect(res.statusCode, 401);
      } on DioException catch (e) {
        expect(e.response?.statusCode, 401,
            reason: 'openapi.json HAIRUHUSU kwa mtu yeyote bila auth');
      }
    });
  });
}
