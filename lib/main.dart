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

// Global error log — displayed in _ErrorApp if crash happens
final List<String> _crashLog = [];

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch widget build errors — show on screen instead of crashing
    FlutterError.onError = (details) {
      _crashLog.add('[Flutter] ${details.exceptionAsString()}');
      FlutterError.presentError(details);
    };

    // Catch platform errors
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      _crashLog.add('[Platform] $error');
      return true; // handled — don't crash
    };

    try {
      await Firebase.initializeApp();
    } catch (e) {
      _crashLog.add('[Firebase] $e');
    }

    try {
      ApiService().init();
    } catch (e) {
      _crashLog.add('[ApiService] $e');
    }

    runApp(const KubadilishanaApp());
  }, (error, stack) {
    _crashLog.add('[Zone] $error\n$stack');
    // Try to show error app if runApp already ran
    try {
      runApp(_ErrorApp(error.toString()));
    } catch (_) {}
  });
}

class KubadilishanaApp extends StatelessWidget {
  const KubadilishanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Override error widget to show message instead of red screen
    ErrorWidget.builder = (details) => _ErrorWidget(details.exceptionAsString());

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
          '/crash-log': (_) => const _CrashLogScreen(),
        },
      ),
    );
  }
}

// ── Error display widgets ─────────────────────────────────────────────────────

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp(this.message);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kosa la App',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                const Text('Piga picha hii na itume kwa msanidi:',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      message,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  const _ErrorWidget(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade100,
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: SelectableText('KOSA: $message',
            style: const TextStyle(fontSize: 10, color: Colors.red)),
      ),
    );
  }
}

class _CrashLogScreen extends StatelessWidget {
  const _CrashLogScreen();
  @override
  Widget build(BuildContext context) {
    final logs = _crashLog.isEmpty ? ['Hakuna makosa yaliyorekodiwa'] : _crashLog;
    return Scaffold(
      appBar: AppBar(title: const Text('Kumbukumbu ya Makosa'), backgroundColor: Colors.red),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: logs.length,
        itemBuilder: (_, i) => Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SelectableText(logs[i],
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
        ),
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
      body: const Center(
          child: Text('Inaendelea kuundwa...',
              style: TextStyle(color: AppColors.textSecondary))),
    );
  }
}
