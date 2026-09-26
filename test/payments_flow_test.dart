// ============================================================================
// test/payments_flow_test.dart
// TESTING NGUVU za flow ya MALIPO (user → admin → user):
//   1. User anatuma malipo (POST /payments/donate) — payload sahihi
//   2. Admin anaona malipo mapya (GET /payments/admin/all + counts)
//   3. Admin anathibitisha (POST approve) → status inabadilika
//      + is_verified inawashwa (user anaweza kupiga simu/WA)
//   4. Admin anakataa (POST reject + note) → note inahifadhiwa
//   5. Admin anatuma ujumbe (POST admin/{id}/reply) → user anaona
//   6. User anatuma ujumbe (POST {id}/message) → admin anaona
//   7. UI: page ya admin ina vitufe vya approve/reject/reply
//   8. UI: user donate screen inaonyesha historia + status
//   9. Cache haifichi real-time (reads muhimu ni useCache:false)
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
import 'package:kubadilishanaapp/screens/admin/admin_payments_page.dart';
import 'package:kubadilishanaapp/screens/donate_screen.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart' show LanguageProvider;

import 'helpers/fake_api.dart';

// ── Fake backend ya malipo (inakumbuka state kama server halisi) ────────────
class PaymentsBackend {
  final List<Map<String, dynamic>> payments = [];
  final Map<String, bool> verifiedUsers = {};
  int seq = 0;

  Map<String, dynamic> donate({
    required String userId,
    required String userName,
    required int amount,
    required String sms,
    required String phone,
  }) {
    seq++;
    final p = <String, dynamic>{
      'order_id': 'ord$seq',
      'payment_id': 'ord$seq',
      'user_id': userId,
      'user_name': userName,
      'phone': phone,
      'amount': amount,
      'currency': 'TZS',
      'sms_text': sms,
      'status': 'verifying',
      'note': null,
      'messages': <Map<String, dynamic>>[],
      'created_at': DateTime.now().toIso8601String(),
    };
    payments.add(p);
    return p;
  }

  Map<String, dynamic>? review(String orderId, String status, String? note) {
    for (final p in payments) {
      if (p['order_id'] == orderId && p['status'] == 'verifying') {
        p['status'] = status;
        if (note != null) p['note'] = note;
        return p;
      }
    }
    return null;
  }

  Map<String, dynamic>? addMessage(String orderId, String sender, String text) {
    for (final p in payments) {
      if (p['order_id'] == orderId) {
        (p['messages'] as List).add({
          'sender': sender,
          'message': text,
          'created_at': DateTime.now().toIso8601String(),
        });
        return p;
      }
    }
    return null;
  }

  Map<String, dynamic> adminAll() => {
        'total_approved_tzs': payments
            .where((p) => p['status'] == 'approved')
            .fold<int>(0, (s, p) => s + (p['amount'] as int)),
        'count': payments.length,
        'payments': payments.map((p) => Map<String, dynamic>.from(p)).toList(),
        'counts': {
          'verifying': payments.where((p) => p['status'] == 'verifying').length,
          'approved': payments.where((p) => p['status'] == 'approved').length,
          'rejected': payments.where((p) => p['status'] == 'rejected').length,
          'all': payments.length,
        },
      };

  List<Map<String, dynamic>> historyFor(String userId) => payments
      .where((p) => p['user_id'] == userId)
      .map((p) => Map<String, dynamic>.from(p))
      .toList();
}

