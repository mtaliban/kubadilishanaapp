/// Kubadilishana — USER entry point (Play Store / App Store).
/// Admin screens, AdminShell, na AdminLoginScreen HAZIPO kwenye build hii —
/// Dart tree-shaker itaziondoa kabisa kwenye APK/AAB.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_config.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'services/app_cache.dart';
import 'services/app_navigator.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/registration_flow_screen.dart'
    show RegistrationFlowScreen, TargetArea, kNoSchool;
import 'screens/dashboard_screen.dart';

// "Wilaya yeyote" — lebo maalum ya lengo (regiza: registration_flow_screen)
const String kWilayaAny = 'Wilaya yeyote';
import 'screens/profile_screen.dart';
import 'screens/donate_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/forgot_number_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/my_matches_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/call_history_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/app_shell.dart' show LanguageProvider;

// NOTE: admin screens HAZIJAIMPORTWA hapa — hazitaingia kwenye APK ya user.

final List<String> _crashLog = [];

Future<PackageInfo?> _loadPackageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    return null;
  }
}

class _VersionLine extends StatelessWidget {
  const _VersionLine({this.light = false});
  final bool light;
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
                  fontSize: 12,
                  color: light ? Colors.grey.shade500 : Colors.red.shade300)),
        );
      },
    );
  }
}

void main() {
  AppConfig.isAdminBuild = false; // User APK — user pages tu, hakuna admin
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      _crashLog.add('[Flutter] ${details.exceptionAsString()}');
      FlutterError.presentError(details);
    };

    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      _crashLog.add('[Platform] $error');
      return true;
    };

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      _crashLog.add('[Firebase] $e');
    }

    try {
      ApiService().init();
    } catch (e) {
      _crashLog.add('[ApiService] $e');
    }

    // SERA: OFFLINE — Cached + banner. Pakia cache iliyohifadhiwa ili pages
    // zioneeshe data za mwisho MARA MOJA hata bila mtandao (banner ya juu
    // inaonyesha hali ya mtandao).
    try {
      await AppCache().warmUp();
    } catch (e) {
      _crashLog.add('[Cache] $e');
    }

    runApp(const _UserApp());
  }, (error, stack) {
    _crashLog.add('[Zone] $error\n$stack');
    try {
      runApp(_ErrorApp(error.toString()));
    } catch (_) {}
  });
}

class _UserApp extends StatefulWidget {
  const _UserApp();
  @override
  State<_UserApp> createState() => _UserAppState();
}

class _UserAppState extends State<_UserApp> {
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
    ErrorWidget.builder = (details) => _ErrorWidget(details.exceptionAsString());
    final locale = Locale(LanguageProvider().lang);

    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Kubadilishana',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
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
          '/':                (_) => const SplashScreen(),
          '/login':           (_) => const LoginScreen(),
          '/register':        (_) => const _RegisterFlowAdapter(),
          '/dashboard':       (_) => const DashboardScreen(),
          '/profile':         (_) => const ProfileScreen(),
          '/donate':          (_) => const DonateScreen(),
          '/feedback':        (_) => const FeedbackScreen(),
          '/notifications':   (_) => const NotificationsScreen(),
          '/announcements':   (_) => const AnnouncementsScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/forgot-number':   (_) => const SahauNambaScreen(),
          '/reset-password':  (_) => const ResetPasswordScreen(phone: ''),
          '/my-matches':      (_) => const MyMatchesScreen(),
          '/call-history':    (_) => const CallHistoryScreen(),
          '/settings':        (_) => const SettingsScreen(),
          '/about':           (_) => const _ComingSoon('Kuhusu Sisi'),
          // /admin na /admin-login HAZIPO — admin APK pekee ina routes hizo
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
    if (_ErrorWidget._isNetworkError(message)) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade500),
                  const SizedBox(height: 20),
                  const Text('Hakuna mtandao',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => main(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Jaribu tena'),
                  ),
                  const _VersionLine(light: true),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
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
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 170),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(message,
                        style: const TextStyle(
                            fontSize: 10, fontFamily: 'monospace', color: Colors.red)),
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
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade500),
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

// ── Adapter: RegistrationFlowScreen → /auth/register ────────────────────────
// Copy ya _RegisterFlowAdapter kutoka main.dart — user build inatumia hii.
class _RegisterFlowAdapter extends StatelessWidget {
  const _RegisterFlowAdapter();

  @override
  Widget build(BuildContext context) {
    return RegistrationFlowScreen(
      onLogin: () => Navigator.pushReplacementNamed(context, '/login'),
      onSubmit: (data) async {
        final auth = context.read<AuthProvider>();

        // Eneo la sasa (StationInput) — kutoka IDs halisi za dropdown
        final station = <String, dynamic>{
          'region_id': data.mkoaId,
          'region_name': data.mkoa,
          'district_id': data.wilayaId,
          'district_name': data.wilaya,
          'facility_id': data.kituoId,
          'facility_name': data.kituo,
          'facility_type': data.kituoType,
        };

        // Maeneo ya lengo (DestinationInput) — mkoa moja kwa kila target card
        final destinations = <Map<String, dynamic>>[];
        for (final t in data.targets) {
          if (t.mkoaId == null) continue;
          final anyDistrict = t.wilaya.contains(kWilayaAny);
          if (anyDistrict || t.wilayaIds.isEmpty) {
            destinations.add({
              'region_id': t.mkoaId,
              'region_name': t.mkoa,
              'district_id': null,
              'district_name': null,
              'facility_id': t.shuleIds.isEmpty ? null : t.shuleIds.values.first,
              'facility_name':
                  (t.shule.isEmpty || t.shule.first == kNoSchool)
                      ? null
                      : t.shule.first,
              'notes': null,
            });
          } else {
            for (final w in t.wilaya) {
              if (w == kWilayaAny) continue;
              destinations.add({
                'region_id': t.mkoaId,
                'region_name': t.mkoa,
                'district_id': _districtIdOf(t, w),
                'district_name': w,
                'facility_id': t.shuleIds.isEmpty ? null : t.shuleIds.values.first,
                'facility_name':
                    (t.shule.isEmpty || t.shule.first == kNoSchool)
                        ? null
                        : t.shule.first,
                'notes': null,
              });
            }
          }
        }

        final payload = <String, dynamic>{
          'full_name': data.name,
          'phone_primary': data.phone,
          'phone_alt': data.whatsapp,
          'category': data.categoryCode ?? 'education',
          if (data.employmentSector != null) 'employment_sector': data.employmentSector,
          'cadre_code': data.cadreCode ?? '',
          'subjects': data.subjectCodes,
          'years_of_service': data.yearsOfService,
          'current_station': station,
          'desired_destinations': destinations,
        };

        final ok = await auth.register(payload);
        if (!context.mounted) return;
        if (ok) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else if (auth.error != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(auth.error!), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  static int? _districtIdOf(TargetArea t, String wName) {
    final i = t.wilaya.indexOf(wName);
    if (i < 0 || i >= t.wilayaIds.length) return null;
    return t.wilayaIds[i];
  }
}
