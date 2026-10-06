// ============================================================================
// test/responsive_admin_screens_test.dart
// Overflow tests — ADMIN pages kwenye simu ndogo→kubwa + font kubwa.
// Admin pages zote zinajengwa ndani ya AdminShell.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/admin_login_screen.dart';
import 'package:kubadilishanaapp/screens/admin/admin_shell.dart';
import 'package:kubadilishanaapp/screens/admin/admin_dashboard_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_users_v2_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_real_matches_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_data_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_announcements_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_payments_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_contacts_page.dart';
import 'package:kubadilishanaapp/screens/admin/waliopigiana_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_feedback_page.dart';
import 'package:kubadilishanaapp/screens/admin/maoni_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_reports_page.dart';
import 'package:kubadilishanaapp/screens/admin/statistics_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_monitoring_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_password_resets_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_add_user_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_add_admin_page.dart';
import 'package:kubadilishanaapp/screens/admin/admin_import_users_page.dart';
import 'package:kubadilishanaapp/screens/admin/profile_page.dart';

import 'helpers/responsive_pump.dart';

void main() {
  setUpAll(() async {
    await bootTestEnv();
  });

  Future<void> check(
    WidgetTester tester,
    WidgetBuilder builder, {
    String label = '',
    bool inShell = true,
  }) async {
    final overflows = await pumpResponsive(
      tester,
      inShell
          ? (ctx) => AdminShell(child: Builder(builder: builder))
          : builder,
      loggedIn: true,
      isAdmin: true, // AdminShell ina guard — pima kama admin halisi
    );
    expect(overflows, isEmpty, reason: 'OVERFLOW kwenye $label');
  };

  testWidgets('AdminLoginScreen', (tester) async {
    final overflows = await pumpResponsive(
      tester,
      (_) => const AdminLoginScreen(),
      loggedIn: false,
    );
    expect(overflows, isEmpty, reason: 'OVERFLOW kwenye AdminLoginScreen');
  });

  testWidgets('AdminShell + AdminDashboardPage', (tester) async {
    await check(tester, (_) => const AdminDashboardPage(),
        label: 'AdminDashboardPage');
  });

  testWidgets('AdminUsersV2Page', (tester) async {
    await check(tester, (_) => const AdminUsersV2Page(),
        label: 'AdminUsersV2Page');
  });

  testWidgets('AdminRealMatchesPage', (tester) async {
    await check(tester, (_) => const AdminRealMatchesPage(),
        label: 'AdminRealMatchesPage');
  });

  testWidgets('AdminDataPage', (tester) async {
    await check(tester, (_) => const AdminDataPage(), label: 'AdminDataPage');
  });

  testWidgets('AdminAnnouncementsPage', (tester) async {
    await check(tester, (_) => const AdminAnnouncementsPage(),
        label: 'AdminAnnouncementsPage');
  });

  testWidgets('AdminPaymentsPage', (tester) async {
    await check(tester, (_) => const AdminPaymentsPage(),
        label: 'AdminPaymentsPage');
  });

  testWidgets('AdminContactsPage', (tester) async {
    await check(tester, (_) => const AdminContactsPage(),
        label: 'AdminContactsPage');
  });

  testWidgets('WaliopigianaPage', (tester) async {
    await check(tester, (_) => const WaliopigianaPage(),
        label: 'WaliopigianaPage');
  });

  testWidgets('AdminFeedbackPage', (tester) async {
    await check(tester, (_) => const AdminFeedbackPage(),
        label: 'AdminFeedbackPage');
  });

  testWidgets('MaoniPage', (tester) async {
    await check(tester, (_) => const MaoniPage(), label: 'MaoniPage');
  });

  testWidgets('AdminReportsPage', (tester) async {
    await check(tester, (_) => const AdminReportsPage(),
        label: 'AdminReportsPage');
  });

  testWidgets('StatisticsPage', (tester) async {
    await check(tester, (_) => const AdminStatisticsPage(),
        label: 'StatisticsPage');
  });

  testWidgets('AdminMonitoringPage', (tester) async {
    await check(tester, (_) => const AdminMonitoringPage(),
        label: 'AdminMonitoringPage');
  });

  testWidgets('AdminPasswordResetsPage', (tester) async {
    await check(tester, (_) => const AdminPasswordResetsPage(),
        label: 'AdminPasswordResetsPage');
  });

  testWidgets('NewUserPage (AddUser)', (tester) async {
    await check(tester, (_) => const NewUserPage(), label: 'NewUserPage');
  });

  testWidgets('AddAdminPage', (tester) async {
    await check(tester, (_) => AddAdminPage(onSave: (_) async => null),
        label: 'AddAdminPage');
  });

  testWidgets('ImportUsersPage', (tester) async {
    await check(tester, (_) => const ImportUsersPage(),
        label: 'ImportUsersPage');
  });

  testWidgets('ProfilePage (view mode, data mbili)', (tester) async {
    // Hakuna API halisi hapa: onSave inajifanya tu.
    Future<String?> fakeSave(String fullName, String? whatsapp) async => null;

    // 1) Taarifa kamili (WhatsApp ipo).
    var overflows = await pumpResponsive(
      tester,
      (_) => ProfilePage(
        profile: const AdminProfile(
          fullName: 'Amani Selemani',
          role: 'Administrator',
          phone: '+255 712 345 678',
          email: 'amani@kubadilishana.app',
          whatsapp: '+255 712 345 678',
        ),
        onSave: fakeSave,
      ),
      loggedIn: false,
    );
    expect(overflows, isEmpty, reason: 'OVERFLOW kwenye ProfilePage (kamili)');

    // 2) Jina ndefu + barua ndefu + hakuna WhatsApp (mistari ya "Haijawekwa").
    overflows = await pumpResponsive(
      tester,
      (_) => ProfilePage(
        profile: const AdminProfile(
          fullName: 'Amani Selemani Mkwajuni Nyanguso',
          role: 'Administrator',
          phone: '+255 712 345 678',
          email: 'amani.mkwajuni.nyanguso@kubadilishana.app',
        ),
        onSave: fakeSave,
      ),
      loggedIn: false,
    );
    expect(overflows, isEmpty, reason: 'OVERFLOW kwenye ProfilePage (ndefu)');
  });
}
