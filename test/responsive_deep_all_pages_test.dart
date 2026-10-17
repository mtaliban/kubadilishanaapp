// ============================================================================
// test/responsive_deep_all_pages_test.dart
// TESTING NGUMU YA RESPONSIVE — UKURASA KILA MOJA WA APP kwenye:
//   simu 6 (280→430, pamoja foldable ndogo) × font 3 (1.0/1.5/2.0) × notch.
// Hakuna overflow e kila exception ya build (18 mazingira kwa ukurasa).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/login_screen.dart';
import 'package:kubadilishanaapp/screens/register_screen.dart' as reg;
import 'package:kubadilishanaapp/screens/register_screen.dart';
import 'package:kubadilishanaapp/screens/register_repo.dart';
import 'package:kubadilishanaapp/screens/forgot_password_screen.dart';
import 'package:kubadilishanaapp/screens/forgot_number_screen.dart';
import 'package:kubadilishanaapp/screens/reset_password_screen.dart';
import 'package:kubadilishanaapp/screens/dashboard_screen.dart';
import 'package:kubadilishanaapp/screens/donate_screen.dart';
import 'package:kubadilishanaapp/screens/feedback_screen.dart';
import 'package:kubadilishanaapp/screens/announcements_screen.dart';
import 'package:kubadilishanaapp/screens/notifications_screen.dart';
import 'package:kubadilishanaapp/screens/settings_screen.dart';
import 'package:kubadilishanaapp/screens/call_history_screen.dart';
import 'package:kubadilishanaapp/screens/my_matches_screen.dart';
import 'package:kubadilishanaapp/screens/user_profile_screen.dart';

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
import 'package:kubadilishanaapp/screens/admin/admin_profile_page.dart';

import 'helpers/responsive_deep.dart';

