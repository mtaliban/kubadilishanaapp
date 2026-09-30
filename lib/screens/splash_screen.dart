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
  // ── Entry: staggered logo → text → loader (1 400ms) ──
  late final AnimationController _entryCtrl;
  late final Animation<double>  _logoScale;
  late final Animation<double>  _logoFade;
  late final Animation<Offset>  _textSlide;
  late final Animation<double>  _textFade;
  late final Animation<double>  _loaderFade;

  // ── Exit: fade everything out (450ms) ──
  late final AnimationController _exitCtrl;
  late final Animation<double>  _exitOpacity;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Logo pops in — scale 0.72 → 1.0 (easeOutBack) + fade in
    _logoScale = Tween(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Text slides up from slightly below + fades in (staggered after logo)
    _textSlide = Tween(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
    ));
    _textFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.28, 0.68, curve: Curves.easeOut),
      ),
    );

    // Loader fades in last
    _loaderFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
      ),
    );

    // Exit — full-screen fade to white before navigation
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _exitOpacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic),
    );

    _entryCtrl.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    final sw = Stopwatch()..start();

    // Auth check na minimum timer zinakimbia pamoja — navigate baada ya zote
    final isLoggedIn = await auth.restoreSession();
    if (!mounted) return;

    // Splash iwe wazi kwa angalau sekunde 2.8 tangu mwanzo
    const minMs = 2800;
    final remaining = minMs - sw.elapsedMilliseconds;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }
    if (!mounted) return;

    // Slide-out ya laini kabla ya navigate
    await _exitCtrl.forward();
    if (!mounted) return;

    if (AppConfig.isAdminBuild && auth.isAdmin) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _exitOpacity,
        builder: (_, child) => Opacity(opacity: _exitOpacity.value, child: child),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFEEF2FF)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // ── Logo ──
            AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(scale: _logoScale.value, child: child),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.22),
                      blurRadius: 36,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                    const BoxShadow(
                      color: Color(0x15000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/images/logo.jpeg',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ── App name + tagline ──
            AnimatedBuilder(
              animation: _entryCtrl,
              builder: (_, child) => SlideTransition(
                position: _textSlide,
                child: FadeTransition(opacity: _textFade, child: child),
              ),
              child: Column(
                children: [
                  const Text(
                    'Kubadilishana Vituo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E40AF),
                      letterSpacing: 0.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Jukwaa la Watumishi wa Umma',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // ── Loader ──
            AnimatedBuilder(
              animation: _loaderFade,
              builder: (_, child) => Opacity(opacity: _loaderFade.value, child: child),
              child: const _ThreeDotsLoader(),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ── Three-dot bouncing loader ─────────────────────────────────────────────────
class _ThreeDotsLoader extends StatefulWidget {
  const _ThreeDotsLoader();
  @override
  State<_ThreeDotsLoader> createState() => _ThreeDotsLoaderState();
}

class _ThreeDotsLoaderState extends State<_ThreeDotsLoader>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 580),
      ),
    );
    _anims = _ctrls
        .map((c) => Tween(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 190), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: AnimatedBuilder(
          animation: _anims[i],
          builder: (_, child2) {
            final v = _anims[i].value;
            return Transform.translate(
              offset: Offset(0, -9 * v),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0xFFBFDBFE), // blue-200
                    const Color(0xFF1E40AF), // blue-700
                    v,
                  ),
                ),
              ),
            );
          },
        ),
      )),
    );
  }
}
