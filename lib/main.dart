/// Kubadilishana — main entry point with all routes.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/donate_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/my_matches_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/call_history_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase itaendelea bila FCM kama haiwezi kuanzishwa
    }
    ApiService().init();
    runApp(const KubadilishanaApp());
  }, (error, stack) {
    // Catch unhandled exceptions — app haitaanguka
    debugPrint('Unhandled error: $error');
  });
}

class KubadilishanaApp extends StatelessWidget {
  const KubadilishanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Kubadilishana',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/user-profile') {
            final userId = settings.arguments as String? ?? '';
            return MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: userId));
          }
          return null;
        },
        routes: {
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/dashboard': (_) => const DashboardScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/donate': (_) => const DonateScreen(),
          '/feedback': (_) => const FeedbackScreen(),
          '/notifications': (_) => const NotificationsScreen(),
          '/announcements': (_) => const AnnouncementsScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/reset-password': (_) => const ResetPasswordScreen(phone: ''),
          '/admin-login': (_) => const AdminLoginScreen(),
          '/admin': (_) => const AdminShell(),
          '/my-matches': (_) => const MyMatchesScreen(),
          '/call-history': (_) => const CallHistoryScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/about': (_) => const _ComingSoon('Kuhusu Sisi'),
        },
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String title;
  const _ComingSoon(this.title);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Inaendelea kuundwa...', style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}
