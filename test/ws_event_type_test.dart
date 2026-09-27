// ============================================================================
// test/ws_event_type_test.dart
// SHIDA ILIYOREKEBISHWA:
//   Backend inatuma envelope: {"event": "notification", "type": "feedback.new"}
//   — wateja waliosoma event['event'] TU walipata "notification" na kupuuza
//   aina halisi → ADMIN HAKUPATA arifa wala badge maoni mapya yaliyotumwa.
// Tests hizi zinathibitisha:
//   1. resolveNotificationEventType() inasoma type halisi kutoka envelope
//   2. AdminBadgeService: 'feedback.new' (envelope) inaongeza badge ya Maoni,
//      'payment.submitted' inaongeza badge ya Malipo
//   3. NotificationService.showFromEvent (admin) haipiuzi envelope hiyo
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/services/admin_badge_service.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/services/app_navigator.dart';
import 'package:kubadilishanaapp/services/notification_service.dart';
import 'package:kubadilishanaapp/services/websocket_service.dart';

import 'helpers/fake_api.dart';

class _Routes extends FakeApiAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    // Badges: malipo verifying = tupu, maoni = tupu (tunategemea WS bump tu)
    if (path.contains('admin')) return _json({'items': []});
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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    ApiService.dioForTest(api).httpClientAdapter = _Routes();
    await api.saveToken('test-token');
  });

  group('1. resolveNotificationEventType — envelope ya backend', () {
    test('{"event":"notification","type":"feedback.new"} → "feedback.new"',
        () {
      final t = resolveNotificationEventType({
        'event': 'notification',
        'notification_id': 'abc',
        'type': 'feedback.new',
        'title': 'Maoni mapya ya mtumiaji',
      });
      expect(t, 'feedback.new',
          reason: 'Aina halisi inasomwa kutoka "type" (siyo jina la envelope)');
    });

    test('event ya moja kwa moja ("match.found") inarudi kama ilivyo', () {
      expect(
        resolveNotificationEventType({'event': 'match.found', 'score': 0.9}),
        'match.found',
      );
      expect(
        resolveNotificationEventType({'event': 'data.changed', 'kind': 'cadre'}),
        'data.changed',
      );
    });

    test('envelope bila "type" inarudisha jina la envelope (salama)', () {
      expect(
        resolveNotificationEventType({'event': 'notification'}),
        'notification',
      );
    });
  });

  group('2. AdminBadgeService — badge ya Maoni/Malipo kwa envelope ya WS', () {
    testWidgets("'feedback.new' inaongeza badge ya Maoni MARA MOJA",
        (tester) async {
      final svc = AdminBadgeService();
      svc.reset();
      svc.start(); // inabind WS onAny + refresh (API bandia: counts = 0)
      await tester.pump(const Duration(milliseconds: 300)); // refresh imemaliza

      WebSocketService().dispatchEventForTest({
        'event': 'notification',
        'notification_id': 'n1',
        'type': 'feedback.new',
        'title': 'Maoni mapya ya mtumiaji',
        'body': 'Tatizo la mtandao — Juma',
      });
      await tester.pump(const Duration(milliseconds: 50));

      expect(svc.feedback, 1,
          reason: 'Badge ya Maoni inajiongeza bila refresh '
              '(hii NDIO ilikuwa haira — kabla haiongezeki kabisa)');
      expect(svc.payments, 0);

      WebSocketService().dispatchEventForTest({
        'event': 'notification',
        'type': 'payment.submitted',
        'title': 'Malipo mapya',
        'body': 'TZS 2,500',
      });
      await tester.pump(const Duration(milliseconds: 50));
      expect(svc.payments, 1,
          reason: 'Badge ya Malipo pia inafanya kazi na envelope ile ile');

      svc.stop(); // cancel timer — hakuna Timer pending mwishoni
    });
  });

  group('3. showFromEvent (admin) — envelope haipiuzi tena', () {
    testWidgets('feedback.new kwa admin inafika hadi arifa (hakuna throw)',
        (tester) async {
      setAdminStatus(true); // admin ndiye aliyeingia
      // Kabla ya fix: type ilisomwa kama "notification" → haipo kwenye
      // adminNotifiable → arifa ilipuuzwa KABISA (ndiyo shida ya user).
      // Sasa: inasoma "feedback.new" → inaonyeshwa. Plugin za local
      // notifications hazipo kwenye tests — _show inashika exception salama.
      NotificationService().showFromEvent({
        'event': 'notification',
        'notification_id': 'n2',
        'type': 'feedback.new',
        'title': 'Maoni mapya ya mtumiaji',
        'body': 'Pongezi — Thea',
      });
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets('user wa kawaida: feedback.replied (envelope) inaonekana',
        (tester) async {
      setAdminStatus(false);
      NotificationService().showFromEvent({
        'event': 'notification',
        'notification_id': 'n3',
        'type': 'feedback.replied',
        'title': 'Jibu la Admin kwenye maoni yako',
        'body': 'Tumerekebisha, asante',
      });
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });
}
