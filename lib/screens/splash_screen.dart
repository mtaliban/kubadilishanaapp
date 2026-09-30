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

  // Logo: fade-in + scale-up laini (0–900 ms)
  late final AnimationController _logoCtrl;
  late final Animation<double>   _logoFade;
  late final Animation<double>   _logoScale;

  // Tagline: inaonekana baada ya logo (350–1100 ms)
  late final AnimationController _tagCtrl;
  late final Animation<double>   _tagFade;
  late final Animation<Offset>   _tagSlide;

  // Dots za kupiga bounce chini
  late final List<AnimationController> _dotCtrls;
  late final List<Animation<double>>   _dotAnims;

  bool? _isLoggedIn;
  static const Duration _minDur = Duration(milliseconds: 3400);

  @override
  void initState() {
    super.initState();

    // ── Logo ──────────────────────────────────────────────────────────
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );
    _logoCtrl.forward();

    // ── Tagline inaonekana baada ya logo ──────────────────────────────
    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut);
    _tagSlide = Tween(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _tagCtrl.forward();
    });

    // ── Dots zinanza kupiga baada ya sekunde moja ─────────────────────
    _dotCtrls = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 580),
      ),
    );
    _dotAnims = _dotCtrls
        .map((c) => Tween(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    Future.delayed(const Duration(milliseconds: 1000), () {
      for (int i = 0; i < 3; i++) {
        Future.delayed(Duration(milliseconds: i * 190), () {
          if (mounted) _dotCtrls[i].repeat(reverse: true);
        });
      }
    });

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    final sw = Stopwatch()..start();

    final loggedIn = await auth.restoreSession();
    if (!mounted) return;

    final remaining = _minDur.inMilliseconds - sw.elapsedMilliseconds;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }
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
    _logoCtrl.dispose();
    _tagCtrl.dispose();
    for (final c in _dotCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Logo + tagline — katikati kamili ──────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo kubwa yenye animation
                    AnimatedBuilder(
                      animation: _logoCtrl,
                      builder: (_, child) => Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: child,
                        ),
                      ),
                      child: Image.asset(
                        'assets/images/logo.jpeg',
                        width: 260,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Tagline inaonekana kwa slide-up laini
                    SlideTransition(
                      position: _tagSlide,
                      child: FadeTransition(
                        opacity: _tagFade,
                        child: const Text(
                          'Jukwaa la Watumishi wa Umma',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7590),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Dots za kupiga bounce chini ───────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 52),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedBuilder(
                    animation: _dotAnims[i],
                    builder: (_, __) {
                      final v = _dotAnims[i].value;
                      return Transform.translate(
                        offset: Offset(0, -9 * v),
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              const Color(0xFFB8D4F5),
                              const Color(0xFF1A52A8),
                              v,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
