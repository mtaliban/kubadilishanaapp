/// Kubadilishana — main entry point with all routes.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'services/app_cache.dart';
import 'services/cached_repository.dart';
import 'services/app_navigator.dart';
import 'services/network_service.dart';
import 'services/offline_queue.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_flow_entry.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/donate_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/forgot_number_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/my_matches_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/call_history_screen.dart';
import 'screens/settings_screen.dart';
import 'app_config.dart';
import 'widgets/app_shell.dart' show LanguageProvider, ThemeProvider;
import 'widgets/network_pill.dart';

// "Wilaya yeyote" — lebo maalum ya lengo (tazama: register_screen.dart)
const String kWilayaAny = 'Wilaya yeyote';

// Global error log — displayed in _ErrorApp if crash happens
final List<String> _crashLog = [];

// UI ya kwanza imeonyeka? Kama NDIYO, kosa lolote la nyuma ya pazia
// (mtandao, WS n.k.) LIFUATE kwenye crash-log TU — USITENGEZE app nzima
// na skrini ya "Hakuna mtandao" (ile ilikuwa inaonekana KABLA ya logo).
// Banner ya mtandao (AppShell/NetworkBanner) na toasts ndizo zinazoonyesha
// offline NDANI ya app, kama WhatsApp.
bool _uiShown = false;

// Version ya APK — inaonyeshwa kwenye screens za makosa ili screenshot
// ionyeshe APK iliyotumika (husaidia kubaini kama mtumiaji bado anatumia
// APK ya zamani isiyopata fixes).
Future<PackageInfo?> _loadPackageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    return null;
  }
}

/// Mstari "Toleo 1.0.9+9" — huru kwenye screens za makosa.
class _VersionLine extends StatelessWidget {
  const _VersionLine();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo?>(
      future: _loadPackageInfo(),
      builder: (context, snap) {
        final v = snap.data;
        if (v == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Toleo ${v.version}+${v.buildNumber}',
              style: TextStyle(
                  fontSize: 12, color: Colors.red.shade300)),
        );
      },
    );
  }
}

void main() {
  AppConfig.isAdminBuild = true; // Admin APK — user + admin pages
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Theme (dark/light) ilio-hifadhiwa — isome kabla ya UI.
    unawaited(ThemeProvider().load());

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
      // Background handler — arifa zinapoingia app ikiwa IMEFUNGWA (kama WhatsApp).
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      _crashLog.add('[Firebase] $e');
    }

    try {
      ApiService().init();
    } catch (e) {
      _crashLog.add('[ApiService] $e');
    }

    // Pakia cache iliyohifadhiwa — pages zinaona data za mwisho MARA MOJA
    // bila kusubiri mtandao (stale-while-revalidate).
    try {
      await AppCache().warmUp();
    } catch (e) {
      _crashLog.add('[Cache] $e');
    }

    // Pakia timestamps za CachedRepository (offline-first) — kurusa zote
    // zinasoma disk mara moja; bango la juu linaona "data ya HH:mm" sahihi.
    try {
      await CachedRepository().warmUp();
    } catch (e) {
      _crashLog.add('[CacheRepo] $e');
    }

    // Anza huduma ya mtandao — inaangalia connectivity na /health
    try {
      NetworkService().start();
    } catch (e) {
      _crashLog.add('[Network] $e');
    }

    // Pakia foleni ya vitendo vilivyosubiri kutumwa (offline queue)
    try {
      await OfflineQueue().load();
    } catch (e) {
      _crashLog.add('[Queue] $e');
    }

    runApp(const KubadilishanaApp());
    // Frame ya kwanza ikaonyeka → app iko NDANI. Makosa yaliyofuata (async,
    // WS, API) hayabadilishi skrini — yanaendelea kwenye crash-log tu.
    WidgetsBinding.instance.addPostFrameCallback((_) => _uiShown = true);
  }, (error, stack) {
    _crashLog.add('[Zone] $error\n$stack');
    if (!_uiShown) {
      // Kosa kabla ya frame ya kwanza (runApp haijafanikiwa).
      // MTANDAO: kosa la mtandao HALIONYESHICI skrini ya zamani ya
      // "Hakuna mtandao / Jaribu tena" — app inafunguliwa kwa flow ya
      // MPYA: kurasa za cache (offline-first) + banner/pill ya mtandao
      // zinazoonyesha hali (kama WhatsApp). Hakuna full-screen ya kuzima.
      try {
        if (_ErrorWidget._isNetworkError(error.toString())) {
          runApp(const KubadilishanaApp());
        } else {
          runApp(_ErrorApp(error.toString()));
        }
      } catch (_) {}
    }
    // App iko ndani tayari: USIRUDIE runApp — banner/toasts zinashughulikia offline.
  });
}

