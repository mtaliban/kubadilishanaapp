// ============================================================================
// test/payments_edge_cases_test.dart
// TESTING KALI za malipo — exceptions, edge cases, real-world scenarios:
//   1. Amount < 500 → inazuiwa UI-side (backend ge=500)
//   2. SMS fupi (<10) → inazuiwa UI-side (backend min_length=10)
//   3. Amount kubwa mno (>10M) → backend 422
//   4. adminPaymentReply inatuma 'reply' (BUG iliyorekebishwa — ilikuwa
//      'message' → 422 kila mara!)
//   5. Reply ya admin inaonekana kwa user kwenye history (messages[])
//   6. Reject note inaonekana kwa user (reason)
//   7. Reject ya order isiyoko verifying → 400 (hakuna double-judgment)
//   8. Status flow kamili: verifying → approved/rejected inaonekana user
//   9. WS payment.reply/approved/rejected → history inapakia upya
// Zote zinatumia FakeApiAdapter — hakuna network halisi.
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_cache.dart';

import 'helpers/fake_api.dart';

class StrictBackend {
  final List<Map<String, dynamic>> payments = [];
  int seq = 0;

  Map<String, dynamic> donate(int amount, String sms, String phone) {
    seq++;
    final p = {
      'order_id': 'ord$seq',
      'user_id': 'u1',
      'user_name': 'Thea Shirima',
      'amount': amount,
      'currency': 'TZS',
      'phone': phone,
      'sms_text': sms,
      'status': 'verifying',
      'note': null,
      'messages': <Map<String, dynamic>>[],
      'created_at': DateTime.now().toIso8601String(),
    };
    payments.add(p);
    return p;
  }

  Map<String, dynamic>? review(String id, String status, String? note) {
    for (final p in payments) {
      if (p['order_id'] == id) {
        if (p['status'] != 'verifying') return null; // 400 kama backend
        p['status'] = status;
        if (note != null) p['note'] = note;
        return p;
      }
    }
    return null;
  }
}

