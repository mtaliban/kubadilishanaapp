// ============================================================================
// test/responsive_v2_screens_test.dart
// Overflow tests za V2 screens za admin + UserDetailsPage + AdminMatchesPage —
// skrini ngumu zaidi (fomu ndefu za admin) kwenye simu ndogo→kubwa + font
// kubwa. Kila test inapump screen kwenye ukubwa 3 × scale 2 = 6 mazingira.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/admin/admin_users_v2_screens.dart';
import 'package:kubadilishanaapp/screens/admin/admin_view_user_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_matches_page.dart';

import 'helpers/responsive_pump.dart';
import 'helpers/fake_api.dart' show fakeRegion, fakeDistrict;

void main() {
  setUpAll(() async {
    await bootTestEnv();
  });

  Future<void> check(
    WidgetTester tester,
    WidgetBuilder builder, {
    String label = '',
  }) async {
    final overflows = await pumpResponsive(
      tester,
      builder,
      loggedIn: true,
      isAdmin: true,
    );
    expect(overflows, isEmpty, reason: 'OVERFLOW kwenye $label');
  };

  testWidgets('V2PickerScreen (mikoa + jina ndefu + maelezo marefu)',
      (tester) async {
    const opts = <V2PickOption>[
      (id: '1', name: 'Manyara', subtitle: 'Mkoa wa Manyara'),
      (id: '2', name: 'Mbeya', subtitle: null),
      (
        id: '3',
        name: 'Mkoa wenye jina ndefu kabisa unaojaa ukanda mzima',
        subtitle: 'Maelezo marefu sana yanayoweza kujaa mistari mingi'
      ),
    ];
    await check(
      tester,
      (_) => V2PickerScreen(
        title: 'Chagua Mkoa',
        subtitle: 'Chagua mkoa unautaka kwenda kufanya kazi',
        icon: Icons.map_rounded,
        allLabel: 'Mikoa yote',
        options: opts,
        selectedId: '2',
      ),
      label: 'V2PickerScreen',
    );
  });

  testWidgets('V2UserFormScreen (mpya + existing yenye jina ndefu)',
      (tester) async {
    // 1) Fomu mpya (empty) — sections zote + dropdowns.
    await check(
      tester,
      (_) => V2UserFormScreen(regions: const [fakeRegion, fakeDistrict]),
      label: 'V2UserFormScreen (mpya)',
    );

    // 2) Fomu ya kuhariri — jina na taarifa ndefu (font kubwa zinajaa).
    final existing = <String, dynamic>{
      'user_id': 'u9',
      'full_name': 'Amani Selemani Mkwajuni Nyanguso wa Kiteto',
      'phone_primary': '0757502446',
      'phone_alt': '0757502446',
      'email': 'amani.mkwajuni.nyanguso@kubadilishana.app',
      'category': 'education',
      'cadre_code': 'TCH',
      'cadre_display': 'Mwalimu wa Sekondari',
      'employment_sector': 'wizara',
      'years_of_service': 12,
      'status': 'active',
      'is_verified': true,
      'subjects': ['Hisabati', 'Fizikia'],
      'current_station': {
        'region_id': 1,
        'region_name': 'Manyara',
        'district_id': 2,
        'district_name': 'Kiteto DC',
        'facility_name': 'Shule ya Sekondari ya Kiteto DC',
      },
      'desired_destinations': [
        {'region_id': 3, 'region_name': 'Mbeya', 'district_name': 'Chunya DC'},
      ],
    };
    await check(
      tester,
      (_) => V2UserFormScreen(existing: existing, regions: const [fakeRegion]),
      label: 'V2UserFormScreen (existing)',
    );
  });

  testWidgets('V2UserDetailScreen (jina ndefu + destinations nyingi)',
      (tester) async {
    final user = <String, dynamic>{
      'user_id': 'u9',
      'full_name': 'Amani Selemani Mkwajuni Nyanguso wa Kiteto DC',
      'phone_primary': '0757502446',
      'phone_alt': '0757502446',
      'email': 'amani@kubadilishana.app',
      'category': 'education',
      'cadre_code': 'TCH',
      'cadre_display': 'Mwalimu wa Sekondari',
      'employment_sector': 'wizara',
      'years_of_service': 12,
      'status': 'active',
      'is_verified': true,
      'paid': true,
      'subjects': ['Hisabati', 'Fizikia', 'Biolojia', 'Kemia'],
      'current_station': {
        'region_id': 1,
        'region_name': 'Manyara',
        'district_id': 2,
        'district_name': 'Kiteto DC',
        'facility_name': 'Shule ya Sekondari ya Kiteto DC',
      },
      'desired_destinations': [
        {'region_id': 3, 'region_name': 'Mbeya', 'district_name': 'Chunya DC'},
        {'region_id': 4, 'region_name': 'Mara', 'district_name': 'Musoma MC'},
        {'region_id': 5, 'region_name': 'Kilimanjaro', 'district_name': 'Hai DC'},
        {'region_id': 6, 'region_name': 'Arusha', 'district_name': 'Monduli DC'},
        {'region_id': 7, 'region_name': 'Tanga', 'district_name': 'Longido DC'},
      ],
      'created_at': '2026-09-10T08:00:00Z',
    };
    await check(
      tester,
      (_) => V2UserDetailScreen(user: user),
      label: 'V2UserDetailScreen',
    );
  });

  testWidgets('V2AddAdminScreen', (tester) async {
    await check(
      tester,
      (_) => const V2AddAdminScreen(),
      label: 'V2AddAdminScreen',
    );
  });

  testWidgets('V2ImportScreen', (tester) async {
    await check(
      tester,
      (_) => V2ImportScreen(departments: const []),
      label: 'V2ImportScreen',
    );
  });

  testWidgets('UserDetailsPage (jina ndefu + destinations nyingi)',
      (tester) async {
    final u = UserDetails(
      name: 'Amani Selemani Mkwajuni Nyanguso wa Kiteto DC',
      idara: 'Wizara ya Afya — Idara ya Matibabu ndefu sana',
      kada: 'Mwalimu wa Sekondari — Hisabati na Fizikia',
      employer: 'Wizara ya Elimu, Sayansi na Teknolojia',
      masomo: const ['Hisabati', 'Fizikia', 'Biolojia'],
      phone: '0757502446',
      whatsapp: '0757502446',
      mkoa: 'Manyara',
      wilaya: 'Kiteto DC',
      kituo: 'Shule ya Sekondari ya Kiteto DC',
      destinations: const [
        ('Chunya DC', 'Mbeya'),
        ('Musoma Municipal Council ndefu', 'Mara'),
        ('Hai DC', 'Kilimanjaro'),
      ],
      active: true,
      paid: true,
      verified: true,
      hasPassword: true,
      contactAllowed: true,
      role: 'Mtumiaji',
      createdAt: DateTime(2026, 9, 10, 8),
      seenBy: 12,
      online: true,
    );
    await check(
      tester,
      (_) => UserDetailsPage(user: u),
      label: 'UserDetailsPage',
    );
  });

  testWidgets('AdminMatchesPage (WenzaoView)', (tester) async {
    await check(tester, (_) => const AdminMatchesPage(),
        label: 'AdminMatchesPage');
  });
}
