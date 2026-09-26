// ============================================================================
// test/feedback_flow_test.dart
// TESTING NGUVU za flow ya Maoni na Malalamiko (user → admin → user):
//   1. User anatuma maoni → API /feedback inaitwa na payload sahihi
//   2. Maoni yanayorudishwa yanaonekana kwenye /feedback/my
//   3. Admin anaona maoni yote kwenye /feedback/admin/all (counts, replied)
//   4. Admin anajibu → POST /feedback/admin/{id}/reply na payload sahihi
//   5. Reply inabadilisha status → 'replied' + admin_reply imehifadhiwa
//   6. Buttons za UI: "Tuma" (user) na "Jibu" (admin) zinafanya kazi
//   7. Admin page ina button ya kujibu (regression: ilikuwa haionekani)
//   8. Cache haifichi real-time: reads za feedback ni useCache:false
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
import 'package:kubadilishanaapp/screens/admin/admin_feedback_page.dart';
import 'package:kubadilishanaapp/screens/feedback_screen.dart';
import 'package:kubadilishanaapp/screens/maoni_view.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart'
    show LanguageProvider;

import 'helpers/fake_api.dart';

/// Wrapper kama responsive_pump._wrap — providers + localizations (AppShell
/// ya FeedbackScreen inahitaji AuthProvider + LanguageProvider + delegates).
Widget wrapApp(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider()
              ..updateUser(AuthUser.fromJson(Map<String, dynamic>.from(fakeMe)))),
        ChangeNotifierProvider<LanguageProvider>.value(
            value: LanguageProvider()),
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

// ── Fake backend ya feedback (inakumbuka state kama server halisi) ──────────
class FeedbackBackend {
  final List<Map<String, dynamic>> feedbacks = [];
  int seq = 0;

  Map<String, dynamic> submit(String subject, String message) {
    seq++;
    final f = <String, dynamic>{
      'id': 'fb$seq',
      'subject': subject,
      'message': message,
      'status': 'open',
      'admin_reply': null,
      'admin_replied_at': null,
      'created_at': DateTime.now().toIso8601String(),
      'user_name': 'Thea Shirima',
      'user_phone': '0757502446',
    };
    feedbacks.add(f);
    return f;
  }

  Map<String, dynamic>? reply(String id, String text) {
    for (final f in feedbacks) {
      if (f['id'] == id) {
        f['status'] = 'replied';
        f['admin_reply'] = text;
        f['admin_replied_at'] = DateTime.now().toIso8601String();
        return f;
      }
    }
    return null;
  }

  Map<String, dynamic> adminAll() => {
        'total': feedbacks.length,
        'items': feedbacks.map((f) => Map<String, dynamic>.from(f)).toList(),
        'counts': {
          'open': feedbacks.where((f) => f['status'] == 'open').length,
          'replied': feedbacks.where((f) => f['status'] == 'replied').length,
        },
      };

  Map<String, dynamic> mine() => {
        'total': feedbacks.length,
        'items': feedbacks.map((f) => Map<String, dynamic>.from(f)).toList(),
      };
}