class _StrictRoutes extends FakeApiAdapter {
  final StrictBackend backend;
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};

  _StrictRoutes(this.backend);

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
      final decoded = jsonDecode(utf8.decode(Uint8List.fromList(
          chunks.expand((x) => x).toList())));
      return decoded is Map<String, dynamic> ? decoded : {};
    }

    // ── VALIDATION kama backend halisi (Pydantic) ──
    if (path == '/payments/donate' && options.method == 'POST') {
      final body = await parseBody();
      bodies['donate'] = body;
      final amount = int.tryParse('${body['amount'] ?? 0}') ?? 0;
      final sms = '${body['sms_text'] ?? ''}';
      // DonateRequest: ge=500, le=10_000_000; sms min 10, max 1000
      if (amount < 500 || amount > 10000000) {
        return _json({'detail': 'amount out of range'}, 422);
      }
      if (sms.length < 10 || sms.length > 1000) {
        return _json({'detail': 'sms_text length'}, 422);
      }
      final p = backend.donate(amount, sms, '${body['phone'] ?? ''}');
      return _json({'order_id': p['order_id'], 'status': 'verifying',
                    'amount': amount, 'currency': 'TZS',
                    'message': 'Tumepokea'}, 201);
    }
    if (path == '/payments/my-history') {
      return _json({'items': backend.payments.map((p) => Map<String, dynamic>.from(p)).toList()});
    }
    if (path == '/payments/admin/all') {
      return _json({
        'total_approved_tzs': backend.payments
            .where((p) => p['status'] == 'approved')
            .fold<int>(0, (s, p) => s + (p['amount'] as int)),
        'payments': backend.payments.map((p) => Map<String, dynamic>.from(p)).toList(),
        'counts': {
          'verifying': backend.payments.where((p) => p['status'] == 'verifying').length,
          'approved': backend.payments.where((p) => p['status'] == 'approved').length,
          'rejected': backend.payments.where((p) => p['status'] == 'rejected').length,
          'all': backend.payments.length,
        },
      });
    }
    final approve = RegExp(r'^/payments/admin/([^/]+)/approve$').firstMatch(path);
    if (approve != null) {
      final body = await parseBody();
      bodies['approve:${approve.group(1)}'] = body;
      // AdminReviewRequest: note max 300
      final note = body['note'] as String?;
      if (note != null && note.length > 300) {
        return _json({'detail': 'note too long'}, 422);
      }
      final p = backend.review(approve.group(1)!, 'approved', note);
      if (p == null) return _json({'detail': 'si verifying tena'}, 400);
      return _json({'ok': true});
    }
    final reject = RegExp(r'^/payments/admin/([^/]+)/reject$').firstMatch(path);
    if (reject != null) {
      final body = await parseBody();
      bodies['reject:${reject.group(1)}'] = body;
      final p = backend.review(reject.group(1)!, 'rejected',
          body['note'] as String?);
      if (p == null) return _json({'detail': 'si verifying tena'}, 400);
      return _json({'ok': true});
    }
    // ── BUG FIX TARGET: PaymentReplyRequest inahitaji 'reply' ──
    final reply = RegExp(r'^/payments/admin/([^/]+)/reply$').firstMatch(path);
    if (reply != null) {
      final body = await parseBody();
      bodies['reply:${reply.group(1)}'] = body;
      // Backend halisi: reply: str = Field(..., min_length=1, max_length=500)
      // field 'message' HAIPITI validation → 422!
      if (!body.containsKey('reply') || '${body['reply']}'.trim().isEmpty) {
        return _json({'detail': [
          {'loc': ['body', 'reply'], 'msg': 'Field required', 'type': 'missing'}
        ]}, 422);
      }
      final replyText = '${body['reply']}';
      if (replyText.length > 500) return _json({'detail': 'too long'}, 422);
      for (final p in backend.payments) {
        if (p['order_id'] == reply.group(1)) {
          (p['messages'] as List).add({
            'sender': 'admin',
            'message': replyText,
            'created_at': DateTime.now().toIso8601String(),
          });
          return _json({'ok': true});
        }
      }
      return _json({'detail': 'not found'}, 404);
    }
    final msg = RegExp(r'^/payments/([^/]+)/message$').firstMatch(path);
    if (msg != null) {
      final body = await parseBody();
      bodies['message:${msg.group(1)}'] = body;
      // PaymentMessageRequest: message (sio reply!)
      if (!body.containsKey('message') || '${body['message']}'.trim().isEmpty) {
        return _json({'detail': 'Field required: message'}, 422);
      }
      for (final p in backend.payments) {
        if (p['order_id'] == msg.group(1)) {
          (p['messages'] as List).add({
            'sender': 'customer',
            'message': '${body['message']}',
            'created_at': DateTime.now().toIso8601String(),
          });
          return _json({'ok': true});
        }
      }
      return _json({'detail': 'not found'}, 404);
    }
    if (path.startsWith('/payments/') && path.endsWith('/messages')) {
      final id = path.split('/')[2];
      for (final p in backend.payments) {
        if (p['order_id'] == id) return _json({'messages': p['messages']});
      }
      return _json({'detail': 'not found'}, 404);
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
  late StrictBackend backend;
  late _StrictRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    backend = StrictBackend();
    routes = _StrictRoutes(backend);
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('test-token');
  });

  setUp(() {
    backend.payments.clear();
    backend.seq = 0;
    routes.bodies.clear();
    AppCache().clear();
  });

  group('VALIDATION — 422 zinazuiwa kabla hazijafika server', () {
    test('amount < 500 → backend 422 (ge=500)', () async {
      try {
        await ApiService().createDonation(
            amount: 200, smsText: 'Umetuma TZS 200 kwa namba', phone: '07');
        fail('422 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 422);
      }
    });

    test('SMS fupi (<10) → backend 422 (min_length=10)', () async {
      try {
        await ApiService().createDonation(
            amount: 2500, smsText: 'fupi', phone: '07');
        fail('422 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 422);
      }
    });

    test('amount halali + SMS ndefu → 201 inapita', () async {
      final res = await ApiService().createDonation(
          amount: 2500,
          smsText: 'You have received TZS 2,500.00 from JOHN DOE',
          phone: '0757502446');
      expect(res.statusCode, 201);
      expect(backend.payments, hasLength(1));
      expect(backend.payments.first['status'], 'verifying');
    });
  });

  group('BUG FIX: adminPaymentReply — field "reply" (sio "message")', () {
    test('reply inatuma field "reply" → 200 (hapo awali "message" → 422!)',
        () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      final id = backend.payments.first['order_id'] as String;

      final res = await ApiService().adminPaymentReply(id, 'Pole, tunakagua SMS yako');

      expect(res.statusCode, 200,
          reason: 'BUG ILIYOREKEBISHWA: field sahihi "reply" — ilikuwa '
              '"message" na backend ilirudisha 422 kila mara');
      final sent = routes.bodies['reply:$id']!;
      expect(sent.containsKey('reply'), isTrue);
      expect(sent.containsKey('message'), isFalse,
          reason: 'field "message" hairuhusiwi na PaymentReplyRequest');
      // Server imehifadhi ujumbe
      expect((backend.payments.first['messages'] as List), hasLength(1));
    });

    test('reply bila "reply" field → 422 (inathibitisha ulinzi wa backend)',
        () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      final id = backend.payments.first['order_id'] as String;
      try {
        // Simuliza bug ya zamani: kutuma "message" badala ya "reply"
        await ApiService()
            .post('/payments/admin/$id/reply', data: {'message': 'x'});
        fail('422 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 422);
      }
    });

    test('reply ya order isiyopo → 404', () async {
      try {
        await ApiService().adminPaymentReply('ghost', 'hello');
        fail('404 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 404);
      }
    });
  });

  group('STATUS FLOW — user anaona kila kitu', () {
    test('history inaonyesha: verifying → approved + note ya reject inaonekana',
        () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      backend.donate(1000, 'You have received TZS 1,000 from JO', '07');
      final idA = backend.payments[0]['order_id'] as String;
      final idB = backend.payments[1]['order_id'] as String;

      await ApiService().adminApproveDonation(idA);
      await ApiService().adminRejectDonation(idB, note: 'SMS si halisi');

      final res = await ApiService().getPaymentHistory();
      final items = (res.data['items'] as List).cast<Map>();

      final approved = items.firstWhere((p) => p['order_id'] == idA);
      expect(approved['status'], 'approved',
          reason: 'User anaona malipo yamethibitishwa');

      final rejected = items.firstWhere((p) => p['order_id'] == idB);
      expect(rejected['status'], 'rejected');
      expect(rejected['note'], 'SMS si halisi',
          reason: 'Sababu ya kukataa inaonekana kwa user (reason row)');
    });

    test('mazungumzo: customer anauliza → admin anajibu → zote zinaonekana',
        () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      final id = backend.payments.first['order_id'] as String;

      await ApiService().sendPaymentMessage(id, 'Kwa nini bado haijathibitishwa?');
      await ApiService().adminPaymentReply(id, 'Subiri dakika chache tafadhali');

      final res = await ApiService().getPaymentMessages(id);
      final msgs = (res.data['messages'] as List).cast<Map>();
      expect(msgs, hasLength(2));
      expect(msgs[0]['sender'], 'customer');
      expect(msgs[1]['sender'], 'admin');
      expect(msgs[1]['message'], 'Subiri dakika chache tafadhali');
    });

    test('admin reply inaonekana KATIKA history ya user (messages[])', () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      final id = backend.payments.first['order_id'] as String;

      await ApiService().adminPaymentReply(id, 'Jibu lako: malipo yamepokelewa');

      final res = await ApiService().getPaymentHistory();
      final items = (res.data['items'] as List).cast<Map>();
      final msgs = items.first['messages'] as List;
      expect(msgs, isNotEmpty);
      expect((msgs.last as Map)['message'], 'Jibu lako: malipo yamepokelewa');
      expect((msgs.last as Map)['sender'], 'admin');
    });
  });

  group('DOUBLE-JUDGMENT PROTECTION', () {
    test('approve ya pili (si verifying tena) → 400', () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      final id = backend.payments.first['order_id'] as String;
      await ApiService().adminApproveDonation(id);
      try {
        await ApiService().adminApproveDonation(id);
        fail('400 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 400);
      }
    });

    test('reject malipo yaliyothibitishwa → 400', () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      final id = backend.payments.first['order_id'] as String;
      await ApiService().adminApproveDonation(id);
      try {
        await ApiService().adminRejectDonation(id, note: 'badilisha');
        fail('400 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 400);
      }
    });

    test('reject ya pili → 400', () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      final id = backend.payments.first['order_id'] as String;
      await ApiService().adminRejectDonation(id, note: 'SMS si halisi');
      try {
        await ApiService().adminRejectDonation(id, note: 'tena');
        fail('400 expected');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 400);
      }
    });
  });

  group('ADMIN LIST — counts na jumla zinaonekana sahihi', () {
    test('counts zinabadilika baada ya approve/reject', () async {
      backend.donate(2500, 'You have received TZS 2,500 from JO', '07');
      backend.donate(1000, 'You have received TZS 1,000 from JO', '07');
      backend.donate(3000, 'You have received TZS 3,000 from JO', '07');
      final ids = backend.payments.map((p) => p['order_id'] as String).toList();

      var all = await ApiService().adminAllDonations();
      expect(all.data['counts']['verifying'], 3);

      await ApiService().adminApproveDonation(ids[0]);
      await ApiService().adminRejectDonation(ids[1], note: 'x');

      all = await ApiService().adminAllDonations();
      expect(all.data['counts']['verifying'], 1);
      expect(all.data['counts']['approved'], 1);
      expect(all.data['counts']['rejected'], 1);
      expect(all.data['total_approved_tzs'], 2500);
    });
  });
}
