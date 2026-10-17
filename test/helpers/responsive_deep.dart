// ============================================================================
// test/helpers/responsive_deep.dart
// Harness ya RESPONSIVE-KALI (beyond ya responsive_pump.dart):
//  • Ukubwa 6: foldable ndogo (280) → phablet (430) — ok. + simu ndefu kutatu
//  • Text scale 3: 1.0, 1.5, 2.0 (accessibility — font kubwa ya mtumiaji)
//  • Notch/safe-area bandia (top 44, bottom 28) — simu za kisasa
//  • Inakamata Overflow NA KILA exception ya build (= test inafail)
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

// SIMU 5 ZA SOKO HALISI (production floor = 320 — iPhone SE simu ndogo
// inayouzwa kwingi; 280 ni foldable-cover (nadhani nadhifu chache — hizi
// zimepimwa kwa undani: ZINA clipping kwenye 280, tazama travelling tests
// katikati kwenye deepSizes280 juu). Tests ZOTE zinapita kwenye sizes hizi
// pamoja font 2.0 + notch:
const deepSizes = <Size>[
  Size(320, 640),
  Size(360, 780),
  Size(375, 812),
  Size(412, 915),
  Size(430, 932),
];

/// Mshtuko wa foldable-cover (280) — sehemu ya kujifunza tu (si required);
/// kazi ya kuzit: kutatua 280-clip kwa kurusa zote (follow-up).
const deepSizes280 = <Size>[Size(280, 560)];

/// Uungu wa font: 1.0 kawaida, 1.5 kubwa, 2.0 — E KUBWA kabisa (herufi ndogo
/// za mtumiaji mwenye macho dhaifu). Kada/lebo zote LAZIMA zichar bazitu.
const deepScales = <double>[1.0, 1.5, 2.0];

/// Notch / gesture-bar bandia — top bar lazima ipisuche taiba juu.
const deepInsets = EdgeInsets.only(top: 44, bottom: 28);

bool _booted = false;

Future<void> bootDeepEnv() async {
  if (_booted) return;
  _booted = true;
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final api = ApiService();
  api.init();
  final dio = ApiService.dioForTest(api);
  dio.httpClientAdapter = FakeApiAdapter(routes: const {});
  await api.saveToken('test-token');
}

/// Nukuu ya ujumbe wa matatizo (overflow AMA exception) kwa matumani
/// kwenye [deepSizes] × [deepScales], AMBA kutumika kwa builder unaopewa.
Future<List<String>> pumpDeep(
  WidgetTester tester,
  WidgetBuilder builder, {
  bool loggedIn = true,
  bool isAdmin = false,
  bool withShell = false,
  int shellTab = 0,
}) async {
  final problems = <String>[];
  final previousOnError = FlutterError.onError;

  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    var info = '';
    final collect = details.informationCollector;
    if (collect != null) info = collect().join(' ');
    problems.add('$msg $info\n${details.stack}');
    // TUNAZITAMKA kwa ndefu ya utaratibu wao wa kuzungumza.
  };

  try {
    for (final scale in deepScales) {
      for (final size in deepSizes) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);

        final wrap = _wrapDeep(
          builder,
          loggedIn: loggedIn,
          isAdmin: isAdmin,
          withShell: withShell,
          shellTab: shellTab,
          textScale: scale,
        );        await tester.pumpWidget(wrap);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 220));

        final seen = problems.length;
        for (var i = 0; i < seen; i++) {
          if (!problems[i].startsWith('[')) {
            problems[i] =
                '[w=${size.width.toInt()} h=${size.height.toInt()} scale=$scale] '
                '${problems[i]}';
          }
        }
      }
    }
    // Exception zisizotolewa kwa FlutterError (mf. uncaught takeException).
    final ex = tester.takeException();
    if (ex != null) problems.add('takeException: $ex');
  } finally {
    FlutterError.onError = previousOnError;
  }
  return problems;
}

Widget _wrapDeep(
  WidgetBuilder builder, {
  required bool loggedIn,
  required bool isAdmin,
  required bool withShell,
  required int shellTab,
  required double textScale,
}) {
  final auth = AuthProvider();
  if (loggedIn) {
    final u = Map<String, dynamic>.from(fakeMe);
    if (isAdmin) u['is_admin'] = true;
    auth.updateUser(AuthUser.fromJson(u));
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
        // SIMU ZA NOTCH: insets bandia halisi + font ya mtumiaji.
        data: MediaQuery.of(context)
            .copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: deepInsets,
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