class _FeedbackRoutes extends FakeApiAdapter {
  final FeedbackBackend backend;
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};

  _FeedbackRoutes(this.backend);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    calls.add('${options.method} $path');

    Future<Uint8List?> readBody() async {
      if (requestStream == null) return null;
      final chunks = <List<int>>[];
      await for (final c in requestStream) {
        chunks.add(c);
      }
      if (chunks.isEmpty) return null;
      return Uint8List.fromList(chunks.expand((x) => x).toList());
    }

    if (path == '/feedback' && options.method == 'POST') {
      final raw = await readBody();
      final body = raw == null
          ? <String, dynamic>{}
          : (jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
      bodies['POST /feedback'] = body;
      return _json(backend.submit(
        '${body['subject'] ?? ''}',
        '${body['message'] ?? ''}',
      ), 201);
    }
    if (path == '/feedback/my') return _json(backend.mine());
    if (path == '/feedback/admin/all') return _json(backend.adminAll());
    final replyMatch =
        RegExp(r'^/feedback/admin/([^/]+)/reply$').firstMatch(path);
    if (replyMatch != null && options.method == 'POST') {
      final raw = await readBody();
      final body = raw == null
          ? <String, dynamic>{}
          : (jsonDecode(utf8.decode(raw)) as Map<String, dynamic>);
      bodies['reply:${replyMatch.group(1)}'] = body;
      final updated = backend.reply(replyMatch.group(1)!,
          '${body['reply'] ?? ''}');
      return _json({'ok': updated != null});
    }
    if (path.startsWith('/feedback/admin/') && options.method == 'DELETE') {
      final id = path.split('/').last;
      backend.feedbacks.removeWhere((f) => f['id'] == id);
      return _json({'ok': true});
    }
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
  late FeedbackBackend backend;
  late _FeedbackRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    backend = FeedbackBackend();
    routes = _FeedbackRoutes(backend);
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    backend.feedbacks.clear();
    backend.seq = 0;
    AppCache().clear();
  });

  group('API: user anatuma maoni (POST /feedback)', () {
    test('submitFeedback inatuma subject + message', () async {
      final res = await ApiService()
          .submitFeedback(subject: 'Shida ya app', message: 'Siwezi kupata mechi');
      expect(res.statusCode, 201);
      final data = res.data as Map;
      expect(data['id'], 'fb1');
      expect(data['status'], 'open');
      // Payload ya POST ilikuwa sahihi
      final sent = routes.bodies['POST /feedback']!;
      expect(sent['subject'], 'Shida ya app');
      expect(sent['message'], 'Siwezi kupata mechi');
    });

    test('maoni yanayotumwa yanaonekana kwenye /feedback/my', () async {
      await ApiService()
          .submitFeedback(subject: 'Swali', message: 'Nawezaje kubadilisha mkoa?');
      final res = await ApiService().getMyFeedback();
      final items = (res.data['items'] as List).cast<Map>();
      expect(items, hasLength(1));
      expect(items.first['message'], 'Nawezaje kubadilisha mkoa?');
      expect(items.first['status'], 'open');
    });

    test('maoni mengi yanajitokeza yote (hakuna lililopotea)', () async {
      for (var i = 1; i <= 3; i++) {
        await ApiService()
            .submitFeedback(subject: 'M$i', message: 'Ujumbe wa majaribio $i');
      }
      final res = await ApiService().getMyFeedback();
      expect((res.data['items'] as List).length, 3);
      expect(backend.feedbacks, hasLength(3));
    });
  });

  group('API: admin anaona + anajibu', () {
    test('adminListFeedback inaonyesha maoni ya watumiaji', () async {
      await ApiService().submitFeedback(subject: 'S', message: 'M wa mtumiaji');
      final res = await ApiService().adminListFeedback(status: '', q: '');
      final items = (res.data['items'] as List).cast<Map>();
      expect(items, hasLength(1));
      expect(items.first['message'], 'M wa mtumiaji');
      expect(res.data['counts']['open'], 1);
      expect(res.data['counts']['replied'], 0);
    });

    test('adminReplyFeedback inatuma reply kwenye id sahihi', () async {
      final f = await ApiService()
          .submitFeedback(subject: 'S', message: 'M');
      final id = '${(f.data as Map)['id']}';

      await ApiService().adminReplyFeedback(id, 'Asante, tunafanya kazi juu yake');

      final sent = routes.bodies['reply:$id']!;
      expect(sent['reply'], 'Asante, tunafanya kazi juu yake');
    });

    test('reply inabadilisha status → replied + inaonekana kwa user', () async {
      final f = await ApiService()
          .submitFeedback(subject: 'S', message: 'M');
      final id = '${(f.data as Map)['id']}';

      // Admin kabla ya kujibu — open
      var all = await ApiService().adminListFeedback(status: '', q: '');
      expect(all.data['counts']['open'], 1);

      await ApiService().adminReplyFeedback(id, 'Jibu la admin');

      // Admin baada ya kujibu — replied
      all = await ApiService().adminListFeedback(status: '', q: '');
      expect(all.data['counts']['replied'], 1);
      expect(all.data['counts']['open'], 0);

      // USER anaona jibu PAPO HAPO (useCache:false — hakuna cache ya kale)
      final mine = await ApiService().getMyFeedback();
      final items = (mine.data['items'] as List).cast<Map>();
      expect(items.first['status'], 'replied');
      expect(items.first['admin_reply'], 'Jibu la admin');
    });

    test('adminDeleteFeedback inafuta maoni', () async {
      final f = await ApiService()
          .submitFeedback(subject: 'S', message: 'Futa mimi');
      final id = '${(f.data as Map)['id']}';
      await ApiService().adminDeleteFeedback(id);
      expect(backend.feedbacks, isEmpty);
      final all = await ApiService().adminListFeedback(status: '', q: '');
      expect((all.data['items'] as List), isEmpty);
    });
  });

  group('Cache haifichi real-time (bug iliyorekebishwa)', () {
    test('getMyFeedback ni useCache:false (kila wito unaenda server)', () async {
      await ApiService().submitFeedback(subject: 'S', message: 'M');
      await ApiService().getMyFeedback(); // wito wa kwanza
      final callsBefore = routes.calls.where((c) => c == 'GET /feedback/my').length;

      await ApiService().getMyFeedback(); // wito wa pili — lazima ufike server
      final callsAfter = routes.calls.where((c) => c == 'GET /feedback/my').length;
      expect(callsAfter, callsBefore + 1,
          reason: 'getMyFeedback lazima ifike server kila wakati — jibu la '
              'admin na maoni mapya yasifichwe na cache');
    });

    test('adminListFeedback ni useCache:false', () async {
      await ApiService().adminListFeedback(status: '', q: '');
      final before = routes.calls.where((c) => c == 'GET /feedback/admin/all').length;
      await ApiService().adminListFeedback(status: '', q: '');
      final after = routes.calls.where((c) => c == 'GET /feedback/admin/all').length;
      expect(after, before + 1,
          reason: 'adminListFeedback lazima ifike server kila wakati — maoni '
              'mapya ya watumiaji yasifichwe na cache');
    });
  });

  group('UI: screen ya mtumiaji (Maoni/Tuma)', () {
    testWidgets('FeedbackScreen inaonyesha maoni + kitufe cha Tuma kinatuma API',
        (tester) async {
      // Maoni ya zamani
      backend.submit('Habari', 'Maoni ya kale ya mtumiaji');

      await tester.pumpWidget(wrapApp(const FeedbackScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Maoni ya kale yaonekana
      expect(find.textContaining('Maoni ya kale ya mtumiaji'), findsOneWidget);

      // Andika maoni mpya na TUMA (kitufe ni FilledButton "Tuma")
      await tester.enterText(find.byType(TextField).first, 'Hii ni maoni mapya ya sasa');
      await tester.pump();
      final callsBefore =
          routes.calls.where((c) => c == 'POST /feedback').length;
      final tumaBtn = find.widgetWithText(FilledButton, 'Tuma');
      expect(tumaBtn, findsOneWidget,
          reason: 'Kitufe cha Tuma kipo');
      await tester.tap(tumaBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(routes.calls.where((c) => c == 'POST /feedback').length,
          callsBefore + 1,
          reason: 'Kitufe cha Tuma lazima kitume POST /feedback');
      expect(routes.bodies['POST /feedback']!['message'],
          'Hii ni maoni mapya ya sasa');

      // Flush timer za toast (4s) — zisibaki pending mwishoni mwa test
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('UI: page ya admin (Jibu + Futa)', () {
    testWidgets('AdminFeedbackPage ina kitufe cha JIBU kwa kila maoni',
        (tester) async {
      backend.submit('Swali la mtumiaji', 'Nawezaje kubadilisha wilaya?');

      await tester.pumpWidget(const MaterialApp(home: AdminFeedbackPage()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // REGRESSION: kitufe cha "Jibu" kilikuwa hakionekani kwa mtumiaji
      expect(find.widgetWithText(ElevatedButton, 'Jibu'), findsOneWidget,
          reason: 'Admin lazima awe na button ya kujibu maoni');
      // Na field ya kuandikia jibu
      expect(find.text('Andika jibu lako...'), findsOneWidget);
    });

    testWidgets('Admin anajibu → POST reply inatumwa na status inabadilika',
        (tester) async {
      final f = backend.submit('Swali', 'Ujumbe wa kupima jibu');
      final id = f['id'] as String;

      await tester.pumpWidget(const MaterialApp(home: AdminFeedbackPage()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // TextFields: [0] = search 'Tafuta...', [1] = 'Andika jibu lako...'
      await tester.enterText(
          find.byType(TextField).last, 'Jibu la haraka la admin');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Jibu'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // POST ilifika kwenye server
      expect(routes.bodies['reply:$id']!['reply'], 'Jibu la haraka la admin');
      // State ya server imebadilika
      expect(f['status'], 'replied');
      expect(f['admin_reply'], 'Jibu la haraka la admin');

      // Flush flash timer (4s)
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Maoni yaliyojibiwa yanaonyesha JIBU LAKO + badge Imejibiwa',
        (tester) async {
      final f = backend.submit('Swali', 'Ujumbe');
      backend.reply('${f['id']}', 'Jibu limehifadhiwa');

      await tester.pumpWidget(const MaterialApp(home: AdminFeedbackPage()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('JIBU LAKO'), findsOneWidget);
      expect(find.text('Imejibiwa'), findsOneWidget);
      expect(find.text('Jibu limehifadhiwa'), findsOneWidget);
    });

    testWidgets('Search inachuja kwa jina/ujumbe', (tester) async {
      backend.submit('Malalamiko ya mfumo', 'Huendi vizuri');
      backend.submit('Pongezi', 'Kazi nzuri sana');

      await tester.pumpWidget(const MaterialApp(home: AdminFeedbackPage()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // REGRESSION BUG: search ilikuwa haichuji SUBJECT (kichwa) — sasa inachuja
      await tester.enterText(find.byType(TextField).first, 'Pongezi');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Kazi nzuri'), findsOneWidget,
          reason: 'Search kwa subject lazima ipate maoni ya Pongezi');
      expect(find.textContaining('Huendi vizuri'), findsNothing);
    });
  });

  group('Model: FeedbackItem', () {
    test('answered ni true pale reply isipokuwa tupu', () {
      final withReply = FeedbackItem(
          id: '1', message: 'm', createdAt: DateTime.now(), reply: 'Jibu');
      final noReply = FeedbackItem(
          id: '2', message: 'm', createdAt: DateTime.now(), reply: null);
      final emptyReply = FeedbackItem(
          id: '3', message: 'm', createdAt: DateTime.now(), reply: '   ');
      expect(withReply.answered, isTrue);
      expect(noReply.answered, isFalse);
      expect(emptyReply.answered, isFalse,
          reason: 'Reply tupu (spaces) si jibu — inabaki "hayajajibiwa"');
    });
  });
}