void main() {
  setUpAll(() async {
    await bootDeepEnv();
  });

  Future<void> kagua(
    WidgetTester tester,
    WidgetBuilder b, {
    String label = '',
    bool loggedIn = true,
    bool isAdmin = false,
    bool withShell = false,
    int shellTab = 0,
  }) async {
    final problems = await pumpDeep(
      tester,
      b,
      loggedIn: loggedIn,
      isAdmin: isAdmin,
      withShell: withShell,
      shellTab: shellTab,
    );
    expect(problems, isEmpty, reason: 'UKURASA $label');
  }

  AdminShell admin(WidgetBuilder b) => AdminShell(child: Builder(builder: b));

  // ── AUTH (bila login) ─────────────────────────────────────────────────────
  testWidgets('LoginScreen', (t) async {
    await kagua(t, (_) => const LoginScreen(),
        label: 'LoginScreen', loggedIn: false);
  });

  testWidgets('RegistrationFlowPage (usajili)', (t) async {
    await kagua(t, (_) => RegistrationFlowPage(repository: _DeepRepo()),
        label: 'RegistrationFlowPage', loggedIn: false);
  });

  testWidgets('ForgotPasswordScreen', (t) async {
    await kagua(t, (_) => const ForgotPasswordScreen(),
        label: 'ForgotPasswordScreen', loggedIn: false);
  });

  testWidgets('SahauNambaScreen', (t) async {
    await kagua(t, (_) => const SahauNambaScreen(),
        label: 'SahauNambaScreen', loggedIn: false);
  });

  testWidgets('ResetPasswordScreen', (t) async {
    await kagua(t, (_) => const ResetPasswordScreen(phone: '0757502446'),
        label: 'ResetPasswordScreen', loggedIn: false);
  });

  // ── Mtumiaji (AppShell tabs) ─────────────────────────────────────────────
  testWidgets('DashboardScreen (tab 0)', (t) async {
    await kagua(t, (_) => const DashboardScreen(),
        withShell: true, shellTab: 0, label: 'DashboardScreen');
  });

  testWidgets('DonateScreen (tab 1)', (t) async {
    await kagua(t, (_) => const DonateScreen(),
        withShell: true, shellTab: 1, label: 'DonateScreen');
  });

  testWidgets('FeedbackScreen (tab 2)', (t) async {
    await kagua(t, (_) => const FeedbackScreen(),
        withShell: true, shellTab: 2, label: 'FeedbackScreen');
  });

  testWidgets('UserProfileScreen (tab 3)', (t) async {
    await kagua(t, (_) => const UserProfileScreen(userId: 'u1'),
        withShell: true, shellTab: 3, label: 'UserProfileScreen');
  });

  // ── Kurusa za sekondari za mtumiaji ───────────────────────────────────────
  testWidgets('AnnouncementsScreen', (t) async {
    await kagua(t, (_) => const AnnouncementsScreen(),
        label: 'AnnouncementsScreen');
  });

  testWidgets('NotificationsScreen', (t) async {
    await kagua(t, (_) => const NotificationsScreen(),
        label: 'NotificationsScreen');
  });

  testWidgets('SettingsScreen', (t) async {
    await kagua(t, (_) => const SettingsScreen(), label: 'SettingsScreen');
  });

  testWidgets('CallHistoryScreen', (t) async {
    await kagua(t, (_) => const CallHistoryScreen(), label: 'CallHistoryScreen');
  });

  testWidgets('MyMatchesScreen', (t) async {
    await kagua(t, (_) => const MyMatchesScreen(), label: 'MyMatchesScreen');
  });

  // ── ADMIN ────────────────────────────────────────────────────────────────
  testWidgets('AdminLoginScreen', (t) async {
    await kagua(t, (_) => const AdminLoginScreen(),
        label: 'AdminLoginScreen', loggedIn: false);
  });

  testWidgets('AdminDashboardPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminDashboardPage()),
        isAdmin: true, label: 'AdminDashboardPage');
  });

  testWidgets('AdminUsersV2Page', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminUsersV2Page()),
        isAdmin: true, label: 'AdminUsersV2Page');
  });

  testWidgets('AdminRealMatchesPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminRealMatchesPage()),
        isAdmin: true, label: 'AdminRealMatchesPage');
  });

  testWidgets('AdminDataPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminDataPage()),
        isAdmin: true, label: 'AdminDataPage');
  });

  testWidgets('AdminAnnouncementsPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminAnnouncementsPage()),
        isAdmin: true, label: 'AdminAnnouncementsPage');
  });

  testWidgets('AdminPaymentsPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminPaymentsPage()),
        isAdmin: true, label: 'AdminPaymentsPage');
  });

  testWidgets('AdminContactsPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminContactsPage()),
        isAdmin: true, label: 'AdminContactsPage');
  });

  testWidgets('WaliopigianaPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const WaliopigianaPage()),
        isAdmin: true, label: 'WaliopigianaPage');
  });

  testWidgets('AdminFeedbackPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminFeedbackPage()),
        isAdmin: true, label: 'AdminFeedbackPage');
  });

  testWidgets('MaoniPage (maoni 2)', (t) async {
    await kagua(
      t,
      (ctx) => admin(
        (_) => MaoniPage(initialItems: [
          Maoni(
              id: 1,
              name: 'Asha Mwinyi',
              phone: '+255700000000',
              date: '9 Okt, 07:41',
              text: 'Hii ni maoni ya kupimana'),
          Maoni(
              id: 2,
              name: 'Juma Kali Juma Kali Juma Kali Ndege',
              phone: '+255700111222',
              date: '9 Okt, 08:15',
              text: 'Maoni ndefu sana kuhusu huduma: kila kitu kipo, lakini '
                  'wenye herufi kubwa inapaswa kuonekana vizuri.'),
        ]),
      ),
      isAdmin: true,
      label: 'MaoniPage',
    );
  });

  testWidgets('AdminReportsPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminReportsPage()),
        isAdmin: true, label: 'AdminReportsPage');
  });

  testWidgets('StatisticsPage (AdminStatisticsPage)', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminStatisticsPage()),
        isAdmin: true, label: 'AdminStatisticsPage');
  });

  testWidgets('AdminMonitoringPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminMonitoringPage()),
        isAdmin: true, label: 'AdminMonitoringPage');
  });

  testWidgets('AdminPasswordResetsPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const AdminPasswordResetsPage()),
        isAdmin: true, label: 'AdminPasswordResetsPage');
  });

  testWidgets('NewUserPage (AddUser)', (t) async {
    await kagua(t, (ctx) => admin((_) => const NewUserPage()),
        isAdmin: true, label: 'NewUserPage');
  });

  testWidgets('AddAdminPage', (t) async {
    await kagua(t, (ctx) => admin((_) => AddAdminPage(onSave: (_) async => null)),
        isAdmin: true, label: 'AddAdminPage');
  });

  testWidgets('ImportUsersPage', (t) async {
    await kagua(t, (ctx) => admin((_) => const ImportUsersPage()),
        isAdmin: true, label: 'ImportUsersPage');
  });

  testWidgets('AdminProfilePage', (t) async {
    Future<bool> fakeSave(
        String fullName, String phone, String whatsapp, String email) async =>
        true;
    await kagua(
      t,
      (_) => AdminProfilePage(
        fullName: 'Amani Selemani Mkwajuni Nyanguso',
        phone: '+255 712 345 678',
        email: 'amani.mkwajuni.nyanguso@kubadilishana.app',
        onSave: fakeSave,
      ),
      label: 'AdminProfilePage',
      loggedIn: false,
    );
  });
}

// ── Repo bandia (hakuna network) ──────────────────────────────────────────────
class _DeepRepo implements reg.RegistrationRepository {
  @override
  Future<bool> isPhoneAvailable(String phone) async => true;
  @override
  Future<List<reg.RegOption>> regions() async =>
      [reg.RegOption(id: '1', label: 'Dar Es Salaam')];
  @override
  Future<List<reg.RegOption>> districts(reg.RegOption region) async =>
      [reg.RegOption(id: '2', label: 'Ilala Mc')];
  @override
  Future<List<reg.RegOption>> schools(reg.RegOption district) async =>
      [reg.RegOption(id: '3', label: 'Vivandani Primary School')];
  @override
  Future<List<reg.RegOption>> facilities(reg.RegOption district) async =>
      [reg.RegOption(id: '4', label: 'Amana Hospital')];
  @override
  Future<List<reg.RegOption>> referralHospitals(reg.RegOption region) async =>
      [reg.RegOption(id: '5', label: 'Muhimbili')];
  @override
  Future<List<reg.RegOption>> cadres() async =>
      [reg.RegOption(id: 'co', label: 'Clinical Officer')];
  @override
  Future<List<reg.RegOption>> subjects(reg.EduLevel level) async =>
      [reg.RegOption(id: 'eng', label: 'English')];
  @override
  Future<void> submit(reg.RegistrationData data) async {}
}
