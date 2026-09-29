// ============================================================================
// test/admin_crud_ui_test.dart
// CRUD UI KAMILI za admin — dialogs na buttons HALISI (si API tu):
//   1. DATA PAGE (Mikoa): Ongeza (POST) → Hifadhi → Hariri (PATCH) → Futa
//      (DELETE) — kwa dialogs halisi (showMkoaEditDialog/Futa).
//   2. MATANGAZO: fomu ya Tuma (POST payload kamili) + Historia + Futa.
//   3. MAONI/MALALAMIKO: Jibu la admin (POST reply) + Futa (DELETE + dialog).
//   4. MALIPO: Thibitisha (approve) + Kataa (reject + chips za sababu).
// Kila test inathibitisha: hakuna snackbar ya "Kosa", body sahihi inatumwa,
// na UI/"DB" ya fake inasasishwa baada ya kila action.
//
// Mbinu muhimu (imethibitishwa kwa diag):
//   - Screen kubwa ya test (1100x2200) — rows zote zinaonekana (SliverList
//     haijengi rows zilizo nje ya viewport kwenye screen ndogo ya 800x600).
//   - pumpAndSettle baada ya kila tap (animation za tab/dialog zinakamilika).
//   - drain() mwishoni (8s ×2) — Timers za WebSocketService/flash haziripoti
//     "A Timer is still pending".
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/screens/admin/admin_announcements_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_data_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_feedback_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_payments_page.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart' show LanguageProvider;

import 'helpers/fake_api.dart';