class KubadilishanaApp extends StatefulWidget {
  const KubadilishanaApp({super.key});
  @override
  State<KubadilishanaApp> createState() => _KubadilishanaAppState();
}

class _KubadilishanaAppState extends State<KubadilishanaApp> {
  @override
  void initState() {
    super.initState();
    LanguageProvider().addListener(_onLangChange);
  }

  @override
  void dispose() {
    LanguageProvider().removeListener(_onLangChange);
    super.dispose();
  }

  void _onLangChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Override error widget to show message instead of red screen
    ErrorWidget.builder = (details) => _ErrorWidget(details.exceptionAsString());

    final locale = Locale(LanguageProvider().lang);

    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: ListenableBuilder(
        listenable: ThemeProvider(),
        builder: (context, _) => MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Kubadilishana',
          debugShowCheckedModeBanner: false,
          // MTANDAO-PILL: kidonge cha hali ya mtandao juu ya kurasa zote —
          // umekatika (njano) → unaunganika (bluu) → umeunganishwa (kijani).
          // Tazama widgets/network_pill.dart.
          builder: (context, child) => NetworkPillOverlay(
            controller: netPill,
            child: child ?? const SizedBox.shrink(),
          ),
          // DARK/LIGHT: ThemeProvider.toggle() inabadilisha app nzima.
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeProvider().dark ? ThemeMode.dark : ThemeMode.light,
          locale: locale,
          supportedLocales: const [Locale('sw'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
            '/register': (_) => const RegisterFlowEntry(),
            '/dashboard': (_) => const DashboardScreen(),
            '/profile': (_) => const ProfileScreen(),
            '/donate': (_) => const DonateScreen(),
            '/feedback': (_) => const FeedbackScreen(),
            '/notifications': (_) => const NotificationsScreen(),
            '/announcements': (_) => const AnnouncementsScreen(),
            '/forgot-password': (_) => const ForgotPasswordScreen(),
            '/forgot-number': (_) => const SahauNambaScreen(),
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
    //NOTE: Tawi la MTANDAO la "Hakuna mtandao / Jaribu tena" LIMEONDOTWA
    //kabisa — makosa ya mtandao hayafiki humu tena (zone handler inafungua
    //app kwa flow ya mpya ya cache + banner). Hii inabaki na makosa ya kweli.
    // Kosa lingine — ujumbe wa kirafiki + Jaribu tena; maelezo ya kiufundi
    // yamebaki chini (bado yanapatikana kwa screenshot kwa msanidi).
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.error_outline_rounded,
                    size: 64, color: Colors.red.shade300),
                const SizedBox(height: 20),
                const Text('Samahani, kosa lilitokea',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(
                  'Bonyeza "Jaribu tena". Kama litarudia, funga app kisha ifungue tena.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => main(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Jaribu tena'),
                ),
                const _VersionLine(),
                const Spacer(),
                // Maelezo ya kiufundi — piga picha na itume kwa msanidi.
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 170),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                          fontSize: 10, fontFamily: 'monospace', color: Colors.red),
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

  /// Kama kosa ni la mtandao (SocketException/DNS/timeout) tushirikishe
  /// mtumiaji kwa lugha rahisi badala ya exception ghafi.
  static bool _isNetworkError(String m) {
    return m.contains('SocketException') ||
        m.contains('Failed host lookup') ||
        m.contains('Failed host') ||
        m.contains('Network is unreachable') ||
        m.contains('Connection refused') ||
        m.contains('Connection timed out') ||
        m.contains('Connection closed') ||
        m.contains('errno = 7') ||
        m.contains('DioException') ||
        m.contains('HandshakeException');
  }

  @override
  Widget build(BuildContext context) {
    final isNet = _isNetworkError(message);
    if (isNet) {
      // Kosa la mtandao — ujumbe wa kirafiki, si screen nyekundu ya exception
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            const Text('Hakuna mtandao',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
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
