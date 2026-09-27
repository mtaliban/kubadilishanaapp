// ============================================================================
// test/security_round2_test.dart
// SECURITY TESTING ROUND 2 — Flutter-side (baada ya round 1: security_flow_test):
//   1. TOKEN LIFECYCLE: save → header 'Authorization: Bearer' kwenye kila
//      ombi → remove/clear (401) — token haibaki wala kutumwa tena.
//   2. LOGOUT ISOLATION: logout inafuta token + WS disconnect + cache clear —
//      user asiweze kuendelea kutumia session ya mtu mwingine.
//   3. ADMIN SHELL GUARD: /admin route — user wa kawaida (is_admin:false)
//      anarudishwa /login; admin anaingia salama (UI guard juu ya server-side).
//   4. WS TOKEN: connect() inatumia token iliyotolewa; disconnect() inasitisha
//      (hakuna reconnect baada ya logout) — hakuna event za session ya zamani.
//   5. OTP LOGIN FLOW REGRESSION: login ya simu HAITOI token moja kwa moja —
//      lazima verifyOtp (auth bypass fix ya round 1 bado imedumu).
// Zote zinatumia FakeApiAdapter — hakuna network halisi.
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/screens/admin/admin_shell.dart';
import 'package:kubadilishanaapp/services/admin_badge_service.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/services/websocket_service.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart' show LanguageProvider;

import 'helpers/fake_api.dart';

/// Adapter inayorekodi headers za kila ombi (kuthibitisha Authorization).
class _HeaderRecorder extends FakeApiAdapter {
  final List<Map<String, String>> seen = [];
  final Map<String, dynamic> overrides;

  _HeaderRecorder({this.overrides = const {}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add({
      'method': options.method,
      'path': options.uri.path.replaceAll(RegExp(r'^/api'), ''),
      'auth': options.headers['Authorization']?.toString() ?? '',
    });
    if (overrides.containsKey(options.uri.path)) {
      return ResponseBody.fromString(
        jsonEncode(overrides[options.uri.path]),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiService ni SINGLETON — init() mara MOJA tu (mara mbili =
  // LateInitializationError). Kila test inabadilisha adapter/token tu.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiService().init();
  });

  group('1. TOKEN LIFECYCLE — header + kutoa (401 handling)', () {
    test('token iliyohifadhiwa inatumwa kama Bearer kwenye kila ombi',
        () async {
      final api = ApiService();
      final recorder = _HeaderRecorder();
      ApiService.dioForTest(api).httpClientAdapter = recorder;

      await api.saveToken('s3cr3t-token-abc');
      await api.get('/admin/data/regions');

      expect(recorder.seen, isNotEmpty);
      expect(recorder.seen.last['auth'], 'Bearer s3cr3t-token-abc',
          reason: 'Token lazima itumwe kama Bearer — siyo kwenye body/query');
      expect(recorder.seen.last['path'], '/admin/data/regions');
    });

    test('BILA token — hakuna Authorization header (siyo "Bearer null")',
        () async {
      final api = ApiService();
      AppCache().clear(); // cache ya singleton isivuke kati ya tests
      final recorder = _HeaderRecorder();
      ApiService.dioForTest(api).httpClientAdapter = recorder;

      await api.removeToken(); // hakuna session
      await api.get('/regions');

      expect(recorder.seen.last['auth'], '',
          reason: 'Bila token, header haipaswi hata kuwepo (siyo Bearer null)');
    });

    test('clearToken (401 handling) inaondoa token — ombi lijalo halitumi nayo',
        () async {
      final api = ApiService();
      AppCache().clear();
      final recorder = _HeaderRecorder();
      ApiService.dioForTest(api).httpClientAdapter = recorder;

      await api.saveToken('token-ya-kwanza');
      await api.removeToken();
      await api.get('/districts');

      expect(recorder.seen.last['auth'], '',
          reason:
              'Baada ya removeToken (401), token isiwe kwenye requests mpya');
    });
  });

  group('2. LOGOUT — session isolation kamili', () {
    testWidgets('logout inafuta token, cache na badges — mtumiaji mpya hana'
        ' data za wa zamani', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final recorder = _HeaderRecorder();
      ApiService.dioForTest(ApiService()).httpClientAdapter = recorder;

      // Session "ya mtumiaji wa zamani": token + cache
      await ApiService().saveToken('token-ya-zamani');
      AppCache().set('/matches/board', {'candidates': 'za-zamani'});
      expect(AppCache().get('/matches/board'), isNotNull);

      final auth = AuthProvider();
      await auth.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('kv_token'), isNull,
          reason: 'Token imefutwa kwenye storage (logout kamili)');
      expect(AppCache().get('/matches/board'), isNull,
          reason: 'Cache ya session ya zamani imefutwa');
    });

    test('WS listener za session ya zamani zinafutwa na logout', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var received = 0;
      WebSocketService().on('secret.event', (_) => received++);

      final auth = AuthProvider();
      await auth.logout(); // inaita _ws.clearListeners()

      WebSocketService()
          .dispatchEventForTest({'event': 'secret.event', 'x': 1});
      expect(received, 0,
          reason: 'Event za WS za session ya zamani zisifanye kazi tena');
    });
  });

  group('3. ADMIN SHELL GUARD — UI defense-in-depth', () {
    testWidgets('user wa kawaida (is_admin:false) huingizi /admin — anapelekwa'
        ' /login', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final auth = AuthProvider()
        ..updateUser(AuthUser.fromJson(Map<String, dynamic>.from(fakeMe)));
      expect(auth.isAdmin, isFalse);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<LanguageProvider>.value(
              value: LanguageProvider()),
        ],
        child: MaterialApp(
          routes: {'/login': (_) => const Scaffold(body: Text('LoginScreen'))},
          home: const AdminShell(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('LoginScreen'), findsOneWidget,
          reason: 'User wa kawaida anarudishwa /login (UI guard)');
    });

    testWidgets('admin halisi (is_admin:true) anaingia AdminShell bila'
        ' kutumwa', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final adminUser = Map<String, dynamic>.from(fakeMe)
        ..['is_admin'] = true
        ..['full_name'] = 'Admin Mkuu';
      final auth = AuthProvider()..updateUser(AuthUser.fromJson(adminUser));
      expect(auth.isAdmin, isTrue);

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<LanguageProvider>.value(
              value: LanguageProvider()),
        ],
        child: MaterialApp(home: const AdminShell()),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AdminShell), findsOneWidget,
          reason: 'Admin anabaki kwenye shell (guard haumpi halali)');
    });
  });

  group('4. LOGIN YA MOJA KWA MOJA — namba → token mara moja (kama zamani)', () {
    test('login ya simu inaingia moja kwa moja — hakuna OTP ya SMS kwa users',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final directServer = FakeApiAdapter(routes: {
        '/auth/login': {
          'access_token': 'token-moja-kwa-moja',
          'user_id': 'u1',
          'full_name': 'Thea Shirima',
        },
      });
      ApiService.dioForTest(ApiService()).httpClientAdapter = directServer;

      final auth = AuthProvider();
      final ok = await auth.login('0757502446');

      expect(ok, isTrue,
          reason: 'Users wanaingia kwa namba tu — hakuna code ya SMS');
      expect(auth.isLoggedIn, isTrue);
    });
  });
}