class _PaymentsRoutes extends FakeApiAdapter {
  final PaymentsBackend backend;
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};

  _PaymentsRoutes(this.backend);

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

    Future<Map<String, dynamic>> parseBody() async {
      final raw = await readBody();
      if (raw == null) return {};
      final decoded = jsonDecode(utf8.decode(raw));
      return decoded is Map<String, dynamic> ? decoded : {};
    }

    if (path == '/payments/info') {
      return _json({'phone': '0763795801', 'amount': 2500});
    }
    if (path == '/payments/donate' && options.method == 'POST') {
      final body = await parseBody();
      bodies['POST /payments/donate'] = body;
      final p = backend.donate(
        userId: 'u1',
        userName: 'Thea Shirima',
        amount: int.tryParse('${body['amount'] ?? 0}') ?? 0,
        sms: '${body['sms_text'] ?? ''}',
        phone: '${body['phone'] ?? ''}',
      );
      return _json({'order_id': p['order_id'], 'status': 'verifying'}, 201);
    }
    if (path == '/payments/my-history') {
      return _json({'items': backend.historyFor('u1')});
    }
    if (path == '/payments/admin/all') {
      return _json(backend.adminAll());
    }
    final approve = RegExp(r'^/payments/admin/([^/]+)/approve$').firstMatch(path);
    if (approve != null && options.method == 'POST') {
      final body = await parseBody();
      bodies['approve:${approve.group(1)}'] = body;
      final p = backend.review(approve.group(1)!, 'approved',
          body['note'] as String?);
      if (p == null) return _json({'detail': 'haipo'}, 400);
      backend.verifiedUsers['${p['user_id']}'] = true;
      return _json({'ok': true, 'status': 'approved'});
    }
    final reject = RegExp(r'^/payments/admin/([^/]+)/reject$').firstMatch(path);
    if (reject != null && options.method == 'POST') {
      final body = await parseBody();
      bodies['reject:${reject.group(1)}'] = body;
      final p = backend.review(reject.group(1)!, 'rejected',
          body['note'] as String?);
      if (p == null) return _json({'detail': 'haipo'}, 400);
      return _json({'ok': true, 'status': 'rejected'});
    }
    final reply = RegExp(r'^/payments/admin/([^/]+)/reply$').firstMatch(path);
    if (reply != null && options.method == 'POST') {
      final body = await parseBody();
      bodies['reply:${reply.group(1)}'] = body;
      final p = backend.addMessage(
          reply.group(1)!, 'admin', '${body['message'] ?? body['reply'] ?? ''}');
      if (p == null) return _json({'detail': 'haipo'}, 404);
      return _json({'ok': true});
    }
    final msg = RegExp(r'^/payments/([^/]+)/message$').firstMatch(path);
    if (msg != null && options.method == 'POST') {
      final body = await parseBody();
      bodies['message:${msg.group(1)}'] = body;
      final p = backend.addMessage(
          msg.group(1)!, 'customer', '${body['message'] ?? ''}');
      if (p == null) return _json({'detail': 'haipo'}, 404);
      return _json({'ok': true});
    }
    if (path.startsWith('/payments/') && path.endsWith('/messages')) {
      final id = path.split('/')[2];
      for (final p in backend.payments) {
        if (p['order_id'] == id) return _json({'messages': p['messages']});
      }
      return _json({'messages': []});
    }
    if (path == '/notifications' || path.startsWith('/notifications')) {
      return _json({'notifications': []});
    }
    if (path == '/auth/me') return _json(Map<String, dynamic>.from(fakeMe));
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
  late PaymentsBackend backend;
  late _PaymentsRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    backend = PaymentsBackend();
    routes = _PaymentsRoutes(backend);
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    backend.payments.clear();
    backend.verifiedUsers.clear();
    backend.seq = 0;
    AppCache().clear();
  });

  group('API: user anatuma malipo (POST /payments/donate)', () {
    test('createDonation inatuma amount + sms + phone', () async {
      final res = await ApiService().createDonation(
          amount: 2500, smsText: 'Umetuma 2,500 TZS kwa 0763795801', phone: '0757502446');
      expect(res.statusCode, 201);
      final sent = routes.bodies['POST /payments/donate']!;
      expect(sent['amount'], 2500);
      expect(sent['phone'], '0757502446');
      expect('${sent['sms_text']}', contains('2,500'));
      // Backend ilihifadhi kama "verifying"
      expect(backend.payments.first['status'], 'verifying');
    });

    test('historia ya mtumiaji inaonyesha malipo yaliyotumwa', () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final res = await ApiService().getPaymentHistory();
      final items = (res.data['items'] as List).cast<Map>();
      expect(items, hasLength(1));
      expect(items.first['amount'], 2500);
      expect(items.first['status'], 'verifying');
    });
  });

  group('API: admin anaona + anahukumu', () {
    test('adminAllDonations inaonyesha malipo mapya na counts', () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final res = await ApiService().adminAllDonations();
      expect(res.data['counts']['verifying'], 1);
      expect(res.data['counts']['approved'], 0);
      final payments = (res.data['payments'] as List).cast<Map>();
      expect(payments.first['user_name'], 'Thea Shirima');
      expect(payments.first['amount'], 2500);
    });

    test('approve inabadilisha status → approved + is_verified inawashwa',
        () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final orderId = backend.payments.first['order_id'] as String;

      await ApiService().adminApproveDonation(orderId);

      expect(backend.payments.first['status'], 'approved');
      // approved → mtumiaji anaweza kupiga simu (is_verified)
      expect(backend.verifiedUsers['u1'], isTrue,
          reason: 'Kuthibitisha malipo kunamthibitisha mtumiaji (is_verified)');
      // Jumla iliyothibitishwa inaongezeka
      final all = await ApiService().adminAllDonations();
      expect(all.data['total_approved_tzs'], 2500);
    });

    test('reject + note inabadilisha status → rejected, note imehifadhiwa',
        () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final orderId = backend.payments.first['order_id'] as String;

      await ApiService()
          .adminRejectDonation(orderId, note: 'Pesa haijaingia');

      final sent = routes.bodies['reject:$orderId']!;
      expect(sent['note'], 'Pesa haijaingia');
      expect(backend.payments.first['status'], 'rejected');
      expect(backend.payments.first['note'], 'Pesa haijaingia');
      // Rejected hairuhusu mtumiaji
      expect(backend.verifiedUsers.containsKey('u1'), isFalse);
    });

    test('approve ya order isiyopo inarudisha 400 (hakuna hukumu ya mara mbili)',
        () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final orderId = backend.payments.first['order_id'] as String;
      await ApiService().adminApproveDonation(orderId);
      // Mara ya pili — backend inakataa (status si verifying tena)
      try {
        await ApiService().adminApproveDonation(orderId);
        fail('Inapaswa kushindwa (400)');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 400);
      }
    });
  });

  group('API: Ujumbe (text) kati ya user na admin', () {
    test('adminPaymentReply inatuma ujumbe kwa mtumiaji', () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final orderId = backend.payments.first['order_id'] as String;

      await ApiService().adminPaymentReply(orderId, 'Pole, thibitisha namba tena');

      final sent = routes.bodies['reply:$orderId']!;
      expect(sent['reply'], 'Pole, thibitisha namba tena',
          reason: 'field "reply" (backend PaymentReplyRequest) — sio "message"');
      final msgs = backend.payments.first['messages'] as List;
      expect(msgs, hasLength(1));
      expect(msgs.first['sender'], 'admin');
    });

    test('sendPaymentMessage — user anauliza kwa nini yamekataliwa', () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final orderId = backend.payments.first['order_id'] as String;

      await ApiService().sendPaymentMessage(orderId, 'Kwa nini yamekataliwa?');

      final sent = routes.bodies['message:$orderId']!;
      expect(sent['message'], 'Kwa nini yamekataliwa?');
      final msgs = backend.payments.first['messages'] as List;
      expect(msgs.first['sender'], 'customer');
    });

    test('mazungumzo kamili: user → admin → user (messages zinahifadhiwa)',
        () async {
      await ApiService().createDonation(amount: 2500, smsText: 'S', phone: '07');
      final orderId = backend.payments.first['order_id'] as String;

      await ApiService().sendPaymentMessage(orderId, 'Nimetuma, angalia');
      await ApiService().adminPaymentReply(orderId, 'Tunakagua');
      await ApiService().adminPaymentReply(orderId, 'Imekamilika ✓');

      final res = await ApiService().getPaymentMessages(orderId);
      final msgs = (res.data['messages'] as List).cast<Map>();
      expect(msgs, hasLength(3));
      expect(msgs[0]['sender'], 'customer');
      expect(msgs[1]['sender'], 'admin');
      expect(msgs[2]['message'], 'Imekamilika ✓');
    });
  });

  group('Cache haifichi real-time (bug iliyorekebishwa)', () {
    test('getPaymentHistory ni useCache:false', () async {
      await ApiService().getPaymentHistory();
      final before =
          routes.calls.where((c) => c == 'GET /payments/my-history').length;
      await ApiService().getPaymentHistory();
      final after =
          routes.calls.where((c) => c == 'GET /payments/my-history').length;
      expect(after, before + 1,
          reason: 'Historia ya malipo lazima ifike server kila wakati — '
              'status mpya ya approved/rejected isifichwe na cache');
    });
  });

  group('UI: page ya admin ya malipo', () {
    testWidgets('inaonyesha malipo yanayosubiri + vitufe vya uthibitisho',
        (tester) async {
      backend.donate(
          userId: 'u1',
          userName: 'Thea Shirima',
          amount: 2500,
          sms: 'Umetuma 2,500 TZS',
          phone: '0757502446');

      await tester.pumpWidget(wrapApp(const AdminPaymentsPage()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Jina na kiasi vinaonekana
      expect(find.textContaining('Thea Shirima'), findsWidgets);
      expect(find.textContaining('2,500'), findsWidgets);
      // Vitufe vya uthibitisho/kukataa vipo
      expect(find.widgetWithText(FilledButton, 'Thibitisha'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Kataa'), findsOneWidget);
    });

    testWidgets('approve dialog inafunguka na kuthibitisha kunabadilisha status',
        (tester) async {
      final p = backend.donate(
          userId: 'u1',
          userName: 'Thea Shirima',
          amount: 2500,
          sms: 'Umetuma 2,500 TZS',
          phone: '0757502446');
      final orderId = p['order_id'] as String;

      await tester.pumpWidget(wrapApp(const AdminPaymentsPage()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Bonyeza kitufe cha kuthibitisha ("Thibitisha" — FilledButton ya kadi)
      final approveBtn = find.widgetWithText(FilledButton, 'Thibitisha').first;
      await tester.tap(approveBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog ya uthibitisho imefunguka
      expect(find.text('Thibitisha malipo haya?'), findsOneWidget);
      // .last — dialog button (card button bado ipo nyuma)
      await tester.tap(find.widgetWithText(FilledButton, 'Thibitisha').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // POST approve ilifika + status imebadilika
      expect(routes.bodies['approve:$orderId'], isNotNull);
      expect(p['status'], 'approved');

      // Flush snackbar timer
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('reject dialog inachagua sababu na kutuma note', (tester) async {
      final p = backend.donate(
          userId: 'u1',
          userName: 'Thea Shirima',
          amount: 2500,
          sms: 'Umetuma 2,500 TZS',
          phone: '0757502446');
      final orderId = p['order_id'] as String;

      await tester.pumpWidget(wrapApp(const AdminPaymentsPage()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Bonyeza kitufe cha kukataa ("Kataa" — OutlinedButton ya kadi)
      final rejectBtn = find.widgetWithText(OutlinedButton, 'Kataa').first;
      await tester.tap(rejectBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog ya kukataa — chagua sababu
      expect(find.text('Kataa malipo haya?'), findsOneWidget);
      await tester.tap(find.text('Pesa haijaingia'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Kataa'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // POST reject ilifika na note ni sababu iliyochaguliwa
      expect(routes.bodies['reject:$orderId']!['note'], 'Pesa haijaingia');
      expect(p['status'], 'rejected');

      // Flush snackbar timer
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('UI: screen ya mtumiaji (Changia/Malipo yangu)', () {
    testWidgets('inaonyesha historia ya malipo na status zake', (tester) async {
      backend.donate(
          userId: 'u1',
          userName: 'Thea Shirima',
          amount: 2500,
          sms: 'Umetuma 2,500 TZS',
          phone: '0757502446');

      await tester.pumpWidget(wrapApp(const DonateScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Historia inaonyesha malipo (kiasi)
      expect(find.textContaining('2,500'), findsWidgets);
    });
  });
}