/// Fake backend yenye "DB" ndogo — CRUD halisi (list inabadilika).
class _AdminUiRoutes extends FakeApiAdapter {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};

  final Map<String, List<Map<String, dynamic>>> data = {
    'regions': [
      {'id': 2, 'name': 'Mkoa wa Kati', 'is_active': true},
    ],
    'departments': [
      {'code': 'IP', 'name': 'Wagonjwa wa Ndani', 'status': 'active'},
    ],
  };
  List<Map<String, dynamic>> announcements = [
    {
      'announcement_id': 'an1',
      'title': 'Tangazo la Mwanzo',
      'message': 'Karibuni mnufaike',
      'audience': 'all',
      'audiences': ['all'],
      'created_at': '2026-09-26T07:00:00Z',
    },
  ];
  List<Map<String, dynamic>> feedback = [
    {
      'id': 'fb1',
      'subject': 'Swali langu',
      'message': 'Nawezaje kubadilisha mkoa?',
      'status': 'open',
      'admin_reply': null,
      'user_name': 'Thea Shirima',
      'created_at': '2026-09-26T06:00:00Z',
    },
  ];
  List<Map<String, dynamic>> payments = [
    {
      'order_id': 'ORD1',
      'user_name': 'Juma Ali',
      'amount': 2500,
      'currency': 'TZS',
      'status': 'verifying',
      'sms_text': 'X1N2K3 confirm 2500 TZS',
      'created_at': '2026-09-26T05:00:00Z',
      'messages': [],
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

    // ── ADMIN DATA CRUD ──
    final dataMatch = RegExp(r'^/admin/data/(\w+)$').firstMatch(path);
    if (dataMatch != null && options.method == 'POST') {
      final type = dataMatch.group(1)!;
      final body = await parseBody();
      bodies['POST /admin/data/$type'] = body;
      final item = Map<String, dynamic>.from(body);
      item['id'] = data[type]!.length + 100;
      data[type]!.add(item);
      return _json({'ok': true}, 201);
    }
    final itemMatch = RegExp(r'^/admin/data/(\w+)/([^/]+)$').firstMatch(path);
    if (itemMatch != null && options.method == 'PATCH') {
      final type = itemMatch.group(1)!;
      final id = itemMatch.group(2)!;
      final body = await parseBody();
      bodies['PATCH /admin/data/$type/$id'] = body;
      final list = data[type] ?? [];
      final idx =
          list.indexWhere((e) => '${e['id'] ?? e['code']}' == id);
      if (idx < 0) return _json({'detail': 'not found'}, 404);
      list[idx] = {...list[idx], ...body};
      return _json({'ok': true});
    }
    if (itemMatch != null && options.method == 'DELETE') {
      final type = itemMatch.group(1)!;
      final id = itemMatch.group(2)!;
      bodies['DELETE /admin/data/$type/$id'] = {'id': id};
      data[type]?.removeWhere((e) => '${e['id'] ?? e['code']}' == id);
      return _json({'ok': true});
    }
    if (dataMatch != null) {
      return _json(data[dataMatch.group(1)] ?? []);
    }

    // ── MATANGAZO ──
    if (path == '/admin/announcements' && options.method == 'POST') {
      final body = await parseBody();
      bodies['POST /admin/announcements'] = body;
      announcements.insert(0, {
        'announcement_id': 'an-new',
        'title': body['title'],
        'message': body['message'],
        'audience': body['audience'],
        'audiences': body['audiences'],
        'created_at': '2026-09-26T09:00:00Z',
      });
      return _json({'ok': true});
    }
    final annDelete =
        RegExp(r'^/admin/announcements/([^/]+)$').firstMatch(path);
    if (annDelete != null && options.method == 'DELETE') {
      bodies['DELETE announcement'] = {'id': annDelete.group(1)};
      announcements
          .removeWhere((a) => a['announcement_id'] == annDelete.group(1));
      return _json({'ok': true});
    }
    if (path == '/admin/announcements') {
      return _json(
          {'announcements': announcements, 'total': announcements.length});
    }

    // ── MAONI ──
    final fbReply =
        RegExp(r'^/feedback/admin/([^/]+)/reply$').firstMatch(path);
    if (fbReply != null && options.method == 'POST') {
      final body = await parseBody();
      bodies['POST reply:${fbReply.group(1)}'] = body;
      for (final f in feedback) {
        if (f['id'] == fbReply.group(1)) {
          f['status'] = 'replied';
          f['admin_reply'] = body['reply'];
        }
      }
      return _json({'ok': true});
    }
    final fbDelete =
        RegExp(r'^/feedback/admin/([^/]+)$').firstMatch(path);
    if (fbDelete != null && options.method == 'DELETE') {
      bodies['DELETE feedback:${fbDelete.group(1)}'] = {
        'id': fbDelete.group(1)
      };
      feedback.removeWhere((f) => f['id'] == fbDelete.group(1));
      return _json({'ok': true});
    }
    if (path == '/feedback/admin/all') {
      return _json({
        'total': feedback.length,
        'items': feedback,
        'counts': {'open': feedback.where((f) => f['status'] == 'open').length},
      });
    }

    // ── MALIPO ──
    final payApprove =
        RegExp(r'^/payments/admin/([^/]+)/approve$').firstMatch(path);
    if (payApprove != null && options.method == 'POST') {
      final body = await parseBody();
      bodies['approve:${payApprove.group(1)}'] = body;
      for (final p in payments) {
        if (p['order_id'] == payApprove.group(1)) p['status'] = 'approved';
      }
      return _json({'ok': true});
    }
    final payReject =
        RegExp(r'^/payments/admin/([^/]+)/reject$').firstMatch(path);
    if (payReject != null && options.method == 'POST') {
      final body = await parseBody();
      bodies['reject:${payReject.group(1)}'] = body;
      for (final p in payments) {
        if (p['order_id'] == payReject.group(1)) {
          p['status'] = 'rejected';
          p['note'] = body['note'];
        }
      }
      return _json({'ok': true});
    }
    if (path == '/payments/admin/all') {
      final st = options.uri.queryParameters['status'];
      final list = st == null
          ? payments
          : payments.where((p) => p['status'] == st).toList();
      return _json({
        'total_approved_tzs': 5000,
        'count': list.length,
        'payments': list,
        'counts': {
          'verifying': payments.where((p) => p['status'] == 'verifying').length
        },
      });
    }

    return super.fetch(options, requestStream, cancelFuture);
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
  late _AdminUiRoutes routes;
  late ApiService api;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = ApiService();
    api.init();
    routes = _AdminUiRoutes();
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('admin-token');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await api.saveToken('admin-token');
    routes.bodies.clear();
    routes.data['regions'] = [
      {'id': 2, 'name': 'Mkoa wa Kati', 'is_active': true},
    ];
    routes.announcements = [
      {
        'announcement_id': 'an1',
        'title': 'Tangazo la Mwanzo',
        'message': 'Karibuni mnufaike',
        'audience': 'all',
        'audiences': ['all'],
        'created_at': '2026-09-26T07:00:00Z',
      },
    ];
    routes.feedback = [
      {
        'id': 'fb1',
        'subject': 'Swali langu',
        'message': 'Nawezaje kubadilisha mkoa?',
        'status': 'open',
        'admin_reply': null,
        'user_name': 'Thea Shirima',
        'created_at': '2026-09-26T06:00:00Z',
      },
    ];
    routes.payments = [
      {
        'order_id': 'ORD1',
        'user_name': 'Juma Ali',
        'amount': 2500,
        'currency': 'TZS',
        'status': 'verifying',
        'sms_text': 'X1N2K3 confirm 2500 TZS',
        'created_at': '2026-09-26T05:00:00Z',
        'messages': [],
      },
    ];
    AppCache().clear();
  });

  Widget harness(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
            value: AuthProvider()
              ..updateUser(AuthUser.fromJson({
                ...Map<String, dynamic>.from(fakeMe),
                'is_admin': true,
                'full_name': 'Admin Mkuu',
              })),
          ),
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
          home: Scaffold(body: child),
        ),
      );

  /// Screen kubwa — rows zote za SliverList zinajengwa na kuonekana
  /// (kwenye 800x600 default, rows chini ya fold hazijengwi kabisa).
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Pumps za kutosha kwa animation za tab/dialog + refresh za API.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Hakuna kosa lililoonyeshwa kwa admin (snackbar/flash ya 'Kosa:').
  void expectNoError() {
    expect(find.textContaining('Kosa:'), findsNothing,
        reason: 'CRUD imefanya kazi bila exception');
  }

  /// Drani timers za UI (flash/snackbar auto-hide, WS heartbeat) kabla ya
  /// test kuisha — vinginevyo flutter_test inaripoti 'A Timer is still pending'.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 8));
  }

  /// Tab ya Mikoa — scoped kwenye scroll view yake (PageStorageKey) ili
  /// finders zisikamate vitufe vya tabs jirani (TabBarView inabuild jirani).
  final regionsView = find.byKey(const PageStorageKey<String>('regions'));

  group('1. DATA PAGE — CRUD ya Mikoa (dialog halisi)', () {
    testWidgets('Ongeza mkoa: dialog → Hifadhi → POST + orodha inasasishwa',
        (tester) async {
      await tester.pumpWidget(harness(const AdminDataPage()));
      await settle(tester);

      // Nenda tab ya Mikoa
      await tester.tap(find.text('Mikoa'));
      await settle(tester);
      expect(find.descendant(of: regionsView, matching: find.text('Mkoa wa Kati')),
          findsOneWidget,
          reason: 'Data ya mikoa kutoka API inaonekana');

      // Ongeza (scoped kwenye tab ya Mikoa) → dialog
      await tester.tap(find.descendant(
          of: regionsView, matching: find.widgetWithText(ElevatedButton, 'Ongeza')));
      await settle(tester);
      await tester.enterText(
          find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
          'Mkoa Jipya');
      // Pump moja: listener ya controller ipange rebuild ili canSave iwe true
      // (bila pump, button bado iko disabled na tap inapuuzwa).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Hifadhi'));
      await settle(tester);

      // POST imefanyika + body sahihi
      final sent = routes.bodies['POST /admin/data/regions'];
      expect(sent, isNotNull, reason: 'POST /admin/data/regions imetumwa');
      expect(sent!['name'], 'Mkoa Jipya');
      expect(
          routes.data['regions']!.any((r) => r['name'] == 'Mkoa Jipya'),
          isTrue,
          reason: 'Mkoa mpya yumo kwenye data (CRUD imefanya kazi)');

      // Orodha imesasishwa (refresh baada ya create)
      expect(find.descendant(of: regionsView, matching: find.text('Mkoa Jipya')),
          findsOneWidget);
      expectNoError();
      await drain(tester);
    });

    testWidgets('Hariri mkoa: pencil → Hifadhi → PATCH na id sahihi',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminDataPage()));
      await settle(tester);
      await tester.tap(find.text('Mikoa'));
      await settle(tester);

      await tester.tap(find.descendant(
          of: regionsView, matching: find.byIcon(PhosphorIcons.pencilSimple())));
      await settle(tester);
      await tester.enterText(
          find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
          'Mkoa wa Kaskazini');
      // Pump moja kabla ya Hifadhi — onyesha canSave (angalia test ya kwanza).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Hifadhi'));
      await settle(tester);

      final sent = routes.bodies['PATCH /admin/data/regions/2'];
      expect(sent, isNotNull, reason: 'PATCH /admin/data/regions/2 imetumwa');
      expect(sent!['name'], 'Mkoa wa Kaskazini');
      expect(routes.data['regions']!.first['name'], 'Mkoa wa Kaskazini',
          reason: 'DB ya fake imesasishwa (PATCH halisi)');
      expect(
          find.descendant(
              of: regionsView, matching: find.text('Mkoa wa Kaskazini')),
          findsOneWidget,
          reason: 'Orodha inaonyesha jina jipya');
      expectNoError();
      await drain(tester);
    });

    testWidgets('Futa mkoa: trash → Futa → DELETE + inaondoka orodhani',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminDataPage()));
      await settle(tester);
      await tester.tap(find.text('Mikoa'));
      await settle(tester);

      await tester.tap(find.descendant(
          of: regionsView, matching: find.byIcon(PhosphorIcons.trash())));
      await settle(tester);
      await tester.tap(find.text('Futa')); // uthibitisho kwenye dialog
      await settle(tester);

      expect(routes.bodies['DELETE /admin/data/regions/2'], isNotNull,
          reason: 'DELETE /admin/data/regions/2 imetumwa');
      expect(routes.data['regions']!, isEmpty,
          reason: 'Mkoa umeondolewa kwenye data');
      expect(
          find.descendant(of: regionsView, matching: find.text('Mkoa wa Kati')),
          findsNothing,
          reason: 'Mkoa umeondoka kwenye orodha (refresh imefanyika)');
      expectNoError();
      await drain(tester);
    });
  });

  group('2. MATANGAZO — Tuma + Historia + Futa (UI halisi)', () {
    testWidgets('Tuma tangazo: fomu → Tuma → POST payload kamili + Limetumwa',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminAnnouncementsPage()));
      await settle(tester);

      // Fomu: title (TextField 1) + message (TextField 2)
      await tester.enterText(
          find.byType(TextField).at(0), 'Tangazo la Jaribio');
      await tester.enterText(
          find.byType(TextField).at(1), 'Karibuni wote mnufaike');
      await tester.tap(find.widgetWithText(FilledButton, 'Tuma'));
      await settle(tester);

      final sent = routes.bodies['POST /admin/announcements'];
      expect(sent, isNotNull, reason: 'POST /admin/announcements imetumwa');
      expect(sent!['title'], 'Tangazo la Jaribio');
      expect(sent['message'], 'Karibuni wote mnufaike');
      expect(sent['audience'], 'all');
      expect(find.text('Limetumwa'), findsOneWidget,
          reason: 'UI imethibitisha kutuma');

      // Inaonekana kwenye Historia
      await tester.tap(find.textContaining('Historia'));
      await settle(tester);
      expect(find.text('Tangazo la Jaribio'), findsOneWidget);
      expectNoError();
      await drain(tester);
    });

    testWidgets('Futa tangazo: Futa → thibitisha → DELETE + inaondoka',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminAnnouncementsPage()));
      await settle(tester);
      await tester.tap(find.textContaining('Historia'));
      await settle(tester);
      expect(find.text('Tangazo la Mwanzo'), findsOneWidget);

      await tester.tap(find.byTooltip('Futa'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Futa'));
      await settle(tester);

      expect(routes.bodies['DELETE announcement']!['id'], 'an1');
      expect(find.text('Tangazo la Mwanzo'), findsNothing,
          reason: 'Tangazo limeondoka papo hapo (bila refresh ya mkono)');
      expect(find.textContaining('Historia · 0'), findsOneWidget);
      expectNoError();
      await drain(tester);
    });
  });

  group('3. MAONI NA MALALAMIKO — Jibu + Futa (UI halisi)', () {
    testWidgets('Jibu la admin: andika → Jibu → POST reply + flash',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminFeedbackPage()));
      await settle(tester);
      expect(find.textContaining('Nawezaje kubadilisha mkoa?'), findsOneWidget);

      // Composer ndiyo TextField ya mwisho (search iko juu)
      await tester.enterText(
          find.byType(TextField).last, 'Nenda profile kisha badilisha');
      await tester.tap(find.widgetWithText(ElevatedButton, 'JIBU'));
      await settle(tester);

      final sent = routes.bodies['POST reply:fb1'];
      expect(sent, isNotNull, reason: 'POST /feedback/admin/fb1/reply imetumwa');
      expect(sent!['reply'], 'Nenda profile kisha badilisha');
      expect(find.text('Jibu limetumwa kwa mtumiaji'), findsOneWidget,
          reason: 'Flash ya mafanikio imeonekana');
      // Composer mpya: button ya JIBU inabaki (admin anaweza kujibu tena)
      expect(find.widgetWithText(ElevatedButton, 'JIBU'), findsOneWidget,
          reason: 'Composer ya kujibu inaonekana kwa kila kadi');
      expectNoError();
      await drain(tester);
    });

    testWidgets('Futa maoni: trash → dialog → Futa → DELETE + orodha tupu',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminFeedbackPage()));
      await settle(tester);

      await tester.tap(find.byIcon(PhosphorIcons.trash()));
      await settle(tester);
      expect(find.text('Futa Maoni'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(ElevatedButton, 'Futa')));
      await settle(tester);

      expect(routes.bodies['DELETE feedback:fb1'], isNotNull);
      expect(find.text('Hakuna maoni'), findsOneWidget,
          reason: 'Orodha imebaki tupu baada ya kufuta');
      expectNoError();
      await drain(tester);
    });
  });

  group('4. MALIPO — Thibitisha + Kataa (UI halisi)', () {
    testWidgets('Thibitisha: POST mara moja (bila dialog) → approve + inaondoka verifying',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminPaymentsPage()));
      await settle(tester);
      expect(find.textContaining('Juma Ali'), findsOneWidget);

      // Kitufe cha kadi (Tooltip 'Thibitisha') → POST inatumwa MARA MOJA
      // (design mpya haina dialog ya uthibitisho). Kadi ni ndefu — ensureVisible.
      final approveBtn = find.byTooltip('Thibitisha').first;
      await tester.ensureVisible(approveBtn);
      await settle(tester);
      await tester.tap(approveBtn);
      await settle(tester);

      final sent = routes.bodies['approve:ORD1'];
      expect(sent, isNotNull, reason: 'POST /payments/admin/ORD1/approve');
      expect(find.textContaining('yamethibitishwa'), findsOneWidget,
          reason: 'Snackbar ya mafanikio imeonekana');
      // Page inaonyesha status zote — kadi ya Juma Ali ibaki,
      // LAKINI vitufe vya 'Thibitisha' vimepotea (status siyo verifying tena).
      expect(find.byTooltip('Thibitisha'), findsNothing,
          reason: 'Kitufe cha Thibitisha kimeondoka (malipo yameidhinishwa)');
      expectNoError();
      await drain(tester);
    });

    testWidgets('Kataa: chagua sababu (chip) → reject + note inatumwa',
        (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(harness(const AdminPaymentsPage()));
      await settle(tester);

      final rejectBtn = find.byTooltip('Kataa').first;
      await tester.ensureVisible(rejectBtn);
      await settle(tester);
      await tester.tap(rejectBtn);
      await settle(tester);
      // Bottom sheet mpya: chips za sababu — chagua 'SMS si sahihi',
      // kisha kitufe chekundu 'Kataa' (FilledButton ndani ya sheet).
      await tester.tap(find.text('SMS si sahihi'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Kataa'));
      await settle(tester);

      final sent = routes.bodies['reject:ORD1'];
      expect(sent, isNotNull, reason: 'POST /payments/admin/ORD1/reject');
      expect(sent!['note'], 'SMS si sahihi',
          reason: 'Sababu iliyochaguliwa imetumwa kama note');
      expect(find.text('Malipo yamekataliwa'), findsOneWidget);
      expectNoError();
      await drain(tester);
    });
  });
}
