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
    if (path.startsWith('/departments')) return [];
    if (path.startsWith('/notifications')) return {'notifications': []};
    if (path.startsWith('/payments')) {
      return {'items': [fakePayment]};
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
const fakePayment = <String, dynamic>{
  'payment_id': 'pay1',
  'amount': 2500,
  'status': 'approved',
  'created_at': '2026-09-24T05:10:00Z',
  'note': null,
};
