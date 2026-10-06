// ============================================================================
// test/helpers/fake_api.dart
// Fake HttpClientAdapter kwa Dio — hurudisha majibu ya JSON kwa kila path.
// Inatumika kwenye widget tests za responsive/overflow.
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adapter bandia: kila GET/POST inarudisha majibu kutoka [routes].
class FakeApiAdapter implements HttpClientAdapter {
  /// key: path (mf. '/matches/board'), value: data ya kurudisha.
  final Map<String, dynamic> routes;
  FakeApiAdapter({this.routes = const {}});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path.replaceAll(RegExp(r'^/api'), '');
    final data = routes[path] ?? _defaultFor(path);
    final body = jsonEncode(data);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  static dynamic _defaultFor(String path) {
    if (path.startsWith('/auth/me')) return fakeMe;
    if (path.startsWith('/matches/board')) {
      return {'candidates': [fakeCandidate], 'total': 1};
    }
    if (path.contains('true-matches') || path.contains('true_matches')) {
      return {'matches': []};
    }
    if (path.startsWith('/announcements')) {
      return {'announcements': []};
    }
    if (path.startsWith('/regions')) return [fakeRegion];
    if (path.startsWith('/districts')) return [fakeDistrict];
    if (path.startsWith('/facilities')) return [fakeFacility];
    if (path.startsWith('/cadres')) return [fakeCadre];
    if (path.startsWith('/subjects')) return [];
    if (path.startsWith('/admin/announcements')) {
      return {'announcements': [], 'total': 0};
    }
    if (path.startsWith('/admin/stats')) return fakeAdminStats;
    if (path.startsWith('/admin/reports')) return fakeAdminReports;
    if (path.startsWith('/admin/events')) return {'events': fakeAdminEvents};
    if (path.startsWith('/admin/users')) return {'users': []};
    if (path.startsWith('/admin/data/departments')) return [];
    if (path.startsWith('/departments')) return [];
    if (path.startsWith('/messages/admin/contacts')) {
      return {'contacts': [fakeContact]};
    }
    if (path.startsWith('/notifications')) return {'notifications': []};
    if (path.startsWith('/payments')) {
      return {'items': [fakePayment]};
    }
    if (path.startsWith('/feedback/admin/all')) {
      return {'total': 2, 'items': [fakeFeedback, fakeFeedbackReplied]};
    }
    if (path.startsWith('/feedback')) return {'items': []};
    if (path.startsWith('/matches/my')) {
      return {'matches': []};
    }
    if (path.startsWith('/matches/stats')) return {'total': 0};
    if (path.startsWith('/matches')) return {'matches': []};
    return {};
  }
}

// ── Data bandia za kawaida ──────────────────────────────────────────────────
const fakeMe = <String, dynamic>{
  'user_id': 'u1',
  'full_name': 'Thea Shirima',
  'phone_primary': '0757502446',
  'email': 'thea@example.com',
  'category': 'education',
  'cadre_code': 'TCH',
  'cadre_display': 'Mwalimu wa Sekondari',
  'employment_sector': 'wizara',
  'is_admin': false,
  'is_verified': true,
  'contact_enabled': true,
  'online': true,
  'subjects': ['Hisabati', 'Fizikia'],
  'current_station': {
    'region_id': 1,
    'region_name': 'Manyara',
    'district_id': 2,
    'district_name': 'Kiteto DC',
    'facility_name': 'Shule ya Sekondari Kiteto',
  },
  'desired_destinations': [
    {'region_id': 3, 'region_name': 'Mbeya', 'district_name': 'Chunya DC'},
    {'region_id': 4, 'region_name': 'Mara', 'district_name': null},
  ],
};

const fakeCandidate = <String, dynamic>{
  'user_id': 'p1',
  'full_name': 'Yona Thomas',
  'category': 'education',
  'cadre_code': 'TCH',
  'cadre_display': 'Mwalimu wa Sekondari',
  'phone_primary': '0712345678',
  'phone_alt': '0712345678',
  'online': true,
  'is_verified': true,
  'contact_enabled': true,
  'created_at': '2026-09-10T08:00:00Z',
  'years_of_service': 1,
  'subjects': ['Hisabati', 'Fizikia'],
  'current_station': {
    'region_name': 'Mbeya',
    'district_name': 'Chunya DC',
    'facility_name': 'Shule ya Chunya',
  },
  'matching_destination': {
    'region_name': 'Manyara',
    'district_name': 'Kiteto DC',
  },
  'desired_destinations': [
    {'region_name': 'Manyara', 'district_name': 'Kiteto DC'},
  ],
};

