import 'dart:math' as math;
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
    with TickerProviderStateMixin {

  late final AnimationController _fadeCtrl;
  late final AnimationController _dotsCtrl;
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
    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack),
    );
    _fadeCtrl.forward();

    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

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
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Logo ────────────────────────────────────────────
                  Container(
                    width: 165,
                    height: 165,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: const Color(0xFFCECECE), width: 1.5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Jina kuu ────────────────────────────────────────
                  const Text(
                    'Kubadilishana portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Mstari bluu ─────────────────────────────────────
                  Container(
                    width: 56,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A78D6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Tagline ─────────────────────────────────────────
                  const Text(
                    'Jukwaa la watumishi wa umma',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7A7A7A),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 44),

                  // ── Dots tatu — staggered pulse ─────────────────────
                  AnimatedBuilder(
                    animation: _dotsCtrl,
                    builder: (context2, child2) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final t = (_dotsCtrl.value + i / 3) % 1.0;
                          final s = math.sin(t * math.pi);
                          final opacity = 0.20 + 0.80 * s * s;
                          final scale   = 0.65 + 0.35 * s * s;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: SizedBox(
                              width: 13,
                              height: 13,
                              child: Center(
                                child: Container(
                                  width: 11 * scale,
                                  height: 11 * scale,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A78D6)
                                        .withValues(alpha: opacity),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
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
