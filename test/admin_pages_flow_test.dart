// ============================================================================
// test/admin_pages_flow_test.dart
// TESTING ya ADMIN pages zisizopimwa kwa flows kamili:
//   1. MATANGAZO: list + send (payload kamili) + resend + delete
//   2. PASSWORD RESETS: list (status filter) + approve + reject
//   3. MONITORING: events + filter ya event_type + clear
//   4. CONTACTS: mawasiliano ya watumiaji (call/sms/whatsapp)
//   5. SETTINGS: require_payment GET/PUT
//   6. REGRESSION: DATA (idara) + MAONI (feedback/admin) + MALIPO
//      (payments/admin) — hizi zimepimwa kwa kina kwenye admin_data_flow,
//      feedback_flow na payments_flow; hapa ni uthibitisho wa kuunganisha.
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

class _AdminRoutes extends FakeApiAdapter {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> bodies = {};
  bool requirePayment = true;

  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> resets = [];
  List<Map<String, dynamic>> monitoring = [];
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> contacts = [];
  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> feedbackAdmin = [];
  List<Map<String, dynamic>> donationsAdmin = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    final q = options.uri.query;
    calls.add('${options.method} $path${q.isEmpty ? '' : '?$q'}');

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

    // ── MATANGAZO (admin) ──
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
      return _json({'ok': true, 'announcement_id': 'an-new'});
    }
    if (path.startsWith('/admin/announcements/') && path.endsWith('/resend')) {
      final id = path.split('/')[3];
      bodies['resend:$id'] = {'ok': true};
      return _json({'ok': true, 'delivered': 5});
    }
    if (path.startsWith('/admin/announcements/') && options.method == 'DELETE') {
      final id = path.split('/').last;
      announcements.removeWhere((a) => a['announcement_id'] == id);
      bodies['DELETE announcement'] = {'id': id};
      return _json({'ok': true});
    }
    if (path == '/admin/announcements') {
      return _json(
          {'announcements': announcements, 'total': announcements.length});
    }

    // ── PASSWORD RESETS ──
    final approveReset =
        RegExp(r'^/admin/password-resets/([^/]+)/approve$').firstMatch(path);
    if (approveReset != null) {
      for (final r in resets) {
        if (r['id'] == approveReset.group(1)) r['status'] = 'approved';
      }
      bodies['approve-reset'] = {'id': approveReset.group(1)};
      return _json({'ok': true});
    }
    final rejectReset =
        RegExp(r'^/admin/password-resets/([^/]+)/reject$').firstMatch(path);
    if (rejectReset != null) {
      for (final r in resets) {
        if (r['id'] == rejectReset.group(1)) r['status'] = 'rejected';
      }
      bodies['reject-reset'] = {'id': rejectReset.group(1)};
      return _json({'ok': true});
    }
    if (path == '/admin/password-resets') {
      final status = options.uri.queryParameters['status'] ?? 'pending';
      bodies['GET password-resets:$status'] = {'status': status};
      return _json({
        'results': resets.where((r) => r['status'] == status).toList(),
      });
    }

    // ── MONITORING / EVENTS ──
    if (path == '/admin/monitoring') return _json({'events': monitoring});
    // /admin/events/clear lazima ichunguzwe KABLA ya /admin/events (prefix).
    if (path == '/admin/events/clear' && options.method == 'POST') {
      bodies['POST /admin/events/clear'] = {'cleared': events.length};
      events.clear();
      return _json({'ok': true});
    }
    if (path == '/admin/events') {
      final t = options.uri.queryParameters['event_type'];
      bodies['GET events:${t ?? 'all'}'] = {'n': events.length};
      return _json({
        'events': t == null ? events : events.where((e) => e['event_type'] == t).toList(),
      });
    }

    // ── CONTACTS ──
    if (path == '/messages/admin/contacts') {
      return _json({'contacts': contacts});
    }

    // ── SETTINGS ──
    if (path == '/admin/settings/contact' && options.method == 'PUT') {
      final body = await parseBody();
      bodies['PUT settings'] = body;
      requirePayment = body['require_payment'] == true;
      return _json({'ok': true, 'require_payment': requirePayment});
    }
    if (path == '/admin/settings/contact') {
      return _json({'require_payment': requirePayment});
    }

    // ── REGRESSION: DATA / MAONI / MALIPO ──
    if (path == '/admin/data/departments') return _json(departments);
    if (path == '/feedback/admin/all') {
      return _json({
        'total': feedbackAdmin.length,
        'items': feedbackAdmin,
        'counts': {'open': 1, 'replied': 0},
      });
    }
    if (path == '/payments/admin/all') {
      return _json({
        'items': donationsAdmin,
        'counts': {'verifying': 1, 'approved': 0, 'rejected': 0},
      });
    }
    if (path == '/admin/stats') {
      return _json({
        'users': {'total': 12},
        'payments': {'total': 3},
        'feedback': {'open': 1},
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
  late _AdminRoutes routes;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final api = ApiService();
    api.init();
    routes = _AdminRoutes();
    ApiService.dioForTest(api).httpClientAdapter = routes;
    await api.saveToken('admin-token');
  });

  setUp(() {
    routes.bodies.clear();
    routes.requirePayment = true;
    routes.announcements = [
      {
        'announcement_id': 'an1',
        'title': 'Tangazo la Makao',
        'message': 'Makao mapya yamefunguliwa Dodoma',
        'audience': 'all',
        'audiences': ['health', 'education', 'service'],
        'created_at': '2026-09-25T07:00:00Z',
      },
      {
        'announcement_id': 'an2',
        'title': 'Kwa Waafya',
        'message': 'Mkutano wa waafya Jumamosi',
        'audience': 'health',
        'audiences': ['health'],
        'created_at': '2026-09-24T07:00:00Z',
      },
    ];
    routes.resets = [
      {
        'id': 'r1',
        'user_name': 'Noah Mushi',
        'phone_primary': '0713000111',
        'status': 'pending',
        'created_at': '2026-09-25T10:00:00Z',
      },
      {
        'id': 'r2',
        'user_name': 'Halima Juma',
        'phone_primary': '0713000222',
        'status': 'pending',
        'created_at': '2026-09-25T11:00:00Z',
      },
    ];
    routes.monitoring = [
      {
        'type': 'success',
        'level': 'info',
        'event_type': 'user.registered',
        'description': 'Mtumiaji mpya amejiunga',
        'created_at': '2026-09-26T08:00:00Z',
      },
      {
        'type': 'error',
        'level': 'error',
        'event_type': 'payment.failed',
        'description': 'Malipo yameshindikana',
        'created_at': '2026-09-26T08:10:00Z',
      },
      {
        'type': 'warning',
        'level': 'warning',
        'event_type': 'payment.approved',
        'description': 'Malipo yameidhinishwa',
        'created_at': '2026-09-26T08:20:00Z',
      },
    ];
    routes.events = [
      {'event_type': 'user.registered', 'created_at': '2026-09-26T07:00:00Z'},
      {'event_type': 'payment.approved', 'created_at': '2026-09-26T07:05:00Z'},
      {'event_type': 'user.registered', 'created_at': '2026-09-26T07:10:00Z'},
    ];
    routes.contacts = [
      {
        'from_user_id': 'u1',
        'from_full_name': 'Juma Ali',
        'from_phone': '0715000111',
        'from_category': 'health',
        'from_cadre': 'NO',
        'from_region': 'Arusha',
        'to_full_name': 'Sara Mwakyusa',
        'to_cadre': 'CO',
        'to_category': 'health',
        'contact_type': 'call',
        'initiated_at': '2026-09-26T06:00:00Z',
      },
      {
        'from_user_id': 'u2',
        'from_full_name': 'Neema Peter',
        'from_phone': '0715000222',
        'from_category': 'education',
        'from_cadre': 'TCH',
        'from_region': 'Mbeya',
        'to_full_name': 'David Msigwa',
        'to_cadre': 'TCH',
        'to_category': 'education',
        'contact_type': 'sms',
        'initiated_at': '2026-09-26T06:30:00Z',
      },
    ];
    routes.departments = [
      {'code': 'IP', 'name': 'Idara ya Wagonjwa wa Ndani', 'is_active': true},
      {'code': 'SURG', 'name': 'Upasuaji', 'is_active': true},
    ];
    routes.feedbackAdmin = [
      {
        'id': 'fb1',
        'subject': 'Swali langu',
        'message': 'Nawezaje kubadilisha mkoa?',
        'status': 'open',
        'admin_reply': null,
        'user_name': 'Thea Shirima',
        'created_at': '2026-09-25T09:00:00Z',
      },
    ];
    routes.donationsAdmin = [
      {
        'order_id': '6E5B0D9DD8',
        'user_name': 'Test Donate Probe',
        'amount': 2500,
        'currency': 'TZS',
        'status': 'verifying',
        'sms_text': 'Test E2E donate probe',
        'created_at': '2026-09-26T05:00:00Z',
        'messages': [],
      },
    ];
    AppCache().clear();
  });

  tearDownAll(() {
    AppCache().clear();
  });

  group('1. MATANGAZO (admin) — list + send + resend + delete', () {
    test('adminListAnnouncements inaonyesha matangazo + audience', () async {
      final res = await ApiService().adminListAnnouncements();
      final items = (res.data['announcements'] as List).cast<Map>();
      expect(items, hasLength(2));
      expect(items.first['title'], 'Tangazo la Makao');
      expect(items.first['audience'], 'all');
      expect((items.last['audiences'] as List), contains('health'));
      expect(routes.calls.any((c) => c.contains('GET /admin/announcements')),
          isTrue);
    });

    test('adminSendAnnouncement inatuma payload kamili + inahifadhiwa',
        () async {
      await ApiService().adminSendAnnouncement({
        'title': 'Tangazo Jipya',
        'message': 'Karibuni mnufaike na mfumo',
        'audience': 'all',
        'audiences': ['health', 'education'],
      });

      final sent = routes.bodies['POST /admin/announcements'];
      expect(sent, isNotNull, reason: 'POST /admin/announcements imetumwa');
      expect(sent!['title'], 'Tangazo Jipya');
      expect(sent['message'], 'Karibuni mnufaike na mfumo');
      expect((sent['audiences'] as List), hasLength(2));

      // Server imehifadhi — list sasa ina matangazo 3
      final res = await ApiService().adminListAnnouncements();
      expect(res.data['total'], 3);
    });

    test('adminResendAnnouncement inafika server (id sahihi)', () async {
      await ApiService().adminResendAnnouncement('an1');
      expect(routes.bodies['resend:an1'], isNotNull,
          reason: 'POST /admin/announcements/an1/resend imetumwa');
    });

    test('adminDeleteAnnouncement inafuta server-side', () async {
      await ApiService().adminDeleteAnnouncement('an-new');
      expect(routes.bodies['DELETE announcement']!['id'], 'an-new');
      final res = await ApiService().adminListAnnouncements();
      expect(res.data['total'], 2, reason: 'Tangazo limefutwa kwenye orodha');
    });
  });

  group('2. PASSWORD RESETS — list + approve + reject', () {
    test('adminListPasswordResets inaomba status + inaonyesha ombi',
        () async {
      final res = await ApiService().adminListPasswordResets(status: 'pending');
      final results = (res.data['results'] as List).cast<Map>();
      expect(results, hasLength(2));
      expect(results.first['user_name'], 'Noah Mushi');
      expect(
          routes.calls
              .any((c) => c.contains('GET /admin/password-resets?status=pending')),
          isTrue);
      expect(routes.bodies['GET password-resets:pending'], isNotNull);
    });

    test('adminApprovePasswordReset inabadilisha status server-side',
        () async {
      await ApiService().adminApprovePasswordReset('r1');
      expect(routes.bodies['approve-reset']!['id'], 'r1');

      final pending =
          await ApiService().adminListPasswordResets(status: 'pending');
      expect((pending.data['results'] as List), hasLength(1),
          reason: 'r1 imeondoka kwenye pending');

      final approved =
          await ApiService().adminListPasswordResets(status: 'approved');
      expect(((approved.data['results'] as List).first as Map)['id'], 'r1');
    });

    test('adminRejectPasswordReset inafika server', () async {
      await ApiService().adminRejectPasswordReset('r2');
      expect(routes.bodies['reject-reset']!['id'], 'r2');
      final pending =
          await ApiService().adminListPasswordResets(status: 'pending');
      expect((pending.data['results'] as List), hasLength(1),
          reason: 'r2 imeondoka kwenye pending (imekataliwa)');
    });
  });

  group('3. MONITORING — events + filter + clear', () {
    test('adminGetMonitoring inaonyesha events za mfumo', () async {
      final res = await ApiService().adminGetMonitoring();
      final events = (res.data['events'] as List).cast<Map>();
      expect(events, hasLength(3));
      expect(events.map((e) => '${e['event_type']}'),
          containsAll(['user.registered', 'payment.approved']));
      expect(events.first['level'], 'info');
    });

    test('adminEvents inaunga mkono filter ya event_type', () async {
      final res = await ApiService().adminEvents(eventType: 'user.registered');
      final events = (res.data['events'] as List).cast<Map>();
      expect(events, hasLength(2), reason: 'Tu events za aina hiyo');
      expect(events.every((e) => e['event_type'] == 'user.registered'), isTrue);
      expect(routes.bodies['GET events:user.registered'], isNotNull);
    });

    test('adminClearEvents inatuma POST + inafuta zote', () async {
      await ApiService().adminClearEvents();
      expect(routes.bodies['POST /admin/events/clear']!['cleared'], 3);
      final res = await ApiService().adminEvents();
      expect(res.data['events'] as List, isEmpty,
          reason: 'Events zote zimefutwa');
    });
  });

  group('4. CONTACTS — mawasiliano ya watumiaji', () {
    test('getContactActivity inaonyesha simu/SMS/WhatsApp', () async {
      final res = await ApiService().getContactActivity(limit: 300);
      final contacts = (res.data['contacts'] as List).cast<Map>();
      expect(contacts, hasLength(2));
      expect(contacts.first['from_full_name'], 'Juma Ali');
      expect(contacts.first['contact_type'], 'call');
      expect(contacts.last['contact_type'], 'sms');
      expect(contacts.first['to_full_name'], 'Sara Mwakyusa');
      expect(
          routes.calls.any((c) => c.contains('GET /messages/admin/contacts')),
          isTrue);
    });
  });

  group('5. SETTINGS — require_payment', () {
    test('adminGetSettings inarudisha hali ya malipo', () async {
      final res = await ApiService().adminGetSettings();
      expect(res.data['require_payment'], isTrue);
    });

    test('adminUpdateContactSettings inatuma require_payment', () async {
      await ApiService().adminUpdateContactSettings(false);
      expect(routes.bodies['PUT settings']!['require_payment'], isFalse);
      final res = await ApiService().adminGetSettings();
      expect(res.data['require_payment'], isFalse,
          reason: 'Server imehifadhi mabadiliko');
    });
  });

  group('6. REGRESSION — DATA + MAONI + MALIPO (zimepimwa kwa kina ' 
      'kwenye admin_data_flow / feedback_flow / payments_flow)', () {
    test('adminListData (idara) inarudisha data ya reference', () async {
      final res = await ApiService().adminListData('departments');
      final items = (res.data as List).cast<Map>();
      expect(items, hasLength(2));
      expect(items.first['code'], 'IP');
      expect(
          routes.calls.any((c) => c.contains('GET /admin/data/departments')),
          isTrue);
    });

    test('adminListFeedback inaonyesha maoni ya watumiaji + counts', () async {
      final res = await ApiService().adminListFeedback();
      final items = (res.data['items'] as List).cast<Map>();
      expect(items, hasLength(1));
      expect(items.first['status'], 'open');
      expect(res.data['counts']['open'], 1);
      expect(
          routes.calls.any((c) => c.contains('GET /feedback/admin/all')),
          isTrue);
    });

    test('adminAllDonations inaonyesha malipo yanayosubiri', () async {
      final res = await ApiService().adminAllDonations();
      final items = (res.data['items'] as List).cast<Map>();
      expect(items, hasLength(1));
      expect(items.first['status'], 'verifying');
      expect(items.first['amount'], 2500);
      expect(
          routes.calls.any((c) => c.contains('GET /payments/admin/all')),
          isTrue);
    });

    test('adminStats inafika server (dashboard ya admin)', () async {
      final res = await ApiService().adminStats();
      expect(res.data['users']['total'], 12);
      expect(routes.calls.any((c) => c.contains('GET /admin/stats')), isTrue);
    });
  });
}
