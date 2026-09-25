// ============================================================================
// test/helpers/responsive_pump.dart
// Harness ya widget tests za responsive:
//  - Inasanidi SharedPreferences (mock), ApiService (FakeApiAdapter),
//    AuthProvider na user aliyeingia.
//  - Inapump widget kwenye ukubwa 3 za simu + text scale mbili (1.0, 1.3).
//  - Inakamata "RenderFlex overflowed" na kurudisha orodha yao.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kubadilishanaapp/providers/auth_provider.dart';
import 'package:kubadilishanaapp/services/api_service.dart';
import 'package:kubadilishanaapp/widgets/app_shell.dart'
    show LanguageProvider, AppShell;

import 'fake_api.dart';

/// Ukubwa wa simu tunayopima: ndogo (320), wastani (390), kubwa (430).
const phoneSizes = <Size>[
  Size(320, 640),
  Size(390, 844),
  Size(430, 932),
];

/// Text scales: kawaida (1.0) na kubwa (1.3) — font kubwa ni lazima.
const textScales = <double>[1.0, 1.3];

bool _booted = false;

/// Sanitisha mazingira ya test mara moja kabla ya pumps.
Future<void> bootTestEnv({
  Map<String, dynamic> routes = const {},
}) async {
  if (_booted) return;
  _booted = true;

  SharedPreferences.setMockInitialValues(<String, Object>{});

  // Injiza FakeApiAdapter kwenye Dio ya ApiService (singleton).
  // ApiService.swapAdapter ni test hook tuliyoweka kwenye api_service.dart.
  final api = ApiService();
  api.init();
  final dio = ApiService.dioForTest(api);
  dio.httpClientAdapter = FakeApiAdapter(routes: routes);

  // Token bandia + user aliyeingia (loadToken ni prefs, hakuna network).
  await api.saveToken('test-token');
}

/// Inapump [builder] kwenye ukubwa wote za simu na text scales zote.
/// Inarudisha orodha ya ujumbe wa overflow (matumaini: tupu).
Future<List<String>> pumpResponsive(
  WidgetTester tester,
  WidgetBuilder builder, {
  bool loggedIn = true,
  bool withShell = false,
  int shellTab = 0,
}) async {
  final overflows = <String>[];
  final previousOnError = FlutterError.onError;

  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed by')) {
      // Kamata pia "error-causing widget" kutoka informationCollector
      // ili tests zionyeshe widget iliyosababisha overflow.
      var info = '';
      final collect = details.informationCollector;
      if (collect != null) {
        info = collect().join(' ');
      }
      final stack = details.stack.toString();
      overflows.add('$msg $info\n$stack');
      return; // Usitupe — tunaendelea kukusanya.
    }
    previousOnError?.call(details);
  };

  try {
    for (final scale in textScales) {
      for (final size in phoneSizes) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        // Text scale kupitia MediaQuery ya MaterialApp (textScaleFactor
        // imeondolewa kwenye TestFlutterView toleo jipya).
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(
          builder,
          loggedIn: loggedIn,
          withShell: withShell,
          shellTab: shellTab,
          textScale: scale,
        ));
        // Pumps: animations, futures ndogo, shimmer n.k.
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 300));
        final seen = overflows.length;
        for (var i = 0; i < seen; i++) {
          if (!overflows[i].startsWith('[')) {
            overflows[i] =
                '[w=${size.width} h=${size.height} scale=$scale] ${overflows[i]}';
          }
        }
      }
    }
  } finally {
    FlutterError.onError = previousOnError;
  }
  return overflows;
}

Widget _wrap(
  WidgetBuilder builder, {
  required bool loggedIn,
  required bool withShell,
  required int shellTab,
  required double textScale,
}) {
  final auth = AuthProvider();
  if (loggedIn) {
    auth.updateUser(AuthUser.fromJson(Map<String, dynamic>.from(fakeMe)));
  }
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<LanguageProvider>.value(value: LanguageProvider()),
    ],
    child: MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('sw'), Locale('en')],
      builder: (context, child) => MediaQuery(
        // Font kubwa — lazima ipimwe (textScaler halisi wa mtumiaji).
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => withShell
            ? AppShell(tabIndex: shellTab, child: Builder(builder: builder))
            : Builder(builder: builder),
      ),
    ),
  );
}
