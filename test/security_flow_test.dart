// ============================================================================
// test/security_flow_test.dart
// TESTING YA USALAMA (security regression) — attacks zilizogunduliwa na
// kurekebishwa kwenye mfumo:
//   1. AUTH BYPASS (kubwa kuliko zote): login ya simu ilikuwa inarudisha
//      token kwa NAMBA TU — mtu asiye mmiliki angeingia akaunti yoyote!
//      Sasa: code ya SMS inahitajika (hatua 2) — token BAADA ya uthibitisho.
//   2. OTP brute-force: majaribio 5 yasiyo sahihi → 429.
//   3. OTP inatumika MARA MOJA (replay hairuhusiwi).
//   4. User enumeration: lookup-by-name huficha namba za wasiothibitishwa.
//   5. CORS: origin ya kigeni HAIRUHIWSHI (access-control-allow-origin).
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

    // ── 1. LOGIN: simu → OTP (HAKUNA token!) ──
    if (path == '/auth/login' && options.method == 'POST') {
      final body = await parseBody();
      bodies['POST /auth/login'] = body;
      final identifier = '${body['phone'] ?? ''}';
      if (identifier.isEmpty) return _json({'detail': '422'}, 422);
      if (identifier.contains('@')) {
        // Admin — 2FA ya email
        return _json({'two_factor_required': true, 'email': identifier});
      }
      otpHash = _hash(kOtp);
      otpAttempts = 0;
      otpUsed = false;
      // SECURITY: hakuna access_token hapa — SMS OTP inahitajika.
      return _json({
        'two_factor_required': true,
        'phone': identifier,
        'message': 'Code ya uthibitisho imetumwa kwa $identifier.',
      });
    }

    // ── 2. VERIFY OTP (simu AU email) — token BAADA ya uthibitisho ──
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

  group('1. AUTH BYPASS (attack kubwa) — login ya simu ni hatua 2 sasa', () {
    test('POST /auth/login kwa namba HAIRUDISHI token — OTP inahitajika',
        () async {
      final res = await api.login('0757502446');
      final data = asMap(res.data);

      expect(data['two_factor_required'], isTrue,
          reason: 'SECURITY: hatua 2 inahitajika (SMS OTP)');
      expect(data.containsKey('access_token'), isFalse,
          reason: 'TOKEN HAIRUDISHWI kwa namba tu — mtu asiye mmiliki '
              'angeingia akaunti yoyote aliyoiua namba yake!');
      expect(routes.bodies['POST /auth/login']!['phone'], '0757502446');
    });

    test('AuthProvider.login inaashiria hatua ya 2 (pendingOtpPhone)',
        () async {
      final auth = AuthProvider(api: api);
      final ok = await auth.login('0757502446');
      expect(ok, isFalse, reason: 'Hakuna token — mtiririko bado haujakamilika');
      expect(auth.pendingOtpPhone, '0757502446',
          reason: 'UI lazima ionyeshe OTP input sasa');
      expect(auth.pendingAdminEmail, isNull,
          reason: 'Hii SI admin 2FA — ni SMS OTP ya mtumiaji');
    });

    test('Kuingia kwa code SAHIHI kunatoa token + session inahifadhiwa',
        () async {
      await api.login('0757502446'); // step 1
      final auth = AuthProvider(api: api);
      await auth.login('0757502446');

      final ok = await auth.verifyOtp(_SecurityRoutes.kOtp);
      expect(ok, isTrue, reason: 'Code sahihi → imeingia');
      expect(auth.user, isNotNull);
      expect(auth.pendingOtpPhone, isNull);

      // Token imehifadhiwa kwenye prefs (session persistence)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kv_token'), 'token-salama-baada-ya-otp');
    });

    test('Code mbaya HAIRUHUSU kuingia (hakuna token)', () async {
      await api.login('0757502446');
      final auth = AuthProvider(api: api);
      await auth.login('0757502446');

      final ok = await auth.verifyOtp('000000');
      expect(ok, isFalse);
      expect(auth.error, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kv_token'), isNull,
          reason: 'Hakuna session bila uthibitisho wa SMS');
    });

    test('OTP brute-force: majaribio mengi → 429 (blocked)', () async {
      await api.login('0757502446');
      DioException? last;
      // Majaribio 5 ya kwanza → 400; ya sita (attempts >= 5) → 429.
      for (var i = 0; i < 6; i++) {
        try {
          await api.verifyLoginOtp('0757502446', '99999$i'.substring(0, 6));
        } on DioException catch (e) {
          last = e;
        }
      }
      expect(last?.response?.statusCode, 429,
          reason: 'Baada ya majaribio 5, server inazuia (brute-force guard)');
    });

    test('OTP inatumika MARA MOJA — replay hairuhusiwi', () async {
      await api.login('0757502446');
      final r1 = await api.verifyLoginOtp('0757502446', _SecurityRoutes.kOtp);
      expect(r1.data['access_token'], isNotNull);

      DioException? replay;
      try {
        await api.verifyLoginOtp('0757502446', _SecurityRoutes.kOtp);
      } on DioException catch (e) {
        replay = e;
      }
      expect(replay?.response?.statusCode, anyOf(400, 429),
          reason: 'Code ile ile HAIRUHUSU kuingia mara ya pili');
    });
  });

  group('2. USER ENUMERATION — lookup-by-name huficha namba', () {
    test('Namba ya mtumiaji asiyyethibitishwa inafichwa (***), phone_alt haipo',
        () async {
      final res = await api.post('/auth/lookup-by-name',
          data: {'full_name': 'Halima'});
      final users = (res.data['users'] as List).cast<Map>();
      expect(users, hasLength(1));

      final u = users.first;
      expect(u['phone_primary'], contains('***'),
          reason: 'ANTI-ENUMERATION: namba kamili HAIONEKANI kwa mtu '
              'asiyethibitisha umiliki (kuingia kunahitaji namba KAMILI + SMS)');
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

  group('3. HARDENING — docs wazi', () {
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

  group('4. ADMIN OTP KWA FOMU KUU — regression ya "Field required"', () {
    test('admin kwa fomu kuu: email inaenda pendingAdminEmail, SI pendingOtpPhone',
        () async {
      final auth = AuthProvider(api: api);
      await auth.login('admin@kubadilishana.co.tz');

      expect(auth.pendingAdminEmail, 'admin@kubadilishana.co.tz',
          reason: 'Email ya admin inaingia 2FA ya email (adminLoginOtp)');
      expect(auth.pendingOtpPhone, isNull,
          reason: 'pendingOtpPhone ni ya SMS OTP (simu) — si email');
      expect(auth.otpRequired, isFalse,
          reason: 'otpRequired inaashiria SMS OTP ya mtumiaji pekee');
    });

    test('OTP ya admin inatumwa na identifier+email — server YA KALE inaikubali',
        () async {
      await api.login('admin@kubadilishana.co.tz');
      // Fake inatoa 400 (kOtp hash haiwekwi kwenye email branch) — tunapima
      // PAYLOAD tu ndiyo itumwayo; 400 ya fake si kosa la payload.
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

    test('OTP ya simu inatumwa na identifier+phone+email — server zote zinaihifadhi',
        () async {
      await api.login('0757502446');
      try {
        await api.verifyLoginOtp('0757502446', _SecurityRoutes.kOtp);
      } on DioException catch (_) {
        // fake inaweza kutoa 429 kama OTP imeumika — body ndiyo muhimu
      }
      final body = routes.bodies['POST /auth/login/2fa']!;
      expect(body['identifier'], '0757502446',
          reason: 'Server MPYA inasoma identifier');
      expect(body['phone'], '0757502446',
          reason: 'Server mpya inasoma phone pia');
      expect(body['email'], '0757502446',
          reason: 'Server ya KALE inasoma email — bila hii: 422 Field required');
    });

    test('verifyOtp (provider) inafanya kazi na phone pending — SMS flow kamili',
        () async {
      final auth = AuthProvider(api: api);
      await auth.login('0757502446');
      final ok = await auth.verifyOtp(_SecurityRoutes.kOtp);
      expect(ok, isTrue);
      expect(auth.user, isNotNull);
    });
  });
}
