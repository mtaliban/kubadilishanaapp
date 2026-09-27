// ============================================================================
// test/notifications_ui_test.dart
// TESTING NGUVU ya ukurasa wa ARIFA (notifications_screen.dart):
//   A. Design mpya: kichwa 'Arifa', icon circles kijivu (bila border),
//      BADGE ya ESS logo kwenye kila arifa, icon za rangi husika
//   B. Muda kulia ya kichwa: '27 Sep · 10:32' (leo), 'Jana', '3 Ago' (zamani)
//   C. Read/unread: muda wa bluu (haijasomwa) → kijivu (imesomwa) + POST read
//   D. Navigation: kubofya arifa inafungua page sahihi (malipo/maoni/tangazo)
//   E. Soma Zote: chip inaonekana, POST read-all inatumwa, subtitle inabadilika
//   F. LIVE: event ya WebSocket ('notification') inaonyesha arifa mpya MARA MOJA
//   G. Hali za pekee: orodha tupu + API ikifeli (hakuna crash)
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
import 'package:kubadilishanaapp/screens/notifications_screen.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/services/websocket_service.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart' show LanguageProvider;

import 'helpers/fake_api.dart';

// ── Rangi za brand (lazima zilingane na notifications_screen.dart) ──────────
const _kBlue = Color(0xFF1E40AF);
const _kGrey100 = Color(0xFFF3F4F6);
const _kGrey400 = Color(0xFF9CA3AF);

class _NotifRoutes extends FakeApiAdapter {
  final List<String> calls = [];
  bool failNotifications = false;
  final List<Map<String, dynamic>> notifications = [];

