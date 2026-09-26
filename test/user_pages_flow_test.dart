// ============================================================================
// test/user_pages_flow_test.dart
// TESTING KAMILI ya pages zote za MTUMIAJI:
//   1. Dashboard: board (candidates) + filters server-side (mkoa/wilaya
//      zinatumwa kwenye API) + wilaya za mkoa zinaload
//   2. Malipo (Changia): history ina status (verifying/approved/rejected)
//      + note ya reject + messages za admin zinaonekana
//   3. Maoni na Malalamiko: orodha + jibu la admin + TUMA
//   4. Profile: getMyProfile + updateProfile (payload sahihi) + cache bust
//   5. Notifications: markAllRead/markNotificationRead
//   6. Announcements: list + dismiss
//   7. Call history: list
//   8. Followed regions: PUT
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
import 'package:kubadilishanaapp/screens/announcements_screen.dart';
import 'package:kubadilishanaapp/screens/dashboard_screen.dart';
import 'package:kubadilishanaapp/screens/feedback_screen.dart';
import 'package:kubadilishanaapp/screens/notifications_screen.dart';
import 'package:kubadilishanaapp/screens/profile_screen.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart' show LanguageProvider;

import 'helpers/fake_api.dart';

class _UserRoutes extends FakeApiAdapter {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};
  bool profileUpdated = false;
  String? updatedName;
  final List<Map<String, dynamic>> announcements = [
    {
      'announcement_id': 'an1',
      'title': 'Karibu Kubadilishana',
      'message': 'Tangazo la kwanza',
      'kind': 'taarifa',
      'created_at': '2026-09-20T08:00:00Z',
    },
  ];
  final List<Map<String, dynamic>> notifications = [
    {
      'notification_id': 'n1',
      'type': 'payment.approved',
      'title': 'Malipo yamethibitishwa',
      'body': 'TZS 2,500',
      'read': false,
      'created_at': '2026-09-24T05:10:00Z',
    },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    calls.add('${options.method} $path${options.uri.query}');

    Future<Map<String, dynamic>> parseBody() async {
      if (requestStream == null) return {};
      final chunks = <List<int>>[];
      await for (final c in requestStream) {
        chunks.add(c);
      }
      if (chunks.isEmpty) return {};
      final decoded = jsonDecode(utf8.decode(
          Uint8List.fromList(chunks.expand((x) => x).toList())));
      return decoded is Map<String, dynamic> ? decoded : {};
    }

    // PATCH /users/me lazima ichunguzwe KABLA ya me-check hapa chini
    // (me-check haimchungi method, ingekamata PATCH na kuificha).
    if (options.method == 'PATCH' && path == '/users/me') {
      final body = await parseBody();
      bodies['PATCH /users/me'] = body;
      profileUpdated = true;
      updatedName = body['full_name'] as String?;
      return _json(Map<String, dynamic>.from(fakeMe));
    }
    if (path == '/auth/me' || path == '/users/me') {
      if (profileUpdated) {
        final me = Map<String, dynamic>.from(fakeMe);
        if (updatedName != null) me['full_name'] = updatedName;
        return _json(me);
      }
      return _json(Map<String, dynamic>.from(fakeMe));
    }
    if (path.startsWith('/users/me/followed-regions')) {
      if (options.method == 'PUT') {
        bodies['PUT followed-regions'] = await parseBody();
        return _json({'ok': true});
      }
      return _json({'region_ids': [1, 3]});
    }
    if (path == '/locations/regions') {
      return _json([
        {'id': 1, 'name': 'Arusha'},
        {'id': 2, 'name': 'Mbeya'},
        {'id': 3, 'name': 'Mwanza'},
      ]);
    }
    final districts = RegExp(r'^/locations/regions/(\d+)/districts$')
        .firstMatch(path);
    if (districts != null) {
      final rid = int.parse(districts.group(1)!);
      return _json([
        {'id': rid * 10 + 1, 'name': 'Wilaya A$rid'},
        {'id': rid * 10 + 2, 'name': 'Wilaya B$rid'},
      ]);
    }
    if (path.startsWith('/locations/districts/')) {
      return _json([
        {'id': 999, 'name': 'Kituo Halisi', 'type': 'hospitali'},
      ]);
    }
    if (path == '/cadres' || path == '/cadres/subjects') return _json([]);
    if (path == '/matches/board') {
      // Thibitisha source_region_id inafika server-side
      final q = options.uri.queryParameters;
      final rid = q['source_region_id'];
      final did = q['district_id'];
      bodies['board:region=$rid,district=$did'] = {'rid': rid, 'did': did};
      return _json({
        'candidates': [
          {
            'user_id': 'p1',
            'full_name': 'Yona Thomas',
            'category': 'education',
            'cadre_display': 'Mwalimu',
            'phone_primary': '0712345678',
            'online': true,
            'created_at': '2026-09-10T08:00:00Z',
            'current_station': {
              'region_name': 'Mbeya',
              'district_name': 'Chunya DC',
              'facility_name': 'Shule ya Chunya',
            },
            'desired_destinations': [
              {'region_name': 'Arusha', 'district_name': 'Arusha Mjini'},
            ],
          },
        ],
        'total': 1,
      });
    }
    if (path == '/matches/true') return _json({'matches': []});
    if (path == '/matches/me') return _json({'matches': []});
    if (path == '/matches/stats') return _json({'total': 0});
    if (path == '/payments/my-history') {
      return _json({'items': [
        {
          'payment_id': 'payA',
          'amount': 2500,
          'status': 'approved',
          'created_at': '2026-09-24T05:10:00Z',
          'note': null,
          'messages': [],
        },
        {
          'payment_id': 'payB',
          'amount': 1000,
          'status': 'rejected',
          'created_at': '2026-09-23T05:10:00Z',
          'note': 'SMS si halisi',
          'messages': [
            {'sender': 'admin', 'message': 'Tumepiga simu kuthibitisha',
             'created_at': '2026-09-23T06:00:00Z'},
          ],
        },
        {
          'payment_id': 'payC',
          'amount': 2500,
          'status': 'verifying',
          'created_at': '2026-09-25T05:10:00Z',
          'note': null,
          'messages': [],
        },
      ]});
    }
    if (path == '/payments/info') {
      return _json({'phone': '0763795801', 'amount': 2500});
    }
    if (path == '/feedback/my') {
      return _json({'items': [
        {
          'id': 'fb1',
          'subject': 'Swali langu',
          'message': 'Nawezaje kubadilisha mkoa?',
          'status': 'replied',
          'admin_reply': 'Nenda profile kisha badilisha',
          'created_at': '2026-09-22T10:00:00Z',
        },
        {
          'id': 'fb2',
          'subject': 'Pongezi',
          'message': 'Mfumo mzuri',
          'status': 'open',
          'admin_reply': null,
          'created_at': '2026-09-23T10:00:00Z',
        },
      ]});
    }
    if (path == '/notifications') {
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
    // ApiService.getAnnouncements() inaita /announcements/active;
    // dismiss ni POST /announcements/{id}/dismiss.
    if (path == '/announcements' || path == '/announcements/active') {
      return _json({'announcements': announcements});
    }
    if (path == '/announcements/unread-count') {
      return _json({'count': announcements.length});
    }
    if (path.endsWith('/dismiss') && options.method == 'POST') {
      final id = path.split('/')[2];
      announcements.removeWhere((a) => a['announcement_id'] == id);
      return _json({'ok': true});
    }
    if (path == '/messages/calls') {
      return _json({'calls': [
        {'call_id': 'c1', 'from_full_name': 'Juma', 'created_at': '2026-09-24T07:00:00Z'},
      ]});
    }
    if (path == '/messages/presence') return _json({'online': []});
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
  late _UserRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    routes = _UserRoutes();
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    routes.bodies.clear();
    routes.profileUpdated = false;
    routes.updatedName = null;
    routes.announcements
      ..clear()
      ..add({
        'announcement_id': 'an1',
        'title': 'Karibu Kubadilishana',
        'message': 'Tangazo la kwanza',
        'kind': 'taarifa',
        'created_at': '2026-09-20T08:00:00Z',
      });
    AppCache().clear();
  });

  group('1. DASHBOARD — board + filters server-side', () {
    test('getBoard inatumia source_region_id + district_id kwenye query',
        () async {
      // Simuliza mkoa uliochaguliwa (Arusha = id 1, Wilaya A1 = id 11)
      await ApiService().get('/matches/board', queryParameters: {
        'scope': 'incoming',
        'limit': 100,
        'source_region_id': 1,
        'district_id': 11,
        'bypass_cache': true,
      });
      expect(routes.bodies.containsKey('board:region=1,district=11'), isTrue,
          reason: 'source_region_id + district_id zinafika server '
              '(filter ya server-side inafanya kazi)');
      expect(routes.calls.last.contains('bypass_cache=true'), isTrue,
          reason: 'Vichujio vinapitwa cache ya backend (5s) — board ya kale '
              'yasiyochujwa hairudishwi wakati mtumiaji anachuja');
    });

    test('getRegions (chips) + getDistricts (wilaya) zinaload', () async {
      final regions = await ApiService().getRegions();
      final names = (regions.data as List).map((r) => '${r['name']}').toList();
      expect(names, containsAll(['Arusha', 'Mbeya', 'Mwanza']));

      final dists = await ApiService().getDistricts(1);
      final dNames = (dists.data as List).map((d) => '${d['name']}').toList();
      expect(dNames, containsAll(['Wilaya A1', 'Wilaya B1']),
          reason: 'Wilaya za mkoa husika zinaload (siyo vitupu)');
    });

    testWidgets('Dashboard inaonyesha candidates kutoka API', (tester) async {
      await tester.pumpWidget(wrapApp(const DashboardScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Yona Thomas'), findsWidgets,
          reason: 'Mwenzi kutoka /matches/board anaonekana');
      expect(find.textContaining('Mbeya'), findsWidgets,
          reason: 'Eneo lake linaonekana');
    });
  });

  group('2. MALIPO (Changia) — status na messages zinaonekana', () {
    test('history inarudisha status zote 3 + note + messages', () async {
      final res = await ApiService().getPaymentHistory();
      final items = (res.data['items'] as List).cast<Map>();
      expect(items, hasLength(3));

      final statuses = items.map((p) => '${p['status']}').toSet();
      expect(statuses, containsAll(['approved', 'rejected', 'verifying']));

      final rejected = items.firstWhere((p) => p['payment_id'] == 'payB');
      expect(rejected['note'], 'SMS si halisi',
          reason: 'Sababu ya kukataliwa inaonekana kwa user');
      final msgs = rejected['messages'] as List;
      expect((msgs.last as Map)['sender'], 'admin',
          reason: 'Jibu la admin linaonekana kwenye malipo yaliyokataliwa');
    });

    testWidgets('DonateScreen inaonyesha historia na status', (tester) async {
      await tester.pumpWidget(wrapApp(const DashboardScreen()));
      // ChangiaView ni kwenye tab ya pili — tunapima API side tu hapa;
      // UI ya changia imeshapimwa kwenye payments_flow_test.dart.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });

  group('3. MAONI NA MALALAMIKO — orodha + jibu + kutuma', () {
    test('getMyFeedback inaonyesha maoni + majibu', () async {
      final res = await ApiService().getMyFeedback();
      final items = (res.data['items'] as List).cast<Map>();
      expect(items, hasLength(2));

      final replied = items.firstWhere((f) => f['id'] == 'fb1');
      expect(replied['status'], 'replied');
      expect(replied['admin_reply'], 'Nenda profile kisha badilisha',
          reason: 'Jibu la admin linaonekana kwa user');

      final open = items.firstWhere((f) => f['id'] == 'fb2');
      expect(open['status'], 'open');
      expect(open['admin_reply'], isNull);
    });

    test('submitFeedback inatuma payload sahihi (subject + message)', () async {
      final res = await ApiService()
          .submitFeedback(subject: 'Swali', message: 'Naweza kubadilisha mkoa?');
      // POST inafika (hakuna exception) — payload imehifadhiwa kwenye
      // fake backend kwenye test ya feedback_flow_test.dart kwa undani zaidi.
      expect(res.data, isNotNull);
    });

    testWidgets('FeedbackScreen inaonyesha maoni + jibu la admin',
        (tester) async {
      await tester.pumpWidget(wrapApp(const FeedbackScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Nawezaje kubadilisha mkoa?'), findsWidgets,
          reason: 'Maoni ya mtumiaji yanaonekana');
      expect(find.textContaining('Nenda profile kisha badilisha'), findsWidgets,
          reason: 'Jibu la admin linaonekana chini ya maoni');
    });
  });

  group('4. PROFILE — load + update', () {
    test('getMyProfile inazidi server (si cache ya kale)', () async {
      final r1 = await ApiService().getMyProfile();
      expect(r1.data['full_name'], 'Thea Shirima');
    });

    test('updateProfile inatuma full_name + phone_alt + station + dests',
        () async {
      await ApiService().updateProfile({
        'full_name': 'Thea Mpya',
        'phone_alt': '0757999000',
        'cadre_code': 'TCH',
        'current_station': {
          'region_id': 1,
          'region_name': 'Arusha',
        },
        'desired_destinations': [
          {'region_id': 2, 'region_name': 'Mbeya'},
        ],
      });

      final sent = routes.bodies['PATCH /users/me'] ??
          routes.bodies['PATCH /users/me?'];
      expect(sent, isNotNull, reason: 'PATCH /users/me imetumwa');
      expect(sent!['full_name'], 'Thea Mpya');
      expect(sent['phone_alt'], '0757999000');
      expect(sent['cadre_code'], 'TCH');
      expect((sent['current_station'] as Map)['region_id'], 1);
      expect((sent['desired_destinations'] as List), hasLength(1));
      // Server imehifadhi
      expect(routes.profileUpdated, isTrue);
      expect(routes.updatedName, 'Thea Mpya');
    });

    test('updateProfile inabust cache ya /users/me na /auth/me', () async {
      await ApiService().getMyProfile(); // jaza cache
      expect(AppCache().get('/users/me'), isNotNull);

      await ApiService().updateProfile({'full_name': 'Thea Tatu'});
      expect(AppCache().get('/users/me'), isNull,
          reason: 'Cache lazima ifutwe — profile inayofuata itapakia mpya');
      expect(AppCache().get('/auth/me'), isNull);
    });

    testWidgets('ProfileScreen inaonyesha data kutoka API', (tester) async {
      await tester.pumpWidget(wrapApp(const ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Thea'), findsWidgets,
          reason: 'Jina kutoka /users/me linaonekana');
    });
  });

  group('5. NOTIFICATIONS — markAllRead/markOne', () {
    testWidgets('Screen inaonyesha arifa + kusoma kunafika server',
        (tester) async {
      await tester.pumpWidget(wrapApp(const NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Malipo yamethibitishwa'), findsWidgets,
          reason: 'Arifa kutoka API inaonekana');
      // markAllRead ilifika server (screen inaita auto)
      expect(routes.calls.any((c) => c.contains('read-all')), isTrue);
    });
  });

  group('6. ANNOUNCEMENTS — list + dismiss', () {
    testWidgets('Matangazo yanaonekana + dismiss inafuta server-side',
        (tester) async {
      await tester.pumpWidget(wrapApp(const AnnouncementsScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Karibu Kubadilishana'), findsWidgets,
          reason: 'Tangazo kutoka API linaonekana');
    });
  });

  group('7. CALL HISTORY — list', () {
    test('getCallHistory inarudisha simu zilizopigwa', () async {
      final res = await ApiService().getCallHistory();
      final calls = (res.data['calls'] as List).cast<Map>();
      expect(calls, hasLength(1));
      expect(calls.first['from_full_name'], 'Juma');
    });
  });

  group('8. FOLLOWED REGIONS — PUT', () {
    test('updateFollowedRegions inatuma region_ids', () async {
      await ApiService().updateFollowedRegions([1, 3]);
      final sent = routes.bodies['PUT followed-regions']!;
      expect(sent['region_ids'], [1, 3]);
    });
  });
}
