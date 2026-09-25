// ============================================================================
// test/responsive_user_screens_test.dart
// Overflow tests — screens za MTUMIAJI kwenye simu ndogo→kubwa + font kubwa.
// Kila test inapump screen kwenye ukubwa 3 × scale 2 = 6 mazingira.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kubadilishanaapp/screens/login_screen.dart';
import 'package:kubadilishanaapp/screens/register_screen.dart';
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

import 'helpers/responsive_pump.dart';

void main() {
  setUpAll(() async {
    await bootTestEnv();
  });

  Future<void> check(
    WidgetTester tester,
    WidgetBuilder builder, {
    bool loggedIn = true,
    bool withShell = false,
    int shellTab = 0,
    String label = '',
  }) async {
    final overflows = await pumpResponsive(
      tester,
      builder,
      loggedIn: loggedIn,
      withShell: withShell,
      shellTab: shellTab,
    );
    expect(overflows, isEmpty, reason: 'OVERFLOW kwenye $label');
  };

  group('Auth screens (hakuna login)', () {
    testWidgets('LoginScreen', (tester) async {
      await check(tester, (_) => const LoginScreen(),
          loggedIn: false, label: 'LoginScreen');
    });

    testWidgets('RegisterScreen', (tester) async {
      await check(tester, (_) => const RegisterScreen(),
          loggedIn: false, label: 'RegisterScreen');
    }, skip: false);

    testWidgets('ForgotPasswordScreen', (tester) async {
      await check(tester, (_) => const ForgotPasswordScreen(),
          loggedIn: false, label: 'ForgotPasswordScreen');
    });

    testWidgets('SahauNambaScreen', (tester) async {
      await check(tester, (_) => const SahauNambaScreen(),
          loggedIn: false, label: 'SahauNambaScreen');
    });

    testWidgets('ResetPasswordScreen', (tester) async {
      await check(tester, (_) => const ResetPasswordScreen(phone: '0757502446'),
          loggedIn: false, label: 'ResetPasswordScreen');
    });
  });

  group('Main tabs (AppShell)', () {
    testWidgets('DashboardScreen', (tester) async {
      await check(tester, (_) => const DashboardScreen(),
          withShell: true, shellTab: 0, label: 'DashboardScreen');
    });

    testWidgets('DonateScreen (Changia)', (tester) async {
      await check(tester, (_) => const DonateScreen(),
          withShell: true, shellTab: 1, label: 'DonateScreen');
    });

    testWidgets('FeedbackScreen (Maoni)', (tester) async {
      await check(tester, (_) => const FeedbackScreen(),
          withShell: true, shellTab: 2, label: 'FeedbackScreen');
    });

    testWidgets('UserProfileScreen (Wasifu)', (tester) async {
      await check(tester, (_) => const UserProfileScreen(userId: 'u1'),
          withShell: true, shellTab: 3, label: 'UserProfileScreen');
    });
  });

  group('Secondary screens', () {
    testWidgets('AnnouncementsScreen', (tester) async {
      await check(tester, (_) => const AnnouncementsScreen(),
          label: 'AnnouncementsScreen');
    });

    testWidgets('NotificationsScreen', (tester) async {
      await check(tester, (_) => const NotificationsScreen(),
          label: 'NotificationsScreen');
    });

    testWidgets('SettingsScreen', (tester) async {
      await check(tester, (_) => const SettingsScreen(),
          label: 'SettingsScreen');
    });

    testWidgets('CallHistoryScreen', (tester) async {
      await check(tester, (_) => const CallHistoryScreen(),
          label: 'CallHistoryScreen');
    });

    testWidgets('MyMatchesScreen', (tester) async {
      await check(tester, (_) => const MyMatchesScreen(),
          label: 'MyMatchesScreen');
    });
  });
}