  void seed() {
    notifications
      ..clear()
      ..addAll([
        {
          'notification_id': 'n1',
          'type': 'payment.approved',
          'title': 'Malipo yamekubaliwa',
          'body': 'Ada ya mwezi imethibitishwa',
          'read': false,
          'created_at': '2026-09-20T09:14:00Z',
        },
        {
          'notification_id': 'n2',
          'type': 'admin.reply',
          'title': 'Admin amejibu maoni yako',
          'body': 'Umeuliza kuhusu malipo',
          'read': false,
          'created_at': '2026-09-20T10:32:00Z',
        },
        {
          'notification_id': 'n3',
          'type': 'announcement',
          'title': 'Tangazo kwa watumiaji wote',
          'body': 'Mfumo utafanyiwa matengenezo',
          'read': true,
          'created_at': '2026-09-18T08:00:00Z',
        },
      ]);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    calls.add('${options.method} $path');

    if (path == '/notifications') {
      if (failNotifications) return _json({'detail': 'boom'}, 500);
      return _json({'notifications': notifications});
    }
    if (path == '/notifications/read-all') {
      for (final n in notifications) {
        n['read'] = true;
      }
      return _json({'ok': true});
    }
    final markOne = RegExp(r'^/notifications/([^/]+)/read$').firstMatch(path);
    if (markOne != null) {
      for (final n in notifications) {
        if (n['notification_id'] == markOne.group(1)) n['read'] = true;
      }
      return _json({'ok': true});
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
        routes: {
          '/donate': (_) => const Scaffold(body: Center(child: Text('PAGE_MALIPO'))),
          '/feedback': (_) => const Scaffold(body: Center(child: Text('PAGE_MAONI'))),
          '/announcements': (_) =>
              const Scaffold(body: Center(child: Text('PAGE_TANGAZO'))),
        },
        home: child,
      ),
    );

// Finder ya Text yenye data inayolingana regex (muda kulia ya kichwa).
Finder timeText(RegExp re) => find.byWidgetPredicate(
      (w) => w is Text && w.data != null && re.hasMatch(w.data!),
    );

void main() {
  late _NotifRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    routes = _NotifRoutes();
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    routes.seed();
    routes.failNotifications = false;
    routes.calls.clear();
    AppCache().clear();
  });

  group('A. DESIGN — kichwa, circles, badge ya ESS, icon za rangi', () {
    testWidgets('Kichwa "Arifa" + kitufe cha kurudi + chip ya Soma Zote',
        (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Arifa'), findsOneWidget,
          reason: 'Kichwa kikubwa "Arifa" kinaonekana');
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget,
          reason: 'Kitufe cha kurudi kipo');
      expect(find.textContaining('hazijasomwa'), findsOneWidget,
          reason: 'Hesabu ya hazijasomwa inaonekana chini ya kichwa');
      expect(find.text('Soma Zote'), findsOneWidget,
          reason: 'Chip ya Soma Zote inaonekana wakati kuna hazijasomwa');
    });

    testWidgets('Kila arifa ina circle ya kijivu (bila border) + BADGE ya ESS',
        (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final greyCircles = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.color == _kGrey100 &&
            d.border == null; // HAKUNA border — design mpya
      });
      expect(greyCircles, findsNWidgets(3),
          reason: 'Arifa zote 3 zina circle ya kijivu bila border');

      final essBadges = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/images/ess_badge.png');
      expect(essBadges, findsNWidgets(3),
          reason: 'Badge ya ESS logo inaonekana kwenye kila arifa '
              '(badala ya "W" ya zamani)');
    });

    testWidgets('Icon za rangi husika kwa kila aina ya arifa', (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget,
          reason: 'Malipo yamekubaliwa → icon ya kijani (check)');
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget,
          reason: 'Jibu la admin → icon ya bluu (chat)');
      expect(find.byIcon(Icons.campaign_rounded), findsOneWidget,
          reason: 'Tangazo → icon ya megafoni');
    });
  });

  group('B. MUDA kulia ya kichwa — leo, jana, zamani', () {
    testWidgets('Leo inaonyesha "d Mon · HH:MM", jana "Jana", zamani "d Mon"',
        (tester) async {
      final now = DateTime.now();
      routes.notifications
        ..clear()
        ..addAll([
          {
            'notification_id': 't1',
            'type': 'payment.approved',
            'title': 'Arifa ya leo',
            'body': 'x',
            'read': false,
            'created_at':
                DateTime(now.year, now.month, now.day, 12).toIso8601String(),
          },
          {
            'notification_id': 't2',
            'type': 'admin.reply',
            'title': 'Arifa ya jana',
            'body': 'x',
            'read': false,
            'created_at': DateTime(now.year, now.month, now.day, 12)
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          },
          {
            'notification_id': 't3',
            'type': 'announcement',
            'title': 'Arifa ya zamani',
            'body': 'x',
            'read': true,
            'created_at': DateTime(2026, 8, 3, 10).toIso8601String(),
          },
        ]);

      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final leo = RegExp(r'^\d{1,2} (Jan|Feb|Mar|Apr|Mei|Jun|Jul|Ago|Sep|Okt|Nov|Des) · \d{2}:\d{2}$');
      expect(timeText(leo), findsOneWidget,
          reason: 'Arifa ya leo: "d Mon · HH:MM" (mf. "27 Sep · 10:32")');
      expect(find.text('Jana'), findsOneWidget,
          reason: 'Arifa ya jana: "Jana"');
      expect(timeText(RegExp(r'^3 Ago$')), findsOneWidget,
          reason: 'Arifa ya zamani: "3 Ago" (mwezi kwa Kiswahili)');
    });
  });

  group('C. READ/UNREAD — rangi + POST kwa server', () {
    testWidgets('Muda wa arifa haijasomwa ni BLUU; ukibofya inakuwa KIJIVU '
        'na POST /notifications/{id}/read inatumwa', (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final timeRe = RegExp(r'^20 Sep$');
      final t = tester.widget<Text>(timeText(timeRe).first);
      expect(t.style?.color, _kBlue,
          reason: 'Arifa haijasomwa → muda wa bluu');

      await tester.tap(find.text('Malipo yamekubaliwa'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final t2 = tester.widget<Text>(timeText(timeRe).first);
      expect(t2.style?.color, _kGrey400,
          reason: 'Arifa imesomwa → muda unaingia kijivu');
      expect(routes.calls.contains('POST /notifications/n1/read'), isTrue,
          reason: 'Mark-one POST inafika server');
    });
  });

  group('D. NAVIGATION — kubofya arifa inafungua page sahihi', () {
    testWidgets('payment.approved → page ya Malipo', (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Malipo yamekubaliwa'));
      await tester.pumpAndSettle();

      expect(find.text('PAGE_MALIPO'), findsOneWidget,
          reason: 'Arifa ya malipo inafungua page ya Malipo');
    });

    testWidgets('admin.reply → page ya Maoni', (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Admin amejibu maoni yako'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE_MAONI'), findsOneWidget);
    });

    testWidgets('announcement → page ya Tangazo', (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Tangazo kwa watumiaji wote'));
      await tester.pumpAndSettle();
      expect(find.text('PAGE_TANGAZO'), findsOneWidget);
    });
  });

  group('E. SOMA ZOTE — chip, POST read-all, subtitle', () {
    testWidgets('Kubofya "Soma Zote" → POST read-all + "Zote zimesomwa"',
        (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('hazijasomwa'), findsOneWidget);
      await tester.tap(find.text('Soma Zote'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Zote zimesomwa'), findsOneWidget,
          reason: 'Subtitle inabadilika baada ya kusoma zote');
      expect(routes.calls.contains('POST /notifications/read-all'), isTrue,
          reason: 'Read-all POST inafika server');
    });

    testWidgets('Screen ikifunguka, auto read-all inaitwa mara moja',
        (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(routes.calls.contains('POST /notifications/read-all'), isTrue,
          reason: 'Kufunguka ukurasa kunasoma zote automatically');
    });
  });

  group('F. LIVE — WebSocket inaonyesha arifa mpya bila refresh', () {
    testWidgets("Event 'notification' inareload orodha MARA MOJA",
        (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Arifa mpya LIVE'), findsNothing);

      // Server "inatuma" arifa mpya, kisha event ya WS inafika:
      routes.notifications.add({
        'notification_id': 'n9',
        'type': 'payment.approved',
        'title': 'Arifa mpya LIVE',
        'body': 'Malipo mapya',
        'read': false,
        'created_at': '2026-09-20T11:00:00Z',
      });
      WebSocketService().dispatchEventForTest({'event': 'notification'});
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Arifa mpya LIVE'), findsOneWidget,
          reason: 'Arifa mpya inaonekana bila kufungua upya ukurasa');
    });
  });

  group('G. HALI ZA PEEKÉ — tupu na error', () {
    testWidgets('Orodha tupu inaonyesha ujumbe wa "Hakuna arifa bado"',
        (tester) async {
      routes.notifications.clear();
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hakuna arifa bado'), findsOneWidget);
      expect(find.textContaining('itaonekana hapa'), findsOneWidget,
          reason: 'Maelezo ya hali tupu yanaonekana');
    });

    testWidgets('API ikifeli (500) — hakuna crash, empty state inaonekana',
        (tester) async {
      routes.failNotifications = true;
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hakuna arifa bado'), findsOneWidget,
          reason: 'Error ya API haivunji app — inaonyesha hali ya tupu');
      expect(tester.takeException(), isNull);
    });
  });
}
