// ============================================================================
// test/notifications_ui_test.dart
// TESTING NGUVU ya ukurasa wa ARIFA (notifications_screen.dart):
//   A. Design mpya: kichwa 'Arifa', icon circles kijivu (bila border),
//      BADGE ya ESS logo kwenye kila arifa, icon za rangi husika
//   B. Muda kulia ya kichwa — RELATIVE (kama WhatsApp): 'Sasa hivi' (<1dak),
//      'dak 30' (<saa), 'saa 10' (<saa 24), 'Jana' (<saa 48), '3 Ago' (zamani)
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
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/screens/notifications_screen.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/services/websocket_service.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart' show LanguageProvider;
import 'package:kubadilishanaapp/widgets/time_ago.dart' show timeAgoShort, timeAgoShortFromDateTime;

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
          'created_at': '2026-09-05T09:14:00Z',
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

    // DESIGN MPYA (kasoro ya mtumiaji): kila arifa ina duara (bila border)
    // la rangi ya AINA (kama AppToast mpya) — tabia ya icons za Tabler/drawer.
    // Unread → duara rangi ya aina; read → kijivu.
    testWidgets('Kila arifa ina circle bila border + BADGE ya ESS',
        (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final greyCircles = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.shape == BoxShape.circle &&
            d.color != null &&
            d.border == null &&
            w.constraints?.maxWidth == 54.0; // duara KUBWA za kadi (54px)
      });
      expect(greyCircles, findsNWidgets(3),
          reason: 'Arifa zote 3 zina duara kubwa (54px) ya rangi ya aina');

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

      // Icons za DRAWER (Tabler) — design mpya ya interface ya arifa.
      // (Icons zinapatokea pia kwenye chips za summary strip — kwa hivyo
      // twatafutia ICON KUBWA ya duara pekee: size == 26.0)
      Finder bigIcon(IconData d) => find.byWidgetPredicate(
          (w) => w is Icon && w.icon == d && w.size == 26.0);
      expect(bigIcon(TablerIcons.circle_check), findsOneWidget,
          reason: 'Malipo yamekubaliwa → icon ya kijani (check)');
      expect(bigIcon(TablerIcons.message_2), findsOneWidget,
          reason: 'Jibu la admin → icon ya bluu (chat — kama drawer ya Maoni)');
      expect(bigIcon(TablerIcons.speakerphone), findsOneWidget,
          reason: 'Tangazo → icon ya megafoni (kama drawer)');
    });
  });

  group('B. MUDA kulia ya kichwa — muda uliopita (relative, kama WhatsApp)', () {
    // Muda ni DETERMINISTIC kwa mbio za dakika: kila seed imetenganishwa
    // katikati ya bandari (30s / dak 30 / saa 10 / saa 30), hivyo matokeo
    // hayabadiliki mpaka clock ya test isogee mbele sana.
    testWidgets('Inaonyesha "Sasa hivi", "dak 30", "saa 10", "Jana", "3 Ago"',
        (tester) async {
      final now = DateTime.now();
      routes.notifications
        ..clear()
        ..addAll([
          {
            'notification_id': 't1',
            'type': 'payment.approved',
            'title': 'Arifa ya punde',
            'body': 'x',
            'read': false,
            'created_at': now
                .subtract(const Duration(seconds: 10))
                .toIso8601String(),
          },
          {
            'notification_id': 't2',
            'type': 'admin.reply',
            'title': 'dak 30 zilizopita',
            'body': 'x',
            'read': false,
            'created_at': now
                .subtract(const Duration(minutes: 30))
                .toIso8601String(),
          },
          {
            'notification_id': 't3',
            'type': 'announcement',
            'title': 'saa 10 zilizopita',
            'body': 'x',
            'read': true,
            'created_at':
                now.subtract(const Duration(hours: 10)).toIso8601String(),
          },
          {
            'notification_id': 't4',
            'type': 'user.registered',
            'title': 'Mtu mpya amejiunga',
            'body': 'x',
            'read': true,
            'created_at':
                now.subtract(const Duration(hours: 30)).toIso8601String(),
          },
          {
            'notification_id': 't5',
            'type': 'announcement',
            'title': 'Zamani sana',
            'body': 'x',
            'read': true,
            'created_at': DateTime(2026, 8, 3, 10).toIso8601String(),
          },
        ]);

      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 'Sasa hivi' iko pia kwenye kichwa (title) ya arifa t1 — kwa hivyo
      // tunatafuta KAMA MUDA (kijivu/kijani/false) sio tu kama mstari.
      expect(timeText(RegExp(r'^Sasa hivi$')), findsOneWidget,
          reason: 'Arifa ya punde (<dakika 1): "Sasa hivi"');
      expect(timeText(RegExp(r'^dak 30$')), findsOneWidget,
          reason: 'Arifa ya dakika 30: "dak 30"');
      expect(timeText(RegExp(r'^saa 10$')), findsOneWidget,
          reason: 'Arifa ya saa 10: "saa 10"');
      expect(timeText(RegExp(r'^Jana$')), findsOneWidget,
          reason: 'Arifa ya saa 30: "Jana"');
      expect(timeText(RegExp(r'^3 Ago$')), findsOneWidget,
          reason: 'Arifa ya zamani: "3 Ago" (siku + mwezi)');
    });
  });

  group('C. READ/UNREAD — rangi + POST kwa server', () {
    testWidgets('Muda wa arifa haijasomwa ni BLUU; ukibofya inakuwa KIJIVU '
        'na POST /notifications/{id}/read inatumwa', (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final timeRe = RegExp(r'^5 Sep$');
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
        'created_at': '2026-09-05T11:00:00Z',
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

    testWidgets('API ikifeli (500) — hakuna crash, widget ya "haijapakuliwa" inaonekana',
        (tester) async {
      routes.failNotifications = true;
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // OFFLINE-FIRST: API imeshindwa + hakuna diski → NoCachedDataWidget
      // ("Data haijapakuliwa bado") — HAKUNA kosa wala "Jaribu tena".
      expect(find.text('Data haijapakuliwa bado'), findsOneWidget,
          reason: 'Error ya API haivunji app — hali rahisi ya "haijapakuliwa"');
      expect(find.text('Jaribu tena'), findsNothing,
          reason: 'Hakuna kitufe cha "Jaribu tena" — pull-to-refresh pekee');
      expect(tester.takeException(), isNull);
    });
  });

  group('H. MUDA — "Sasa hivi" inageuka "dak 7", haiwakai milele', () {
    testWidgets('Arifa ya dakika 7 iliyopita inaonyesha "dak 7", si "Sasa hivi"',
        (tester) async {
      routes.notifications
        ..clear()
        ..add({
          'notification_id': 'n-x',
          'type': 'payment.approved',
          'title': 'Malipo yamekubaliwa',
          'body': 'Ada ya mwezi imethibitishwa',
          'read': false,
          'created_at':
              DateTime.now().subtract(const Duration(minutes: 7)).toIso8601String(),
        });
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('dak 7'), findsOneWidget,
          reason: 'Arifa yenye dakika 7 iliyopita inaonyesha muda halisi');
      expect(find.text('Sasa hivi'), findsNothing,
          reason: 'Arifa ya dakika 7 iliyopita SI "Sasa hivi"');
      await tester.pumpWidget(const SizedBox()); // timer idispose (teardown)
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Ukiwa ukurasa: tick ya sekunde 30 inabadilisha muda ("Sasa hivi" → "dak 1")',
        (tester) async {
      // Arifa imetumwa sekunde ~59.5 zilizopita — inaonyesha "Sasa hivi".
      routes.notifications
        ..clear()
        ..add({
          'notification_id': 'n-y',
          'type': 'payment.approved',
          'title': 'Malipo yamekubaliwa',
          'body': 'Ada ya mwezi imethibitishwa',
          'read': false,
          'created_at': DateTime.now()
              .subtract(const Duration(milliseconds: 59500))
              .toIso8601String(),
        });
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sasa hivi'), findsOneWidget);

      // Wakati halisi unaendelea bila reload yoyote (mtumiaji hajafanya
      // kitu). Baada ya ~6 s halisi arifa ipo zaidi ya dakika 1 iliyopita —
      // tick ya sekunde 30 inarebuild labels BILA kufungua upya ukurasa.
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(seconds: 6)));
      await tester.pump(const Duration(seconds: 31));

      expect(find.text('dak 1'), findsOneWidget,
          reason: 'Tick ya sekunde 30 inaonyesha muda mpya bila reload');
      await tester.pumpWidget(const SizedBox()); // timer idispose (teardown)
      await tester.pump(const Duration(milliseconds: 50));
    });

    test('DIFF HASI — saa ya simu ikinyuma na server: "dak 7" haipotei', () {
      // Simu ya mtumiaji iko NYUMA kwa dakika 7 ikilinganishwa na server:
      // zamani diff ilikuwa hasi → arifa zote zibaki "Sasa hivi" MILELE.
      final ref = DateTime(2026, 10, 20, 14, 0); // wakati wa simu
      final arifa = DateTime(2026, 10, 20, 14, 7); // dakika 7 "mbeleni" kwa simu
      expect(timeAgoShortFromDateTime(arifa, at: ref), 'dak 7');
    });

    test('diff kama kawaida: dakika 7 → "dak 7", chini ya dakika 1 → "Sasa hivi"', () {
      final now = DateTime.now();
      expect(
        timeAgoShortFromDateTime(now.subtract(const Duration(minutes: 7)), at: now),
        'dak 7',
      );
      expect(timeAgoShort(now.toIso8601String()), 'Sasa hivi');
    });
  });
}
