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

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _scaleAnim;

  bool? _isLoggedIn;
  static const Duration _minDur = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack),
    );
    _fadeCtrl.forward();

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    final sw = Stopwatch()..start();

    final loggedIn = await auth.restoreSession();
    if (!mounted) return;

    final remaining = _minDur.inMilliseconds - sw.elapsedMilliseconds;
    if (remaining > 0) await Future.delayed(Duration(milliseconds: remaining));
    if (!mounted) return;

    setState(() => _isLoggedIn = loggedIn);
    _navigate();
  }

  void _navigate() {
    if (!mounted || _isLoggedIn == null) return;
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
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FB),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _fadeCtrl,
          builder: (_, child) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(scale: _scaleAnim.value, child: child),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo kwenye rounded square kubwa ────────────────────
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A52A8).withValues(alpha: 0.10),
                          blurRadius: 32,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Jina kuu ────────────────────────────────────────────
                  const Text(
                    'KUBADILISHANA PORTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0C1A4F),
                      letterSpacing: 2.2,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Tagline ──────────────────────────────────────────────
                  const Text(
                    'Jukwaa la Watumishi wa Umma',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7590),
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Progress bar nyembamba ───────────────────────────────
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0xFFD5DCF0),
                        valueColor: AlwaysStoppedAnimation(Color(0xFF1A52A8)),
                        minHeight: 7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
