/// Kubadilishana — main entry point.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/api.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Init API service
  ApiService().init();

  runApp(const KubadilishanaApp());
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
        routes: {
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/dashboard': (_) => const DashboardScreen(),
          '/forgot-password': (_) => const _ComingSoon('Nenosiri Jipya'),
          '/admin-login': (_) => const _ComingSoon('Admin Login'),
          '/admin': (_) => const _ComingSoon('Admin Dashboard'),
          '/profile': (_) => const _ComingSoon('Wasifu'),
          '/donate': (_) => const _ComingSoon('Michango'),
          '/feedback': (_) => const _ComingSoon('Maoni'),
          '/notifications': (_) => const _ComingSoon('Arifa'),
          '/about': (_) => const _ComingSoon('Kuhusu Sisi'),
        },
      ),
    );
  }
}

/// Placeholder for screens not yet built.
class _ComingSoon extends StatelessWidget {
  final String title;
  const _ComingSoon(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Inaendelea kuundwa...',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
      ),
    );
  }
}
