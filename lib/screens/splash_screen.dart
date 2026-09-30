import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _navy     = Color(0xFF1A2B8F);
  static const Color _subtitle = Color(0xFF6B7590);
  static const Color _track    = Color(0xFFE3E7F3);
  static const Duration _dur   = Duration(milliseconds: 3000);

  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  late final Animation<double> _fade;

  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: _dur);

    _progress = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
    );

    _ctrl.forward().whenComplete(_maybeNavigate);
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    final loggedIn = await auth.restoreSession();
    if (!mounted) return;
    setState(() => _isLoggedIn = loggedIn);
    _maybeNavigate();
  }

  void _maybeNavigate() {
    if (!mounted) return;
    if (_ctrl.status != AnimationStatus.completed) return;
    if (_isLoggedIn == null) return;

    final auth = context.read<AuthProvider>();
    if (AppConfig.isAdminBuild && auth.isAdmin) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (_isLoggedIn!) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.jpeg',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 28),

                // App name
                const Text(
                  'KUBADILISHANA PORTAL',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _navy,
                    letterSpacing: 2.4,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Jukwaa la Watumishi wa Umma',
                  style: TextStyle(
                    fontSize: 13,
                    color: _subtitle,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 36),

                // Progress bar
                SizedBox(
                  width: 120,
                  height: 5,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _track,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (_, __) => FractionallySizedBox(
                          widthFactor: _progress.value,
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: _navy,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
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