const fakeRegion = <String, dynamic>{'id': 1, 'name': 'Manyara'};
const fakeDistrict = <String, dynamic>{'id': 2, 'name': 'Kiteto DC'};
const fakeFacility = <String, dynamic>{'id': 3, 'name': 'Shule ya Kiteto', 'type': 'sekondari'};
const fakeCadre = <String, dynamic>{'code': 'TCH', 'display_name': 'Mwalimu wa Sekondari'};
const fakeFeedback = <String, dynamic>{
  'id': 'fb1',
  'subject': 'Malipo hayajaonekana',
  'message': 'Nimelipa leo asubuhi lakini hali bado open.',
  'status': 'open',
  'admin_reply': null,
  'admin_replied_at': null,
  'created_at': '2026-10-04T09:30:00Z',
  'user_name': 'Amina Hassan',
  'user_phone': '0757123456',
};
const fakeFeedbackReplied = <String, dynamic>{
  'id': 'fb2',
  'subject': 'Sahihi kwenye jina',
  'message': 'Jina langu limeandikwa vibaya kwenye mfumo.',
  'status': 'replied',
  'admin_reply': 'Asante, tumelirekebisha jina lako.',
  'admin_replied_at': '2026-10-04T11:00:00Z',
  'created_at': '2026-10-03T08:15:00Z',
  'user_name': '',
  'user_phone': '0713998877',
};
const fakeContact = <String, dynamic>{
  'from_user_id': 'u1',
  'from_full_name': 'Juma Ali',
  'from_phone': '0715000111',
  'from_category': 'health',
  'from_cadre': 'NO',
  'from_region': 'Arusha',
  'to_full_name': 'Sara Mwakyusa',
  'to_phone': '0715000222',
  'to_category': 'health',
  'to_cadre': 'CO',
  'to_region': 'Dodoma',
  'contact_type': 'call',
  'initiated_at': '2026-09-26T06:00:00Z',
};
const fakePayment = <String, dynamic>{
  'payment_id': 'pay1',
  'amount': 2500,
  'status': 'approved',
  'created_at': '2026-09-24T05:10:00Z',
  'note': null,
};

// ── Statistics (/admin/stats + /admin/reports + /admin/events) ───────────────
const fakeAdminStats = <String, dynamic>{
  'totals': {
    'users': 1349,
    'users_active_7d': 258,
    'users_verified': 45,
    'users_health': 445,
    'users_education': 883,
  },
  'by_cadre': [
    {'category': 'education', 'cadre': 'Mwalimu wa Sekondari', 'count': 631},
  ],
};

const fakeAdminReports = <String, dynamic>{
  'regions_total': 28,
  'districts_total': 194,
  'users_by_region': [
    {'region': 'Mwanza', 'count': 72},
    {'region': 'Dar Es Salaam', 'count': 19},
    {'region': 'Morogoro', 'count': 47},
  ],
  'incoming_by_region': [
    {'region': 'Mwanza', 'count': 308},
    {'region': 'Dar Es Salaam', 'count': 279},
    {'region': 'Morogoro', 'count': 232},
  ],
  'users_by_district': [
    {'district': 'Dodoma Cc', 'region': 'Dodoma', 'count': 9},
    {'district': 'Mbeya Cc', 'region': 'Mbeya', 'count': 11},
  ],
  'incoming_by_district': [
    {'district': 'Dodoma Cc', 'count': 83},
    {'district': 'Mbeya Cc', 'count': 58},
  ],
  'users_by_category': [
    {'category': 'education', 'count': 883},
    {'category': 'health', 'count': 445},
    {'category': 'watumishi_wa_umma', 'count': 9},
  ],
  'users_by_status': [
    {'status': 'active', 'count': 1349},
  ],
  'users_by_cadre': [
    {'cadre': 'Mwalimu wa Sekondari', 'level': 'Secondary', 'count': 631},
    {'cadre': 'Mwalimu wa Elimu ya Msingi', 'level': 'Primary', 'count': 252},
    {'cadre': 'Clinical Officer', 'level': '', 'count': 63},
  ],
  'incoming_sources': [
    {'from': 'Mtwara', 'to': 'Mwanza', 'count': 35},
    {'from': 'Kigoma', 'to': 'Morogoro', 'count': 32},
  ],
};

const fakeAdminEvents = <Map<String, dynamic>>[
  {'event_type': 'user.registered', 'occurred_at': '2026-09-26T08:25:00Z'},
  {'event_type': 'match.found', 'occurred_at': '2026-09-26T21:45:00Z'},
  {'event_type': 'feedback.new', 'occurred_at': '2026-09-26T17:04:00Z'},
];
